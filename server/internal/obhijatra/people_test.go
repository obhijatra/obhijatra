package obhijatra_test

import (
	"encoding/json"
	"net/http"
	"strings"
	"testing"

	"ganigeorgiev.com/pocketbase/pocketbase/core"
	"ganigeorgiev.com/pocketbase/pocketbase/tools/hook"

	"github.com/obhijatra/obhijatra/server/internal/api"
	"github.com/obhijatra/obhijatra/server/internal/audit"
	"github.com/obhijatra/obhijatra/server/internal/schema"
	"github.com/obhijatra/obhijatra/server/internal/testutil"
)

const oneTimePassword = "kfmw-tqzp-hrvx"

func tokenOf(t *testing.T, body string) string {
	t.Helper()
	var auth struct {
		Token string `json:"token"`
	}
	if err := json.Unmarshal([]byte(body), &auth); err != nil || auth.Token == "" {
		t.Fatalf("no token in %s", body)
	}
	return auth.Token
}

// An org admin adds a field officer with a one-time password; the officer
// can do nothing but choose a new password, and then works normally.
func TestOneTimePasswordMustBeChangedFirst(t *testing.T) {
	app := testutil.NewApp(t)
	defer app.Cleanup()
	o := testutil.SeedOrg(t, app)
	mux := serveMux(t, app)

	status, body := call(mux, http.MethodPost, "/api/collections/field_users/records", testutil.Token(t, o.Admin), map[string]any{
		"name": "Nasrin Akter", "email": "nasrin@example.org", "role": schema.RoleFieldOfficer,
		"location": o.Branch1.Id, "active": true, "verified": true,
		"password": oneTimePassword, "passwordConfirm": oneTimePassword, schema.MustChangePassword: true,
	})
	if status != http.StatusOK {
		t.Fatalf("admin adds a person: %d %s", status, body)
	}
	id := idOf(t, body)

	status, body = signIn(mux, schema.FieldUsers, "nasrin@example.org", oneTimePassword)
	if status != http.StatusOK || !strings.Contains(body, `"`+schema.MustChangePassword+`":true`) {
		t.Fatalf("sign in with the one-time password: %d %s", status, body)
	}
	token := tokenOf(t, body)

	// Everything else is refused, with a reason the apps understand.
	for _, c := range []struct{ method, url string }{
		{http.MethodGet, "/api/collections/forms/records"},
		{http.MethodGet, "/api/collections/locations/records"},
		{http.MethodGet, "/api/realtime"},
		{http.MethodGet, "/api/collections/staff_users/records/" + o.Admin.Id},
		{http.MethodGet, "/api/collections/field_users/records/" + o.Peer1.Id},
	} {
		status, body := call(mux, c.method, c.url, token, nil)
		if status != http.StatusForbidden || !strings.Contains(body, `"code":"`+api.ReasonPasswordChangeRequired+`"`) {
			t.Errorf("%s %s: %d %s", c.method, c.url, status, body)
		}
	}
	// Reading your own account and the public checks still work.
	for _, url := range []string{"/api/collections/field_users/records/" + id, "/api/obhijatra/v1/meta", "/api/obhijatra/v1/signin/methods"} {
		if status, body := call(mux, http.MethodGet, url, token, nil); status != http.StatusOK {
			t.Errorf("GET %s: %d %s", url, status, body)
		}
	}
	// Clearing the flag, or changing anything else, is refused.
	for _, b := range []map[string]any{
		{schema.MustChangePassword: false},
		{"name": "Someone else"},
		{"password": "a-new-password-1", "passwordConfirm": "a-new-password-1", "oldPassword": oneTimePassword, "name": "x"},
	} {
		if status, body := call(mux, http.MethodPatch, "/api/collections/field_users/records/"+id, token, b); status == http.StatusOK {
			t.Errorf("PATCH %v was allowed: %s", b, body)
		}
	}

	// Choosing a new password clears the flag and ends the old session.
	status, body = call(mux, http.MethodPatch, "/api/collections/field_users/records/"+id, token, map[string]any{
		"oldPassword": oneTimePassword, "password": "my-own-password-1", "passwordConfirm": "my-own-password-1",
	})
	if status != http.StatusOK {
		t.Fatalf("change password: %d %s", status, body)
	}
	r, _ := app.FindRecordById(schema.FieldUsers, id)
	if r.GetBool(schema.MustChangePassword) {
		t.Error("the flag is still set after the person chose a password")
	}
	if status, _ := call(mux, http.MethodPost, "/api/collections/field_users/auth-refresh", token, nil); status == http.StatusOK {
		t.Error("the one-time session survived the password change")
	}
	status, body = signIn(mux, schema.FieldUsers, "nasrin@example.org", "my-own-password-1")
	if status != http.StatusOK {
		t.Fatalf("sign in with the new password: %d %s", status, body)
	}
	if status, body := call(mux, http.MethodGet, "/api/collections/forms/records", tokenOf(t, body), nil); status != http.StatusOK ||
		!strings.Contains(body, testutil.FormID) {
		t.Errorf("forms after the change: %d %s", status, body)
	}
}

