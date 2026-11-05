package migrations

import (
	"errors"
	"fmt"

	"ganigeorgiev.com/pocketbase/pocketbase/core"
	m "ganigeorgiev.com/pocketbase/pocketbase/migrations"
	"ganigeorgiev.com/pocketbase/pocketbase/tools/types"

	"github.com/obhijatra/obhijatra/server/internal/schema"
)

// SchemaVersion7 is the schema version this migration produces.
const SchemaVersion7 = 7

func init() {
	m.Register(placesUp, placesDown)
}

// placesUp (6 November 2026) lets org admins manage the organisation tree
// in the manager app (docs/decisions/0007-places.md):
//   - a place can be closed (hidden from new choices) when it is in use,
//     and deleted when nothing uses it (the guards decide);
//   - place codes, when given, are unique, ignoring capital letters.
//
// Every step can run again without harm.
func placesUp(app core.App) error {
	c, err := app.FindCollectionByNameOrId(schema.Locations)
	if err != nil {
		return err
	}
	if c.Fields.GetByName("closed") == nil {
		c.Fields.Add(&core.BoolField{Name: "closed",
			Help: "A closed place is kept for its records but cannot be chosen for new people or places"})
	}
	c.DeleteRule = types.Pointer(schema.LocationsDelete)
	c.AddIndex("idx_locations_code", true, "`code` COLLATE NOCASE", "`code` != ''")
	if err := app.Save(c); err != nil {
		return fmt.Errorf("schema version 7, %s (two places may share a code; give them different codes first): %w",
			schema.Locations, err)
	}
	if err := raiseSchemaVersion(app, SchemaVersion7); err != nil {
		return fmt.Errorf("schema version 7, schema version: %w", err)
	}
	return nil
}

func placesDown(app core.App) error {
	return errors.New("schema version 7 cannot be rolled back; restore a backup instead")
}
