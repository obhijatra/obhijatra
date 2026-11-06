package obhijatra_test

import (
	"archive/zip"
	"bytes"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"ganigeorgiev.com/pocketbase/dbx"
	"ganigeorgiev.com/pocketbase/pocketbase/core"
	"ganigeorgiev.com/pocketbase/pocketbase/tools/filesystem"
	"ganigeorgiev.com/pocketbase/pocketbase/tools/types"

	"github.com/obhijatra/obhijatra/server/internal/api"
	"github.com/obhijatra/obhijatra/server/internal/audit"
	"github.com/obhijatra/obhijatra/server/internal/schema"
	"github.com/obhijatra/obhijatra/server/internal/testutil"
)

const exportURL = api.Prefix + api.ExportSubmissionsPath

// A visit form with a Bangla name, a photo and a repeat.
const visitForm = `<?xml version="1.0"?>
<h:html xmlns="http://www.w3.org/2002/xforms" xmlns:h="http://www.w3.org/1999/xhtml" xmlns:jr="http://openrosa.org/javarosa">
 <h:head><h:title>Visit</h:title><model>
  <instance><data id="visit" version="1">
   <name/><photo/><members jr:template=""><member/></members><meta><instanceID/></meta>
  </data></instance>
  <bind nodeset="/data/photo" type="binary"/>
  <bind nodeset="/data/meta/instanceID" type="string" readonly="true()" jr:preload="uid"/>
 </model></h:head>
 <h:body>
  <input ref="/data/name"/><upload ref="/data/photo" mediatype="image/*"/>
  <group ref="/data/members"><repeat nodeset="/data/members"><input ref="member"/></repeat></group>
 </h:body>
</h:html>`

// A name with conjuncts and the zero-width joiner, as the Phase 1 test asks.
const exportName = "অন্তরা ক্ষমা র\u200d্যাব"

func visitInstance(instanceID, name, photo string) []byte {
	return fmt.Appendf(nil, `<?xml version="1.0"?><data id="visit" version="1"><name>%s</name><photo>%s</photo>`+
		`<members><member>করিম</member></members><members><member>সালমা</member></members>`+
		`<meta><instanceID>%s</instanceID></meta></data>`, name, photo, instanceID)
}

type exportOrg struct {
	*testutil.Org
	form *core.Record
}

func seedVisits(t *testing.T, app core.App, mux http.Handler) exportOrg {
	t.Helper()
	o := testutil.SeedOrg(t, app)
	forms, _ := app.FindCollectionByNameOrId(schema.Forms)
	form := core.NewRecord(forms)
	form.Load(map[string]any{"form_id": "visit", "title": "Visit"})
	if err := app.Save(form); err != nil {
		t.Fatal(err)
	}
	versions, _ := app.FindCollectionByNameOrId(schema.FormVersions)
	v := core.NewRecord(versions)
	f, _ := filesystem.NewFileFromBytes([]byte(visitForm), "visit.xml")
	v.Load(map[string]any{"form": form.Id, "version": "1", "xform": f, "published": true})
	if err := app.Save(v); err != nil {
		t.Fatal(err)
	}
	for _, s := range []struct {
		user       *core.Record
		id, photo  string
		photoBytes string
	}{
		{o.Field1, "uuid:branch-one", "1700000001.jpg", "photo from branch 1"},
		{o.Field2, "uuid:branch-two", "1700000002.jpg", "photo from branch 2"},
	} {
		body, ct := testutil.Multipart(t, visitInstance(s.id, exportName, s.photo), map[string][]byte{s.photo: []byte(s.photoBytes)})
		r := httptest.NewRequest(http.MethodPost, submitURL, body)
		r.Header.Set("Content-Type", ct)
		r.Header.Set("Authorization", testutil.Token(t, s.user))
		r.RemoteAddr = defaultIP + ":40000"
		w := httptest.NewRecorder()
		mux.ServeHTTP(w, r)
		if w.Code != http.StatusOK {
			t.Fatalf("submit %s: %d %s", s.id, w.Code, w.Body.String())
		}
	}
	return exportOrg{o, form}
}

