package api

import (
	"bytes"
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"fmt"
	"io"
	"mime/multipart"
	"net/http"
	"slices"

	"ganigeorgiev.com/pocketbase/dbx"
	"ganigeorgiev.com/pocketbase/pocketbase/apis"
	"ganigeorgiev.com/pocketbase/pocketbase/core"
	"ganigeorgiev.com/pocketbase/pocketbase/tools/filesystem"
	"ganigeorgiev.com/pocketbase/pocketbase/tools/router"

	"github.com/obhijatra/obhijatra/server/internal/audit"
	"github.com/obhijatra/obhijatra/server/internal/schema"
	"github.com/obhijatra/obhijatra/server/internal/xform"
)

// XMLPartName is the multipart part that carries the instance XML. It is the
// name OpenRosa clients (ODK Collect, Enketo) use.
const XMLPartName = "xml_submission_file"

// Submission statuses returned with HTTP 200.
const (
	StatusReceived        = "received"
	StatusAlreadyReceived = "already_received"
)

// SubmissionResponse is the body of a successful POST /submissions.
type SubmissionResponse struct {
	ID         string `json:"id"`
	InstanceID string `json:"instance_id"`
	Status     string `json:"status"`
	Message    string `json:"message"`
}

// AttachmentInfo is one entry of a submission's attachments_manifest.
type AttachmentInfo struct {
	Name       string `json:"name"`        // file name as sent, which the XML refers to
	StoredName string `json:"stored_name"` // name in the attachments field
	SHA256     string `json:"sha256"`
	Size       int64  `json:"size"`
}

// submit stores one finalised submission. It is idempotent on the
// instanceID inside the XML, so a phone can retry an upload safely:
//
//   - new instanceID: stored, 200 "received";
//   - same instanceID, same XML (SHA-256), same user: 200 "already_received";
//   - same instanceID, different XML or different user: 409.
func submit(e *core.RequestEvent) error {
	user := e.Auth
	if user == nil || user.Collection().Name != schema.FieldUsers {
		return e.ForbiddenError("Only field users can send submissions.", nil)
	}
	if !user.GetBool("active") {
		return e.ForbiddenError("This account is not active. Please contact your organisation admin.", nil)
	}

	if err := e.Request.ParseMultipartForm(router.DefaultMaxMemory); err != nil {
		if errors.Is(err, apis.ErrRequestEntityTooLarge) {
			return apis.ErrRequestEntityTooLarge
		}
		return e.BadRequestError("Send the submission as multipart/form-data with an \""+XMLPartName+"\" part.", nil)
	}
	form := e.Request.MultipartForm

	xmlParts := form.File[XMLPartName]
	if len(xmlParts) != 1 {
		return e.BadRequestError("Send exactly one \""+XMLPartName+"\" part with the submission XML.", nil)
	}

	xmlBytes, err := readPart(xmlParts[0], schema.MaxXMLSize)
	if err != nil {
		return e.BadRequestError("The submission XML could not be read: "+err.Error(), nil)
	}

	inst, err := xform.ParseInstance(bytes.NewReader(xmlBytes))
	if err != nil {
		return e.BadRequestError("The submission XML is not valid: "+err.Error(), nil)
	}

	sum := sha256.Sum256(xmlBytes)
	digest := hex.EncodeToString(sum[:])

	// Fast path for retries: the instance is already stored.
	if existing, err := findByInstanceID(e.App, inst.InstanceID); err == nil {
		return duplicateResponse(e, existing, user, digest)
	}

	formRec, err := e.App.FindFirstRecordByData(schema.Forms, "form_id", inst.FormID)
	if err != nil {
		return unprocessable(e, fmt.Sprintf("The form %q is not on this server.", inst.FormID))
	}
	formVersion, err := e.App.FindFirstRecordByFilter(
		schema.FormVersions,
		"form = {:form} && version = {:version}",
		dbx.Params{"form": formRec.Id, "version": inst.Version},
	)
	if err != nil {
		return unprocessable(e, fmt.Sprintf("Version %q of form %q is not on this server.", inst.Version, inst.FormID))
	}
	if !formVersion.GetBool("published") {
		return unprocessable(e, fmt.Sprintf("Version %q of form %q is not published.", inst.Version, inst.FormID))
	}

	attachments, manifest, err := collectAttachments(form)
	if err != nil {
		return e.BadRequestError(err.Error(), nil)
	}

	xmlFile, err := filesystem.NewFileFromBytes(xmlBytes, "submission.xml")
	if err != nil {
		return e.InternalServerError("", err)
	}

	collection, err := e.App.FindCachedCollectionByNameOrId(schema.Submissions)
	if err != nil {
		return e.InternalServerError("", err)
	}

	rec := core.NewRecord(collection)
	rec.Set("instance_id", inst.InstanceID)
	rec.Set("form", formRec.Id)
	rec.Set("form_version", formVersion.Id)
	rec.Set("xml", xmlFile)
	rec.Set("xml_sha256", digest)
	rec.Set("attachments", attachments)
	rec.Set("attachments_manifest", manifest)
	rec.Set("submitted_by", user.Id)
	if device, ok := e.Get(audit.DeviceStoreKey).(string); ok && device != "" {
		rec.Set("device", device)
	}
	rec.Set("location_path", user.GetString("location_path"))
	rec.Set("review_state", schema.ReviewReceived)

	saveErr := audit.RunAs(e.App, audit.ActorFromRequest(e), func(txApp core.App) error {
		return txApp.Save(rec)
	})
	if saveErr != nil {
		// Two uploads of the same instance can race; the unique index on
		// instance_id lets only one in. Answer the loser as a retry.
		if existing, err := findByInstanceID(e.App, inst.InstanceID); err == nil {
			return duplicateResponse(e, existing, user, digest)
		}
		return e.BadRequestError("The submission could not be stored.", saveErr)
	}

	return e.JSON(http.StatusOK, SubmissionResponse{
		ID:         rec.Id,
		InstanceID: inst.InstanceID,
		Status:     StatusReceived,
		Message:    "Submission received.",
	})
}

