# 5. Sign-in by Google and by SMS code, on the organisation's own server

Date: 5 November 2026

Status: Accepted

## Context

The owner asked for three ways to sign in: email and password, Google, and phone. The first request was to use Firebase Authentication and Firestore as the backend. Three facts from Google's own pages (checked 5 November 2026) argued against that:

- Firestore has no Bangladesh region; the nearest are Mumbai, Delhi and Singapore ([Firestore locations](https://firebase.google.com/docs/firestore/locations)). Personal data would leave the country, which section 29 of the Personal Data Protection Act 2026 allows only with consent or a contract.
- Firebase phone sign-in sends its SMS codes only on the paid Blaze plan ([Firebase Auth limits](https://firebase.google.com/docs/auth/limits)), against the no-budget rule.
- It would reverse confirmed decisions: each organisation runs its own server, Aninda Studio hosts nothing, and nothing leaves the organisation's server.

The owner chose (5 November 2026): keep the self-hosted server and add the three sign-in methods to it; keep the Firebase project `obhijatra-ci` for testing only; send SMS codes through each organisation's own SMS provider; refuse SMS sign-in to org admins; connect any SMS provider by form; open Google sign-in in a secure browser tab, with no Google code inside the apps.

## Decision

**Email and password** stay as they are (lockout, progressive delay for admins).

**Google sign-in** uses PocketBase's OAuth2 flow with the organisation's own Google Cloud client (free). The app opens Google's page in a secure browser tab; the server finishes the sign-in. A server guard lets Google reach only an account that:

- an org admin already created (nobody is created by signing in with Google: accounts are by invitation only);
- is active;
- has the same email address as Google reports, ignoring capital letters, and Google has confirmed that address;
- has its email address confirmed by an admin (`verified`), which closes the pre-hijacking pattern behind PocketBase's account-takeover advisories.

A signed-in session cannot link a different Google account (so a stolen session cannot plant a lasting way in), and a Google link stops working when an admin changes the account's email address. Google requires the server to have an `https://` web address with a real domain name, not a bare IP address ([Google OAuth redirect URI rules](https://developers.google.com/identity/protocols/oauth2/web-server)).

**SMS-code sign-in** is Obhijatra's own route (`/api/obhijatra/v1/signin/phone/…`):

- A 6-digit code, valid for 5 minutes and 3 tries, works once. Codes are stored hashed in PocketBase's own one-time-code table, and PocketBase's email-code routes stay off.
- It is refused to org admins, and checked again when the code is used (role, active status and number may have changed).
- The answer to "send me a code" is the same, and arrives just as fast, whether or not the number has an account; the SMS goes out after the answer.
- Wrong codes count towards the same locks as wrong passwords.
- Every SMS costs the organisation money, so sending is limited: 3 codes per number per 15 minutes, 10 per day, 30 per internet address per 15 minutes; 60 code checks per address per 15 minutes; 10 test messages per admin per 15 minutes.
- The SMS provider is any service with an HTTPS web interface, described by form: method, address, body (JSON or form), extra headers, a secret key and an optional "success text". The placeholders `{phone}`, `{phone_digits}`, `{message}` and `{secret}` are filled in with the right escaping for each place. Plain `http://` is refused, redirects are not followed, and loopback, link-local and multicast addresses are refused, so the form cannot reach the server itself or a cloud metadata service. Providers on the organisation's own network are allowed.

**Settings** are changed only by an active org admin, in the manager app (GET and PUT `/api/obhijatra/v1/signin/settings`). Secrets are never sent back, only "set" or "not set". The SMS settings are stored encrypted with the server settings key; the Google client secret sits in PocketBase's own collection settings, as PocketBase stores it. Every change is an audit-chain entry.

**Accounts** gain an optional phone number in international form (unique per kind of account) that users cannot change themselves. Email becomes optional, so field staff without email can sign in by phone, but every account needs an email or a phone, and an org admin needs an email. `obhijatra-server unlock` accepts a phone number.

## Consequences

- Nothing leaves the organisation's server except what it chooses: the SMS provider sees the phone number and the code; Google sees that the person signed in. Both are listed as sub-processors in the install guide.
- Each organisation does a one-time set-up for each extra method (`docs/setup/sign-in.md`), guided in the manager app.
- No Google or Firebase code is added to the apps; the repository rule stands.
- SMS codes are weaker than an authenticator app (a SIM can be swapped), which is why org admins cannot use them. The blueprint's plan for multi-factor sign-in for admins is unchanged.
- Firebase stays a test tool only. Firebase Test Lab shuts down on 30 September 2027; the test workflow will move to its replacement before then (`docs/setup/firebase.md`).
