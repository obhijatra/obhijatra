package migrations

import (
	"errors"
	"fmt"
	"strings"

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
//   - names are stored clean (Unicode NFC, invisible characters removed,
//     spaces collapsed) with a name_key that ignores capitals, unique
//     among a place's siblings, so look-alike twins cannot be made;
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
	if c.Fields.GetByName("name_key") == nil {
		c.Fields.Add(&core.TextField{Name: "name_key", Max: 400, Hidden: true,
			Help: "Set by the server: the name as compared with its neighbours'"})
	}
	c.DeleteRule = types.Pointer(schema.LocationsDelete)
	if err := app.Save(c); err != nil {
		return fmt.Errorf("schema version 7, %s: %w", schema.Locations, err)
	}

	// Clean every stored name and code and fill in the keys, then refuse
	// to go on, with the names to fix, if two neighbours share a name or
	// two places a code.
	all, err := app.FindAllRecords(schema.Locations)
	if err != nil {
		return err
	}
	byKey := map[string]string{}
	byCode := map[string]string{}
	var clashes []string
	for _, r := range all {
		key := r.GetString("parent") + "\x00" + schema.PlaceNameKey(r.GetString("name"))
		if other, ok := byKey[key]; ok {
			clashes = append(clashes, fmt.Sprintf("the places %q and %q have the same name under the same place", other, r.GetString("name")))
		}
		byKey[key] = r.GetString("name")
		if code := strings.ToLower(strings.TrimSpace(r.GetString("code"))); code != "" {
			if other, ok := byCode[code]; ok {
				clashes = append(clashes, fmt.Sprintf("the places %q and %q have the same code %q", other, r.GetString("name"), r.GetString("code")))
			}
			byCode[code] = r.GetString("name")
		}
	}
	if len(clashes) > 0 {
		return fmt.Errorf("schema version 7 cannot start: %s. With the previous server version, rename or recode one "+
			"of each pair, then upgrade again", strings.Join(clashes, "; "))
	}
	for _, r := range all {
		r.Set("name", schema.CleanPlaceName(r.GetString("name")))
		r.Set("name_key", schema.PlaceNameKey(r.GetString("name")))
		r.Set("code", strings.TrimSpace(r.GetString("code")))
		if err := app.Save(r); err != nil {
			return fmt.Errorf("schema version 7, place %q: %w", r.GetString("name"), err)
		}
	}

	c, err = app.FindCollectionByNameOrId(schema.Locations)
	if err != nil {
		return err
	}
	c.AddIndex("idx_locations_code", true, "`code` COLLATE NOCASE", "`code` != ''")
	c.AddIndex("idx_locations_parent_name_key", true, "`parent`, `name_key`", "")
	if err := app.Save(c); err != nil {
		return fmt.Errorf("schema version 7, %s indexes: %w", schema.Locations, err)
	}
	if err := raiseSchemaVersion(app, SchemaVersion7); err != nil {
		return fmt.Errorf("schema version 7, schema version: %w", err)
	}
	return nil
}

func placesDown(app core.App) error {
	return errors.New("schema version 7 cannot be rolled back; restore a backup instead")
}
