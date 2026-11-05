// Package places imports a spreadsheet of places into the organisation
// tree (docs/decisions/0007-places.md). The rest of place management uses
// the records API, governed by the guards.
package places

import (
	"errors"
	"fmt"
	"net/http"
	"strings"

	"ganigeorgiev.com/pocketbase/dbx"
	validation "ganigeorgiev.com/pocketbase/ozzo-validation/v4"
	"ganigeorgiev.com/pocketbase/pocketbase/apis"
	"ganigeorgiev.com/pocketbase/pocketbase/core"
	"ganigeorgiev.com/pocketbase/pocketbase/tools/hook"

	"github.com/obhijatra/obhijatra/server/internal/api"
	"github.com/obhijatra/obhijatra/server/internal/audit"
	"github.com/obhijatra/obhijatra/server/internal/schema"
)

// ImportPath is the import route, under api.Prefix.
const ImportPath = "/places/import"

// importBodyLimit fits schema.MaxPlacesImport rows of long names.
const importBodyLimit = 8 << 20

// Register binds the import route.
func Register(app core.App) {
	app.OnServe().Bind(&hook.Handler[*core.ServeEvent]{
		Id: "obhijatraPlacesRoutes",
		Func: func(se *core.ServeEvent) error {
			se.Router.POST(api.Prefix+ImportPath, importPlaces).Bind(
				apis.RequireAuth(schema.StaffUsers),
				apis.BodyLimit(importBodyLimit),
			)
			return se.Next()
		},
	})
}

// Row is one spreadsheet row: the names from the top level down (under
// the chosen parent), and an optional code for the last one. Line is the
// row's line in the file, for messages.
type Row struct {
	Line int      `json:"line"`
	Path []string `json:"path"`
	Code string   `json:"code"`
}

// Request is the body of POST /places/import.
type Request struct {
	Parent string `json:"parent"`
	Rows   []Row  `json:"rows"`
	DryRun bool   `json:"dry_run"`
}

// Problem is something wrong with one row. Code says which problem, so
// the apps can word it in the person's language; Name is the place and
// Value the code or limit it is about, when there is one.
type Problem struct {
	Line    int    `json:"line"`
	Code    string `json:"code"`
	Message string `json:"message"`
	Name    string `json:"name,omitempty"`
	Value   string `json:"value,omitempty"`
}

// Problem codes.
const (
	ProblemNoName       = "no_name"
	ProblemTooDeep      = "too_deep"
	ProblemCodeTooLong  = "code_too_long"
	ProblemNameTooLong  = "name_too_long"
	ProblemPlaceClosed  = "place_closed"
	ProblemCodeMismatch = "code_mismatch" // the place already has another code
	ProblemCodeRepeated = "code_repeated" // the same code twice in the file
	ProblemCodeTaken    = "code_taken"    // another place has the code
)

// Result is the answer: how many places the import makes and finds, and
// any problems. Saved is true only when the places were saved.
type Result struct {
	Created  int       `json:"created"`
	Existing int       `json:"existing"`
	Problems []Problem `json:"problems"`
	Saved    bool      `json:"saved"`
}

// node is a place, stored or about to be.
type node struct {
	id, code string
	closed   bool
	children map[string]*node // by lower-case name, loaded on first use
	stored   bool             // in the database
	loaded   bool             // stored children read into children
	name     string
}

