// Package setup holds `obhijatra-server init`, which turns an empty data
// folder into a server with Obhijatra's security baseline switched on, and
// the secrets-file helpers that `serve` uses to find the settings key.
package setup

import (
	"errors"
	"fmt"
	"io"
	"net/mail"
	"net/netip"
	"net/url"
	"os"
	"path/filepath"
	"regexp"
	"runtime"
	"strings"
	"time"

	"ganigeorgiev.com/pocketbase/dbx"
	"ganigeorgiev.com/pocketbase/pocketbase/core"
	"ganigeorgiev.com/pocketbase/pocketbase/tools/security"

	"github.com/obhijatra/obhijatra/server/internal/audit"
	"github.com/obhijatra/obhijatra/server/internal/schema"
	"github.com/obhijatra/obhijatra/server/internal/version"
)

// Baseline values the blueprint requires and init switches on.
const (
	LoginRateLimitRequests = schema.AuthRateLimitRequests // sign-in attempts...
	LoginRateLimitSeconds  = schema.AuthRateLimitSeconds  // ...per this many seconds, per IP address
	LogRetentionDays       = 365
	MinPasswordLength      = 12

	// DefaultAppURL is used when no server address is given.
	DefaultAppURL = "http://localhost:8090"
)

// Options are the answers init needs. Empty fields are asked for
// interactively, unless NonInteractive is set.
type Options struct {
	OrgName string
	Country string // ISO 3166-1 alpha-2, e.g. BD
	AppURL  string // the address people will use to reach the server

	SuperuserEmail    string
	SuperuserPassword string

	AdminName     string
	AdminEmail    string
	AdminPassword string

	SuperuserIPs []string // optional allow-list for superuser access

	// TrustedProxyHeaders name the header(s) a reverse proxy in front of
	// the server puts the client's IP address in, e.g. X-Forwarded-For.
	// Empty: no proxy; the address of the connection is used.
	TrustedProxyHeaders []string
	// TrustedProxyUseLeftmost takes the left-most address in the header
	// instead of the right-most (PocketBase's default).
	TrustedProxyUseLeftmost bool

	EnvFile string // where to write the settings key

	Now func() time.Time
}

// Report is what init did, for the security-posture summary.
type Report struct {
	Date           time.Time
	DataDir        string
	EnvFile        string
	OrgName        string
	Country        string
	AppURL         string
	SuperuserEmail string
	AdminEmail     string
	SuperuserIPs   []string
	AuditEntries   int64
	AuditHead      string

	TrustedProxyHeaders     []string
	TrustedProxyUseLeftmost bool

	// Color prints warnings in red (for a terminal).
	Color bool
}

var countryPattern = regexp.MustCompile(`^[A-Z]{2}$`)

// headerNamePattern is an HTTP header name (an RFC 9110 token).
var headerNamePattern = regexp.MustCompile("^[!#$%&'*+.^_`|~0-9A-Za-z-]{1,100}$")

// IsInitialised reports whether init has already run against app: the
// organisation settings record exists or a real superuser does.
func IsInitialised(app core.App) (bool, error) {
	if app.HasTable(schema.Settings) {
		total, err := app.CountRecords(schema.Settings)
		if err != nil {
			return false, err
		}
		if total > 0 {
			return true, nil
		}
	}

	total, err := app.CountRecords(core.CollectionNameSuperusers,
		dbx.Not(dbx.HashExp{"email": core.DefaultInstallerEmail}))
	if err != nil {
		return false, err
	}
	return total > 0, nil
}

