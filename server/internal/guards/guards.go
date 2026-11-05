// Package guards holds the Go record hooks that keep Obhijatra's data
// consistent and its integrity rules binding on everyone. API rules protect
// data from ordinary users; these hooks also bind superusers, the Dashboard
// and Go code, because they run on every save, not only on API requests.
package guards

import (
	"bytes"
	"crypto/sha256"
	"database/sql"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"slices"
	"strings"

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
	// One root (the organisation); every other place sits under an open
	// place, with a name of its own among its siblings. A place closes only
	// when nothing open or active is left in it, and is deleted only when
	// nothing uses it.
	app.OnRecordCreate(schema.Locations).BindFunc(func(e *core.RecordEvent) error {
		if err := checkNewPlace(e.App, e.Record); err != nil {
			return err
		}
		return setLocationPath(e)
	})
	onUpdate(app, schema.Locations, func(e *core.RecordEvent, old *core.Record) error {
		if anyChanged(old, e.Record, "parent", "path") {
			return errors.New("a location cannot be moved: its parent and path are fixed once created")
		}
		if anyChanged(old, e.Record, "name", "code", "name_key") {
			if err := checkPlaceText(e.App, e.Record); err != nil {
				return err
			}
		}
		if changed(old, e.Record, "closed") {
			if err := checkPlaceClosing(e.App, e.Record); err != nil {
				return err
			}
		}
		return e.Next()
	})
	// A place's id is part of every path below it, and a deleted place's id
	// must never come back somewhere else, so the server chooses ids.
	app.OnRecordCreateRequest(schema.Locations).BindFunc(func(e *core.RecordRequestEvent) error {
		info, err := e.RequestInfo()
		if err != nil {
			return err
		}
		if _, ok := info.Body["id"]; ok {
			return router.NewBadRequestError("The server chooses place ids.", map[string]validation.Error{
				"id": validation.NewError("validation_place_id_server_only", "The server chooses place ids.")})
		}
		e.Record.Id = ""
		return e.Next()
	})
	app.OnRecordDelete(schema.Locations).BindFunc(func(e *core.RecordEvent) error {
		if err := checkPlaceUnused(e.App, e.Record); err != nil {
			return err
		}
		return e.Next()
	})

	// Users: location_path always follows the location relation, and only
	// an org admin (or the server) may change what a user can see.
	// Every user can sign in somehow, and an org admin by email.
	for _, name := range []string{schema.FieldUsers, schema.StaffUsers} {
		app.OnRecordCreate(name).BindFunc(func(e *core.RecordEvent) error {
			if err := checkUserSignIn(e.Record); err != nil {
				return err
			}
			if err := checkOpenPlace(e.App, e.Record.GetString("location")); err != nil {
				return err
			}
			return syncUserLocationPath(e)
		})
		onUpdate(app, name, func(e *core.RecordEvent, old *core.Record) error {
			actor := audit.ActorOf(e.App)
			self := actor.Collection == name && actor.ID == e.Record.Id
			if anyChanged(old, e.Record, "role", "location", "location_path", "active", schema.MustChangePassword) {
				ok, err := mayAdministerNow(e.App, actor)
				if err != nil {
					return err
				}
				if !ok {
					return errors.New("only an organisation admin can change a user's role, location, active status or one-time password")
				}
			}
			if self && e.Record.GetBool(schema.MustChangePassword) && !old.GetBool(schema.MustChangePassword) {
				return validation.Errors{schema.MustChangePassword: validation.NewError("validation_one_time_password_for_self",
					"You cannot give yourself a one-time password. Ask another organisation admin.")}
			}
			// Choosing your own password ends a one-time password; it must
			// really be new, or the admin who gave it would still know it.
			if settingPassword(e.Record) && self {
				if old.GetBool(schema.MustChangePassword) && old.ValidatePassword(plainPassword(e.Record)) {
					return validation.Errors{"password": validation.NewError("validation_password_unchanged",
						"Choose a new password, not the one-time password.")}
				}
				e.Record.Set(schema.MustChangePassword, false)
			}
			if err := checkUserSignIn(e.Record); err != nil {
				return err
			}
			// Nobody is moved into, or made active again in, a closed place.
			if changed(old, e.Record, "location") || (e.Record.GetBool("active") && !old.GetBool("active")) {
				if err := checkOpenPlace(e.App, e.Record.GetString("location")); err != nil {
					return err
				}
			}
			if name == schema.StaffUsers {
				if err := keepAnOrgAdmin(e.App, old, e.Record); err != nil {
					return err
				}
			}
			// A change to how someone signs in, or to what they may do,
			// ends every session they have: a session started by SMS must
			// not carry on as an org admin, nor outlive a changed number
			// or email address.
			if anyChanged(old, e.Record, "phone", "email", "verified", "role", "active") ||
				(e.Record.GetBool(schema.MustChangePassword) && !old.GetBool(schema.MustChangePassword)) {
				e.Record.RefreshTokenKey()
			}
			return syncUserLocationPath(e)
		})
	}

	// Users, through the records API (the Dashboard included): a write based
	// on a copy that someone else has changed since is refused, so a
	// request already under way cannot undo an admin's reset, demotion or
	// deactivation; and people changing their own password prove the
	// current one, admins included (PocketBase skips that check for
	// anyone with manage access).
	app.OnRecordUpdateRequest(schema.FieldUsers, schema.StaffUsers).BindFunc(func(e *core.RecordRequestEvent) error {
		stored, err := e.App.FindRecordById(e.Record.Collection(), e.Record.Id)
		if err != nil {
			return err
		}
		if stored.GetString("updated") != e.Record.Original().GetString("updated") {
			return router.NewApiError(http.StatusConflict,
				"Someone changed this person a moment ago. Reload, then make your change again.", nil)
		}
		isSelf := e.Auth != nil && e.Auth.Collection().Id == e.Record.Collection().Id && e.Auth.Id == e.Record.Id
		if isSelf && settingPassword(e.Record) {
			info, err := e.RequestInfo()
			if err != nil {
				return err
			}
			current, _ := info.Body["oldPassword"].(string)
			if current == "" || !stored.ValidatePassword(current) {
				return router.NewBadRequestError("The current password is wrong.", map[string]validation.Error{
					"oldPassword": validation.NewError("validation_invalid_old_password", "The current password is wrong."),
				})
			}
		}
		return e.Next()
	})

	// Never delete the last active org admin (the API cannot delete users
	// at all; this binds superusers and Go code).
	app.OnRecordDelete(schema.StaffUsers).BindFunc(func(e *core.RecordEvent) error {
		old, err := stored(e)
		if err != nil {
			return err
		}
		retired := core.NewRecord(e.Record.Collection())
		retired.Id = old.Id
		retired.Set("role", old.GetString("role"))
		retired.Set("active", false)
		if err := keepAnOrgAdmin(e.App, old, retired); err != nil {
			return err
		}
		return e.Next()
	})

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

	// Sessions: identity fields are fixed (a session not yet used by any
	// device is tied to the first one, once); a revoked session stays
	// revoked.
	onUpdate(app, schema.Sessions, func(e *core.RecordEvent, old *core.Record) error {
		if anyChanged(old, e.Record, "field_user", "staff_user", "token_hash", "issued") ||
			(changed(old, e.Record, "device") && old.GetString("device") != "") {
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

// checkUserSignIn refuses a user with neither an email address nor a phone
// number (they could not sign in), a one-time password without an email
// address (nobody could sign in with it), and an org admin without an
// email address (SMS sign-in is not available to org admins, so a swapped
// SIM card cannot take over the accounts that control all the others).
func checkUserSignIn(r *core.Record) error {
	email, phone := r.Email(), r.GetString("phone")
	if email == "" && phone == "" {
		return validation.Errors{"email": validation.NewError("validation_email_or_phone_required",
			"Give an email address or a phone number, so this person can sign in.")}
	}
	if email == "" && r.GetBool(schema.MustChangePassword) {
		return validation.Errors{"email": validation.NewError("validation_one_time_password_needs_email",
			"A one-time password needs an email address to sign in with.")}
	}
	if email == "" && r.Collection().Name == schema.StaffUsers && r.GetString("role") == schema.RoleOrgAdmin {
		return validation.Errors{"email": validation.NewError("validation_org_admin_email_required",
			"An organisation admin needs an email address. SMS sign-in is not available to organisation admins.")}
	}
	return nil
}

// settingPassword reports whether r's password is being set in this write.
func settingPassword(r *core.Record) bool {
	return plainPassword(r) != ""
}

// plainPassword is the password being set on r in this write, or "".
func plainPassword(r *core.Record) string {
	if pv, ok := r.GetRaw(core.FieldNamePassword).(*core.PasswordFieldValue); ok {
		return pv.Plain
	}
	return ""
}

// mayAdministerNow is mayAdminister with an org admin's account read again
// inside the write: still an active org admin, still on the session the
// request started with, and not waiting to change a one-time password.
func mayAdministerNow(app core.App, a audit.Actor) (bool, error) {
	if !mayAdminister(a) {
		return false, nil
	}
	if a.Collection != schema.StaffUsers {
		return true, nil
	}
	r, err := app.FindRecordById(schema.StaffUsers, a.ID)
	if errors.Is(err, sql.ErrNoRows) {
		return false, nil
	}
	if err != nil {
		return false, err
	}
	return r.GetString("role") == schema.RoleOrgAdmin && r.GetBool("active") &&
		!r.GetBool(schema.MustChangePassword) && (a.TokenKey == "" || r.TokenKey() == a.TokenKey), nil
}

// keepAnOrgAdmin refuses a change that would leave the organisation with no
// active org admin: nobody could then manage people, unlock accounts or
// change settings without the server's command line.
func keepAnOrgAdmin(app core.App, old, r *core.Record) error {
	wasAdmin := old.GetString("role") == schema.RoleOrgAdmin && old.GetBool("active")
	isAdmin := r.GetString("role") == schema.RoleOrgAdmin && r.GetBool("active")
	if !wasAdmin || isAdmin {
		return nil
	}
	others, err := app.CountRecords(schema.StaffUsers, dbx.HashExp{"role": schema.RoleOrgAdmin, "active": true},
		dbx.Not(dbx.HashExp{"id": r.Id}))
	if err != nil {
		return err
	}
	if others == 0 {
		return validation.Errors{"role": validation.NewError("validation_last_org_admin",
			"This is the only active organisation admin. Make someone else an organisation admin first.")}
	}
	return nil
}

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

// ---------------------------------------------------------------------
// Places
// ---------------------------------------------------------------------

func placeError(field, code, message string) error {
	return validation.Errors{field: validation.NewError(code, message)}
}

// checkNewPlace: one root, a parent that is open, and a name of its own.
func checkNewPlace(app core.App, r *core.Record) error {
	if r.GetBool("closed") {
		return placeError("closed", "validation_place_closed_on_create", "A new place cannot start closed.")
	}
	if r.GetString("parent") == "" {
		total, err := app.CountRecords(schema.Locations)
		if err != nil {
			return err
		}
		if total > 0 {
			return placeError("parent", "validation_place_parent_required",
				"Choose the place this one belongs under. Only the organisation itself has nothing above it.")
		}
		return checkPlaceText(app, r)
	}
	if err := checkOpenPlace(app, r.GetString("parent")); err != nil {
		return validation.Errors{"parent": validation.NewError("validation_place_parent_closed",
			"The place above is closed. Reopen it first, or choose an open place.")}
	}
	return checkPlaceText(app, r)
}

// checkPlaceText cleans the name and code and refuses an empty name,
// unsafe characters, or a name a sibling already has. Names are compared
// by schema.PlaceNameKey (Unicode NFC, invisible characters and extra
// spaces removed, capitals ignored), so a place is never confused with its
// neighbour and a spreadsheet import finds it again; the unique index on
// (parent, name_key) holds the same line in the database.
func checkPlaceText(app core.App, r *core.Record) error {
	name := schema.CleanPlaceName(r.GetString("name"))
	code := strings.TrimSpace(r.GetString("code"))
	r.Set("name", name)
	r.Set("code", code)
	r.Set("name_key", schema.PlaceNameKey(name))
	switch {
	case name == "":
		return placeError("name", "validation_required", "Give the place a name.")
	case strings.ContainsFunc(name, schema.UnsafeTextRune):
		return placeError("name", "validation_place_text_unsafe",
			"The name has a line break or a hidden control character. Type it again.")
	case strings.ContainsFunc(code, schema.UnsafeTextRune):
		return placeError("code", "validation_place_text_unsafe",
			"The code has a line break or a hidden control character. Type it again.")
	}
	_, err := app.FindFirstRecordByFilter(schema.Locations,
		"parent = {:parent} && name_key = {:key} && id != {:id}",
		dbx.Params{"parent": r.GetString("parent"), "key": r.GetString("name_key"), "id": r.Id})
	switch {
	case err == nil:
		return placeError("name", "validation_place_name_taken",
			"Another place at this level already has this name. Choose a different name.")
	case !errors.Is(err, sql.ErrNoRows):
		return err
	}
	return nil
}

// checkOpenPlace refuses a place id that does not exist or is closed.
func checkOpenPlace(app core.App, id string) error {
	if id == "" {
		return nil // the relation field decides whether a place is required
	}
	p, err := app.FindRecordById(schema.Locations, id)
	if err != nil {
		return placeError("location", "validation_place_missing", "This place does not exist.")
	}
	if p.GetBool("closed") {
		return placeError("location", "validation_place_closed", "This place is closed. Choose an open place.")
	}
	return nil
}

// checkPlaceClosing: the organisation itself never closes; a place closes
// only when no open place and no active person is left in it; it reopens
// only under an open place.
func checkPlaceClosing(app core.App, r *core.Record) error {
	if !r.GetBool("closed") {
		if parent := r.GetString("parent"); parent != "" {
			if err := checkOpenPlace(app, parent); err != nil {
				return placeError("closed", "validation_place_parent_closed",
					"The place above is closed. Reopen it first.")
			}
		}
		return nil
	}
	if r.GetString("parent") == "" {
		return placeError("closed", "validation_place_root", "The organisation itself cannot be closed.")
	}
	open, err := app.CountRecords(schema.Locations, dbx.HashExp{"parent": r.Id, "closed": false})
	if err != nil {
		return err
	}
	if open > 0 {
		return placeError("closed", "validation_place_has_open_places",
			fmt.Sprintf("%d open place(s) are inside this place. Close or delete them first.", open))
	}
	people := 0
	for _, c := range []string{schema.FieldUsers, schema.StaffUsers} {
		n, err := app.CountRecords(c, dbx.HashExp{"location": r.Id, "active": true})
		if err != nil {
			return err
		}
		people += int(n)
	}
	if people > 0 {
		return placeError("closed", "validation_place_has_people",
			fmt.Sprintf("%d active person(s) work here. Move them to another place, or deactivate them, first.", people))
	}
	return nil
}

// checkPlaceUnused allows deleting a place only when nothing refers to it:
// no place inside it, nobody assigned to it, and no record stamped with its
// path, in any collection, so that records never point at a missing place.
// The organisation itself is never deleted. The convention every
// collection follows: a place is referred to by a relation to locations or
// by a text field named location_path (docs/decisions/0007-places.md).
func checkPlaceUnused(app core.App, r *core.Record) error {
	old, err := app.FindRecordById(schema.Locations, r.Id)
	if err != nil {
		return err
	}
	if old.GetString("parent") == "" {
		return placeError("id", "validation_place_root", "The organisation itself cannot be deleted.")
	}
	locations, err := app.FindCollectionByNameOrId(schema.Locations)
	if err != nil {
		return err
	}
	collections, err := app.FindAllCollections()
	if err != nil {
		return err
	}
	uses := 0
	for _, c := range collections {
		if c.IsView() {
			continue
		}
		for _, f := range c.Fields {
			var n int64
			switch field := f.(type) {
			case *core.RelationField:
				if field.CollectionId != locations.Id {
					continue
				}
				if field.IsMultiple() {
					n, err = app.CountRecords(c, dbx.NewExp("EXISTS (SELECT 1 FROM json_each([["+field.Name+"]]) WHERE value = {:id})",
						dbx.Params{"id": r.Id}))
				} else {
					n, err = app.CountRecords(c, dbx.HashExp{field.Name: r.Id})
				}
			case *core.TextField:
				if field.Name != "location_path" {
					continue
				}
				n, err = app.CountRecords(c, dbx.HashExp{"location_path": old.GetString("path")})
			default:
				continue
			}
			if err != nil {
				return err
			}
			uses += int(n)
		}
	}
	if uses > 0 {
		const msg = "This place is still used by places inside it, people or records, so it cannot be deleted. Close it instead."
		return router.NewBadRequestError(msg, map[string]validation.Error{"id": validation.NewError("validation_place_in_use", msg)})
	}
	return nil
}
