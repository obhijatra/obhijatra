package api

import (
	"net/http"

	"ganigeorgiev.com/pocketbase/pocketbase/core"
	"ganigeorgiev.com/pocketbase/pocketbase/tools/router"
)

// DeviceEnrolNotReady is the answer of the enrolment placeholder.
const DeviceEnrolNotReady = "Device enrolment is not available yet. It arrives with the device-signing " +
	"part of Obhijatra; until then devices cannot be enrolled on this server."

// enrolDevice is a placeholder for the device-signing milestone. It will
// accept a device's public keys with the organisation's signature over the
// device record, check that signature, and for a device that may act with
// the admin or export scopes require the signatures of two organisation
// admins (docs/decisions/0002-obhijatra-server.md, "Device records").
// Until then it answers 501 Not Implemented to everyone.
func enrolDevice(e *core.RequestEvent) error {
	return router.NewApiError(http.StatusNotImplemented, DeviceEnrolNotReady, nil)
}
