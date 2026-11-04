package obhijatra_test

import (
	"encoding/json"
	"io"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"ganigeorgiev.com/pocketbase/dbx"
	"ganigeorgiev.com/pocketbase/pocketbase/core"
	"ganigeorgiev.com/pocketbase/pocketbase/tools/filesystem"

	"github.com/obhijatra/obhijatra/server/internal/audit"
	"github.com/obhijatra/obhijatra/server/internal/schema"
	"github.com/obhijatra/obhijatra/server/internal/testutil"
)

// uploadVersion posts a new form version as user, through the records API.
func uploadVersion(t testing.TB, mux http.Handler, user *core.Record, formRecordID, version string, xform []byte, published bool) (int, string) {
	t.Helper()
	body, contentType := testutil.FormVersionUpload(t, formRecordID, version, xform, published)
	r := httptest.NewRequest(http.MethodPost, versionsURL, body)
	r.Header.Set("Content-Type", contentType)
	r.Header.Set("Authorization", testutil.Token(t, user))
	w := httptest.NewRecorder()
	mux.ServeHTTP(w, r)
	out, _ := io.ReadAll(w.Body)
	return w.Code, string(out)
}

func idOf(t testing.TB, body string) string {
	t.Helper()
	var rec struct {
		ID string `json:"id"`
	}
	if err := json.Unmarshal([]byte(body), &rec); err != nil || rec.ID == "" {
		t.Fatalf("no record id in %s", body)
	}
	return rec.ID
}