func TestPeopleCannotGiveThemselvesAOneTimePasswordFlag(t *testing.T) {
	app := testutil.NewApp(t)
	defer app.Cleanup()
	o := testutil.SeedOrg(t, app)
	mux := serveMux(t, app)

	status, body := call(mux, http.MethodPatch, "/api/collections/field_users/records/"+o.Field1.Id,
		testutil.Token(t, o.Field1), map[string]any{schema.MustChangePassword: true})
	if status == http.StatusOK {
		t.Fatalf("a field user set %s on themselves: %s", schema.MustChangePassword, body)
	}
	if status, body := call(mux, http.MethodPatch, "/api/collections/field_users/records/"+o.Field1.Id,
		testutil.Token(t, o.Sup1), map[string]any{schema.MustChangePassword: true}); status == http.StatusOK {
		t.Fatalf("a supervisor set %s on a field user: %s", schema.MustChangePassword, body)
	}
}

func TestAdminResetGivesANewOneTimePasswordAndEndsSessions(t *testing.T) {
	app := testutil.NewApp(t)
	defer app.Cleanup()
	o := testutil.SeedOrg(t, app)
	mux := serveMux(t, app)

	old := testutil.Token(t, o.Field1)
	status, body := call(mux, http.MethodPatch, "/api/collections/field_users/records/"+o.Field1.Id, testutil.Token(t, o.Admin), map[string]any{
		"password": oneTimePassword, "passwordConfirm": oneTimePassword, schema.MustChangePassword: true,
	})
	if status != http.StatusOK {
		t.Fatalf("admin resets the password: %d %s", status, body)
	}
	if status, _ := call(mux, http.MethodPost, "/api/collections/field_users/auth-refresh", old, nil); status == http.StatusOK {
		t.Error("the old session survived a password reset")
	}
	r, _ := app.FindRecordById(schema.FieldUsers, o.Field1.Id)
	if !r.GetBool(schema.MustChangePassword) {
		t.Error("the admin's one-time password did not stay one-time")
	}
}

func TestOneTimePasswordNeedsAnEmail(t *testing.T) {
	app := testutil.NewApp(t)
	defer app.Cleanup()
	o := testutil.SeedOrg(t, app)

	c, _ := app.FindCollectionByNameOrId(schema.FieldUsers)
	r := core.NewRecord(c)
	r.Set("phone", "+8801755555555")
	r.SetPassword(oneTimePassword)
	r.Set("role", schema.RoleFieldOfficer)
	r.Set("location", o.Branch1.Id)
	r.Set("active", true)
	r.Set(schema.MustChangePassword, true)
	if err := app.Save(r); err == nil {
		t.Fatal("a one-time password was given to an account with no email address")
	}
}

func TestTheLastOrgAdminCannotBeRemoved(t *testing.T) {
	app := testutil.NewApp(t)
	defer app.Cleanup()
	o := testutil.SeedOrg(t, app)
	mux := serveMux(t, app)
	adminToken := testutil.Token(t, o.Admin)

	for _, change := range []map[string]any{{"role": schema.RoleSupervisor}, {"active": false}} {
		status, body := call(mux, http.MethodPatch, "/api/collections/staff_users/records/"+o.Admin.Id, adminToken, change)
		if status != http.StatusBadRequest || !strings.Contains(body, "only active organisation admin") {
			t.Errorf("the only org admin changed %v: %d %s", change, status, body)
		}
	}

	// With a second org admin, the first may step down.
	second := testutil.User(t, app, schema.StaffUsers, "admin2@example.org", schema.RoleOrgAdmin, o.Root, true)
	status, body := call(mux, http.MethodPatch, "/api/collections/staff_users/records/"+o.Admin.Id,
		testutil.Token(t, second), map[string]any{"role": schema.RoleSupervisor})
	if status != http.StatusOK {
		t.Fatalf("stepping down with another admin: %d %s", status, body)
	}
}

