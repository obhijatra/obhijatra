package signin

import (
	"context"
	"errors"
	"net/http"
	"time"

	validation "ganigeorgiev.com/pocketbase/ozzo-validation/v4"
	"ganigeorgiev.com/pocketbase/pocketbase/apis"
	"ganigeorgiev.com/pocketbase/pocketbase/core"
	"ganigeorgiev.com/pocketbase/pocketbase/tools/hook"
	"ganigeorgiev.com/pocketbase/pocketbase/tools/router"

	"github.com/obhijatra/obhijatra/server/internal/api"
	"github.com/obhijatra/obhijatra/server/internal/audit"
	"github.com/obhijatra/obhijatra/server/internal/schema"
)

// Route paths, under api.Prefix.
const (
	MethodsPath     = "/signin/methods"
	SettingsPath    = "/signin/settings"
	TestSMSPath     = "/signin/test-sms"
	PhoneCodePath   = "/signin/phone/code"
	PhoneVerifyPath = "/signin/phone/verify"
)

// testSMSPerWindow test messages per org admin per schema.PhoneCodeWindow.
const testSMSPerWindow = 10

// Register binds the Google sign-in guard and the sign-in routes to app.
func Register(app core.App) {
	app.OnRecordAuthWithOAuth2Request(schema.FieldUsers, schema.StaffUsers).Bind(&hook.Handler[*core.RecordAuthWithOAuth2RequestEvent]{
		Id:   "obhijatraGuardGoogleSignIn",
		Func: guardGoogle,
	})

	app.OnServe().Bind(&hook.Handler[*core.ServeEvent]{
		Id: "obhijatraSignInRoutes",
		Func: func(se *core.ServeEvent) error {
			g := se.Router.Group(api.Prefix)
			g.GET(MethodsPath, methods)
			g.GET(SettingsPath, getSettings).Bind(apis.RequireAuth(schema.StaffUsers))
			g.PUT(SettingsPath, putSettings).Bind(apis.RequireAuth(schema.StaffUsers), apis.BodyLimit(64<<10))
			g.POST(TestSMSPath, testSMS).Bind(apis.RequireAuth(schema.StaffUsers), apis.BodyLimit(64<<10))
			g.POST(PhoneCodePath, requestCode).Bind(apis.BodyLimit(4 << 10))
			g.POST(PhoneVerifyPath, verifyCode).Bind(apis.BodyLimit(4 << 10))
			return se.Next()
		},
	})
}

// Methods is the answer of GET /signin/methods: which ways to sign in this
// server offers. It is public, like PocketBase's own list of auth methods.
type Methods struct {
	Password bool `json:"password"`
	Google   bool `json:"google"`
	Phone    bool `json:"phone"`
}

func methods(e *core.RequestEvent) error {
	g, err := LoadGoogle(e.App)
	if err != nil {
		return e.InternalServerError("", err)
	}
	s, err := Load(e.App)
	if err != nil {
		return e.InternalServerError("", err)
	}
	return e.JSON(http.StatusOK, Methods{Password: true, Google: g.Enabled, Phone: s.PhoneReady()})
}

// requireOrgAdmin refuses everyone but an active org admin.
func requireOrgAdmin(e *core.RequestEvent) error {
	if e.Auth == nil || e.Auth.Collection().Name != schema.StaffUsers ||
		e.Auth.GetString("role") != schema.RoleOrgAdmin || !e.Auth.GetBool("active") {
		return e.ForbiddenError("Only an organisation admin can change how people sign in.", nil)
	}
	return nil
}

func getSettings(e *core.RequestEvent) error {
	if err := requireOrgAdmin(e); err != nil {
		return err
	}
	v, err := LoadView(e.App)
	if err != nil {
		return e.InternalServerError("", err)
	}
	return e.JSON(http.StatusOK, v)
}

func putSettings(e *core.RequestEvent) error {
	if err := requireOrgAdmin(e); err != nil {
		return err
	}
	var u Update
	if err := e.BindBody(&u); err != nil {
		return e.BadRequestError("The request could not be read.", err)
	}
	if err := Apply(e.App, audit.ActorFromRequest(e), u); err != nil {
		var fe FieldErrors
		if errors.As(err, &fe) {
			return fieldErrors(fe)
		}
		return e.InternalServerError("", err)
	}
	v, err := LoadView(e.App)
	if err != nil {
		return e.InternalServerError("", err)
	}
	return e.JSON(http.StatusOK, v)
}

// testSMS answers POST /signin/test-sms {"phone", "sms"?}: it sends
// TestMessage to phone through the submitted provider settings (an empty
// secret means the stored one), or the stored ones when none are
// submitted, and reports what the provider answered.
func testSMS(e *core.RequestEvent) error {
	if err := requireOrgAdmin(e); err != nil {
		return err
	}
	var body struct {
		Phone string      `json:"phone"`
		SMS   *SMSGateway `json:"sms"`
	}
	if err := e.BindBody(&body); err != nil {
		return e.BadRequestError("The request could not be read.", err)
	}
	phone := NormalisePhone(body.Phone)
	if !schema.PhoneRegex.MatchString(phone) {
		return fieldError("phone", "validation_invalid_phone", InvalidPhoneMessage)
	}

	stored, err := Load(e.App)
	if err != nil {
		return e.InternalServerError("", err)
	}
	gateway := stored.SMS
	if body.SMS != nil {
		gateway = body.SMS.normalised()
		if gateway.Secret == "" {
			gateway.Secret = stored.SMS.Secret
		}
	}
	if errs := gateway.Validate(); len(errs) > 0 {
		prefixed := FieldErrors{}
		for k, v := range errs {
			prefixed["sms."+k] = v
		}
		return fieldErrors(prefixed)
	}

	now := time.Now().UTC()
	ok, err := withinLimits(e.App, now, limit{kindTestSMS, e.Auth.Id, testSMSPerWindow, schema.PhoneCodeWindow})
	if err != nil {
		return e.InternalServerError("", err)
	}
	if !ok {
		return e.TooManyRequestsError("Too many test messages. Wait 15 minutes and try again.", nil)
	}
	if err := note(e.App, now, kindTestSMS, e.Auth.Id); err != nil {
		return e.InternalServerError("", err)
	}

	res := gateway.Send(context.WithoutCancel(e.Request.Context()), phone, TestMessage)
	remember(e.App, res)
	e.App.Logger().Info("signin: test SMS", "admin", e.Auth.Id, "ok", res.OK, "status", res.Status)
	return e.JSON(http.StatusOK, res)
}

// fieldErrors answers 400 with one entry per field, in PocketBase's usual
// shape.
func fieldErrors(fe FieldErrors) error {
	data := make(map[string]validation.Error, len(fe))
	for field, msg := range fe {
		data[field] = validation.NewError("validation_invalid_value", msg)
	}
	return router.NewBadRequestError("Some sign-in settings need attention.", data)
}
