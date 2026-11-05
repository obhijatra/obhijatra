package obhijatra_test

import (
	"encoding/json"
	"net/http"
	"strings"
	"testing"

	"ganigeorgiev.com/pocketbase/dbx"
	"ganigeorgiev.com/pocketbase/pocketbase/core"

	"github.com/obhijatra/obhijatra/server/internal/places"
	"github.com/obhijatra/obhijatra/server/internal/schema"
	"github.com/obhijatra/obhijatra/server/internal/testutil"
)

const placesURL = "/api/collections/locations/records"

func importURL() string { return "/api/obhijatra/v1" + places.ImportPath }

func placeNamed(t *testing.T, app core.App, name string) *core.Record {
	t.Helper()
	r, err := app.FindFirstRecordByData(schema.Locations, "name", name)
	if err != nil {
		t.Fatalf("no place %q: %v", name, err)
	}
	return r
}

func TestPlacesFollowTheTreeRules(t *testing.T) {
	app := testutil.NewApp(t)
	defer app.Cleanup()
	o := testutil.SeedOrg(t, app)
	mux := serveMux(t, app)
	admin := testutil.Token(t, o.Admin)

	cases := []struct {
		name string
		body map[string]any
		want string
	}{
		{"a second root", map[string]any{"name": "Elsewhere"}, "validation_place_parent_required"},
		{"a sibling's name, other capitals", map[string]any{"name": " branch 1 ", "parent": o.Root.Id}, "validation_place_name_taken"},
		{"no name", map[string]any{"name": "  ", "parent": o.Root.Id}, `"name"`},
	}
	for _, c := range cases {
		if status, body := call(mux, http.MethodPost, placesURL, admin, c.body); status != http.StatusBadRequest || !strings.Contains(body, c.want) {
			t.Errorf("%s: %d %s", c.name, status, body)
		}
	}
	if status, body := call(mux, http.MethodPost, placesURL, testutil.Token(t, o.Sup1), map[string]any{"name": "Area 9", "parent": o.Root.Id}); status == http.StatusOK {
		t.Errorf("a supervisor added a place: %s", body)
	}
	status, body := call(mux, http.MethodPost, placesURL, admin, map[string]any{"name": "Area 9", "code": " A9 ", "parent": o.Root.Id})
	if status != http.StatusOK {
		t.Fatalf("add a place: %d %s", status, body)
	}
	if status, body := call(mux, http.MethodPost, placesURL, admin, map[string]any{"name": "Area 10", "code": "a9", "parent": o.Root.Id}); status != http.StatusBadRequest {
		t.Errorf("a code used twice (other capitals): %d %s", status, body)
	}
	area := placeNamed(t, app, "Area 9")
	if area.GetString("code") != "A9" {
		t.Errorf("the code was stored as %q", area.GetString("code"))
	}
	// A place cannot move.
	if status, _ := call(mux, http.MethodPatch, placesURL+"/"+area.Id, admin, map[string]any{"parent": o.Branch1.Id}); status == http.StatusOK {
		t.Error("a place moved")
	}
}

func TestClosingAPlace(t *testing.T) {
	app := testutil.NewApp(t)
	defer app.Cleanup()
	o := testutil.SeedOrg(t, app)
	mux := serveMux(t, app)
	admin := testutil.Token(t, o.Admin)
	branch := func(id string) string { return placesURL + "/" + id }

	if status, body := call(mux, http.MethodPatch, branch(o.Root.Id), admin, map[string]any{"closed": true}); status != http.StatusBadRequest ||
		!strings.Contains(body, "validation_place_root") {
		t.Errorf("closing the organisation: %d %s", status, body)
	}
	// Branch 1 has active people.
	if status, body := call(mux, http.MethodPatch, branch(o.Branch1.Id), admin, map[string]any{"closed": true}); status != http.StatusBadRequest ||
		!strings.Contains(body, "validation_place_has_people") {
		t.Errorf("closing a place with active people: %d %s", status, body)
	}

	empty := testutil.Location(t, app, "Empty branch", o.Root)
	inner := testutil.Location(t, app, "Inner unit", empty)
	if status, body := call(mux, http.MethodPatch, branch(empty.Id), admin, map[string]any{"closed": true}); status != http.StatusBadRequest ||
		!strings.Contains(body, "validation_place_has_open_places") {
		t.Errorf("closing a place with an open place inside: %d %s", status, body)
	}
	for _, id := range []string{inner.Id, empty.Id} {
		if status, body := call(mux, http.MethodPatch, branch(id), admin, map[string]any{"closed": true}); status != http.StatusOK {
			t.Fatalf("close: %d %s", status, body)
		}
	}
	// Nothing new goes into a closed place.
	if status, body := call(mux, http.MethodPost, placesURL, admin, map[string]any{"name": "New unit", "parent": empty.Id}); status != http.StatusBadRequest {
		t.Errorf("a place under a closed place: %d %s", status, body)
	}
	if status, body := call(mux, http.MethodPatch, "/api/collections/field_users/records/"+o.Field1.Id, admin, map[string]any{"location": empty.Id}); status != http.StatusBadRequest ||
		!strings.Contains(body, "validation_place_closed") {
		t.Errorf("a person moved to a closed place: %d %s", status, body)
	}
	// Reopening goes top down.
	if status, body := call(mux, http.MethodPatch, branch(inner.Id), admin, map[string]any{"closed": false}); status != http.StatusBadRequest {
		t.Errorf("reopening under a closed place: %d %s", status, body)
	}
	for _, id := range []string{empty.Id, inner.Id} {
		if status, body := call(mux, http.MethodPatch, branch(id), admin, map[string]any{"closed": false}); status != http.StatusOK {
			t.Fatalf("reopen: %d %s", status, body)
		}
	}
}

