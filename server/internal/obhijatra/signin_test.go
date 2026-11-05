package obhijatra_test

import (
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/http/httptest"
	"regexp"
	"strings"
	"testing"
	"time"

	"ganigeorgiev.com/pocketbase/dbx"
	"ganigeorgiev.com/pocketbase/pocketbase/core"
	"ganigeorgiev.com/pocketbase/pocketbase/tests"

	"github.com/obhijatra/obhijatra/server/internal/audit"
	"github.com/obhijatra/obhijatra/server/internal/lockout"
	"github.com/obhijatra/obhijatra/server/internal/obhijatra"
	"github.com/obhijatra/obhijatra/server/internal/schema"
	"github.com/obhijatra/obhijatra/server/internal/signin"
	"github.com/obhijatra/obhijatra/server/internal/testutil"
)

const (
	settingsURL = "/api/obhijatra/v1" + signin.SettingsPath
	methodsURL  = "/api/obhijatra/v1" + signin.MethodsPath
	codeURL     = "/api/obhijatra/v1" + signin.PhoneCodePath
	verifyURL   = "/api/obhijatra/v1" + signin.PhoneVerifyPath
	testSMSURL  = "/api/obhijatra/v1" + signin.TestSMSPath

	smsSecret   = "s3cret-api-key"
	field1Phone = "+8801711111111"
)

// smsMsg is one request the fake SMS provider received.
type smsMsg struct {
	method, query, contentType, body string
	header                           http.Header
}

// fakeSMSProvider starts an HTTPS SMS provider that accepts every message
// and repeats the X-Key header in its reply (as some real providers repeat
// the key), and points the server's SMS transport at it.
func fakeSMSProvider(t *testing.T) (*httptest.Server, chan smsMsg) {
	t.Helper()
	got := make(chan smsMsg, 20)
	srv := httptest.NewTLSServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		b, _ := io.ReadAll(r.Body)
		got <- smsMsg{r.Method, r.URL.RawQuery, r.Header.Get("Content-Type"), string(b), r.Header.Clone()}
		fmt.Fprintf(w, `{"status":"SUCCESS","echo":"%s"}`, r.Header.Get("X-Key"))
	}))
	old := signin.SMSTransport
	signin.SMSTransport = srv.Client().Transport
	t.Cleanup(func() {
		srv.Close()
		signin.SMSTransport = old
	})
	return srv, got
}

func gatewayFor(srv *httptest.Server) map[string]any {
	return map[string]any{
		"method":       "POST",
		"url":          srv.URL + "/send?key={secret}",
		"content_type": "json",
		"body":         `{"to":"{phone_digits}","text":"{message}"}`,
		"headers":      []map[string]string{{"name": "X-Key", "value": "{secret}"}},
		"secret":       smsSecret,
		"success_text": "SUCCESS",
	}
}

func putSignInSettings(t *testing.T, mux http.Handler, admin *core.Record, body map[string]any) (int, string) {
	t.Helper()
	return call(mux, http.MethodPut, settingsURL, testutil.Token(t, admin), body)
}

func enablePhone(t *testing.T, mux http.Handler, admin *core.Record, srv *httptest.Server) {
	t.Helper()
	status, body := putSignInSettings(t, mux, admin, map[string]any{
		"phone": map[string]any{"enabled": true, "sms": gatewayFor(srv)},
	})
	if status != http.StatusOK {
		t.Fatalf("switching on phone sign-in: %d %s", status, body)
	}
}

func setPhone(t testing.TB, app core.App, r *core.Record, phone string) {
	t.Helper()
	r.Set("phone", phone)
	if err := app.Save(r); err != nil {
		t.Fatalf("set phone: %v", err)
	}
}

func waitSMS(t *testing.T, got chan smsMsg) smsMsg {
	t.Helper()
	select {
	case m := <-got:
		return m
	case <-time.After(5 * time.Second):
		t.Fatal("no SMS was sent")
	}
	return smsMsg{}
}

func noSMS(t *testing.T, got chan smsMsg) {
	t.Helper()
	select {
	case m := <-got:
		t.Fatalf("an SMS was sent: %+v", m)
	case <-time.After(300 * time.Millisecond):
	}
}

