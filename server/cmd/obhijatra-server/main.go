// Command obhijatra-server is the Obhijatra server: PocketBase (vendored)
// plus Obhijatra's migrations, audit chain, integrity guards, routes under
// /api/obhijatra/v1/ and the `init`, `audit verify` and `unlock` commands.
//
// It is built with CGO_ENABLED=0; PocketBase's SQLite driver is pure Go.
package main

import (
	"errors"
	"fmt"
	"os"
	"runtime/debug"
	"strings"

	"ganigeorgiev.com/pocketbase/pocketbase"
	"ganigeorgiev.com/pocketbase/pocketbase/core"
	"ganigeorgiev.com/pocketbase/pocketbase/tools/hook"

	"github.com/obhijatra/obhijatra/server/internal/cli"
	"github.com/obhijatra/obhijatra/server/internal/obhijatra"
	"github.com/obhijatra/obhijatra/server/internal/setup"
	"github.com/obhijatra/obhijatra/server/internal/version"
)

const pocketbaseModule = "ganigeorgiev.com/pocketbase/pocketbase"

func main() {
	pbVersion := moduleVersion(pocketbaseModule)
	pocketbase.Version = pbVersion

	app := pocketbase.NewWithConfig(pocketbase.Config{
		DefaultEncryptionEnv: setup.EncryptionEnv,
	})
	app.RootCmd.Use = "obhijatra-server"
	app.RootCmd.Short = "Obhijatra server"
	app.RootCmd.Version = version.Version + " (PocketBase " + pbVersion + ")"
	if f := app.RootCmd.PersistentFlags().Lookup("encryptionEnv"); f != nil {
		f.Usage = "the environment variable holding the 32-character key that encrypts the server settings"
	}

	// --envFile is parsed early, like PocketBase's own --dir, because the
	// settings key must be in the environment before the database opens.
	var envFileFlag string
	app.RootCmd.PersistentFlags().StringVar(&envFileFlag, "envFile", "",
		"the private file holding the settings key (default: "+setup.EnvFileName+" next to the data folder)")
	_ = app.RootCmd.ParseFlags(os.Args[1:])
	envFile := func() string {
		if envFileFlag != "" {
			return envFileFlag
		}
		return setup.DefaultEnvFilePath(app.DataDir())
	}

	if _, err := setup.LoadEnvFile(envFile(), app.EncryptionEnv()); err != nil {
		fail(err)
	}

	obhijatra.Register(app)

	app.RootCmd.AddCommand(
		setup.NewInitCommand(app, envFile),
		cli.NewAuditCommand(app),
		cli.NewUnlockCommand(app),
	)

	// `serve` refuses to start a server that `init` has not set up, so the
	// security baseline is always on before the first request.
	app.OnServe().Bind(&hook.Handler[*core.ServeEvent]{
		Id:       "obhijatraRequireInit",
		Priority: -2000,
		Func: func(se *core.ServeEvent) error {
			se.InstallerFunc = nil // superusers come from init, never from a browser link

			ok, err := setup.IsInitialised(se.App)
			if err != nil {
				return err
			}
			if !ok {
				return errors.New("this server has not been set up yet. Run `obhijatra-server init` first")
			}
			if os.Getenv(se.App.EncryptionEnv()) == "" {
				return fmt.Errorf("the settings key is missing. Put the file `init` created at %s, "+
					"or point --envFile at it, or set %s", envFile(), se.App.EncryptionEnv())
			}
			return se.Next()
		},
	})

	if err := app.Start(); err != nil {
		if strings.Contains(err.Error(), "missing encryption key") {
			err = fmt.Errorf("%w\nThe server settings are encrypted and the key was not found. "+
				"Expected it in %s (or set %s).", err, envFile(), app.EncryptionEnv())
		}
		fail(err)
	}
}

func fail(err error) {
	fmt.Fprintln(os.Stderr, "Error:", err)
	os.Exit(1)
}

func moduleVersion(path string) string {
	info, ok := debug.ReadBuildInfo()
	if !ok {
		return "unknown"
	}
	for _, dep := range info.Deps {
		if dep.Path == path {
			return dep.Version
		}
	}
	return "unknown"
}
