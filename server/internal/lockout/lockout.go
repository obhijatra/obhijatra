// Package lockout protects password sign-in against guessing.
//
// Wrong passwords are counted per account and IP address. With the schema
// constants (see docs/decisions/0002-obhijatra-server.md):
//
//   - 10 wrong passwords for one account from one IP address within 15
//     minutes lock that account for that address for 15 minutes. People
//     signing in from anywhere else are not affected, so a stranger cannot
//     lock someone out of their own office.
//   - 30 wrong passwords for one account from all addresses together
//     within 15 minutes lock an ordinary account for every address for 15
//     minutes. A privileged account (an org admin or a superuser) is never
//     locked this way: each of its sign-in attempts waits instead, from 1
//     second, doubling with every further wrong password, up to 30 seconds.
//
// The wrong-password counter lives in a plain database table and the locks
// in the login_locks collection, so a restart resets neither. A lock is a
// new login_locks record; an early unlock (by an org admin, or with
// `obhijatra-server unlock`) is an update of it; both are in the audit
// chain.
//
// Every refused sign-in gets the same answer (HTTP 400, FailureMessage)
// after the same amount of password-hashing work, whether the account does
// not exist, the password is wrong, the account is locked or the account
// is deactivated, so the answer reveals none of these.
package lockout

import (
	"context"
	"database/sql"
	"errors"
	"fmt"
	"slices"
	"time"

	"ganigeorgiev.com/pocketbase/dbx"
	"ganigeorgiev.com/pocketbase/pocketbase/apis"
	"ganigeorgiev.com/pocketbase/pocketbase/core"
	"ganigeorgiev.com/pocketbase/pocketbase/tools/hook"
	"ganigeorgiev.com/pocketbase/pocketbase/tools/types"

	"github.com/obhijatra/obhijatra/server/internal/audit"
	"github.com/obhijatra/obhijatra/server/internal/schema"
)

// FailureMessage is the only answer to a refused password sign-in.
const FailureMessage = "Sign-in failed. Check the email address and password and try again. " +
	"After 10 wrong passwords an account is locked for 15 minutes; your organisation admin can unlock it sooner."

const failures = schema.LoginFailuresTable

// Sleep waits for d, or until ctx ends. It is a variable so that tests can
// observe the delays without waiting for them.
var Sleep = func(ctx context.Context, d time.Duration) {
	timer := time.NewTimer(d)
	defer timer.Stop()
	select {
	case <-timer.C:
	case <-ctx.Done():
	}
}

// Register binds the sign-in check and the login_locks guards to app.
func Register(app core.App) {
	app.OnRecordAuthWithPasswordRequest().Bind(&hook.Handler[*core.RecordAuthWithPasswordRequestEvent]{
		Id:   "obhijatraLockoutPasswordAuth",
		Func: authWithPassword,
	})

	app.OnRecordUpdate(schema.LoginLocks).BindFunc(guardUnlock)
	app.OnRecordDelete(schema.LoginLocks).BindFunc(func(e *core.RecordEvent) error {
		return errors.New("a login lock is kept as a record of the lock; unlock it instead of deleting it")
	})
}

type account struct{ collection, id string }

func accountOf(r *core.Record) account {
	return account{collection: r.Collection().Name, id: r.Id}
}

// Privileged reports whether r is an account that the account-wide limit
// slows down instead of locking: a superuser or an org admin. Locking them
// would let a stranger keep the people who unlock others locked out.
func Privileged(r *core.Record) bool {
	if r.IsSuperuser() {
		return true
	}
	return r.Collection().Name == schema.StaffUsers && r.GetString("role") == schema.RoleOrgAdmin
}

// Delay is how long each sign-in attempt for a privileged account waits
// when the account has accountFailures wrong passwords, from all
// addresses, within the window: nothing below AccountMaxFailures, then
// AccountDelayBase, doubling with every further wrong password, up to
// AccountDelayMax.
func Delay(accountFailures int) time.Duration {
	over := accountFailures - schema.AccountMaxFailures
	if over < 0 {
		return 0
	}
	d := schema.AccountDelayMax
	if over < 16 { // beyond this the shift could overflow; the cap applies anyway
		d = min(schema.AccountDelayBase<<over, schema.AccountDelayMax)
	}
	return d
}

