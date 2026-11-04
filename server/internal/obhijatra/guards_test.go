package obhijatra_test

import (
	"testing"

	"ganigeorgiev.com/pocketbase/pocketbase/core"
	"ganigeorgiev.com/pocketbase/pocketbase/tools/filesystem"

	"github.com/obhijatra/obhijatra/server/internal/audit"
	"github.com/obhijatra/obhijatra/server/internal/schema"
	"github.com/obhijatra/obhijatra/server/internal/testutil"
)

// These rules bind Go code, and so the Dashboard and superusers, not only
// API users.
func TestGuardsBindEveryWriter(t *testing.T) {
	app := testutil.NewApp(t)
	defer app.Cleanup()
	o := testutil.SeedOrg(t, app)

	mustFail := func(name string, err error) {
		t.Helper()
		if err == nil {
			t.Errorf("%s: expected a refusal", name)
			return
		}
		t.Logf("%s: refused: %v", name, err)
	}

	// Published form versions are immutable, even through the very record
	// instance that created them (whose Original() is blank).
	o.Version.Set("published", false)
	mustFail("unpublish a published version", app.Save(o.Version))
	mustFail("delete a published version", app.Delete(o.Version))

	// A version whose XForm says something else is refused.
	versionsCol, _ := app.FindCollectionByNameOrId(schema.FormVersions)
	xml, _ := filesystem.NewFileFromBytes(testutil.XForm(testutil.FormID, "2026110409"), "form.xml")
	mismatch := core.NewRecord(versionsCol)
	mismatch.Load(map[string]any{"form": o.Form.Id, "version": "2026110410", "xform": xml})
	mustFail("version string differs from the XForm", app.Save(mismatch))

	// Locations cannot move.
	o.Branch1.Set("parent", o.Branch2.Id)
	mustFail("move a location", app.Save(o.Branch1))

	// The location path of a user always follows their location.
	o.Peer1.Set("location_path", o.Root.GetString("path"))
	if err := app.Save(o.Peer1); err != nil {
		t.Fatal(err)
	}
	if got := o.Peer1.GetString("location_path"); got != o.Branch1.GetString("path") {
		t.Errorf("location_path %q was not reset to the location's path %q", got, o.Branch1.GetString("path"))
	}

	// A field user cannot widen their own scope, even through Go code
	// attributed to them.
	err := audit.RunAs(app, audit.Actor{Collection: schema.FieldUsers, ID: o.Field1.Id, Role: schema.RoleFieldOfficer},
		func(txApp core.App) error {
			o.Field1.Set("location", o.Root.Id)
			return txApp.Save(o.Field1)
		})
	mustFail("field user moves themselves to the root", err)

	// One settings record, never deleted.
	settingsCol, _ := app.FindCollectionByNameOrId(schema.Settings)
	first := core.NewRecord(settingsCol)
	first.Set("organisation_name", "A")
	first.Set("hosting_country", "BD")
	first.Set("schema_version", 1)
	if err := app.Save(first); err != nil {
		t.Fatal(err)
	}
	second := core.NewRecord(settingsCol)
	second.Load(map[string]any{"organisation_name": "B", "hosting_country": "BD", "schema_version": 1})
	mustFail("second settings record", app.Save(second))
	mustFail("delete settings", app.Delete(first))

	// Devices: exactly one owner; revocation is final.
	devicesCol, _ := app.FindCollectionByNameOrId(schema.Devices)
	both := core.NewRecord(devicesCol)
	both.Load(map[string]any{"field_user": o.Field1.Id, "staff_user": o.Sup1.Id, "status": "active", "attestation_level": "none"})
	mustFail("device with two owners", app.Save(both))

	device := core.NewRecord(devicesCol)
	device.Load(map[string]any{"field_user": o.Field1.Id, "status": "active", "attestation_level": "software"})
	if err := app.Save(device); err != nil {
		t.Fatal(err)
	}
	device.Set("status", schema.DeviceRevoked)
	if err := app.Save(device); err != nil {
		t.Fatal(err)
	}
	if device.GetDateTime("revoked_at").IsZero() {
		t.Error("revoked_at was not stamped")
	}
	device.Set("status", schema.DeviceActive)
	mustFail("reactivate a revoked device", app.Save(device))

	// Core collections cannot be renamed or deleted.
	subs, _ := app.FindCollectionByNameOrId(schema.Submissions)
	mustFail("delete the submissions collection", app.Delete(subs))
	subs.Name = "renamed"
	mustFail("rename the submissions collection", app.Save(subs))

	if r := mustVerify(t, app); !r.OK {
		t.Fatalf("chain should verify after refused writes: %+v", r)
	}
}
