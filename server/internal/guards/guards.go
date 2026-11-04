// Package guards holds the Go record hooks that keep Obhijatra's data
// consistent and its integrity rules binding on everyone. API rules protect
// data from ordinary users; these hooks also bind superusers, the Dashboard
// and Go code, because they run on every save, not only on API requests.
package guards

import (
	"bytes"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"slices"

	"ganigeorgiev.com/pocketbase/pocketbase/core"
	"ganigeorgiev.com/pocketbase/pocketbase/tools/hook"
	"ganigeorgiev.com/pocketbase/pocketbase/tools/security"
	"ganigeorgiev.com/pocketbase/pocketbase/tools/types"

	"github.com/obhijatra/obhijatra/server/internal/audit"
	"github.com/obhijatra/obhijatra/server/internal/schema"
	"github.com/obhijatra/obhijatra/server/internal/xform"
)

// Register binds every guard to app.
func Register(app core.App) {
	// Locations: the materialised path is computed here and never changes.
	app.OnRecordCreate(schema.Locations).BindFunc(setLocationPath)
	onUpdate(app, schema.Locations, func(e *core.RecordEvent, old *core.Record) error {
		if anyChanged(old, e.Record, "parent", "path") {
			return errors.New("a location cannot be moved: its parent and path are fixed once created")
		}
		return e.Next()
	})

	// Users: location_path always follows the location relation, and only
	// an org admin (or the server) may change what a user can see.
	for _, name := range []string{schema.FieldUsers, schema.StaffUsers} {
		app.OnRecordCreate(name).BindFunc(syncUserLocationPath)
		onUpdate(app, name, func(e *core.RecordEvent, old *core.Record) error {
			if anyChanged(old, e.Record, "role", "location", "location_path", "active") && !mayAdminister(audit.ActorOf(e.App)) {
				return errors.New("only an organisation admin can change a user's role, location or active status")
			}
			return syncUserLocationPath(e)
		})
	}

	// Settings: exactly one record, never deleted.
	app.OnRecordCreate(schema.Settings).BindFunc(func(e *core.RecordEvent) error {
		total, err := e.App.CountRecords(schema.Settings)
		if err != nil {
			return err
		}
		if total > 0 {
			return errors.New("the organisation settings record already exists")
		}
		return e.Next()
	})
	app.OnRecordDelete(schema.Settings).BindFunc(func(e *core.RecordEvent) error {
		return errors.New("the organisation settings record cannot be deleted")
	})

	// Form versions: checked against their XForm; immutable once published.
	app.OnRecordCreate(schema.FormVersions).BindFunc(func(e *core.RecordEvent) error {
		if err := checkFormVersion(e.App, e.Record); err != nil {
			return err
		}
		stampPublished(e.Record)
		return e.Next()
	})
	onUpdate(app, schema.FormVersions, func(e *core.RecordEvent, old *core.Record) error {
		if old.GetBool("published") {
			return errors.New("a published form version cannot be changed; upload a new version instead")
		}
		if anyChanged(old, e.Record, "version", "xform", "form") {
			if err := checkFormVersion(e.App, e.Record); err != nil {
				return err
			}
		}
		stampPublished(e.Record)
		return e.Next()
	})
	app.OnRecordDelete(schema.FormVersions).BindFunc(func(e *core.RecordEvent) error {
		old, err := stored(e)
		if err != nil {
			return err
		}
		if old.GetBool("published") {
			return errors.New("a published form version cannot be deleted")
		}
		return e.Next()
	})

	// Submissions: only the review state may change after receipt.
	onUpdate(app, schema.Submissions, func(e *core.RecordEvent, old *core.Record) error {
		for _, f := range e.Record.Collection().Fields {
			name := f.GetName()
			if name == "review_state" || name == "updated" {
				continue
			}
			if changed(old, e.Record, name) {
				return fmt.Errorf("a received submission cannot be changed (field %q); only its review state can", name)
			}
		}
		return e.Next()
	})

	// Devices: one owner, fixed; a revoked device stays revoked.
	app.OnRecordCreate(schema.Devices).BindFunc(func(e *core.RecordEvent) error {
		if err := checkSingleOwner(e.Record); err != nil {
			return err
		}
		if e.Record.GetString("status") == schema.DeviceRevoked && e.Record.GetDateTime("revoked_at").IsZero() {
			e.Record.Set("revoked_at", types.NowDateTime())
		}
		return e.Next()
	})
	onUpdate(app, schema.Devices, func(e *core.RecordEvent, old *core.Record) error {
		if anyChanged(old, e.Record, "field_user", "staff_user") {
			return errors.New("a device cannot be moved to another user; enrol a new device instead")
		}
		wasRevoked := old.GetString("status") == schema.DeviceRevoked
		if wasRevoked && e.Record.GetString("status") != schema.DeviceRevoked {
			return errors.New("a revoked device cannot be reactivated; enrol it again as a new device")
		}
		if !wasRevoked && e.Record.GetString("status") == schema.DeviceRevoked {
			e.Record.Set("revoked_at", types.NowDateTime())
		}
		return e.Next()
	})

	// Sessions: identity fields are fixed; a revoked session stays revoked.
	onUpdate(app, schema.Sessions, func(e *core.RecordEvent, old *core.Record) error {
		if anyChanged(old, e.Record, "field_user", "staff_user", "device", "token_hash", "issued") {
			return errors.New("a session's user, device, token and issue time cannot be changed")
		}
		wasRevoked := old.GetBool("revoked")
		if wasRevoked && !e.Record.GetBool("revoked") {
			return errors.New("a revoked session cannot be restored")
		}
		if !wasRevoked && e.Record.GetBool("revoked") {
			e.Record.Set("revoked_at", types.NowDateTime())
		}
		return e.Next()
	})

	// Core collections: no renaming, no deleting.
	app.OnCollectionUpdate().Bind(&hook.Handler[*core.CollectionEvent]{
		Id: "obhijatraGuardCoreCollectionRename",
		Func: func(e *core.CollectionEvent) error {
			old, err := e.App.FindCollectionByNameOrId(e.Collection.Id)
			if err == nil && schema.IsCoreCollection(old.Name) && old.Name != e.Collection.Name {
				return fmt.Errorf("the %q collection is part of Obhijatra's core schema and cannot be renamed", old.Name)
			}
			return e.Next()
		},
	})
	app.OnCollectionDelete().Bind(&hook.Handler[*core.CollectionEvent]{
		Id: "obhijatraGuardCoreCollectionDelete",
		Func: func(e *core.CollectionEvent) error {
			if schema.IsCoreCollection(e.Collection.Name) {
				return fmt.Errorf("the %q collection is part of Obhijatra's core schema and cannot be deleted", e.Collection.Name)
			}
			return e.Next()
		},
	})
}

