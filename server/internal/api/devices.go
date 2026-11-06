package api

import (
	"bytes"
	"crypto/sha256"
	"database/sql"
	"encoding/hex"
	"errors"
	"io"
	"net/http"
	"slices"
	"strconv"
	"strings"
	"sync"
	"time"

	"ganigeorgiev.com/pocketbase/dbx"
	validation "ganigeorgiev.com/pocketbase/ozzo-validation/v4"
	"ganigeorgiev.com/pocketbase/pocketbase/apis"
	"ganigeorgiev.com/pocketbase/pocketbase/core"
	"ganigeorgiev.com/pocketbase/pocketbase/tools/hook"
	"ganigeorgiev.com/pocketbase/pocketbase/tools/router"
	"ganigeorgiev.com/pocketbase/pocketbase/tools/security"
	"ganigeorgiev.com/pocketbase/pocketbase/tools/types"
	"github.com/golang-jwt/jwt/v5"

	"github.com/obhijatra/obhijatra/server/internal/audit"
	"github.com/obhijatra/obhijatra/server/internal/devicetrust"
	"github.com/obhijatra/obhijatra/server/internal/schema"
)

// Device trust (docs/decisions/0008-device-trust.md): every request by a
// signed-in field or staff user carries a signature from a device approved
// for that person, and every session belongs to one device and can be
// revoked at once.

// deviceRecordKey holds the verified device record of a request.
const deviceRecordKey = "obhijatra.verifiedDevice"

// EnrolDeviceID is the device header value of an enrolment request, which
// is signed with the key it enrols.
const EnrolDeviceID = "enrol"

// Device routes, under Prefix.
const (
	DeviceMePath      = "/devices/me"
	DeviceApprovePath = "/devices/{id}/approve"
	DeviceRevokePath  = "/devices/{id}/revoke"
)

// started is when this server process started; a signature from that
// second or before may have been used already (the replay memory starts
// empty).
var started = time.Now().UTC()

// nonces remembers the device nonces seen recently, in three buckets of
// schema.SignatureWindow each: a nonce is kept for more than twice the
// window (a signature is accepted while the server's clock is within the
// window either side of its time), and dropping the oldest bucket costs
// nothing however many requests arrive.
var nonces struct {
	sync.Mutex
	buckets [3]map[string]struct{}
	start   time.Time // when buckets[0], the newest, began
}

// useNonce records device+nonce and reports false if it was seen already.
func useNonce(device, nonce string, now time.Time) bool {
	nonces.Lock()
	defer nonces.Unlock()
	w := schema.SignatureWindow
	switch {
	case nonces.buckets[0] == nil || now.Sub(nonces.start) >= 3*w:
		for i := range nonces.buckets {
			nonces.buckets[i] = map[string]struct{}{}
		}
		nonces.start = now
	default:
		for now.Sub(nonces.start) >= w {
			nonces.buckets[2], nonces.buckets[1], nonces.buckets[0] = nonces.buckets[1], nonces.buckets[0], map[string]struct{}{}
			nonces.start = nonces.start.Add(w)
		}
	}
	key := device + "\x00" + nonce
	for _, b := range nonces.buckets {
		if _, seen := b[key]; seen {
			return false
		}
	}
	nonces.buckets[0][key] = struct{}{}
	return true
}

func deviceProblem(status int, reason, message string) error {
	return router.NewApiError(status, message, map[string]validation.Error{
		"reason": validation.NewError(reason, message),
	})
}

var (
	errSignatureRequired = deviceProblem(http.StatusForbidden, schema.ReasonDeviceSignatureRequired,
		"This device is not set up for this server yet. Sign in again on this device.")
	errSignatureInvalid = deviceProblem(http.StatusForbidden, schema.ReasonDeviceSignatureInvalid,
		"This request could not be checked. Try again; if it keeps happening, sign in again.")
	errDeviceUnknown = deviceProblem(http.StatusForbidden, schema.ReasonDeviceUnknown,
		"The server does not know this device. Set it up again; it will need approval again.")
	errDeviceClock = deviceProblem(http.StatusForbidden, schema.ReasonDeviceClock,
		"This device's date or time is wrong. Set the date and time, then try again.")
	errDeviceNotApproved = deviceProblem(http.StatusForbidden, schema.ReasonDeviceNotApproved,
		"This device is waiting for approval. Ask your branch manager or organisation admin to approve it.")
	errDeviceRevoked = deviceProblem(http.StatusForbidden, schema.ReasonDeviceRevoked,
		"This device has been switched off for Obhijatra. Ask your organisation admin.")
	errDeviceExpired = deviceProblem(http.StatusForbidden, schema.ReasonDeviceExpired,
		"This device's approval has run out. Ask your branch manager or organisation admin to approve it again.")
	errSessionRevoked = deviceProblem(http.StatusUnauthorized, schema.ReasonSessionRevoked,
		"Your session has ended. Sign in again.")
	errSessionOtherDevice = deviceProblem(http.StatusUnauthorized, schema.ReasonSessionOtherDevice,
		"This session belongs to another device. Sign in again on this device.")
)

