package api

import (
	"errors"
	"fmt"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"slices"
	"time"

	"ganigeorgiev.com/pocketbase/dbx"
	"ganigeorgiev.com/pocketbase/pocketbase/core"
	"ganigeorgiev.com/pocketbase/pocketbase/tools/filesystem"
	"ganigeorgiev.com/pocketbase/pocketbase/tools/types"

	"github.com/obhijatra/obhijatra/server/internal/audit"
	"github.com/obhijatra/obhijatra/server/internal/export"
	"github.com/obhijatra/obhijatra/server/internal/schema"
	"github.com/obhijatra/obhijatra/server/internal/version"
	"github.com/obhijatra/obhijatra/server/internal/xform"
)

// ExportSubmissionsPath downloads one form's submissions as a zip package
// (docs/decisions/0009-data-export.md).
const ExportSubmissionsPath = "/exports/submissions"

// exportBatch is how many submissions are read from the database at once.
const exportBatch = 200

// ExportRequest is the body of POST /exports/submissions.
type ExportRequest struct {
	Form         string   `json:"form"`          // the forms record id
	From         string   `json:"from"`          // optional: received at or after, RFC 3339
	To           string   `json:"to"`            // optional: received before, RFC 3339
	ReviewStates []string `json:"review_states"` // optional: only these review states
	IncludeMedia bool     `json:"include_media"`
}

// centralReviewState is the ReviewState column value ODK Central writes
// for each Obhijatra review state (Central leaves "received" empty).
var centralReviewState = map[string]string{
	schema.ReviewReceived:  "",
	schema.ReviewEdited:    "edited",
	schema.ReviewHasIssues: "hasIssues",
	schema.ReviewApproved:  "approved",
	schema.ReviewRejected:  "rejected",
}

var errRecentSignInRequired = deviceProblem(http.StatusForbidden, schema.ReasonRecentSignInRequired,
	"To download data, sign in again: your last sign-in was more than 15 minutes ago.")

