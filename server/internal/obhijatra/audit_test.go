package obhijatra_test

import (
	"net/http"
	"strings"
	"testing"

	"ganigeorgiev.com/pocketbase/dbx"
	"ganigeorgiev.com/pocketbase/pocketbase/core"
	"ganigeorgiev.com/pocketbase/pocketbase/tests"

	"github.com/obhijatra/obhijatra/server/internal/audit"
	"github.com/obhijatra/obhijatra/server/internal/schema"
	"github.com/obhijatra/obhijatra/server/internal/testutil"
)

func auditCount(t testing.TB, app core.App) int64 {
	t.Helper()
	n, err := app.CountRecords(schema.Audit)
	if err != nil {
		t.Fatal(err)
	}
	return n
}

func mustVerify(t testing.TB, app core.App) audit.VerifyResult {
	t.Helper()
	r, err := audit.Verify(app)
	if err != nil {
		t.Fatal(err)
	}
	return r
}

func exec(t testing.TB, app core.App, sql string, params dbx.Params) {
	t.Helper()
	if _, err := app.NonconcurrentDB().NewQuery(sql).Bind(params).Execute(); err != nil {
		t.Fatalf("%s: %v", sql, err)
	}
}

func TestAuditChainVerifiesAndDetectsTampering(t *testing.T) {
	app := testutil.NewApp(t)
	defer app.Cleanup()

	o := testutil.SeedOrg(t, app)
	s := testutil.Submission(t, app, o, o.Field1, "uuid:b0000000-0000-4000-8000-000000000001")
	s.Set("review_state", schema.ReviewApproved)
	if err := app.Save(s); err != nil {
		t.Fatal(err)
	}
	if err := app.Delete(o.Unpublished); err != nil {
		t.Fatal(err)
	}

	total := auditCount(t, app)
	r := mustVerify(t, app)
	if !r.OK || r.Entries != total || r.HeadSeq != total {
		t.Fatalf("fresh chain should verify: %+v (rows %d)", r, total)
	}

	// Each kind of write is in the chain, with before/after fingerprints.
	for _, c := range []struct {
		action, collection, id string
		before, after          bool
	}{
		{audit.ActionCreate, schema.Submissions, s.Id, false, true},
		{audit.ActionUpdate, schema.Submissions, s.Id, true, true},
		{audit.ActionDelete, schema.FormVersions, o.Unpublished.Id, true, false},
	} {
		var e audit.Entry
		err := app.DB().Select("*").From(schema.Audit).
			Where(dbx.HashExp{"action": c.action, "collection": c.collection, "record_id": c.id}).
			One(&e)
		if err != nil {
			t.Errorf("no %s entry for %s/%s: %v", c.action, c.collection, c.id, err)
			continue
		}
		if (e.BeforeHash != "") != c.before || (e.AfterHash != "") != c.after {
			t.Errorf("%s %s: before=%q after=%q", c.action, c.collection, e.BeforeHash, e.AfterHash)
		}
	}

	// 1. Change one field of entry 3 in the database file.
	var original string
	if err := app.DB().NewQuery("SELECT record_id FROM audit WHERE seq = 3").Row(&original); err != nil {
		t.Fatal(err)
	}
	exec(t, app, "UPDATE audit SET record_id = 'tampered' WHERE seq = 3", nil)
	r = mustVerify(t, app)
	if r.OK || r.BrokenSeq != 3 || !strings.Contains(r.Problem, "changed") {
		t.Fatalf("changed entry not detected: %+v", r)
	}
	if r.Entries != 2 || r.HeadSeq != 2 {
		t.Errorf("the entries before the break should be reported intact: %+v", r)
	}
	exec(t, app, "UPDATE audit SET record_id = {:v} WHERE seq = 3", dbx.Params{"v": original})
	if r = mustVerify(t, app); !r.OK {
		t.Fatalf("restored chain should verify: %+v", r)
	}

	// 2. Rewrite entry 4 consistently (new hash), so only its successor's
	// link reveals it.
	var e4 audit.Entry
	if err := app.DB().Select("*").From(schema.Audit).Where(dbx.HashExp{"seq": 4}).One(&e4); err != nil {
		t.Fatal(err)
	}
	e4.Actor = "someone-else"
	newHash, err := audit.ComputeHash(e4)
	if err != nil {
		t.Fatal(err)
	}
	exec(t, app, "UPDATE audit SET actor = {:a}, hash = {:h} WHERE seq = 4", dbx.Params{"a": e4.Actor, "h": newHash})
	r = mustVerify(t, app)
	if r.OK || r.BrokenSeq != 5 || !strings.Contains(r.Problem, "link") {
		t.Fatalf("re-hashed entry not detected at its successor: %+v", r)
	}

	// 3. Delete an entry: the gap is reported.
	exec(t, app, "DELETE FROM audit WHERE seq IN (2, 3, 4)", nil)
	r = mustVerify(t, app)
	if r.OK || r.BrokenSeq != 5 || !strings.Contains(r.Problem, "missing") {
		t.Fatalf("deleted entries not detected: %+v", r)
	}
}

