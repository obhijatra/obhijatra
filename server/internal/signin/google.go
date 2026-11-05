package signin

import (
	"errors"
	"strings"

	"ganigeorgiev.com/pocketbase/pocketbase/core"
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
)

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
	refuse := func(msg, reason string) error {
		return e.BadRequestError(msg, errors.New("Google sign-in refused: "+reason))
	}

	email := strings.TrimSpace(e.OAuth2User.Email)
	switch {
	case email == "":
		return refuse(GoogleNoEmailMessage, "no confirmed email from Google")
	case e.Record == nil:
		return refuse(GoogleNoAccountMessage, "no account")
	case !strings.EqualFold(e.Record.Email(), email):
		return refuse(GoogleNoAccountMessage, "account email differs from the Google email")
	case !e.Record.Verified():
		return refuse(GoogleUnconfirmedMessage, "account email not confirmed")
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
		return refuse(GoogleNotAllowedMessage, "account not allowed to sign in (deactivated)")
	}

	e.CreateData = nil
	return e.Next()
}
