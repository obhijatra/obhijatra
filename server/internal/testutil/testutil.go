// Package testutil builds fresh Obhijatra test servers and sample data for
// the integration tests. It uses PocketBase's tests package.
package testutil

import (
	"bytes"
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"mime/multipart"
	"net/textproto"
	"testing"

	"ganigeorgiev.com/pocketbase/pocketbase/core"
	"ganigeorgiev.com/pocketbase/pocketbase/tests"
	"ganigeorgiev.com/pocketbase/pocketbase/tools/filesystem"
	"ganigeorgiev.com/pocketbase/pocketbase/tools/hook"

	"github.com/obhijatra/obhijatra/server/internal/obhijatra"
	"github.com/obhijatra/obhijatra/server/internal/schema"
)

// Password is used for every test account.
const Password = "correct-horse-battery-1"

// FormID and FormVersion describe the sample form.
const (
	FormID      = "household_visit"
	FormVersion = "2026110401"
)

// NewApp starts a test app on a brand-new, empty pb_data folder, applies
// every migration and registers Obhijatra's hooks and routes.
func NewApp(t testing.TB) *tests.TestApp {
	t.Helper()

	app, err := tests.NewTestApp(t.TempDir())
	if err != nil {
		t.Fatalf("create test app: %v", err)
	}
	obhijatra.Register(app)
	app.OnServe().Bind(&hook.Handler[*core.ServeEvent]{
		Id: "obhijatraTestAutoSignBinder",
		Func: func(se *core.ServeEvent) error {
			se.Router.Bind(autoSign())
			return se.Next()
		},
	})

	return app
}

// Org is a small organisation: a root, two branches, staff and field users
// in each branch, one inactive field user and a published form.
type Org struct {
	Root, Branch1, Branch2 *core.Record

	Admin  *core.Record // org_admin at the root
	Donor  *core.Record // donor_readonly at the root
	Sup1   *core.Record // supervisor, branch 1
	Sup2   *core.Record // supervisor, branch 2
	ME1    *core.Record // monitoring and evaluation officer, branch 1
	Field1 *core.Record // field officer, branch 1
	Peer1  *core.Record // a second field officer, branch 1
	Field2 *core.Record // field officer, branch 2
	Gone1  *core.Record // inactive field officer, branch 1

	Form        *core.Record
	Version     *core.Record // published
	Unpublished *core.Record
}

// SeedOrg creates an Org in app.
func SeedOrg(t testing.TB, app core.App) *Org {
	t.Helper()

	o := &Org{}
	o.Root = save(t, app, schema.Locations, map[string]any{"name": "Head office"})
	o.Branch1 = save(t, app, schema.Locations, map[string]any{"name": "Branch 1", "parent": o.Root.Id})
	o.Branch2 = save(t, app, schema.Locations, map[string]any{"name": "Branch 2", "parent": o.Root.Id})

	o.Admin = User(t, app, schema.StaffUsers, "admin@example.org", schema.RoleOrgAdmin, o.Root, true)
	o.Donor = User(t, app, schema.StaffUsers, "donor@example.org", schema.RoleDonorReadonly, o.Root, true)
	o.Sup1 = User(t, app, schema.StaffUsers, "sup1@example.org", schema.RoleSupervisor, o.Branch1, true)
	o.Sup2 = User(t, app, schema.StaffUsers, "sup2@example.org", schema.RoleSupervisor, o.Branch2, true)
	o.ME1 = User(t, app, schema.StaffUsers, "me1@example.org", schema.RoleME, o.Branch1, true)
	o.Field1 = User(t, app, schema.FieldUsers, "field1@example.org", schema.RoleFieldOfficer, o.Branch1, true)
	o.Peer1 = User(t, app, schema.FieldUsers, "peer1@example.org", schema.RoleFieldOfficer, o.Branch1, true)
	o.Field2 = User(t, app, schema.FieldUsers, "field2@example.org", schema.RoleFieldOfficer, o.Branch2, true)
	o.Gone1 = User(t, app, schema.FieldUsers, "gone1@example.org", schema.RoleFieldOfficer, o.Branch1, false)

	o.Form = save(t, app, schema.Forms, map[string]any{"form_id": FormID, "title": "Household visit"})
	o.Version = FormVersionRecord(t, app, o.Form, FormVersion, true)
	o.Unpublished = FormVersionRecord(t, app, o.Form, "2026110402", false)

	return o
}

// Location creates a location named name under parent (nil for a root).
func Location(t testing.TB, app core.App, name string, parent *core.Record) *core.Record {
	t.Helper()

	data := map[string]any{"name": name}
	if parent != nil {
		data["parent"] = parent.Id
	}
	return save(t, app, schema.Locations, data)
}

// User creates a field or staff user.
func User(t testing.TB, app core.App, collection, email, role string, location *core.Record, active bool) *core.Record {
	t.Helper()

	col, err := app.FindCollectionByNameOrId(collection)
	if err != nil {
		t.Fatal(err)
	}
	r := core.NewRecord(col)
	r.SetEmail(email)
	r.SetPassword(Password)
	r.SetVerified(true)
	r.Set("name", email)
	r.Set("role", role)
	r.Set("location", location.Id)
	r.Set("active", active)
	if err := app.Save(r); err != nil {
		t.Fatalf("create %s %s: %v", collection, email, err)
	}
	return r
}

// FormVersionRecord uploads the sample XForm as a version of form.
func FormVersionRecord(t testing.TB, app core.App, form *core.Record, version string, published bool) *core.Record {
	t.Helper()

	f, err := filesystem.NewFileFromBytes(XForm(FormID, version), FormID+".xml")
	if err != nil {
		t.Fatal(err)
	}
	return save(t, app, schema.FormVersions, map[string]any{
		"form":      form.Id,
		"version":   version,
		"xform":     f,
		"published": published,
	})
}