// ---------------------------------------------------------------------
// Findings of the security review (6 November 2026)
// ---------------------------------------------------------------------

func TestOneTimeSessionCannotExpandRelatedRecords(t *testing.T) {
	app := testutil.NewApp(t)
	defer app.Cleanup()
	o := testutil.SeedOrg(t, app)
	mux := serveMux(t, app)
	testutil.Submission(t, app, o, o.Field1, "uuid:expand-1")

	f, _ := app.FindRecordById(schema.FieldUsers, o.Field1.Id)
	f.SetPassword(oneTimePassword)
	f.Set(schema.MustChangePassword, true)
	if err := app.Save(f); err != nil {
		t.Fatal(err)
	}
	_, body := signIn(mux, schema.FieldUsers, "field1@example.org", oneTimePassword)
	token := tokenOf(t, body)

	for _, c := range []struct{ method, url string }{
		{http.MethodGet, "/api/collections/field_users/records/" + o.Field1.Id + "?expand=location,submissions_via_submitted_by"},
		{http.MethodPost, "/api/collections/field_users/auth-refresh?expand=location"},
	} {
		status, body := call(mux, c.method, c.url, token, nil)
		if status != http.StatusForbidden || strings.Contains(body, "uuid:expand-1") {
			t.Errorf("%s %s: %d %s", c.method, c.url, status, body)
		}
	}
}

// changeDuring runs change (as org admin A) after the request for record
// id has been loaded and before its write, as a second admin's request
// arriving at that moment would.
func changeDuring(t *testing.T, app core.App, admin *core.Record, id string, change func(r *core.Record)) {
	fired := false
	app.OnRecordUpdateRequest(schema.StaffUsers, schema.FieldUsers).Bind(&hook.Handler[*core.RecordRequestEvent]{
		Priority: -2000, // before the request's own transaction
		Func: func(e *core.RecordRequestEvent) error {
			if !fired && e.Record.Id == id {
				fired = true
				err := audit.RunAs(app, audit.Actor{Collection: schema.StaffUsers, ID: admin.Id, Role: schema.RoleOrgAdmin},
					func(tx core.App) error {
						r, err := tx.FindRecordById(e.Record.Collection(), id)
						if err != nil {
							return err
						}
						change(r)
						return tx.Save(r)
					})
				if err != nil {
					t.Fatalf("the other admin's change: %v", err)
				}
			}
			return e.Next()
		},
	})
}

func TestARequestUnderWayCannotUndoAnAdminsChange(t *testing.T) {
	app := testutil.NewApp(t)
	defer app.Cleanup()
	o := testutil.SeedOrg(t, app)
	b := testutil.User(t, app, schema.StaffUsers, "admin2@example.org", schema.RoleOrgAdmin, o.Root, true)
	mux := serveMux(t, app)
	bToken := testutil.Token(t, b)

	// A demotes B while B's harmless rename is under way.
	changeDuring(t, app, o.Admin, b.Id, func(r *core.Record) { r.Set("role", schema.RoleSupervisor) })
	status, body := call(mux, http.MethodPatch, "/api/collections/staff_users/records/"+b.Id, bToken, map[string]any{"name": "B renamed"})
	if status != http.StatusConflict {
		t.Errorf("the stale rename: %d %s", status, body)
	}
	if r, _ := app.FindRecordById(schema.StaffUsers, b.Id); r.GetString("role") != schema.RoleSupervisor {
		t.Errorf("the demotion was undone: role %s", r.GetString("role"))
	}
}

func TestARequestUnderWayCannotUndoAReset(t *testing.T) {
	app := testutil.NewApp(t)
	defer app.Cleanup()
	o := testutil.SeedOrg(t, app)
	b := testutil.User(t, app, schema.StaffUsers, "admin2@example.org", schema.RoleOrgAdmin, o.Root, true)
	mux := serveMux(t, app)
	stolen := testutil.Token(t, b)

	changeDuring(t, app, o.Admin, b.Id, func(r *core.Record) {
		r.SetPassword(oneTimePassword)
		r.Set(schema.MustChangePassword, true)
	})
	if status, body := call(mux, http.MethodPatch, "/api/collections/staff_users/records/"+b.Id, stolen, map[string]any{"name": "x"}); status != http.StatusConflict {
		t.Errorf("the stale write: %d %s", status, body)
	}
	if status, _ := call(mux, http.MethodPost, "/api/collections/staff_users/auth-refresh", stolen, nil); status == http.StatusOK {
		t.Error("the stolen session works again after the reset")
	}
	if r, _ := app.FindRecordById(schema.StaffUsers, b.Id); !r.GetBool(schema.MustChangePassword) {
		t.Error("the reset was undone")
	}
}

