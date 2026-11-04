package migrations

import (
	"errors"
	"fmt"

	"ganigeorgiev.com/pocketbase/pocketbase/core"
	m "ganigeorgiev.com/pocketbase/pocketbase/migrations"
	"ganigeorgiev.com/pocketbase/pocketbase/tools/types"

	"github.com/obhijatra/obhijatra/server/internal/schema"
)

// SchemaVersion2 is the schema version this migration produces.
const SchemaVersion2 = 2

func init() {
	m.Register(reviewPublishingSigninUp, reviewPublishingSigninDown)
}

// reviewPublishingSigninUp (4 November 2026):
//   - XML file fields no longer check MIME types (the hooks parse the XML
//     instead) and the XForm file is protected;
//   - M&E staff and org admins manage forms; reviewers may comment;
//   - sign-in protection: the login_locks collection, the failure counter
//     table and the wider per-IP sign-in rate limit.
func reviewPublishingSigninUp(app core.App) error {
	steps := []struct {
		name string
		fn   func(core.App) error
	}{
		{schema.Forms, updateForms},
		{schema.FormVersions, updateFormVersions},
		{schema.Submissions, updateSubmissions},
		{schema.LoginLocks, createLoginLocks},
		{schema.LoginFailuresTable, createLoginFailures},
		{"sign-in rate limit", widenAuthRateLimit},
		{"schema version", setSchemaVersion},
	}

	for _, s := range steps {
		if err := s.fn(app); err != nil {
			return fmt.Errorf("schema version 2, %s: %w", s.name, err)
		}
	}
	return nil
}

func reviewPublishingSigninDown(app core.App) error {
	return errors.New("schema version 2 cannot be rolled back; restore a backup instead")
}

// ---------------------------------------------------------------------

func updateForms(app core.App) error {
	c, err := app.FindCollectionByNameOrId(schema.Forms)
	if err != nil {
		return err
	}
	c.CreateRule = types.Pointer(schema.FormsWrite)
	c.UpdateRule = types.Pointer(schema.FormsWrite)
	c.DeleteRule = types.Pointer(schema.FormsWrite)
	return app.Save(c)
}

func updateFormVersions(app core.App) error {
	c, err := app.FindCollectionByNameOrId(schema.FormVersions)
	if err != nil {
		return err
	}
	f, ok := c.Fields.GetByName("xform").(*core.FileField)
	if !ok {
		return errors.New("the xform file field is missing")
	}
	f.MimeTypes = nil
	f.Protected = true

	c.ListRule = types.Pointer(schema.FormVersionsRead)
	c.ViewRule = types.Pointer(schema.FormVersionsRead)
	c.CreateRule = types.Pointer(schema.FormVersionsCreate)
	c.UpdateRule = types.Pointer(schema.FormVersionsUpdate)
	c.DeleteRule = types.Pointer(schema.FormVersionsDelete)
	return app.Save(c)
}

func updateSubmissions(app core.App) error {
	c, err := app.FindCollectionByNameOrId(schema.Submissions)
	if err != nil {
		return err
	}
	f, ok := c.Fields.GetByName("xml").(*core.FileField)
	if !ok {
		return errors.New("the xml file field is missing")
	}
	f.MimeTypes = nil
	f.Protected = true

	if c.Fields.GetByName("review_comment") == nil {
		c.Fields.Add(&core.TextField{Name: "review_comment", Max: schema.MaxReviewComment,
			Help: "The reviewer's comment; set with review_state"})
	}
	c.UpdateRule = types.Pointer(schema.SubmissionsUpdate)
	return app.Save(c)
}

func createLoginLocks(app core.App) error {
	if _, err := app.FindCollectionByNameOrId(schema.LoginLocks); err == nil {
		return nil
	}

	c := core.NewBaseCollection(schema.LoginLocks)
	c.ListRule = types.Pointer(schema.LoginLocksRead)
	c.ViewRule = types.Pointer(schema.LoginLocksRead)
	c.UpdateRule = types.Pointer(schema.LoginLocksUpdate)
	// No create or delete API: the server writes a row when it locks an
	// account, and rows are kept as history.

	unlockedBy, err := relationTo(app, schema.StaffUsers, "unlocked_by", false)
	if err != nil {
		return err
	}
	zero := 0.0

	c.Fields.Add(&core.SelectField{Name: "account_collection", Required: true, MaxSelect: 1, Values: schema.LockableCollections})
	c.Fields.Add(&core.TextField{Name: "account_id", Required: true, Max: 100, Presentable: true,
		Help: "Id of the locked account in account_collection"})
	c.Fields.Add(&core.NumberField{Name: "failed_attempts", OnlyInt: true, Min: &zero})
	c.Fields.Add(&core.DateField{Name: "locked_until", Required: true})
	c.Fields.Add(&core.BoolField{Name: "unlocked", Help: "Set to true by an org admin to unlock early"})
	c.Fields.Add(&core.DateField{Name: "unlocked_at"})
	c.Fields.Add(unlockedBy)
	autodates(c)
	c.AddIndex("idx_login_locks_account", false, "`account_collection`, `account_id`, `locked_until`", "")

	return app.Save(c)
}

func createLoginFailures(app core.App) error {
	for _, q := range []string{
		"CREATE TABLE IF NOT EXISTS {{" + schema.LoginFailuresTable + "}} (" +
			"[[account_collection]] TEXT NOT NULL, " +
			"[[account_id]] TEXT NOT NULL, " +
			"[[at]] INTEGER NOT NULL)", // Unix time in milliseconds
		"CREATE INDEX IF NOT EXISTS idx_obhijatra_login_failures_account ON {{" + schema.LoginFailuresTable + "}} " +
			"([[account_collection]], [[account_id]], [[at]])",
		"CREATE INDEX IF NOT EXISTS idx_obhijatra_login_failures_at ON {{" + schema.LoginFailuresTable + "}} ([[at]])",
	} {
		if _, err := app.DB().NewQuery(q).Execute(); err != nil {
			return err
		}
	}
	return nil
}

// widenAuthRateLimit moves a server that `init` set up with the first
// baseline (2 sign-ins per 3 s per IP) to the current one. A rule an
// organisation changed itself is left alone. A server not yet set up is
// skipped: its settings are PocketBase's defaults and init applies the
// baseline.
func widenAuthRateLimit(app core.App) error {
	if !isSetUp(app) {
		return nil
	}

	s, err := app.Settings().Clone()
	if err != nil {
		return err
	}
	changed := false
	for i, r := range s.RateLimits.Rules {
		if r.Label == "*:auth" && r.Audience == "" && r.MaxRequests == 2 && r.Duration == 3 {
			s.RateLimits.Rules[i].MaxRequests = schema.AuthRateLimitRequests
			s.RateLimits.Rules[i].Duration = schema.AuthRateLimitSeconds
			changed = true
		}
	}
	if !changed {
		return nil
	}
	return app.Save(s)
}

func setSchemaVersion(app core.App) error {
	if !isSetUp(app) {
		return nil // init writes the current version
	}
	rec, err := app.FindFirstRecordByFilter(schema.Settings, "")
	if err != nil {
		return err
	}
	if rec.GetInt("schema_version") >= SchemaVersion2 {
		return nil
	}
	rec.Set("schema_version", SchemaVersion2)
	return app.Save(rec)
}

// isSetUp reports whether `init` has written the organisation settings.
func isSetUp(app core.App) bool {
	total, err := app.CountRecords(schema.Settings)
	return err == nil && total > 0
}