func findByInstanceID(app core.App, instanceID string) (*core.Record, error) {
	return app.FindFirstRecordByData(schema.Submissions, "instance_id", instanceID)
}

func duplicateResponse(e *core.RequestEvent, existing, user *core.Record, digest string) error {
	if existing.GetString("submitted_by") != user.Id || existing.GetString("xml_sha256") != digest {
		// Deliberately the same answer whether the other copy belongs to
		// this user or not, so the response reveals nothing about others.
		return e.Error(http.StatusConflict,
			"A different submission with this instance ID is already on the server. It was not replaced.", nil)
	}

	return e.JSON(http.StatusOK, SubmissionResponse{
		ID:         existing.Id,
		InstanceID: existing.GetString("instance_id"),
		Status:     StatusAlreadyReceived,
		Message:    "This submission was already received. Nothing was changed.",
	})
}

func unprocessable(e *core.RequestEvent, msg string) error {
	return e.Error(http.StatusUnprocessableEntity, msg, nil)
}

// readPart reads a whole multipart file part, refusing more than limit bytes.
func readPart(fh *multipart.FileHeader, limit int64) ([]byte, error) {
	if fh.Size > limit {
		return nil, fmt.Errorf("it is larger than %d MB", limit>>20)
	}
	f, err := fh.Open()
	if err != nil {
		return nil, err
	}
	defer f.Close()

	b, err := io.ReadAll(io.LimitReader(f, limit+1))
	if err != nil {
		return nil, err
	}
	if int64(len(b)) > limit {
		return nil, fmt.Errorf("it is larger than %d MB", limit>>20)
	}
	return b, nil
}

// collectAttachments turns every file part except the XML into an
// attachment, in a stable order, and records each one's original name,
// stored name, SHA-256 and size.
func collectAttachments(form *multipart.Form) ([]*filesystem.File, []AttachmentInfo, error) {
	keys := make([]string, 0, len(form.File))
	for k := range form.File {
		if k != XMLPartName {
			keys = append(keys, k)
		}
	}
	slices.Sort(keys)

	var (
		files    []*filesystem.File
		manifest = []AttachmentInfo{}
	)
	for _, k := range keys {
		for _, fh := range form.File[k] {
			if len(files) == schema.MaxAttachments {
				return nil, nil, fmt.Errorf("a submission can carry at most %d attachments", schema.MaxAttachments)
			}
			if fh.Size > schema.MaxAttachmentSize {
				return nil, nil, fmt.Errorf("the attachment %q is larger than %d MB", fh.Filename, schema.MaxAttachmentSize>>20)
			}

			sha, err := hashPart(fh)
			if err != nil {
				return nil, nil, fmt.Errorf("the attachment %q could not be read", fh.Filename)
			}
			f, err := filesystem.NewFileFromMultipart(fh)
			if err != nil {
				return nil, nil, fmt.Errorf("the attachment %q could not be read", fh.Filename)
			}

			files = append(files, f)
			manifest = append(manifest, AttachmentInfo{
				Name:       fh.Filename,
				StoredName: f.Name,
				SHA256:     sha,
				Size:       fh.Size,
			})
		}
	}

	return files, manifest, nil
}

func hashPart(fh *multipart.FileHeader) (string, error) {
	f, err := fh.Open()
	if err != nil {
		return "", err
	}
	defer f.Close()

	h := sha256.New()
	if _, err := io.Copy(h, f); err != nil {
		return "", err
	}
	return hex.EncodeToString(h.Sum(nil)), nil
}
