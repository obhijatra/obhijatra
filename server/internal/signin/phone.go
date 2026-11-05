package signin

import (
	"context"
	"errors"
	"fmt"
	"net/http"
	"slices"
	"strings"
	"time"

	"ganigeorgiev.com/pocketbase/dbx"
	"ganigeorgiev.com/pocketbase/pocketbase/apis"
	"ganigeorgiev.com/pocketbase/pocketbase/core"
	"ganigeorgiev.com/pocketbase/pocketbase/tools/router"
	"ganigeorgiev.com/pocketbase/pocketbase/tools/routine"
	"ganigeorgiev.com/pocketbase/pocketbase/tools/security"

	"github.com/obhijatra/obhijatra/server/internal/lockout"
	"github.com/obhijatra/obhijatra/server/internal/schema"
)

// Answers of the phone routes, in plain words. Every refused code gets the
// same answer, whatever the reason.
const (
	PhoneOffMessage  = "Sign-in by SMS code is switched off on this server. Use another way to sign in."
	TooManyCodes     = "Too many codes were asked for. Wait 15 minutes, or use another way to sign in."
	TooManyChecks    = "Too many tries from this connection. Wait 15 minutes, then ask for a new code."
	WrongCodeMessage = "That code is wrong or has expired. Check the SMS, or ask for a new code. " +
		"After 10 wrong tries, sign-in is locked for 15 minutes; your organisation admin can unlock it sooner."
	InvalidPhoneMessage = "Enter the mobile number in international form, for example +8801712345678."
)

// CodeMessage is the SMS that carries a sign-in code. It stays in plain
// English letters (GSM-7), so it fits in one SMS on every network.
func CodeMessage(code string) string {
	return fmt.Sprintf("%s is your Obhijatra sign-in code. It expires in %d minutes. Never share it with anyone.",
		code, int(schema.PhoneCodeLifetime.Minutes()))
}

// TestMessage is the SMS sent by "Send test SMS".
const TestMessage = "Obhijatra test message: your SMS settings work."

// Kinds of row in schema.SignInAttemptsTable.
const (
	kindCodeIP    = "code_ip"    // a code asked for from this address
	kindCodePhone = "code_phone" // a code asked for for this collection and number
	kindCheckIP   = "check_ip"   // a code checked from this address
	kindCodeTries = "code_tries" // a wrong entry of this code
	kindTestSMS   = "test_sms"   // a test SMS sent by this admin
)

// NormalisePhone removes the spaces, hyphens, dots and brackets people type
// in phone numbers. It does not guess a country code.
func NormalisePhone(s string) string {
	return strings.Map(func(r rune) rune {
		switch r {
		case ' ', '-', '.', '(', ')', ' ':
			return -1
		}
		return r
	}, strings.TrimSpace(s))
}

// PhoneSignInAllowed reports whether r may sign in with an SMS code: an
// active field or staff user with a phone number who is not an org admin.
func PhoneSignInAllowed(r *core.Record) bool {
	if !slices.Contains(schema.PhoneSignInCollections, r.Collection().Name) {
		return false
	}
	if r.Collection().Name == schema.StaffUsers && r.GetString("role") == schema.RoleOrgAdmin {
		return false
	}
	return r.GetBool("active") && r.GetString("phone") != ""
}

// CodeResponse is the answer to a code request. CodeID names the code for
// the check; it looks the same whether or not an SMS was sent.
type CodeResponse struct {
	CodeID      string `json:"code_id"`
	ExpiresIn   int    `json:"expires_in"`   // seconds
	ResendAfter int    `json:"resend_after"` // seconds
}

