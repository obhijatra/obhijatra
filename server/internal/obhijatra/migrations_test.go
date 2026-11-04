package obhijatra_test

import (
	"strings"
	"testing"

	"ganigeorgiev.com/pocketbase/pocketbase/core"

	"github.com/obhijatra/obhijatra/server/internal/schema"
	"github.com/obhijatra/obhijatra/server/internal/testutil"
)

func TestMigrationsApplyOnFreshDataDir(t *testing.T) {
	app := testutil.NewApp(t)
	defer app.Cleanup()

	// Running them again must be a no-op.
	if err := app.RunAllMigrations(); err != nil {
		t.Fatalf("re-running migrations: %v", err)
	}

	wantType := map[string]string{
		schema.Settings:     core.CollectionTypeBase,
		schema.Locations:    core.CollectionTypeBase,
		schema.FieldUsers:   core.CollectionTypeAuth,
		schema.StaffUsers:   core.CollectionTypeAuth,
		schema.Forms:        core.CollectionTypeBase,
		schema.FormVersions: core.CollectionTypeBase,
		schema.Submissions:  core.CollectionTypeBase,
		schema.Devices:      core.CollectionTypeBase,
		schema.Sessions:     core.CollectionTypeBase,
		schema.Audit:        core.CollectionTypeBase,
	}
	for name, typ := range wantType {
		c, err := app.FindCollectionByNameOrId(name)
		if err != nil {
			t.Errorf("collection %s missing: %v", name, err)
			continue
		}
		if c.Type != typ {
			t.Errorf("collection %s: type %s, want %s", name, c.Type, typ)
		}
		if !app.HasTable(name) {
			t.Errorf("collection %s has no table", name)
		}
	}

	// PocketBase's sample "users" collection allows public sign-up.
	if _, err := app.FindCollectionByNameOrId("users"); err == nil {
		t.Error("the default public-sign-up users collection still exists")
	}

	tokenHours := map[string]int64{
		schema.FieldUsers: 24 * 3600,
		schema.StaffUsers: 4 * 3600,
		schema.Superusers: 30 * 60,
	}
	for name, want := range tokenHours {
		c, _ := app.FindCollectionByNameOrId(name)
		if c.AuthToken.Duration != want {
			t.Errorf("%s token duration %d s, want %d s", name, c.AuthToken.Duration, want)
		}
		if pf, ok := c.Fields.GetByName("password").(*core.PasswordField); !ok || pf.Min != 12 {
			t.Errorf("%s password minimum is not 12", name)
		}
	}

	for _, name := range []string{schema.FieldUsers, schema.StaffUsers} {
		c, _ := app.FindCollectionByNameOrId(name)
		if c.CreateRule == nil || !strings.Contains(*c.CreateRule, `@request.auth.role = "org_admin"`) {
			t.Errorf("%s: account creation must be limited to org admins (invite-only), got %v", name, c.CreateRule)
		}
		if c.DeleteRule != nil {
			t.Errorf("%s: users must not be deletable through the API", name)
		}
		if c.AuthRule == nil || *c.AuthRule != schema.AuthRule {
			t.Errorf("%s: inactive users must be unable to log in", name)
		}
		for _, f := range []string{"location_path", "active", "role", "location"} {
			if c.Fields.GetByName(f) == nil {
				t.Errorf("%s: field %s missing", name, f)
			}
		}
	}

	// Every rule that exists requires an active user.
	for name := range wantType {
		c, _ := app.FindCollectionByNameOrId(name)
		for label, rule := range map[string]*string{
			"list": c.ListRule, "view": c.ViewRule, "create": c.CreateRule,
			"update": c.UpdateRule, "delete": c.DeleteRule,
		} {
			if rule != nil && !strings.Contains(*rule, "@request.auth.active = true") {
				t.Errorf("%s %s rule does not require an active user: %s", name, label, *rule)
			}
		}
	}

	// No write API on the audit chain; no create or delete API on submissions.
	audit, _ := app.FindCollectionByNameOrId(schema.Audit)
	if audit.CreateRule != nil || audit.UpdateRule != nil || audit.DeleteRule != nil {
		t.Error("the audit collection must have no create, update or delete rule")
	}
	subs, _ := app.FindCollectionByNameOrId(schema.Submissions)
	if subs.CreateRule != nil || subs.DeleteRule != nil {
		t.Error("submissions must have no create or delete API rule")
	}

	for collection, index := range map[string]string{
		schema.Submissions:  "idx_submissions_instance_id",
		schema.FormVersions: "idx_form_versions_form_version",
		schema.Audit:        "idx_audit_seq",
		schema.Locations:    "idx_locations_path",
	} {
		c, _ := app.FindCollectionByNameOrId(collection)
		idx := c.GetIndex(index)
		if !strings.Contains(idx, "UNIQUE") {
			t.Errorf("%s: unique index %s missing (got %q)", collection, index, idx)
		}
	}
}
