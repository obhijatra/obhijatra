package obhijatra_test

import (
	"encoding/json"
	"fmt"
	"net/http"
	"net/http/httptest"
	"sync"
	"testing"

	"ganigeorgiev.com/pocketbase/pocketbase/apis"
	"ganigeorgiev.com/pocketbase/pocketbase/core"
	"ganigeorgiev.com/pocketbase/pocketbase/tests"

	"github.com/obhijatra/obhijatra/server/internal/api"
	"github.com/obhijatra/obhijatra/server/internal/schema"
	"github.com/obhijatra/obhijatra/server/internal/testutil"
)

const submitURL = api.Prefix + "/submissions"

// submitScenario posts xml (and attachments) as user; a nil user is a guest.
func submitScenario(t testing.TB, name string, user *core.Record, xml []byte, attachments map[string][]byte, status int, content ...string) tests.ApiScenario {
	body, contentType := testutil.Multipart(t, xml, attachments)
	headers := map[string]string{"Content-Type": contentType}
	if user != nil {
		headers["Authorization"] = testutil.Token(t, user)
	}
	return tests.ApiScenario{
		Name:            name,
		Method:          http.MethodPost,
		URL:             submitURL,
		Body:            body,
		Headers:         headers,
		ExpectedStatus:  status,
		ExpectedContent: content,
	}
}

func TestSubmissionIdempotency(t *testing.T) {
	app := testutil.NewApp(t)
	defer app.Cleanup()
	o := testutil.SeedOrg(t, app)

	const id = "uuid:5a1c2d3e-4f50-4a6b-8c7d-9e0f1a2b3c4d"
	original := testutil.Instance(id, testutil.FormVersion, 5)
	changed := testutil.Instance(id, testutil.FormVersion, 6)
	photo := []byte("\xff\xd8\xff\xe0 not really a jpeg")

	runShared(t, app, []tests.ApiScenario{
		submitScenario(t, "first upload is stored", o.Field1, original, map[string][]byte{"photo-1.jpg": photo},
			200, `"status":"received"`, `"instance_id":"`+id+`"`),
		submitScenario(t, "retry of the same upload is acknowledged, not duplicated", o.Field1, original, nil,
			200, `"status":"already_received"`),
		submitScenario(t, "same instance ID with different content is refused", o.Field1, changed, nil,
			409, `"status":409`),
		submitScenario(t, "same instance ID from another user is refused", o.Peer1, original, nil,
			409, `"status":409`),
	})

	// Exactly one stored copy, with the first upload's content and metadata.
	records, err := app.FindAllRecords(schema.Submissions)
	if err != nil {
		t.Fatal(err)
	}
	if len(records) != 1 {
		t.Fatalf("stored %d submissions, want 1", len(records))
	}
	rec := records[0]
	if rec.GetString("submitted_by") != o.Field1.Id {
		t.Errorf("submitted_by %q, want %q", rec.GetString("submitted_by"), o.Field1.Id)
	}
	if rec.GetString("location_path") != o.Field1.GetString("location_path") {
		t.Errorf("location_path %q, want the user's %q", rec.GetString("location_path"), o.Field1.GetString("location_path"))
	}
	if rec.GetString("review_state") != schema.ReviewReceived {
		t.Errorf("review_state %q, want Received", rec.GetString("review_state"))
	}
	if rec.GetString("form_version") != o.Version.Id {
		t.Errorf("form_version %q, want %q", rec.GetString("form_version"), o.Version.Id)
	}
	if len(rec.GetStringSlice("attachments")) != 1 {
		t.Errorf("want 1 attachment, got %v", rec.GetStringSlice("attachments"))
	}
	var manifest []api.AttachmentInfo
	if err := json.Unmarshal([]byte(rec.GetString("attachments_manifest")), &manifest); err != nil || len(manifest) != 1 || manifest[0].Name != "photo-1.jpg" {
		t.Errorf("attachments_manifest %s does not record the original file name", rec.GetString("attachments_manifest"))
	}
}

