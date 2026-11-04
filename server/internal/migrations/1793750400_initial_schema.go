// Package migrations holds Obhijatra's Go migrations. Each file registers
// one migration with PocketBase; the file name (a Unix timestamp plus a
// description) fixes the order. Importing this package for its side effect
// is enough to make `serve` and `init` apply them.
package migrations

import (
	"errors"
	"fmt"

	"ganigeorgiev.com/pocketbase/pocketbase/core"
	m "ganigeorgiev.com/pocketbase/pocketbase/migrations"
	"ganigeorgiev.com/pocketbase/pocketbase/tools/types"

	"github.com/obhijatra/obhijatra/server/internal/schema"
)

var xmlMimeTypes = []string{"text/xml", "application/xml"}

func init() {
	m.Register(initialSchemaUp, initialSchemaDown)
}

func initialSchemaUp(app core.App) error {
	steps := []struct {
		name string
		fn   func(core.App) error
	}{
		// The audit collection comes first so that every later step is
		// itself recorded in the chain when the hooks are active.
		{schema.Audit, createAudit},
		{"default users collection", removeDefaultUsers},
		{schema.Superusers, hardenSuperusers},
		{schema.Settings, createSettings},
		{schema.Locations, createLocations},
		{schema.StaffUsers, func(a core.App) error { return createUsers(a, schema.StaffUsers) }},
		{schema.FieldUsers, func(a core.App) error { return createUsers(a, schema.FieldUsers) }},
		{schema.Forms, createForms},
		{schema.FormVersions, createFormVersions},
		{schema.Devices, createDevices},
		{schema.Sessions, createSessions},
		{schema.Submissions, createSubmissions},
	}

	for _, s := range steps {
		if err := s.fn(app); err != nil {
			return fmt.Errorf("initial schema, %s: %w", s.name, err)
		}
	}

	return nil
}

// initialSchemaDown refuses: rolling back the first schema would delete the
// audit chain and every submission. Restore from a backup instead.
func initialSchemaDown(app core.App) error {
	return errors.New("the initial Obhijatra schema cannot be rolled back; restore a backup instead")
}

// ---------------------------------------------------------------------

func autodates(c *core.Collection) {
	c.Fields.Add(&core.AutodateField{Name: "created", OnCreate: true})
	c.Fields.Add(&core.AutodateField{Name: "updated", OnCreate: true, OnUpdate: true})
}

func relationTo(app core.App, name, field string, required bool) (*core.RelationField, error) {
	target, err := app.FindCollectionByNameOrId(name)
	if err != nil {
		return nil, fmt.Errorf("missing collection %q: %w", name, err)
	}
	return &core.RelationField{
		Name:         field,
		CollectionId: target.Id,
		MaxSelect:    1,
		Required:     required,
	}, nil
}

func locationPathField() *core.TextField {
	return &core.TextField{
		Name:     "location_path",
		Required: true,
		Max:      1000,
		Pattern:  schema.LocationPathPattern,
	}
}

// ---------------------------------------------------------------------

func createAudit(app core.App) error {
	c := core.NewBaseCollection(schema.Audit)
	c.ListRule = types.Pointer(schema.AuditRead)
	c.ViewRule = types.Pointer(schema.AuditRead)
	// CreateRule, UpdateRule and DeleteRule stay nil: no API at all for
	// ordinary users; the audit hooks reject superusers too.

	one := 1.0
	c.Fields.Add(&core.NumberField{Name: "seq", Required: true, OnlyInt: true, Min: &one})
	c.Fields.Add(&core.TextField{Name: "actor", Max: 100})
	c.Fields.Add(&core.TextField{Name: "actor_collection", Max: 100})
	c.Fields.Add(&core.TextField{Name: "device", Max: 100})
	c.Fields.Add(&core.SelectField{Name: "action", MaxSelect: 1, Required: true, Values: []string{"create", "update", "delete"}})
	c.Fields.Add(&core.TextField{Name: "collection", Max: 100})
	c.Fields.Add(&core.TextField{Name: "record_id", Max: 100})
	c.Fields.Add(&core.TextField{Name: "before_hash", Max: 64})
	c.Fields.Add(&core.TextField{Name: "after_hash", Max: 64})
	c.Fields.Add(&core.TextField{Name: "at", Required: true, Max: 40})
	c.Fields.Add(&core.TextField{Name: "prev_hash", Required: true, Max: 64})
	c.Fields.Add(&core.TextField{Name: "hash", Required: true, Max: 64})

	c.AddIndex("idx_audit_seq", true, "`seq`", "")
	c.AddIndex("idx_audit_record", false, "`collection`, `record_id`", "")
	c.AddIndex("idx_audit_actor", false, "`actor`", "")

	return app.Save(c)
}

