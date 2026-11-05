package signin

import (
	"context"
	"database/sql"
	"errors"
	"fmt"
	"net"
	"net/http"
	"slices"
	"strings"
	"sync"
	"time"

	"ganigeorgiev.com/pocketbase/dbx"
	validation "ganigeorgiev.com/pocketbase/ozzo-validation/v4"
	"ganigeorgiev.com/pocketbase/pocketbase/apis"
	"ganigeorgiev.com/pocketbase/pocketbase/core"
	"ganigeorgiev.com/pocketbase/pocketbase/tools/router"
	"ganigeorgiev.com/pocketbase/pocketbase/tools/routine"
	"ganigeorgiev.com/pocketbase/pocketbase/tools/security"
	"golang.org/x/crypto/bcrypt"

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
	kindSMSSent   = "sms_sent"   // a sign-in code sent by SMS (organisation-wide)
	kindTestSMS   = "test_sms"   // a test SMS sent by this admin
)

// codeHashCost is the bcrypt cost of stored codes. A code lives 5 minutes
// and allows 3 tries; the hash only keeps it out of plain sight.
const codeHashCost = 8

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

// limitKey is the address a limit counts against: the IP address, or for
// IPv6 its /64 network, which one household or office usually holds whole.
func limitKey(ip string) string {
	parsed := net.ParseIP(ip)
	if parsed == nil || parsed.To4() != nil {
		return ip
	}
	return parsed.Mask(net.CIDRMask(64, 128)).String() + "/64"
}

// CodeResponse is the answer to a code request. CodeID names the code for
// the check; it looks the same whether or not an SMS will be sent.
type CodeResponse struct {
	CodeID      string `json:"code_id"`
	ExpiresIn   int    `json:"expires_in"`   // seconds
	ResendAfter int    `json:"resend_after"` // seconds
}

// requestCode answers POST /signin/phone/code {"collection", "phone"}.
//
// It checks only the input and the limits, then answers. Finding the
// account, deciding whether it may have a code, storing the code and
// sending the SMS all happen after the answer, so neither the answer nor
// its timing tells a stranger which numbers have accounts.
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
	phoneKey := body.Collection + ":" + phone
	ok, err := reserve(e.App, now, []limit{
		{kindCodeIP, limitKey(e.RealIP()), schema.PhoneCodesPerIP, schema.PhoneCodeWindow},
		{kindCodePhone, phoneKey, schema.PhoneCodesPerWindow, schema.PhoneCodeWindow},
		{kindCodePhone, phoneKey, schema.PhoneCodesPerDay, 24 * time.Hour},
	})
	if err != nil {
		return e.InternalServerError("", err)
	}
	if !ok {
		return e.TooManyRequestsError(TooManyCodes, nil)
	}

	codeID := core.GenerateDefaultRandomId()
	app, gateway, collection, ip := e.App, settings.SMS, body.Collection, e.RealIP()
	routine.FireAndForget(func() { deliverCode(app, gateway, collection, phone, codeID, ip) })

	return e.JSON(http.StatusOK, CodeResponse{
		CodeID:      codeID,
		ExpiresIn:   int(schema.PhoneCodeLifetime.Seconds()),
		ResendAfter: int(schema.PhoneCodeResendAfter.Seconds()),
	})
}

// deliverCode runs after requestCode has answered: it stores a code and
// sends it, if the number belongs to an account that may sign in by SMS,
// that is not locked for ip, and the organisation's daily SMS limit has
// room.
func deliverCode(app core.App, gateway SMSGateway, collection, phone, codeID, ip string) {
	user, err := app.FindFirstRecordByData(collection, "phone", phone)
	if err != nil || !PhoneSignInAllowed(user) {
		return
	}
	if locked, err := lockout.Locked(app, user, ip); err != nil || locked {
		return
	}

	now := time.Now().UTC()
	ok, err := reserve(app, now, []limit{{kindSMSSent, "org", orgDailySMSLimit(app), 24 * time.Hour}})
	if err != nil {
		app.Logger().Error("signin: could not check the daily SMS limit", "error", err)
		return
	}
	if !ok {
		app.Logger().Warn("signin: the organisation's daily limit of SMS sign-in codes is reached; no code was sent")
		return
	}

	code := security.RandomStringWithAlphabet(schema.PhoneCodeLength, "0123456789")
	hash, err := bcrypt.GenerateFromPassword([]byte(code), codeHashCost)
	if err != nil {
		app.Logger().Error("signin: could not hash a sign-in code", "error", err)
		return
	}
	_, err = app.NonconcurrentDB().Insert(schema.PhoneCodesTable, dbx.Params{
		"id":                 codeID,
		"account_collection": collection,
		"account_id":         user.Id,
		"phone":              phone,
		"code_hash":          string(hash),
		"tries":              0,
		"created":            now.UnixMilli(),
	}).Execute()
	if err != nil {
		app.Logger().Error("signin: could not store a sign-in code", "error", err)
		return
	}

	res := gateway.Send(context.Background(), phone, CodeMessage(code))
	// Some providers repeat the message in their reply: never keep it.
	res.Reply = ""
	remember(app, res)
	if !res.OK {
		app.Logger().Warn("signin: the SMS provider did not accept a sign-in code", "status", res.Status)
	}
}