func TestDeletingAPlaceOnlyWhenUnused(t *testing.T) {
	app := testutil.NewApp(t)
	defer app.Cleanup()
	o := testutil.SeedOrg(t, app)
	mux := serveMux(t, app)
	admin := testutil.Token(t, o.Admin)

	// Someone left Branch 2 but their records are stamped with its path.
	testutil.Submission(t, app, o, o.Field2, "uuid:place-1")
	o.Field2.Set("active", false)
	o.Field2.Set("location", o.Branch1.Id)
	if err := app.Save(o.Field2); err != nil {
		t.Fatal(err)
	}
	o.Sup2.Set("location", o.Branch1.Id)
	if err := app.Save(o.Sup2); err != nil {
		t.Fatal(err)
	}
	if n, _ := app.CountRecords(schema.FieldUsers, dbx.HashExp{"location": o.Branch2.Id}); n != 0 {
		t.Fatalf("setup: %d people still in Branch 2", n)
	}

	for _, c := range []struct{ name, id, want string }{
		{"the organisation", o.Root.Id, "validation_place_root"},
		{"a place with people", o.Branch1.Id, "validation_place_in_use"},
		{"a place with records", o.Branch2.Id, "validation_place_in_use"},
	} {
		if status, body := call(mux, http.MethodDelete, placesURL+"/"+c.id, admin, nil); status == http.StatusNoContent ||
			!strings.Contains(body, c.want) {
			t.Errorf("deleting %s: %d %s", c.name, status, body)
		}
	}

	unused := testutil.Location(t, app, "Never used", o.Root)
	if status, body := call(mux, http.MethodDelete, placesURL+"/"+unused.Id, testutil.Token(t, o.Sup1), nil); status == http.StatusNoContent {
		t.Errorf("a supervisor deleted a place: %s", body)
	}
	if status, body := call(mux, http.MethodDelete, placesURL+"/"+unused.Id, admin, nil); status != http.StatusNoContent {
		t.Errorf("deleting an unused place: %d %s", status, body)
	}
}

func importPlaces(t *testing.T, mux http.Handler, token string, req map[string]any) (int, places.Result, string) {
	t.Helper()
	status, body := call(mux, http.MethodPost, importURL(), token, req)
	var r places.Result
	_ = json.Unmarshal([]byte(body), &r)
	return status, r, body
}

