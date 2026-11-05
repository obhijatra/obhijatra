package migrations

import (
	"errors"
	"fmt"
	"strings"

	"ganigeorgiev.com/pocketbase/pocketbase/core"
	m "ganigeorgiev.com/pocketbase/pocketbase/migrations"
	"ganigeorgiev.com/pocketbase/pocketbase/tools/dbutils"
	"ganigeorgiev.com/pocketbase/pocketbase/tools/types"

	"github.com/obhijatra/obhijatra/server/internal/schema"
)

// SchemaVersion5 is the schema version this migration produces.
const SchemaVersion5 = 5

func init() {
	m.Register(signinMethodsUp, signinMethodsDown)
}

// signinMethodsUp (5 November 2026) prepares Google sign-in and SMS-code
// sign-in (docs/decisions/0005-sign-in-methods.md):
//   - field and staff users gain an optional phone number (international
//     form, unique per collection) and no longer need an email address,
//     so field staff without email can sign in by phone; users still
//     cannot change their own phone number;
//   - email addresses are matched without regard to capital letters (the
//     unique index is COLLATE NOCASE), so Google's address finds the
//     account an admin typed as "Rahima.Khatun@…", and two accounts cannot
//     differ only in capitals;
//   - PocketBase's own one-time-code settings give codes 6 digits and 5
//     minutes; its email-code routes stay switched off, because codes are
//     sent only by SMS through the server's own routes;
//   - two plain tables hold the phone sign-in settings and the counts
//     behind the sending limits.
//
// Google and phone sign-in stay off until an org admin switches them on.
// Every step can run again without harm.
func signinMethodsUp(app core.App) error {
	steps := []struct {
		name string
		fn   func(core.App) error
	}{
		{schema.FieldUsers, func(a core.App) error { return addPhoneSignIn(a, schema.FieldUsers) }},
		{schema.StaffUsers, func(a core.App) error { return addPhoneSignIn(a, schema.StaffUsers) }},
		{schema.SignInSettingsTable, createSignInTables},
		{"schema version", func(a core.App) error { return raiseSchemaVersion(a, SchemaVersion5) }},
	}

	for _, s := range steps {
		if err := s.fn(app); err != nil {
			return fmt.Errorf("schema version 5, %s: %w", s.name, err)
		}
	}
	return nil
}

func signinMethodsDown(app core.App) error {
	return errors.New("schema version 5 cannot be rolled back; restore a backup instead")
}

func addPhoneSignIn(app core.App, name string) error {
	c, err := app.FindCollectionByNameOrId(name)
	if err != nil {
		return err
	}

	if c.Fields.GetByName("phone") == nil {
		c.Fields.Add(&core.TextField{
			Name:    "phone",
			Max:     16,
			Pattern: schema.PhonePattern,
			Help:    "Mobile number for SMS sign-in codes, in international form, for example +8801712345678",
		})
	}
	c.AddIndex("idx_"+name+"_phone", true, "`phone`", "`phone` != ''")

	// A user needs an email address or a phone number (guards package);
	// org admins always need an email address.
	if email, ok := c.Fields.GetByName(core.FieldNameEmail).(*core.EmailField); ok {
		email.Required = false
	}
	if idx, ok := dbutils.FindSingleColumnUniqueIndex(c.Indexes, core.FieldNameEmail); ok &&
		!strings.EqualFold(idx.Columns[0].Collate, "nocase") {
		c.RemoveIndex(idx.IndexName)
		c.AddIndex(idx.IndexName, true, "`email` COLLATE NOCASE", "`email` != ''")
	}

	switch name {
	case schema.FieldUsers:
		c.UpdateRule = types.Pointer(schema.FieldUsersUpdate)
	case schema.StaffUsers:
		c.UpdateRule = types.Pointer(schema.StaffUsersUpdate)
	}

	// Codes are created and checked only by Obhijatra's phone routes;
	// PocketBase's email-code routes stay off.
	c.OTP.Enabled = false
	c.OTP.Length = schema.PhoneCodeLength
	c.OTP.Duration = int64(schema.PhoneCodeLifetime.Seconds())

	return app.Save(c)
}

func createSignInTables(app core.App) error {
	for _, q := range []string{
		"CREATE TABLE IF NOT EXISTS {{" + schema.SignInSettingsTable + "}} (" +
			"[[key]] TEXT PRIMARY KEY NOT NULL, " +
			"[[value]] TEXT NOT NULL, " +
			"[[updated]] INTEGER NOT NULL)", // Unix time in milliseconds
		"CREATE TABLE IF NOT EXISTS {{" + schema.SignInAttemptsTable + "}} (" +
			"[[kind]] TEXT NOT NULL, " +
			"[[key]] TEXT NOT NULL, " +
			"[[at]] INTEGER NOT NULL)", // Unix time in milliseconds
		"CREATE INDEX IF NOT EXISTS idx_obhijatra_signin_attempts ON {{" + schema.SignInAttemptsTable + "}} " +
			"([[kind]], [[key]], [[at]])",
		"CREATE INDEX IF NOT EXISTS idx_obhijatra_signin_attempts_at ON {{" + schema.SignInAttemptsTable + "}} ([[at]])",
	} {
		if _, err := app.DB().NewQuery(q).Execute(); err != nil {
			return err
		}
	}
	return nil
}
