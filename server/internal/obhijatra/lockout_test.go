package obhijatra_test

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"net/http/httptest"
	"strings"
	"sync"
	"testing"
	"time"

	"ganigeorgiev.com/pocketbase/dbx"
	"ganigeorgiev.com/pocketbase/pocketbase/apis"
	"ganigeorgiev.com/pocketbase/pocketbase/core"
	"ganigeorgiev.com/pocketbase/pocketbase/tests"

	"github.com/obhijatra/obhijatra/server/internal/audit"
	"github.com/obhijatra/obhijatra/server/internal/lockout"
	"github.com/obhijatra/obhijatra/server/internal/obhijatra"
	"github.com/obhijatra/obhijatra/server/internal/schema"
	"github.com/obhijatra/obhijatra/server/internal/testutil"
)

const wrongPassword = "not-the-password-1"

// serveMux returns app's HTTP handler with Obhijatra's routes bound, for
// tests that need raw responses.
func serveMux(t testing.TB, app core.App) http.Handler {
	t.Helper()
	router, err := apis.NewRouter(app)
	if err != nil {
		t.Fatal(err)
	}
	var mux http.Handler
	err = app.OnServe().Trigger(&core.ServeEvent{App: app, Router: router}, func(e *core.ServeEvent) error {
		mux, err = e.Router.BuildMux()
		return err
	})
	if err != nil {
		t.Fatal(err)
	}
	return mux
}

// defaultIP is the address httptest requests come from.
const defaultIP = "192.0.2.1"

// call sends one request from defaultIP and returns the status and raw
// body.
func call(mux http.Handler, method, url, token string, body any) (int, string) {
	return callFrom(mux, defaultIP, method, url, token, body)
}

// callFrom sends one request from the IP address ip.
func callFrom(mux http.Handler, ip, method, url, token string, body any) (int, string) {
	var r *http.Request
	if body == nil {
		r = httptest.NewRequest(method, url, nil)
	} else {
		raw, _ := json.Marshal(body)
		r = httptest.NewRequest(method, url, bytes.NewReader(raw))
		r.Header.Set("Content-Type", "application/json")
	}
	if token != "" {
		r.Header.Set("Authorization", token)
	}
	r.RemoteAddr = ip + ":40000"
	w := httptest.NewRecorder()
	mux.ServeHTTP(w, r)
	return w.Code, w.Body.String()
}

func signIn(mux http.Handler, collection, email, password string) (int, string) {
	return signInFrom(mux, defaultIP, collection, email, password)
}

func signInFrom(mux http.Handler, ip, collection, email, password string) (int, string) {
	return callFrom(mux, ip, http.MethodPost, "/api/collections/"+collection+"/auth-with-password", "",
		map[string]string{"identity": email, "password": password})
}

func activeLocks(t testing.TB, app core.App, r *core.Record) []*core.Record {
	t.Helper()
	locks, err := app.FindRecordsByFilter(schema.LoginLocks,
		"account_collection = {:c} && account_id = {:id} && unlocked = false && locked_until > @now",
		"", 0, 0, dbx.Params{"c": r.Collection().Name, "id": r.Id})
	if err != nil {
		t.Fatal(err)
	}
	return locks
}

func auditEntry(t testing.TB, app core.App, action, collection, recordID string) (audit.Entry, bool) {
	t.Helper()
	var e audit.Entry
	err := app.DB().Select("*").From(schema.Audit).
		Where(dbx.HashExp{"action": action, "collection": collection, "record_id": recordID}).One(&e)
	return e, err == nil
}

// restart opens the same data in a fresh server process, as a restart
// does.
func restart(t testing.TB, app *tests.TestApp) *tests.TestApp {
	t.Helper()
	if _, err := app.DB().NewQuery("PRAGMA wal_checkpoint(TRUNCATE)").Execute(); err != nil {
		t.Fatal(err)
	}
	again, err := tests.NewTestApp(app.DataDir())
	if err != nil {
		t.Fatal(err)
	}
	obhijatra.Register(again)
	return again
}

