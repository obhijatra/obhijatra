package obhijatra_test

import (
	"net/http"
	"strings"
	"testing"

	"ganigeorgiev.com/pocketbase/pocketbase/core"
	"ganigeorgiev.com/pocketbase/pocketbase/tests"

	"github.com/obhijatra/obhijatra/server/internal/schema"
	"github.com/obhijatra/obhijatra/server/internal/testutil"
)

// staffOfEveryRole adds a branch manager and an inactive staff user to o,
// and returns one active staff user of every role.
func staffOfEveryRole(t *testing.T, app core.App, o *testutil.Org) (active map[string]*core.Record, inactive *core.Record) {
	t.Helper()
	bm1 := testutil.User(t, app, schema.StaffUsers, "bm1@example.org", schema.RoleBranchManager, o.Branch1, true)
	inactive = testutil.User(t, app, schema.StaffUsers, "gone-sup1@example.org", schema.RoleSupervisor, o.Branch1, false)
	active = map[string]*core.Record{
		schema.RoleSupervisor:    o.Sup1,
		schema.RoleBranchManager: bm1,
		schema.RoleME:            o.ME1,
		schema.RoleOrgAdmin:      o.Admin,
		schema.RoleDonorReadonly: o.Donor,
	}
	if len(active) != len(schema.StaffRoles) {
		t.Fatalf("the test covers %d staff roles, the schema has %d", len(active), len(schema.StaffRoles))
	}
	return active, inactive
}

// Every active staff role reads published form version records and
// downloads their protected XForm with a file token (the manager app shows
// submissions with them). Drafts stay with M&E staff and org admins; an
// inactive staff user gets nothing.
func TestEveryStaffRoleReadsPublishedFormVersions(t *testing.T) {
	app := testutil.NewApp(t)
	defer app.Cleanup()
	o := testutil.SeedOrg(t, app)
	staff, gone := staffOfEveryRole(t, app, o)

	fileURL := func(v *core.Record, token string) string {
		return "/api/files/form_versions/" + v.Id + "/" + v.GetString("xform") + "?token=" + token
	}
	xform := string(testutil.XForm(testutil.FormID, testutil.FormVersion))
	notFound := []string{`"status":404`}
	canSeeDrafts := map[string]bool{schema.RoleME: true, schema.RoleOrgAdmin: true}

	var scenarios []tests.ApiScenario
	for _, role := range schema.StaffRoles {
		who := staff[role]
		scenarios = append(scenarios,
			tests.ApiScenario{
				Name: role + " lists the published version", Method: http.MethodGet, URL: versionsURL,
				Headers: auth(t, who), ExpectedStatus: 200,
				ExpectedContent: []string{`"id":"` + o.Version.Id + `"`, `"version":"` + testutil.FormVersion + `"`},
			},
			tests.ApiScenario{
				Name: role + " views the published version", Method: http.MethodGet, URL: versionsURL + "/" + o.Version.Id,
				Headers: auth(t, who), ExpectedStatus: 200, ExpectedContent: []string{`"published":true`},
			},
			tests.ApiScenario{
				Name: role + " downloads the published XForm with a file token", Method: http.MethodGet,
				URL: fileURL(o.Version, testutil.FileToken(t, who)), ExpectedStatus: 200, ExpectedContent: []string{xform},
			},
			tests.ApiScenario{
				Name: role + " cannot download with a sign-in token in the address", Method: http.MethodGet,
				URL: fileURL(o.Version, testutil.Token(t, who)), ExpectedStatus: 404, ExpectedContent: notFound,
			},
		)
		if canSeeDrafts[role] {
			scenarios = append(scenarios, tests.ApiScenario{
				Name: role + " downloads a draft XForm", Method: http.MethodGet,
				URL: fileURL(o.Unpublished, testutil.FileToken(t, who)), ExpectedStatus: 200, ExpectedContent: []string{`version="2026110402"`},
			})
		} else {
			scenarios = append(scenarios,
				tests.ApiScenario{
					Name: role + " does not see a draft version", Method: http.MethodGet, URL: versionsURL + "/" + o.Unpublished.Id,
					Headers: auth(t, who), ExpectedStatus: 404, ExpectedContent: notFound,
				},
				tests.ApiScenario{
					Name: role + " cannot download a draft XForm", Method: http.MethodGet,
					URL: fileURL(o.Unpublished, testutil.FileToken(t, who)), ExpectedStatus: 404, ExpectedContent: notFound,
				},
			)
		}
	}
	scenarios = append(scenarios,
		tests.ApiScenario{
			Name: "an inactive staff user lists no form versions", Method: http.MethodGet, URL: versionsURL,
			Headers: auth(t, gone), ExpectedStatus: 200, ExpectedContent: []string{`"totalItems":0`},
		},
		tests.ApiScenario{
			Name: "an inactive staff user cannot view a published version", Method: http.MethodGet, URL: versionsURL + "/" + o.Version.Id,
			Headers: auth(t, gone), ExpectedStatus: 404, ExpectedContent: notFound,
		},
		tests.ApiScenario{
			Name: "an inactive staff user's file token is refused", Method: http.MethodGet,
			URL: fileURL(o.Version, testutil.FileToken(t, gone)), ExpectedStatus: 404, ExpectedContent: notFound,
		},
	)
	runShared(t, app, scenarios)
}