func isPersonRecord(r *core.Record) bool {
	name := r.Collection().Name
	return name == schema.FieldUsers || name == schema.StaffUsers
}

// ownerField is the devices or sessions field that points at person r.
func ownerField(r *core.Record) string {
	if r.Collection().Name == schema.FieldUsers {
		return "field_user"
	}
	return "staff_user"
}

func ownsDevice(person, device *core.Record) bool {
	return person != nil && device.GetString(ownerField(person)) == person.Id
}

// hashBody returns the SHA-256 of the request body and leaves the body
// readable again for the handlers. PocketBase's router keeps what is read
// in memory up to 16 MB and in a temporary file beyond, so a large body is
// never held in memory before its signature is checked.
func hashBody(e *core.RequestEvent) ([]byte, error) {
	h := sha256.New()
	if e.Request.Body == nil || e.Request.Body == http.NoBody {
		return h.Sum(nil), nil
	}
	if rr, ok := e.Request.Body.(router.Rereader); ok {
		_, err := io.Copy(h, e.Request.Body)
		rr.Reread()
		return h.Sum(nil), err
	}
	// Outside PocketBase's router (tests): keep a copy in memory.
	body, err := io.ReadAll(e.Request.Body)
	if err != nil {
		return nil, err
	}
	e.Request.Body = &router.RereadableReadCloser{ReadCloser: io.NopCloser(bytes.NewReader(body))}
	h.Write(body)
	return h.Sum(nil), nil
}

// checkSignature verifies the request's signature headers with signKey for
// deviceID: the time within the window and after this process started,
// a fresh nonce, and the signature over the exact request.
func checkSignature(e *core.RequestEvent, deviceID string, signKey []byte) error {
	h := e.Request.Header
	unix, nonce, sig := h.Get(devicetrust.HeaderTime), h.Get(devicetrust.HeaderNonce), h.Get(devicetrust.HeaderSignature)
	if unix == "" || nonce == "" || sig == "" {
		return errSignatureRequired
	}
	secs, err := strconv.ParseInt(unix, 10, 64)
	if err != nil || !devicetrust.ValidNonce(nonce) {
		return errSignatureInvalid
	}
	now := time.Now().UTC()
	at := time.Unix(secs, 0).UTC()
	if at.Before(now.Add(-schema.SignatureWindow)) || at.After(now.Add(schema.SignatureWindow)) {
		return errDeviceClock
	}
	if secs <= started.Unix() {
		return errSignatureInvalid // possibly used before this process started
	}
	bodyHash, err := hashBody(e)
	if err != nil {
		return e.BadRequestError("The request could not be read.", err)
	}
	if !devicetrust.Verify(signKey, devicetrust.MessageWithBodyHash(e.Request.Method, e.Request.RequestURI, unix, nonce, bodyHash), sig) {
		return errSignatureInvalid
	}
	if !useNonce(deviceID, nonce, now) {
		return errSignatureInvalid
	}
	return nil
}

// verifiedDevice finds the device named in the request headers, checks it
// belongs to person and that it signed this request.
func verifiedDevice(e *core.RequestEvent, person *core.Record) (*core.Record, error) {
	id := e.Request.Header.Get(devicetrust.HeaderDevice)
	if id == "" {
		return nil, errSignatureRequired
	}
	device, err := e.App.FindRecordById(schema.Devices, id)
	if err != nil || !ownsDevice(person, device) {
		// Not one of this person's devices: for example, the server was
		// restored from a backup older than the enrolment. The app enrols
		// again (and needs approval again).
		return nil, errDeviceUnknown
	}
	key, err := devicetrust.DecodeKey(device.GetString("sign_public_key"))
	if err != nil {
		return nil, errSignatureInvalid
	}
	if err := checkSignature(e, device.Id, key); err != nil {
		return nil, err
	}
	if device.GetString("status") == schema.DeviceRevoked {
		return nil, errDeviceRevoked
	}
	return device, nil
}