// Submission stores a submission by user directly (not through the API).
func Submission(t testing.TB, app core.App, o *Org, user *core.Record, instanceID string) *core.Record {
	t.Helper()

	xml := Instance(instanceID, FormVersion, 4)
	f, err := filesystem.NewFileFromBytes(xml, "submission.xml")
	if err != nil {
		t.Fatal(err)
	}
	sum := sha256.Sum256(xml)

	return save(t, app, schema.Submissions, map[string]any{
		"instance_id":   instanceID,
		"form":          o.Form.Id,
		"form_version":  o.Version.Id,
		"xml":           f,
		"xml_sha256":    hex.EncodeToString(sum[:]),
		"submitted_by":  user.Id,
		"location_path": user.GetString("location_path"),
		"review_state":  schema.ReviewReceived,
	})
}

// Token returns a valid auth token for r.
func Token(t testing.TB, r *core.Record) string {
	t.Helper()

	token, err := r.NewAuthToken()
	if err != nil {
		t.Fatal(err)
	}
	return token
}

// FileToken returns a short-lived file token for r, as POST /api/files/token
// would.
func FileToken(t testing.TB, r *core.Record) string {
	t.Helper()

	token, err := r.NewFileToken()
	if err != nil {
		t.Fatal(err)
	}
	return token
}

// FormVersionUpload builds a records-API request body that uploads xform as
// a version of the form record formID.
func FormVersionUpload(t testing.TB, formID, version string, xform []byte, published bool) (body *bytes.Buffer, contentType string) {
	t.Helper()

	body = &bytes.Buffer{}
	w := multipart.NewWriter(body)
	for k, v := range map[string]string{"form": formID, "version": version, "published": fmt.Sprint(published)} {
		if err := w.WriteField(k, v); err != nil {
			t.Fatal(err)
		}
	}
	part, err := w.CreateFormFile("xform", "form.xml")
	if err != nil {
		t.Fatal(err)
	}
	part.Write(xform)
	if err := w.Close(); err != nil {
		t.Fatal(err)
	}
	return body, w.FormDataContentType()
}

// Superuser creates a superuser and returns it.
func Superuser(t testing.TB, app core.App) *core.Record {
	t.Helper()
	return saveAuth(t, app, core.CollectionNameSuperusers, "root@example.org")
}

func saveAuth(t testing.TB, app core.App, collection, email string) *core.Record {
	t.Helper()

	col, err := app.FindCollectionByNameOrId(collection)
	if err != nil {
		t.Fatal(err)
	}
	r := core.NewRecord(col)
	r.SetEmail(email)
	r.SetPassword(Password)
	if err := app.Save(r); err != nil {
		t.Fatal(err)
	}
	return r
}

func save(t testing.TB, app core.App, collection string, data map[string]any) *core.Record {
	t.Helper()

	col, err := app.FindCollectionByNameOrId(collection)
	if err != nil {
		t.Fatal(err)
	}
	r := core.NewRecord(col)
	for k, v := range data {
		r.Set(k, v)
	}
	if err := app.Save(r); err != nil {
		t.Fatalf("create %s: %v", collection, err)
	}
	return r
}

// XForm returns a minimal ODK XForm definition.
func XForm(formID, version string) []byte {
	return fmt.Appendf(nil, `<?xml version="1.0"?>
<h:html xmlns="http://www.w3.org/2002/xforms" xmlns:h="http://www.w3.org/1999/xhtml" xmlns:jr="http://openrosa.org/javarosa" xmlns:orx="http://openrosa.org/xforms">
  <h:head>
    <h:title>Household visit</h:title>
    <model>
      <instance>
        <data id="%s" version="%s">
          <household_size/>
          <meta><instanceID/></meta>
        </data>
      </instance>
      <instance id="villages" src="jr://file-csv/villages.csv"/>
      <bind nodeset="/data/household_size" type="int"/>
      <bind nodeset="/data/meta/instanceID" type="string" readonly="true()" jr:preload="uid"/>
    </model>
  </h:head>
  <h:body>
    <input ref="/data/household_size"><label>Household size</label></input>
  </h:body>
</h:html>
`, formID, version)
}

// Instance returns a filled-in submission of the sample form.
func Instance(instanceID, version string, householdSize int) []byte {
	return fmt.Appendf(nil, `<?xml version='1.0' ?><data id="%s" version="%s" xmlns:orx="http://openrosa.org/xforms"><household_size>%d</household_size><orx:meta><orx:instanceID>%s</orx:instanceID></orx:meta></data>`,
		FormID, version, householdSize, instanceID)
}

// Multipart builds a submission request body: the XML as
// xml_submission_file plus any attachments (name -> content).
func Multipart(t testing.TB, xml []byte, attachments map[string][]byte) (body *bytes.Buffer, contentType string) {
	t.Helper()

	body = &bytes.Buffer{}
	w := multipart.NewWriter(body)

	h := textproto.MIMEHeader{}
	h.Set("Content-Disposition", `form-data; name="xml_submission_file"; filename="submission.xml"`)
	h.Set("Content-Type", "text/xml")
	part, err := w.CreatePart(h)
	if err != nil {
		t.Fatal(err)
	}
	part.Write(xml)

	for name, content := range attachments {
		part, err := w.CreateFormFile(name, name)
		if err != nil {
			t.Fatal(err)
		}
		part.Write(content)
	}

	if err := w.Close(); err != nil {
		t.Fatal(err)
	}
	return body, w.FormDataContentType()
}