func TestTenWrongPasswordsLockTheAccount(t *testing.T) {
	app := testutil.NewApp(t)
	defer app.Cleanup()
	o := testutil.SeedOrg(t, app)
	mux := serveMux(t, app)
	const staff = schema.StaffUsers

	// 1. Ten wrong passwords: every refusal is the same plain answer, and
	// the tenth locks the account.
	var refusal string
	for i := 1; i <= schema.LockoutMaxFailures; i++ {
		status, body := signIn(mux, staff, "sup1@example.org", wrongPassword)
		if status != 400 {
			t.Fatalf("wrong password %d: status %d", i, status)
		}
		if i == 1 {
			refusal = body
		} else if body != refusal {
			t.Fatalf("wrong password %d answered differently:\n%s\n%s", i, body, refusal)
		}
		if locks := activeLocks(t, app, o.Sup1); (len(locks) == 1) != (i == schema.LockoutMaxFailures) {
			t.Fatalf("after %d wrong passwords: %d locks", i, len(locks))
		}
	}
	if !strings.Contains(refusal, lockout.FailureMessage) || strings.Contains(refusal, "sup1") {
		t.Errorf("refusal is not the plain message: %s", refusal)
	}

	lock := activeLocks(t, app, o.Sup1)[0]
	until := lock.GetDateTime("locked_until").Time()
	if want := time.Now().Add(schema.LockoutDuration); until.Before(want.Add(-time.Minute)) || until.After(want.Add(time.Minute)) {
		t.Errorf("locked_until %s, want about %s", until, want)
	}
	if lock.GetInt("failed_attempts") != schema.LockoutMaxFailures || lock.GetString("ip") != defaultIP {
		t.Errorf("failed_attempts %d, ip %q; want %d from %s", lock.GetInt("failed_attempts"), lock.GetString("ip"),
			schema.LockoutMaxFailures, defaultIP)
	}

	// 2. The right password is refused while locked, with the same answer
	// as an unknown account or a wrong password for another account.
	for name, try := range map[string][3]string{
		"right password, locked account":         {staff, "sup1@example.org", testutil.Password},
		"account that does not exist":            {staff, "nobody@example.org", wrongPassword},
		"wrong password, other account":          {staff, "sup2@example.org", wrongPassword},
		"field user account that does not exist": {schema.FieldUsers, "nobody@example.org", wrongPassword},
	} {
		if status, body := signIn(mux, try[0], try[1], try[2]); status != 400 || body != refusal {
			t.Errorf("%s: %d %s; want the same 400 as every refusal", name, status, body)
		}
	}

	// 3. Other accounts are unaffected.
	if status, body := signIn(mux, staff, "sup2@example.org", testutil.Password); status != 200 {
		t.Errorf("another account must still sign in: %d %s", status, body)
	}

	// 4. The lock is in the audit chain, written by the server.
	if e, ok := auditEntry(t, app, audit.ActionCreate, schema.LoginLocks, lock.Id); !ok || e.ActorCollection != audit.SystemActor.Collection {
		t.Errorf("no audit entry for the lock by the server: %+v", e)
	}

	// 5. A restart does not lift it.
	again := restart(t, app)
	defer again.Cleanup()
	if status, _ := signIn(serveMux(t, again), staff, "sup1@example.org", testutil.Password); status != 400 {
		t.Errorf("after a restart the account must still be locked, got %d", status)
	}

	// 6. Only an org admin may unlock early, and only by unlocking.
	lockURL := "/api/collections/login_locks/records/" + lock.Id
	for name, c := range map[string]struct {
		who    *core.Record
		body   map[string]any
		status int
	}{
		"a supervisor cannot unlock":                    {o.Sup2, map[string]any{"unlocked": true}, 404},
		"a field user cannot unlock":                    {o.Field1, map[string]any{"unlocked": true}, 404},
		"an org admin cannot shorten the lock":          {o.Admin, map[string]any{"locked_until": "2026-01-01 00:00:00.000Z"}, 404},
		"an org admin cannot change it while unlocking": {o.Admin, map[string]any{"unlocked": true, "account_id": o.Sup2.Id}, 400},
	} {
		if status, body := call(mux, http.MethodPatch, lockURL, testutil.Token(t, c.who), c.body); status != c.status {
			t.Errorf("%s: %d %s, want %d", name, status, body, c.status)
		}
	}
	if status, body := call(mux, http.MethodGet, "/api/collections/login_locks/records", testutil.Token(t, o.Sup2), nil); status != 200 || !strings.Contains(body, `"totalItems":0`) {
		t.Errorf("a supervisor must not see login locks: %d %s", status, body)
	}

	status, body := call(mux, http.MethodPatch, lockURL, testutil.Token(t, o.Admin), map[string]any{"unlocked": true})
	if status != 200 || !strings.Contains(body, `"unlocked":true`) || !strings.Contains(body, `"unlocked_by":"`+o.Admin.Id+`"`) {
		t.Fatalf("org admin unlock: %d %s", status, body)
	}
	if e, ok := auditEntry(t, app, audit.ActionUpdate, schema.LoginLocks, lock.Id); !ok || e.Actor != o.Admin.Id {
		t.Errorf("no audit entry for the unlock by the org admin: %+v", e)
	}
	if status, body := signIn(mux, staff, "sup1@example.org", testutil.Password); status != 200 {
		t.Errorf("after the unlock the right password must work: %d %s", status, body)
	}

	// 7. A lock is kept as history: no second unlock, no delete, even by a
	// superuser.
	if status, _ := call(mux, http.MethodPatch, lockURL, testutil.Token(t, o.Admin), map[string]any{"unlocked": true}); status != 400 {
		t.Errorf("a second unlock must be refused, got %d", status)
	}
	su := testutil.Superuser(t, app)
	if status, _ := call(mux, http.MethodDelete, lockURL, testutil.Token(t, su), nil); status != 400 {
		t.Errorf("a superuser must not delete a lock, got %d", status)
	}
	if status, _ := call(mux, http.MethodPatch, lockURL, testutil.Token(t, su), map[string]any{"unlocked": false}); status != 400 {
		t.Errorf("a superuser must not re-lock by editing, got %d", status)
	}

	if r := mustVerify(t, app); !r.OK {
		t.Fatalf("audit chain: %+v", r)
	}
}