// deviceUsable reports whether an active device has not run out.
func deviceUsable(device *core.Record) bool {
	if device.GetString("status") != schema.DeviceActive {
		return false
	}
	exp := device.GetDateTime("expires")
	return !exp.IsZero() && exp.Time().After(time.Now())
}

// tokenHash is the SHA-256 (hex) of the request's session token.
func tokenHash(e *core.RequestEvent) string {
	// As PocketBase reads it: "Bearer " in any case, or no prefix.
	token := e.Request.Header.Get("Authorization")
	if len(token) > 7 && strings.EqualFold(token[:7], "Bearer ") {
		token = token[7:]
	}
	sum := sha256.Sum256([]byte(token))
	return hex.EncodeToString(sum[:])
}

// checkSession finds the request's session: not revoked, of this person,
// and of this device (a session not yet used by any device is tied to this
// one now).
func checkSession(e *core.RequestEvent, device *core.Record) error {
	session, err := e.App.FindFirstRecordByData(schema.Sessions, "token_hash", tokenHash(e))
	if err != nil || session.GetBool("revoked") || session.GetString(ownerField(e.Auth)) != e.Auth.Id {
		return errSessionRevoked
	}
	switch session.GetString("device") {
	case device.Id:
		return nil
	case "":
		session.Set("device", device.Id)
		return audit.RunAs(e.App, audit.ActorFromRequest(e), func(txApp core.App) error { return txApp.Save(session) })
	}
	return errSessionOtherDevice
}

// mayUseUnapproved reports whether a request may come from a device that
// is waiting for approval (or whose approval ran out): its own status, a
// session refresh, and, only for a person who must replace a one-time
// password, what choosing the new one needs.
func mayUseUnapproved(e *core.RequestEvent) (bool, error) {
	p := cleanPath(e.Request.URL.Path)
	if p == Prefix+DeviceMePath && e.Request.Method == http.MethodGet {
		return true, nil
	}
	c := e.Auth.Collection()
	if e.Request.Method == http.MethodPost &&
		(p == "/api/collections/"+c.Name+"/auth-refresh" || p == "/api/collections/"+c.Id+"/auth-refresh") &&
		!e.Request.URL.Query().Has("expand") {
		return true, nil
	}
	if !e.Auth.GetBool(schema.MustChangePassword) {
		return false, nil
	}
	return mayPassGate(e)
}

// deviceGate checks every request by a signed-in field or staff user:
// signed by a device of theirs that is approved (or, for the few requests
// mayUseUnapproved allows, waiting), within its session. A file download
// with a file token of such a person must be signed by an approved device
// of theirs too.
func deviceGate() *hook.Handler[*core.RequestEvent] {
	return &hook.Handler[*core.RequestEvent]{
		Id:       "obhijatraDeviceGate",
		Priority: apis.DefaultLoadAuthTokenMiddlewarePriority + 105, // after the fence, before the password gate
		Func: func(e *core.RequestEvent) error {
			if e.Auth == nil {
				if err := checkFileToken(e); err != nil {
					return err
				}
				return e.Next() // strangers, sign-in
			}
			if !isPersonRecord(e.Auth) {
				return e.Next() // superusers (docs/decisions/0008-device-trust.md)
			}
			if e.Request.Method == http.MethodPost && cleanPath(e.Request.URL.Path) == schema.DeviceEnrolPath {
				return e.Next() // signed with the key it enrols; checked by enrolDevice
			}
			device, err := verifiedDevice(e, e.Auth)
			if err != nil {
				return err
			}
			if !deviceUsable(device) {
				ok, err := mayUseUnapproved(e)
				if err != nil {
					return err
				}
				if !ok {
					if device.GetString("status") == schema.DeviceActive {
						return errDeviceExpired
					}
					return errDeviceNotApproved
				}
			}
			if err := checkSession(e, device); err != nil {
				return err
			}
			e.Set(audit.DeviceStoreKey, device.Id)
			e.Set(deviceRecordKey, device)
			return e.Next()
		},
	}
}

