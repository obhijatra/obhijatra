package setup_test

import (
	"bytes"
	"encoding/json"
	"fmt"
	"net/http"
	"os"
	"path/filepath"
	"runtime"
	"slices"
	"strings"
	"testing"
	"time"

	"ganigeorgiev.com/pocketbase/pocketbase/core"
	"ganigeorgiev.com/pocketbase/pocketbase/tests"
	"ganigeorgiev.com/pocketbase/pocketbase/tools/types"

	"github.com/obhijatra/obhijatra/server/internal/audit"
	"github.com/obhijatra/obhijatra/server/internal/obhijatra"
	"github.com/obhijatra/obhijatra/server/internal/schema"
	"github.com/obhijatra/obhijatra/server/internal/setup"
	"github.com/obhijatra/obhijatra/server/internal/testutil"
	"github.com/obhijatra/obhijatra/server/internal/version"
)

const (
	suPassword    = "superuser-password-1"
	adminPassword = "org-admin-password-1"
)

// newFreshApp opens a brand-new pb_data with the same settings-key variable
// the real binary uses.
func newFreshApp(t *testing.T) *tests.TestApp {
	t.Helper()

	// Ensure the variable is unset for the test and restored afterwards.
	t.Setenv(setup.EncryptionEnv, "")
	os.Unsetenv(setup.EncryptionEnv)

	app, err := tests.NewTestAppWithConfig(core.BaseAppConfig{
		DataDir:       t.TempDir(),
		EncryptionEnv: setup.EncryptionEnv,
	})
	if err != nil {
		t.Fatal(err)
	}
	obhijatra.Register(app)
	return app
}

func options(envFile string) setup.Options {
	return setup.Options{
		OrgName:           "Test NGO",
		Country:           "bd",
		AppURL:            "https://data.example.org",
		SuperuserEmail:    "su@example.org",
		SuperuserPassword: suPassword,
		AdminName:         "Asha",
		AdminEmail:        "admin@example.org",
		AdminPassword:     adminPassword,
		EnvFile:           envFile,
	}
}

func TestInitSetsUpTheSecurityBaseline(t *testing.T) {
	app := newFreshApp(t)
	defer app.Cleanup()

	envFile := filepath.Join(t.TempDir(), setup.EnvFileName)
	report, err := setup.Run(app, options(envFile))
	if err != nil {
		t.Fatalf("init failed: %v", err)
	}

	// The key file: owner-only, holding the key now in use.
	info, err := os.Stat(envFile)
	if err != nil {
		t.Fatalf("env file not created: %v", err)
	}
	if runtime.GOOS != "windows" && info.Mode().Perm() != 0o600 {
		t.Errorf("env file permissions %o, want 600", info.Mode().Perm())
	}
	content, _ := os.ReadFile(envFile)
	key := os.Getenv(setup.EncryptionEnv)
	if len(key) != 32 || !strings.Contains(string(content), setup.EncryptionEnv+"="+key+"\n") {
		t.Errorf("env file does not hold the 32-character key in use")
	}

	// The settings are stored encrypted, not as readable JSON.
	var stored string
	if err := app.DB().NewQuery("SELECT value FROM _params WHERE id = 'settings'").Row(&stored); err != nil {
		t.Fatal(err)
	}
	if strings.HasPrefix(strings.TrimSpace(stored), "{") || strings.Contains(stored, "rateLimits") {
		t.Error("server settings are stored unencrypted")
	}

	// The rate limiter and logs baseline.
	s := app.Settings()
	if !s.RateLimits.Enabled {
		t.Error("rate limiter is not enabled")
	}
	rule, ok := s.RateLimits.FindRateLimitRule([]string{"*:auth"})
	if !ok || rule.MaxRequests != 30 || rule.Duration != 60 {
		t.Errorf("sign-in rate limit rule = %+v, want 30 per 60 s", rule)
	}
	if s.Logs.MaxDays != 365 || !s.Logs.LogAuthId {
		t.Errorf("logs: %d days, auth id %v; want 365 days with auth id", s.Logs.MaxDays, s.Logs.LogAuthId)
	}

	// One superuser, the settings record, the first org admin at the root.
	if n, _ := app.CountRecords(core.CollectionNameSuperusers); n != 1 {
		t.Errorf("%d superusers, want 1", n)
	}
	settings, err := app.FindFirstRecordByFilter(schema.Settings, "")
	if err != nil {
		t.Fatal(err)
	}
	if settings.GetString("organisation_name") != "Test NGO" || settings.GetString("hosting_country") != "BD" || settings.GetInt("schema_version") != version.SchemaVersion {
		t.Errorf("settings record wrong: %q %q %d", settings.GetString("organisation_name"), settings.GetString("hosting_country"), settings.GetInt("schema_version"))
	}
	admin, err := app.FindAuthRecordByEmail(schema.StaffUsers, "admin@example.org")
	if err != nil {
		t.Fatal(err)
	}
	if admin.GetString("role") != schema.RoleOrgAdmin || !admin.GetBool("active") || !admin.ValidatePassword(adminPassword) {
		t.Errorf("org admin wrong: role %q active %v", admin.GetString("role"), admin.GetBool("active"))
	}
	if !schema.LocationPathRegex.MatchString(admin.GetString("location_path")) {
		t.Errorf("org admin location_path %q", admin.GetString("location_path"))
	}
	if report.AuditEntries == 0 || len(report.AuditHead) != 64 {
		t.Errorf("report should include a verified audit chain: %+v", report)
	}

	// Running init again changes nothing.
	if _, err := setup.Run(app, options(envFile)); err == nil {
		t.Error("a second init must be refused")
	}
	os.Remove(envFile)
	os.Unsetenv(setup.EncryptionEnv)
	if _, err := setup.Run(app, options(envFile)); err == nil || !strings.Contains(err.Error(), "already set up") {
		t.Errorf("init on a set-up database must be refused, got %v", err)
	}
	if _, err := os.Stat(envFile); err == nil {
		t.Error("a refused init must not leave a new key file behind")
	}
}

