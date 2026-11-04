// Package lockout locks an account after repeated wrong passwords.
//
// LockoutMaxFailures wrong passwords for one account within LockoutWindow
// lock it for LockoutDuration (schema constants: 10, 15 minutes, 15
// minutes). The wrong-password counter lives in a plain database table and
// the lock in the login_locks collection, so neither is reset by a restart.
// A lock is a new login_locks record and an early unlock by an org admin is
// an update of it; both are therefore in the audit chain.
//
// Every refused sign-in gets the same answer (HTTP 400, FailureMessage)
// after the same amount of password-hashing work, whether the account does
// not exist, the password is wrong or the account is locked, so the answer
// reveals neither.
package lockout

import (
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

// authWithPassword replaces PocketBase's own password check for every auth
// collection. It hashes the submitted password exactly once on every path,
// as PocketBase does, and on success hands over to PocketBase's standard
// response (apis.RecordAuthResponse), which applies the collection's auth
// rule, the superuser IP allow-list, MFA and login alerts.
func authWithPassword(e *core.RecordAuthWithPasswordRequestEvent) error {
	if e.Record == nil {
		dummyPasswordCheck(e.App, e.Collection)
		return refuse(e, "unknown identity")
	}

	acct := accountOf(e.Record)
	now := time.Now().UTC()

	locked, err := isLocked(e.App, acct, now)
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
		if err := recordFailure(e.App, acct, now); err != nil {
			return e.InternalServerError("", err)
		}
		return refuse(e, "wrong password")
	}

	if err := clearFailures(e.App, acct); err != nil {
		return e.InternalServerError("", err)
	}
	return apis.RecordAuthResponse(e.RequestEvent, e.Record, core.MFAMethodPassword, nil)
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

// isLocked reports whether acct has a lock that has neither expired nor
// been lifted.
func isLocked(app core.App, acct account, now time.Time) (bool, error) {
	_, err := app.FindFirstRecordByFilter(schema.LoginLocks,
		"account_collection = {:c} && account_id = {:id} && unlocked = false && locked_until > {:now}",
		dbx.Params{"c": acct.collection, "id": acct.id, "now": dateTime(now)},
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

// recordFailure counts one wrong password for acct and, at the limit,
// locks the account. It runs in one transaction, so two simultaneous wrong
// passwords cannot both miss the limit or both create a lock.
func recordFailure(app core.App, acct account, now time.Time) error {
	return audit.RunAs(app, audit.SystemActor, func(txApp core.App) error {
		db := txApp.NonconcurrentDB()
		windowStart := now.Add(-schema.LockoutWindow).UnixMilli()

		// Forget failures older than the window, for every account.
		if _, err := db.Delete(failures, dbx.NewExp("[[at]] <= {:start}", dbx.Params{"start": windowStart})).Execute(); err != nil {
			return fmt.Errorf("lockout: prune: %w", err)
		}

		// A request running alongside this one may have locked it already.
		if locked, err := isLocked(txApp, acct, now); err != nil || locked {
			return err
		}

		if _, err := db.Insert(failures, dbx.Params{
			"account_collection": acct.collection,
			"account_id":         acct.id,
			"at":                 now.UnixMilli(),
		}).Execute(); err != nil {
			return fmt.Errorf("lockout: count: %w", err)
		}

		var count int
		err := db.Select("COUNT(*)").From(failures).
			Where(dbx.HashExp{"account_collection": acct.collection, "account_id": acct.id}).
			AndWhere(dbx.NewExp("[[at]] > {:start}", dbx.Params{"start": windowStart})).
			Row(&count)
		if err != nil {
			return fmt.Errorf("lockout: count: %w", err)
		}
		if count < schema.LockoutMaxFailures {
			return nil
		}

		locks, err := txApp.FindCollectionByNameOrId(schema.LoginLocks)
		if err != nil {
			return err
		}
		lock := core.NewRecord(locks)
		lock.Set("account_collection", acct.collection)
		lock.Set("account_id", acct.id)
		lock.Set("failed_attempts", count)
		lock.Set("locked_until", dateTime(now.Add(schema.LockoutDuration)))
		if err := txApp.Save(lock); err != nil {
			return fmt.Errorf("lockout: lock: %w", err)
		}

		// The lock starts a fresh count once it ends.
		return deleteFailures(txApp, acct)
	})
}

// clearFailures forgets acct's wrong passwords after a correct one. It
// writes only when there is something to forget.
func clearFailures(app core.App, acct account) error {
	var n int
	err := app.DB().Select("COUNT(*)").From(failures).
		Where(dbx.HashExp{"account_collection": acct.collection, "account_id": acct.id}).
		Row(&n)
	if err != nil || n == 0 {
		return err
	}
	return deleteFailures(app, acct)
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

// dateTime formats t as PocketBase stores dates, so that stored dates and
// t compare correctly as text.
func dateTime(t time.Time) string {
	dt, _ := types.ParseDateTime(t)
	return dt.String()
}