// requestCode answers POST /signin/phone/code {"collection", "phone"}.
//
// The answer is the same whether or not the number belongs to an account
// that may sign in, and the SMS is sent after the answer, so neither the
// answer nor its timing tells a stranger which numbers have accounts.
func requestCode(e *core.RequestEvent) error {
	var body struct {
		Collection string `json:"collection"`
		Phone      string `json:"phone"`
	}
	if err := e.BindBody(&body); err != nil {
		return e.BadRequestError("The request could not be read.", err)
	}
	phone := NormalisePhone(body.Phone)
	if !slices.Contains(schema.PhoneSignInCollections, body.Collection) {
		return e.BadRequestError("Unknown kind of account.", nil)
	}
	if !schema.PhoneRegex.MatchString(phone) {
		return fieldError("phone", "validation_invalid_phone", InvalidPhoneMessage)
	}

	settings, err := Load(e.App)
	if err != nil {
		return e.InternalServerError("", err)
	}
	if !settings.PhoneReady() {
		return e.ForbiddenError(PhoneOffMessage, nil)
	}

	now := time.Now().UTC()
	ip := e.RealIP()
	phoneKey := body.Collection + ":" + phone
	ok, err := withinLimits(e.App, now,
		limit{kindCodeIP, ip, schema.PhoneCodesPerIP, schema.PhoneCodeWindow},
		limit{kindCodePhone, phoneKey, schema.PhoneCodesPerWindow, schema.PhoneCodeWindow},
		limit{kindCodePhone, phoneKey, schema.PhoneCodesPerDay, 24 * time.Hour},
	)
	if err != nil {
		return e.InternalServerError("", err)
	}
	if !ok {
		return e.TooManyRequestsError(TooManyCodes, nil)
	}
	if err := note(e.App, now, kindCodeIP, ip); err != nil {
		return e.InternalServerError("", err)
	}
	if err := note(e.App, now, kindCodePhone, phoneKey); err != nil {
		return e.InternalServerError("", err)
	}

	code := security.RandomStringWithAlphabet(schema.PhoneCodeLength, "0123456789")
	otp := core.NewOTP(e.App)
	otp.SetPassword(code) // hashed now, whether or not it is kept, so timing is the same
	codeID := core.GenerateDefaultRandomId()

	user, err := e.App.FindFirstRecordByData(body.Collection, "phone", phone)
	send := err == nil && PhoneSignInAllowed(user)
	if send {
		if locked, err := lockout.Locked(e.App, user, ip); err != nil {
			return e.InternalServerError("", err)
		} else if locked {
			send = false
		}
	}

	if send {
		otp.SetCollectionRef(user.Collection().Id)
		otp.SetRecordRef(user.Id)
		otp.SetSentTo(phone)
		if err := e.App.Save(otp); err != nil {
			return e.InternalServerError("", err)
		}
		codeID = otp.Id

		app, gateway := e.App, settings.SMS
		routine.FireAndForget(func() {
			res := gateway.Send(context.Background(), phone, CodeMessage(code))
			remember(app, res)
			if !res.OK {
				app.Logger().Warn("signin: the SMS provider did not send a sign-in code",
					"status", res.Status, "reply", res.Reply)
			}
		})
	}

	return e.JSON(http.StatusOK, CodeResponse{
		CodeID:      codeID,
		ExpiresIn:   int(schema.PhoneCodeLifetime.Seconds()),
		ResendAfter: int(schema.PhoneCodeResendAfter.Seconds()),
	})
}