func TestAuditIsAppendOnly(t *testing.T) {
	app := testutil.NewApp(t)
	defer app.Cleanup()

	o := testutil.SeedOrg(t, app)
	su := testutil.Superuser(t, app)

	var first audit.Entry
	if err := app.DB().Select("*").From(schema.Audit).Where(dbx.HashExp{"seq": 1}).One(&first); err != nil {
		t.Fatal(err)
	}
	rec, err := app.FindRecordById(schema.Audit, first.ID)
	if err != nil {
		t.Fatal(err)
	}

	// Go code, which is what the Dashboard and every API call end up in.
	rec.Set("actor", "rewritten")
	if err := app.Save(rec); err == nil {
		t.Error("updating an audit row through app.Save must fail")
	}
	if err := app.Delete(rec); err == nil {
		t.Error("deleting an audit row through app.Delete must fail")
	}
	col, _ := app.FindCollectionByNameOrId(schema.Audit)
	forged := core.NewRecord(col)
	forged.Set("seq", 999)
	forged.Set("hash", "x")
	if err := app.Save(forged); err == nil {
		t.Error("creating an audit row through app.Save must fail")
	}
	if err := app.Delete(col); err == nil {
		t.Error("deleting the audit collection must fail")
	}
	col.UpdateRule = new(string)
	if err := app.Save(col); err == nil {
		t.Error("giving the audit collection an update rule must fail")
	}

	if r := mustVerify(t, app); !r.OK {
		t.Fatalf("chain should be intact after refused writes: %+v", r)
	}

	auditURL := "/api/collections/audit/records/" + first.ID
	runShared(t, app, []tests.ApiScenario{
		{
			Name: "superuser cannot edit an audit row through the API", Method: http.MethodPatch, URL: auditURL,
			Body: strings.NewReader(`{"actor":"rewritten"}`), Headers: auth(t, su),
			ExpectedStatus: 400, ExpectedContent: []string{`"status":400`},
		},
		{
			Name: "superuser cannot delete an audit row through the API", Method: http.MethodDelete, URL: auditURL,
			Headers: auth(t, su), ExpectedStatus: 400, ExpectedContent: []string{`"status":400`},
		},
		{
			Name: "superuser cannot run raw SQL", Method: http.MethodPost, URL: "/api/sql",
			Body: strings.NewReader(`{"query":"DELETE FROM audit"}`), Headers: auth(t, su),
			ExpectedStatus: 403, ExpectedContent: []string{"SQL console is switched off"},
		},
		{
			Name: "superuser cannot empty a collection", Method: http.MethodDelete, URL: "/api/collections/audit/truncate",
			Headers: auth(t, su), ExpectedStatus: 403, ExpectedContent: []string{`"status":403`},
		},
		{
			Name: "superuser cannot impersonate a user", Method: http.MethodPost,
			URL: "/api/collections/staff_users/impersonate/" + o.Admin.Id, Body: strings.NewReader(`{}`),
			Headers: auth(t, su), ExpectedStatus: 403, ExpectedContent: []string{`"status":403`},
		},
		{
			Name: "org admin can read the audit chain", Method: http.MethodGet, URL: "/api/collections/audit/records",
			Headers: auth(t, o.Admin), ExpectedStatus: 200, ExpectedContent: []string{`"totalItems":`, first.ID},
		},
		{
			Name: "supervisor cannot read the audit chain", Method: http.MethodGet, URL: "/api/collections/audit/records",
			Headers: auth(t, o.Sup1), ExpectedStatus: 200, ExpectedContent: []string{`"totalItems":0`},
		},
	})

	if r := mustVerify(t, app); !r.OK {
		t.Fatalf("chain should be intact after refused API calls: %+v", r)
	}
}