// Validate normalises o and reports every problem at once.
func (o *Options) Validate() error {
	o.OrgName = strings.TrimSpace(o.OrgName)
	o.Country = strings.ToUpper(strings.TrimSpace(o.Country))
	o.AppURL = strings.TrimSpace(o.AppURL)
	if o.AppURL == "" {
		o.AppURL = DefaultAppURL
	}
	o.SuperuserEmail = strings.TrimSpace(o.SuperuserEmail)
	o.AdminEmail = strings.TrimSpace(o.AdminEmail)
	o.AdminName = strings.TrimSpace(o.AdminName)

	var problems []string
	add := func(format string, args ...any) { problems = append(problems, fmt.Sprintf(format, args...)) }

	if o.OrgName == "" || len(o.OrgName) > 200 {
		add("the organisation name is required (at most 200 characters)")
	}
	if !countryPattern.MatchString(o.Country) {
		add("the hosting country must be a two-letter ISO code, for example BD for Bangladesh")
	}
	if u, err := url.Parse(o.AppURL); err != nil || (u.Scheme != "http" && u.Scheme != "https") || u.Host == "" {
		add("the server address must start with https:// or http://, for example https://data.example.org")
	}
	for _, e := range []struct{ label, value string }{
		{"superuser email", o.SuperuserEmail},
		{"organisation admin email", o.AdminEmail},
	} {
		if addr, err := mail.ParseAddress(e.value); err != nil || addr.Address != e.value {
			add("the %s is not a valid email address", e.label)
		}
	}
	for _, p := range []struct{ label, value, email string }{
		{"superuser password", o.SuperuserPassword, o.SuperuserEmail},
		{"organisation admin password", o.AdminPassword, o.AdminEmail},
	} {
		if len([]rune(p.value)) < MinPasswordLength {
			add("the %s must be at least %d characters", p.label, MinPasswordLength)
		} else if len(p.value) > 71 {
			add("the %s must be at most 71 bytes", p.label)
		} else if strings.EqualFold(p.value, p.email) {
			add("the %s must not be the same as the email address", p.label)
		}
	}
	if o.SuperuserPassword != "" && o.SuperuserPassword == o.AdminPassword {
		add("the superuser and organisation admin passwords must be different")
	}
	for _, h := range o.TrustedProxyHeaders {
		if !headerNamePattern.MatchString(h) {
			add("%q is not an HTTP header name (for example X-Forwarded-For)", h)
		}
	}
	if o.TrustedProxyUseLeftmost && len(o.TrustedProxyHeaders) == 0 {
		add("--trusted-proxy-use-left needs --trusted-proxy-header")
	}
	if o.EnvFile == "" {
		add("the secrets file path is missing")
	}

	if len(problems) > 0 {
		return errors.New("init cannot continue:\n  - " + strings.Join(problems, "\n  - "))
	}
	return nil
}

// Run sets up a new server. It refuses to touch a server that is already
// set up. If any step fails, the secrets file it created is removed and the
// database changes are rolled back.
func Run(app core.App, o Options) (*Report, error) {
	if err := o.Validate(); err != nil {
		return nil, err
	}
	now := time.Now
	if o.Now != nil {
		now = o.Now
	}

	envName := app.EncryptionEnv()
	if envName == "" {
		return nil, errors.New("no settings-key variable is configured (--encryptionEnv); cannot encrypt the settings")
	}
	if os.Getenv(envName) != "" {
		return nil, fmt.Errorf("%s is already set in this environment; init creates its own key. "+
			"If this server is already set up there is nothing to do; otherwise unset %s and run init again", envName, envName)
	}
	if _, err := os.Stat(o.EnvFile); err == nil {
		return nil, fmt.Errorf("the secrets file %s already exists, so this server looks set up already; nothing was changed", o.EnvFile)
	}

	if err := app.RunAllMigrations(); err != nil {
		return nil, fmt.Errorf("could not prepare the database: %w", err)
	}

	initialised, err := IsInitialised(app)
	if err != nil {
		return nil, err
	}
	if initialised {
		return nil, errors.New("this server is already set up (it has a superuser or organisation settings); nothing was changed")
	}

	// 1. The settings key, outside pb_data, readable by the owner only.
	key := security.RandomString(32)
	if err := WriteEnvFile(o.EnvFile, envName, key, now()); err != nil {
		return nil, err
	}
	if err := os.Setenv(envName, key); err != nil {
		os.Remove(o.EnvFile)
		return nil, err
	}
	undoKey := func() {
		os.Unsetenv(envName)
		os.Remove(o.EnvFile)
	}

	// 2. Everything else in one transaction, attributed to "init" in the
	// audit chain.
	err = audit.RunAs(app, audit.CLIActor("init"), func(txApp core.App) error {
		return seed(txApp, o)
	})
	if err != nil {
		undoKey()
		return nil, fmt.Errorf("setup failed and was rolled back: %w", err)
	}

	// 3. Keep pb_data private to the server's user.
	if runtime.GOOS != "windows" {
		if err := os.Chmod(app.DataDir(), 0o700); err != nil {
			return nil, fmt.Errorf("the server is set up, but the data folder permissions could not be restricted: %w", err)
		}
	}

	result, err := audit.Verify(app)
	if err != nil {
		return nil, err
	}
	if !result.OK {
		return nil, fmt.Errorf("the audit chain failed verification at entry %d: %s", result.BrokenSeq, result.Problem)
	}

	dataDir := app.DataDir()
	if abs, err := filepath.Abs(dataDir); err == nil {
		dataDir = abs
	}

	return &Report{
		Date:           now(),
		DataDir:        dataDir,
		EnvFile:        o.EnvFile,
		OrgName:        o.OrgName,
		Country:        o.Country,
		AppURL:         o.AppURL,
		SuperuserEmail: o.SuperuserEmail,
		AdminEmail:     o.AdminEmail,
		SuperuserIPs:   o.SuperuserIPs,
		AuditEntries:   result.Entries,
		AuditHead:      result.HeadHash,

		TrustedProxyHeaders:     o.TrustedProxyHeaders,
		TrustedProxyUseLeftmost: o.TrustedProxyUseLeftmost,
	}, nil
}