// Every active staff user reads the whole location tree with names and
// paths; a field user reads only their own location and the locations
// below it; inactive users and guests read nothing.
func TestLocationReadAccess(t *testing.T) {
	app := testutil.NewApp(t)
	defer app.Cleanup()
	o := testutil.SeedOrg(t, app)
	staff, goneStaff := staffOfEveryRole(t, app, o)
	village1 := testutil.Location(t, app, "Village 1", o.Branch1)
	village2 := testutil.Location(t, app, "Village 2", o.Branch2)
	all := []*core.Record{o.Root, o.Branch1, o.Branch2, village1, village2}

	const list = "/api/collections/locations/records"
	view := func(r *core.Record) string { return list + "/" + r.Id }
	idOf := func(r *core.Record) string { return `"id":"` + r.Id + `"` }
	// Paths and parent fields name ancestors' ids, so absence is checked
	// on the record id itself.
	ids := func(rs ...*core.Record) []string {
		var out []string
		for _, r := range rs {
			out = append(out, idOf(r))
		}
		return out
	}
	notFound := []string{`"status":404`}

	var scenarios []tests.ApiScenario
	for _, role := range schema.StaffRoles {
		who := staff[role]
		want := []string{`"totalItems":5`}
		for _, l := range all {
			want = append(want, idOf(l), `"name":"`+l.GetString("name")+`"`, `"path":"`+l.GetString("path")+`"`)
		}
		scenarios = append(scenarios,
			tests.ApiScenario{
				Name: role + " lists every location with names and paths", Method: http.MethodGet, URL: list,
				Headers: auth(t, who), ExpectedStatus: 200, ExpectedContent: want,
			},
			tests.ApiScenario{
				Name: role + " views a location outside their branch", Method: http.MethodGet, URL: view(o.Branch2),
				Headers: auth(t, who), ExpectedStatus: 200, ExpectedContent: []string{`"name":"Branch 2"`},
			},
		)
	}

	scenarios = append(scenarios,
		// Field users: their own subtree.
		tests.ApiScenario{
			Name: "a field user lists their own branch and the places below it", Method: http.MethodGet, URL: list,
			Headers: auth(t, o.Field1), ExpectedStatus: 200,
			ExpectedContent:    []string{`"totalItems":2`, idOf(o.Branch1), idOf(village1), `"name":"Village 1"`, `"path":"` + village1.GetString("path") + `"`},
			NotExpectedContent: ids(o.Root, o.Branch2, village2),
		},
		tests.ApiScenario{
			Name: "a field user views a place below their branch", Method: http.MethodGet, URL: view(village1),
			Headers: auth(t, o.Field1), ExpectedStatus: 200, ExpectedContent: []string{`"name":"Village 1"`},
		},
		tests.ApiScenario{
			Name: "a field user cannot view another branch", Method: http.MethodGet, URL: view(o.Branch2),
			Headers: auth(t, o.Field1), ExpectedStatus: 404, ExpectedContent: notFound,
		},
		tests.ApiScenario{
			Name: "a field user cannot view a place in another branch", Method: http.MethodGet, URL: view(village2),
			Headers: auth(t, o.Field1), ExpectedStatus: 404, ExpectedContent: notFound,
		},
		tests.ApiScenario{
			Name: "a field user cannot view the location above their branch", Method: http.MethodGet, URL: view(o.Root),
			Headers: auth(t, o.Field1), ExpectedStatus: 404, ExpectedContent: notFound,
		},
		tests.ApiScenario{
			Name: "the other branch's field user sees only their branch", Method: http.MethodGet, URL: list,
			Headers: auth(t, o.Field2), ExpectedStatus: 200,
			ExpectedContent:    []string{`"totalItems":2`, idOf(o.Branch2), idOf(village2)},
			NotExpectedContent: ids(o.Root, o.Branch1, village1),
		},
		tests.ApiScenario{
			Name: "a field user cannot widen the list with a filter", Method: http.MethodGet,
			URL:     list + "?filter=" + strings.ReplaceAll(`(name="Branch 2" || name="Head office")`, " ", "%20"),
			Headers: auth(t, o.Field1), ExpectedStatus: 200, ExpectedContent: []string{`"totalItems":0`},
		},

		// Inactive users and guests: nothing.
		tests.ApiScenario{
			Name: "an inactive field user lists no locations", Method: http.MethodGet, URL: list,
			Headers: auth(t, o.Gone1), ExpectedStatus: 200, ExpectedContent: []string{`"totalItems":0`},
		},
		tests.ApiScenario{
			Name: "an inactive field user cannot view their own branch", Method: http.MethodGet, URL: view(o.Branch1),
			Headers: auth(t, o.Gone1), ExpectedStatus: 404, ExpectedContent: notFound,
		},
		tests.ApiScenario{
			Name: "an inactive staff user lists no locations", Method: http.MethodGet, URL: list,
			Headers: auth(t, goneStaff), ExpectedStatus: 200, ExpectedContent: []string{`"totalItems":0`},
		},
		tests.ApiScenario{
			Name: "an inactive staff user cannot view a location", Method: http.MethodGet, URL: view(o.Branch1),
			Headers: auth(t, goneStaff), ExpectedStatus: 404, ExpectedContent: notFound,
		},
		tests.ApiScenario{
			Name: "a guest lists no locations", Method: http.MethodGet, URL: list,
			ExpectedStatus: 200, ExpectedContent: []string{`"totalItems":0`},
		},

		// Reading is all: only an org admin writes.
		tests.ApiScenario{
			Name: "a supervisor cannot rename a location", Method: http.MethodPatch, URL: view(o.Branch1),
			Body: strings.NewReader(`{"name":"Renamed"}`), Headers: auth(t, o.Sup1),
			ExpectedStatus: 404, ExpectedContent: notFound,
		},
		tests.ApiScenario{
			Name: "a field user cannot rename their own branch", Method: http.MethodPatch, URL: view(o.Branch1),
			Body: strings.NewReader(`{"name":"Renamed"}`), Headers: auth(t, o.Field1),
			ExpectedStatus: 404, ExpectedContent: notFound,
		},
	)
	runShared(t, app, scenarios)

	if got, _ := app.FindRecordById(schema.Locations, o.Branch1.Id); got.GetString("name") != "Branch 1" {
		t.Errorf("a refused write renamed the branch to %q", got.GetString("name"))
	}
}
