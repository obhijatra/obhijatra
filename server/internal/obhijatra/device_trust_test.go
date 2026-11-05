package obhijatra_test

import (
	"bytes"
	"crypto/ed25519"
	"encoding/base64"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strconv"
	"strings"
	"testing"
	"time"

	"ganigeorgiev.com/pocketbase/dbx"
	"ganigeorgiev.com/pocketbase/pocketbase/core"
	"ganigeorgiev.com/pocketbase/pocketbase/tools/types"

	"github.com/obhijatra/obhijatra/server/internal/api"
	"github.com/obhijatra/obhijatra/server/internal/audit"
	"github.com/obhijatra/obhijatra/server/internal/cli"
	"github.com/obhijatra/obhijatra/server/internal/devicetrust"
	"github.com/obhijatra/obhijatra/server/internal/schema"
	"github.com/obhijatra/obhijatra/server/internal/testutil"
)

const (
	enrolURL = schema.DeviceEnrolPath
	meURL    = api.Prefix + api.DeviceMePath
	formsURL = "/api/collections/forms/records"
)

func approveURL(id string) string { return api.Prefix + "/devices/" + id + "/approve" }
func revokeURL(id string) string  { return api.Prefix + "/devices/" + id + "/revoke" }

// strictApp is a test server where nothing signs requests for the test.
func strictApp(t *testing.T) (*testutil.Org, http.Handler, core.App, func()) {
	app := testutil.NewApp(t)
	app.Store().Set(testutil.NoAutoSignKey, true)
	o := testutil.SeedOrg(t, app)
	return o, serveMux(t, app), app, app.Cleanup
}

// signed sends one request signed as deviceID with key.
func signed(mux http.Handler, method, url, token, deviceID string, key ed25519.PrivateKey, body any, tweak ...func(*http.Request)) (int, string) {
	var raw []byte
	if body != nil {
		raw, _ = json.Marshal(body)
	}
	r := httptest.NewRequest(method, url, bytes.NewReader(raw))
	if body != nil {
		r.Header.Set("Content-Type", "application/json")
	}
	if token != "" {
		r.Header.Set("Authorization", token)
	}
	r.RemoteAddr = defaultIP + ":40000"
	testutil.Sign(r, deviceID, key, raw)
	for _, f := range tweak {
		f(r)
	}
	w := httptest.NewRecorder()
	mux.ServeHTTP(w, r)
	return w.Code, w.Body.String()
}

// approver is a person with an approved device and a session, ready to sign.
type approver struct {
	token string
	dev   *testutil.TestDevice
}

func asApprover(t *testing.T, app core.App, person *core.Record) approver {
	token := testutil.Token(t, person)
	testutil.Prime(t, app, person, token)
	return approver{token, testutil.Device(t, app, person)}
}

func (a approver) call(mux http.Handler, method, url string, body any) (int, string) {
	return signed(mux, method, url, a.token, a.dev.ID, a.dev.Key, body)
}

// newPhone is a device that is not enrolled yet.
type newPhone struct {
	key ed25519.PrivateKey
	enc []byte
}

func freshPhone() newPhone {
	k, e := testutil.NewKeys()
	return newPhone{k, e}
}

func (p newPhone) keys() map[string]any {
	return map[string]any{
		"label": "Sample phone", "platform": "android",
		"sign_public_key": base64.StdEncoding.EncodeToString(p.key.Public().(ed25519.PublicKey)),
		"enc_public_key":  base64.StdEncoding.EncodeToString(p.enc),
	}
}

func (p newPhone) code() string {
	return devicetrust.Code(p.key.Public().(ed25519.PublicKey), p.enc)
}

