// Package signin adds Google sign-in and SMS-code sign-in to the field and
// staff user collections, next to email and password
// (docs/decisions/0005-sign-in-methods.md):
//
//   - Google sign-in is PocketBase's OAuth2 flow with the organisation's
//     own Google client. A guard lets it reach only an account an org admin
//     created, active, with the same email address, already confirmed;
//     nobody can create an account by signing in with Google.
//   - SMS-code sign-in sends a 6-digit code, valid for 5 minutes and 3
//     tries, through the organisation's own SMS provider, set up by form.
//     It is refused to org admins. Wrong codes count towards the same
//     locks as wrong passwords; sending is limited per number and per
//     address, because every SMS costs the organisation money.
//
// Both are off until an org admin switches them on in the manager app.
package signin

import (
	"database/sql"
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"regexp"
	"strings"
	"time"

	"ganigeorgiev.com/pocketbase/dbx"
	"ganigeorgiev.com/pocketbase/pocketbase/core"
	"ganigeorgiev.com/pocketbase/pocketbase/tools/security"

	"github.com/obhijatra/obhijatra/server/internal/audit"
	"github.com/obhijatra/obhijatra/server/internal/schema"
)

// settingsKey is the one row of schema.SignInSettingsTable in use.
const settingsKey = "settings"

// Stored values start with one of these, so a server that gains a
// settings key later can still read what it stored without one.
const (
	sealedPrefix = "v1:"
	plainPrefix  = "plain:"
)

// Settings are the sign-in settings PocketBase has no place for.
type Settings struct {
	PhoneEnabled bool       `json:"phone_enabled"`
	SMS          SMSGateway `json:"sms"`
}

// PhoneReady reports whether SMS-code sign-in is switched on and has an
// SMS provider to send through.
func (s Settings) PhoneReady() bool {
	return s.PhoneEnabled && s.SMS.URL != ""
}

// Load reads the settings; a server where nobody has saved any yet has
// everything off.
func Load(app core.App) (Settings, error) {
	var row struct {
		Value string `db:"value"`
	}
	err := app.DB().Select("value").From(schema.SignInSettingsTable).
		Where(dbx.HashExp{"key": settingsKey}).One(&row)
	if errors.Is(err, sql.ErrNoRows) {
		return Settings{}, nil
	}
	if err != nil {
		return Settings{}, fmt.Errorf("signin: read settings: %w", err)
	}

	raw, err := open(app, row.Value)
	if err != nil {
		return Settings{}, err
	}
	var s Settings
	if err := json.Unmarshal(raw, &s); err != nil {
		return Settings{}, fmt.Errorf("signin: read settings: %w", err)
	}
	return s, nil
}

func store(txApp core.App, s Settings) error {
	raw, err := json.Marshal(s)
	if err != nil {
		return err
	}
	value, err := seal(txApp, raw)
	if err != nil {
		return err
	}
	_, err = txApp.NonconcurrentDB().NewQuery(
		"INSERT INTO {{" + schema.SignInSettingsTable + "}} ([[key]], [[value]], [[updated]]) " +
			"VALUES ({:key}, {:value}, {:updated}) " +
			"ON CONFLICT ([[key]]) DO UPDATE SET [[value]] = excluded.[[value]], [[updated]] = excluded.[[updated]]",
	).Bind(dbx.Params{"key": settingsKey, "value": value, "updated": time.Now().UnixMilli()}).Execute()
	if err != nil {
		return fmt.Errorf("signin: save settings: %w", err)
	}
	return nil
}

// seal encrypts raw with the server settings key (the one PocketBase uses
// for its own settings), when the server has one; `serve` refuses to start
// without it, so only tests and set-up store plain values.
func seal(app core.App, raw []byte) (string, error) {
	key := settingsKeyOf(app)
	if key == "" {
		return plainPrefix + string(raw), nil
	}
	sealed, err := security.Encrypt(raw, key)
	if err != nil {
		return "", fmt.Errorf("signin: encrypt settings: %w", err)
	}
	return sealedPrefix + sealed, nil
}