// checkFileToken refuses a file download with a field or staff user's file
// token unless an approved device of theirs signed it, so a download link
// that leaks (from a log or a browser's history) is of no use to anyone.
func checkFileToken(e *core.RequestEvent) error {
	if !strings.HasPrefix(cleanPath(e.Request.URL.Path), "/api/files/") {
		return nil
	}
	token := e.Request.URL.Query().Get("token")
	if token == "" {
		return nil
	}
	person, err := e.App.FindAuthRecordByToken(token, core.TokenTypeFile)
	if err != nil || !isPersonRecord(person) {
		return nil // PocketBase refuses a bad token; superusers' own tokens
	}
	device, err := verifiedDevice(e, person)
	if err != nil {
		return err
	}
	if !deviceUsable(device) {
		if device.GetString("status") == schema.DeviceActive {
			return errDeviceExpired
		}
		return errDeviceNotApproved
	}
	e.Set(audit.DeviceStoreKey, device.Id)
	return nil
}

// recordSession writes a session for every sign-in and refresh of a field
// or staff user, tied to the signing device when the request carried a
// valid signature from one of theirs.
func recordSession(e *core.RecordAuthRequestEvent) error {
	if !isPersonRecord(e.Record) || e.Token == "" {
		return e.Next()
	}
	sessions, err := e.App.FindCollectionByNameOrId(schema.Sessions)
	if err != nil {
		return err
	}
	// PocketBase's token is the same for two sign-ins in one second; a
	// random id makes every session's token its own.
	token, err := uniqueToken(e.Record)
	if err != nil {
		return err
	}
	e.Token = token

	s := core.NewRecord(sessions)
	s.Set(ownerField(e.Record), e.Record.Id)
	sum := sha256.Sum256([]byte(e.Token))
	s.Set("token_hash", hex.EncodeToString(sum[:]))
	s.Set("issued", types.NowDateTime())

	if d, ok := e.Get(deviceRecordKey).(*core.Record); ok && ownsDevice(e.Record, d) {
		s.Set("device", d.Id)
	} else if e.Request.Header.Get(devicetrust.HeaderDevice) != "" {
		// A sign-in carries no session token, so the gate did not check
		// it; a valid signature from the person's own device ties the new
		// session to that device at once.
		if d, err := verifiedDevice(e.RequestEvent, e.Record); err == nil {
			s.Set("device", d.Id)
		}
	}
	if err := audit.RunAs(e.App, audit.ActorFromRequest(e.RequestEvent), func(txApp core.App) error { return txApp.Save(s) }); err != nil {
		return err
	}
	return e.Next()
}

// uniqueToken is PocketBase's auth token for r with a random "jti" claim
// added, so no two sessions share a token.
func uniqueToken(r *core.Record) (string, error) {
	key := r.TokenKey() + r.Collection().AuthToken.Secret
	if key == "" {
		return "", core.ErrMissingSigningKey
	}
	return security.NewJWT(jwt.MapClaims{
		core.TokenClaimType:         core.TokenTypeAuth,
		core.TokenClaimId:           r.Id,
		core.TokenClaimCollectionId: r.Collection().Id,
		core.TokenClaimRefreshable:  true,
		"jti":                       security.RandomString(20),
	}, key, r.Collection().AuthToken.DurationTime())
}

// DeviceView is how the device routes describe a device. The check code
// is never sent: the device and the approver work it out from the keys.
type DeviceView struct {
	ID                  string `json:"id"`
	Status              string `json:"status"`
	Label               string `json:"label"`
	Platform            string `json:"platform"`
	Expires             string `json:"expires"`
	ApprovedAt          string `json:"approved_at"`
	NeedsSecondApproval bool   `json:"needs_second_approval"`
	ApprovalExpired     bool   `json:"approval_expired"`
}

func viewOf(d *core.Record) DeviceView {
	return DeviceView{
		ID:                  d.Id,
		Status:              d.GetString("status"),
		Label:               d.GetString("label"),
		Platform:            d.GetString("platform"),
		Expires:             d.GetDateTime("expires").String(),
		ApprovedAt:          d.GetDateTime("approved_at").String(),
		NeedsSecondApproval: d.GetString("status") == schema.DevicePending && d.GetString("first_approved_by") != "",
		ApprovalExpired:     d.GetString("status") == schema.DeviceActive && !deviceUsable(d),
	}
}

func deviceFieldError(field, code, message string) error {
	return router.NewBadRequestError(message, map[string]validation.Error{field: validation.NewError(code, message)})
}