// enrol signs person in with a password and enrols the phone; it returns
// the session token and the device id.
func (p newPhone) enrol(t *testing.T, mux http.Handler, collection, email string) (string, string) {
	t.Helper()
	status, body := signIn(mux, collection, email, testutil.Password)
	if status != http.StatusOK {
		t.Fatalf("sign in: %d %s", status, body)
	}
	token := tokenOf(t, body)
	status, body = signed(mux, http.MethodPost, enrolURL, token, api.EnrolDeviceID, p.key, p.keys())
	if status != http.StatusOK || !strings.Contains(body, `"status":"pending"`) {
		t.Fatalf("enrol: %d %s", status, body)
	}
	return token, idOf(t, body)
}

func reasonIs(body, reason string) bool { return strings.Contains(body, `"code":"`+reason+`"`) }

func TestUnsignedRequestsAreRefused(t *testing.T) {
	o, mux, _, done := strictApp(t)
	defer done()

	status, body := call(mux, http.MethodGet, formsURL, testutil.Token(t, o.Field1), nil)
	if status != http.StatusForbidden || !reasonIs(body, schema.ReasonDeviceSignatureRequired) {
		t.Errorf("unsigned: %d %s", status, body)
	}
	// Public routes need no device.
	if status, _ := call(mux, http.MethodGet, "/api/obhijatra/v1/meta", "", nil); status != http.StatusOK {
		t.Error("the public meta route needs a device")
	}
}

func TestANewPhoneWaitsForItsBranchManager(t *testing.T) {
	o, mux, app, done := strictApp(t)
	defer done()
	bm := testutil.User(t, app, schema.StaffUsers, "bm1@example.org", schema.RoleBranchManager, o.Branch1, true)
	bm2 := testutil.User(t, app, schema.StaffUsers, "bm2@example.org", schema.RoleBranchManager, o.Branch2, true)

	phone := freshPhone()
	token, id := phone.enrol(t, mux, schema.FieldUsers, "field1@example.org")

	// Enrolling again is the same device; unsigned or wrongly signed
	// enrolment is refused.
	if status, body := signed(mux, http.MethodPost, enrolURL, token, api.EnrolDeviceID, phone.key, phone.keys()); status != http.StatusOK || idOf(t, body) != id {
		t.Errorf("enrol again: %d %s", status, body)
	}
	other := freshPhone()
	if status, body := signed(mux, http.MethodPost, enrolURL, token, api.EnrolDeviceID, other.key, phone.keys()); status != http.StatusForbidden {
		t.Errorf("enrolling keys it does not hold: %d %s", status, body)
	}

	// While waiting: its own status, nothing else.
	if status, body := signed(mux, http.MethodGet, meURL, token, id, phone.key, nil); status != http.StatusOK || !strings.Contains(body, `"status":"pending"`) {
		t.Errorf("status while waiting: %d %s", status, body)
	}
	if status, body := signed(mux, http.MethodGet, formsURL, token, id, phone.key, nil); status != http.StatusForbidden || !reasonIs(body, schema.ReasonDeviceNotApproved) {
		t.Errorf("forms while waiting: %d %s", status, body)
	}

	// The branch manager sees it and approves it with the right numbers;
	// others cannot.
	b := asApprover(t, app, bm)
	if status, body := b.call(mux, http.MethodGet, "/api/collections/devices/records?filter=status%3D%27pending%27", nil); status != http.StatusOK || !strings.Contains(body, id) {
		t.Errorf("the branch manager's list: %d %s", status, body)
	}
	if status, body := asApprover(t, app, bm2).call(mux, http.MethodPost, approveURL(id), map[string]any{"code": phone.code()}); status != http.StatusForbidden {
		t.Errorf("another branch's manager approved: %d %s", status, body)
	}
	if status, body := asApprover(t, app, o.Sup1).call(mux, http.MethodPost, approveURL(id), map[string]any{"code": phone.code()}); status != http.StatusForbidden {
		t.Errorf("a supervisor approved: %d %s", status, body)
	}
	if status, body := b.call(mux, http.MethodPost, approveURL(id), map[string]any{"code": "000000000000000000"}); status != http.StatusBadRequest ||
		!strings.Contains(body, "validation_device_code_mismatch") {
		t.Errorf("wrong numbers: %d %s", status, body)
	}
	// Grouped, in Bangla digits, as people type them.
	bangla := strings.Map(func(r rune) rune { return '০' + (r - '0') }, devicetrust.GroupCode(phone.code()))
	if status, body := b.call(mux, http.MethodPost, approveURL(id), map[string]any{"code": bangla}); status != http.StatusOK ||
		!strings.Contains(body, `"status":"active"`) {
		t.Fatalf("approve: %d %s", status, body)
	}

	// Now the phone works, and the approval is in the audit chain.
	if status, body := signed(mux, http.MethodGet, formsURL, token, id, phone.key, nil); status != http.StatusOK {
		t.Errorf("forms after approval: %d %s", status, body)
	}
	dev, _ := app.FindRecordById(schema.Devices, id)
	if dev.GetString("enrolled_by") != bm.Id || dev.GetDateTime("expires").Time().Before(time.Now().Add(364*24*time.Hour)) {
		t.Errorf("approval record: %v", dev.PublicExport())
	}
	if _, ok := auditEntry(t, app, audit.ActionUpdate, schema.Devices, id); !ok {
		t.Error("the approval is not in the audit chain")
	}
}