// ---------------------------------------------------------------------

// onUpdate binds fn to updates of collection, passing the record as it is
// stored in the database now. The guards compare against that, not against
// Record.Original(), which is blank for a record created in the same
// process and so cannot be trusted to describe what is stored.
func onUpdate(app core.App, collection string, fn func(e *core.RecordEvent, old *core.Record) error) {
	app.OnRecordUpdate(collection).BindFunc(func(e *core.RecordEvent) error {
		old, err := stored(e)
		if err != nil {
			return err
		}
		return fn(e, old)
	})
}

// stored reads e.Record's current database row through e.App, which is the
// audit wrapper's transaction.
func stored(e *core.RecordEvent) (*core.Record, error) {
	old, err := e.App.FindRecordById(e.Record.Collection(), e.Record.Id)
	if err != nil {
		return nil, fmt.Errorf("could not read the stored %s record: %w", e.Record.Collection().Name, err)
	}
	return old, nil
}

// changed reports whether field of r differs from old, comparing values in
// their JSON form so that equal values of different Go types (a parsed and
// a freshly set date, for example) compare equal.
func changed(old, r *core.Record, field string) bool {
	if len(r.GetUnsavedFiles(field)) > 0 {
		return true
	}
	a, errA := json.Marshal(old.Get(field))
	b, errB := json.Marshal(r.Get(field))
	return errA != nil || errB != nil || !bytes.Equal(a, b)
}