// enrolDevice answers POST /api/obhijatra/v1/devices/enrol: a signed-in
// person registers this device's public keys, proving it holds the signing
// key by signing the request with it (device header "enrol"). The device
// waits for approval, and the session becomes this device's: a session
// already used by another device, or ended, cannot enrol one. Enrolling
// the same key again returns the same device.
func enrolDevice(e *core.RequestEvent) error {
	if e.Auth == nil || !isPersonRecord(e.Auth) {
		return e.ForbiddenError("Only field and office staff enrol devices.", nil)
	}
	var body struct {
		Label    string `json:"label"`
		Platform string `json:"platform"`
		SignKey  string `json:"sign_public_key"`
		EncKey   string `json:"enc_public_key"`
	}
	if _, err := hashBody(e); err != nil { // leaves the body readable for the signature check
		return e.BadRequestError("The request could not be read.", err)
	}
	if err := e.BindBody(&body); err != nil {
		return e.BadRequestError("The request could not be read.", err)
	}

	signKey, err := devicetrust.DecodeKey(body.SignKey)
	if err == nil {
		err = devicetrust.CheckSignKey(signKey)
	}
	if err != nil {
		return deviceFieldError("sign_public_key", "validation_invalid_key", err.Error())
	}
	encKey, err := devicetrust.DecodeKey(body.EncKey)
	if err == nil {
		err = devicetrust.CheckEncKey(encKey)
	}
	if err != nil {
		return deviceFieldError("enc_public_key", "validation_invalid_key", err.Error())
	}
	label := strings.TrimSpace(body.Label)
	if label == "" || len([]rune(label)) > 100 || strings.ContainsFunc(label, schema.UnsafeTextRune) {
		return deviceFieldError("label", "validation_invalid_label", "Name the device in up to 100 characters.")
	}
	if !slices.Contains(schema.DevicePlatforms, body.Platform) {
		return deviceFieldError("platform", "validation_invalid_platform", "Unknown platform.")
	}
	if e.Request.Header.Get(devicetrust.HeaderDevice) != EnrolDeviceID {
		return errSignatureRequired
	}
	// Check the session before the signature, so an ended session cannot
	// fill the nonce memory; checked again, and bound, below.
	if err := enrolSessionUsable(e.App, e, body.SignKey); err != nil {
		return err
	}
	if err := checkSignature(e, "enrol:"+body.SignKey, signKey); err != nil {
		return err
	}

	var device *core.Record
	err = audit.RunAs(e.App, audit.ActorFromRequest(e), func(txApp core.App) error {
		// The session must be live and not already another device's; it
		// becomes this device's at once.
		session, err := txApp.FindFirstRecordByData(schema.Sessions, "token_hash", tokenHash(e))
		if err != nil || session.GetBool("revoked") || session.GetString(ownerField(e.Auth)) != e.Auth.Id {
			return errSessionRevoked
		}
		bind := func(d *core.Record) error {
			switch session.GetString("device") {
			case d.Id:
				return nil
			case "":
				session.Set("device", d.Id)
				return txApp.Save(session)
			}
			return errSessionOtherDevice
		}

		existing, err := txApp.FindFirstRecordByData(schema.Devices, "sign_public_key", body.SignKey)
		switch {
		case err == nil:
			if !ownsDevice(e.Auth, existing) || existing.GetString("status") == schema.DeviceRevoked ||
				existing.GetString("enc_public_key") != body.EncKey {
				return router.NewApiError(http.StatusConflict,
					"This device's key is already in use. Clear the app's data on this device and sign in again.", nil)
			}
			device = existing
			return bind(device)
		case !errors.Is(err, sql.ErrNoRows):
			return err
		}
		if d := session.GetString("device"); d != "" {
			return errSessionOtherDevice
		}

		waiting, err := txApp.CountRecords(schema.Devices,
			dbx.HashExp{ownerField(e.Auth): e.Auth.Id, "status": schema.DevicePending})
		if err != nil {
			return err
		}
		if waiting >= schema.MaxPendingDevices {
			return router.NewApiError(http.StatusTooManyRequests,
				"Too many of your devices are waiting for approval. Ask your approver to approve them or switch them off.", nil)
		}
		devices, err := txApp.FindCollectionByNameOrId(schema.Devices)
		if err != nil {
			return err
		}
		device = core.NewRecord(devices)
		device.Set(ownerField(e.Auth), e.Auth.Id)
		device.Set("label", label)
		device.Set("platform", body.Platform)
		device.Set("sign_public_key", body.SignKey)
		device.Set("enc_public_key", body.EncKey)
		device.Set("status", schema.DevicePending)
		device.Set("attestation_level", schema.AttestationNone)
		if err := txApp.Save(device); err != nil {
			return err
		}
		return bind(device)
	})
	if err != nil {
		return err
	}
	return e.JSON(http.StatusOK, viewOf(device))
}