func seed(txApp core.App, o Options) error {
	// Remove PocketBase's temporary installer superuser, if a plain
	// `serve` ever created one.
	if installer, err := txApp.FindAuthRecordByEmail(core.CollectionNameSuperusers, core.DefaultInstallerEmail); err == nil {
		if err := txApp.Delete(installer); err != nil {
			return fmt.Errorf("remove installer account: %w", err)
		}
	}

	// One superuser, for installation and recovery only.
	superusers, err := txApp.FindCollectionByNameOrId(core.CollectionNameSuperusers)
	if err != nil {
		return err
	}
	su := core.NewRecord(superusers)
	su.SetEmail(o.SuperuserEmail)
	su.SetPassword(o.SuperuserPassword)
	su.SetVerified(true)
	if err := txApp.Save(su); err != nil {
		return fmt.Errorf("create superuser: %w", err)
	}

	// The organisation settings record.
	settingsCol, err := txApp.FindCollectionByNameOrId(schema.Settings)
	if err != nil {
		return err
	}
	settings := core.NewRecord(settingsCol)
	settings.Set("organisation_name", o.OrgName)
	settings.Set("hosting_country", o.Country)
	settings.Set("schema_version", version.SchemaVersion)
	if err := txApp.Save(settings); err != nil {
		return fmt.Errorf("create organisation settings: %w", err)
	}

	// The root of the organisation tree.
	locationsCol, err := txApp.FindCollectionByNameOrId(schema.Locations)
	if err != nil {
		return err
	}
	root := core.NewRecord(locationsCol)
	root.Set("name", o.OrgName)
	if err := txApp.Save(root); err != nil {
		return fmt.Errorf("create organisation root location: %w", err)
	}

	// The first organisation admin, at the root of the tree.
	staffCol, err := txApp.FindCollectionByNameOrId(schema.StaffUsers)
	if err != nil {
		return err
	}
	admin := core.NewRecord(staffCol)
	admin.SetEmail(o.AdminEmail)
	admin.SetPassword(o.AdminPassword)
	admin.SetVerified(true)
	admin.Set("name", o.AdminName)
	admin.Set("role", schema.RoleOrgAdmin)
	admin.Set("location", root.Id)
	admin.Set("active", true)
	if err := txApp.Save(admin); err != nil {
		return fmt.Errorf("create organisation admin: %w", err)
	}

	// The PocketBase settings baseline. Saved while the key is in the
	// environment, so the stored settings are encrypted.
	s := txApp.Settings()
	s.Meta.AppName = truncate(o.OrgName, 255)
	s.Meta.AppURL = o.AppURL
	s.RateLimits.Enabled = true
	s.RateLimits.Rules = withLoginRule(s.RateLimits.Rules)
	s.Logs.MaxDays = LogRetentionDays
	s.Logs.LogAuthId = true
	s.Logs.LogIP = true
	if len(o.SuperuserIPs) > 0 {
		s.SuperuserIPs = o.SuperuserIPs
	}
	if len(o.TrustedProxyHeaders) > 0 {
		s.TrustedProxy.Headers = o.TrustedProxyHeaders
		s.TrustedProxy.UseLeftmostIP = o.TrustedProxyUseLeftmost
	}
	if err := txApp.Save(s); err != nil {
		return fmt.Errorf("save server settings: %w", err)
	}

	return nil
}