var codeInSMS = regexp.MustCompile(`"text":"(\d{6}) is your Obhijatra sign-in code`)

func codeOf(t *testing.T, m smsMsg) string {
	t.Helper()
	match := codeInSMS.FindStringSubmatch(m.body)
	if match == nil {
		t.Fatalf("no code in the SMS %q", m.body)
	}
	return match[1]
}

func askForCode(t *testing.T, mux http.Handler, collection, phone string) (int, signin.CodeResponse, string) {
	t.Helper()
	status, body := call(mux, http.MethodPost, codeURL, "", map[string]string{"collection": collection, "phone": phone})
	var r signin.CodeResponse
	_ = json.Unmarshal([]byte(body), &r)
	return status, r, body
}

func checkCode(mux http.Handler, codeID, code string) (int, string) {
	return call(mux, http.MethodPost, verifyURL, "", map[string]string{"code_id": codeID, "code": code})
}

func wrongCodeFor(code string) string {
	if code == "000000" {
		return "111111"
	}
	return "000000"
}

// ---------------------------------------------------------------------

func TestSignInMethodsAreOffUntilSwitchedOn(t *testing.T) {
	app := testutil.NewApp(t)
	defer app.Cleanup()
	mux := serveMux(t, app)

	status, body := call(mux, http.MethodGet, methodsURL, "", nil)
	if status != http.StatusOK || body != `{"password":true,"google":false,"phone":false}` {
		t.Fatalf("methods: %d %s", status, body)
	}
}

func TestSignInSettingsAreForOrgAdminsOnly(t *testing.T) {
	app := testutil.NewApp(t)
	defer app.Cleanup()
	o := testutil.SeedOrg(t, app)
	mux := serveMux(t, app)

	for _, who := range []*core.Record{o.Sup1, o.ME1, o.Donor, o.Field1} {
		if status, body := call(mux, http.MethodGet, settingsURL, testutil.Token(t, who), nil); status == http.StatusOK {
			t.Errorf("%s read the sign-in settings: %s", who.Email(), body)
		}
		if status, _ := putSignInSettings(t, mux, who, map[string]any{}); status == http.StatusOK {
			t.Errorf("%s changed the sign-in settings", who.Email())
		}
	}
	if status, _ := call(mux, http.MethodGet, settingsURL, "", nil); status == http.StatusOK {
		t.Error("a stranger read the sign-in settings")
	}

	status, body := call(mux, http.MethodGet, settingsURL, testutil.Token(t, o.Admin), nil)
	if status != http.StatusOK || !strings.Contains(body, `/api/oauth2-redirect"`) {
		t.Fatalf("org admin: %d %s", status, body)
	}
}

func TestSignInSettingsAreChecked(t *testing.T) {
	app := testutil.NewApp(t)
	defer app.Cleanup()
	o := testutil.SeedOrg(t, app)
	mux := serveMux(t, app)
	srv, _ := fakeSMSProvider(t)

	plainHTTP := gatewayFor(srv)
	plainHTTP["url"] = strings.Replace(srv.URL, "https://", "http://", 1) + "/send?key={secret}"
	noMessage := gatewayFor(srv)
	noMessage["body"] = `{"to":"{phone}"}`
	badJSON := gatewayFor(srv)
	badJSON["body"] = `{"to":"{phone}","text":"{message}"`
	badHeader := gatewayFor(srv)
	badHeader["headers"] = []map[string]string{{"name": "Host", "value": "x"}}

	cases := []struct {
		name  string
		body  map[string]any
		field string
	}{
		{"plain http", map[string]any{"phone": map[string]any{"enabled": true, "sms": plainHTTP}}, "phone.sms.url"},
		{"no message placeholder", map[string]any{"phone": map[string]any{"enabled": true, "sms": noMessage}}, "phone.sms.body"},
		{"broken JSON", map[string]any{"phone": map[string]any{"enabled": true, "sms": badJSON}}, "phone.sms.body"},
		{"server-set header", map[string]any{"phone": map[string]any{"enabled": true, "sms": badHeader}}, "phone.sms.headers.0"},
		{"phone on, no provider", map[string]any{"phone": map[string]any{"enabled": true}}, "phone.sms.url"},
		{"Google on, no client", map[string]any{"google": map[string]any{"enabled": true}}, "google.client_id"},
		{"Google, wrong client id", map[string]any{"google": map[string]any{"enabled": true, "client_id": "my-app", "client_secret": "x"}}, "google.client_id"},
		{"Google on, no secret", map[string]any{"google": map[string]any{"enabled": true, "client_id": "123-abc.apps.googleusercontent.com"}}, "google.client_secret"},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			status, body := putSignInSettings(t, mux, o.Admin, c.body)
			if status != http.StatusBadRequest || !strings.Contains(body, `"`+c.field+`"`) {
				t.Fatalf("want 400 naming %s, got %d %s", c.field, status, body)
			}
		})
	}

	status, body := call(mux, http.MethodGet, methodsURL, "", nil)
	if status != http.StatusOK || body != `{"password":true,"google":false,"phone":false}` {
		t.Fatalf("refused settings changed something: %s", body)
	}
}