func open(app core.App, value string) ([]byte, error) {
	switch {
	case strings.HasPrefix(value, plainPrefix):
		return []byte(strings.TrimPrefix(value, plainPrefix)), nil
	case strings.HasPrefix(value, sealedPrefix):
		key := settingsKeyOf(app)
		if key == "" {
			return nil, errors.New("signin: the sign-in settings are encrypted and the server settings key is missing")
		}
		raw, err := security.Decrypt(strings.TrimPrefix(value, sealedPrefix), key)
		if err != nil {
			return nil, fmt.Errorf("signin: decrypt settings: %w", err)
		}
		return raw, nil
	}
	return nil, errors.New("signin: the stored sign-in settings are in an unknown format")
}

func settingsKeyOf(app core.App) string {
	if env := app.EncryptionEnv(); env != "" {
		return os.Getenv(env)
	}
	return ""
}

// ---------------------------------------------------------------------
// Google sign-in, stored as PocketBase's own OAuth2 provider settings of
// both user collections
// ---------------------------------------------------------------------

// Google describes the organisation's Google sign-in client.
type Google struct {
	Enabled   bool
	ClientID  string
	SecretSet bool
}

// LoadGoogle reads the Google settings (they are the same on both user
// collections).
func LoadGoogle(app core.App) (Google, error) {
	c, err := app.FindCachedCollectionByNameOrId(schema.FieldUsers)
	if err != nil {
		return Google{}, err
	}
	p, ok := c.OAuth2.GetProviderConfig(schema.GoogleProvider)
	return Google{
		Enabled:   c.OAuth2.Enabled && ok && p.ClientId != "" && p.ClientSecret != "",
		ClientID:  p.ClientId,
		SecretSet: p.ClientSecret != "",
	}, nil
}

// googleClientIDPattern is the shape of a Google OAuth client id, for
// example "123456789012-abc123def456.apps.googleusercontent.com".
var googleClientIDPattern = regexp.MustCompile(`^[0-9]+-[A-Za-z0-9_]+\.apps\.googleusercontent\.com$`)

func setGoogle(txApp core.App, enabled bool, clientID, clientSecret string) error {
	for _, name := range []string{schema.FieldUsers, schema.StaffUsers} {
		c, err := txApp.FindCollectionByNameOrId(name)
		if err != nil {
			return err
		}

		cfg, _ := c.OAuth2.GetProviderConfig(schema.GoogleProvider)
		cfg.Name = schema.GoogleProvider
		cfg.ClientId = clientID
		if clientSecret != "" {
			cfg.ClientSecret = clientSecret
		}
		if clientID == "" {
			cfg.ClientSecret = "" // no client, no secret
		}

		providers := make([]core.OAuth2ProviderConfig, 0, len(c.OAuth2.Providers)+1)
		for _, p := range c.OAuth2.Providers {
			if p.Name != schema.GoogleProvider {
				providers = append(providers, p)
			}
		}
		if cfg.ClientId != "" {
			providers = append(providers, cfg)
		}
		c.OAuth2.Providers = providers
		c.OAuth2.Enabled = enabled
		// Nobody is ever created by signing in with Google, so nothing is
		// copied from the Google profile.
		c.OAuth2.MappedFields = core.OAuth2KnownFields{}

		if err := txApp.Save(c); err != nil {
			return fmt.Errorf("save Google sign-in on %s: %w", name, err)
		}
	}
	return nil
}

// ---------------------------------------------------------------------
// What an org admin sees and changes
// ---------------------------------------------------------------------

// View is the answer of GET /signin/settings: everything except the
// secrets, which are only ever reported as set or not set.
type View struct {
	Google GoogleView `json:"google"`
	Phone  PhoneView  `json:"phone"`
}

// GoogleView describes Google sign-in to an org admin.
type GoogleView struct {
	Enabled         bool   `json:"enabled"`
	ClientID        string `json:"client_id"`
	ClientSecretSet bool   `json:"client_secret_set"`
	// RedirectURL is the address to register as an authorised redirect
	// URI in the organisation's Google Cloud client.
	RedirectURL string `json:"redirect_url"`
}

// PhoneView describes SMS-code sign-in to an org admin.
type PhoneView struct {
	Enabled             bool        `json:"enabled"`
	SMS                 SMSView     `json:"sms"`
	LastSend            *SendResult `json:"last_send"`
	CodeLifetimeSeconds int         `json:"code_lifetime_seconds"`
}

// SMSView is an SMSGateway without its secret.
type SMSView struct {
	Method      string   `json:"method"`
	URL         string   `json:"url"`
	ContentType string   `json:"content_type"`
	Body        string   `json:"body"`
	Headers     []Header `json:"headers"`
	SecretSet   bool     `json:"secret_set"`
	SuccessText string   `json:"success_text"`
}