func anyChanged(old, r *core.Record, fields ...string) bool {
	return slices.ContainsFunc(fields, func(f string) bool { return changed(old, r, f) })
}

// mayAdminister reports whether actor may change user permissions: an org
// admin, a superuser, a command-line action or the server itself.
func mayAdminister(a audit.Actor) bool {
	switch a.Collection {
	case schema.Superusers, audit.SystemActor.Collection, "_cli":
		return true
	case schema.StaffUsers:
		return a.Role == schema.RoleOrgAdmin
	}
	return false
}

func setLocationPath(e *core.RecordEvent) error {
	if e.Record.Id == "" {
		// The id is part of the path, so it is fixed here rather than
		// during validation.
		e.Record.Id = security.RandomStringWithAlphabet(core.DefaultIdLength, core.DefaultIdAlphabet)
	}

	path := "/" + e.Record.Id + "/"
	if parentID := e.Record.GetString("parent"); parentID != "" {
		parent, err := e.App.FindRecordById(schema.Locations, parentID)
		if err != nil {
			return errors.New("the parent location does not exist")
		}
		path = parent.GetString("path") + e.Record.Id + "/"
	}
	if !schema.LocationPathRegex.MatchString(path) {
		return fmt.Errorf("location id %q is not a 15-character lower-case id", e.Record.Id)
	}
	e.Record.Set("path", path)

	return e.Next()
}

func syncUserLocationPath(e *core.RecordEvent) error {
	locationID := e.Record.GetString("location")
	if locationID == "" {
		return errors.New("every user needs a location")
	}
	location, err := e.App.FindRecordById(schema.Locations, locationID)
	if err != nil {
		return errors.New("the user's location does not exist")
	}
	e.Record.Set("location_path", location.GetString("path"))

	return e.Next()
}

func stampPublished(r *core.Record) {
	if r.GetBool("published") && r.GetDateTime("published_at").IsZero() {
		r.Set("published_at", types.NowDateTime())
	}
}

func checkSingleOwner(r *core.Record) error {
	hasField := r.GetString("field_user") != ""
	hasStaff := r.GetString("staff_user") != ""
	if hasField == hasStaff {
		return errors.New("a device belongs to exactly one user: set either field_user or staff_user")
	}
	return nil
}

// checkFormVersion confirms that the XForm file's form id and version match
// the form record and the version string, so that submissions made with it
// can be matched back to this version.
func checkFormVersion(app core.App, r *core.Record) error {
	form, err := app.FindRecordById(schema.Forms, r.GetString("form"))
	if err != nil {
		return errors.New("the form for this version does not exist")
	}

	reader, closeFn, err := openXForm(app, r)
	if err != nil {
		return err
	}
	defer closeFn()

	def, err := xform.ParseDefinition(io.LimitReader(reader, schema.MaxXMLSize+1))
	if err != nil {
		return fmt.Errorf("the XForm file could not be read: %w", err)
	}
	if def.FormID != form.GetString("form_id") {
		return fmt.Errorf("the XForm's form id is %q but this form's id is %q", def.FormID, form.GetString("form_id"))
	}
	if def.Version != r.GetString("version") {
		return fmt.Errorf("the XForm's version is %q but this record's version is %q", def.Version, r.GetString("version"))
	}

	return nil
}

func openXForm(app core.App, r *core.Record) (io.Reader, func(), error) {
	if files := r.GetUnsavedFiles("xform"); len(files) > 0 {
		f, err := files[0].Reader.Open()
		if err != nil {
			return nil, nil, fmt.Errorf("the XForm file could not be opened: %w", err)
		}
		return f, func() { f.Close() }, nil
	}

	name := r.GetString("xform")
	if name == "" {
		return nil, nil, errors.New("an XForm file is required")
	}
	fsys, err := app.NewFilesystem()
	if err != nil {
		return nil, nil, err
	}
	br, err := fsys.GetReader(r.BaseFilesPath() + "/" + name)
	if err != nil {
		fsys.Close()
		return nil, nil, fmt.Errorf("the stored XForm file could not be opened: %w", err)
	}
	return br, func() { br.Close(); fsys.Close() }, nil
}
