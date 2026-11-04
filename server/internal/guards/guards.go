// Package guards holds the Go record hooks that keep Obhijatra's data
// consistent and its integrity rules binding on everyone. API rules protect
// data from ordinary users; these hooks also bind superusers, the Dashboard
// and Go code, because they run on every save, not only on API requests.
package guards

import (
	"bytes"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"slices"

	"ganigeorgiev.com/pocketbase/dbx"
	validation "ganigeorgiev.com/pocketbase/ozzo-validation/v4"
	"ganigeorgiev.com/pocketbase/pocketbase/core"
	"ganigeorgiev.com/pocketbase/pocketbase/tools/hook"
	"ganigeorgiev.com/pocketbase/pocketbase/tools/router"
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

	// Forms: the form id ties every version's XForm and every submission to
	// the form, so it is fixed once the form has a version.
	onUpdate(app, schema.Forms, func(e *core.RecordEvent, old *core.Record) error {
		if changed(old, e.Record, "form_id") {
			total, err := e.App.CountRecords(schema.FormVersions, dbx.HashExp{"form": old.Id})
			if err != nil {
				return err
			}
			if total > 0 {
				return validation.Errors{"form_id": validation.NewError("validation_form_id_fixed",
					"The form id cannot be changed once the form has a version.")}
			}
		}
		return e.Next()
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

	// Submissions: the XML is checked on arrival, from any source; after
	// that only the review state and comment may change.
	app.OnRecordCreate(schema.Submissions).BindFunc(func(e *core.RecordEvent) error {
		if err := checkSubmission(e.App, e.Record); err != nil {
			return err
		}
		return e.Next()
	})
	onUpdate(app, schema.Submissions, func(e *core.RecordEvent, old *core.Record) error {
		for _, f := range e.Record.Collection().Fields {
			name := f.GetName()
			if name == "updated" || slices.Contains(schema.ReviewFields, name) {
				continue
			}
			if changed(old, e.Record, name) {
				return fmt.Errorf("a received submission cannot be changed (field %q); only its review state and comment can", name)
			}
		}
		return e.Next()
	})

	// Devices: the fields that decide whether a device is trusted are never
	// written through the records API, by anyone, superusers and the
	// Dashboard included; enrolment will go through the server's own route.
	app.OnRecordCreateRequest(schema.Devices).BindFunc(func(e *core.RecordRequestEvent) error {
		if err := refuseDeviceTrustFields(e, nil); err != nil {
			return err
		}
		return e.Next()
	})
	app.OnRecordUpdateRequest(schema.Devices).BindFunc(func(e *core.RecordRequestEvent) error {
		old, err := e.App.FindRecordById(schema.Devices, e.Record.Id)
		if err != nil {
			return fmt.Errorf("could not read the stored device record: %w", err)
		}
		if err := refuseDeviceTrustFields(e, old); err != nil {
			return err
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

	// Superusers: at most schema.MaxSuperusers, whoever creates them (the
	// API, the Dashboard, `obhijatra-server superuser`, Go code). A refused
	// attempt is recorded in the audit chain.
	app.OnRecordCreate(schema.Superusers).BindFunc(func(e *core.RecordEvent) error {
		total, err := e.App.CountRecords(schema.Superusers)
		if err != nil {
			return err
		}
		if total >= schema.MaxSuperusers {
			audit.RecordRefusal(app, e.App, audit.ActorOf(e.App), schema.Superusers, e.Record.Id)
			return router.NewBadRequestError(fmt.Sprintf(
				"This server already has %d superusers, the most it allows. Use an existing superuser, "+
					"or delete one before creating another. This attempt is recorded in the audit chain.", total), nil)
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

// stampPublished makes published_at the server's own record of when a
// version was published: now, when it is published by this write, and empty
// while it is not published. A value sent by the client is ignored.
func stampPublished(r *core.Record) {
	if r.GetBool("published") {
		r.Set("published_at", types.NowDateTime())
	} else {
		r.Set("published_at", "")
	}
}

// refuseDeviceTrustFields refuses a records-API write that sets or changes
// any of schema.DeviceTrustFields: on create (old is nil) any non-empty
// value, on update any change from the stored record old. The answer is
// HTTP 400 with data.<field>.code = "validation_device_field_server_only".
func refuseDeviceTrustFields(e *core.RecordRequestEvent, old *core.Record) error {
	errs := validation.Errors{}
	for _, name := range schema.DeviceTrustFields {
		var touched bool
		if old == nil {
			touched = !isZero(e.Record.Get(name))
		} else {
			touched = changed(old, e.Record, name)
		}
		if touched {
			errs[name] = validation.NewError("validation_device_field_server_only",
				"Only the server sets this field, when it enrols or revokes a device.")
		}
	}
	if len(errs) == 0 {
		return nil
	}
	return e.BadRequestError("Device keys, signature, status and expiry are set only by the server's device "+
		"enrolment (POST "+schema.DeviceEnrolPath+"), not through the records API.", errs)
}

func isZero(v any) bool {
	switch x := v.(type) {
	case nil:
		return true
	case string:
		return x == ""
	case types.DateTime:
		return x.IsZero()
	case []string:
		return len(x) == 0
	}
	b, err := json.Marshal(v)
	return err == nil && (string(b) == `""` || string(b) == "null" || string(b) == "[]")
}

func checkSingleOwner(r *core.Record) error {
	hasField := r.GetString("field_user") != ""
	hasStaff := r.GetString("staff_user") != ""
	if hasField == hasStaff {
		return errors.New("a device belongs to exactly one user: set either field_user or staff_user")
	}
	return nil
}

// checkFormVersion checks the whole XForm file (see package xform) and
// confirms that its form id and version match the form record and the
// version string, so that submissions made with it can be matched back to
// this version. Problems are reported per field, as the API returns them.
func checkFormVersion(app core.App, r *core.Record) error {
	form, err := app.FindRecordById(schema.Forms, r.GetString("form"))
	if err != nil {
		return validation.Errors{"form": validation.NewError("validation_missing_form", "The form for this version does not exist.")}
	}

	if files := r.GetUnsavedFiles("xform"); len(files) > 1 {
		return validation.Errors{"xform": validation.NewError("validation_too_many_files", "Upload exactly one XForm file.")}
	}

	reader, closeFn, err := openXForm(app, r)
	if err != nil {
		return err
	}
	defer closeFn()

	def, err := xform.ParseDefinition(reader)
	if err != nil {
		return xmlFieldError("xform", err)
	}
	if def.FormID != form.GetString("form_id") {
		return validation.Errors{"xform": validation.NewError("validation_xform_mismatch",
			fmt.Sprintf("The XForm's form id is %q but this form's id is %q.", def.FormID, form.GetString("form_id")))}
	}
	if def.Version != r.GetString("version") {
		return validation.Errors{"version": validation.NewError("validation_xform_mismatch",
			fmt.Sprintf("The XForm's version is %q but this record's version is %q.", def.Version, r.GetString("version")))}
	}

	return nil
}

// checkSubmission checks the submission XML (see package xform) and that
// the record's instance id, SHA-256, form and form version agree with it,
// whoever writes the record: the submissions route, Go code or a superuser.
func checkSubmission(app core.App, r *core.Record) error {
	files := r.GetUnsavedFiles("xml")
	if len(files) != 1 {
		return validation.Errors{"xml": validation.NewError("validation_required", "Exactly one submission XML file is required.")}
	}
	if files[0].Size > schema.MaxXMLSize {
		return xmlFieldError("xml", xform.ErrTooLarge)
	}
	f, err := files[0].Reader.Open()
	if err != nil {
		return fmt.Errorf("the submission XML could not be opened: %w", err)
	}
	defer f.Close()

	h := sha256.New()
	inst, err := xform.ParseInstance(io.TeeReader(f, h))
	if err != nil {
		return xmlFieldError("xml", err)
	}

	mismatch := func(field, msg string) error {
		return validation.Errors{field: validation.NewError("validation_submission_mismatch", msg)}
	}
	if r.GetString("xml_sha256") != hex.EncodeToString(h.Sum(nil)) {
		return mismatch("xml_sha256", "xml_sha256 is not the SHA-256 of the submission XML.")
	}
	if r.GetString("instance_id") != inst.InstanceID {
		return mismatch("instance_id", "instance_id is not the submission XML's meta/instanceID.")
	}
	form, err := app.FindRecordById(schema.Forms, r.GetString("form"))
	if err != nil || form.GetString("form_id") != inst.FormID {
		return mismatch("form", "The form is not the one the submission XML names.")
	}
	version, err := app.FindRecordById(schema.FormVersions, r.GetString("form_version"))
	if err != nil || version.GetString("form") != form.Id || version.GetString("version") != inst.Version {
		return mismatch("form_version", "The form version is not the one the submission XML names.")
	}

	return nil
}

// xmlFieldError reports a problem with an uploaded XML file as a field
// validation error, which the API returns as data.<field>.code and
// .message. A failure to read the file is not the uploader's fault and is
// returned unchanged.
func xmlFieldError(field string, err error) error {
	var code string
	switch {
	case errors.Is(err, xform.ErrTooLarge):
		code = "validation_file_size_limit"
	case errors.Is(err, xform.ErrMalformed):
		code = "validation_invalid_xml"
	case errors.Is(err, xform.ErrNotXForm):
		code = "validation_invalid_xform"
	case errors.Is(err, xform.ErrNotInstance):
		code = "validation_invalid_instance"
	default:
		return err
	}
	return validation.Errors{field: validation.NewError(code, "The file is "+err.Error()+".")}
}

func openXForm(app core.App, r *core.Record) (io.Reader, func(), error) {
	if files := r.GetUnsavedFiles("xform"); len(files) > 0 {
		if files[0].Size > schema.MaxXMLSize {
			return nil, nil, xmlFieldError("xform", xform.ErrTooLarge)
		}
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