// importPlaces checks every row and, when nothing is wrong and this is
// not a dry run, creates the missing places in one transaction: all or
// nothing. A place whose name already exists at that level (ignoring
// capitals and surrounding spaces) is reused, so the same file can be
// imported twice without making duplicates.
func importPlaces(e *core.RequestEvent) error {
	if e.Auth == nil || e.Auth.GetString("role") != schema.RoleOrgAdmin || !e.Auth.GetBool("active") {
		return e.ForbiddenError("Only an organisation admin can add places.", nil)
	}
	var req Request
	if err := e.BindBody(&req); err != nil {
		return e.BadRequestError("The request could not be read.", err)
	}
	if len(req.Rows) == 0 {
		return e.BadRequestError("The file has no places in it.", nil)
	}
	if len(req.Rows) > schema.MaxPlacesImport {
		return e.BadRequestError(fmt.Sprintf("A file can hold at most %d places. Split it into smaller files.", schema.MaxPlacesImport), nil)
	}

	var result Result
	errStop := errors.New("stop") // rolls the transaction back after a dry run or problems
	err := audit.RunAs(e.App, audit.ActorFromRequest(e), func(txApp core.App) error {
		parent, err := txApp.FindRecordById(schema.Locations, req.Parent)
		if err != nil {
			return validation.Errors{"parent": validation.NewError("validation_place_missing", "Choose where the new places go.")}
		}
		if parent.GetBool("closed") {
			return validation.Errors{"parent": validation.NewError("validation_place_closed", "This place is closed. Choose an open place.")}
		}
		locations, err := txApp.FindCollectionByNameOrId(schema.Locations)
		if err != nil {
			return err
		}

		top := &node{id: parent.Id, stored: true, name: parent.GetString("name")}
		codes := map[string]bool{} // codes given in this file, lower case
		created := map[*node]bool{}
		seen := map[*node]bool{}

		for i, row := range req.Rows {
			line := row.Line
			if line == 0 {
				line = i + 1
			}
			problem := func(code, name, value, format string, args ...any) {
				result.Problems = append(result.Problems, Problem{Line: line, Code: code, Name: name, Value: value,
					Message: fmt.Sprintf(format, args...)})
			}

			names := make([]string, 0, len(row.Path))
			for _, n := range row.Path {
				if n = strings.TrimSpace(n); n != "" {
					names = append(names, n)
				}
			}
			code := strings.TrimSpace(row.Code)
			switch {
			case len(names) == 0:
				problem(ProblemNoName, "", "", "This row has no place name.")
				continue
			case len(names) > schema.MaxPlaceDepth:
				problem(ProblemTooDeep, "", fmt.Sprint(schema.MaxPlaceDepth), "This row has more than %d levels.", schema.MaxPlaceDepth)
				continue
			case len(code) > 50:
				problem(ProblemCodeTooLong, "", code, "The code %q is longer than 50 characters.", code)
				continue
			}
			bad := false
			for _, n := range names {
				if len([]rune(n)) > 200 {
					problem(ProblemNameTooLong, n, "", "The name %q is longer than 200 characters.", n)
					bad = true
				}
			}
			if bad {
				continue
			}

			cur := top
			for depth, name := range names {
				if err := loadChildren(txApp, cur); err != nil {
					return err
				}
				next, ok := cur.children[strings.ToLower(name)]
				if !ok {
					next = &node{name: name, children: map[string]*node{}}
					cur.children[strings.ToLower(name)] = next
					created[next] = true
				}
				if next.closed {
					problem(ProblemPlaceClosed, next.name, "", "%q is closed. Reopen it first, or remove this row.", next.name)
					bad = true
					break
				}
				if depth == len(names)-1 && code != "" {
					switch {
					case next.code != "" && !strings.EqualFold(next.code, code):
						problem(ProblemCodeMismatch, next.name, next.code, "%q already has the code %q, not %q.", next.name, next.code, code)
						bad = true
					case next.code == "" && codes[strings.ToLower(code)]:
						problem(ProblemCodeRepeated, "", code, "The code %q is used more than once in this file.", code)
						bad = true
					case next.code == "":
						taken, err := txApp.CountRecords(schema.Locations,
							dbx.NewExp("[[code]] = {:code} COLLATE NOCASE", dbx.Params{"code": code}))
						if err != nil {
							return err
						}
						if taken > 0 {
							problem(ProblemCodeTaken, "", code, "Another place already has the code %q.", code)
							bad = true
						} else {
							next.code = code
							codes[strings.ToLower(code)] = true
						}
					}
				}
				if bad {
					break
				}
				seen[next] = true
				cur = next
			}
		}

		for n := range seen {
			if created[n] {
				result.Created++
			} else {
				result.Existing++
			}
		}
		if len(result.Problems) > 0 || req.DryRun {
			return errStop
		}

		// Create parents before children.
		var save func(parentID string, n *node) error
		save = func(parentID string, n *node) error {
			for _, child := range n.children {
				if !seen[child] {
					continue
				}
				if created[child] && !child.stored {
					r := core.NewRecord(locations)
					r.Set("name", child.name)
					r.Set("code", child.code)
					r.Set("parent", parentID)
					if err := txApp.Save(r); err != nil {
						return fmt.Errorf("save %q: %w", child.name, err)
					}
					child.id, child.stored = r.Id, true
				} else if child.stored && child.code != "" {
					stored, err := txApp.FindRecordById(schema.Locations, child.id)
					if err != nil {
						return err
					}
					if stored.GetString("code") == "" {
						stored.Set("code", child.code)
						if err := txApp.Save(stored); err != nil {
							return fmt.Errorf("save %q: %w", child.name, err)
						}
					}
				}
				if err := save(child.id, child); err != nil {
					return err
				}
			}
			return nil
		}
		if err := save(top.id, top); err != nil {
			return err
		}
		result.Saved = true
		return nil
	})

	switch {
	case errors.Is(err, errStop):
		if result.Problems == nil {
			result.Problems = []Problem{}
		}
		if len(result.Problems) > 0 && !req.DryRun {
			return e.JSON(http.StatusBadRequest, result)
		}
		return e.JSON(http.StatusOK, result)
	case err != nil:
		var verr validation.Errors
		if errors.As(err, &verr) {
			return e.BadRequestError("The import could not start.", verr)
		}
		return e.InternalServerError("", err)
	}
	result.Problems = []Problem{}
	return e.JSON(http.StatusOK, result)
}

// loadChildren reads n's stored children once.
func loadChildren(app core.App, n *node) error {
	if n.children == nil {
		n.children = map[string]*node{}
	}
	if !n.stored || n.loaded {
		return nil
	}
	n.loaded = true
	rows, err := app.FindRecordsByFilter(schema.Locations, "parent = {:p}", "", 0, 0, dbx.Params{"p": n.id})
	if err != nil {
		return err
	}
	for _, r := range rows {
		key := strings.ToLower(strings.TrimSpace(r.GetString("name")))
		if _, dup := n.children[key]; !dup {
			n.children[key] = &node{id: r.Id, code: r.GetString("code"), closed: r.GetBool("closed"),
				stored: true, name: r.GetString("name")}
		}
	}
	return nil
}
