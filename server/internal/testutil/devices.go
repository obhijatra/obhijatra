package testutil

import (
	"bytes"
	"crypto/ed25519"
	"crypto/rand"
	"crypto/sha256"
	"encoding/base64"
	"encoding/hex"
	"io"
	"net/http"
	"strconv"
	"strings"
	"sync"
	"testing"
	"time"

	"ganigeorgiev.com/pocketbase/pocketbase/apis"
	"ganigeorgiev.com/pocketbase/pocketbase/core"
	"ganigeorgiev.com/pocketbase/pocketbase/tools/hook"
	"ganigeorgiev.com/pocketbase/pocketbase/tools/router"
	"ganigeorgiev.com/pocketbase/pocketbase/tools/types"

	"github.com/obhijatra/obhijatra/server/internal/devicetrust"
	"github.com/obhijatra/obhijatra/server/internal/schema"
)

// NoAutoSignKey, set to true in an app's store, stops the test helper from
// signing requests, for tests of device trust itself.
const NoAutoSignKey = "testutil.noAutoSign"

// TestDevice is a device made for a test, with its private signing key.
type TestDevice struct {
	ID     string
	Key    ed25519.PrivateKey
	EncKey []byte
	Record *core.Record
}

var devicesMu sync.Mutex

func devicesOf(app core.App) map[string]*TestDevice {
	m, _ := app.Store().GetOrSet("testutil.devices", func() any { return map[string]*TestDevice{} }).(map[string]*TestDevice)
	return m
}

// NewKeys makes a signing key and a stand-in encryption public key.
func NewKeys() (ed25519.PrivateKey, []byte) {
	_, priv, _ := ed25519.GenerateKey(rand.Reader)
	enc := make([]byte, 32)
	_, _ = rand.Read(enc)
	return priv, enc
}

// Device returns an approved device of person, made on first use.
func Device(t testing.TB, app core.App, person *core.Record) *TestDevice {
	t.Helper()
	d, err := deviceFor(app, person)
	if err != nil {
		t.Fatal(err)
	}
	return d
}

func deviceFor(app core.App, person *core.Record) (*TestDevice, error) {
	devicesMu.Lock()
	defer devicesMu.Unlock()
	m := devicesOf(app)
	if d, ok := m[person.Id]; ok {
		return d, nil
	}
	priv, enc := NewKeys()
	col, err := app.FindCollectionByNameOrId(schema.Devices)
	if err != nil {
		return nil, err
	}
	r := core.NewRecord(col)
	owner := "staff_user"
	if person.Collection().Name == schema.FieldUsers {
		owner = "field_user"
	}
	r.Set(owner, person.Id)
	r.Set("label", "Test device")
	r.Set("platform", "android")
	r.Set("sign_public_key", base64.StdEncoding.EncodeToString(priv.Public().(ed25519.PublicKey)))
	r.Set("enc_public_key", base64.StdEncoding.EncodeToString(enc))
	r.Set("status", schema.DeviceActive)
	r.Set("attestation_level", schema.AttestationNone)
	r.Set("approved_at", types.NowDateTime())
	exp, _ := types.ParseDateTime(time.Now().Add(schema.DeviceLifetime))
	r.Set("expires", exp)
	if err := app.Save(r); err != nil {
		return nil, err
	}
	d := &TestDevice{ID: r.Id, Key: priv, EncKey: enc, Record: r}
	m[person.Id] = d
	return d, nil
}

// Prime makes person's approved test device and the session for token
// before a test starts counting writes.
func Prime(t testing.TB, app core.App, person *core.Record, token string) {
	t.Helper()
	d := Device(t, app, person)
	if err := EnsureSession(app, token, person, d.ID); err != nil {
		t.Fatal(err)
	}
}

// TokenHash is the session-table hash of a token.
func TokenHash(token string) string {
	sum := sha256.Sum256([]byte(token))
	return hex.EncodeToString(sum[:])
}