func TestAuditAttributionAndAtomicity(t *testing.T) {
	app := testutil.NewApp(t)
	defer app.Cleanup()

	o := testutil.SeedOrg(t, app)
	su := testutil.Superuser(t, app)
	adminToken, fieldToken := testutil.Token(t, o.Admin), testutil.Token(t, o.Field1)
	testutil.Prime(t, app, o.Admin, adminToken)
	testutil.Prime(t, app, o.Field1, fieldToken)

	before := auditCount(t, app)
	const instanceID = "uuid:c0000000-0000-4000-8000-000000000001"
	body, contentType := testutil.Multipart(t, testutil.Instance(instanceID, testutil.FormVersion, 2), nil)

	runShared(t, app, []tests.ApiScenario{
		{
			Name: "org admin creates a location through the API", Method: http.MethodPost,
			URL:  "/api/collections/locations/records",
			Body: strings.NewReader(`{"name":"Branch 3","parent":"` + o.Root.Id + `"}`), Headers: map[string]string{"Authorization": adminToken},
			ExpectedStatus: 200, ExpectedContent: []string{`"name":"Branch 3"`, `"path":"/` + o.Root.Id + `/`},
		},
		{
			Name: "field user submits", Method: http.MethodPost, URL: submitURL, Body: body,
			Headers:        map[string]string{"Content-Type": contentType, "Authorization": fieldToken},
			ExpectedStatus: 200, ExpectedContent: []string{`"status":"received"`},
		},
		{
			Name: "superuser edits form metadata in the Dashboard", Method: http.MethodPatch,
			URL: "/api/collections/forms/records/" + o.Form.Id, Body: strings.NewReader(`{"title":"Household visit v2"}`),
			Headers: auth(t, su), ExpectedStatus: 200, ExpectedContent: []string{`"title":"Household visit v2"`},
		},
		{
			Name: "a published form version cannot be changed, even by a superuser", Method: http.MethodPatch,
			URL: "/api/collections/form_versions/records/" + o.Version.Id, Body: strings.NewReader(`{"published":false}`),
			Headers: auth(t, su), ExpectedStatus: 400, ExpectedContent: []string{`"status":400`},
		},
	})

	// Three successful writes, three entries; the refused one left none.
	if got := auditCount(t, app) - before; got != 3 {
		t.Fatalf("want 3 new audit entries, got %d", got)
	}

	sub, err := app.FindFirstRecordByData(schema.Submissions, "instance_id", instanceID)
	if err != nil {
		t.Fatal(err)
	}

	for _, c := range []struct {
		collection, recordID, actor, actorCollection string
	}{
		{schema.Locations, "", o.Admin.Id, schema.StaffUsers},
		{schema.Submissions, sub.Id, o.Field1.Id, schema.FieldUsers},
		{schema.Forms, o.Form.Id, su.Id, schema.Superusers},
	} {
		where := dbx.HashExp{"collection": c.collection, "actor": c.actor}
		if c.recordID != "" {
			where["record_id"] = c.recordID
		}
		var e audit.Entry
		if err := app.DB().Select("*").From(schema.Audit).Where(where).One(&e); err != nil {
			t.Errorf("no %s entry attributed to %s %s: %v", c.collection, c.actorCollection, c.actor, err)
			continue
		}
		if e.ActorCollection != c.actorCollection {
			t.Errorf("%s entry: actor_collection %q, want %q", c.collection, e.ActorCollection, c.actorCollection)
		}
	}

	if r := mustVerify(t, app); !r.OK {
		t.Fatalf("chain should verify: %+v", r)
	}
}
