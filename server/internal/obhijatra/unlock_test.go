package obhijatra_test

import (
	"bytes"
	"fmt"
	"strings"
	"testing"

	"ganigeorgiev.com/pocketbase/dbx"
	"ganigeorgiev.com/pocketbase/pocketbase/core"

	"github.com/obhijatra/obhijatra/server/internal/audit"
	"github.com/obhijatra/obhijatra/server/internal/cli"
	"github.com/obhijatra/obhijatra/server/internal/schema"
	"github.com/obhijatra/obhijatra/server/internal/testutil"
)

// runUnlock runs `obhijatra-server unlock <args>` against app.
func runUnlock(t testing.TB, app core.App, args ...string) (string, error) {
	t.Helper()
	cmd := cli.NewUnlockCommand(app)
	var out bytes.Buffer
	cmd.SetOut(&out)
	cmd.SetErr(&out)
	cmd.SetArgs(args)
	err := cmd.Execute()
	return out.String(), err
}

func failureCount(t testing.TB, app core.App, r *core.Record) int {
	t.Helper()
	var n int
	err := app.DB().Select("COUNT(*)").From(schema.LoginFailuresTable).
		Where(dbx.HashExp{"account_collection": r.Collection().Name, "account_id": r.Id}).Row(&n)
	if err != nil {
		t.Fatal(err)
	}
	return n
}

// A locked-out org admin is unlocked on the server itself, without another
// admin, and the unlock is in the audit chain.
func TestUnlockCommandRecoversALockedOutOrgAdmin(t *testing.T) {
	app := testutil.NewApp(t)
	defer app.Cleanup()
	o := testutil.SeedOrg(t, app)
	mux := serveMux(t, app)
	slept := recordSleeps(t)

	// Locked from two addresses and slowed down everywhere: 35 wrong
	// passwords, ten each from three addresses and five from a fourth.
	for i, n := range []int{10, 10, 10, 5} {
		for range n {
			signInFrom(mux, fmt.Sprintf("203.0.113.%d", 40+i), schema.StaffUsers, "admin@example.org", wrongPassword)
		}
	}
	locks := activeLocks(t, app, o.Admin)
	if len(locks) != 3 {
		t.Fatalf("%d locks before the unlock, want 3", len(locks))
	}

	out, err := runUnlock(t, app, "admin@example.org")
	if err != nil {
		t.Fatalf("unlock: %v\n%s", err, out)
	}
	if want := "The staff user admin@example.org is unlocked: 3 locks lifted, 35 recent wrong passwords cleared."; !strings.Contains(out, want) {
		t.Errorf("output %q, want %q", out, want)
	}
	if len(activeLocks(t, app, o.Admin)) != 0 || failureCount(t, app, o.Admin) != 0 {
		t.Error("the unlock must lift every lock and clear the count")
	}
	for _, l := range locks {
		if e, ok := auditEntry(t, app, audit.ActionUpdate, schema.LoginLocks, l.Id); !ok ||
			e.ActorCollection != cli.UnlockActor.Collection || e.Actor != cli.UnlockActor.ID {
			t.Errorf("lock %s: no audit entry by the unlock command: %+v", l.Id, e)
		}
	}

	*slept = nil
	if status, body := signInFrom(mux, "203.0.113.40", schema.StaffUsers, "admin@example.org", testutil.Password); status != 200 {
		t.Errorf("after the unlock the admin must sign in from the formerly locked address: %d %s", status, body)
	}
	if len(*slept) != 0 {
		t.Errorf("after the unlock the admin must not wait: %v", *slept)
	}

	if r := mustVerify(t, app); !r.OK {
		t.Fatalf("audit chain: %+v", r)
	}
}

// Wrong passwords without a lock are cleared too, and that is recorded.
func TestUnlockCommandClearsACountWithoutALock(t *testing.T) {
	app := testutil.NewApp(t)
	defer app.Cleanup()
	o := testutil.SeedOrg(t, app)
	mux := serveMux(t, app)

	for range schema.LockoutMaxFailures - 1 {
		signIn(mux, schema.StaffUsers, "admin@example.org", wrongPassword)
	}
	out, err := runUnlock(t, app, "admin@example.org")
	if err != nil || !strings.Contains(out, "0 locks lifted, 9 recent wrong passwords cleared") {
		t.Fatalf("unlock: %v %q", err, out)
	}
	if failureCount(t, app, o.Admin) != 0 {
		t.Error("the count must be cleared")
	}
	if e, ok := auditEntry(t, app, audit.ActionDelete, schema.LoginFailuresTable, o.Admin.Id); !ok || e.Actor != cli.UnlockActor.ID {
		t.Errorf("clearing the count must be in the audit chain: %+v", e)
	}

	// Nothing to do: nothing changes, nothing is recorded.
	before := auditCount(t, app)
	out, err = runUnlock(t, app, "sup1@example.org")
	if err != nil || !strings.Contains(out, "was not locked and had no wrong passwords. Nothing was changed.") {
		t.Errorf("unlock of an account that is not locked: %v %q", err, out)
	}
	if auditCount(t, app) != before {
		t.Error("an unlock that changes nothing must not write to the audit chain")
	}

	// No such account, or not an email address: refused, exit status 1.
	for _, arg := range []string{"nobody@example.org", "not an email"} {
		if _, err := runUnlock(t, app, arg); err == nil {
			t.Errorf("unlock %q must fail", arg)
		}
	}

	if r := mustVerify(t, app); !r.OK {
		t.Fatalf("audit chain: %+v", r)
	}
}