// A branch office of 30 staff behind one internet connection can all sign
// in within the same minute; the 31st attempt from that address in the
// minute is refused with 429 until the minute is over.
func TestInitSignInRateLimitFitsABranchOffice(t *testing.T) {
	app := newFreshApp(t)
	defer app.Cleanup()

	if _, err := setup.Run(app, options(filepath.Join(t.TempDir(), setup.EnvFileName))); err != nil {
		t.Fatal(err)
	}
	root, err := app.FindFirstRecordByFilter(schema.Locations, "parent = ''")
	if err != nil {
		t.Fatal(err)
	}

	type login struct{ email, password string }
	logins := []login{{"admin@example.org", adminPassword}}
	for i := 2; i <= setup.LoginRateLimitRequests; i++ {
		email := fmt.Sprintf("staff%02d@example.org", i)
		testutil.User(t, app, schema.StaffUsers, email, schema.RoleSupervisor, root, true)
		logins = append(logins, login{email, testutil.Password})
	}

	signIn := func(name string, l login, status int, content string) {
		body, _ := json.Marshal(map[string]string{"identity": l.email, "password": l.password})
		(&tests.ApiScenario{
			Name: name, Method: http.MethodPost, URL: "/api/collections/staff_users/auth-with-password",
			Body: bytes.NewReader(body), ExpectedStatus: status, ExpectedContent: []string{content},
			TestAppFactory: func(testing.TB) *tests.TestApp { return app }, DisableTestAppCleanup: true,
		}).Test(t)
	}

	// The limiter's window is 60 s from the first attempt; 31 sign-ins
	// take a few seconds even on a slow machine.
	start := time.Now()
	for i, l := range logins {
		signIn(fmt.Sprintf("staff member %d of %d signs in", i+1, len(logins)), l, 200, `"token":`)
	}
	if elapsed := time.Since(start); elapsed > 50*time.Second {
		t.Fatalf("30 sign-ins took %s; this machine is too slow to test a 60-second window", elapsed)
	}
	signIn("the 31st attempt within the minute is rate limited", logins[0], 429, `"status":429`)
}