// signedInToken signs person in with a password, as the manager app does
// before a download.
func signedInToken(t *testing.T, mux http.Handler, collection, email string) string {
	t.Helper()
	status, body := signIn(mux, collection, email, testutil.Password)
	if status != http.StatusOK {
		t.Fatalf("sign in %s: %d %s", email, status, body)
	}
	return tokenOf(t, body)
}

func download(t *testing.T, mux http.Handler, token string, body map[string]any) (int, []byte, http.Header) {
	t.Helper()
	raw, _ := json.Marshal(body)
	r := httptest.NewRequest(http.MethodPost, exportURL, bytes.NewReader(raw))
	r.Header.Set("Content-Type", "application/json")
	if token != "" {
		r.Header.Set("Authorization", token)
	}
	r.RemoteAddr = defaultIP + ":40000"
	w := httptest.NewRecorder()
	mux.ServeHTTP(w, r)
	return w.Code, w.Body.Bytes(), w.Header()
}

func unzip(t *testing.T, b []byte) map[string]string {
	t.Helper()
	z, err := zip.NewReader(bytes.NewReader(b), int64(len(b)))
	if err != nil {
		t.Fatalf("not a zip: %v (%.200s)", err, b)
	}
	files := map[string]string{}
	for _, f := range z.File {
		rc, _ := f.Open()
		c, _ := io.ReadAll(rc)
		rc.Close()
		files[f.Name] = string(c)
	}
	return files
}

func TestAnOrgAdminDownloadsEverySubmission(t *testing.T) {
	app := testutil.NewApp(t)
	defer app.Cleanup()
	mux := serveMux(t, app)
	o := seedVisits(t, app, mux)
	token := signedInToken(t, mux, schema.StaffUsers, "admin@example.org")

	status, body, h := download(t, mux, token, map[string]any{"form": o.form.Id, "include_media": true})
	if status != http.StatusOK {
		t.Fatalf("download: %d %s", status, body)
	}
	if h.Get("Content-Type") != "application/zip" || !strings.Contains(h.Get("Content-Disposition"), `filename="visit_`) ||
		h.Get("Cache-Control") != "no-store" {
		t.Errorf("headers: %v", h)
	}
	files := unzip(t, body)
	csv := files["visit.csv"]
	if !strings.HasPrefix(csv, "\ufeffSubmissionDate,name,photo,meta-instanceID,KEY,") {
		t.Errorf("visit.csv starts %q", csv[:min(len(csv), 80)])
	}
	if strings.Count(csv, exportName) != 2 || !strings.Contains(csv, "uuid:branch-one") || !strings.Contains(csv, "uuid:branch-two") {
		t.Errorf("visit.csv: %s", csv)
	}
	if !strings.Contains(files["visit-members.csv"], "করিম,uuid:branch-one,uuid:branch-one/members[1]") {
		t.Errorf("visit-members.csv: %s", files["visit-members.csv"])
	}
	for _, name := range []string{"forms/visit_1.xml", "submissions/uuid_branch-one.xml", "submissions/uuid_branch-two.xml",
		"media/1700000001.jpg", "media/1700000002.jpg", "README.txt", "manifest.json"} {
		if _, ok := files[name]; !ok {
			t.Errorf("no %s in %v", name, keysOf(files))
		}
	}
	if files["media/1700000001.jpg"] != "photo from branch 1" {
		t.Error("media content")
	}
	// The root row reports one expected and one present attachment.
	if !strings.Contains(csv, ",1,1,,,") {
		t.Errorf("attachment counts: %s", csv)
	}

	// The download is in the export log, completed, with the manifest's
	// SHA-256, and in the audit chain.
	logs, err := app.FindAllRecords(schema.Exports)
	if err != nil || len(logs) != 1 {
		t.Fatalf("export log: %d %v", len(logs), err)
	}
	l := logs[0]
	m := sha256.Sum256([]byte(files["manifest.json"]))
	if l.GetString("status") != schema.ExportCompleted || l.GetString("manifest_sha256") != hex.EncodeToString(m[:]) ||
		l.GetInt("submissions") != 2 || l.GetInt("files") != 2 || l.GetString("staff_user") != o.Admin.Id || l.GetString("device") == "" {
		t.Errorf("export log: %v", l.PublicExport())
	}
	if n, _ := app.CountRecords(schema.Audit, dbx.HashExp{"collection": schema.Exports, "record_id": l.Id}); n != 2 {
		t.Errorf("%d audit entries for the export, want 2 (started, completed)", n)
	}
	if r := mustVerify(t, app); !r.OK {
		t.Errorf("audit chain: %+v", r)
	}
}

