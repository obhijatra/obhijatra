package setup_test

import (
	"net/http"
	"os"
	"path/filepath"
	"runtime"
	"strings"
	"testing"
	"time"

	"ganigeorgiev.com/pocketbase/pocketbase/core"
	"ganigeorgiev.com/pocketbase/pocketbase/tests"

	"github.com/obhijatra/obhijatra/server/internal/obhijatra"
	"github.com/obhijatra/obhijatra/server/internal/schema"
	"github.com/obhijatra/obhijatra/server/internal/setup"
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
	if !ok || rule.MaxRequests != 2 || rule.Duration != 3 {
		t.Errorf("login rate limit rule = %+v, want 2 per 3 s", rule)
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
	if settings.GetString("organisation_name") != "Test NGO" || settings.GetString("hosting_country") != "BD" || settings.GetInt("schema_version") != 1 {
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

func TestInitLoginRateLimitIsEnforced(t *testing.T) {
	app := newFreshApp(t)
	defer app.Cleanup()

	if _, err := setup.Run(app, options(filepath.Join(t.TempDir(), setup.EnvFileName))); err != nil {
		t.Fatal(err)
	}

	login := func(name string, status int) *tests.ApiScenario {
		return &tests.ApiScenario{
			Name:   name,
			Method: http.MethodPost, URL: "/api/collections/staff_users/auth-with-password",
			// No password: refused by validation before any password hashing,
			// so the requests are fast; the rate limiter counts them anyway.
			Body:           strings.NewReader(`{"identity":"admin@example.org"}`),
			ExpectedStatus: status, ExpectedContent: []string{`"status":`},
			TestAppFactory: func(testing.TB) *tests.TestApp { return app }, DisableTestAppCleanup: true,
		}
	}
	start := time.Now()
	login("first login attempt", 400).Test(t)
	login("second login attempt", 400).Test(t)

	// On a very slow machine two requests could outlast the 3-second
	// window; the settings test above still covers the configuration.
	if elapsed := time.Since(start); elapsed > 2*time.Second {
		t.Skipf("two requests took %s, too slow to test a 3-second window here", elapsed)
	}
	login("third login within 3 seconds is rate limited", 429).Test(t)
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