func TestLockoutCountsOnlyRecentConsecutiveFailures(t *testing.T) {
	app := testutil.NewApp(t)
	defer app.Cleanup()
	o := testutil.SeedOrg(t, app)
	mux := serveMux(t, app)
	const field = schema.FieldUsers

	wrong := func(n int, email string) {
		t.Helper()
		for range n {
			if status, _ := signIn(mux, field, email, wrongPassword); status != 400 {
				t.Fatalf("wrong password: status %d", status)
			}
		}
	}
	locked := func(r *core.Record) bool { return len(activeLocks(t, app, r)) > 0 }

	// Failures older than the 15-minute window do not count.
	old := time.Now().Add(-schema.LockoutWindow - time.Minute).UnixMilli()
	for range schema.LockoutMaxFailures - 1 {
		exec(t, app, "INSERT INTO "+schema.LoginFailuresTable+" (account_collection, account_id, at) VALUES ({:c}, {:id}, {:at})",
			dbx.Params{"c": field, "id": o.Field1.Id, "at": old})
	}
	wrong(schema.LockoutMaxFailures-1, "field1@example.org")
	if locked(o.Field1) {
		t.Fatal("failures older than the window were counted")
	}
	wrong(1, "field1@example.org")
	if !locked(o.Field1) {
		t.Fatal("ten failures within the window must lock the account")
	}

	// The lock ends by itself after 15 minutes.
	exec(t, app, "UPDATE login_locks SET locked_until = {:past} WHERE account_id = {:id}",
		dbx.Params{"past": "2026-01-01 00:00:00.000Z", "id": o.Field1.Id})
	if status, body := signIn(mux, field, "field1@example.org", testutil.Password); status != 200 {
		t.Fatalf("an expired lock must not refuse the right password: %d %s", status, body)
	}

	// A correct password starts the count again.
	wrong(schema.LockoutMaxFailures-1, "peer1@example.org")
	if status, _ := signIn(mux, field, "peer1@example.org", testutil.Password); status != 200 {
		t.Fatal("the right password must work before the limit")
	}
	wrong(schema.LockoutMaxFailures-1, "peer1@example.org")
	if locked(o.Peer1) {
		t.Fatal("a correct password must reset the count")
	}

	// Failures before and after a restart count together.
	wrong(5, "field2@example.org")
	again := restart(t, app)
	defer again.Cleanup()
	againMux := serveMux(t, again)
	for range schema.LockoutMaxFailures - 5 {
		signIn(againMux, field, "field2@example.org", wrongPassword)
	}
	if len(activeLocks(t, again, o.Field2)) != 1 {
		t.Fatal("failures before a restart must still count after it")
	}

	// Superusers are protected the same way.
	su := testutil.Superuser(t, app)
	for range schema.LockoutMaxFailures {
		signIn(mux, schema.Superusers, "root@example.org", wrongPassword)
	}
	if status, _ := signIn(mux, schema.Superusers, "root@example.org", testutil.Password); status != 400 || !locked(su) {
		t.Errorf("a superuser must be locked after ten wrong passwords too, got %d", status)
	}

	if r := mustVerify(t, app); !r.OK {
		t.Fatalf("audit chain: %+v", r)
	}
}