// withLoginRule sets the "*:auth" rule (every password, OTP and OAuth2
// login on every auth collection) to the baseline, keeping other rules.
func withLoginRule(rules []core.RateLimitRule) []core.RateLimitRule {
	login := core.RateLimitRule{
		Label:       "*:auth",
		MaxRequests: LoginRateLimitRequests,
		Duration:    LoginRateLimitSeconds,
	}
	out := make([]core.RateLimitRule, 0, len(rules)+1)
	out = append(out, login)
	for _, r := range rules {
		if r.Label != login.Label {
			out = append(out, r)
		}
	}
	return out
}

func truncate(s string, max int) string {
	r := []rune(s)
	if len(r) > max {
		return string(r[:max])
	}
	return s
}

// URLKind classifies the address people use to reach the server.
type URLKind int

const (
	URLHTTPS       URLKind = iota // https://: encrypted
	URLTestingOnly                // http:// on this computer or a private network
	URLInsecure                   // http:// anywhere else
)

// ClassifyAppURL tells whether appURL is https://, a plain http:// address
// on this computer (loopback) or a private network (10.0.0.0/8,
// 172.16.0.0/12, 192.168.0.0/16, fc00::/7, link-local), which is fine for
// testing only, or a plain http:// address anywhere else. A host name
// other than localhost counts as "anywhere else": init does not look it
// up.
func ClassifyAppURL(appURL string) URLKind {
	u, err := url.Parse(appURL)
	if err != nil {
		return URLInsecure
	}
	if strings.EqualFold(u.Scheme, "https") {
		return URLHTTPS
	}
	host := strings.ToLower(strings.TrimSuffix(u.Hostname(), "."))
	if host == "localhost" || strings.HasSuffix(host, ".localhost") {
		return URLTestingOnly
	}
	if ip, err := netip.ParseAddr(host); err == nil {
		ip = ip.Unmap()
		if ip.IsLoopback() || ip.IsPrivate() || ip.IsLinkLocalUnicast() {
			return URLTestingOnly
		}
	}
	return URLInsecure
}

