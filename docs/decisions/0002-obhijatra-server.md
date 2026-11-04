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
- **Set up by `init`.** `obhijatra-server serve` refuses to start until `obhijatra-server init` has run. `init` writes the settings key to a private file, creates one superuser and the first organisation admin, switches on the sign-in rate limit and year-long logs, and can set the reverse-proxy header (see "Reverse proxies and HTTPS").
- **Fenced endpoints.** Three PocketBase superuser features are blocked because they would bypass the audit chain: the SQL console, impersonation and emptying a whole collection.
- **At most two superusers** (see "Superusers").
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

*Changed 4 November 2026, and again later that day after an independent review (wrong passwords are now counted per account and IP address; deactivated accounts get the uniform answer; `obhijatra-server unlock`).* Two layers, from the blueprint ("rate limiting on login plus a 15-minute lock after 10 failed attempts").

**Per internet address (IP): 30 sign-in attempts per 60 seconds, for each user collection.** PocketBase's rate limiter counts requests per IP address in fixed time windows; the window length decides how many requests may arrive *at once*. The first baseline, 2 per 3 seconds, allowed only two people to sign in at the same moment, but up to 40 per minute over time. A branch office shares one internet connection, so every phone and laptop there has the same IP address, and about 30 staff may sign in together at the start of the day or of a training session. 30 per 60 seconds lets all 30 sign in within the same minute; field users and staff each have their own 30, because the limiter counts each user collection separately. Someone who mistypes and arrives as the 31st waits until the minute ends (the app shows "server busy" and tries again). The ceiling over time falls from 40 to 30 attempts per minute from one address, so trying one common password against many accounts from one address becomes slower, not faster. The tests sign in 30 staff from one address and check that the 31st attempt in the minute is refused with 429.

**Per account and address: 10 wrong passwords within 15 minutes from one IP address lock the account for that address for 15 minutes** (`schema.LockoutMaxFailures`, `LockoutWindow`, `LockoutDuration`), for field users, staff and superusers (`server/internal/lockout`). The person signing in from anywhere else is not affected. Before this change one count per account let anyone who knew an email address keep that person, an org admin included, locked out for good, 15 minutes at a time.

**Per account, from all addresses: 30 wrong passwords within 15 minutes** (`schema.AccountMaxFailures`). This stops guessing spread across many addresses.

- An **ordinary account** (field user, or staff other than org admin) is then locked for every address for 15 minutes.
- A **privileged account** (an org admin or a superuser) is never locked for every address, because whoever could do that could keep the people who unlock others locked out. Instead every sign-in attempt for it waits before its password is checked: 1 second at 30 wrong passwords, doubling with each further one, up to 30 seconds (`AccountDelayBase`, `AccountDelayMax`; the apps wait 60 seconds for an answer). The right password waits too, so the wait does not reveal it, and then works. The wait ends when the wrong passwords leave the 15-minute window, or with `obhijatra-server unlock`.
- Residual: the wait slows each attempt, not many parallel ones; an attacker with many addresses is held by the per-address lock (10 per address per 15 minutes). After 30 wrong passwords the wait also tells the attacker that the account exists and is privileged.

How it works:

