package obhijatra_test

import (
	"net/http"
	"strings"
	"testing"

	"ganigeorgiev.com/pocketbase/dbx"
	"ganigeorgiev.com/pocketbase/pocketbase/core"

	"github.com/obhijatra/obhijatra/server/internal/api"
	"github.com/obhijatra/obhijatra/server/internal/audit"
	"github.com/obhijatra/obhijatra/server/internal/schema"
	"github.com/obhijatra/obhijatra/server/internal/testutil"
)

// A device's keys, organisation signature, status and expiry are never
// written through the records API, by an org admin or a superuser; only
// the server's own code (the future enrolment route) sets them.
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
		"sign_public_key": "bmV3", "enc_public_key": "bmV3", "org_signature": "Zm9yZ2Vk",
		"status": schema.DeviceRevoked, "expires": "2099-01-01 00:00:00.000Z",
	}
	before := auditCount(t, app)

	for _, who := range []struct {
		name  string
		token string
	}{
		{"org admin", testutil.Token(t, o.Admin)},
		{"superuser", testutil.Token(t, su)},
	} {
		for _, field := range schema.DeviceTrustFields {
			create := map[string]any{"field_user": o.Field1.Id, "attestation_level": schema.AttestationNone,
				"status": schema.DeviceActive, field: values[field]}
			status, body := call(mux, http.MethodPost, list, who.token, create)
			if status != 400 || !strings.Contains(body, `"`+field+`":{"code":"validation_device_field_server_only"`) {
				t.Errorf("%s creates a device with %s: %d %s", who.name, field, status, body)
			}

			status, body = call(mux, http.MethodPatch, one, who.token, map[string]any{field: values[field]})
			if status != 400 || !strings.Contains(body, `"`+field+`":{"code":"validation_device_field_server_only"`) {
				t.Errorf("%s changes %s: %d %s", who.name, field, status, body)
			}
		}

		// Without them a device cannot be created at all (status is
		// required): enrolment is the only way in.
		status, body := call(mux, http.MethodPost, list, who.token,
			map[string]any{"field_user": o.Field1.Id, "attestation_level": schema.AttestationNone})
		if status != 400 {
			t.Errorf("%s creates a device without a status: %d %s", who.name, status, body)
		}
	}
	if n, _ := app.CountRecords(schema.Devices); n != 1 {
		t.Errorf("%d devices, want only the one the server wrote", n)
	}
	if auditCount(t, app) != before {
		t.Error("refused device writes must change nothing")
	}

	// Other fields stay editable by an org admin; sending a trust field
	// unchanged is not a change.
	status, body := call(mux, http.MethodPatch, one, testutil.Token(t, o.Admin),
		map[string]any{"label": "Rahima's phone", "status": schema.DeviceActive})
	if status != 200 || !strings.Contains(body, `"label":"Rahima's phone"`) {
		t.Errorf("org admin renames a device: %d %s", status, body)
	}
	stored, _ := app.FindRecordById(schema.Devices, device.Id)
	if stored.GetString("org_signature") != "c2ln" || stored.GetString("status") != schema.DeviceActive {
		t.Error("the trust fields changed")
	}

	if r := mustVerify(t, app); !r.OK {
		t.Fatalf("audit chain: %+v", r)
	}
}

// The enrolment route exists as a placeholder and says so plainly.
func TestDeviceEnrolmentIsNotYetAvailable(t *testing.T) {
	app := testutil.NewApp(t)
	defer app.Cleanup()
	o := testutil.SeedOrg(t, app)
	mux := serveMux(t, app)

	for name, token := range map[string]string{
		"guest":     "",
		"org admin": testutil.Token(t, o.Admin),
	} {
		status, body := call(mux, http.MethodPost, schema.DeviceEnrolPath, token, map[string]any{"label": "Phone"})
		if status != http.StatusNotImplemented || !strings.Contains(body, api.DeviceEnrolNotReady) {
			t.Errorf("%s: %d %s; want 501 with the plain message", name, status, body)
		}
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