// removeDefaultUsers deletes PocketBase's sample "users" collection, which
// allows public sign-up. If it already holds records it is kept but its
// public create rule is removed.
func removeDefaultUsers(app core.App) error {
	users, err := app.FindCollectionByNameOrId("users")
	if err != nil {
		return nil // already gone
	}

	total, err := app.CountRecords(users)
	if err != nil {
		return err
	}
	if total == 0 {
		return app.Delete(users)
	}

	users.CreateRule = nil
	return app.Save(users)
}

// hardenSuperusers sets the superuser session to 30 minutes and the
// minimum password length to 12, as the blueprint requires.
func hardenSuperusers(app core.App) error {
	su, err := app.FindCollectionByNameOrId(schema.Superusers)
	if err != nil {
		return err
	}
	su.AuthToken.Duration = 30 * 60
	if pf, ok := su.Fields.GetByName("password").(*core.PasswordField); ok {
		pf.Min = 12
	}
	return app.Save(su)
}

func createSettings(app core.App) error {
	c := core.NewBaseCollection(schema.Settings)
	c.ListRule = types.Pointer(schema.SettingsRead)
	c.ViewRule = types.Pointer(schema.SettingsRead)
	c.UpdateRule = types.Pointer(schema.SettingsUpdate)
	// One record, created by `obhijatra-server init`; no create or delete API.

	one := 1.0
	c.Fields.Add(&core.TextField{Name: "organisation_name", Required: true, Max: 200, Presentable: true})
	c.Fields.Add(&core.TextField{Name: "hosting_country", Required: true, Min: 2, Max: 2, Pattern: `^[A-Z]{2}$`,
		Help: "ISO 3166-1 alpha-2 code of the country where this server and its data are hosted"})
	c.Fields.Add(&core.NumberField{Name: "schema_version", Required: true, OnlyInt: true, Min: &one})
	autodates(c)

	return app.Save(c)
}

func createLocations(app core.App) error {
	c := core.NewBaseCollection(schema.Locations)
	c.ListRule = types.Pointer(schema.LocationsRead)
	c.ViewRule = types.Pointer(schema.LocationsRead)
	c.CreateRule = types.Pointer(schema.LocationsWrite)
	c.UpdateRule = types.Pointer(schema.LocationsWrite)
	// No delete API: records and users keep copies of location paths.

	c.Fields.Add(&core.TextField{Name: "name", Required: true, Max: 200, Presentable: true})
	c.Fields.Add(&core.TextField{Name: "code", Max: 50})
	c.Fields.Add(&core.TextField{Name: "path", Required: true, Max: 1000, Pattern: schema.LocationPathPattern,
		Help: "Set by the server from the parent; cannot be changed"})
	autodates(c)
	c.AddIndex("idx_locations_path", true, "`path`", "")

	if err := app.Save(c); err != nil {
		return err
	}

	// The self-relation needs the collection id, so it is added afterwards.
	c.Fields.Add(&core.RelationField{Name: "parent", CollectionId: c.Id, MaxSelect: 1})
	c.AddIndex("idx_locations_parent", false, "`parent`", "")

	return app.Save(c)
}

func createUsers(app core.App, name string) error {
	c := core.NewAuthCollection(name)

	var roles []string
	switch name {
	case schema.FieldUsers:
		roles = []string{schema.RoleFieldOfficer}
		c.ListRule = types.Pointer(schema.FieldUsersRead)
		c.ViewRule = types.Pointer(schema.FieldUsersRead)
		c.CreateRule = types.Pointer(schema.FieldUsersCreate)
		c.UpdateRule = types.Pointer(schema.FieldUsersUpdate)
		c.ManageRule = types.Pointer(schema.FieldUsersManage)
		c.AuthToken.Duration = 24 * 60 * 60
	case schema.StaffUsers:
		roles = schema.StaffRoles
		c.ListRule = types.Pointer(schema.StaffUsersRead)
		c.ViewRule = types.Pointer(schema.StaffUsersRead)
		c.CreateRule = types.Pointer(schema.StaffUsersCreate)
		c.UpdateRule = types.Pointer(schema.StaffUsersUpdate)
		c.ManageRule = types.Pointer(schema.StaffUsersManage)
		c.AuthToken.Duration = 4 * 60 * 60
	default:
		return fmt.Errorf("unknown user collection %q", name)
	}
	// DeleteRule stays nil: accounts are deactivated, never deleted, so the
	// audit trail and submissions keep pointing at them.
	c.AuthRule = types.Pointer(schema.AuthRule)
	c.PasswordAuth.Enabled = true
	c.PasswordAuth.IdentityFields = []string{"email"}
	c.OAuth2.Enabled = false
	c.OTP.Enabled = false
	c.MFA.Enabled = false

	if pf, ok := c.Fields.GetByName("password").(*core.PasswordField); ok {
		pf.Min = 12
	}

	location, err := relationTo(app, schema.Locations, "location", true)
	if err != nil {
		return err
	}

	c.Fields.Add(&core.TextField{Name: "name", Max: 200, Presentable: true})
	c.Fields.Add(&core.SelectField{Name: "role", Required: true, MaxSelect: 1, Values: roles})
	c.Fields.Add(location)
	c.Fields.Add(locationPathField())
	c.Fields.Add(&core.BoolField{Name: "active"})
	autodates(c)
	c.AddIndex("idx_"+name+"_location_path", false, "`location_path`", "")

	return app.Save(c)
}