- The wrong-password count is kept in a plain database table, `_obhijatra_login_failures` (account, IP address and time only; rows older than 15 minutes are deleted). It is the server's own counter, like the rate limiter, so it is not a collection: it is invisible to the API and the Dashboard, and counting does not add rows to the audit chain, so strangers cannot grow the chain. A correct password clears the count from its own address only; wrong passwords from other addresses still count towards the account-wide limit. Attempts while locked are not counted and do not extend the lock. A lock for one address does not clear that address's count, which still counts towards the account-wide limit and leaves the window when the lock ends.
- A lock is a new record in the `login_locks` collection (`account_collection`, `account_id`, `ip`, `failed_attempts`, `locked_until`), written by the server and therefore an audit-chain entry by `_system/server`. `ip` is the address the lock applies to; empty means every address (locks made before schema version 4 are empty, so they apply everywhere). Both the count and the lock are in the database, so a restart lifts neither.
- An org admin can unlock early: `PATCH /api/collections/login_locks/records/{id}` with `{"unlocked": true}`. The server stamps `unlocked_at` and `unlocked_by` and clears the account's whole count; the change is an audit-chain entry under the admin's name. Nothing else about a lock can be changed and a lock cannot be deleted, by anyone including superusers. A lock that runs out needs no write: its end time is already in the record.
- **`obhijatra-server unlock <email>`**, for an org admin who is locked out with no other admin to help. It runs on the server computer against the data folder (`--dir`), so only someone who can run the server program there can use it; it is safe while the server runs. It lifts every active lock on every account with that email address (field users, staff, superusers) and clears their count, which also ends a privileged account's wait. Each lifted lock is an audit-chain update of the lock by `_cli/unlock`; a count cleared without a lock is an audit-chain entry `delete` on `_obhijatra_login_failures` with the account's id, by `_cli/unlock`. If nothing was locked or counted, nothing is written. Exit status 1 means no account has the address. The email must match exactly, as at sign-in.
- **Deactivated accounts.** PocketBase checks the collection's sign-in rule (`active = true`) only after a correct password and answers 403, which told a stranger that the password was right. The hook now applies the same rule itself before the sign-in response and refuses a deactivated account with the uniform 400, counted like a wrong password.
- **One answer for every refused sign-in.** An unknown email, a wrong password, a locked account and a deactivated account all get HTTP 400 with the same text: "Sign-in failed. Check the email address and password and try again. After 10 wrong passwords an account is locked for 15 minutes; your organisation admin can unlock it sooner." The password is checked (hashed) exactly once on every path, so the answer and its timing do not reveal whether the account exists, is locked or is deactivated. Residuals: a wrong password for a real account also writes the counter, a sub-millisecond difference we accept; and PocketBase still answers 403 when a superuser signs in with the right password from outside the superuser IP allow-list (left for a later change).
- To check the password only once, the hook replaces PocketBase's own password check and, on success, calls PocketBase's standard `apis.RecordAuthResponse`, which still applies the superuser IP allow-list, MFA and login alerts. Re-read PocketBase's `recordAuthWithPassword` and `RecordAuthResponse` on every upgrade.
- The address is PocketBase's `RealIP()`: the connection's address, or, when a trusted proxy header is set, the address in that header (see "Reverse proxies and HTTPS"). Behind a proxy without that setting every user appears to come from the proxy, shares one allowance, and one person's wrong passwords lock everyone there out.
- A lock does not end sessions already signed in; that arrives with the sessions middleware.

### Reverse proxies and HTTPS

*Added 4 November 2026, after the independent review.*

- **Trusted proxy header.** `init --trusted-proxy-header X-Forwarded-For` (comma-separated for several) sets PocketBase's `trustedProxy.headers`; `--trusted-proxy-use-left` sets `trustedProxy.useLeftmostIP`. By default PocketBase takes the right-most valid address in the header, the one the proxy added, which a client cannot fake; the left-most address is safe only if the proxy replaces any header the client sent. Header names are checked (an HTTP token); `--trusted-proxy-use-left` without a header is refused. On a server already set up, the same setting is in the Dashboard (Settings, Application, IP proxy headers).
- **Posture report.** `init` reports the proxy header. When a superuser IP allow-list is set without a trusted proxy header it prints a warning: behind a proxy every request seems to come from the proxy's address, so the allow-list would admit everyone the proxy serves, or no one.
- **HTTPS.** `init` checks the web address it is given. `https://` is reported as on. Plain `http://` on this computer (`localhost`, 127.0.0.0/8, ::1) or a private network (10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16, fc00::/7, link-local) is marked "testing only". Any other `http://` address, including every host name other than `localhost` (init does not look names up), gets a warning, in red when the output is a terminal (not when `NO_COLOR` is set). `init` still completes: a test server may need plain http. `server/README.md`, "Run it with HTTPS", gives the two supported set-ups in numbered steps: PocketBase's own `serve <domain>` with automatic Let's Encrypt certificates, or Caddy or NGINX in front with the trusted proxy header.

### Device records

*Added 4 November 2026, preparing the device-signing milestone.*

- The fields that decide whether a device is trusted, `sign_public_key`, `enc_public_key`, `org_signature`, `status` and `expires` (`schema.DeviceTrustFields`), can no longer be written through the records API by anyone, superusers and the Dashboard included: a guard on PocketBase's create and update *requests* for `devices` answers HTTP 400 with `data.<field>.code = "validation_device_field_server_only"`. Because `status` is required, no device can be created through the records API at all. An org admin may still change other fields, such as `label`. The server's own Go code is not bound, because it is the future enrolment path.
- **`POST /api/obhijatra/v1/devices/enrol` is the only future way to enrol a device.** Today it is a placeholder that answers 501 Not Implemented with a plain message. When built it will accept the device's public keys with the organisation's signature over the device record, verify that signature before storing anything, and, for a device allowed to act with the admin or export scopes, require the signatures of two different org admins.
- Consequence: an org admin can no longer revoke a device through the records API (`status` is a trust field). No device is enrolled yet, so nothing depends on it today; revocation will get its own server route in the same milestone.

### Superusers

*Added 4 November 2026.* A guard on every superuser create (the API, the Dashboard, `obhijatra-server superuser create` or `upsert`, Go code) refuses a third superuser (`schema.MaxSuperusers` = 2: the one `init` creates and one spare) with HTTP 400 and a plain message. The refused attempt's own transaction rolls back, so the guard records the refusal afterwards as an audit-chain entry with the new action `refuse` (collection `_superusers`, the actor who tried, the record id if one was set). Only superusers and people who can run the server program can attempt it, so this cannot be used to grow the chain.