func TestSignInSecretsAreNeverSentBackAndChangesAreAudited(t *testing.T) {
	app := testutil.NewApp(t)
	defer app.Cleanup()
	o := testutil.SeedOrg(t, app)
	mux := serveMux(t, app)
	srv, _ := fakeSMSProvider(t)

	status, body := putSignInSettings(t, mux, o.Admin, map[string]any{
		"google": map[string]any{"enabled": true, "client_id": "123456789012-abc123.apps.googleusercontent.com", "client_secret": "google-secret-1"},
		"phone":  map[string]any{"enabled": true, "sms": gatewayFor(srv)},
	})
	if status != http.StatusOK {
		t.Fatalf("save: %d %s", status, body)
	}
	_, body = call(mux, http.MethodGet, settingsURL, testutil.Token(t, o.Admin), nil)
	for _, secret := range []string{smsSecret, "google-secret-1"} {
		if strings.Contains(body, secret) {
			t.Errorf("a secret was sent back: %s", body)
		}
	}
	if !strings.Contains(body, `"secret_set":true`) || !strings.Contains(body, `"client_secret_set":true`) {
		t.Errorf("the settings do not say the secrets are set: %s", body)
	}
	if _, ok := auditEntry(t, app, audit.ActionUpdate, schema.SignInSettingsTable, "settings"); !ok {
		t.Error("the change is not in the audit chain")
	}

	// Saving again without the secrets keeps them.
	gw := gatewayFor(srv)
	gw["secret"] = ""
	status, body = putSignInSettings(t, mux, o.Admin, map[string]any{
		"google": map[string]any{"enabled": true, "client_id": "123456789012-abc123.apps.googleusercontent.com"},
		"phone":  map[string]any{"enabled": true, "sms": gw},
	})
	if status != http.StatusOK {
		t.Fatalf("save without secrets: %d %s", status, body)
	}
	s, err := signin.Load(app)
	if err != nil || s.SMS.Secret != smsSecret {
		t.Errorf("the SMS key was not kept: %q %v", s.SMS.Secret, err)
	}
	g, _ := signin.LoadGoogle(app)
	if !g.Enabled || !g.SecretSet {
		t.Errorf("Google sign-in after saving without the secret: %+v", g)
	}

	_, body = call(mux, http.MethodGet, methodsURL, "", nil)
	if body != `{"password":true,"google":true,"phone":true}` {
		t.Errorf("methods: %s", body)
	}
	if r, err := audit.Verify(app); err != nil || !r.OK {
		t.Errorf("audit chain: %+v %v", r, err)
	}
}