func TestAdminsProveTheirCurrentPasswordToChangeIt(t *testing.T) {
	app := testutil.NewApp(t)
	defer app.Cleanup()
	o := testutil.SeedOrg(t, app)
	mux := serveMux(t, app)
	url := "/api/collections/staff_users/records/" + o.Admin.Id

	for _, b := range []map[string]any{
		{"password": "a-new-password-1", "passwordConfirm": "a-new-password-1"},
		{"password": "a-new-password-1", "passwordConfirm": "a-new-password-1", "oldPassword": "not-the-password"},
	} {
		if status, body := call(mux, http.MethodPatch, url, testutil.Token(t, o.Admin), b); status != http.StatusBadRequest ||
			!strings.Contains(body, "oldPassword") {
			t.Errorf("without the right current password: %d %s", status, body)
		}
	}
	if status, body := call(mux, http.MethodPatch, url, testutil.Token(t, o.Admin), map[string]any{
		"password": "a-new-password-1", "passwordConfirm": "a-new-password-1", "oldPassword": testutil.Password,
	}); status != http.StatusOK {
		t.Errorf("with the current password: %d %s", status, body)
	}
}

func TestNobodyGivesThemselvesAOneTimePasswordOrKeepsIt(t *testing.T) {
	app := testutil.NewApp(t)
	defer app.Cleanup()
	o := testutil.SeedOrg(t, app)
	mux := serveMux(t, app)

	status, body := call(mux, http.MethodPatch, "/api/collections/staff_users/records/"+o.Admin.Id, testutil.Token(t, o.Admin), map[string]any{
		"password": oneTimePassword, "passwordConfirm": oneTimePassword, "oldPassword": testutil.Password, schema.MustChangePassword: true,
	})
	if status != http.StatusBadRequest {
		t.Errorf("an admin gave themselves a one-time password: %d %s", status, body)
	}

	// Keeping the one-time password as the "new" one is refused.
	f, _ := app.FindRecordById(schema.FieldUsers, o.Field1.Id)
	f.SetPassword(oneTimePassword)
	f.Set(schema.MustChangePassword, true)
	if err := app.Save(f); err != nil {
		t.Fatal(err)
	}
	_, body = signIn(mux, schema.FieldUsers, "field1@example.org", oneTimePassword)
	status, body = call(mux, http.MethodPatch, "/api/collections/field_users/records/"+o.Field1.Id, tokenOf(t, body), map[string]any{
		"oldPassword": oneTimePassword, "password": oneTimePassword, "passwordConfirm": oneTimePassword,
	})
	if status != http.StatusBadRequest {
		t.Errorf("the one-time password was kept as the new one: %d %s", status, body)
	}
}

func TestSettingOnlyTheFlagEndsSessions(t *testing.T) {
	app := testutil.NewApp(t)
	defer app.Cleanup()
	o := testutil.SeedOrg(t, app)
	mux := serveMux(t, app)
	old := testutil.Token(t, o.Field1)

	if status, body := call(mux, http.MethodPatch, "/api/collections/field_users/records/"+o.Field1.Id, testutil.Token(t, o.Admin),
		map[string]any{schema.MustChangePassword: true}); status != http.StatusOK {
		t.Fatalf("set the flag: %d %s", status, body)
	}
	if status, _ := call(mux, http.MethodPost, "/api/collections/field_users/auth-refresh", old, nil); status == http.StatusOK {
		t.Error("an existing session survived the flag")
	}
}

func TestTheLastOrgAdminCannotBeDeleted(t *testing.T) {
	app := testutil.NewApp(t)
	defer app.Cleanup()
	o := testutil.SeedOrg(t, app)

	err := audit.RunAs(app, audit.Actor{Collection: schema.Superusers, ID: "su"}, func(tx core.App) error {
		r, err := tx.FindRecordById(schema.StaffUsers, o.Admin.Id)
		if err != nil {
			return err
		}
		return tx.Delete(r)
	})
	if err == nil {
		t.Fatal("the only org admin was deleted")
	}
}