### Vulnerability scanning in CI

*Added 4 November 2026.* The `server` job in `.github/workflows/ci.yml` runs, after the tests and the cross-build:

- **govulncheck v1.9.0** (`go run golang.org/x/vuln/cmd/govulncheck@v1.9.0 ./...`). It reports only vulnerabilities the code can reach. The exact version is pinned and the Go checksum database verifies the download.
- **OSV-Scanner v2.7.0** over `pubspec.lock` and `server/go.mod`, installed from the release's `osv-scanner_linux_amd64` and checked against the SHA-256 that release publishes before it runs. Accepted exceptions live in `server/osv-scanner.toml`, each with a reason and an end date after which the scan fails again. The first: GHSA-q7pp-wcgr-pffx (CVE-2023-36308, a panic on a crafted TIFF in `github.com/disintegration/imaging` 1.6.2, rated Low, no fixed version); PocketBase uses imaging only for thumbnails of files stored as PNG, JPEG, GIF or WebP, so a TIFF never reaches it. Re-check by 4 February 2027.

### Reviewing submissions

*Changed 4 November 2026.* Staff with the role `supervisor`, `branch_manager`, `me` (monitoring and evaluation) or `org_admin` may set `review_state` (Received, Edited, HasIssues, Approved, Rejected) and the new `review_comment` (up to 2,000 characters) on submissions whose `location_path` lies within their own. `branch_manager` already had this right and keeps it. Field users and donors cannot review. A guard hook refuses a change to any other field of a received submission, for superusers too, and every review is an audit-chain entry under the reviewer's name.

### Publishing forms

*Changed 4 November 2026.* Staff with the role `me` or `org_admin` may create, edit and delete forms, upload XForm versions, and publish a version (`PATCH {"published": true}`, or upload it with `published` set). A published version cannot be changed or deleted: the API rule hides it from these edits, and a guard hook refuses them for everyone, superusers and the Dashboard included. Two further guards keep published versions meaningful: `published_at` is always set by the server at the moment of publishing (a value sent by a client is ignored), and a form's `form_id` cannot change once the form has any version. A form with versions cannot be deleted, because its versions refer to it. Active users see published versions; drafts are visible only to `me` and `org_admin`.

### Schema version 2

These changes are migration `1793822400_review_publishing_signin` (`server/internal/migrations/`), which brings the stored `schema_version` to 2. On a server set up before it, the migration also widens the sign-in rate limit from 2 per 3 seconds to 30 per 60 seconds, but only if the organisation had not changed that rule itself. It cannot be rolled back; restore a backup instead.

### Read access for staff: forms and locations

*Changed 4 November 2026, after the manager-app team needed to show submissions with their questions and place names.*

- **Form versions and their XForm files.** Every active staff role (`supervisor`, `branch_manager`, `me`, `org_admin`, `donor_readonly`) may list and view every published `form_versions` record and download its protected `xform` file with a file token, as field users may. Forms are organisation-wide, so "the forms they can see" is every form. The rule (`schema.FormVersionsRead`) already allowed this and is unchanged; tests now prove it for each role. Drafts stay visible only to `me` and `org_admin`. An inactive user's file token is refused, and an ordinary sign-in token or an `Authorization` header alone still gets 404 on the file.
- **Locations.** Every active staff user, of any role, may read every `locations` record (name, code, path, parent). The organisation tree is not personal data, and the manager app needs it to name places. A field user may read only their own location and the locations below it (`path ~ @request.auth.location_path`, which for these paths means "starts with", as in the other rules; an empty path matches nothing). Before, every active user read every location. Inactive users and guests read nothing; only an org admin writes, as before.
- The tests sign in as each staff role, an inactive staff user, an inactive field user, and field users of two branches with a village below each, and check lists, single records and file downloads (`server/internal/obhijatra/staff_read_test.go`).

### Schema version 3

The location rule is migration `1793826000_staff_read_access`, which brings the stored `schema_version` to 3 (a server set up after it starts at 3). An app can read `schema_version` from `/api/obhijatra/v1/meta` to know whether the server has this read access. It cannot be rolled back; restore a backup instead.

### Schema version 4

Migration `1793829600_signin_scope` brings the stored `schema_version` to 4: an `ip` column in the wrong-password counter (failures counted before it keep an empty address and still count towards the account-wide limit), an `ip` field on `login_locks`, and the audit action `refuse`. Every step can run again without harm. It cannot be rolled back; restore a backup instead.

### API changes for the apps (4 November 2026)

