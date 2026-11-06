package migrations

import (
	"errors"
	"fmt"

	"ganigeorgiev.com/pocketbase/pocketbase/core"
	m "ganigeorgiev.com/pocketbase/pocketbase/migrations"
	"ganigeorgiev.com/pocketbase/pocketbase/tools/types"

	"github.com/obhijatra/obhijatra/server/internal/schema"
)

// SchemaVersion9 is the schema version this migration produces.
const SchemaVersion9 = 9

func init() {
	m.Register(exportsUp, exportsDown)
}

// exportsUp (6 November 2026) prepares submission downloads
// (docs/decisions/0009-data-export.md):
//   - sessions record when the person signed in (empty after a refresh),
//     so a download can require a sign-in within the last 15 minutes;
//   - an exports collection records every download: who, from which
//     device, which form, the filters, how many submissions and files,
//     and the SHA-256 of the package's manifest. Only the export route
//     writes it; org admins read all of it and everyone else their own.
//
// Every step can run again without harm.
func exportsUp(app core.App) error {
	steps := []struct {
		name string
		fn   func(core.App) error
	}{
		{schema.Sessions, addSignedIn},
		{schema.Exports, createExports},
		{"schema version", func(a core.App) error { return raiseSchemaVersion(a, SchemaVersion9) }},
	}
	for _, s := range steps {
		if err := s.fn(app); err != nil {
			return fmt.Errorf("schema version 9, %s: %w", s.name, err)
		}
	}
	return nil
}

func exportsDown(app core.App) error {
	return errors.New("schema version 9 cannot be rolled back; restore a backup instead")
}

func addSignedIn(app core.App) error {
	c, err := app.FindCollectionByNameOrId(schema.Sessions)
	if err != nil {
		return err
	}
	if c.Fields.GetByName("signed_in") == nil {
		c.Fields.Add(&core.DateField{Name: "signed_in",
			Help: "When the person signed in for this session; empty for a session made by a refresh"})
	}
	return app.Save(c)
}

func createExports(app core.App) error {
	if _, err := app.FindCollectionByNameOrId(schema.Exports); err == nil {
		return nil
	}
	c := core.NewBaseCollection(schema.Exports)
	c.ListRule = types.Pointer(schema.ExportsRead)
	c.ViewRule = types.Pointer(schema.ExportsRead)
	// No create, update or delete API: only the export route writes, and
	// a guard refuses records-API writes from superusers too.

	staffUser, err := relationTo(app, schema.StaffUsers, "staff_user", true)
	if err != nil {
		return err
	}
	device, err := relationTo(app, schema.Devices, "device", false)
	if err != nil {
		return err
	}
	form, err := relationTo(app, schema.Forms, "form", true)
	if err != nil {
		return err
	}
	c.Fields.Add(staffUser)
	c.Fields.Add(device)
	c.Fields.Add(form)
	c.Fields.Add(&core.JSONField{Name: "filters", MaxSize: 4 * 1024,
		Help: "The filters of the download: dates, review states, whether media were included, the place scope"})
	c.Fields.Add(&core.NumberField{Name: "submissions", OnlyInt: true})
	c.Fields.Add(&core.NumberField{Name: "files", OnlyInt: true,
		Help: "Media files in the package"})
	c.Fields.Add(&core.SelectField{Name: "status", Required: true, MaxSelect: 1, Values: schema.ExportStatuses})
	c.Fields.Add(&core.TextField{Name: "manifest_sha256", Max: 64, Pattern: `^([a-f0-9]{64})?$`,
		Help: "SHA-256 of manifest.json in the downloaded package"})
	autodates(c)
	c.AddIndex("idx_exports_staff_user", false, "`staff_user`", "")
	return app.Save(c)
}