func TestSignInSettingsAreEncryptedWithTheSettingsKey(t *testing.T) {
	const env = "OBHIJATRA_TEST_SETTINGS_KEY"
	t.Setenv(env, "0123456789abcdef0123456789abcdef")
	app, err := tests.NewTestAppWithConfig(core.BaseAppConfig{DataDir: t.TempDir(), EncryptionEnv: env})
	if err != nil {
		t.Fatal(err)
	}
	defer app.Cleanup()
	obhijatra.Register(app)

	var u signin.Update
	u.Phone.Enabled = true
	u.Phone.SMS = signin.SMSGateway{Method: "POST", URL: "https://sms.example.org/send", ContentType: "form",
		Body: "to={phone_digits}&text={message}&key={secret}", Secret: smsSecret}
	if err := signin.Apply(app, audit.CLIActor("test"), u); err != nil {
		t.Fatal(err)
	}

	var stored string
	if err := app.DB().Select("value").From(schema.SignInSettingsTable).Row(&stored); err != nil {
		t.Fatal(err)
	}
	if !strings.HasPrefix(stored, "v1:") || strings.Contains(stored, smsSecret) || strings.Contains(stored, "sms.example.org") {
		t.Fatalf("stored settings are not encrypted: %q", stored)
	}
	s, err := signin.Load(app)
	if err != nil || s.SMS.Secret != smsSecret || !s.PhoneReady() {
		t.Fatalf("read back: %+v %v", s, err)
	}
}

func TestPhoneSignInWorksEndToEnd(t *testing.T) {
	app := testutil.NewApp(t)
	defer app.Cleanup()
	o := testutil.SeedOrg(t, app)
	mux := serveMux(t, app)
	srv, got := fakeSMSProvider(t)
	enablePhone(t, mux, o.Admin, srv)
	setPhone(t, app, o.Field1, field1Phone)

	// People type numbers with spaces and hyphens.
	status, r, body := askForCode(t, mux, schema.FieldUsers, "+880 1711-111111")
	if status != http.StatusOK || len(r.CodeID) != 15 || r.ExpiresIn != 300 || r.ResendAfter != 60 {
		t.Fatalf("ask for a code: %d %s", status, body)
	}

	m := waitSMS(t, got)
	if m.method != http.MethodPost || m.contentType != "application/json" || m.query != "key="+smsSecret || m.header.Get("X-Key") != smsSecret {
		t.Errorf("the provider got %+v", m)
	}
	if !json.Valid([]byte(m.body)) || !strings.Contains(m.body, `"to":"8801711111111"`) {
		t.Errorf("the provider got the body %s", m.body)
	}
	code := codeOf(t, m)

	status, body = checkCode(mux, r.CodeID, code)
	if status != http.StatusOK {
		t.Fatalf("right code: %d %s", status, body)
	}
	var auth struct {
		Token  string `json:"token"`
		Record struct {
			ID string `json:"id"`
		} `json:"record"`
	}
	if err := json.Unmarshal([]byte(body), &auth); err != nil || auth.Token == "" || auth.Record.ID != o.Field1.Id {
		t.Fatalf("sign-in answer: %s", body)
	}

	// A code works once.
	if status, _ := checkCode(mux, r.CodeID, code); status != http.StatusBadRequest {
		t.Errorf("a used code worked again: %d", status)
	}

	// The settings screen shows the last send, without the key the
	// provider repeated.
	_, body = call(mux, http.MethodGet, settingsURL, testutil.Token(t, o.Admin), nil)
	if !strings.Contains(body, `"ok":true`) || strings.Contains(body, smsSecret) || !strings.Contains(body, "[key hidden]") {
		t.Errorf("last send: %s", body)
	}
	if r, err := audit.Verify(app); err != nil || !r.OK {
		t.Errorf("audit chain: %+v %v", r, err)
	}
}

func TestPhoneCodeAllowsThreeTriesAndCountsTowardsTheLock(t *testing.T) {
	app := testutil.NewApp(t)
	defer app.Cleanup()
	o := testutil.SeedOrg(t, app)
	mux := serveMux(t, app)
	srv, got := fakeSMSProvider(t)
	enablePhone(t, mux, o.Admin, srv)
	setPhone(t, app, o.Field1, field1Phone)

	_, r, _ := askForCode(t, mux, schema.FieldUsers, field1Phone)
	code := codeOf(t, waitSMS(t, got))

	for i := 0; i < schema.PhoneCodeMaxTries; i++ {
		status, body := checkCode(mux, r.CodeID, wrongCodeFor(code))
		if status != http.StatusBadRequest || !strings.Contains(body, "That code is wrong or has expired") {
			t.Fatalf("wrong code %d: %d %s", i+1, status, body)
		}
	}
	if status, _ := checkCode(mux, r.CodeID, code); status != http.StatusBadRequest {
		t.Fatalf("the right code worked after %d wrong ones", schema.PhoneCodeMaxTries)
	}
	if n := failureCount(t, app, o.Field1); n != schema.PhoneCodeMaxTries {
		t.Errorf("wrong codes counted towards the lock: %d, want %d", n, schema.PhoneCodeMaxTries)
	}
}