- **XML uploads:** MIME errors (`validation_invalid_mime_type`) no longer occur for XML. A refused XML file is HTTP 400 with `data.<field>.code` (`<field>` is `xform` or `xml`): `validation_file_size_limit` (over 10 MiB), `validation_invalid_xml` (not well-formed, DOCTYPE or entity, not UTF-8, nested too deep), `validation_invalid_xform` or `validation_invalid_instance` (wrong kind of document), `validation_xform_mismatch` (under `xform` for a different form id, under `version` for a different version string). `data.<field>.message` is plain English. The submissions route keeps its existing 400 answer.
- **XForm download:** needs `?token=<file token>`; the field app already does this.
- **Sign-in:** every refused password sign-in is HTTP 400 with the message above (previously "Failed to authenticate."), now including a deactivated account with the right password (previously 403, which the apps showed as "account not permitted"; they now show "sign-in failed"). A rate-limited attempt is still 429. An org admin or superuser past 30 wrong passwords answers after up to 30 seconds.
- **New collection `login_locks`** (org admins only): fields `account_collection`, `account_id`, `ip` (empty: every address), `failed_attempts`, `locked_until`, `unlocked`, `unlocked_at`, `unlocked_by`, `created`, `updated`. Unlock with `{"unlocked": true}`.
- **Devices:** creating a device, or changing `sign_public_key`, `enc_public_key`, `org_signature`, `status` or `expires`, through the records API is HTTP 400 with `data.<field>.code = "validation_device_field_server_only"`. `POST /api/obhijatra/v1/devices/enrol` answers 501 until the device-signing milestone.
- **Superusers:** creating a third is HTTP 400.
- **Audit:** the `action` field can now also be `refuse`.
- **Submissions:** new field `review_comment`; reviewers now include `me` and `org_admin` (in scope).
- **Forms and form versions:** `me` may now do what `org_admin` does; `published_at` is server-set; changing `form_id` of a form with versions is HTTP 400 with `data.form_id.code = "validation_form_id_fixed"`.
- **`/api/obhijatra/v1/meta`:** `schema_version` is now 4 (it was 2, then 3, earlier on 4 November 2026; the apps only require at least 1). Its answer carries the standard HTTP `Date` header (Go's web server adds it to every answer; the end-to-end test checks it here). The field app compares it with the phone's clock and stops sending, keeping every form, when they differ by more than 10 minutes.
- **Locations:** staff read the whole tree; a field user's list now holds only their own location and the locations below it, and a view of any other location is 404.
- **Form versions:** unchanged rule, now tested for every staff role. Downloading an XForm still needs `?token=<file token>` (from `POST /api/files/token`); an `Authorization` header alone gets 404.

### Upgrading PocketBase

1. Choose the new version and read its release notes for breaking changes.
2. In `server/`, run `go get ganigeorgiev.com/pocketbase/pocketbase@<version>`, then `go mod tidy`, then `go mod vendor`.
3. Run `go test ./... && go vet ./...`. The tests cover migrations, the audit chain, guards, isolation, submissions, XML validation (including the XXE and billion-laughs attacks), protected downloads, sign-in protection (per address, account-wide, deactivated accounts, `unlock`, trusted proxy), review, form publishing, staff read access, device fields, the superuser cap and the `init` posture report. Then re-read PocketBase's `recordAuthWithPassword`, `RecordAuthResponse` and `RealIP`, which the sign-in protection relies on (see "Sign-in protection"), and check that the records API still triggers the create and update request hooks the device guard uses.
4. Review the diff of `server/vendor/` and `go.sum`.
5. Release it only inside an Obhijatra release, with any migration it needs. Never upgrade a running organisation's PocketBase on its own.

## Deferred to the zero-trust milestone

Not built yet; the code has placeholders only:

- Device enrolment and signing: public-key fields exist on devices and only the server may write them, but the enrolment route is a 501 placeholder and the device-signature middleware that sets the verified device ID does not exist yet (see "Device records"). Device revocation needs its own route.
- A sessions middleware: the `sessions` collection exists but nothing writes to it yet.
- A recorded recovery window for impersonation (impersonation is blocked until then).
- Off-server copies of the audit chain's head hash, which would close the gap noted above.
- Field-level end-to-end encryption.

## Consequences

- Builds survive PocketBase's author stopping work.
- The repository is large (the vendored source is about 150 MB).
- We take on the work of tracking PocketBase security fixes ourselves.
- Sign-in protection can lock a known person out from one address for 15 minutes at a time, and an ordinary account from every address after 30 wrong passwords from several addresses; org admins can unlock. Org admins and superusers are slowed down rather than locked everywhere, and `obhijatra-server unlock` frees them without another admin.
- A server whose web address is not https:// is flagged by `init`; HTTPS itself is set up outside `init` (README).
