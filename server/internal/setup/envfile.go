package setup

import (
	"bufio"
	"errors"
	"fmt"
	"io/fs"
	"os"
	"path/filepath"
	"runtime"
	"slices"
	"strings"
	"time"
)

// EncryptionEnv is the environment variable that holds the 32-character key
// PocketBase uses to encrypt the server settings (SMTP and S3 passwords,
// OAuth2 secrets) inside the database.
const EncryptionEnv = "OBHIJATRA_SETTINGS_KEY"

// EnvFileName is the default name of the secrets file `init` writes.
const EnvFileName = "obhijatra.env"

// DefaultEnvFilePath puts the secrets file next to the data folder, never
// inside it, so a copy of pb_data does not carry the key that unlocks it.
func DefaultEnvFilePath(dataDir string) string {
	if abs, err := filepath.Abs(dataDir); err == nil {
		dataDir = abs
	}
	return filepath.Join(filepath.Dir(filepath.Clean(dataDir)), EnvFileName)
}

// WriteEnvFile creates path with owner-only permissions (0600) holding the
// settings key in the variable name. It never overwrites an existing file.
func WriteEnvFile(path, name, key string, now time.Time) error {
	f, err := os.OpenFile(path, os.O_WRONLY|os.O_CREATE|os.O_EXCL, 0o600)
	if err != nil {
		if errors.Is(err, fs.ErrExist) {
			return fmt.Errorf("the secrets file %s already exists; it was not changed", path)
		}
		return fmt.Errorf("could not create the secrets file %s: %w", path, err)
	}

	// The umask can only remove permissions, but be explicit anyway.
	if runtime.GOOS != "windows" {
		if err := f.Chmod(0o600); err != nil {
			f.Close()
			os.Remove(path)
			return fmt.Errorf("could not restrict the secrets file %s: %w", path, err)
		}
	}

	content := "# Obhijatra server secrets, created by `obhijatra-server init` on " + now.Format("2 January 2006") + ".\n" +
		"# Keep this file private (only the server's user may read it). Do not store it\n" +
		"# inside pb_data, in Git or in the same backup as pb_data: it unlocks the\n" +
		"# encrypted server settings. Record it in the organisation's key inventory.\n" +
		name + "=" + key + "\n"

	if _, err := f.WriteString(content); err != nil {
		f.Close()
		os.Remove(path)
		return fmt.Errorf("could not write the secrets file %s: %w", path, err)
	}
	if err := f.Sync(); err != nil {
		f.Close()
		os.Remove(path)
		return fmt.Errorf("could not write the secrets file %s: %w", path, err)
	}

	return f.Close()
}

// LoadEnvFile reads KEY=VALUE lines from path into the process environment.
// Only variables whose names start with OBHIJATRA_, or are listed in
// alsoAllowed, are read, and a variable already set in the environment (for
// example by systemd) wins. A missing file is not an error: the server may
// not have been set up yet.
//
// On Linux and macOS the file must not be readable by group or others.
func LoadEnvFile(path string, alsoAllowed ...string) (loaded bool, err error) {
	info, err := os.Stat(path)
	if errors.Is(err, fs.ErrNotExist) {
		return false, nil
	}
	if err != nil {
		return false, fmt.Errorf("could not read the secrets file %s: %w", path, err)
	}
	if info.IsDir() {
		return false, fmt.Errorf("the secrets file %s is a folder", path)
	}
	if runtime.GOOS != "windows" && info.Mode().Perm()&0o077 != 0 {
		return false, fmt.Errorf("the secrets file %s can be read by other users of this computer; "+
			"run `chmod 600 %s` and start again", path, path)
	}

	f, err := os.Open(path)
	if err != nil {
		return false, fmt.Errorf("could not read the secrets file %s: %w", path, err)
	}
	defer f.Close()

	scanner := bufio.NewScanner(f)
	line := 0
	for scanner.Scan() {
		line++
		text := strings.TrimSpace(scanner.Text())
		if text == "" || strings.HasPrefix(text, "#") {
			continue
		}
		name, value, ok := strings.Cut(text, "=")
		name = strings.TrimSpace(strings.TrimPrefix(name, "export "))
		if !ok || name == "" {
			return false, fmt.Errorf("the secrets file %s has an unreadable line %d", path, line)
		}
		if !strings.HasPrefix(name, "OBHIJATRA_") && !slices.Contains(alsoAllowed, name) {
			continue
		}
		value = strings.Trim(strings.TrimSpace(value), `"'`)
		if _, set := os.LookupEnv(name); set {
			continue
		}
		if err := os.Setenv(name, value); err != nil {
			return false, err
		}
	}
	if err := scanner.Err(); err != nil {
		return false, fmt.Errorf("could not read the secrets file %s: %w", path, err)
	}

	return true, nil
}
