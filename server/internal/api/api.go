// Package api holds Obhijatra's HTTP routes, all under /api/obhijatra/v1/,
// and the middleware that fences off PocketBase endpoints which would let a
// superuser bypass the audit chain.
package api

import (
	"net/http"
	"path"
	"strings"

	"ganigeorgiev.com/pocketbase/pocketbase/apis"
	"ganigeorgiev.com/pocketbase/pocketbase/core"
	"ganigeorgiev.com/pocketbase/pocketbase/tools/hook"

	"github.com/obhijatra/obhijatra/server/internal/schema"
)

// Prefix is the base path of every Obhijatra route. A version is removed no
// sooner than 24 months after its successor ships (blueprint, Governance).
const Prefix = "/api/obhijatra/v1"

// submissionBodyLimit caps one submission request: the XML instance plus
// its attachments. Larger media will move to one-file-per-request uploads.
const submissionBodyLimit = 128 << 20

// Register binds the routes and the fence to app's router.
func Register(app core.App) {
	app.OnServe().Bind(&hook.Handler[*core.ServeEvent]{
		Id: "obhijatraRoutes",
		Func: func(se *core.ServeEvent) error {
			se.Router.Bind(fence())

			g := se.Router.Group(Prefix)
			g.GET("/meta", meta)
			g.POST("/submissions", submit).Bind(
				apis.RequireAuth(schema.FieldUsers),
				apis.BodyLimit(submissionBodyLimit),
			)
			se.Router.POST(schema.DeviceEnrolPath, enrolDevice)

			return se.Next()
		},
	})
}

// fence blocks three PocketBase superuser endpoints:
//
//   - the SQL console (POST /api/sql), which runs raw SQL and so bypasses
//     every Go hook, including the audit chain and the integrity guards;
//   - impersonation (POST /api/collections/{c}/impersonate/{id}), which the
//     blueprint allows only inside a recorded recovery window (zero-trust
//     milestone);
//   - collection truncation (DELETE /api/collections/{c}/truncate), a bulk
//     delete with no place in production.
func fence() *hook.Handler[*core.RequestEvent] {
	return &hook.Handler[*core.RequestEvent]{
		Id: "obhijatraFence",
		// After the auth token loader, before any route handler.
		Priority: apis.DefaultLoadAuthTokenMiddlewarePriority + 100,
		Func: func(e *core.RequestEvent) error {
			if msg := fencedReason(e.Request.Method, e.Request.URL.Path); msg != "" {
				return e.ForbiddenError(msg, nil)
			}
			return e.Next()
		},
	}
}

func fencedReason(method, urlPath string) string {
	p := path.Clean("/" + urlPath)
	parts := strings.Split(strings.Trim(p, "/"), "/")

	switch {
	case p == "/api/sql":
		return "The SQL console is switched off in Obhijatra because it bypasses the audit chain."
	case method == http.MethodPost && len(parts) == 5 && parts[0] == "api" && parts[1] == "collections" && parts[3] == "impersonate":
		return "Impersonation is switched off in Obhijatra until the recorded recovery window is available."
	case method == http.MethodDelete && len(parts) == 4 && parts[0] == "api" && parts[1] == "collections" && parts[3] == "truncate":
		return "Emptying a whole collection is switched off in Obhijatra."
	}
	return ""
}