// orgDailySMSLimit caps the sign-in codes sent in 24 hours, as a guard
// against abuse that the per-number limits miss: three per account that
// has a phone number, and at least 100.
func orgDailySMSLimit(app core.App) int {
	total := 0
	for _, c := range schema.PhoneSignInCollections {
		n, err := app.CountRecords(c, dbx.NewExp("[[phone]] != ''"))
		if err == nil {
			total += int(n)
		}
	}
	return max(100, 3*total)
}

// storedCode is one row of schema.PhoneCodesTable.
type storedCode struct {
	ID         string `db:"id"`
	Collection string `db:"account_collection"`
	AccountID  string `db:"account_id"`
	Phone      string `db:"phone"`
	Hash       string `db:"code_hash"`
	Tries      int    `db:"tries"`
	Created    int64  `db:"created"`
}

// dummyHash is checked against when there is no code, so a refusal takes
// as long as a wrong code.
var dummyHash = sync.OnceValue(func() []byte {
	h, _ := bcrypt.GenerateFromPassword([]byte("000000"), codeHashCost)
	return h
})

// verifyCode answers POST /signin/phone/verify {"code_id", "code"} with
// PocketBase's standard sign-in answer (token and record) for the right
// code, and WrongCodeMessage otherwise.
//
// A try is claimed in one database statement before the code is checked,
// so requests running side by side cannot together check a code more than
// schema.PhoneCodeMaxTries times, and the code is deleted in one statement
// on success, so it signs in once.
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
	ok, err := reserve(e.App, now, []limit{{kindCheckIP, limitKey(ip), schema.PhoneChecksPerIP, schema.PhoneCodeWindow}})
	if err != nil {
		return e.InternalServerError("", err)
	}
	if !ok {
		return e.TooManyRequestsError(TooManyChecks, nil)
	}

	wrong := func(reason string) error {
		return e.BadRequestError(WrongCodeMessage, errors.New("sign-in code refused: "+reason))
	}
	// Spend the same hashing time on every refusal that has no code to check.
	wrongAfterDummyCheck := func(reason string) error {
		_ = bcrypt.CompareHashAndPassword(dummyHash(), []byte(code))
		return wrong(reason)
	}
	if codeID == "" || len(codeID) > 64 || len(code) != schema.PhoneCodeLength || strings.Trim(code, "0123456789") != "" {
		return wrongAfterDummyCheck("malformed")
	}

	// Claim a try.
	res, err := e.App.NonconcurrentDB().NewQuery(
		"UPDATE {{" + schema.PhoneCodesTable + "}} SET [[tries]] = [[tries]] + 1 " +
			"WHERE [[id]] = {:id} AND [[tries]] < {:max} AND [[created]] > {:since}",
	).Bind(dbx.Params{
		"id":    codeID,
		"max":   schema.PhoneCodeMaxTries,
		"since": now.Add(-schema.PhoneCodeLifetime).UnixMilli(),
	}).Execute()
	if err != nil {
		return e.InternalServerError("", err)
	}
	if n, _ := res.RowsAffected(); n != 1 {
		return wrongAfterDummyCheck("unknown, expired, used or out of tries")
	}

	var c storedCode
	err = e.App.DB().Select("*").From(schema.PhoneCodesTable).Where(dbx.HashExp{"id": codeID}).One(&c)
	if errors.Is(err, sql.ErrNoRows) {
		return wrongAfterDummyCheck("used meanwhile")
	}
	if err != nil {
		return e.InternalServerError("", err)
	}
	discard := func() {
		if err := deleteCode(e.App, codeID); err != nil {
			e.App.Logger().Error("signin: could not delete a sign-in code", "error", err)
		}
	}

	user, err := e.App.FindRecordById(c.Collection, c.AccountID)
	// The number, role or status may have changed since the code was sent.
	if err != nil || !PhoneSignInAllowed(user) || user.GetString("phone") != c.Phone {
		discard()
		return wrongAfterDummyCheck("account may no longer sign in by phone")
	}

	locked, err := lockout.Locked(e.App, user, ip)
	if err != nil {
		return e.InternalServerError("", err)
	}
	if locked {
		return wrongAfterDummyCheck("account locked")
	}
	// Counted as wrong before the check and forgotten if it is right, so
	// guesses running side by side all count towards the lock.
	if err := lockout.RecordFailure(e.App, user, ip); err != nil {
		return e.InternalServerError("", err)
	}

	if bcrypt.CompareHashAndPassword([]byte(c.Hash), []byte(code)) != nil {
		if c.Tries >= schema.PhoneCodeMaxTries {
			discard()
		}
		return wrong("wrong code")
	}

	// A code signs in once: only the request that deletes it goes on.
	res, err = e.App.NonconcurrentDB().Delete(schema.PhoneCodesTable, dbx.HashExp{"id": codeID}).Execute()
	if err != nil {
		return e.InternalServerError("", err)
	}
	if n, _ := res.RowsAffected(); n != 1 {
		return wrong("used meanwhile")
	}
	if err := lockout.ClearFailures(e.App, user, ip); err != nil {
		return e.InternalServerError("", err)
	}
	return apis.RecordAuthResponse(e, user, core.MFAMethodOTP, nil)
}