// A server set up before schema version 2 had the first baseline: 2
// sign-ins per 3 s per IP. Upgrading widens it, unless the organisation
// changed the rule itself, and records the new schema version. Before
// schema version 3 every active user read every location; upgrading limits
// field users to their own part of the tree. Schema version 4 counts wrong
// passwords per IP address and lets the audit chain record refusals.
func TestUpgradeWidensTheOldSignInRateLimit(t *testing.T) {
	for _, c := range []struct {
		name         string
		requests     int
		seconds      int64
		wantRequests int
		wantSeconds  int64
	}{
		{"first baseline is widened", 2, 3, setup.LoginRateLimitRequests, setup.LoginRateLimitSeconds},
		{"an organisation's own rule is kept", 5, 10, 5, 10},
	} {
		t.Run(c.name, func(t *testing.T) {
			app := newFreshApp(t)
			defer app.Cleanup()
			if _, err := setup.Run(app, options(filepath.Join(t.TempDir(), setup.EnvFileName))); err != nil {
				t.Fatal(err)
			}

			// Wind the server back to before the migration.
			s, _ := app.Settings().Clone()
			for i := range s.RateLimits.Rules {
				if s.RateLimits.Rules[i].Label == "*:auth" {
					s.RateLimits.Rules[i].MaxRequests, s.RateLimits.Rules[i].Duration = c.requests, c.seconds
				}
			}
			if err := app.Save(s); err != nil {
				t.Fatal(err)
			}
			settings, _ := app.FindFirstRecordByFilter(schema.Settings, "")
			settings.Set("schema_version", 1)
			if err := app.Save(settings); err != nil {
				t.Fatal(err)
			}
			locations, _ := app.FindCollectionByNameOrId(schema.Locations)
			locations.ListRule = types.Pointer(schema.AnyActiveUser)
			locations.ViewRule = types.Pointer(schema.AnyActiveUser)
			if err := app.Save(locations); err != nil {
				t.Fatal(err)
			}
			windBackSchemaVersion4(t, app)
			if _, err := app.DB().NewQuery("DELETE FROM _migrations WHERE file LIKE '1793822400_%' OR file LIKE '1793826000_%' OR file LIKE '1793829600_%'").Execute(); err != nil {
				t.Fatal(err)
			}

			if err := app.RunAllMigrations(); err != nil {
				t.Fatalf("upgrade: %v", err)
			}
			checkSchemaVersion4(t, app)

			rule, ok := app.Settings().RateLimits.FindRateLimitRule([]string{"*:auth"})
			if !ok || rule.MaxRequests != c.wantRequests || rule.Duration != c.wantSeconds {
				t.Errorf("after the upgrade the rule is %+v, want %d per %d s", rule, c.wantRequests, c.wantSeconds)
			}
			locations, _ = app.FindCollectionByNameOrId(schema.Locations)
			if *locations.ListRule != schema.LocationsRead || *locations.ViewRule != schema.LocationsRead {
				t.Errorf("after the upgrade the location rules are %q / %q", *locations.ListRule, *locations.ViewRule)
			}
			settings, _ = app.FindFirstRecordByFilter(schema.Settings, "")
			if settings.GetInt("schema_version") != version.SchemaVersion {
				t.Errorf("schema_version %d after the upgrade, want %d", settings.GetInt("schema_version"), version.SchemaVersion)
			}
			if r, err := audit.Verify(app); err != nil || !r.OK {
				t.Errorf("audit chain after the upgrade: %+v %v", r, err)
			}
		})
	}
}

// windBackSchemaVersion4 undoes schema version 4: no ip column in the
// wrong-password counter (with one failure counted before the upgrade), no
// ip field on login_locks, no "refuse" audit action.
func windBackSchemaVersion4(t *testing.T, app core.App) {
	t.Helper()
	for _, q := range []string{
		"DROP INDEX IF EXISTS idx_obhijatra_login_failures_account_ip",
		"ALTER TABLE " + schema.LoginFailuresTable + " DROP COLUMN ip",
		"INSERT INTO " + schema.LoginFailuresTable + " (account_collection, account_id, at) VALUES ('staff_users', 'x', 1)",
	} {
		if _, err := app.DB().NewQuery(q).Execute(); err != nil {
			t.Fatalf("%s: %v", q, err)
		}
	}
	locks, _ := app.FindCollectionByNameOrId(schema.LoginLocks)
	locks.Fields.RemoveByName("ip")
	if err := app.Save(locks); err != nil {
		t.Fatal(err)
	}
	auditCol, _ := app.FindCollectionByNameOrId(schema.Audit)
	action := auditCol.Fields.GetByName("action").(*core.SelectField)
	action.Values = []string{audit.ActionCreate, audit.ActionUpdate, audit.ActionDelete}
	if err := app.Save(auditCol); err != nil {
		t.Fatal(err)
	}
}