func TestAnOrgAdminsDeviceNeedsTwoOtherAdmins(t *testing.T) {
	o, mux, app, done := strictApp(t)
	defer done()
	admin2 := testutil.User(t, app, schema.StaffUsers, "admin2@example.org", schema.RoleOrgAdmin, o.Root, true)
	admin3 := testutil.User(t, app, schema.StaffUsers, "admin3@example.org", schema.RoleOrgAdmin, o.Root, true)
	bm := testutil.User(t, app, schema.StaffUsers, "bm1@example.org", schema.RoleBranchManager, o.Branch1, true)

	phone := freshPhone()
	token, id := phone.enrol(t, mux, schema.StaffUsers, "admin@example.org")

	// Nobody approves their own device: sign as the admin's other, approved device.
	if status, body := asApprover(t, app, o.Admin).call(mux, http.MethodPost, approveURL(id), map[string]any{"code": phone.code()}); status != http.StatusForbidden {
		t.Errorf("self-approval: %d %s", status, body)
	}
	if status, body := asApprover(t, app, bm).call(mux, http.MethodPost, approveURL(id), map[string]any{"code": phone.code()}); status != http.StatusForbidden {
		t.Errorf("a branch manager approved an admin's device: %d %s", status, body)
	}
	a2 := asApprover(t, app, admin2)
	status, body := a2.call(mux, http.MethodPost, approveURL(id), map[string]any{"code": phone.code()})
	if status != http.StatusOK || !strings.Contains(body, `"needs_second_approval":true`) {
		t.Fatalf("first approval: %d %s", status, body)
	}
	if status, body := a2.call(mux, http.MethodPost, approveURL(id), map[string]any{"code": phone.code()}); status != http.StatusConflict {
		t.Errorf("the same admin approved twice: %d %s", status, body)
	}
	if status, _ := signed(mux, http.MethodGet, formsURL, token, id, phone.key, nil); status != http.StatusForbidden {
		t.Error("the device worked after one approval")
	}
	if status, body := asApprover(t, app, admin3).call(mux, http.MethodPost, approveURL(id), map[string]any{"code": phone.code()}); status != http.StatusOK ||
		!strings.Contains(body, `"status":"active"`) {
		t.Fatalf("second approval: %d %s", status, body)
	}
	if status, body := signed(mux, http.MethodGet, formsURL, token, id, phone.key, nil); status != http.StatusOK {
		t.Errorf("after two approvals: %d %s", status, body)
	}
}