// WritePosture prints the security-posture summary in plain English.
func (r *Report) WritePosture(w io.Writer) {
	on := func(text string, args ...any) { fmt.Fprintf(w, "  [ON]      "+text+"\n", args...) }
	off := func(text string, args ...any) { fmt.Fprintf(w, "  [OFF]     "+text+"\n", args...) }
	later := func(text string, args ...any) { fmt.Fprintf(w, "  [NOT YET] "+text+"\n", args...) }
	testing := func(text string, args ...any) { fmt.Fprintf(w, "  [TESTING ONLY] "+text+"\n", args...) }
	warn := func(text string, args ...any) {
		line := fmt.Sprintf("  [WARNING] "+text, args...)
		if r.Color {
			line = "\x1b[1;31m" + line + "\x1b[0m"
		}
		fmt.Fprintln(w, line)
	}

	fmt.Fprintf(w, "\nObhijatra server is set up for %s (hosting country %s).\n", r.OrgName, r.Country)
	fmt.Fprintf(w, "\nSecurity posture on %s, server version %s:\n", r.Date.Format("2 January 2006"), version.Version)
	switch ClassifyAppURL(r.AppURL) {
	case URLHTTPS:
		on("Web address %s uses HTTPS, so passwords and data are encrypted on the way", r.AppURL)
	case URLTestingOnly:
		testing("Web address %s is plain http:// on this computer or a private network. "+
			"Passwords and data cross that network unencrypted: use it for testing only. "+
			"For real use, set up HTTPS (README.md, \"Run it with HTTPS\")", r.AppURL)
	default:
		warn("Web address %s is not https://. Passwords and personal data would cross the internet "+
			"unencrypted. Set up HTTPS before anyone signs in (README.md, \"Run it with HTTPS\"), then "+
			"change the address in the Dashboard's application settings", r.AppURL)
	}
	if runtime.GOOS == "windows" {
		on("Server settings are encrypted; the key is in %s, outside the data folder", r.EnvFile)
		off("File permissions: on Windows, limit %s and %s to the server's account yourself", r.EnvFile, r.DataDir)
	} else {
		on("Server settings are encrypted; the key is in %s (owner-only), outside the data folder", r.EnvFile)
		on("Data folder %s is readable by this server's user only", r.DataDir)
	}
	on("Sign-in rate limit: %d attempts every %d seconds from one IP address", LoginRateLimitRequests, LoginRateLimitSeconds)
	on("Account lock: %d wrong passwords within %d minutes from one IP address lock the account for that address for %d minutes",
		schema.LockoutMaxFailures, int(schema.LockoutWindow.Minutes()), int(schema.LockoutDuration.Minutes()))
	on("Account-wide limit: %d wrong passwords from all addresses lock an ordinary account everywhere; "+
		"organisation admins and superusers are slowed down instead (up to %d seconds per attempt). "+
		"`obhijatra-server unlock <email>` lifts a lock",
		schema.AccountMaxFailures, int(schema.AccountDelayMax.Seconds()))
	if len(r.TrustedProxyHeaders) > 0 {
		which := "right-most"
		if r.TrustedProxyUseLeftmost {
			which = "left-most (safe only if your proxy replaces this header rather than adding to what the client sent)"
		}
		on("Behind a reverse proxy: each user's IP address is read from the %s header, %s address",
			strings.Join(r.TrustedProxyHeaders, ", "), which)
	} else {
		off("Trusted proxy header. If Caddy, NGINX or another reverse proxy sits in front of this server, " +
			"set its header (init --trusted-proxy-header, or the Dashboard's application settings); " +
			"otherwise everyone seems to come from the proxy's address and shares one sign-in allowance")
	}
	on("Request logs kept %d days, with the user ID of each request", LogRetentionDays)
	on("No public sign-up: an organisation admin creates every account")
	on("Session lengths: field users 24 hours, staff 4 hours, superusers 30 minutes")
	on("Passwords at least %d characters", MinPasswordLength)
	on("Tamper-evident audit chain: %d entries, verified; head %s", r.AuditEntries, r.AuditHead)
	on("SQL console, impersonation and collection emptying are switched off")
	on("One superuser (%s), for installation and recovery only; the server refuses more than %d", r.SuperuserEmail, schema.MaxSuperusers)
	if len(r.SuperuserIPs) > 0 {
		on("Superuser access only from: %s", strings.Join(r.SuperuserIPs, ", "))
		if len(r.TrustedProxyHeaders) == 0 {
			warn("The superuser IP allow-list is set but no trusted proxy header is. Behind a reverse proxy " +
				"every request seems to come from the proxy's address, so the allow-list would let in everyone " +
				"the proxy serves, or no one. If a proxy sits in front of this server, set its header " +
				"(init --trusted-proxy-header, or the Dashboard's application settings)")
		}
	} else {
		off("Superuser IP allow-list (set one with --superuser-ips)")
	}
	later("Device-signed requests, revocable sessions, admin MFA, login alerts to admins")
	later("Recovery cards and key ceremony, off-site audit anchors, encrypted backups")

	fmt.Fprintf(w, "\nOrganisation admin: %s. Sign in to the manager app at %s.\n", r.AdminEmail, r.AppURL)
	fmt.Fprintf(w, "\nNext steps:\n")
	fmt.Fprintf(w, "  1. Copy %s to the place your key inventory names. Without it the server cannot start.\n", r.EnvFile)
	fmt.Fprintf(w, "  2. Write down the audit head above, with today's date, somewhere off this server.\n")
	fmt.Fprintf(w, "  3. Start the server: obhijatra-server serve (see README.md for HTTPS).\n")
}