func createForms(app core.App) error {
	c := core.NewBaseCollection(schema.Forms)
	c.ListRule = types.Pointer(schema.FormsRead)
	c.ViewRule = types.Pointer(schema.FormsRead)
	c.CreateRule = types.Pointer(schema.FormsWrite)
	c.UpdateRule = types.Pointer(schema.FormsWrite)
	c.DeleteRule = types.Pointer(schema.FormsWrite)

	c.Fields.Add(&core.TextField{Name: "form_id", Required: true, Max: 255,
		Help: "The id attribute of the XForm's primary instance"})
	c.Fields.Add(&core.TextField{Name: "title", Max: 255, Presentable: true})
	autodates(c)
	c.AddIndex("idx_forms_form_id", true, "`form_id`", "")

	return app.Save(c)
}

func createFormVersions(app core.App) error {
	c := core.NewBaseCollection(schema.FormVersions)
	c.ListRule = types.Pointer(schema.FormVersionsRead)
	c.ViewRule = types.Pointer(schema.FormVersionsRead)
	c.CreateRule = types.Pointer(schema.FormVersionsCreate)
	c.UpdateRule = types.Pointer(schema.FormVersionsUpdate)
	c.DeleteRule = types.Pointer(schema.FormVersionsDelete)

	form, err := relationTo(app, schema.Forms, "form", true)
	if err != nil {
		return err
	}

	c.Fields.Add(form)
	c.Fields.Add(&core.TextField{Name: "version", Required: true, Max: 255,
		Help: "Must equal the version attribute of the XForm's primary instance"})
	c.Fields.Add(&core.FileField{Name: "xform", Required: true, MaxSelect: 1, MaxSize: schema.MaxXMLSize, MimeTypes: xmlMimeTypes})
	c.Fields.Add(&core.BoolField{Name: "published"})
	c.Fields.Add(&core.DateField{Name: "published_at"})
	autodates(c)
	c.AddIndex("idx_form_versions_form_version", true, "`form`, `version`", "")

	return app.Save(c)
}

func createDevices(app core.App) error {
	c := core.NewBaseCollection(schema.Devices)
	c.ListRule = types.Pointer(schema.DevicesRead)
	c.ViewRule = types.Pointer(schema.DevicesRead)
	c.CreateRule = types.Pointer(schema.DevicesWrite)
	c.UpdateRule = types.Pointer(schema.DevicesWrite)
	// No delete API: a device is revoked, never deleted.

	fieldUser, err := relationTo(app, schema.FieldUsers, "field_user", false)
	if err != nil {
		return err
	}
	staffUser, err := relationTo(app, schema.StaffUsers, "staff_user", false)
	if err != nil {
		return err
	}
	enrolledBy, err := relationTo(app, schema.StaffUsers, "enrolled_by", false)
	if err != nil {
		return err
	}

	c.Fields.Add(fieldUser)
	c.Fields.Add(staffUser)
	c.Fields.Add(&core.TextField{Name: "label", Max: 100, Presentable: true})
	// Placeholders for the zero-trust milestone: base64 public keys made on
	// the device with libsodium, and the organisation's Ed25519 signature
	// over the device record.
	c.Fields.Add(&core.TextField{Name: "sign_public_key", Max: 200, Help: "Ed25519 public key, base64 (zero-trust milestone)"})
	c.Fields.Add(&core.TextField{Name: "enc_public_key", Max: 200, Help: "X25519 public key, base64 (zero-trust milestone)"})
	c.Fields.Add(&core.TextField{Name: "org_signature", Max: 500, Help: "Organisation signature over the device record (zero-trust milestone)"})
	c.Fields.Add(&core.SelectField{Name: "status", Required: true, MaxSelect: 1,
		Values: []string{schema.DeviceActive, schema.DeviceRevoked}})
	c.Fields.Add(&core.SelectField{Name: "attestation_level", Required: true, MaxSelect: 1,
		Values: []string{schema.AttestationNone, schema.AttestationSoftware, schema.AttestationHardware}})
	c.Fields.Add(enrolledBy)
	c.Fields.Add(&core.DateField{Name: "expires"})
	c.Fields.Add(&core.DateField{Name: "revoked_at"})
	autodates(c)
	c.AddIndex("idx_devices_field_user", false, "`field_user`", "")
	c.AddIndex("idx_devices_staff_user", false, "`staff_user`", "")

	return app.Save(c)
}