func TestImportingPlacesFromASpreadsheet(t *testing.T) {
	app := testutil.NewApp(t)
	defer app.Cleanup()
	o := testutil.SeedOrg(t, app)
	mux := serveMux(t, app)
	admin := testutil.Token(t, o.Admin)

	rows := []map[string]any{
		{"line": 2, "path": []string{"Dhaka region", "Mirpur area", "Mirpur-10 branch"}, "code": "MRP10"},
		{"line": 3, "path": []string{"Dhaka region", "Mirpur area", "Pallabi branch"}, "code": "PLB"},
		{"line": 4, "path": []string{"dhaka region ", "Uttara area"}},
		{"line": 5, "path": []string{"Branch 1", "Ward 3"}}, // Branch 1 already exists
	}

	if status, _, body := importPlaces(t, mux, testutil.Token(t, o.Sup1), map[string]any{"parent": o.Root.Id, "rows": rows}); status != http.StatusForbidden {
		t.Errorf("a supervisor imported places: %d %s", status, body)
	}

	before, _ := app.CountRecords(schema.Locations)
	status, r, body := importPlaces(t, mux, admin, map[string]any{"parent": o.Root.Id, "rows": rows, "dry_run": true})
	if status != http.StatusOK || r.Created != 6 || r.Existing != 1 || len(r.Problems) != 0 || r.Saved {
		t.Fatalf("dry run: %d %s", status, body)
	}
	if after, _ := app.CountRecords(schema.Locations); after != before {
		t.Fatalf("the dry run saved %d places", after-before)
	}

	status, r, body = importPlaces(t, mux, admin, map[string]any{"parent": o.Root.Id, "rows": rows})
	if status != http.StatusOK || r.Created != 6 || !r.Saved {
		t.Fatalf("import: %d %s", status, body)
	}
	branch := placeNamed(t, app, "Mirpur-10 branch")
	area := placeNamed(t, app, "Mirpur area")
	region := placeNamed(t, app, "Dhaka region")
	if branch.GetString("code") != "MRP10" || branch.GetString("parent") != area.Id || area.GetString("parent") != region.Id ||
		region.GetString("parent") != o.Root.Id || !strings.HasPrefix(branch.GetString("path"), o.Root.GetString("path")) {
		t.Errorf("the tree was built wrongly: %v %v %v", branch.PublicExport(), area.PublicExport(), region.PublicExport())
	}
	if ward := placeNamed(t, app, "Ward 3"); ward.GetString("parent") != o.Branch1.Id {
		t.Error("Ward 3 is not under the existing Branch 1")
	}

	// The same file again makes nothing new.
	status, r, body = importPlaces(t, mux, admin, map[string]any{"parent": o.Root.Id, "rows": rows})
	if status != http.StatusOK || r.Created != 0 || r.Existing != 7 {
		t.Errorf("the second import: %d %s", status, body)
	}
}

func TestAnImportWithProblemsSavesNothing(t *testing.T) {
	app := testutil.NewApp(t)
	defer app.Cleanup()
	o := testutil.SeedOrg(t, app)
	mux := serveMux(t, app)
	admin := testutil.Token(t, o.Admin)

	closed := testutil.Location(t, app, "Old area", o.Root)
	closed.Set("closed", true)
	if err := app.Save(closed); err != nil {
		t.Fatal(err)
	}
	if _, err := app.FindFirstRecordByData(schema.Locations, "name", "Branch 2"); err != nil {
		t.Fatal(err)
	}
	b2 := placeNamed(t, app, "Branch 2")
	b2.Set("code", "B2")
	if err := app.Save(b2); err != nil {
		t.Fatal(err)
	}

	before, _ := app.CountRecords(schema.Locations)
	rows := []map[string]any{
		{"line": 2, "path": []string{"Fine area", "Fine branch"}},
		{"line": 3, "path": []string{"Old area", "New branch"}},     // under a closed place
		{"line": 4, "path": []string{"Another area"}, "code": "b2"}, // code taken
		{"line": 5, "path": []string{"Area X"}, "code": "X1"},       //
		{"line": 6, "path": []string{"Area Y"}, "code": "x1"},       // code twice in the file
		{"line": 7, "path": []string{"  ", ""}},                     // no name
		{"line": 8, "path": []string{"Branch 2"}, "code": "OTHER"},  // has another code
		{"line": 9, "path": []string{strings.Repeat("n", 201)}},     // too long
	}
	status, r, body := importPlaces(t, mux, admin, map[string]any{"parent": o.Root.Id, "rows": rows})
	if status != http.StatusBadRequest || r.Saved {
		t.Fatalf("import with problems: %d %s", status, body)
	}
	got := map[int]string{}
	for _, p := range r.Problems {
		got[p.Line] = p.Code
	}
	for line, code := range map[int]string{
		3: places.ProblemPlaceClosed, 4: places.ProblemCodeTaken, 6: places.ProblemCodeRepeated,
		7: places.ProblemNoName, 8: places.ProblemCodeMismatch, 9: places.ProblemNameTooLong,
	} {
		if got[line] != code {
			t.Errorf("line %d: problem %q, want %q: %s", line, got[line], code, body)
		}
	}
	if got[2] != "" || got[5] != "" {
		t.Errorf("a good line was reported: %s", body)
	}
	if after, _ := app.CountRecords(schema.Locations); after != before {
		t.Errorf("%d places were saved despite the problems", after-before)
	}

	if status, _, body := importPlaces(t, mux, admin, map[string]any{"parent": closed.Id, "rows": rows[:1]}); status != http.StatusBadRequest {
		t.Errorf("import into a closed place: %d %s", status, body)
	}
}