func TestSubmissionValidation(t *testing.T) {
	app := testutil.NewApp(t)
	defer app.Cleanup()
	o := testutil.SeedOrg(t, app)

	good := func(id string) []byte { return testutil.Instance(id, testutil.FormVersion, 3) }

	runShared(t, app, []tests.ApiScenario{
		submitScenario(t, "guest cannot submit", nil, good("uuid:a0000000-0000-4000-8000-000000000001"), nil,
			401, `"status":401`),
		submitScenario(t, "staff user cannot submit", o.Sup1, good("uuid:a0000000-0000-4000-8000-000000000002"), nil,
			403, `"status":403`),
		submitScenario(t, "inactive field user cannot submit", o.Gone1, good("uuid:a0000000-0000-4000-8000-000000000003"), nil,
			403, `"status":403`),
		submitScenario(t, "unpublished form version is refused", o.Field1,
			testutil.Instance("uuid:a0000000-0000-4000-8000-000000000004", "2026110402", 3), nil,
			422, `"status":422`, `not published`),
		submitScenario(t, "unknown form version is refused", o.Field1,
			testutil.Instance("uuid:a0000000-0000-4000-8000-000000000005", "1999", 3), nil,
			422, `"status":422`),
		submitScenario(t, "XML without an instanceID is refused", o.Field1,
			[]byte(`<data id="household_visit" version="2026110401"><household_size>3</household_size></data>`), nil,
			400, `"status":400`, `instanceID`),
		submitScenario(t, "XML with a DOCTYPE is refused", o.Field1,
			[]byte(`<?xml version="1.0"?><!DOCTYPE data [<!ENTITY x "y">]><data id="household_visit" version="2026110401"><meta><instanceID>uuid:a0000000-0000-4000-8000-000000000006</instanceID></meta></data>`), nil,
			400, `"status":400`),
		{
			Name: "missing XML part is refused", Method: http.MethodPost, URL: submitURL,
			Headers: auth(t, o.Field1), ExpectedStatus: 400, ExpectedContent: []string{`"status":400`},
		},
	})

	if total, _ := app.CountRecords(schema.Submissions); total != 0 {
		t.Errorf("%d submissions stored by refused requests", total)
	}
}

// Phones retry aggressively on bad networks, so two copies of one upload
// can arrive at the same moment. Exactly one is stored; both get 200.
func TestConcurrentDuplicateSubmissions(t *testing.T) {
	app := testutil.NewApp(t)
	defer app.Cleanup()
	o := testutil.SeedOrg(t, app)

	router, err := apis.NewRouter(app)
	if err != nil {
		t.Fatal(err)
	}
	var mux http.Handler
	err = app.OnServe().Trigger(&core.ServeEvent{App: app, Router: router}, func(e *core.ServeEvent) error {
		mux, err = e.Router.BuildMux()
		return err
	})
	if err != nil {
		t.Fatal(err)
	}

	const copies = 8
	xml := testutil.Instance("uuid:d0000000-0000-4000-8000-000000000001", testutil.FormVersion, 7)
	token := testutil.Token(t, o.Field1)

	var wg sync.WaitGroup
	results := make(chan string, copies)
	for range copies {
		body, contentType := testutil.Multipart(t, xml, nil)
		wg.Add(1)
		go func() {
			defer wg.Done()
			req := httptest.NewRequest(http.MethodPost, submitURL, body)
			req.Header.Set("Content-Type", contentType)
			req.Header.Set("Authorization", token)
			rec := httptest.NewRecorder()
			mux.ServeHTTP(rec, req)

			var resp api.SubmissionResponse
			_ = json.Unmarshal(rec.Body.Bytes(), &resp)
			results <- fmt.Sprintf("%d %s", rec.Code, resp.Status)
		}()
	}
	wg.Wait()
	close(results)

	counts := map[string]int{}
	for r := range results {
		counts[r]++
	}
	if counts["200 "+api.StatusReceived] != 1 || counts["200 "+api.StatusAlreadyReceived] != copies-1 {
		t.Errorf("want 1 received and %d already_received, got %v", copies-1, counts)
	}
	if n, _ := app.CountRecords(schema.Submissions); n != 1 {
		t.Errorf("stored %d copies, want 1", n)
	}
	if r := mustVerify(t, app); !r.OK {
		t.Errorf("audit chain broken by concurrent writes: %+v", r)
	}
}