// authWithPassword replaces PocketBase's own password check for every auth
// collection. It hashes the submitted password exactly once on every path,
// as PocketBase does, refuses accounts the collection's sign-in rule does
// not allow (deactivated accounts) with the same answer as a wrong
// password, and on success hands over to PocketBase's standard response
// (apis.RecordAuthResponse), which applies the superuser IP allow-list,
// MFA and login alerts.
func authWithPassword(e *core.RecordAuthWithPasswordRequestEvent) error {
	if e.Record == nil {
		dummyPasswordCheck(e.App, e.Collection)
		return refuse(e, "unknown identity")
	}

	acct := accountOf(e.Record)
	ip := e.RealIP()

	if Privileged(e.Record) {
		n, err := countFailures(e.App, acct, "", time.Now().UTC())
		if err != nil {
			return e.InternalServerError("", err) // fail closed
		}
		// Every attempt waits, the right password too, so the wait does
		// not reveal whether the password was right.
		if d := Delay(n); d > 0 {
			Sleep(e.Request.Context(), d)
		}
	}

	now := time.Now().UTC()
	locked, err := isLocked(e.App, acct, ip, now)
	if err != nil {
		return e.InternalServerError("", err) // fail closed
	}
	// Always check the password, so a locked account answers as slowly as
	// any other refused sign-in.
	valid := e.Record.ValidatePassword(e.Password)

	switch {
	case locked:
		return refuse(e, "account locked")
	case !valid:
		if err := recordFailure(e.App, acct, ip, Privileged(e.Record), now); err != nil {
			return e.InternalServerError("", err)
		}
		return refuse(e, "wrong password")
	}

	// The collection's sign-in rule (active accounts only). PocketBase's
	// response checks it too, but answers 403, which would tell a stranger
	// that the password was right; here it is one more refused sign-in.
	allowed, err := mayAuthenticate(e)
	if err != nil {
		return e.InternalServerError("", err)
	}
	if !allowed {
		if err := recordFailure(e.App, acct, ip, Privileged(e.Record), now); err != nil {
			return e.InternalServerError("", err)
		}
		return refuse(e, "account not allowed to sign in (deactivated)")
	}

	if err := clearFailures(e.App, acct, ip); err != nil {
		return e.InternalServerError("", err)
	}
	return apis.RecordAuthResponse(e.RequestEvent, e.Record, core.MFAMethodPassword, nil)
}

// mayAuthenticate applies the collection's auth rule to the account, as
// apis.RecordAuthResponse does.
func mayAuthenticate(e *core.RecordAuthWithPasswordRequestEvent) (bool, error) {
	info, err := e.RequestInfo()
	if err != nil {
		return false, err
	}
	return e.App.CanAccessRecord(e.Record, info, e.Record.Collection().AuthRule)
}

// refuse answers a refused sign-in. reason goes to the server's request log
// only; the client always sees FailureMessage.
func refuse(e *core.RecordAuthWithPasswordRequestEvent, reason string) error {
	return e.BadRequestError(FailureMessage, errors.New("sign-in refused: "+reason))
}

// dummyPasswordCheck spends the same hashing time as a real check, as
// PocketBase does for an unknown identity, so timing does not reveal
// whether an account exists.
func dummyPasswordCheck(app core.App, collection *core.Collection) {
	record := &core.Record{}
	if err := app.RecordQuery(collection).Limit(1).One(record); err != nil {
		return
	}
	_ = record.ValidatePassword("")
}

// isLocked reports whether acct has a lock for ip, or for every address,
// that has neither expired nor been lifted.
func isLocked(app core.App, acct account, ip string, now time.Time) (bool, error) {
	_, err := app.FindFirstRecordByFilter(schema.LoginLocks,
		"account_collection = {:c} && account_id = {:id} && unlocked = false && locked_until > {:now} && (ip = '' || ip = {:ip})",
		dbx.Params{"c": acct.collection, "id": acct.id, "now": dateTime(now), "ip": ip},
	)
	switch {
	case err == nil:
		return true, nil
	case errors.Is(err, sql.ErrNoRows):
		return false, nil
	default:
		return false, fmt.Errorf("lockout: check for a lock: %w", err)
	}
}