func TestPhoneCodeIsNotSentToThoseWhoMayNotUseIt(t *testing.T) {
	app := testutil.NewApp(t)
	defer app.Cleanup()
	o := testutil.SeedOrg(t, app)
	mux := serveMux(t, app)
	srv, got := fakeSMSProvider(t)
	enablePhone(t, mux, o.Admin, srv)

	setPhone(t, app, o.Admin, "+8801700000001") // org admin
	setPhone(t, app, o.Gone1, "+8801700000002") // deactivated
	setPhone(t, app, o.Peer1, "+8801700000003") // locked, below

	for i := 0; i < schema.LockoutMaxFailures; i++ {
		if err := lockout.RecordFailure(app, o.Peer1, defaultIP); err != nil {
			t.Fatal(err)
		}
	}

	for _, c := range []struct{ collection, phone string }{
		{schema.StaffUsers, "+8801700000001"},
		{schema.FieldUsers, "+8801700000002"},
		{schema.FieldUsers, "+8801700000003"},
		{schema.FieldUsers, "+8801799999999"}, // nobody
		{schema.StaffUsers, field1Phone},      // a field user's number asked for as staff
	} {
		status, r, body := askForCode(t, mux, c.collection, c.phone)
		if status != http.StatusOK || len(r.CodeID) != 15 {
			t.Errorf("%s: the answer differs from a real request: %d %s", c.phone, status, body)
		}
		noSMS(t, got)
		if status, body := checkCode(mux, r.CodeID, "123456"); status != http.StatusBadRequest {
			t.Errorf("%s: checking the code: %d %s", c.phone, status, body)
		}
	}
}

func TestPhoneCodeRequestsAreLimitedAndChecked(t *testing.T) {
	app := testutil.NewApp(t)
	defer app.Cleanup()
	o := testutil.SeedOrg(t, app)
	mux := serveMux(t, app)
	srv, got := fakeSMSProvider(t)

	if status, _, body := askForCode(t, mux, schema.FieldUsers, field1Phone); status != http.StatusForbidden {
		t.Fatalf("phone sign-in off: %d %s", status, body)
	}

	enablePhone(t, mux, o.Admin, srv)
	setPhone(t, app, o.Field1, field1Phone)

	if status, _, body := askForCode(t, mux, schema.FieldUsers, "01711111111"); status != http.StatusBadRequest {
		t.Errorf("a number without a country code: %d %s", status, body)
	}
	if status, _, body := askForCode(t, mux, schema.Superusers, field1Phone); status != http.StatusBadRequest {
		t.Errorf("superusers: %d %s", status, body)
	}

	for i := 0; i < schema.PhoneCodesPerWindow; i++ {
		if status, _, body := askForCode(t, mux, schema.FieldUsers, field1Phone); status != http.StatusOK {
			t.Fatalf("code %d: %d %s", i+1, status, body)
		}
		waitSMS(t, got)
	}
	if status, _, body := askForCode(t, mux, schema.FieldUsers, field1Phone); status != http.StatusTooManyRequests {
		t.Fatalf("code %d: %d %s", schema.PhoneCodesPerWindow+1, status, body)
	}
	noSMS(t, got)
}