// exportSubmissions streams a form's submissions as a zip package. Org
// admins may download every submission; M&E staff the submissions of their
// part of the organisation tree. The person must have signed in (not only
// refreshed the session) within schema.RecentSignIn, on an approved device
// (the device gate has checked it). Every download is recorded in the
// exports collection, and so in the audit chain, before the first byte is
// sent, and marked completed with the SHA-256 of its manifest at the end.
func exportSubmissions(e *core.RequestEvent) error {
	user := e.Auth
	if user == nil || user.Collection().Name != schema.StaffUsers || !user.GetBool("active") ||
		!slices.Contains(schema.ExportRoles, user.GetString("role")) {
		return e.ForbiddenError("Only organisation admins and M&E staff can download submissions.", nil)
	}
	scope := ""
	if user.GetString("role") != schema.RoleOrgAdmin {
		scope = user.GetString("location_path")
		if scope == "" {
			return e.ForbiddenError("Your account has no place, so there is nothing you may download.", nil)
		}
	}
	if !signedInRecently(e) {
		return errRecentSignInRequired
	}

	var body ExportRequest
	if err := e.BindBody(&body); err != nil {
		return e.BadRequestError("The request could not be read.", err)
	}
	from, to, err := exportPeriod(body)
	if err != nil {
		return err
	}
	for _, s := range body.ReviewStates {
		if !slices.Contains(schema.ReviewStates, s) {
			return exportFieldError("review_states", "validation_invalid_review_state", "Unknown review state: "+s+".")
		}
	}
	form, err := e.App.FindRecordById(schema.Forms, body.Form)
	if err != nil {
		return exportFieldError("form", "validation_form_not_found", "This form does not exist.")
	}

	versions, err := e.App.FindAllRecords(schema.FormVersions, dbx.HashExp{"form": form.Id})
	if err != nil {
		return err
	}
	columns := columnsVersion(versions)
	if columns == nil {
		return exportFieldError("form", "validation_form_has_no_version", "This form has no version yet, so it has no submissions.")
	}

	fsys, err := e.App.NewFilesystem()
	if err != nil {
		return err
	}
	defer fsys.Close()

	fields, err := readFields(fsys, columns)
	if err != nil {
		return fmt.Errorf("form version %s: %w", columns.GetString("version"), err)
	}

	where := []dbx.Expression{dbx.HashExp{"form": form.Id}}
	if !from.IsZero() {
		where = append(where, dbx.NewExp("received_at >= {:from}", dbx.Params{"from": from.UTC().Format(types.DefaultDateLayout)}))
	}
	if !to.IsZero() {
		where = append(where, dbx.NewExp("received_at < {:to}", dbx.Params{"to": to.UTC().Format(types.DefaultDateLayout)}))
	}
	if len(body.ReviewStates) > 0 {
		states := make([]any, len(body.ReviewStates))
		for i, s := range body.ReviewStates {
			states[i] = s
		}
		where = append(where, dbx.In("review_state", states...))
	}
	if scope != "" {
		where = append(where, dbx.NewExp("location_path LIKE {:scope}", dbx.Params{"scope": scope + "%"}))
	}

	versionNames := map[string]string{}
	for _, v := range versions {
		versionNames[v.Id] = v.GetString("version")
	}
	used := map[string]bool{columns.Id: true}
	names := map[string]string{}

	each := func(fn func(export.Submission) error) error {
		var lastAt, lastID string
		for {
			q := e.App.RecordQuery(schema.Submissions).AndWhere(dbx.And(where...))
			if lastID != "" {
				q = q.AndWhere(dbx.NewExp("(received_at > {:at} OR (received_at = {:at} AND id > {:id}))",
					dbx.Params{"at": lastAt, "id": lastID}))
			}
			var batch []*core.Record
			if err := q.OrderBy("received_at ASC", "id ASC").Limit(exportBatch).All(&batch); err != nil {
				return err
			}
			for _, r := range batch {
				used[r.GetString("form_version")] = true
				if err := fn(submissionOf(e.App, fsys, r, versionNames, names)); err != nil {
					return err
				}
			}
			if len(batch) < exportBatch {
				return nil
			}
			last := batch[len(batch)-1]
			lastAt, lastID = last.GetDateTime("received_at").String(), last.Id
		}
	}

	reload := func(ids []string) ([]export.Submission, error) {
		records, err := e.App.FindRecordsByIds(schema.Submissions, ids)
		if err != nil {
			return nil, err
		}
		byID := make(map[string]*core.Record, len(records))
		for _, r := range records {
			byID[r.Id] = r
		}
		subs := make([]export.Submission, 0, len(ids))
		for _, id := range ids {
			if r, ok := byID[id]; ok {
				subs = append(subs, submissionOf(e.App, fsys, r, versionNames, names))
			}
		}
		return subs, nil
	}

	settings, _ := e.App.FindFirstRecordByFilter(schema.Settings, "")
	organisation := ""
	if settings != nil {
		organisation = settings.GetString("organisation_name")
	}
	device, _ := e.Get(audit.DeviceStoreKey).(string)
	filters := map[string]any{
		"from":          body.From,
		"to":            body.To,
		"review_states": body.ReviewStates,
		"include_media": body.IncludeMedia,
		"place_scope":   scope,
	}
	now := time.Now().UTC()

	// PocketBase's temporary folder is left out of backups and emptied
	// each time the server starts, so a download cut short leaves nothing.
	tempDir := filepath.Join(e.App.DataDir(), core.LocalTempDirName, "exports")
	if err := os.MkdirAll(tempDir, 0o700); err != nil {
		return err
	}
	pkg := &export.Package{
		FormID:         form.GetString("form_id"),
		FormTitle:      form.GetString("title"),
		Fields:         fields,
		ColumnsVersion: columns.GetString("version"),
		Organisation:   organisation,
		ExportedAt:     now,
		ExportedBy:     map[string]string{"id": user.Id, "name": user.GetString("name"), "role": user.GetString("role")},
		Device:         device,
		Filters:        filters,
		IncludeMedia:   body.IncludeMedia,
		ServerVersion:  version.Version,
		SchemaVersion:  version.SchemaVersion,
		Each:           each,
		Reload:         reload,
	}
	prepared, err := pkg.Prepare(tempDir)
	if err != nil {
		return fmt.Errorf("export: %w", err)
	}
	defer prepared.Close()
	for _, v := range versions {
		if used[v.Id] {
			v := v
			pkg.Versions = append(pkg.Versions, export.FormVersion{
				Version: v.GetString("version"),
				XML:     fileOpener(fsys, v, v.GetString("xform")),
			})
		}
	}

	// Record the download before the first byte leaves.
	exports, err := e.App.FindCollectionByNameOrId(schema.Exports)
	if err != nil {
		return err
	}
	entry := core.NewRecord(exports)
	entry.Set("staff_user", user.Id)
	entry.Set("device", device)
	entry.Set("form", form.Id)
	entry.Set("filters", filters)
	entry.Set("submissions", prepared.Count)
	entry.Set("files", prepared.Files)
	entry.Set("status", schema.ExportStarted)
	if err := audit.RunAs(e.App, audit.ActorFromRequest(e), func(tx core.App) error { return tx.Save(entry) }); err != nil {
		return err
	}

	name := export.SafeName(fmt.Sprintf("%s_%s", pkg.FormID, now.Format("2006-01-02"))) + ".zip"
	h := e.Response.Header()
	h.Set("Content-Type", "application/zip")
	h.Set("Content-Disposition", `attachment; filename="`+name+`"`)
	h.Set("Cache-Control", "no-store")
	h.Set("X-Content-Type-Options", "nosniff")
	e.Response.WriteHeader(http.StatusOK)

	// A large download may take longer than the server's usual 5-minute
	// write limit: each write moves the deadline on.
	rc := http.NewResponseController(e.Response)
	manifest, err := prepared.Write(&deadlineWriter{w: e.Response, rc: rc})

	status := schema.ExportCompleted
	if err != nil {
		status = schema.ExportFailed
		e.App.Logger().Error("export: the download stopped", "form", pkg.FormID, "error", err)
	}
	entry.Set("status", status)
	entry.Set("manifest_sha256", manifest)
	if err := audit.RunAs(e.App, audit.ActorFromRequest(e), func(tx core.App) error { return tx.Save(entry) }); err != nil {
		e.App.Logger().Error("export: could not record the end of a download", "error", err)
	}
	return nil // the response has started: an error can no longer be sent
}