// countFailures counts acct's wrong passwords within the window: from ip,
// or from every address when ip is "".
func countFailures(app core.App, acct account, ip string, now time.Time) (int, error) {
	q := app.DB().Select("COUNT(*)").From(failures).
		Where(dbx.HashExp{"account_collection": acct.collection, "account_id": acct.id}).
		AndWhere(dbx.NewExp("[[at]] > {:start}", dbx.Params{"start": now.Add(-schema.LockoutWindow).UnixMilli()}))
	if ip != "" {
		q.AndWhere(dbx.HashExp{"ip": ip})
	}
	var n int
	if err := q.Row(&n); err != nil {
		return 0, fmt.Errorf("lockout: count: %w", err)
	}
	return n, nil
}

// recordFailure counts one wrong password for acct from ip and, at a
// limit, locks the account: for ip at LockoutMaxFailures from it, or, for
// an ordinary account, for every address at AccountMaxFailures from all
// addresses. It runs in one transaction, so two simultaneous wrong
// passwords cannot both miss a limit or both create a lock.
//
// The count from one address is not cleared when that address is locked:
// those wrong passwords still count towards the account-wide limit, and
// they leave the window when the lock ends (LockoutDuration is not shorter
// than LockoutWindow).
func recordFailure(app core.App, acct account, ip string, privileged bool, now time.Time) error {
	return audit.RunAs(app, audit.SystemActor, func(txApp core.App) error {
		db := txApp.NonconcurrentDB()

		// Forget failures older than the window, for every account.
		if _, err := db.Delete(failures, dbx.NewExp("[[at]] <= {:start}",
			dbx.Params{"start": now.Add(-schema.LockoutWindow).UnixMilli()})).Execute(); err != nil {
			return fmt.Errorf("lockout: prune: %w", err)
		}

		// A request running alongside this one may have locked it already.
		if locked, err := isLocked(txApp, acct, ip, now); err != nil || locked {
			return err
		}

		if _, err := db.Insert(failures, dbx.Params{
			"account_collection": acct.collection,
			"account_id":         acct.id,
			"ip":                 ip,
			"at":                 now.UnixMilli(),
		}).Execute(); err != nil {
			return fmt.Errorf("lockout: count: %w", err)
		}

		fromIP, err := countFailures(txApp, acct, ip, now)
		if err != nil {
			return err
		}
		total, err := countFailures(txApp, acct, "", now)
		if err != nil {
			return err
		}

		switch {
		case !privileged && total >= schema.AccountMaxFailures:
			if err := lock(txApp, acct, "", total, now); err != nil {
				return err
			}
			// The account-wide lock starts a fresh count once it ends.
			return deleteFailures(txApp, acct)
		case fromIP >= schema.LockoutMaxFailures:
			return lock(txApp, acct, ip, fromIP, now)
		}
		return nil
	})
}

// lock creates a login_locks record for acct: for ip, or for every
// address when ip is "".
func lock(txApp core.App, acct account, ip string, attempts int, now time.Time) error {
	locks, err := txApp.FindCollectionByNameOrId(schema.LoginLocks)
	if err != nil {
		return err
	}
	l := core.NewRecord(locks)
	l.Set("account_collection", acct.collection)
	l.Set("account_id", acct.id)
	l.Set("ip", ip)
	l.Set("failed_attempts", attempts)
	l.Set("locked_until", dateTime(now.Add(schema.LockoutDuration)))
	if err := txApp.Save(l); err != nil {
		return fmt.Errorf("lockout: lock: %w", err)
	}
	return nil
}

// clearFailures forgets acct's wrong passwords from ip after a correct
// password from it. Wrong passwords from other addresses still count
// towards the account-wide limit. It writes only when there is something
// to forget.
func clearFailures(app core.App, acct account, ip string) error {
	where := dbx.HashExp{"account_collection": acct.collection, "account_id": acct.id, "ip": ip}
	var n int
	if err := app.DB().Select("COUNT(*)").From(failures).Where(where).Row(&n); err != nil || n == 0 {
		return err
	}
	_, err := app.NonconcurrentDB().Delete(failures, where).Execute()
	return err
}

func deleteFailures(app core.App, acct account) error {
	_, err := app.NonconcurrentDB().Delete(failures,
		dbx.HashExp{"account_collection": acct.collection, "account_id": acct.id}).Execute()
	return err
}

