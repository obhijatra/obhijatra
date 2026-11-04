package obhijatra_test

import (
	"net/http"
	"strings"
	"testing"

	"ganigeorgiev.com/pocketbase/pocketbase/core"
	"ganigeorgiev.com/pocketbase/pocketbase/tests"

	"github.com/obhijatra/obhijatra/server/internal/testutil"
)

func auth(t testing.TB, r *core.Record) map[string]string {
	return map[string]string{"Authorization": testutil.Token(t, r)}
}

// runShared runs scenarios in order against one app, which the caller
// cleans up.
func runShared(t *testing.T, app *tests.TestApp, scenarios []tests.ApiScenario) {
	t.Helper()
	for _, s := range scenarios {
		s.TestAppFactory = func(testing.TB) *tests.TestApp { return app }
		s.DisableTestAppCleanup = true
		s.Test(t)
	}
}

func TestBranchIsolation(t *testing.T) {
	app := testutil.NewApp(t)
	defer app.Cleanup()

	o := testutil.SeedOrg(t, app)
	s1 := testutil.Submission(t, app, o, o.Field1, "uuid:11111111-1111-4111-8111-111111111111")
	p1 := testutil.Submission(t, app, o, o.Peer1, "uuid:22222222-2222-4222-8222-222222222222")
	s2 := testutil.Submission(t, app, o, o.Field2, "uuid:33333333-3333-4333-8333-333333333333")

	const list = "/api/collections/submissions/records"
	view := func(r *core.Record) string { return list + "/" + r.Id }
	idOf := func(r *core.Record) string { return `"id":"` + r.Id + `"` }
	notFound := []string{`"status":404`}

	runShared(t, app, []tests.ApiScenario{
		// Field users: their own submissions only.
		{
			Name: "field user lists only their own submissions", Method: http.MethodGet, URL: list,
			Headers: auth(t, o.Field1), ExpectedStatus: 200,
			ExpectedContent:    []string{`"totalItems":1`, idOf(s1)},
			NotExpectedContent: []string{p1.Id, s2.Id},
		},
		{
			Name: "field user cannot read another branch's submission", Method: http.MethodGet, URL: view(s2),
			Headers: auth(t, o.Field1), ExpectedStatus: 404, ExpectedContent: notFound,
		},
		{
			Name: "field user cannot read a same-branch colleague's submission", Method: http.MethodGet, URL: view(p1),
			Headers: auth(t, o.Field1), ExpectedStatus: 404, ExpectedContent: notFound,
		},
		{
			Name: "field user cannot change a submission", Method: http.MethodPatch, URL: view(s1),
			Body: strings.NewReader(`{"review_state":"Approved"}`), Headers: auth(t, o.Field1),
			ExpectedStatus: 404, ExpectedContent: notFound,
		},
		{
			Name: "field user cannot create a submission through the records API", Method: http.MethodPost, URL: list,
			Body: strings.NewReader(`{}`), Headers: auth(t, o.Field1),
			ExpectedStatus: 403, ExpectedContent: []string{`"status":403`},
		},

		// Staff: records under their location path only.
		{
			Name: "supervisor lists only their branch", Method: http.MethodGet, URL: list,
			Headers: auth(t, o.Sup1), ExpectedStatus: 200,
			ExpectedContent:    []string{`"totalItems":2`, idOf(s1), idOf(p1)},
			NotExpectedContent: []string{s2.Id},
		},
		{
			Name: "supervisor cannot read outside their branch", Method: http.MethodGet, URL: view(s2),
			Headers: auth(t, o.Sup1), ExpectedStatus: 404, ExpectedContent: notFound,
		},
		{
			Name: "the other branch's supervisor cannot read branch 1", Method: http.MethodGet, URL: view(s1),
			Headers: auth(t, o.Sup2), ExpectedStatus: 404, ExpectedContent: notFound,
		},
		{
			Name: "supervisor cannot review outside their branch", Method: http.MethodPatch, URL: view(s2),
			Body: strings.NewReader(`{"review_state":"Approved"}`), Headers: auth(t, o.Sup1),
			ExpectedStatus: 404, ExpectedContent: notFound,
		},
		{
			Name: "supervisor lists field users of their branch only", Method: http.MethodGet,
			URL: "/api/collections/field_users/records", Headers: auth(t, o.Sup1), ExpectedStatus: 200,
			ExpectedContent:    []string{idOf(o.Field1), idOf(o.Peer1)},
			NotExpectedContent: []string{o.Field2.Id},
		},
		{
			Name: "org admin sees every submission", Method: http.MethodGet, URL: list,
			Headers: auth(t, o.Admin), ExpectedStatus: 200,
			ExpectedContent: []string{`"totalItems":3`, idOf(s1), idOf(p1), idOf(s2)},
		},
		{
			Name: "read-only donor sees no beneficiary-level submissions", Method: http.MethodGet, URL: list,
			Headers: auth(t, o.Donor), ExpectedStatus: 200, ExpectedContent: []string{`"totalItems":0`},
		},
		{
			Name: "inactive user sees nothing even with a valid token", Method: http.MethodGet, URL: list,
			Headers: auth(t, o.Gone1), ExpectedStatus: 200, ExpectedContent: []string{`"totalItems":0`},
		},
		{
			Name: "guest sees nothing", Method: http.MethodGet, URL: list,
			ExpectedStatus: 200, ExpectedContent: []string{`"totalItems":0`},
		},

		// Users cannot widen their own scope.
		{
			Name: "field user cannot move themselves to another branch", Method: http.MethodPatch,
			URL:  "/api/collections/field_users/records/" + o.Field1.Id,
			Body: strings.NewReader(`{"location":"` + o.Branch2.Id + `"}`), Headers: auth(t, o.Field1),
			ExpectedStatus: 404, ExpectedContent: notFound,
		},
		{
			Name: "supervisor cannot make themselves org admin", Method: http.MethodPatch,
			URL:  "/api/collections/staff_users/records/" + o.Sup1.Id,
			Body: strings.NewReader(`{"role":"org_admin"}`), Headers: auth(t, o.Sup1),
			ExpectedStatus: 404, ExpectedContent: notFound,
		},

		// Reviews: only review_state may change, in scope, for everyone.
		{
			Name: "supervisor approves a submission in their branch", Method: http.MethodPatch, URL: view(s1),
			Body: strings.NewReader(`{"review_state":"Approved"}`), Headers: auth(t, o.Sup1),
			ExpectedStatus: 200, ExpectedContent: []string{`"review_state":"Approved"`},
		},
		{
			Name: "supervisor cannot change a submission's instance ID", Method: http.MethodPatch, URL: view(p1),
			Body: strings.NewReader(`{"instance_id":"uuid:44444444-4444-4444-8444-444444444444"}`), Headers: auth(t, o.Sup1),
			ExpectedStatus: 400, ExpectedContent: []string{`"status":400`},
		},
		{
			Name: "superuser cannot change a submission's instance ID either", Method: http.MethodPatch, URL: view(p1),
			Body:    strings.NewReader(`{"instance_id":"uuid:44444444-4444-4444-8444-444444444444"}`),
			Headers: auth(t, testutil.Superuser(t, app)), ExpectedStatus: 400, ExpectedContent: []string{`"status":400`},
		},
	})
}