// deadlineWriter moves the response's write deadline on before each
// write, so a long download is not cut off while it keeps moving.
type deadlineWriter struct {
	w  io.Writer
	rc *http.ResponseController
}

func (d *deadlineWriter) Write(p []byte) (int, error) {
	_ = d.rc.SetWriteDeadline(time.Now().Add(2 * time.Minute))
	return d.w.Write(p)
}

// signedInRecently reports whether the request's session was made by a
// sign-in (not a refresh) within schema.RecentSignIn.
func signedInRecently(e *core.RequestEvent) bool {
	s, err := e.App.FindFirstRecordByData(schema.Sessions, "token_hash", tokenHash(e))
	if err != nil || s.GetBool("revoked") || s.GetString(ownerField(e.Auth)) != e.Auth.Id {
		return false
	}
	at := s.GetDateTime("signed_in")
	return !at.IsZero() && time.Since(at.Time()) <= schema.RecentSignIn
}

func exportPeriod(b ExportRequest) (from, to time.Time, err error) {
	parse := func(field, v string) (time.Time, error) {
		if v == "" {
			return time.Time{}, nil
		}
		t, err := time.Parse(time.RFC3339, v)
		if err != nil {
			return time.Time{}, exportFieldError(field, "validation_invalid_date", "Give a date and time such as 2026-11-01T00:00:00+06:00.")
		}
		return t, nil
	}
	if from, err = parse("from", b.From); err != nil {
		return
	}
	if to, err = parse("to", b.To); err != nil {
		return
	}
	if !from.IsZero() && !to.IsZero() && !from.Before(to) {
		err = exportFieldError("to", "validation_period_empty", "The end must be after the start.")
	}
	return
}

// columnsVersion is the version whose fields lay out the CSV tables: the
// most recently published one, or else the most recent one, as ODK
// Central uses the form's current version.
func columnsVersion(versions []*core.Record) *core.Record {
	var best *core.Record
	for _, v := range versions {
		if best == nil {
			best = v
			continue
		}
		bp, vp := best.GetBool("published"), v.GetBool("published")
		switch {
		case vp && !bp:
			best = v
		case vp == bp:
			at := func(r *core.Record) time.Time {
				if t := r.GetDateTime("published_at"); !t.IsZero() {
					return t.Time()
				}
				return r.GetDateTime("created").Time()
			}
			if at(v).After(at(best)) {
				best = v
			}
		}
	}
	return best
}

func readFields(fsys *filesystem.System, v *core.Record) ([]xform.Field, error) {
	rc, err := fileOpener(fsys, v, v.GetString("xform"))()
	if err != nil {
		return nil, err
	}
	defer rc.Close()
	return xform.ParseFields(rc)
}

func fileOpener(fsys *filesystem.System, r *core.Record, name string) export.Opener {
	return func() (io.ReadCloser, error) {
		if name == "" {
			return nil, errors.New("the file is missing")
		}
		return fsys.GetReader(r.BaseFilesPath() + "/" + name)
	}
}

func submissionOf(app core.App, fsys *filesystem.System, r *core.Record, versions, names map[string]string) export.Submission {
	submitter := r.GetString("submitted_by")
	name, ok := names[submitter]
	if !ok {
		if u, err := app.FindRecordById(schema.FieldUsers, submitter); err == nil {
			name = u.GetString("name")
		}
		names[submitter] = name
	}

	var manifest []AttachmentInfo
	_ = r.UnmarshalJSONField("attachments_manifest", &manifest)
	media := make([]export.Media, 0, len(manifest))
	for _, a := range manifest {
		media = append(media, export.Media{Name: a.Name, SHA256: a.SHA256, Open: fileOpener(fsys, r, a.StoredName)})
	}

	return export.Submission{
		ID: r.Id,
		Meta: export.Metadata{
			SubmissionDate: r.GetDateTime("received_at").Time().UTC().Format("2006-01-02T15:04:05.000Z"),
			InstanceID:     r.GetString("instance_id"),
			SubmitterID:    submitter,
			SubmitterName:  name,
			ReviewState:    centralReviewState[r.GetString("review_state")],
			DeviceID:       r.GetString("device"),
			FormVersion:    versions[r.GetString("form_version")],
		},
		XML:   fileOpener(fsys, r, r.GetString("xml")),
		Media: media,
	}
}

// exportFieldError is a 400 with a plain-language message for one field.
func exportFieldError(field, code, message string) error {
	return deviceFieldError(field, code, message)
}