func TestMEStaffDownloadOnlyTheirPlaces(t *testing.T) {
	app := testutil.NewApp(t)
	defer app.Cleanup()
	mux := serveMux(t, app)
	o := seedVisits(t, app, mux)
	token := signedInToken(t, mux, schema.StaffUsers, "me1@example.org")

	status, body, _ := download(t, mux, token, map[string]any{"form": o.form.Id})
	if status != http.StatusOK {
		t.Fatalf("download: %d %s", status, body)
	}
	files := unzip(t, body)
	if !strings.Contains(files["visit.csv"], "uuid:branch-one") || strings.Contains(files["visit.csv"], "uuid:branch-two") {
		t.Errorf("an M&E officer in branch 1 got: %s", files["visit.csv"])
	}
	if _, ok := files["submissions/uuid_branch-two.xml"]; ok {
		t.Error("another branch's XML is in the package")
	}
	if _, ok := files["media/1700000001.jpg"]; ok {
		t.Error("media without include_media")
	}
}

func TestOnlyAdminsAndMEStaffDownload(t *testing.T) {
	app := testutil.NewApp(t)
	defer app.Cleanup()
	mux := serveMux(t, app)
	o := seedVisits(t, app, mux)
	for _, email := range []string{"sup1@example.org", "donor@example.org"} {
		token := signedInToken(t, mux, schema.StaffUsers, email)
		if status, body, _ := download(t, mux, token, map[string]any{"form": o.form.Id}); status != http.StatusForbidden {
			t.Errorf("%s: %d %s", email, status, body)
		}
	}
	field := signedInToken(t, mux, schema.FieldUsers, "field1@example.org")
	if status, _, _ := download(t, mux, field, map[string]any{"form": o.form.Id}); status != http.StatusForbidden {
		t.Errorf("a field user: %d", status)
	}
	if status, _, _ := download(t, mux, "", map[string]any{"form": o.form.Id}); status != http.StatusUnauthorized {
		t.Errorf("a stranger: %d", status)
	}
	if n, _ := app.CountRecords(schema.Exports); n != 0 {
		t.Errorf("%d refused downloads in the export log", n)
	}
}

func TestADownloadNeedsASignInWithinFifteenMinutes(t *testing.T) {
	app := testutil.NewApp(t)
	defer app.Cleanup()
	mux := serveMux(t, app)
	o := seedVisits(t, app, mux)
	reason := `"code":"` + schema.ReasonRecentSignInRequired + `"`

	// A session from a refresh is not a sign-in.
	token := signedInToken(t, mux, schema.StaffUsers, "admin@example.org")
	status, body := call(mux, http.MethodPost, "/api/collections/staff_users/auth-refresh", token, nil)
	if status != http.StatusOK {
		t.Fatalf("refresh: %d %s", status, body)
	}
	refreshed := tokenOf(t, body)
	if status, body, _ := download(t, mux, refreshed, map[string]any{"form": o.form.Id}); status != http.StatusForbidden ||
		!strings.Contains(string(body), reason) {
		t.Errorf("after a refresh: %d %s", status, body)
	}

	// A sign-in 16 minutes ago is too old.
	s, err := app.FindFirstRecordByData(schema.Sessions, "token_hash", testutil.TokenHash(token))
	if err != nil {
		t.Fatal(err)
	}
	old, _ := types.ParseDateTime(time.Now().Add(-16 * time.Minute))
	s.Set("signed_in", old)
	if err := app.Save(s); err != nil {
		t.Fatal(err)
	}
	if status, body, _ := download(t, mux, token, map[string]any{"form": o.form.Id}); status != http.StatusForbidden ||
		!strings.Contains(string(body), reason) {
		t.Errorf("16 minutes after signing in: %d %s", status, body)
	}

	// Signing in again works.
	again := signedInToken(t, mux, schema.StaffUsers, "admin@example.org")
	if status, body, _ := download(t, mux, again, map[string]any{"form": o.form.Id}); status != http.StatusOK {
		t.Errorf("after signing in again: %d %.200s", status, body)
	}
}

