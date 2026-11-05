package obhijatra_test

import (
	"net/http"
	"strings"
	"testing"

	"ganigeorgiev.com/pocketbase/dbx"
	"ganigeorgiev.com/pocketbase/pocketbase/core"

	"github.com/obhijatra/obhijatra/server/internal/audit"
	"github.com/obhijatra/obhijatra/server/internal/schema"
	"github.com/obhijatra/obhijatra/server/internal/testutil"
)

// Nobody but a superuser writes devices through the records API, and not
// even a superuser sets the fields that decide whether a device is trusted:
// only the server's device routes and commands do.
func TestDeviceTrustFieldsAreServerOnly(t *testing.T) {
	app := testutil.NewApp(t)
	defer app.Cleanup()
	o := testutil.SeedOrg(t, app)
	su := testutil.Superuser(t, app)
	mux := serveMux(t, app)

	// The server itself (Go code) may still write every field.
	devices, _ := app.FindCollectionByNameOrId(schema.Devices)
	device := core.NewRecord(devices)
	device.Load(map[string]any{
		"field_user": o.Field1.Id, "label": "Phone 1", "status": schema.DeviceActive,
		"attestation_level": schema.AttestationSoftware, "sign_public_key": "c2lnbg==",
		"enc_public_key": "ZW5j", "org_signature": "c2ln", "expires": "2027-11-04 00:00:00.000Z",
	})
	if err := app.Save(device); err != nil {
		t.Fatalf("the server's own code must be able to write a device: %v", err)
	}

	const list = "/api/collections/devices/records"
	one := list + "/" + device.Id
	values := map[string]any{
		"field_user": o.Field2.Id, "staff_user": o.Admin.Id,
		"sign_public_key": "bmV3", "enc_public_key": "bmV3", "org_signature": "Zm9yZ2Vk",
		"status": schema.DeviceRevoked, "expires": "2099-01-01 00:00:00.000Z",
		"enrolled_by": o.Admin.Id, "approved_at": "2026-11-01 00:00:00.000Z", "first_approved_by": o.Admin.Id,
		"attestation_level": schema.AttestationHardware, "revoked_at": "2026-11-01 00:00:00.000Z",
	}
	adminToken := testutil.Token(t, o.Admin)
	testutil.Prime(t, app, o.Admin, adminToken)
	suToken := testutil.Token(t, su)
	before := auditCount(t, app)

	// An org admin cannot write devices through the records API at all.
	if status, body := call(mux, http.MethodPost, list, adminToken, map[string]any{"label": "x"}); status != http.StatusForbidden {
		t.Errorf("org admin creates a device: %d %s", status, body)
	}
	for _, change := range []map[string]any{{"label": "x"}, {"first_approved_by": o.Admin.Id}} {
		if status, body := call(mux, http.MethodPatch, one, adminToken, change); status != http.StatusForbidden {
			t.Errorf("org admin changes %v: %d %s", change, status, body)
		}
	}

	// A superuser is refused every trust field, alone.
	for _, field := range schema.DeviceTrustFields {
		v, ok := values[field]
		if !ok {
			t.Fatalf("no test value for %s", field)
		}
		status, body := call(mux, http.MethodPost, list, suToken, map[string]any{"label": "x", field: v})
		if status != 400 || !strings.Contains(body, `"`+field+`":{"code":"validation_device_field_server_only"`) {
			t.Errorf("superuser creates a device with %s: %d %s", field, status, body)
		}
		status, body = call(mux, http.MethodPatch, one, suToken, map[string]any{field: v})
		if status != 400 || !strings.Contains(body, `"`+field+`":{"code":"validation_device_field_server_only"`) {
			t.Errorf("superuser changes %s: %d %s", field, status, body)
		}
	}
	if n, _ := app.CountRecords(schema.Devices, dbx.Not(dbx.HashExp{"label": "Test device"})); n != 1 {
		t.Errorf("%d devices, want only the one the server wrote", n)
	}
	if auditCount(t, app) != before {
		t.Error("refused device writes must change nothing")
	}

	// A superuser may still rename one; sending a trust field unchanged
	// is not a change.
	status, body := call(mux, http.MethodPatch, one, suToken,
		map[string]any{"label": "Sample phone", "status": schema.DeviceActive})
	if status != 200 || !strings.Contains(body, `"label":"Sample phone"`) {
		t.Errorf("superuser renames a device: %d %s", status, body)
	}
	stored, _ := app.FindRecordById(schema.Devices, device.Id)
	if stored.GetString("org_signature") != "c2ln" || stored.GetString("status") != schema.DeviceActive {
		t.Error("the trust fields changed")
	}

	if r := mustVerify(t, app); !r.OK {
		t.Fatalf("audit chain: %+v", r)
	}
}

// A third superuser is refused, however it is created, and the refusal is
// recorded in the audit chain even though the write itself rolled back.
func TestAThirdSuperuserIsRefusedAndRecorded(t *testing.T) {
	app := testutil.NewApp(t)
	defer app.Cleanup()
	first := testutil.Superuser(t, app)
	mux := serveMux(t, app)

	superusers, _ := app.FindCollectionByNameOrId(schema.Superusers)
	newSuperuser := func(email string) *core.Record {
		r := core.NewRecord(superusers)
		r.SetEmail(email)
		r.SetPassword(testutil.Password)
		return r
	}
	if err := app.Save(newSuperuser("spare@example.org")); err != nil {
		t.Fatalf("a second superuser is allowed: %v", err)
	}

	refusals := func() []audit.Entry {
		var entries []audit.Entry
		if err := app.DB().Select("*").From(schema.Audit).
			Where(dbx.HashExp{"action": audit.ActionRefuse, "collection": schema.Superusers}).
			OrderBy("seq").All(&entries); err != nil {
			t.Fatal(err)
		}
		return entries
	}

	// Go code (as `obhijatra-server superuser create` does).
	if err := app.Save(newSuperuser("third@example.org")); err == nil || !strings.Contains(err.Error(), "already has 2 superusers") {
		t.Errorf("a third superuser from Go code: %v", err)
	}
	if r := refusals(); len(r) != 1 || r[0].ActorCollection != audit.SystemActor.Collection {
		t.Errorf("refusal from Go code not recorded as the server's: %+v", r)
	}

	// The API (and so the Dashboard), as a superuser.
	status, body := call(mux, http.MethodPost, "/api/collections/_superusers/records", testutil.Token(t, first),
		map[string]any{"email": "third@example.org", "password": testutil.Password, "passwordConfirm": testutil.Password})
	if status != 400 || !strings.Contains(body, "already has 2 superusers") {
		t.Errorf("a third superuser through the API: %d %s", status, body)
	}
	r := refusals()
	if len(r) != 2 || r[1].Actor != first.Id || r[1].ActorCollection != schema.Superusers {
		t.Errorf("refusal through the API not recorded under the superuser's name: %+v", r)
	}

	if n, _ := app.CountRecords(schema.Superusers); n != schema.MaxSuperusers {
		t.Errorf("%d superusers, want %d", n, schema.MaxSuperusers)
	}
	if v := mustVerify(t, app); !v.OK {
		t.Fatalf("audit chain: %+v", v)
	}
}
