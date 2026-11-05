package signin

import (
	"strings"

	validation "ganigeorgiev.com/pocketbase/ozzo-validation/v4"
	"ganigeorgiev.com/pocketbase/pocketbase/core"
	"ganigeorgiev.com/pocketbase/pocketbase/tools/router"
)

// Reasons for a refused Google sign-in, sent as data.reason.code so the
// apps can show their own translated sentence.
const (
	ReasonGoogleNoEmail     = "google_no_email"
	ReasonGoogleNoAccount   = "google_no_account"
	ReasonGoogleUnconfirmed = "google_email_unconfirmed"
	ReasonNotAllowed        = "account_not_allowed"
	ReasonGoogleUnmanaged   = "google_email_not_managed"
)

// Answers to a refused Google sign-in. The person has proved who they are
// to Google, so each answer can say what to do.
const (
	GoogleNoEmailMessage = "Google did not share a confirmed email address for this Google account. " +
		"Use a Google account with a confirmed email address, or another way to sign in."
	GoogleNoAccountMessage = "No Obhijatra account here uses this Google email address. " +
		"Ask your organisation admin to add it, or use another way to sign in."
	GoogleUnconfirmedMessage = "Your organisation admin must confirm your email address on your account " +
		"before you can sign in with Google."
	GoogleNotAllowedMessage = "This account cannot sign in. Ask your organisation admin."
	GoogleUnmanagedMessage  = "Google cannot vouch that this email address belongs to this Google account. " +
		"Sign in with a Gmail address or your organisation's Google Workspace account, or use another way to sign in."
)

// googleOwnsAddress reports whether Google is the authority for email, as
// Google's guide "Verify the Google ID token on your server side" puts it:
// a Gmail address, or a Google Workspace account (the "hd" claim is set).
// Any other address Google confirmed once, when the account was made, but
// its owner may have changed since (a reused work mailbox), so it does not
// prove who is signing in.
func googleOwnsAddress(email string, rawUser map[string]any) bool {
	at := strings.LastIndex(email, "@")
	if at < 0 {
		return false
	}
	switch strings.ToLower(email[at+1:]) {
	case "gmail.com", "googlemail.com":
		return true
	}
	hd, _ := rawUser["hd"].(string)
	return strings.TrimSpace(hd) != ""
}

// guardGoogle runs before PocketBase completes a Google sign-in. It lets
// the sign-in through only to an existing, active account whose confirmed
// email address is the one Google reports, so:
//   - nobody can create an account by signing in with Google (accounts are
//     by invitation only);
//   - a stolen session cannot link the thief's own Google account to its
//     victim, which would outlast the session;
//   - an account an admin has not confirmed cannot be taken over by
//     whoever controls a Google account with that address (the
//     pre-hijacking pattern behind PocketBase's account-takeover advisories);
//   - a Google link stops working when an admin changes the email address.
func guardGoogle(e *core.RecordAuthWithOAuth2RequestEvent) error {
	refuse := func(reason, msg, why string) error {
		e.App.Logger().Info("Google sign-in refused", "reason", why)
		return router.NewBadRequestError(msg, map[string]validation.Error{
			"reason": validation.NewError(reason, msg),
		})
	}

	email := strings.TrimSpace(e.OAuth2User.Email)
	switch {
	case email == "":
		return refuse(ReasonGoogleNoEmail, GoogleNoEmailMessage, "no confirmed email from Google")
	case !googleOwnsAddress(email, e.OAuth2User.RawUser):
		return refuse(ReasonGoogleUnmanaged, GoogleUnmanagedMessage, "address is neither Gmail nor a Google Workspace account")
	case e.Record == nil:
		return refuse(ReasonGoogleNoAccount, GoogleNoAccountMessage, "no account")
	case !strings.EqualFold(e.Record.Email(), email):
		return refuse(ReasonGoogleNoAccount, GoogleNoAccountMessage, "account email differs from the Google email")
	case !e.Record.Verified():
		return refuse(ReasonGoogleUnconfirmed, GoogleUnconfirmedMessage, "account email not confirmed")
	}

	info, err := e.RequestInfo()
	if err != nil {
		return err
	}
	allowed, err := e.App.CanAccessRecord(e.Record, info, e.Record.Collection().AuthRule)
	if err != nil {
		return err
	}
	if !allowed {
		return refuse(ReasonNotAllowed, GoogleNotAllowedMessage, "account not allowed to sign in (deactivated)")
	}

	e.CreateData = nil
	return e.Next()
}
