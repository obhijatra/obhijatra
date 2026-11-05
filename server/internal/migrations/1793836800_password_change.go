package migrations

import (
	"errors"
	"fmt"

	"ganigeorgiev.com/pocketbase/pocketbase/core"
	m "ganigeorgiev.com/pocketbase/pocketbase/migrations"
	"ganigeorgiev.com/pocketbase/pocketbase/tools/types"

	"github.com/obhijatra/obhijatra/server/internal/schema"
)

// SchemaVersion6 is the schema version this migration produces.
const SchemaVersion6 = 6

func init() {
	m.Register(passwordChangeUp, passwordChangeDown)
}

// passwordChangeUp (6 November 2026) lets an org admin give a person a
// one-time password: field and staff users gain must_change_password,
// which the person cannot set on themselves. Every step can run again
// without harm.
func passwordChangeUp(app core.App) error {
	for _, name := range []string{schema.FieldUsers, schema.StaffUsers} {
		if err := addMustChangePassword(app, name); err != nil {
			return fmt.Errorf("schema version 6, %s: %w", name, err)
		}
	}
	if err := raiseSchemaVersion(app, SchemaVersion6); err != nil {
		return fmt.Errorf("schema version 6, schema version: %w", err)
	}
	return nil
}

func passwordChangeDown(app core.App) error {
	return errors.New("schema version 6 cannot be rolled back; restore a backup instead")
}

func addMustChangePassword(app core.App, name string) error {
	c, err := app.FindCollectionByNameOrId(name)
	if err != nil {
		return err
	}
	if c.Fields.GetByName(schema.MustChangePassword) == nil {
		c.Fields.Add(&core.BoolField{
			Name: schema.MustChangePassword,
			Help: "Set by an org admin with a one-time password; cleared when the person chooses their own",
		})
	}
	switch name {
	case schema.FieldUsers:
		c.UpdateRule = types.Pointer(schema.FieldUsersUpdate)
	case schema.StaffUsers:
		c.UpdateRule = types.Pointer(schema.StaffUsersUpdate)
	}
	return app.Save(c)
}
