# 2. obhijatra-server: PocketBase, vendored, with Go hooks only

Date: 4 November 2026

Status: Accepted (draft — to be confirmed)

## Context

Each organisation runs its own server, often with little IT support. PocketBase (a small database server that stores data in one SQLite file) fits this well. But it is before version 1.0, is maintained by one volunteer, and its source now lives on the author's own site (`ganigeorgiev.com`), not on GitHub. A build that depends on that site could stop working.

## Decision

`obhijatra-server` is a Go program (module `github.com/obhijatra/obhijatra/server`, Go 1.27.3 in `server/go.mod`) that uses PocketBase **v0.41.1** (`ganigeorgiev.com/pocketbase/pocketbase`) as a library.

- **Vendored.** The source of PocketBase and every other dependency is committed in `server/vendor/`. A build never needs the network: `go build -mod=vendor` is enough.
- **Go hooks only.** Obhijatra's behaviour is added through Go code (migrations, hooks, middleware, routes), not PocketBase's embedded JavaScript. The signature checks and the audit chain need Go.
- **Built without C.** `CGO_ENABLED=0` for linux/amd64, linux/arm64, windows/amd64 and darwin/arm64 (`server/scripts/build-all.sh`), giving one file plus the `pb_data` folder.
- **Set up by `init`.** `obhijatra-server serve` refuses to start until `obhijatra-server init` has run. `init` writes the settings key to a private file, creates one superuser and the first organisation admin, and switches on the sign-in rate limit and year-long logs.
- **Fenced endpoints.** Three PocketBase superuser features are blocked because they would bypass the audit chain: the SQL console, impersonation and emptying a whole collection.
- **Routes** live under `/api/obhijatra/v1/` and a version is removed no sooner than 24 months after its successor ships.

### The audit chain

Every create, update and delete of a record, a collection (the data structure) or the server settings adds one row to an `audit` collection, inside the same database transaction as the change. Each row stores the SHA-256 hash of the row before it, so changing or deleting any row breaks the chain from that point. `obhijatra-server audit verify` re-checks the whole chain and reports the first broken link. The chain is append-only for everything that goes through the server, including superusers. It is **tamper-evident, not tamper-proof**: someone who can edit the database file directly could rewrite the chain, and cutting rows off the end cannot be detected from the database alone.

### The idempotent submission route

`POST /api/obhijatra/v1/submissions` stores one finished ODK form submission (XML plus attachments). "Idempotent" means a phone can safely send the same submission again after a poor connection. The server keys it on the `instanceID` inside the XML:

- new instance ID: stored, answer 200 "received";
- same instance ID, same XML (checked by SHA-256) and same user: 200 "already_received", nothing changed;
- same instance ID but different XML or a different user: 409, nothing replaced.

Only active field users may send; the form version must exist and be published.

### XML files are checked by their content, not their MIME type

*Changed 4 November 2026, after the client team found valid files refused as "invalid mime type".*

A MIME type is the label that says what kind of file something is. PocketBase guessed it from the first bytes, so a valid submission without an `<?xml ...?>` line looked like plain text, and an XForm starting `<html xmlns=...>` looked like a web page. Both were refused. The two XML file fields (`submissions.xml`, `form_versions.xform`) no longer have a MIME-type list. Instead a Go hook reads every uploaded XML file in full, whoever uploads it (the API, the Dashboard, a superuser or Go code), with a hardened reader (`server/internal/xform`):

- **Size:** at most 10 MiB (10,485,760 bytes, `schema.MaxXMLSize`) per file. Real XForms with several languages stay well under 1 MiB and submissions are a few KiB, so this leaves wide room while bounding memory and time. The limit is checked before reading and again while reading.
- **No DTD, so no entities:** any `<!DOCTYPE ...>` or other `<!...>` declaration is refused. Without a DTD no entity can be defined, so an "external entity" that reads a server file or a web address (XXE) and nested entities that expand a small file into gigabytes ("billion laughs") are both impossible. Only the five built-in XML entities (`&lt;` and so on) and numeric character references are understood. Go's XML reader never fetches anything in any case; the tests prove both attacks are refused, that no web address is contacted, and that memory stays small.
- **Well-formed to the last byte:** exactly one root element; no text outside it; the `<?xml ...?>` line only at the very start (and optional); no attribute twice on one element; every namespace prefix declared; at most 100 levels of nesting; UTF-8 only (a leading byte-order mark is allowed).
- **The right kind of document.** XForm: the root is `html` in the XHTML namespace (`http://www.w3.org/1999/xhtml`, written `<h:html>` or `<html xmlns=...>`), with an `h:head` child holding a `model` in the XForms namespace, whose primary instance (the first `instance` without an `id`) has exactly one root element with an `id`; that id and version must match the form record and the version string. Submission: one root element with an `id` and a `meta/instanceID`; the record's `instance_id`, `xml_sha256`, `form` and `form_version` must agree with the XML.