// enrolSessionUsable reports errSessionRevoked for an ended session or one
// of someone else, and errSessionOtherDevice for a session already used
// by a device other than the one with signKey.
func enrolSessionUsable(app core.App, e *core.RequestEvent, signKey string) error {
	session, err := app.FindFirstRecordByData(schema.Sessions, "token_hash", tokenHash(e))
	if err != nil || session.GetBool("revoked") || session.GetString(ownerField(e.Auth)) != e.Auth.Id {
		return errSessionRevoked
	}
	if id := session.GetString("device"); id != "" {
		d, err := app.FindRecordById(schema.Devices, id)
		if err != nil || d.GetString("sign_public_key") != signKey {
			return errSessionOtherDevice
		}
	}
	return nil
}

// deviceMe answers GET /devices/me with the requesting device's status.
func deviceMe(e *core.RequestEvent) error {
	device, ok := e.Get(deviceRecordKey).(*core.Record)
	if !ok {
		return errSignatureRequired
	}
	return e.JSON(http.StatusOK, viewOf(device))
}

// ownerOf loads the person a device belongs to.
func ownerOf(app core.App, device *core.Record) (*core.Record, error) {
	if id := device.GetString("field_user"); id != "" {
		return app.FindRecordById(schema.FieldUsers, id)
	}
	return app.FindRecordById(schema.StaffUsers, device.GetString("staff_user"))
}

// mayManageDevice reports whether actor may approve or revoke a device of
// owner: an org admin for anyone; a branch manager for field staff in
// their part of the tree.
func mayManageDevice(actor, owner *core.Record) bool {
	if actor == nil || actor.Collection().Name != schema.StaffUsers || !actor.GetBool("active") {
		return false
	}
	switch actor.GetString("role") {
	case schema.RoleOrgAdmin:
		return true
	case schema.RoleBranchManager:
		mine := actor.GetString("location_path")
		return owner.Collection().Name == schema.FieldUsers && mine != "" &&
			strings.HasPrefix(owner.GetString("location_path"), mine)
	}
	return false
}

// approveDevice answers POST /devices/{id}/approve {"code"}: the approver
// has compared the 18-digit code the device shows with the one their app
// works out, and the server checks it again. An org admin's device needs
// two different org admins; nobody approves their own device.
func approveDevice(e *core.RequestEvent) error {
	var body struct {
		Code string `json:"code"`
	}
	if err := e.BindBody(&body); err != nil {
		return e.BadRequestError("The request could not be read.", err)
	}
	var view DeviceView
	err := audit.RunAs(e.App, audit.ActorFromRequest(e), func(txApp core.App) error {
		device, err := txApp.FindRecordById(schema.Devices, e.Request.PathValue("id"))
		if err != nil {
			return e.NotFoundError("", err)
		}
		owner, err := ownerOf(txApp, device)
		if err != nil {
			return err
		}
		if owner.Id == e.Auth.Id {
			return e.ForbiddenError("Nobody approves their own device. Ask another approver.", nil)
		}
		if !mayManageDevice(e.Auth, owner) || (owner.Collection().Name == schema.StaffUsers && e.Auth.GetString("role") != schema.RoleOrgAdmin) {
			return e.ForbiddenError("You cannot approve this person's devices.", nil)
		}
		waiting := device.GetString("status") == schema.DevicePending
		if !waiting && !(device.GetString("status") == schema.DeviceActive && !deviceUsable(device)) {
			return router.NewApiError(http.StatusConflict, "This device is not waiting for approval.", nil)
		}
		signKey, err1 := devicetrust.DecodeKey(device.GetString("sign_public_key"))
		encKey, err2 := devicetrust.DecodeKey(device.GetString("enc_public_key"))
		if err1 != nil || err2 != nil {
			return errors.New("the device's stored keys cannot be read")
		}
		if devicetrust.NormaliseCode(body.Code) != devicetrust.Code(signKey, encKey) {
			return deviceFieldError("code", "validation_device_code_mismatch",
				"The numbers do not match. Check them with the person again.")
		}

		ownerIsAdmin := owner.Collection().Name == schema.StaffUsers && owner.GetString("role") == schema.RoleOrgAdmin
		if ownerIsAdmin {
			switch first := device.GetString("first_approved_by"); {
			case first == "":
				device.Set("first_approved_by", e.Auth.Id)
				device.Set("status", schema.DevicePending)
				if err := txApp.Save(device); err != nil {
					return err
				}
				view = viewOf(device)
				return nil
			case first == e.Auth.Id:
				return router.NewApiError(http.StatusConflict,
					"An organisation admin's device needs a second approval from a different organisation admin.", nil)
			case !isActiveOrgAdmin(txApp, first):
				// The first approver is no longer an org admin: this
				// approval counts as the first one.
				device.Set("first_approved_by", e.Auth.Id)
				if err := txApp.Save(device); err != nil {
					return err
				}
				view = viewOf(device)
				return nil
			}
		}
		activate(device, e.Auth.Id)
		if err := txApp.Save(device); err != nil {
			return err
		}
		view = viewOf(device)
		return nil
	})
	if err != nil {
		return err
	}
	return e.JSON(http.StatusOK, view)
}

