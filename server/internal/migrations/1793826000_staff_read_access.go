package migrations

import (
	"errors"
	"fmt"

	"ganigeorgiev.com/pocketbase/pocketbase/core"
	m "ganigeorgiev.com/pocketbase/pocketbase/migrations"
	"ganigeorgiev.com/pocketbase/pocketbase/tools/types"

	"github.com/obhijatra/obhijatra/server/internal/schema"
)

// SchemaVersion3 is the schema version this migration produces.
const SchemaVersion3 = 3

func init() {
	m.Register(staffReadAccessUp, staffReadAccessDown)
}

// staffReadAccessUp (4 November 2026): every active staff user reads the
// whole location tree; a field user reads only their own location and the
// locations below it (before, every active user read every location).
// Published form versions and their XForm files were already readable by
// every active staff role; that rule is unchanged.
func staffReadAccessUp(app core.App) error {
	steps := []struct {
		name string
		fn   func(core.App) error
	}{
		{schema.Locations, updateLocations},
		{"schema version", func(a core.App) error { return raiseSchemaVersion(a, SchemaVersion3) }},
	}

	for _, s := range steps {
		if err := s.fn(app); err != nil {
			return fmt.Errorf("schema version 3, %s: %w", s.name, err)
		}
	}
	return nil
}

func staffReadAccessDown(app core.App) error {
	return errors.New("schema version 3 cannot be rolled back; restore a backup instead")
}

func updateLocations(app core.App) error {
	c, err := app.FindCollectionByNameOrId(schema.Locations)
	if err != nil {
		return err
	}
	c.ListRule = types.Pointer(schema.LocationsRead)
	c.ViewRule = types.Pointer(schema.LocationsRead)
	return app.Save(c)
}

// raiseSchemaVersion stores version in the settings record unless it is
// already as high. A server not yet set up is skipped: init writes the
// current version.
func raiseSchemaVersion(app core.App, version int) error {
	if !isSetUp(app) {
		return nil
	}
	rec, err := app.FindFirstRecordByFilter(schema.Settings, "")
	if err != nil {
		return err
	}
	if rec.GetInt("schema_version") >= version {
		return nil
	}
	rec.Set("schema_version", version)
	return app.Save(rec)
}
