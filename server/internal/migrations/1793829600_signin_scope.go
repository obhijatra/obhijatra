package migrations

import (
	"errors"
	"fmt"
	"slices"

	"ganigeorgiev.com/pocketbase/pocketbase/core"
	m "ganigeorgiev.com/pocketbase/pocketbase/migrations"

	"github.com/obhijatra/obhijatra/server/internal/schema"
)

// SchemaVersion4 is the schema version this migration produces.
const SchemaVersion4 = 4

// actionRefuse is the audit action for a write a guard refused (see
// audit.ActionRefuse; repeated here so migrations do not import the hooks).
const actionRefuse = "refuse"

func init() {
	m.Register(signinScopeUp, signinScopeDown)
}

// signinScopeUp (4 November 2026):
//   - wrong passwords are counted per account and IP address, so the
//     failure counter and login_locks gain an ip column (empty in a lock
//     means "every address");
//   - the audit chain can record a refused write (action "refuse").
//
// Every step can run again without harm.
func signinScopeUp(app core.App) error {
	steps := []struct {
		name string
		fn   func(core.App) error
	}{
		{schema.LoginFailuresTable, addFailureIP},
		{schema.LoginLocks, addLockIP},
		{schema.Audit, addRefuseAction},
		{"schema version", func(a core.App) error { return raiseSchemaVersion(a, SchemaVersion4) }},
	}

	for _, s := range steps {
		if err := s.fn(app); err != nil {
			return fmt.Errorf("schema version 4, %s: %w", s.name, err)
		}
	}
	return nil
}

func signinScopeDown(app core.App) error {
	return errors.New("schema version 4 cannot be rolled back; restore a backup instead")
}

func addFailureIP(app core.App) error {
	columns, err := app.TableColumns(schema.LoginFailuresTable)
	if err != nil {
		return err
	}
	queries := []string{
		"CREATE INDEX IF NOT EXISTS idx_obhijatra_login_failures_account_ip ON {{" + schema.LoginFailuresTable + "}} " +
			"([[account_collection]], [[account_id]], [[ip]], [[at]])",
	}
	if !slices.Contains(columns, "ip") {
		// Failures counted before the upgrade have no address; they still
		// count towards the account-wide limit and expire within the window.
		queries = append([]string{
			"ALTER TABLE {{" + schema.LoginFailuresTable + "}} ADD COLUMN [[ip]] TEXT NOT NULL DEFAULT ''",
		}, queries...)
	}
	for _, q := range queries {
		if _, err := app.DB().NewQuery(q).Execute(); err != nil {
			return err
		}
	}
	return nil
}

func addLockIP(app core.App) error {
	c, err := app.FindCollectionByNameOrId(schema.LoginLocks)
	if err != nil {
		return err
	}
	if c.Fields.GetByName("ip") != nil {
		return nil
	}
	c.Fields.Add(&core.TextField{Name: "ip", Max: 64,
		Help: "The IP address the lock applies to; empty means every address"})
	return app.Save(c)
}

func addRefuseAction(app core.App) error {
	c, err := app.FindCollectionByNameOrId(schema.Audit)
	if err != nil {
		return err
	}
	f, ok := c.Fields.GetByName("action").(*core.SelectField)
	if !ok {
		return errors.New("the audit action field is missing")
	}
	if slices.Contains(f.Values, actionRefuse) {
		return nil
	}
	f.Values = append(f.Values, actionRefuse)
	return app.Save(c)
}