func isActiveOrgAdmin(app core.App, staffID string) bool {
	r, err := app.FindRecordById(schema.StaffUsers, staffID)
	return err == nil && r.GetBool("active") && r.GetString("role") == schema.RoleOrgAdmin
}

// activate marks device approved by approverID ("" for the server's
// command line) for schema.DeviceLifetime.
func activate(device *core.Record, approverID string) {
	now := time.Now().UTC()
	device.Set("status", schema.DeviceActive)
	device.Set("enrolled_by", approverID)
	device.Set("approved_at", types.NowDateTime())
	exp, _ := types.ParseDateTime(now.Add(schema.DeviceLifetime))
	device.Set("expires", exp)
	device.Set("first_approved_by", "")
}

// ActivateFromCommandLine approves a device from the server's command line
// after checking the code: whoever can run the server program is trusted
// with everything already, so this counts as a full approval, also for an
// org admin's device (this is how the first admin's first device is
// approved).
func ActivateFromCommandLine(app core.App, actor audit.Actor, deviceID, code string) (*core.Record, error) {
	var device *core.Record
	err := audit.RunAs(app, actor, func(txApp core.App) error {
		d, err := txApp.FindRecordById(schema.Devices, deviceID)
		if err != nil {
			return errors.New("no device has this id")
		}
		if d.GetString("status") == schema.DeviceRevoked {
			return errors.New("this device has been switched off; it cannot be approved")
		}
		signKey, err1 := devicetrust.DecodeKey(d.GetString("sign_public_key"))
		encKey, err2 := devicetrust.DecodeKey(d.GetString("enc_public_key"))
		if err1 != nil || err2 != nil {
			return errors.New("the device's stored keys cannot be read")
		}
		if devicetrust.NormaliseCode(code) != devicetrust.Code(signKey, encKey) {
			return errors.New("the numbers do not match the device; check them with the person again")
		}
		activate(d, "")
		device = d
		return txApp.Save(d)
	})
	return device, err
}

// revokeDevice answers POST /devices/{id}/revoke: the owner (for a lost
// device), an org admin, or a branch manager for field staff in their part
// of the tree switches a device off. Its sessions end at once.
func revokeDevice(e *core.RequestEvent) error {
	var view DeviceView
	err := audit.RunAs(e.App, audit.ActorFromRequest(e), func(txApp core.App) error {
		device, err := txApp.FindRecordById(schema.Devices, e.Request.PathValue("id"))
		if err != nil {
			return e.NotFoundError("", err)
		}
		owner, err := ownerOf(txApp, device)
		if err != nil {
			return err
		}
		if owner.Id != e.Auth.Id && !mayManageDevice(e.Auth, owner) {
			return e.ForbiddenError("You cannot switch off this person's devices.", nil)
		}
		if err := RevokeDevice(txApp, device); err != nil {
			return err
		}
		view = viewOf(device)
		return nil
	})
	if err != nil {
		return err
	}
	return e.JSON(http.StatusOK, view)
}

// RevokeDevice switches a device off and ends its sessions, in txApp.
func RevokeDevice(txApp core.App, device *core.Record) error {
	if device.GetString("status") != schema.DeviceRevoked {
		device.Set("status", schema.DeviceRevoked)
		if err := txApp.Save(device); err != nil {
			return err
		}
	}
	sessions, err := txApp.FindRecordsByFilter(schema.Sessions, "device = {:d} && revoked = false", "", 0, 0,
		dbx.Params{"d": device.Id})
	if err != nil {
		return err
	}
	for _, s := range sessions {
		s.Set("revoked", true)
		if err := txApp.Save(s); err != nil {
			return err
		}
	}
	return nil
}