func TestTheServerCommandLineApprovesTheFirstAdminsDevice(t *testing.T) {
	o, mux, app, done := strictApp(t)
	defer done()
	phone := freshPhone()
	token, id := phone.enrol(t, mux, schema.StaffUsers, "admin@example.org")

	if _, err := api.ActivateFromCommandLine(app, audit.CLIActor("device approve"), id, "123"); err == nil {
		t.Fatal("wrong numbers were accepted")
	}
	if _, err := api.ActivateFromCommandLine(app, audit.CLIActor("device approve"), id, devicetrust.GroupCode(phone.code())); err != nil {
		t.Fatal(err)
	}
	if status, body := signed(mux, http.MethodGet, formsURL, token, id, phone.key, nil); status != http.StatusOK {
		t.Errorf("after command-line approval: %d %s", status, body)
	}
	_ = o
}

func TestSignaturesCannotBeReplayedOrForged(t *testing.T) {
	o, mux, app, done := strictApp(t)
	defer done()
	a := asApprover(t, app, o.Field1)

	// The same signed request twice.
	r := httptest.NewRequest(http.MethodGet, formsURL, nil)
	r.Header.Set("Authorization", a.token)
	testutil.Sign(r, a.dev.ID, a.dev.Key, nil)
	for i, want := range []int{http.StatusOK, http.StatusForbidden} {
		r2 := r.Clone(r.Context())
		w := httptest.NewRecorder()
		mux.ServeHTTP(w, r2)
		if w.Code != want {
			t.Errorf("send %d: %d %s", i+1, w.Code, w.Body.String())
		}
	}
	cases := map[string]func(*http.Request){
		"old time": func(r *http.Request) {
			r.Header.Set(devicetrust.HeaderTime, strconv.FormatInt(time.Now().Add(-10*time.Minute).Unix(), 10))
		},
		"other path":   func(r *http.Request) { r.URL.Path = "/api/collections/locations/records"; r.RequestURI = r.URL.Path },
		"no signature": func(r *http.Request) { r.Header.Del(devicetrust.HeaderSignature) },
		"someone else's device": func(r *http.Request) {
			r.Header.Set(devicetrust.HeaderDevice, testutil.Device(t, app, o.Peer1).ID)
		},
	}
	for name, tweak := range cases {
		if status, body := signed(mux, http.MethodGet, formsURL, a.token, a.dev.ID, a.dev.Key, nil, tweak); status == http.StatusOK {
			t.Errorf("%s: accepted: %s", name, body)
		}
	}
	// A changed body.
	if status, _ := signed(mux, http.MethodPatch, "/api/collections/field_users/records/"+o.Field1.Id, a.token, a.dev.ID, a.dev.Key,
		map[string]any{"name": "A"}, func(r *http.Request) {
			r.Body = httpBody(`{"name":"B"}`)
		}); status == http.StatusOK {
		t.Error("a changed body was accepted")
	}
}

func TestASessionStaysOnItsDeviceAndCanBeRevoked(t *testing.T) {
	o, mux, app, done := strictApp(t)
	defer done()
	a := asApprover(t, app, o.Field1)

	// A second approved device of the same person cannot use the session.
	second := freshPhone()
	_, secondID := second.enrol(t, mux, schema.FieldUsers, "field1@example.org")
	if _, err := api.ActivateFromCommandLine(app, audit.CLIActor("device approve"), secondID, second.code()); err != nil {
		t.Fatal(err)
	}
	if status, body := signed(mux, http.MethodGet, formsURL, a.token, secondID, second.key, nil); status != http.StatusUnauthorized ||
		!reasonIs(body, schema.ReasonSessionOtherDevice) {
		t.Errorf("session on another device: %d %s", status, body)
	}

	// An org admin revokes the session.
	session, err := app.FindFirstRecordByData(schema.Sessions, "token_hash", testutil.TokenHash(a.token))
	if err != nil {
		t.Fatal(err)
	}
	admin := asApprover(t, app, o.Admin)
	if status, body := admin.call(mux, http.MethodPatch, "/api/collections/sessions/records/"+session.Id, map[string]any{"revoked": true}); status != http.StatusOK {
		t.Fatalf("revoke session: %d %s", status, body)
	}
	if status, body := a.call(mux, http.MethodGet, formsURL, nil); status != http.StatusUnauthorized || !reasonIs(body, schema.ReasonSessionRevoked) {
		t.Errorf("after the session was revoked: %d %s", status, body)
	}
}