func checkSchemaVersion4(t *testing.T, app core.App) {
	t.Helper()
	columns, err := app.TableColumns(schema.LoginFailuresTable)
	if err != nil || !slices.Contains(columns, "ip") {
		t.Errorf("after the upgrade the failure counter has columns %v (%v), want ip", columns, err)
	}
	var ip string
	if err := app.DB().NewQuery("SELECT ip FROM " + schema.LoginFailuresTable + " WHERE account_id = 'x'").Row(&ip); err != nil || ip != "" {
		t.Errorf("a failure counted before the upgrade should be kept with no address: %q %v", ip, err)
	}
	locks, _ := app.FindCollectionByNameOrId(schema.LoginLocks)
	if locks.Fields.GetByName("ip") == nil {
		t.Error("after the upgrade login_locks has no ip field")
	}
	auditCol, _ := app.FindCollectionByNameOrId(schema.Audit)
	if values := auditCol.Fields.GetByName("action").(*core.SelectField).Values; !slices.Contains(values, audit.ActionRefuse) {
		t.Errorf("after the upgrade the audit actions are %v, want %q among them", values, audit.ActionRefuse)
	}
}

func TestInitRejectsWeakInput(t *testing.T) {
	app := newFreshApp(t)
	defer app.Cleanup()

	envFile := filepath.Join(t.TempDir(), setup.EnvFileName)
	o := options(envFile)
	o.Country = "Bangladesh"
	o.AdminPassword = "short"
	o.SuperuserEmail = "not-an-email"

	_, err := setup.Run(app, o)
	if err == nil {
		t.Fatal("weak input must be refused")
	}
	for _, want := range []string{"two-letter", "at least 12", "superuser email"} {
		if !strings.Contains(err.Error(), want) {
			t.Errorf("error should mention %q: %v", want, err)
		}
	}
	if _, err := os.Stat(envFile); err == nil {
		t.Error("refused input must not create a key file")
	}
}