func createSessions(app core.App) error {
	c := core.NewBaseCollection(schema.Sessions)
	c.ListRule = types.Pointer(schema.SessionsRead)
	c.ViewRule = types.Pointer(schema.SessionsRead)
	c.UpdateRule = types.Pointer(schema.SessionsUpdate)
	// No create or delete API: the sessions middleware (zero-trust
	// milestone) writes rows; revocation is an update.

	fieldUser, err := relationTo(app, schema.FieldUsers, "field_user", false)
	if err != nil {
		return err
	}
	staffUser, err := relationTo(app, schema.StaffUsers, "staff_user", false)
	if err != nil {
		return err
	}
	device, err := relationTo(app, schema.Devices, "device", false)
	if err != nil {
		return err
	}

	c.Fields.Add(fieldUser)
	c.Fields.Add(staffUser)
	c.Fields.Add(device)
	c.Fields.Add(&core.TextField{Name: "token_hash", Hidden: true, Max: 64, Pattern: `^[a-f0-9]{64}$`,
		Help: "SHA-256 of the session token, hex; never returned by the API"})
	c.Fields.Add(&core.DateField{Name: "issued"})
	c.Fields.Add(&core.DateField{Name: "last_seen"})
	c.Fields.Add(&core.BoolField{Name: "revoked"})
	c.Fields.Add(&core.DateField{Name: "revoked_at"})
	autodates(c)
	c.AddIndex("idx_sessions_token_hash", true, "`token_hash`", "`token_hash` != ''")

	return app.Save(c)
}

func createSubmissions(app core.App) error {
	c := core.NewBaseCollection(schema.Submissions)
	c.ListRule = types.Pointer(schema.SubmissionsRead)
	c.ViewRule = types.Pointer(schema.SubmissionsRead)
	c.UpdateRule = types.Pointer(schema.SubmissionsUpdate)
	// CreateRule nil: submissions arrive only through
	// POST /api/obhijatra/v1/submissions. DeleteRule nil: superusers only,
	// and every delete is in the audit chain.

	form, err := relationTo(app, schema.Forms, "form", true)
	if err != nil {
		return err
	}
	formVersion, err := relationTo(app, schema.FormVersions, "form_version", true)
	if err != nil {
		return err
	}
	submittedBy, err := relationTo(app, schema.FieldUsers, "submitted_by", true)
	if err != nil {
		return err
	}
	device, err := relationTo(app, schema.Devices, "device", false)
	if err != nil {
		return err
	}

	c.Fields.Add(&core.TextField{Name: "instance_id", Required: true, Max: 128, Presentable: true})
	c.Fields.Add(form)
	c.Fields.Add(formVersion)
	c.Fields.Add(&core.FileField{Name: "xml", Required: true, MaxSelect: 1, MaxSize: schema.MaxXMLSize,
		MimeTypes: xmlMimeTypes, Protected: true})
	c.Fields.Add(&core.TextField{Name: "xml_sha256", Required: true, Min: 64, Max: 64, Pattern: `^[a-f0-9]{64}$`})
	c.Fields.Add(&core.FileField{Name: "attachments", MaxSelect: schema.MaxAttachments, MaxSize: schema.MaxAttachmentSize, Protected: true})
	c.Fields.Add(&core.JSONField{Name: "attachments_manifest", MaxSize: 64 * 1024,
		Help: "One entry per attachment: original file name, stored name, SHA-256 and size"})
	c.Fields.Add(submittedBy)
	c.Fields.Add(device)
	c.Fields.Add(locationPathField())
	c.Fields.Add(&core.SelectField{Name: "review_state", Required: true, MaxSelect: 1, Values: schema.ReviewStates})
	c.Fields.Add(&core.AutodateField{Name: "received_at", OnCreate: true})
	c.Fields.Add(&core.AutodateField{Name: "updated", OnCreate: true, OnUpdate: true})

	c.AddIndex("idx_submissions_instance_id", true, "`instance_id`", "")
	c.AddIndex("idx_submissions_location_path", false, "`location_path`", "")
	c.AddIndex("idx_submissions_submitted_by", false, "`submitted_by`", "")
	c.AddIndex("idx_submissions_form_version", false, "`form`, `form_version`", "")

	return app.Save(c)
}