A refused file is answered with HTTP 400 and the reason under the field name, for example `data.xform.code = "validation_invalid_xml"` (see "API changes" below).

### XForm downloads need a file token

*Changed 4 November 2026.* The `form_versions.xform` file field is now *protected*: downloading it needs a short-lived file token (`POST /api/files/token`, then `?token=...` on the file address), and the request must pass the collection's view rule: an active, signed-in user, and for an unpublished version an M&E officer or org admin. Without a token, with an ordinary sign-in token, or as an inactive user, the answer is 404. `submissions.xml` and attachments were already protected.

### Sign-in protection

*Changed 4 November 2026.* Two layers, both from the blueprint ("rate limiting on login plus a 15-minute lock after 10 failed attempts").

**Per internet address (IP): 30 sign-in attempts per 60 seconds, for each user collection.** PocketBase's rate limiter counts requests per IP address in fixed time windows; the window length decides how many requests may arrive *at once*. The first baseline, 2 per 3 seconds, allowed only two people to sign in at the same moment, but up to 40 per minute over time. A branch office shares one internet connection, so every phone and laptop there has the same IP address, and about 30 staff may sign in together at the start of the day or of a training session. 30 per 60 seconds lets all 30 sign in within the same minute; field users and staff each have their own 30, because the limiter counts each user collection separately. Someone who mistypes and arrives as the 31st waits until the minute ends (the app shows "server busy" and tries again). The ceiling over time falls from 40 to 30 attempts per minute from one address, so trying one common password against many accounts from one address becomes slower, not faster. Guessing one person's password is limited by the per-account lock below, however many addresses an attacker uses. The tests sign in 30 staff from one address and check that the 31st attempt in the minute is refused with 429. **Deployment note:** behind a reverse proxy, set PocketBase's trusted-proxy header setting, otherwise every user appears to come from the proxy's address and shares one allowance.

**Per account: 10 wrong passwords within 15 minutes lock the account for 15 minutes** (`schema.LockoutMaxFailures`, `LockoutWindow`, `LockoutDuration`), for field users, staff and superusers (`server/internal/lockout`).

- The wrong-password count is kept in a plain database table, `_obhijatra_login_failures` (account and time only; rows older than 15 minutes are deleted). It is the server's own counter, like the rate limiter, so it is not a collection: it is invisible to the API and the Dashboard, and counting does not add rows to the audit chain, so strangers cannot grow the chain. A correct password clears the count; attempts while locked are not counted and do not extend the lock.
- A lock is a new record in the `login_locks` collection (`account_collection`, `account_id`, `failed_attempts`, `locked_until`), written by the server and therefore an audit-chain entry by `_system/server`. Both the count and the lock are in the database, so a restart lifts neither.
- An org admin can unlock early: `PATCH /api/collections/login_locks/records/{id}` with `{"unlocked": true}`. The server stamps `unlocked_at` and `unlocked_by` and clears the count; the change is an audit-chain entry under the admin's name. Nothing else about a lock can be changed and a lock cannot be deleted, by anyone including superusers. A lock that runs out needs no write: its end time is already in the record.
- **One answer for every refused sign-in.** An unknown email, a wrong password and a locked account all get HTTP 400 with the same text: "Sign-in failed. Check the email address and password and try again. After 10 wrong passwords an account is locked for 15 minutes; your organisation admin can unlock it sooner." The password is checked (hashed) exactly once on every path, so the answer and its timing do not reveal whether the account exists or is locked. Residual: a wrong password for a real account also writes the counter, a sub-millisecond difference we accept.
- To check the password only once, the hook replaces PocketBase's own password check and, on success, calls PocketBase's standard `apis.RecordAuthResponse`, which still applies the collection's sign-in rule (active accounts only), the superuser IP allow-list, MFA and login alerts. Re-read PocketBase's `recordAuthWithPassword` on every upgrade.
- Trade-off: someone who knows an email address can keep that person locked out, 15 minutes at a time. The per-IP limit slows this and an org admin can unlock. A lock does not end sessions already signed in; that arrives with the sessions middleware.

### Reviewing submissions