func TestPhoneCodeExpiresAndFollowsTheAccount(t *testing.T) {
	app := testutil.NewApp(t)
	defer app.Cleanup()
	o := testutil.SeedOrg(t, app)
	mux := serveMux(t, app)
	srv, got := fakeSMSProvider(t)
	enablePhone(t, mux, o.Admin, srv)
	setPhone(t, app, o.Field1, field1Phone)

	// Expired.
	_, r, _ := askForCode(t, mux, schema.FieldUsers, field1Phone)
	code := codeOf(t, waitSMS(t, got))
	old := time.Now().UTC().Add(-schema.PhoneCodeLifetime - time.Minute).Format("2006-01-02 15:04:05.000Z")
	exec(t, app, "UPDATE _otps SET created = {:t} WHERE id = {:id}", dbx.Params{"t": old, "id": r.CodeID})
	if status, _ := checkCode(mux, r.CodeID, code); status != http.StatusBadRequest {
		t.Error("an expired code worked")
	}

	// The number changed after the code was sent.
	_, r, _ = askForCode(t, mux, schema.FieldUsers, field1Phone)
	code = codeOf(t, waitSMS(t, got))
	setPhone(t, app, o.Field1, "+8801722222222")
	if status, _ := checkCode(mux, r.CodeID, code); status != http.StatusBadRequest {
		t.Error("a code sent to the old number worked")
	}

	// The account was made an org admin after the code was sent.
	setPhone(t, app, o.Sup1, "+8801733333333")
	_, r, _ = askForCode(t, mux, schema.StaffUsers, "+8801733333333")
	code = codeOf(t, waitSMS(t, got))
	o.Sup1.Set("role", schema.RoleOrgAdmin)
	if err := app.Save(o.Sup1); err != nil {
		t.Fatal(err)
	}
	if status, _ := checkCode(mux, r.CodeID, code); status != http.StatusBadRequest {
		t.Error("an org admin signed in with an SMS code")
	}
}

func TestTestSMS(t *testing.T) {
	app := testutil.NewApp(t)
	defer app.Cleanup()
	o := testutil.SeedOrg(t, app)
	mux := serveMux(t, app)
	srv, got := fakeSMSProvider(t)

	body := map[string]any{"phone": "+8801744444444", "sms": gatewayFor(srv)}
	if status, _ := call(mux, http.MethodPost, testSMSURL, testutil.Token(t, o.Sup1), body); status != http.StatusForbidden {
		t.Errorf("a supervisor sent a test SMS: %d", status)
	}

	status, resp := call(mux, http.MethodPost, testSMSURL, testutil.Token(t, o.Admin), body)
	if status != http.StatusOK || !strings.Contains(resp, `"ok":true`) || strings.Contains(resp, smsSecret) {
		t.Fatalf("test SMS: %d %s", status, resp)
	}
	m := waitSMS(t, got)
	if !strings.Contains(m.body, signin.TestMessage) || !strings.Contains(m.body, `"to":"8801744444444"`) {
		t.Errorf("test SMS body: %s", m.body)
	}

	// The provider's success text is missing from its reply.
	gw := gatewayFor(srv)
	gw["success_text"] = "DELIVERED"
	body["sms"] = gw
	status, resp = call(mux, http.MethodPost, testSMSURL, testutil.Token(t, o.Admin), body)
	if status != http.StatusOK || !strings.Contains(resp, `"ok":false`) {
		t.Fatalf("test SMS without the success text: %d %s", status, resp)
	}
	waitSMS(t, got)
}

func TestSMSProviderOnTheServerItselfIsRefused(t *testing.T) {
	// The real transport, not the test one: loopback is refused.
	g := signin.SMSGateway{Method: "GET", URL: "https://127.0.0.1:9/send?to={phone}&text={message}&key={secret}", Secret: smsSecret}
	res := g.Send(t.Context(), field1Phone, "hello")
	if res.OK || !strings.Contains(res.Reply, "not allowed") || strings.Contains(res.Reply, smsSecret) {
		t.Fatalf("send to loopback: %+v", res)
	}
}

// ---------------------------------------------------------------------
// Google sign-in, against a fake Google
// ---------------------------------------------------------------------

// fakeGoogle answers the token and user-info requests PocketBase makes. The
// authorisation code names the profile it returns.
func fakeGoogle(t *testing.T, profiles map[string]map[string]any) *httptest.Server {
	t.Helper()
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		switch r.URL.Path {
		case "/token":
			_ = r.ParseForm()
			fmt.Fprintf(w, `{"access_token":%q,"token_type":"Bearer","expires_in":3600}`, r.Form.Get("code"))
		case "/userinfo":
			p, ok := profiles[strings.TrimPrefix(r.Header.Get("Authorization"), "Bearer ")]
			if !ok {
				http.Error(w, "unknown", http.StatusUnauthorized)
				return
			}
			_ = json.NewEncoder(w).Encode(p)
		default:
			http.NotFound(w, r)
		}
	}))
	t.Cleanup(srv.Close)
	return srv
}