func TestRevokingADeviceStopsItAtOnce(t *testing.T) {
	o, mux, app, done := strictApp(t)
	defer done()
	a := asApprover(t, app, o.Field1)

	if status, body := asApprover(t, app, o.Sup1).call(mux, http.MethodPost, revokeURL(a.dev.ID), nil); status != http.StatusForbidden {
		t.Errorf("a supervisor revoked a device: %d %s", status, body)
	}
	// The owner reports the phone lost.
	if status, body := a.call(mux, http.MethodPost, revokeURL(a.dev.ID), nil); status != http.StatusOK {
		t.Fatalf("revoke own device: %d %s", status, body)
	}
	if status, body := a.call(mux, http.MethodGet, formsURL, nil); status != http.StatusForbidden || !reasonIs(body, schema.ReasonDeviceRevoked) {
		t.Errorf("after revoking: %d %s", status, body)
	}
	if n, _ := app.CountRecords(schema.Sessions, dbx.HashExp{"device": a.dev.ID, "revoked": false}); n != 0 {
		t.Errorf("%d sessions of the revoked device still open", n)
	}
}

func TestAnExpiredApprovalIsRenewed(t *testing.T) {
	o, mux, app, done := strictApp(t)
	defer done()
	a := asApprover(t, app, o.Field1)
	dev, _ := app.FindRecordById(schema.Devices, a.dev.ID)
	past, _ := types.ParseDateTime(time.Now().Add(-time.Hour))
	dev.Set("expires", past)
	if err := app.Save(dev); err != nil {
		t.Fatal(err)
	}
	if status, body := a.call(mux, http.MethodGet, formsURL, nil); status != http.StatusForbidden || !reasonIs(body, schema.ReasonDeviceExpired) {
		t.Errorf("expired: %d %s", status, body)
	}
	if status, body := a.call(mux, http.MethodGet, meURL, nil); status != http.StatusOK || !strings.Contains(body, `"approval_expired":true`) {
		t.Errorf("status of an expired device: %d %s", status, body)
	}
	code := devicetrust.Code(a.dev.Key.Public().(ed25519.PublicKey), a.dev.EncKey)
	if status, body := asApprover(t, app, o.Admin).call(mux, http.MethodPost, approveURL(a.dev.ID), map[string]any{"code": code}); status != http.StatusOK {
		t.Fatalf("renew: %d %s", status, body)
	}
	if status, body := a.call(mux, http.MethodGet, formsURL, nil); status != http.StatusOK {
		t.Errorf("after renewal: %d %s", status, body)
	}
}

func TestAtMostThreeDevicesWaitPerPerson(t *testing.T) {
	_, mux, _, done := strictApp(t)
	defer done()
	for i := 0; i < schema.MaxPendingDevices; i++ {
		freshPhone().enrol(t, mux, schema.FieldUsers, "field1@example.org")
	}
	p := freshPhone()
	_, body := signIn(mux, schema.FieldUsers, "field1@example.org", testutil.Password)
	if status, body := signed(mux, http.MethodPost, enrolURL, tokenOf(t, body), api.EnrolDeviceID, p.key, p.keys()); status != http.StatusTooManyRequests {
		t.Errorf("a fourth waiting device: %d %s", status, body)
	}
}

