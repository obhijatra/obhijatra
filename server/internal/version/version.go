// Package version holds the version numbers that obhijatra-server reports
// about itself. Release builds set Version with
//
//	-ldflags "-X github.com/obhijatra/obhijatra/server/internal/version.Version=1.2.3"
package version

// Version is the obhijatra-server release. Overwritten at build time.
var Version = "0.1.0-dev"

const (
	// APIVersion is the version of the routes under /api/obhijatra/v1/.
	// It changes only when a breaking change ships under a new prefix.
	APIVersion = "1"

	// MinClientVersion is the oldest Obhijatra app release this server
	// accepts. Apps older than this must update before they sync.
	MinClientVersion = "0.1.0"

	// SchemaVersion is the database schema version this build's migrations
	// produce. It is stored in the settings record by `init` and bumped by
	// every migration that changes the data model.
	SchemaVersion = 8
)