*Changed 4 November 2026.* Staff with the role `supervisor`, `branch_manager`, `me` (monitoring and evaluation) or `org_admin` may set `review_state` (Received, Edited, HasIssues, Approved, Rejected) and the new `review_comment` (up to 2,000 characters) on submissions whose `location_path` lies within their own. `branch_manager` already had this right and keeps it. Field users and donors cannot review. A guard hook refuses a change to any other field of a received submission, for superusers too, and every review is an audit-chain entry under the reviewer's name.

### Publishing forms

*Changed 4 November 2026.* Staff with the role `me` or `org_admin` may create, edit and delete forms, upload XForm versions, and publish a version (`PATCH {"published": true}`, or upload it with `published` set). A published version cannot be changed or deleted: the API rule hides it from these edits, and a guard hook refuses them for everyone, superusers and the Dashboard included. Two further guards keep published versions meaningful: `published_at` is always set by the server at the moment of publishing (a value sent by a client is ignored), and a form's `form_id` cannot change once the form has any version. A form with versions cannot be deleted, because its versions refer to it. Active users see published versions; drafts are visible only to `me` and `org_admin`.

### Schema version 2

These changes are migration `1793822400_review_publishing_signin` (`server/internal/migrations/`), which brings the stored `schema_version` to 2. On a server set up before it, the migration also widens the sign-in rate limit from 2 per 3 seconds to 30 per 60 seconds, but only if the organisation had not changed that rule itself. It cannot be rolled back; restore a backup instead.

### API changes for the apps (4 November 2026)

- **XML uploads:** MIME errors (`validation_invalid_mime_type`) no longer occur for XML. A refused XML file is HTTP 400 with `data.<field>.code` (`<field>` is `xform` or `xml`): `validation_file_size_limit` (over 10 MiB), `validation_invalid_xml` (not well-formed, DOCTYPE or entity, not UTF-8, nested too deep), `validation_invalid_xform` or `validation_invalid_instance` (wrong kind of document), `validation_xform_mismatch` (under `xform` for a different form id, under `version` for a different version string). `data.<field>.message` is plain English. The submissions route keeps its existing 400 answer.
- **XForm download:** needs `?token=<file token>`; the field app already does this.
- **Sign-in:** every refused password sign-in is HTTP 400 with the message above (previously "Failed to authenticate."). A rate-limited attempt is still 429.
- **New collection `login_locks`** (org admins only): fields `account_collection`, `account_id`, `failed_attempts`, `locked_until`, `unlocked`, `unlocked_at`, `unlocked_by`, `created`, `updated`. Unlock with `{"unlocked": true}`.
- **Submissions:** new field `review_comment`; reviewers now include `me` and `org_admin` (in scope).
- **Forms and form versions:** `me` may now do what `org_admin` does; `published_at` is server-set; changing `form_id` of a form with versions is HTTP 400 with `data.form_id.code = "validation_form_id_fixed"`.
- **`/api/obhijatra/v1/meta`:** `schema_version` is now 2.

### Upgrading PocketBase

1. Choose the new version and read its release notes for breaking changes.
2. In `server/`, run `go get ganigeorgiev.com/pocketbase/pocketbase@<version>`, then `go mod tidy`, then `go mod vendor`.
3. Run `go test ./... && go vet ./...`. The tests cover migrations, the audit chain, guards, isolation, submissions, XML validation (including the XXE and billion-laughs attacks), protected downloads, sign-in protection, review and form publishing. Then re-read PocketBase's `recordAuthWithPassword` and `RecordAuthResponse`, which the sign-in lockout relies on (see "Sign-in protection").
4. Review the diff of `server/vendor/` and `go.sum`.
5. Release it only inside an Obhijatra release, with any migration it needs. Never upgrade a running organisation's PocketBase on its own.

## Deferred to the zero-trust milestone

Not built yet; the code has placeholders only:

- Device enrolment and signing: public-key fields exist on devices, but the device-signature middleware that sets the verified device ID does not.
- A sessions middleware: the `sessions` collection exists but nothing writes to it yet.
- A recorded recovery window for impersonation (impersonation is blocked until then).
- Off-server copies of the audit chain's head hash, which would close the gap noted above.
- Field-level end-to-end encryption.

## Consequences

- Builds survive PocketBase's author stopping work.
- The repository is large (the vendored source is about 150 MB).
- We take on the work of tracking PocketBase security fixes ourselves.
- Sign-in protection can be used to lock a known person out for 15 minutes at a time; org admins can unlock.
