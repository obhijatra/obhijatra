package obhijatra_test

import (
	"net/http"
	"strings"
	"testing"

	"ganigeorgiev.com/pocketbase/dbx"
	"ganigeorgiev.com/pocketbase/pocketbase/core"

	"github.com/obhijatra/obhijatra/server/internal/audit"
	"github.com/obhijatra/obhijatra/server/internal/schema"
	"github.com/obhijatra/obhijatra/server/internal/testutil"
)

// Supervisors, M&E staff and org admins review submissions in their part
// of the organisation: they set review_state and review_comment and nothing
// else. Field users and donors cannot.
func TestReviewWorkflow(t *testing.T) {
	app := testutil.NewApp(t)
	defer app.Cleanup()
	o := testutil.SeedOrg(t, app)
	mux := serveMux(t, app)

	s1 := testutil.Submission(t, app, o, o.Field1, "uuid:a1000000-0000-4000-8000-000000000001")
	s2 := testutil.Submission(t, app, o, o.Field2, "uuid:a2000000-0000-4000-8000-000000000002")
	url := func(r *core.Record) string { return "/api/collections/submissions/records/" + r.Id }

	cases := []struct {
		name    string
		who     *core.Record
		target  *core.Record
		body    map[string]any
		status  int
		content string
	}{
		{"a supervisor flags issues with a comment", o.Sup1, s1,
			map[string]any{"review_state": schema.ReviewHasIssues, "review_comment": "Household size looks wrong."},
			200, `"review_comment":"Household size looks wrong."`},
		{"an M&E officer approves in their branch", o.ME1, s1,
			map[string]any{"review_state": schema.ReviewApproved}, 200, `"review_state":"Approved"`},
		{"a comment alone may be changed", o.Sup1, s1,
			map[string]any{"review_comment": "Checked again by phone."}, 200, `"review_comment":"Checked again by phone."`},
		{"an org admin reviews anywhere below the root", o.Admin, s2,
			map[string]any{"review_state": schema.ReviewRejected, "review_comment": "Duplicate visit."}, 200, `"review_state":"Rejected"`},
		{"every review state can be set", o.Sup2, s2,
			map[string]any{"review_state": schema.ReviewEdited}, 200, `"review_state":"Edited"`},

		{"an M&E officer cannot review another branch", o.ME1, s2, map[string]any{"review_state": schema.ReviewApproved}, 404, ""},
		{"a supervisor cannot review another branch", o.Sup2, s1, map[string]any{"review_state": schema.ReviewApproved}, 404, ""},
		{"a field user cannot review their own submission", o.Field1, s1, map[string]any{"review_state": schema.ReviewApproved}, 404, ""},
		{"a donor cannot review", o.Donor, s1, map[string]any{"review_state": schema.ReviewApproved}, 404, ""},

		{"a reviewer cannot change who submitted it", o.Sup1, s1,
			map[string]any{"review_state": schema.ReviewApproved, "submitted_by": o.Peer1.Id}, 400, ""},
		{"a reviewer cannot move it to another branch", o.Admin, s1,
			map[string]any{"review_comment": "x", "location_path": o.Branch2.GetString("path")}, 400, ""},
		{"a reviewer cannot change its fingerprint", o.Sup1, s1,
			map[string]any{"xml_sha256": strings.Repeat("0", 64)}, 400, ""},
		{"an unknown review state is refused", o.Sup1, s1, map[string]any{"review_state": "Done"}, 400, ""},
		{"an over-long comment is refused", o.Sup1, s1,
			map[string]any{"review_comment": strings.Repeat("x", schema.MaxReviewComment+1)}, 400, ""},
	}

	for _, c := range cases {
		status, body := call(mux, http.MethodPatch, url(c.target), testutil.Token(t, c.who), c.body)
		if status != c.status || !strings.Contains(body, c.content) {
			t.Errorf("%s: %d %s; want %d with %s", c.name, status, body, c.status, c.content)
		}
	}

	// The refused changes left the records as the last allowed change set
	// them.
	got, _ := app.FindRecordById(schema.Submissions, s1.Id)
	if got.GetString("submitted_by") != o.Field1.Id || got.GetString("location_path") != o.Field1.GetString("location_path") ||
		got.GetString("xml_sha256") != s1.GetString("xml_sha256") {
		t.Error("a refused review changed fields other than the review fields")
	}
	if got.GetString("review_state") != schema.ReviewApproved || got.GetString("review_comment") != "Checked again by phone." {
		t.Errorf("review fields: %q %q", got.GetString("review_state"), got.GetString("review_comment"))
	}

	// Every review is in the audit chain, attributed to the reviewer.
	for _, c := range []struct {
		submission, reviewer *core.Record
		want                 int64
	}{{s1, o.Sup1, 2}, {s1, o.ME1, 1}, {s2, o.Admin, 1}, {s2, o.Sup2, 1}} {
		n, err := app.CountRecords(schema.Audit, dbx.HashExp{
			"action": audit.ActionUpdate, "collection": schema.Submissions,
			"record_id": c.submission.Id, "actor": c.reviewer.Id,
		})
		if err != nil || n != c.want {
			t.Errorf("audit entries for %s reviewing %s: %d, want %d", c.reviewer.GetString("email"), c.submission.Id, n, c.want)
		}
	}
	if r := mustVerify(t, app); !r.OK {
		t.Fatalf("audit chain: %+v", r)
	}
}