// Wrong passwords arriving at the same moment are counted exactly: one
// lock, never two, and never a missed one.
func TestSimultaneousWrongPasswordsMakeOneLock(t *testing.T) {
	app := testutil.NewApp(t)
	defer app.Cleanup()
	o := testutil.SeedOrg(t, app)
	mux := serveMux(t, app)

	const attempts = 3 * schema.LockoutMaxFailures
	var wg sync.WaitGroup
	statuses := make(chan int, attempts)
	for range attempts {
		wg.Add(1)
		go func() {
			defer wg.Done()
			status, _ := signIn(mux, schema.FieldUsers, "field1@example.org", wrongPassword)
			statuses <- status
		}()
	}
	wg.Wait()
	close(statuses)

	for status := range statuses {
		if status != 400 {
			t.Errorf("a wrong password got %d, want 400", status)
		}
	}
	n, err := app.CountRecords(schema.LoginLocks, dbx.HashExp{"account_id": o.Field1.Id})
	if err != nil || n != 1 {
		t.Errorf("%d locks for one burst of wrong passwords, want 1", n)
	}
	if r := mustVerify(t, app); !r.OK {
		t.Fatalf("audit chain: %+v", r)
	}
}

// A deactivated account with the right password gets the same plain 400
// as every other refused sign-in (PocketBase alone would answer 403, which
// tells a stranger the password was right), and it counts as a wrong
// password.
func TestDeactivatedAccountGetsTheUniformRefusal(t *testing.T) {
	app := testutil.NewApp(t)
	defer app.Cleanup()
	o := testutil.SeedOrg(t, app)
	mux := serveMux(t, app)

	_, refusal := signIn(mux, schema.FieldUsers, "nobody@example.org", wrongPassword)
	for i := 1; i <= schema.LockoutMaxFailures; i++ {
		status, body := signIn(mux, schema.FieldUsers, "gone1@example.org", testutil.Password)
		if status != 400 || body != refusal {
			t.Fatalf("deactivated account, right password, attempt %d: %d %s; want the uniform 400 %s", i, status, body, refusal)
		}
	}
	if len(activeLocks(t, app, o.Gone1)) != 1 {
		t.Error("ten sign-ins to a deactivated account must count like ten wrong passwords and lock it")
	}

	// A deactivated staff user, likewise; reactivated, it signs in.
	staff := testutil.User(t, app, schema.StaffUsers, "former@example.org", schema.RoleSupervisor, o.Branch1, false)
	if status, body := signIn(mux, schema.StaffUsers, "former@example.org", testutil.Password); status != 400 || body != refusal {
		t.Errorf("deactivated staff user: %d %s", status, body)
	}
	staff.Set("active", true)
	if err := app.Save(staff); err != nil {
		t.Fatal(err)
	}
	if status, body := signIn(mux, schema.StaffUsers, "former@example.org", testutil.Password); status != 200 {
		t.Errorf("reactivated staff user: %d %s", status, body)
	}

	if r := mustVerify(t, app); !r.OK {
		t.Fatalf("audit chain: %+v", r)
	}
}

