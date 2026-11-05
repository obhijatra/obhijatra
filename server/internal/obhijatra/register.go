// Package obhijatra wires Obhijatra's migrations, hooks and routes into a
// PocketBase app. main uses it, and so do the tests, so both run exactly
// the same server.
package obhijatra

import (
	"ganigeorgiev.com/pocketbase/pocketbase/core"

	"github.com/obhijatra/obhijatra/server/internal/api"
	"github.com/obhijatra/obhijatra/server/internal/audit"
	"github.com/obhijatra/obhijatra/server/internal/guards"
	"github.com/obhijatra/obhijatra/server/internal/lockout"
	"github.com/obhijatra/obhijatra/server/internal/signin"

	// Registers the Go migrations with PocketBase.
	_ "github.com/obhijatra/obhijatra/server/internal/migrations"
)

// Register binds the audit chain, the integrity guards, the sign-in
// lockout, Google and SMS-code sign-in and the /api/obhijatra/v1 routes to
// app. Call it once, before the app starts.
func Register(app core.App) {
	audit.Register(app)
	guards.Register(app)
	lockout.Register(app)
	signin.Register(app)
	api.Register(app)
}