func deleteCode(app core.App, id string) error {
	_, err := app.NonconcurrentDB().Delete(schema.PhoneCodesTable, dbx.HashExp{"id": id}).Execute()
	return err
}

// ---------------------------------------------------------------------
// Counting, for the limits
// ---------------------------------------------------------------------

type limit struct {
	kind, key string
	max       int
	window    time.Duration
}

// reserve checks every limit and, only if all have room, counts one more
// against each, in one transaction: requests running side by side are
// counted one after another, so none can slip past a limit. It also
// forgets counts older than a day and codes past their lifetime.
func reserve(app core.App, now time.Time, limits []limit) (bool, error) {
	ok := false
	err := app.RunInTransaction(func(txApp core.App) error {
		db := txApp.NonconcurrentDB()
		if _, err := db.Delete(schema.SignInAttemptsTable, dbx.NewExp("[[at]] <= {:start}",
			dbx.Params{"start": now.Add(-24 * time.Hour).UnixMilli()})).Execute(); err != nil {
			return fmt.Errorf("signin: prune attempts: %w", err)
		}
		if _, err := db.Delete(schema.PhoneCodesTable, dbx.NewExp("[[created]] <= {:start}",
			dbx.Params{"start": now.Add(-schema.PhoneCodeLifetime).UnixMilli()})).Execute(); err != nil {
			return fmt.Errorf("signin: prune codes: %w", err)
		}

		for _, l := range limits {
			var n int
			err := db.Select("COUNT(*)").From(schema.SignInAttemptsTable).
				Where(dbx.HashExp{"kind": l.kind, "key": l.key}).
				AndWhere(dbx.NewExp("[[at]] > {:since}", dbx.Params{"since": now.Add(-l.window).UnixMilli()})).
				Row(&n)
			if err != nil {
				return fmt.Errorf("signin: count attempts: %w", err)
			}
			if n >= l.max {
				return nil
			}
		}

		counted := map[string]bool{}
		for _, l := range limits {
			if counted[l.kind+"\x00"+l.key] {
				continue // two windows on one count
			}
			counted[l.kind+"\x00"+l.key] = true
			if _, err := db.Insert(schema.SignInAttemptsTable, dbx.Params{
				"kind": l.kind, "key": l.key, "at": now.UnixMilli(),
			}).Execute(); err != nil {
				return fmt.Errorf("signin: count attempt: %w", err)
			}
		}
		ok = true
		return nil
	})
	return ok, err
}

// fieldError answers 400 with PocketBase's usual shape for a problem with
// one submitted field: data.<field>.code and data.<field>.message. (Plain
// maps would reach the client as "Invalid value."; validation errors keep
// their code and message.)
func fieldError(field, code, message string) error {
	return router.NewBadRequestError(message, map[string]validation.Error{
		field: validation.NewError(code, message),
	})
}