// Ten wrong passwords from one address lock the account for that address
// only: the person signing in from their own office is not locked out.
func TestLockIsPerAccountAndAddress(t *testing.T) {
	app := testutil.NewApp(t)
	defer app.Cleanup()
	o := testutil.SeedOrg(t, app)
	mux := serveMux(t, app)
	const attacker, office = "203.0.113.66", "198.51.100.20"

	for range schema.LockoutMaxFailures {
		signInFrom(mux, attacker, schema.StaffUsers, "sup1@example.org", wrongPassword)
	}
	locks := activeLocks(t, app, o.Sup1)
	if len(locks) != 1 || locks[0].GetString("ip") != attacker {
		t.Fatalf("want one lock for %s, got %d", attacker, len(locks))
	}
	if status, _ := signInFrom(mux, attacker, schema.StaffUsers, "sup1@example.org", testutil.Password); status != 400 {
		t.Errorf("the locked address must be refused, got %d", status)
	}
	if status, body := signInFrom(mux, office, schema.StaffUsers, "sup1@example.org", testutil.Password); status != 200 {
		t.Errorf("another address must still sign in: %d %s", status, body)
	}

	// A correct password clears only its own address's count.
	for range schema.LockoutMaxFailures - 1 {
		signInFrom(mux, office, schema.StaffUsers, "sup2@example.org", wrongPassword)
	}
	signInFrom(mux, "198.51.100.21", schema.StaffUsers, "sup2@example.org", testutil.Password)
	signInFrom(mux, office, schema.StaffUsers, "sup2@example.org", wrongPassword)
	if len(activeLocks(t, app, o.Sup2)) != 1 {
		t.Error("a correct password from elsewhere must not clear this address's count")
	}
}

// 30 wrong passwords from all addresses together lock an ordinary account
// everywhere, so many addresses cannot guess without limit.
func TestAccountWideLimitLocksAnOrdinaryAccount(t *testing.T) {
	app := testutil.NewApp(t)
	defer app.Cleanup()
	o := testutil.SeedOrg(t, app)
	mux := serveMux(t, app)
	slept := recordSleeps(t)

	addresses := schema.AccountMaxFailures / schema.LockoutMaxFailures
	for i := range addresses {
		ip := fmt.Sprintf("203.0.113.%d", 10+i)
		for range schema.LockoutMaxFailures {
			if status, _ := signInFrom(mux, ip, schema.FieldUsers, "field1@example.org", wrongPassword); status != 400 {
				t.Fatalf("wrong password: %d", status)
			}
		}
	}

	var everywhere *core.Record
	for _, l := range activeLocks(t, app, o.Field1) {
		if l.GetString("ip") == "" {
			everywhere = l
		}
	}
	if everywhere == nil || everywhere.GetInt("failed_attempts") != schema.AccountMaxFailures {
		t.Fatalf("want an account-wide lock after %d wrong passwords", schema.AccountMaxFailures)
	}
	if status, _ := signInFrom(mux, "198.51.100.99", schema.FieldUsers, "field1@example.org", testutil.Password); status != 400 {
		t.Errorf("an account-wide lock must refuse every address, got %d", status)
	}
	if len(*slept) != 0 {
		t.Errorf("an ordinary account is locked, never slowed: waits %v", *slept)
	}
}