// M&E staff and org admins create forms, upload XForm versions and publish
// them; a published version can be neither changed nor deleted by anyone.
func TestFormPublishing(t *testing.T) {
	app := testutil.NewApp(t)
	defer app.Cleanup()
	o := testutil.SeedOrg(t, app)
	mux := serveMux(t, app)
	su := testutil.Superuser(t, app)

	const formID = "nutrition_check"
	xform := func(v string) []byte { return testutil.XForm(formID, v) }

	// Who may create a form.
	newForm := map[string]any{"form_id": formID, "title": "Nutrition check"}
	for _, who := range []*core.Record{o.Sup1, o.Field1, o.Donor} {
		if status, body := call(mux, http.MethodPost, "/api/collections/forms/records", testutil.Token(t, who), newForm); status < 400 {
			t.Errorf("%s must not create a form: %d %s", who.GetString("email"), status, body)
		}
	}
	status, body := call(mux, http.MethodPost, "/api/collections/forms/records", testutil.Token(t, o.ME1), newForm)
	if status != 200 {
		t.Fatalf("M&E officer creates a form: %d %s", status, body)
	}
	form := idOf(t, body)

	// Who may upload a version.
	for _, who := range []*core.Record{o.Sup1, o.Field1} {
		if status, body := uploadVersion(t, mux, who, form, "1", xform("1"), false); status < 400 {
			t.Errorf("%s must not upload a version: %d %s", who.GetString("email"), status, body)
		}
	}
	status, body = uploadVersion(t, mux, o.ME1, form, "1", xform("1"), false)
	if status != 200 || !strings.Contains(body, `"published":false`) || !strings.Contains(body, `"published_at":""`) {
		t.Fatalf("M&E officer uploads a draft version: %d %s", status, body)
	}
	draft := idOf(t, body)
	status, body = uploadVersion(t, mux, o.ME1, form, "1", xform("1"), false)
	if status != 400 {
		t.Errorf("a second version with the same version string must be refused: %d %s", status, body)
	}

	// Field users do not see drafts.
	if _, body := call(mux, http.MethodGet, versionsURL+"/"+draft, testutil.Token(t, o.Field1), nil); !strings.Contains(body, `"status":404`) {
		t.Errorf("a field user must not see a draft version: %s", body)
	}

	// Publish. published_at is the server's clock, not the client's.
	versionURL := versionsURL + "/" + draft
	before := time.Now().Add(-time.Second)
	status, body = call(mux, http.MethodPatch, versionURL, testutil.Token(t, o.ME1),
		map[string]any{"published": true, "published_at": "2020-01-01 00:00:00.000Z"})
	if status != 200 || !strings.Contains(body, `"published":true`) {
		t.Fatalf("M&E officer publishes: %d %s", status, body)
	}
	published, _ := app.FindRecordById(schema.FormVersions, draft)
	if at := published.GetDateTime("published_at").Time(); at.Before(before) || at.After(time.Now().Add(time.Second)) {
		t.Errorf("published_at %s is not the time of publishing", at)
	}

	// A published version is immutable, for every writer.
	for name, c := range map[string]struct {
		who    *core.Record
		method string
		body   map[string]any
	}{
		"M&E officer unpublishes":   {o.ME1, http.MethodPatch, map[string]any{"published": false}},
		"org admin changes version": {o.Admin, http.MethodPatch, map[string]any{"version": "2"}},
		"M&E officer deletes":       {o.ME1, http.MethodDelete, nil},
		"superuser unpublishes":     {su, http.MethodPatch, map[string]any{"published": false}},
		"superuser edits the date":  {su, http.MethodPatch, map[string]any{"published_at": "2020-01-01 00:00:00.000Z"}},
		"superuser deletes":         {su, http.MethodDelete, nil},
	} {
		if status, body := call(mux, c.method, versionURL, testutil.Token(t, c.who), c.body); status < 400 {
			t.Errorf("%s: a published version was changed: %d %s", name, status, body)
		}
	}
	replacement, _ := filesystem.NewFileFromBytes(xform("1"), "form.xml")
	published.Set("xform", replacement)
	if err := app.Save(published); err == nil {
		t.Error("Go code replaced a published XForm")
	}
	if err := app.Delete(published); err == nil {
		t.Error("Go code deleted a published version")
	}
	if got, _ := app.FindRecordById(schema.FormVersions, draft); !got.GetBool("published") || got.GetString("version") != "1" {
		t.Error("the published version changed")
	}

	// A draft can still be changed and deleted by M&E staff.
	status, body = uploadVersion(t, mux, o.ME1, form, "2", xform("2"), false)
	if status != 200 {
		t.Fatalf("second draft: %d %s", status, body)
	}
	if status, body := call(mux, http.MethodDelete, versionsURL+"/"+idOf(t, body), testutil.Token(t, o.ME1), nil); status != 204 {
		t.Errorf("M&E officer deletes a draft: %d %s", status, body)
	}

	// Once a form has a version its form id is fixed, and it cannot be
	// deleted; its title can change.
	formURL := "/api/collections/forms/records/" + form
	if status, body := call(mux, http.MethodPatch, formURL, testutil.Token(t, o.ME1), map[string]any{"form_id": "renamed"}); status != 400 || !strings.Contains(body, "validation_form_id_fixed") {
		t.Errorf("changing the form id of a form with versions: %d %s", status, body)
	}
	if status, body := call(mux, http.MethodPatch, formURL, testutil.Token(t, o.ME1), map[string]any{"title": "Nutrition check v2"}); status != 200 {
		t.Errorf("changing the title: %d %s", status, body)
	}
	if status, _ := call(mux, http.MethodDelete, formURL, testutil.Token(t, o.ME1), nil); status != 400 {
		t.Errorf("deleting a form with a published version must be refused, got %d", status)
	}

	// An org admin can publish too, in one step.
	if status, body := uploadVersion(t, mux, o.Admin, form, "3", xform("3"), true); status != 200 || !strings.Contains(body, `"published":true`) {
		t.Errorf("org admin uploads a published version: %d %s", status, body)
	}

	// The M&E officer's actions are in the audit chain under their name.
	n, _ := app.CountRecords(schema.Audit, dbx.HashExp{"actor": o.ME1.Id, "actor_collection": schema.StaffUsers})
	if n != 6 { // form, two drafts, publish, delete draft, title
		t.Errorf("%d audit entries for the M&E officer, want 6", n)
	}
	if e, ok := auditEntry(t, app, audit.ActionUpdate, schema.FormVersions, draft); !ok || e.Actor != o.ME1.Id {
		t.Errorf("publishing is not in the audit chain under the M&E officer: %+v", e)
	}
	if r := mustVerify(t, app); !r.OK {
		t.Fatalf("audit chain: %+v", r)
	}
}