// registerDevices binds the device gate, the session hook and the device
// routes.
func registerDevices(app core.App, se *core.ServeEvent) {
	// A signature from the second this process started may have been used
	// by the process before it (the nonce memory starts empty), so such
	// signatures are refused; serving starts once that second has passed.
	if d := time.Until(time.Unix(started.Unix()+1, 0)); d > 0 {
		time.Sleep(d)
	}
	se.Router.Bind(deviceGate())
	persons := apis.RequireAuth(schema.FieldUsers, schema.StaffUsers)
	se.Router.POST(schema.DeviceEnrolPath, enrolDevice).Bind(persons, apis.BodyLimit(16<<10))
	se.Router.GET(Prefix+DeviceMePath, deviceMe).Bind(persons)
	se.Router.POST(Prefix+DeviceApprovePath, approveDevice).Bind(apis.RequireAuth(schema.StaffUsers), apis.BodyLimit(4<<10))
	se.Router.POST(Prefix+DeviceRevokePath, revokeDevice).Bind(persons, apis.BodyLimit(4<<10))
}

// bindSessions writes a session row for every sign-in and refresh, and
// keeps live updates (realtime) within device trust.
func bindSessions(app core.App) {
	app.OnRecordAuthRequest(schema.FieldUsers, schema.StaffUsers).Bind(&hook.Handler[*core.RecordAuthRequestEvent]{
		Id:   "obhijatraRecordSession",
		Func: recordSession,
	})
	app.OnRealtimeSubscribeRequest().Bind(&hook.Handler[*core.RealtimeSubscribeRequestEvent]{
		Id:   "obhijatraRealtimeDevice",
		Func: rememberRealtimeDevice,
	})
	app.OnRealtimeMessageSend().Bind(&hook.Handler[*core.RealtimeMessageEvent]{
		Id:   "obhijatraRealtimeTrust",
		Func: checkRealtimeTrust,
	})
}

// Where a realtime client keeps the device and session it subscribed with.
const (
	realtimeDeviceKey  = "obhijatra.device"
	realtimeSessionKey = "obhijatra.session"
)

// rememberRealtimeDevice keeps, on the realtime connection, the device and
// session that subscribed (the device gate has checked both).
func rememberRealtimeDevice(e *core.RealtimeSubscribeRequestEvent) error {
	e.Client.Unset(realtimeDeviceKey)
	e.Client.Unset(realtimeSessionKey)
	if e.Auth != nil && isPersonRecord(e.Auth) {
		device, ok := e.Get(deviceRecordKey).(*core.Record)
		if !ok {
			return errSignatureRequired
		}
		e.Client.Set(realtimeDeviceKey, device.Id)
		e.Client.Set(realtimeSessionKey, tokenHash(e.RequestEvent))
	}
	return e.Next()
}

// checkRealtimeTrust stops live updates to a person's connection as soon
// as its device is switched off or runs out, or its session ends: the
// message is dropped and the connection carries on signed out, as
// PocketBase does when a password changes.
func checkRealtimeTrust(e *core.RealtimeMessageEvent) error {
	auth, _ := e.Client.Get(apis.RealtimeClientAuthKey).(*core.Record)
	if auth == nil || !isPersonRecord(auth) {
		return e.Next()
	}
	deviceID, _ := e.Client.Get(realtimeDeviceKey).(string)
	session, _ := e.Client.Get(realtimeSessionKey).(string)
	if !stillTrusted(e.App, auth, deviceID, session) {
		e.Client.Unset(apis.RealtimeClientAuthKey)
		e.Client.Unset(realtimeDeviceKey)
		e.Client.Unset(realtimeSessionKey)
		return nil
	}
	return e.Next()
}

func stillTrusted(app core.App, person *core.Record, deviceID, sessionHash string) bool {
	if deviceID == "" || sessionHash == "" {
		return false
	}
	device, err := app.FindRecordById(schema.Devices, deviceID)
	if err != nil || !ownsDevice(person, device) || !deviceUsable(device) {
		return false
	}
	s, err := app.FindFirstRecordByData(schema.Sessions, "token_hash", sessionHash)
	return err == nil && !s.GetBool("revoked") && s.GetString("device") == deviceID
}