// guardUnlock allows exactly one change to a lock, by anyone including
// superusers: unlocked from false to true. The server stamps when and by
// whom, and forgets the account's wrong passwords so it starts afresh.
func guardUnlock(e *core.RecordEvent) error {
	old, err := e.App.FindRecordById(schema.LoginLocks, e.Record.Id)
	if err != nil {
		return fmt.Errorf("could not read the stored login lock: %w", err)
	}
	if old.GetBool("unlocked") {
		return errors.New("this login lock has already been unlocked")
	}
	if !e.Record.GetBool("unlocked") {
		return errors.New("the only change allowed to a login lock is unlocking it (unlocked = true)")
	}

	allowed := []string{"unlocked", "unlocked_at", "unlocked_by", "updated"}
	for _, f := range e.Record.Collection().Fields {
		name := f.GetName()
		if !slices.Contains(allowed, name) && fmt.Sprint(old.Get(name)) != fmt.Sprint(e.Record.Get(name)) {
			return fmt.Errorf("the only change allowed to a login lock is unlocking it (field %q)", name)
		}
	}

	e.Record.Set("unlocked_at", types.NowDateTime())
	e.Record.Set("unlocked_by", "")
	if actor := audit.ActorOf(e.App); actor.Collection == schema.StaffUsers {
		e.Record.Set("unlocked_by", actor.ID)
	}

	if err := deleteFailures(e.App, account{old.GetString("account_collection"), old.GetString("account_id")}); err != nil {
		return err
	}
	return e.Next()
}

// UnlockResult is what Unlock did for one account.
type UnlockResult struct {
	Collection string
	ID         string
	Email      string
	Locks      int // locks lifted
	Failures   int // wrong passwords forgotten
}

// Unlock lifts every lock on the accounts with this email address (field
// users, staff users and superusers) and forgets their wrong passwords,
// which also ends the waiting of a privileged account. Every lifted lock
// and every cleared count is an audit-chain entry by actor. It is for
// `obhijatra-server unlock`, run on the server's own data folder, so a
// locked-out org admin can recover without another admin.
//
// It returns one result per account found; none means no account has the
// address.
func Unlock(app core.App, actor audit.Actor, email string) ([]UnlockResult, error) {
	var results []UnlockResult

	err := audit.RunAs(app, actor, func(txApp core.App) error {
		now := time.Now().UTC()
		for _, collection := range schema.LockableCollections {
			r, err := txApp.FindAuthRecordByEmail(collection, email)
			if errors.Is(err, sql.ErrNoRows) {
				continue
			}
			if err != nil {
				return fmt.Errorf("look up %s: %w", collection, err)
			}
			acct := accountOf(r)
			res := UnlockResult{Collection: collection, ID: r.Id, Email: r.Email()}

			if res.Failures, err = countFailures(txApp, acct, "", now); err != nil {
				return err
			}

			locks, err := txApp.FindRecordsByFilter(schema.LoginLocks,
				"account_collection = {:c} && account_id = {:id} && unlocked = false && locked_until > {:now}",
				"created", 0, 0, dbx.Params{"c": acct.collection, "id": acct.id, "now": dateTime(now)})
			if err != nil {
				return fmt.Errorf("find locks: %w", err)
			}
			for _, l := range locks {
				l.Set("unlocked", true)
				if err := txApp.Save(l); err != nil { // guardUnlock clears the count
					return fmt.Errorf("unlock: %w", err)
				}
				res.Locks++
			}

			// Wrong passwords without a lock (a privileged account that is
			// being slowed down, or an ordinary one below the limit).
			if remaining, err := countFailures(txApp, acct, "", now); err != nil {
				return err
			} else if remaining > 0 {
				if err := deleteFailures(txApp, acct); err != nil {
					return err
				}
				if err := audit.AppendEvent(txApp, actor, audit.ActionDelete, failures, acct.id); err != nil {
					return err
				}
			}

			results = append(results, res)
		}
		return nil
	})
	if err != nil {
		return nil, err
	}
	return results, nil
}

// dateTime formats t as PocketBase stores dates, so that stored dates and
// t compare correctly as text.
func dateTime(t time.Time) string {
	dt, _ := types.ParseDateTime(t)
	return dt.String()
}