func TestLoadEnvFileRefusesSharedFile(t *testing.T) {
	if runtime.GOOS == "windows" {
		t.Skip("POSIX permissions only")
	}
	path := filepath.Join(t.TempDir(), setup.EnvFileName)
	if err := os.WriteFile(path, []byte("OBHIJATRA_TEST_ONLY=1\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	if _, err := setup.LoadEnvFile(path); err == nil || !strings.Contains(err.Error(), "chmod 600") {
		t.Errorf("a world-readable key file must be refused, got %v", err)
	}
}

// init --trusted-proxy-header and --trusted-proxy-use-left set PocketBase's
// trusted-proxy settings, and the posture report says so.
func TestInitCommandSetsTheTrustedProxy(t *testing.T) {
	app := newFreshApp(t)
	defer app.Cleanup()
	t.Setenv(setup.SuperuserPasswordEnv, suPassword)
	t.Setenv(setup.AdminPasswordEnv, adminPassword)

	envFile := filepath.Join(t.TempDir(), setup.EnvFileName)
	cmd := setup.NewInitCommand(app, func() string { return envFile })
	var out bytes.Buffer
	cmd.SetOut(&out)
	cmd.SetArgs([]string{
		"--non-interactive", "--org-name", "Test NGO", "--country", "BD", "--url", "https://data.example.org",
		"--superuser-email", "su@example.org", "--admin-name", "Asha", "--admin-email", "admin@example.org",
		"--superuser-ips", "203.0.113.7",
		"--trusted-proxy-header", "X-Forwarded-For", "--trusted-proxy-use-left",
	})
	if err := cmd.Execute(); err != nil {
		t.Fatalf("init: %v\n%s", err, out.String())
	}

	tp := app.Settings().TrustedProxy
	if !slices.Equal(tp.Headers, []string{"X-Forwarded-For"}) || !tp.UseLeftmostIP {
		t.Errorf("trusted proxy settings %+v, want X-Forwarded-For, left-most", tp)
	}
	posture := out.String()
	for _, want := range []string{
		"[ON]      Behind a reverse proxy: each user's IP address is read from the X-Forwarded-For header, left-most",
		"[ON]      Web address https://data.example.org uses HTTPS",
		"[ON]      Superuser access only from: 203.0.113.7",
	} {
		if !strings.Contains(posture, want) {
			t.Errorf("posture report lacks %q:\n%s", want, posture)
		}
	}
	if strings.Contains(posture, "[WARNING]") || strings.Contains(posture, "\x1b[") {
		t.Errorf("no warning expected (and no colour when not a terminal):\n%s", posture)
	}
}

func TestInitRejectsABadTrustedProxyHeader(t *testing.T) {
	for name, c := range map[string]struct {
		headers []string
		left    bool
		want    string
	}{
		"not a header name":        {[]string{"X Forwarded For"}, false, "is not an HTTP header name"},
		"left-most with no header": {nil, true, "--trusted-proxy-use-left needs --trusted-proxy-header"},
	} {
		t.Run(name, func(t *testing.T) {
			o := options(filepath.Join(t.TempDir(), setup.EnvFileName))
			o.TrustedProxyHeaders, o.TrustedProxyUseLeftmost = c.headers, c.left
			if err := o.Validate(); err == nil || !strings.Contains(err.Error(), c.want) {
				t.Errorf("got %v, want an error mentioning %q", err, c.want)
			}
		})
	}
}

// A superuser IP allow-list without a trusted proxy header admits everyone
// behind a proxy (or no one): the posture report warns, in red on a
// terminal.
func TestPostureWarnsAboutAnAllowListWithoutAProxyHeader(t *testing.T) {
	report := func(headers ...string) *setup.Report {
		return &setup.Report{
			Date: time.Date(2026, 11, 4, 0, 0, 0, 0, time.UTC), OrgName: "Test NGO", Country: "BD",
			AppURL: "https://data.example.org", SuperuserIPs: []string{"203.0.113.7"}, TrustedProxyHeaders: headers,
		}
	}
	const warning = "[WARNING] The superuser IP allow-list is set but no trusted proxy header is"

	var plain, red, withProxy bytes.Buffer
	report().WritePosture(&plain)
	r := report()
	r.Color = true
	r.WritePosture(&red)
	report("X-Forwarded-For").WritePosture(&withProxy)

	if !strings.Contains(plain.String(), "  "+warning) || strings.Contains(plain.String(), "\x1b[") {
		t.Errorf("plain report should warn without colour:\n%s", plain.String())
	}
	if !strings.Contains(red.String(), "\x1b[1;31m  "+warning) {
		t.Errorf("terminal report should warn in red:\n%q", red.String())
	}
	if strings.Contains(withProxy.String(), warning) {
		t.Errorf("no warning expected with a trusted proxy header:\n%s", withProxy.String())
	}
}

// A public address that is not https:// gets a red warning; plain http on
// this computer or a private network is flagged "testing only".
func TestPostureChecksTheWebAddressForHTTPS(t *testing.T) {
	for url, want := range map[string]setup.URLKind{
		"https://data.example.org":     setup.URLHTTPS,
		"HTTPS://203.0.113.5:8443/":    setup.URLHTTPS,
		"http://localhost:8090":        setup.URLTestingOnly,
		"http://app.localhost":         setup.URLTestingOnly,
		"http://127.0.0.1:8090":        setup.URLTestingOnly,
		"http://[::1]:8090":            setup.URLTestingOnly,
		"http://10.1.2.3":              setup.URLTestingOnly,
		"http://172.16.0.5":            setup.URLTestingOnly,
		"http://172.31.255.254":        setup.URLTestingOnly,
		"http://192.168.1.10:8090":     setup.URLTestingOnly,
		"http://169.254.10.1":          setup.URLTestingOnly,
		"http://[fd12:3456::1]:8090":   setup.URLTestingOnly,
		"http://[::ffff:192.168.0.2]/": setup.URLTestingOnly,
		"http://data.example.org":      setup.URLInsecure,
		"http://203.0.113.5":           setup.URLInsecure,
		"http://172.32.0.1":            setup.URLInsecure,
		"http://100.64.0.1":            setup.URLInsecure,
		"http://[2001:db8::1]":         setup.URLInsecure,
		"http://server.lan":            setup.URLInsecure,
	} {
		if got := setup.ClassifyAppURL(url); got != want {
			t.Errorf("ClassifyAppURL(%q) = %d, want %d", url, got, want)
		}
	}

	posture := func(url string, color bool) string {
		var b bytes.Buffer
		(&setup.Report{Date: time.Now(), AppURL: url, Color: color}).WritePosture(&b)
		return b.String()
	}
	const insecure = "[WARNING] Web address http://data.example.org is not https://"
	if got := posture("http://data.example.org", true); !strings.Contains(got, "\x1b[1;31m  "+insecure) {
		t.Errorf("a public http address needs a red warning:\n%q", got)
	}
	if got := posture("http://data.example.org", false); !strings.Contains(got, "  "+insecure) {
		t.Errorf("a public http address needs a warning:\n%s", got)
	}
	got := posture("http://192.168.1.10:8090", true)
	if !strings.Contains(got, "[TESTING ONLY] Web address http://192.168.1.10:8090 is plain http://") ||
		strings.Contains(got, "is not https://") {
		t.Errorf("a private-network http address is for testing only, without the red warning:\n%s", got)
	}
}
