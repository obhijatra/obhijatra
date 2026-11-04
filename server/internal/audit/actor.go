package audit

import (
	"errors"
	"sync"

	"ganigeorgiev.com/pocketbase/dbx"
	"ganigeorgiev.com/pocketbase/pocketbase/core"
)

// DeviceStoreKey is the request-store key under which the device-signature
// middleware (zero-trust milestone) will put the verified device id. The
// audit chain reads the device only from here, never from a request header.
const DeviceStoreKey = "obhijatra.verifiedDeviceId"

// Actor is who caused a write: an authenticated record, a command-line
// action or the server itself.
type Actor struct {
	Collection string // auth collection name, "_cli", "_system" or "_guest"
	ID         string // record id, or the command name for "_cli"
	Role       string // the role field of field_users and staff_users
	Device     string // verified device id, when known
}

// SystemActor is used for writes that no authenticated request or command
// is attributed to: migrations, scheduled jobs, PocketBase's own
// housekeeping and the authentication flows (login, password reset).
var SystemActor = Actor{Collection: "_system", ID: "server"}

// CLIActor attributes writes to an obhijatra-server command.
func CLIActor(command string) Actor {
	return Actor{Collection: "_cli", ID: command}
}

// ActorFromRequest returns the actor of an HTTP request: its authenticated
// record (superuser, staff or field user) or "_guest".
func ActorFromRequest(e *core.RequestEvent) Actor {
	var a Actor
	if e.Auth == nil {
		a = Actor{Collection: "_guest"}
	} else {
		a = Actor{
			Collection: e.Auth.Collection().Name,
			ID:         e.Auth.Id,
			Role:       e.Auth.GetString("role"),
		}
	}
	if device, ok := e.Get(DeviceStoreKey).(string); ok {
		a.Device = device
	}
	return a
}

// The registry maps an open transaction to the actor its writes belong to.
// PocketBase's record API does not pass the request context down to the
// model hooks, but every write inside one transaction goes through the same
// *dbx.Tx, so the transaction itself carries the attribution.
var registry = struct {
	sync.Mutex
	m map[*dbx.Tx]Actor
}{m: map[*dbx.Tx]Actor{}}

func txOf(app core.App) (*dbx.Tx, bool) {
	tx, ok := app.NonconcurrentDB().(*dbx.Tx)
	return tx, ok
}

// ActorOf returns the actor that writes made through txApp are attributed
// to, or SystemActor. Hooks also use it to apply rules that bind superusers.
func ActorOf(txApp core.App) Actor {
	tx, ok := txOf(txApp)
	if !ok {
		return SystemActor
	}

	registry.Lock()
	defer registry.Unlock()

	if a, ok := registry.m[tx]; ok {
		return a
	}
	return SystemActor
}

// RunAs runs fn in a transaction (joining the current one if app is already
// transactional) and attributes every write fn makes to actor.
func RunAs(app core.App, actor Actor, fn func(txApp core.App) error) error {
	return app.RunInTransaction(func(txApp core.App) error {
		tx, ok := txOf(txApp)
		if !ok {
			return errors.New("audit: RunAs expected a database transaction")
		}

		registry.Lock()
		previous, hadPrevious := registry.m[tx]
		registry.m[tx] = actor
		registry.Unlock()

		defer func() {
			registry.Lock()
			if hadPrevious {
				registry.m[tx] = previous
			} else {
				delete(registry.m, tx)
			}
			registry.Unlock()
		}()

		return fn(txApp)
	})
}