func TestDownloadFilters(t *testing.T) {
	app := testutil.NewApp(t)
	defer app.Cleanup()
	mux := serveMux(t, app)
	o := seedVisits(t, app, mux)
	token := signedInToken(t, mux, schema.StaffUsers, "admin@example.org")

	two, _ := app.FindFirstRecordByData(schema.Submissions, "instance_id", "uuid:branch-two")
	two.Set("review_state", schema.ReviewApproved)
	if err := audit.RunAs(app, audit.CLIActor("test"), func(tx core.App) error { return tx.Save(two) }); err != nil {
		t.Fatal(err)
	}
	status, body, _ := download(t, mux, token, map[string]any{"form": o.form.Id, "review_states": []string{schema.ReviewApproved}})
	if status != http.StatusOK {
		t.Fatalf("by review state: %d %s", status, body)
	}
	csv := unzip(t, body)["visit.csv"]
	if strings.Contains(csv, "uuid:branch-one") || !strings.Contains(csv, "uuid:branch-two,") || !strings.Contains(csv, ",approved,") {
		t.Errorf("approved only: %s", csv)
	}

	tomorrow := time.Now().Add(24 * time.Hour).Format(time.RFC3339)
	status, body, _ = download(t, mux, token, map[string]any{"form": o.form.Id, "from": tomorrow})
	if status != http.StatusOK || strings.Count(unzip(t, body)["visit.csv"], "\r\n") != 1 {
		t.Errorf("from tomorrow: %d, want the header only", status)
	}

	for name, req := range map[string]map[string]any{
		"bad date":        {"form": o.form.Id, "from": "1 November"},
		"empty period":    {"form": o.form.Id, "from": tomorrow, "to": tomorrow},
		"unknown state":   {"form": o.form.Id, "review_states": []string{"Lost"}},
		"unknown form":    {"form": "nosuchform12345"},
		"form without id": {},
	} {
		if status, body, _ := download(t, mux, token, req); status != http.StatusBadRequest {
			t.Errorf("%s: %d %s", name, status, body)
		}
	}
}

func TestTheExportLogIsWrittenOnlyByTheServer(t *testing.T) {
	app := testutil.NewApp(t)
	defer app.Cleanup()
	mux := serveMux(t, app)
	o := seedVisits(t, app, mux)
	su := testutil.Token(t, testutil.Superuser(t, app))
	if status, body := call(mux, http.MethodPost, "/api/collections/exports/records", su,
		map[string]any{"staff_user": o.Admin.Id, "form": o.form.Id, "status": schema.ExportCompleted}); status != http.StatusForbidden {
		t.Errorf("a superuser wrote the export log: %d %s", status, body)
	}
	// Org admins read the log; M&E staff only their own downloads.
	me := signedInToken(t, mux, schema.StaffUsers, "me1@example.org")
	admin := signedInToken(t, mux, schema.StaffUsers, "admin@example.org")
	download(t, mux, me, map[string]any{"form": o.form.Id})
	download(t, mux, admin, map[string]any{"form": o.form.Id})
	for token, want := range map[string]int{admin: 2, me: 1} {
		_, body := call(mux, http.MethodGet, "/api/collections/exports/records", token, nil)
		if !strings.Contains(body, fmt.Sprintf(`"totalItems":%d`, want)) {
			t.Errorf("export log as seen: %s", body)
		}
	}
}

func keysOf(m map[string]string) []string {
	var k []string
	for n := range m {
		k = append(k, n)
	}
	return k
}
