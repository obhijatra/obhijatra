package api

import (
	"net/http"
	"path"
	"slices"
	"strings"

	validation "ganigeorgiev.com/pocketbase/ozzo-validation/v4"
	"ganigeorgiev.com/pocketbase/pocketbase/apis"
	"ganigeorgiev.com/pocketbase/pocketbase/core"
	"ganigeorgiev.com/pocketbase/pocketbase/tools/hook"
	"ganigeorgiev.com/pocketbase/pocketbase/tools/router"

	"github.com/obhijatra/obhijatra/server/internal/schema"
)

// Answer to a person who must choose a new password first. The reason
// code lets the apps open their "choose a new password" screen.
const (
	PasswordChangeRequiredMessage = "Choose a new password before you continue."
	ReasonPasswordChangeRequired  = "password_change_required"
)

// passwordFields are the only fields a person with a one-time password may
// send when updating their own account.
var passwordFields = []string{"oldPassword", "password", "passwordConfirm"}

// passwordGate lets a person whose account has a one-time password do only
// what choosing a new one needs: read their own account, change their own
// password, sign in or refresh the session, and the public version and
// sign-in-method checks. Everything else is refused, whatever the API
// rules would allow.
func passwordGate() *hook.Handler[*core.RequestEvent] {
	return &hook.Handler[*core.RequestEvent]{
		Id:       "obhijatraPasswordGate",
		Priority: apis.DefaultLoadAuthTokenMiddlewarePriority + 110, // after the fence
		Func: func(e *core.RequestEvent) error {
			if e.Auth == nil || !e.Auth.GetBool(schema.MustChangePassword) {
				return e.Next()
			}
			allowed, err := mayPassGate(e)
			if err != nil {
				return err
			}
			if !allowed {
				return router.NewApiError(http.StatusForbidden, PasswordChangeRequiredMessage, map[string]validation.Error{
					"reason": validation.NewError(ReasonPasswordChangeRequired, PasswordChangeRequiredMessage),
				})
			}
			return e.Next()
		},
	}
}

func mayPassGate(e *core.RequestEvent) (bool, error) {
	p := path.Clean("/" + e.Request.URL.Path)
	switch p {
	case Prefix + "/meta", Prefix + "/signin/methods":
		return true, nil
	}

	parts := strings.Split(strings.Trim(p, "/"), "/")
	if len(parts) < 4 || parts[0] != "api" || parts[1] != "collections" {
		return false, nil
	}
	c := e.Auth.Collection()
	if parts[2] != c.Name && parts[2] != c.Id {
		return false, nil
	}

	switch {
	case len(parts) == 4 && e.Request.Method == http.MethodPost &&
		(parts[3] == "auth-refresh" || strings.HasPrefix(parts[3], "auth-with-")):
		return true, nil
	case len(parts) == 5 && parts[3] == "records" && parts[4] == e.Auth.Id:
		switch e.Request.Method {
		case http.MethodGet:
			return true, nil
		case http.MethodPatch:
			info, err := e.RequestInfo()
			if err != nil {
				return false, err
			}
			for key := range info.Body {
				if !slices.Contains(passwordFields, key) {
					return false, nil
				}
			}
			return true, nil
		}
	}
	return false, nil
}