func TestAOneTimePasswordCanBeChangedOnAWaitingPhone(t *testing.T) {
	o, mux, app, done := strictApp(t)
	defer done()
	f, _ := app.FindRecordById(schema.FieldUsers, o.Field1.Id)
	f.SetPassword(oneTimePassword)
	f.Set(schema.MustChangePassword, true)
	if err := app.Save(f); err != nil {
		t.Fatal(err)
	}
	phone := freshPhone()
	status, body := signIn(mux, schema.FieldUsers, "field1@example.org", oneTimePassword)
	if status != http.StatusOK {
		t.Fatal(body)
	}
	token := tokenOf(t, body)
	status, body = signed(mux, http.MethodPost, enrolURL, token, api.EnrolDeviceID, phone.key, phone.keys())
	if status != http.StatusOK {
		t.Fatalf("enrol: %d %s", status, body)
	}
	id := idOf(t, body)
	if status, body := signed(mux, http.MethodPatch, "/api/collections/field_users/records/"+o.Field1.Id, token, id, phone.key,
		map[string]any{"oldPassword": oneTimePassword, "password": "my-own-password-1", "passwordConfirm": "my-own-password-1"}); status != http.StatusOK {
		t.Errorf("password change on a waiting phone: %d %s", status, body)
	}
}

func TestASignedSignInTiesTheSessionToTheDevice(t *testing.T) {
	o, mux, app, done := strictApp(t)
	defer done()
	d := testutil.Device(t, app, o.Field1)

	raw, _ := json.Marshal(map[string]string{"identity": "field1@example.org", "password": testutil.Password})
	r := httptest.NewRequest(http.MethodPost, "/api/collections/field_users/auth-with-password", bytes.NewReader(raw))
	r.Header.Set("Content-Type", "application/json")
	r.RemoteAddr = defaultIP + ":40000"
	testutil.Sign(r, d.ID, d.Key, raw)
	w := httptest.NewRecorder()
	mux.ServeHTTP(w, r)
	if w.Code != http.StatusOK {
		t.Fatalf("signed sign-in: %d %s", w.Code, w.Body.String())
	}
	token := tokenOf(t, w.Body.String())
	s, err := app.FindFirstRecordByData(schema.Sessions, "token_hash", testutil.TokenHash(token))
	if err != nil || s.GetString("device") != d.ID {
		t.Fatalf("session device %q (%v)", s.GetString("device"), err)
	}
	// Two sign-ins in one second get different tokens.
	_, b1 := signIn(mux, schema.FieldUsers, "field1@example.org", testutil.Password)
	_, b2 := signIn(mux, schema.FieldUsers, "field1@example.org", testutil.Password)
	if tokenOf(t, b1) == tokenOf(t, b2) {
		t.Error("two sign-ins got the same token")
	}
}

func httpBody(s string) *readCloser { return &readCloser{strings.NewReader(s)} }

type readCloser struct{ *strings.Reader }

func (readCloser) Close() error { return nil }

func runDevice(t testing.TB, app core.App, args ...string) (string, error) {
	t.Helper()
	cmd := cli.NewDeviceCommand(app)
	var out bytes.Buffer
	cmd.SetOut(&out)
	cmd.SetErr(&out)
	cmd.SetArgs(args)
	err := cmd.Execute()
	return out.String(), err
}