func TestGoogleSignInReachesOnlyExistingConfirmedAccounts(t *testing.T) {
	app := testutil.NewApp(t)
	defer app.Cleanup()
	o := testutil.SeedOrg(t, app)
	mux := serveMux(t, app)

	unconfirmed := testutil.User(t, app, schema.FieldUsers, "new@example.org", schema.RoleFieldOfficer, o.Branch1, true)
	unconfirmed.SetVerified(false)
	if err := app.Save(unconfirmed); err != nil {
		t.Fatal(err)
	}

	profile := func(email string, verified bool) map[string]any {
		return map[string]any{"sub": "g-" + email, "email": email, "email_verified": verified, "name": "Someone"}
	}
	google := fakeGoogle(t, map[string]map[string]any{
		"field1":      profile("Field1@example.org", true), // case differs
		"admin":       profile("admin@example.org", true),
		"stranger":    profile("stranger@example.org", true),
		"unconfirmed": profile("new@example.org", true),
		"gone":        profile("gone1@example.org", true),
		"noemail":     profile("field2@example.org", false),
	})

	status, body := putSignInSettings(t, mux, o.Admin, map[string]any{
		"google": map[string]any{"enabled": true, "client_id": "123456789012-abc123.apps.googleusercontent.com", "client_secret": "google-secret-1"},
	})
	if status != http.StatusOK {
		t.Fatalf("switch on Google: %d %s", status, body)
	}
	for _, name := range []string{schema.FieldUsers, schema.StaffUsers} {
		c, _ := app.FindCollectionByNameOrId(name)
		for i := range c.OAuth2.Providers {
			c.OAuth2.Providers[i].TokenURL = google.URL + "/token"
			c.OAuth2.Providers[i].UserInfoURL = google.URL + "/userinfo"
		}
		if err := app.Save(c); err != nil {
			t.Fatal(err)
		}
	}

	signInWithGoogle := func(collection, code, token string) (int, string) {
		return call(mux, http.MethodPost, "/api/collections/"+collection+"/auth-with-oauth2", token, map[string]string{
			"provider": "google", "code": code, "codeVerifier": strings.Repeat("v", 43),
			"redirectURL": "https://obhijatra.example.org/api/oauth2-redirect",
		})
	}
	usersBefore, _ := app.CountRecords(schema.FieldUsers)

	cases := []struct {
		name, collection, code, token string
		wantStatus                    int
		want                          string
	}{
		{"existing field user", schema.FieldUsers, "field1", "", http.StatusOK, o.Field1.Id},
		{"org admin", schema.StaffUsers, "admin", "", http.StatusOK, o.Admin.Id},
		{"no account", schema.FieldUsers, "stranger", "", http.StatusBadRequest, "No Obhijatra account here uses this Google email"},
		{"account not confirmed", schema.FieldUsers, "unconfirmed", "", http.StatusBadRequest, "must confirm your email address"},
		{"deactivated", schema.FieldUsers, "gone", "", http.StatusBadRequest, "This account cannot sign in"},
		{"Google email not confirmed", schema.FieldUsers, "noemail", "", http.StatusBadRequest, "did not share a confirmed email"},
		{"signed-in user links another Google account", schema.FieldUsers, "stranger", testutil.Token(t, o.Peer1), http.StatusBadRequest, "No Obhijatra account"},
		{"field account through the staff door", schema.StaffUsers, "field1", "", http.StatusBadRequest, "No Obhijatra account"},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			status, body := signInWithGoogle(c.collection, c.code, c.token)
			if status != c.wantStatus || !strings.Contains(body, c.want) {
				t.Fatalf("want %d with %q, got %d %s", c.wantStatus, c.want, status, body)
			}
		})
	}

	if usersAfter, _ := app.CountRecords(schema.FieldUsers); usersAfter != usersBefore {
		t.Errorf("Google sign-in created accounts: %d before, %d after", usersBefore, usersAfter)
	}
	if links, _ := app.CountRecords(core.CollectionNameExternalAuths); links != 2 {
		t.Errorf("Google links: %d, want 2 (field1 and admin)", links)
	}

	// The link stops working when an admin changes the email address.
	o.Field1.SetEmail("field1-new@example.org")
	if err := app.Save(o.Field1); err != nil {
		t.Fatal(err)
	}
	if status, body := signInWithGoogle(schema.FieldUsers, "field1", ""); status != http.StatusBadRequest {
		t.Errorf("Google sign-in after the email changed: %d %s", status, body)
	}
}

