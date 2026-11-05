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
- has its email address confirmed by an admin (`verified`), which closes the pre-hijacking pattern behind PocketBase's account-takeover advisories;
- uses an address Google can vouch for: a Gmail address or a Google Workspace account. Google's own guidance says any other address was confirmed only when the Google account was made, and may since have changed hands ([Verify the Google ID token on your server side](https://developers.google.com/identity/gsi/web/guides/verify-google-id-token)).

A signed-in session cannot link a different Google account (so a stolen session cannot plant a lasting way in), and a Google link stops working when an admin changes the account's email address. Google requires the server to have an `https://` web address with a real domain name, not a bare IP address ([Google OAuth redirect URI rules](https://developers.google.com/identity/protocols/oauth2/web-server)).

**SMS-code sign-in** is Obhijatra's own route (`/api/obhijatra/v1/signin/phone/…`):

- A 6-digit code, valid for 5 minutes and 3 tries, works once. Codes are stored hashed in a plain table of Obhijatra's own (so strangers' requests cannot grow the audit chain), and PocketBase's email-code routes stay off.
- Each try is claimed in one database statement before the code is checked, and the code is deleted in one statement on success, so requests sent side by side cannot get more than 3 tries or sign in twice.
- It is refused to org admins, and checked again when the code is used (role, active status and number may have changed).
- The answer to "send me a code" is the same, and arrives just as fast, whether or not the number has an account: finding the account, storing the code and sending the SMS all happen after the answer. A wrong code takes as long to refuse whether or not the code exists.
- Wrong codes count towards the same locks as wrong passwords.
- Every SMS costs the organisation money, so sending is limited, counted in one transaction so simultaneous requests cannot slip past: 3 codes per number per 15 minutes, 10 per day, 30 per internet address per 15 minutes (an IPv6 address counts as its /64 network); 60 code checks per address per 15 minutes; 10 test messages per admin per 15 minutes; and, organisation-wide, 3 codes a day per account with a phone number (at least 100). PocketBase's own per-address limit (30 a minute) also covers the SMS-code routes. The flip side: anyone who asks for 10 codes for a number blocks SMS sign-in for that number for a day; the person can still use another way to sign in.
- The SMS provider is any service with an HTTPS web interface, described by form: method, address, body (JSON or form), extra headers, a secret key and an optional "success text". The placeholders `{phone}`, `{phone_digits}`, `{message}` and `{secret}` are filled in with the right escaping for each place, and may not appear in the server name. Plain `http://` is refused, redirects are not followed, and loopback, link-local and multicast addresses are refused, so the form cannot reach the server through `localhost` or a cloud metadata service. Providers on the organisation's own network are allowed, so an admin can still reach the server through its own network address; the test SMS shows the first 300 characters of the reply, and only to org admins.

**Settings** are changed only by an active org admin, in the manager app (GET and PUT `/api/obhijatra/v1/signin/settings`). Secrets are never sent back, only "set" or "not set", and the stored SMS key is reused only while messages go to the same provider server; a new server name needs the key typed again, so a stolen admin session cannot send the key elsewhere. The provider's reply to a sign-in code is never kept or logged (some providers repeat the message, code included). The SMS settings are stored encrypted with the server settings key; the Google client secret sits in PocketBase's own collection settings, as PocketBase stores it. Every change is an audit-chain entry.

**Sessions** end when an admin changes a person's phone number, email address, confirmation, role or active status, so a session started by SMS cannot carry on as an org admin, and none outlives a changed number or address.

**The field app's lock** (PIN or the phone's screen lock) still guards the data on the phone. An SMS code or Google can renew the online session after 30 days offline, but the PIN or screen lock must still open the data. Resetting a forgotten PIN, or choosing one on a phone with no screen lock, needs the email address and password, as before: an SMS code arrives on the same phone, so it proves nothing about who holds it. People whose account has no password ask their admin.

**Accounts** gain an optional phone number in international form (unique per kind of account) that users cannot change themselves. Email becomes optional, so field staff without email can sign in by phone, but every account needs an email or a phone, and an org admin needs an email. `obhijatra-server unlock` accepts a phone number.

## Consequences

- Nothing leaves the organisation's server except what it chooses: the SMS provider sees the phone number and the code; Google sees that the person signed in. Both are listed as sub-processors in the install guide.
- Each organisation does a one-time set-up for each extra method (`docs/setup/sign-in.md`), guided in the manager app.
- No Google or Firebase code is added to the apps; the repository rule stands.
- SMS codes are weaker than an authenticator app (a SIM can be swapped), which is why org admins cannot use them. The blueprint's plan for multi-factor sign-in for admins is unchanged.
- An independent security review on 5 November 2026 found and had fixed: the app-lock bypass above, simultaneous guesses beyond 3 tries, races in the sending limits, timing that showed which numbers have accounts, sessions outliving changes, the stored key reusable towards another server, codes visible in the last provider reply, and audit-chain growth from strangers.
- Firebase stays a test tool only. Firebase Test Lab shuts down on 30 September 2027; the test workflow will move to its replacement before then (`docs/setup/firebase.md`).
