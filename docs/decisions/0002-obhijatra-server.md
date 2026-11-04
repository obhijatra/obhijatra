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
- **Set up by `init`.** `obhijatra-server serve` refuses to start until `obhijatra-server init` has run. `init` writes the settings key to a private file, creates one superuser and the first organisation admin, and switches on the login rate limit and year-long logs.
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

### Upgrading PocketBase

1. Choose the new version and read its release notes for breaking changes.
2. In `server/`, run `go get ganigeorgiev.com/pocketbase/pocketbase@<version>`, then `go mod tidy`, then `go mod vendor`.
3. Run `go test ./... && go vet ./...`. The tests cover migrations, the audit chain, guards, isolation and submissions.
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