func TestTheDeviceCommands(t *testing.T) {
	_, mux, app, done := strictApp(t)
	defer done()

	if out, err := runDevice(t, app, "list"); err != nil || !strings.Contains(out, "No devices are waiting") {
		t.Errorf("empty list: %v %s", err, out)
	}
	phone := freshPhone()
	token, id := phone.enrol(t, mux, schema.StaffUsers, "admin@example.org")
	dev, _ := app.FindRecordById(schema.Devices, id)
	dev.Set("label", "Sample\x1b[2Jphone‮")
	if err := app.Save(dev); err != nil {
		t.Fatal(err)
	}

	out, err := runDevice(t, app, "list")
	if err != nil || !strings.Contains(out, id) || !strings.Contains(out, "admin@example.org (organisation admin)") ||
		strings.ContainsAny(out, "\x1b‮") {
		t.Errorf("list: %v %q", err, out)
	}
	if _, err := runDevice(t, app, "approve", id, "111 222 333 444 555 666"); err == nil {
		t.Error("wrong numbers were accepted")
	}
	if _, err := runDevice(t, app, "approve", "nosuchdevice123", phone.code()); err == nil {
		t.Error("an unknown device was approved")
	}
	if out, err := runDevice(t, app, "approve", id, devicetrust.GroupCode(phone.code())); err != nil || !strings.Contains(out, "Approved") {
		t.Fatalf("approve: %v %s", err, out)
	}
	if status, body := signed(mux, http.MethodGet, formsURL, token, id, phone.key, nil); status != http.StatusOK {
		t.Errorf("after approval: %d %s", status, body)
	}
	if n, err := app.CountRecords(schema.Audit, dbx.HashExp{"action": audit.ActionUpdate, "record_id": id,
		"actor": cli.DeviceApproveActor.ID, "actor_collection": cli.DeviceApproveActor.Collection}); err != nil || n != 1 {
		t.Errorf("audit entries for the approval: %d %v", n, err)
	}

	if out, err := runDevice(t, app, "revoke", id); err != nil || !strings.Contains(out, "Switched off") {
		t.Fatalf("revoke: %v %s", err, out)
	}
	if status, body := signed(mux, http.MethodGet, formsURL, token, id, phone.key, nil); status == http.StatusOK {
		t.Errorf("after revoking: %d %s", status, body)
	}
	if _, err := runDevice(t, app, "approve", id, phone.code()); err == nil {
		t.Error("a switched-off device was approved again")
	}
	if out, _ := runDevice(t, app, "list", "--all"); !strings.Contains(out, schema.DeviceRevoked) {
		t.Errorf("list --all: %s", out)
	}
}

func TestOnlyAFreshSessionEnrolsADevice(t *testing.T) {
	o, mux, app, done := strictApp(t)
	defer done()
	phone := freshPhone()
	token, id := phone.enrol(t, mux, schema.FieldUsers, "field1@example.org")
	s, err := app.FindFirstRecordByData(schema.Sessions, "token_hash", testutil.TokenHash(token))
	if err != nil || s.GetString("device") != id {
		t.Fatalf("the enrolling session is not the device's: %q %v", s.GetString("device"), err)
	}

	// The same session cannot enrol a second device.
	other := freshPhone()
	if status, body := signed(mux, http.MethodPost, enrolURL, token, api.EnrolDeviceID, other.key, other.keys()); status != http.StatusUnauthorized ||
		!reasonIs(body, schema.ReasonSessionOtherDevice) {
		t.Errorf("a second device on one session: %d %s", status, body)
	}

	// An ended session cannot enrol at all.
	_, body := signIn(mux, schema.FieldUsers, "field1@example.org", testutil.Password)
	fresh := tokenOf(t, body)
	s2, _ := app.FindFirstRecordByData(schema.Sessions, "token_hash", testutil.TokenHash(fresh))
	s2.Set("revoked", true)
	if err := app.Save(s2); err != nil {
		t.Fatal(err)
	}
	if status, body := signed(mux, http.MethodPost, enrolURL, fresh, api.EnrolDeviceID, other.key, other.keys()); status != http.StatusUnauthorized ||
		!reasonIs(body, schema.ReasonSessionRevoked) {
		t.Errorf("enrol on an ended session: %d %s", status, body)
	}
	if n, _ := app.CountRecords(schema.Devices, dbx.HashExp{"field_user": o.Field1.Id, "status": schema.DevicePending}); n != 1 {
		t.Errorf("%d waiting devices, want 1", n)
	}
}