// verifyCode answers POST /signin/phone/verify {"code_id", "code"} with
// PocketBase's standard sign-in answer (token and record) for the right
// code, and WrongCodeMessage otherwise.
func verifyCode(e *core.RequestEvent) error {
	var body struct {
		CodeID string `json:"code_id"`
		Code   string `json:"code"`
	}
	if err := e.BindBody(&body); err != nil {
		return e.BadRequestError("The request could not be read.", err)
	}
	codeID, code := strings.TrimSpace(body.CodeID), strings.TrimSpace(body.Code)

	settings, err := Load(e.App)
	if err != nil {
		return e.InternalServerError("", err)
	}
	if !settings.PhoneReady() {
		return e.ForbiddenError(PhoneOffMessage, nil)
	}

	now := time.Now().UTC()
	ip := e.RealIP()
	ok, err := withinLimits(e.App, now, limit{kindCheckIP, ip, schema.PhoneChecksPerIP, schema.PhoneCodeWindow})
	if err != nil {
		return e.InternalServerError("", err)
	}
	if !ok {
		return e.TooManyRequestsError(TooManyChecks, nil)
	}
	if err := note(e.App, now, kindCheckIP, ip); err != nil {
		return e.InternalServerError("", err)
	}

	wrong := func(reason string) error {
		return e.BadRequestError(WrongCodeMessage, errors.New("sign-in code refused: "+reason))
	}
	if codeID == "" || len(codeID) > 64 || len(code) != schema.PhoneCodeLength || strings.Trim(code, "0123456789") != "" {
		return wrong("malformed")
	}

	otp, err := e.App.FindOTPById(codeID)
	if err != nil {
		return wrong("unknown code id")
	}
	discard := func(reason string) error {
		if err := e.App.Delete(otp); err != nil {
			e.App.Logger().Error("signin: could not delete a sign-in code", "error", err)
		}
		return wrong(reason)
	}

	collection, err := e.App.FindCachedCollectionByNameOrId(otp.CollectionRef())
	if err != nil || !slices.Contains(schema.PhoneSignInCollections, collection.Name) {
		return wrong("code for another collection")
	}
	if otp.HasExpired(schema.PhoneCodeLifetime) {
		return discard("expired")
	}
	user, err := e.App.FindRecordById(collection, otp.RecordRef())
	if err != nil {
		return discard("account gone")
	}
	// The number, role or status may have changed since the code was sent.
	if !PhoneSignInAllowed(user) || user.GetString("phone") != otp.SentTo() {
		return discard("account may no longer sign in by phone")
	}
	locked, err := lockout.Locked(e.App, user, ip)
	if err != nil {
		return e.InternalServerError("", err)
	}
	valid := otp.ValidatePassword(code)

	switch {
	case locked:
		return wrong("account locked")
	case !valid:
		if err := lockout.RecordFailure(e.App, user, ip); err != nil {
			return e.InternalServerError("", err)
		}
		if err := note(e.App, now, kindCodeTries, otp.Id); err != nil {
			return e.InternalServerError("", err)
		}
		tries, err := count(e.App, kindCodeTries, otp.Id, now.Add(-24*time.Hour))
		if err != nil {
			return e.InternalServerError("", err)
		}
		if tries >= schema.PhoneCodeMaxTries {
			return discard("wrong code, no tries left")
		}
		return wrong("wrong code")
	}

	// A code works once.
	if err := e.App.Delete(otp); err != nil {
		return e.InternalServerError("", err)
	}
	if err := lockout.ClearFailures(e.App, user, ip); err != nil {
		return e.InternalServerError("", err)
	}
	return apis.RecordAuthResponse(e, user, core.MFAMethodOTP, nil)
}

// ---------------------------------------------------------------------
// Counting, for the limits
// ---------------------------------------------------------------------

type limit struct {
	kind, key string
	max       int
	window    time.Duration
}

// withinLimits reports whether every limit still has room. It also forgets
// rows older than a day, the longest window.
func withinLimits(app core.App, now time.Time, limits ...limit) (bool, error) {
	if _, err := app.NonconcurrentDB().Delete(schema.SignInAttemptsTable, dbx.NewExp("[[at]] <= {:start}",
		dbx.Params{"start": now.Add(-24 * time.Hour).UnixMilli()})).Execute(); err != nil {
		return false, fmt.Errorf("signin: prune attempts: %w", err)
	}
	for _, l := range limits {
		n, err := count(app, l.kind, l.key, now.Add(-l.window))
		if err != nil {
			return false, err
		}
		if n >= l.max {
			return false, nil
		}
	}
	return true, nil
}

func count(app core.App, kind, key string, since time.Time) (int, error) {
	var n int
	err := app.DB().Select("COUNT(*)").From(schema.SignInAttemptsTable).
		Where(dbx.HashExp{"kind": kind, "key": key}).
		AndWhere(dbx.NewExp("[[at]] > {:since}", dbx.Params{"since": since.UnixMilli()})).
		Row(&n)
	if err != nil {
		return 0, fmt.Errorf("signin: count attempts: %w", err)
	}
	return n, nil
}

func note(app core.App, at time.Time, kind, key string) error {
	_, err := app.NonconcurrentDB().Insert(schema.SignInAttemptsTable, dbx.Params{
		"kind": kind, "key": key, "at": at.UnixMilli(),
	}).Execute()
	if err != nil {
		return fmt.Errorf("signin: count attempt: %w", err)
	}
	return nil
}

// fieldError answers 400 with PocketBase's usual shape for a problem with
// one submitted field.
func fieldError(field, code, message string) error {
	return router.NewBadRequestError(message, map[string]any{
		field: map[string]string{"code": code, "message": message},
	})
}