// ---------------------------------------------------------------------
// Phone numbers on accounts
// ---------------------------------------------------------------------

func TestEveryUserCanSignInSomehow(t *testing.T) {
	app := testutil.NewApp(t)
	defer app.Cleanup()
	o := testutil.SeedOrg(t, app)

	newUser := func(collection, email, phone, role string) error {
		c, _ := app.FindCollectionByNameOrId(collection)
		r := core.NewRecord(c)
		r.SetEmail(email)
		r.Set("phone", phone)
		r.SetPassword(testutil.Password)
		r.Set("role", role)
		r.Set("location", o.Branch1.Id)
		r.Set("active", true)
		return app.Save(r)
	}

	if err := newUser(schema.FieldUsers, "", "", schema.RoleFieldOfficer); err == nil {
		t.Error("a user with neither email nor phone was created")
	}
	if err := newUser(schema.FieldUsers, "", "+8801755555555", schema.RoleFieldOfficer); err != nil {
		t.Errorf("a field user with a phone number only: %v", err)
	}
	if err := newUser(schema.FieldUsers, "", "+8801755555555", schema.RoleFieldOfficer); err == nil {
		t.Error("two field users share a phone number")
	}
	if err := newUser(schema.StaffUsers, "", "+8801766666666", schema.RoleSupervisor); err != nil {
		t.Errorf("a supervisor with a phone number only: %v", err)
	}
	if err := newUser(schema.StaffUsers, "", "+8801777777777", schema.RoleOrgAdmin); err == nil {
		t.Error("an org admin without an email address was created")
	}
	if err := newUser(schema.FieldUsers, "", "01788888888", schema.RoleFieldOfficer); err == nil {
		t.Error("a phone number not in international form was stored")
	}
	if err := newUser(schema.FieldUsers, "FIELD1@example.org", "", schema.RoleFieldOfficer); err == nil {
		t.Error("two field users' email addresses differ only in capital letters")
	}

	// Password sign-in finds the account whatever capitals are typed.
	if status, body := signIn(serveMux(t, app), schema.FieldUsers, "Field1@Example.org", testutil.Password); status != http.StatusOK {
		t.Errorf("sign-in with capitals in the email: %d %s", status, body)
	}
}

func TestUsersCannotChangeTheirOwnPhoneNumber(t *testing.T) {
	app := testutil.NewApp(t)
	defer app.Cleanup()
	o := testutil.SeedOrg(t, app)
	mux := serveMux(t, app)
	setPhone(t, app, o.Field1, field1Phone)

	status, body := call(mux, http.MethodPatch, "/api/collections/field_users/records/"+o.Field1.Id,
		testutil.Token(t, o.Field1), map[string]string{"phone": "+8801799999999"})
	if status == http.StatusOK {
		t.Fatalf("a field user changed their own phone number: %s", body)
	}
	r, _ := app.FindRecordById(schema.FieldUsers, o.Field1.Id)
	if r.GetString("phone") != field1Phone {
		t.Errorf("phone is now %q", r.GetString("phone"))
	}
}

func TestUnlockByPhoneNumber(t *testing.T) {
	app := testutil.NewApp(t)
	defer app.Cleanup()
	o := testutil.SeedOrg(t, app)
	setPhone(t, app, o.Field1, field1Phone)

	for i := 0; i < schema.LockoutMaxFailures; i++ {
		if err := lockout.RecordFailure(app, o.Field1, defaultIP); err != nil {
			t.Fatal(err)
		}
	}
	results, err := lockout.Unlock(app, audit.CLIActor("unlock"), field1Phone)
	if err != nil || len(results) != 1 || results[0].ID != o.Field1.Id || results[0].Locks != 1 {
		t.Fatalf("unlock by phone: %+v %v", results, err)
	}
	if locked, _ := lockout.Locked(app, o.Field1, defaultIP); locked {
		t.Error("still locked")
	}
}