// Update is the body of PUT /signin/settings. An empty secret keeps the
// stored one.
type Update struct {
	Google struct {
		Enabled      bool   `json:"enabled"`
		ClientID     string `json:"client_id"`
		ClientSecret string `json:"client_secret"`
	} `json:"google"`
	Phone struct {
		Enabled bool       `json:"enabled"`
		SMS     SMSGateway `json:"sms"`
	} `json:"phone"`
}

// LoadView builds the View.
func LoadView(app core.App) (View, error) {
	g, err := LoadGoogle(app)
	if err != nil {
		return View{}, err
	}
	s, err := Load(app)
	if err != nil {
		return View{}, err
	}
	headers := s.SMS.Headers
	if headers == nil {
		headers = []Header{}
	}
	return View{
		Google: GoogleView{
			Enabled:         g.Enabled,
			ClientID:        g.ClientID,
			ClientSecretSet: g.SecretSet,
			RedirectURL:     strings.TrimRight(app.Settings().Meta.AppURL, "/") + "/api/oauth2-redirect",
		},
		Phone: PhoneView{
			Enabled: s.PhoneEnabled,
			SMS: SMSView{
				Method:      s.SMS.Method,
				URL:         s.SMS.URL,
				ContentType: s.SMS.ContentType,
				Body:        s.SMS.Body,
				Headers:     headers,
				SecretSet:   s.SMS.Secret != "",
				SuccessText: s.SMS.SuccessText,
			},
			LastSend:            lastSend(app),
			CodeLifetimeSeconds: int(schema.PhoneCodeLifetime.Seconds()),
		},
	}, nil
}

// Apply checks u and saves it as actor, in one transaction with its audit
// entries. A problem with what was submitted is a FieldErrors.
func Apply(app core.App, actor audit.Actor, u Update) error {
	clientID := strings.TrimSpace(u.Google.ClientID)
	clientSecret := strings.TrimSpace(u.Google.ClientSecret)
	errs := FieldErrors{}

	if clientID != "" && (len(clientID) > 200 || !googleClientIDPattern.MatchString(clientID)) {
		errs["google.client_id"] = "This does not look like a Google client ID. It ends with .apps.googleusercontent.com."
	}
	if len(clientSecret) > 200 || strings.ContainsFunc(clientSecret, isSpaceOrControl) {
		errs["google.client_secret"] = "This does not look like a Google client secret."
	}

	return audit.RunAs(app, actor, func(txApp core.App) error {
		current, err := Load(txApp)
		if err != nil {
			return err
		}
		g, err := LoadGoogle(txApp)
		if err != nil {
			return err
		}

		if u.Google.Enabled {
			switch {
			case clientID == "":
				errs["google.client_id"] = "Enter the client ID from your Google Cloud project to switch on Google sign-in."
			case clientSecret == "" && (!g.SecretSet || clientID != g.ClientID):
				errs["google.client_secret"] = "Enter the client secret from your Google Cloud project to switch on Google sign-in."
			}
		}

		sms := u.Phone.SMS.normalised().withStoredSecret(current.SMS)
		if sms.URL != "" || u.Phone.Enabled {
			for field, msg := range sms.Validate() {
				errs["phone.sms."+field] = msg
			}
		}
		if len(errs) > 0 {
			return errs
		}

		if err := setGoogle(txApp, u.Google.Enabled, clientID, clientSecret); err != nil {
			return err
		}
		if err := store(txApp, Settings{PhoneEnabled: u.Phone.Enabled, SMS: sms}); err != nil {
			return err
		}
		return audit.AppendEvent(txApp, actor, audit.ActionUpdate, schema.SignInSettingsTable, settingsKey)
	})
}

// FieldErrors maps a submitted field (dotted path) to a plain-language
// problem with it.
type FieldErrors map[string]string

// add records msg for field unless the field already has a problem.
func (e FieldErrors) add(field, msg string) {
	if _, ok := e[field]; !ok {
		e[field] = msg
	}
}

func (e FieldErrors) Error() string {
	return fmt.Sprintf("%d sign-in setting(s) need attention", len(e))
}

func isSpaceOrControl(r rune) bool {
	return r <= ' ' || r == 0x7f
}
