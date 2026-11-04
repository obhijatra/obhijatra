package api

import (
	"net/http"

	"ganigeorgiev.com/pocketbase/pocketbase/core"

	"github.com/obhijatra/obhijatra/server/internal/schema"
	"github.com/obhijatra/obhijatra/server/internal/version"
)

// MetaResponse is the body of GET /api/obhijatra/v1/meta.
type MetaResponse struct {
	ServerVersion    string `json:"server_version"`
	SchemaVersion    int    `json:"schema_version"`
	APIVersion       string `json:"api_version"`
	MinClientVersion string `json:"min_client_version"`
}

// meta tells an app, before it logs in, whether it can talk to this server.
// It is public and reveals only version numbers.
func meta(e *core.RequestEvent) error {
	resp := MetaResponse{
		ServerVersion:    version.Version,
		APIVersion:       version.APIVersion,
		MinClientVersion: version.MinClientVersion,
	}

	// The stored schema version describes this database; 0 means the server
	// has not been set up with `obhijatra-server init` yet.
	if rec, err := e.App.FindFirstRecordByFilter(schema.Settings, ""); err == nil {
		resp.SchemaVersion = rec.GetInt("schema_version")
	}

	return e.JSON(http.StatusOK, resp)
}