// EnsureSession writes the session row for token, as a sign-in would,
// tied to deviceID, unless one exists.
func EnsureSession(app core.App, token string, person *core.Record, deviceID string) error {
	devicesMu.Lock()
	defer devicesMu.Unlock()
	if _, err := app.FindFirstRecordByData(schema.Sessions, "token_hash", TokenHash(token)); err == nil {
		return nil
	}
	col, err := app.FindCollectionByNameOrId(schema.Sessions)
	if err != nil {
		return err
	}
	s := core.NewRecord(col)
	if person.Collection().Name == schema.FieldUsers {
		s.Set("field_user", person.Id)
	} else {
		s.Set("staff_user", person.Id)
	}
	s.Set("device", deviceID)
	s.Set("token_hash", TokenHash(token))
	s.Set("issued", types.NowDateTime())
	return app.Save(s)
}

// Sign adds device-signature headers for deviceID (or "enrol") to r,
// whose body is body.
func Sign(r *http.Request, deviceID string, key ed25519.PrivateKey, body []byte) {
	nonce := make([]byte, 16)
	_, _ = rand.Read(nonce)
	n := base64.RawURLEncoding.EncodeToString(nonce)
	unix := strconv.FormatInt(time.Now().Unix(), 10)
	target := r.URL.RequestURI()
	if r.RequestURI != "" {
		target = r.RequestURI
	}
	msg := devicetrust.Message(r.Method, target, unix, n, body)
	r.Header.Set(devicetrust.HeaderDevice, deviceID)
	r.Header.Set(devicetrust.HeaderTime, unix)
	r.Header.Set(devicetrust.HeaderNonce, n)
	r.Header.Set(devicetrust.HeaderSignature, base64.RawURLEncoding.EncodeToString(ed25519.Sign(key, msg)))
}

// autoSign plays an approved device for every signed-in request, and every
// file download with a person's file token, that does not carry device
// headers, so tests written before device trust keep
// testing what they were written for. Tests of device trust switch it off
// with NoAutoSignKey.
func autoSign() *hook.Handler[*core.RequestEvent] {
	return &hook.Handler[*core.RequestEvent]{
		Id:       "obhijatraTestAutoSign",
		Priority: apis.DefaultLoadAuthTokenMiddlewarePriority + 104, // just before the device gate
		Func: func(e *core.RequestEvent) error {
			if off, _ := e.App.Store().Get(NoAutoSignKey).(bool); off ||
				e.Request.Header.Get(devicetrust.HeaderDevice) != "" {
				return e.Next()
			}
			if e.Auth == nil {
				// A file download with a person's file token.
				token := e.Request.URL.Query().Get("token")
				if !strings.HasPrefix(e.Request.URL.Path, "/api/files/") || token == "" {
					return e.Next()
				}
				person, err := e.App.FindAuthRecordByToken(token, core.TokenTypeFile)
				if err != nil || (person.Collection().Name != schema.FieldUsers && person.Collection().Name != schema.StaffUsers) {
					return e.Next()
				}
				d, err := deviceFor(e.App, person)
				if err != nil {
					return err
				}
				Sign(e.Request, d.ID, d.Key, nil)
				return e.Next()
			}
			name := e.Auth.Collection().Name
			if name != schema.FieldUsers && name != schema.StaffUsers {
				return e.Next()
			}
			d, err := deviceFor(e.App, e.Auth)
			if err != nil {
				return err
			}
			token := strings.TrimSpace(strings.TrimPrefix(e.Request.Header.Get("Authorization"), "Bearer "))
			if err := EnsureSession(e.App, token, e.Auth, d.ID); err != nil {
				return err
			}
			var body []byte
			if e.Request.Body != nil {
				body, _ = io.ReadAll(e.Request.Body)
				if rr, ok := e.Request.Body.(router.Rereader); ok {
					rr.Reread()
				} else {
					e.Request.Body = &router.RereadableReadCloser{ReadCloser: io.NopCloser(bytes.NewReader(body))}
				}
			}
			Sign(e.Request, d.ID, d.Key, body)
			return e.Next()
		},
	}
}