// An org admin or a superuser is never locked for every address: past the
// account-wide limit each attempt waits, longer and longer up to a cap,
// and the right password still works.
func TestPrivilegedAccountsAreSlowedNotLocked(t *testing.T) {
	app := testutil.NewApp(t)
	defer app.Cleanup()
	o := testutil.SeedOrg(t, app)
	su := testutil.Superuser(t, app)
	mux := serveMux(t, app)

	for _, c := range []struct {
		collection, email string
		record            *core.Record
	}{
		{schema.StaffUsers, "admin@example.org", o.Admin},
		{schema.Superusers, "root@example.org", su},
	} {
		t.Run(c.collection, func(t *testing.T) {
			slept := recordSleeps(t)
			const addresses = 4 // 40 wrong passwords, 10 past the limit
			for i := range addresses {
				ip := fmt.Sprintf("203.0.113.%d", 20+i)
				for range schema.LockoutMaxFailures {
					signInFrom(mux, ip, c.collection, c.email, wrongPassword)
				}
			}

			locks := activeLocks(t, app, c.record)
			if len(locks) != addresses {
				t.Errorf("%d locks, want one per attacking address (%d)", len(locks), addresses)
			}
			for _, l := range locks {
				if l.GetString("ip") == "" {
					t.Error("a privileged account must never be locked for every address")
				}
			}

			want := []time.Duration{1, 2, 4, 8, 16, 30, 30, 30, 30, 30}
			if len(*slept) != len(want) {
				t.Fatalf("waits %v, want %d waits", *slept, len(want))
			}
			for i, d := range *slept {
				if d != want[i]*time.Second {
					t.Errorf("wait %d is %s, want %s", i+1, d, want[i]*time.Second)
				}
			}

			*slept = nil
			if status, body := signInFrom(mux, "198.51.100.30", c.collection, c.email, testutil.Password); status != 200 {
				t.Errorf("the right password from a new address must still work: %d %s", status, body)
			}
			if len(*slept) != 1 || (*slept)[0] != schema.AccountDelayMax {
				t.Errorf("the right password must wait too (so the wait reveals nothing): %v", *slept)
			}
		})
	}
}

func TestDelayGrowsToItsCap(t *testing.T) {
	for failures, want := range map[int]time.Duration{
		0: 0, schema.AccountMaxFailures - 1: 0,
		schema.AccountMaxFailures: time.Second, schema.AccountMaxFailures + 1: 2 * time.Second,
		schema.AccountMaxFailures + 4: 16 * time.Second, schema.AccountMaxFailures + 5: schema.AccountDelayMax,
		schema.AccountMaxFailures + 100: schema.AccountDelayMax,
	} {
		if got := lockout.Delay(failures); got != want {
			t.Errorf("Delay(%d) = %s, want %s", failures, got, want)
		}
	}
}

// recordSleeps makes lockout.Sleep record its waits instead of waiting,
// until the test ends.
func recordSleeps(t *testing.T) *[]time.Duration {
	t.Helper()
	var mu sync.Mutex
	slept := &[]time.Duration{}
	original := lockout.Sleep
	lockout.Sleep = func(_ context.Context, d time.Duration) {
		mu.Lock()
		defer mu.Unlock()
		*slept = append(*slept, d)
	}
	t.Cleanup(func() { lockout.Sleep = original })
	return slept
}

// Behind a reverse proxy every connection comes from the proxy; with the
// trusted proxy header set (init --trusted-proxy-header), the lock follows
// each user's own address instead.
func TestLockFollowsTheTrustedProxyHeader(t *testing.T) {
	app := testutil.NewApp(t)
	defer app.Cleanup()
	o := testutil.SeedOrg(t, app)
	s, _ := app.Settings().Clone()
	s.TrustedProxy.Headers = []string{"X-Forwarded-For"}
	if err := app.Save(s); err != nil {
		t.Fatal(err)
	}
	mux := serveMux(t, app)

	const proxy, attacker, staff = "10.0.0.2", "203.0.113.77", "198.51.100.40"
	viaProxy := func(client, password string) int {
		raw, _ := json.Marshal(map[string]string{"identity": "sup1@example.org", "password": password})
		r := httptest.NewRequest(http.MethodPost, "/api/collections/staff_users/auth-with-password", bytes.NewReader(raw))
		r.Header.Set("Content-Type", "application/json")
		r.Header.Set("X-Forwarded-For", client)
		r.RemoteAddr = proxy + ":40000"
		w := httptest.NewRecorder()
		mux.ServeHTTP(w, r)
		return w.Code
	}

	for range schema.LockoutMaxFailures {
		viaProxy(attacker, wrongPassword)
	}
	locks := activeLocks(t, app, o.Sup1)
	if len(locks) != 1 || locks[0].GetString("ip") != attacker {
		t.Fatalf("want one lock for the attacker's own address %s, got %d", attacker, len(locks))
	}
	if status := viaProxy(staff, testutil.Password); status != 200 {
		t.Errorf("a colleague behind the same proxy must still sign in, got %d", status)
	}
}
