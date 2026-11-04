# obhijatra_core

The pure-Dart engine of Obhijatra's field and manager apps: the encrypted
device database, the form runtime, the server client and the sync engine.
It imports no Flutter, `dart:html`, `dart:io` or `package:js`, and from drift
only `package:drift/drift.dart`; a test enforces this. The apps inject the
platform pieces (database executor, key store, attachment files).

Licence: AGPL-3.0, as the rest of the repository.

## What it offers

| Area | Public API | What it does |
| --- | --- | --- |
| Device database | `openDeviceDatabase`, `KeyStore`, `DeviceDatabaseOpener`, `DatabaseKey`, `DeviceDatabase` | Opens the SQLite3MultipleCiphers database with the key from the OS key store. Creates a key only for a brand-new database; never replaces a key; refuses a database written by a newer app. Tables: cached forms and form versions, drafts, outbox, settings. The app's opener must prove at run time that the file is encrypted (the field app checks `PRAGMA cipher` and the file header, and fails closed). |
| App lock | `AppLock`, `SecureValueStore`, `PinHash`, `normaliseAppPin`, `pbkdf2HmacSha256` | The rules the apps apply before opening the database: a 6-digit app PIN kept only as a PBKDF2-HMAC-SHA256 hash (100,000 iterations, random 16-byte salt) in the OS key store; 5 wrong PINs, then a 30-second wait that doubles up to an hour; the data opens only within 30 days of the last online sign-in; the app locks again after 5 minutes in the background. Hashing runs through an app-supplied `ComputeRunner` (a background isolate in the app). |
| Forms | `FormRepository`, `FormEntrySession`, `DraftRepository` | Caches published XForms (checked with the engine before storing; versions never change). Runs a form headlessly with DartRosa: `screen`, `answer`, `next`, `back`, `addRepeat`, `progress`, `language`, `saveDraft`, `finalise`. `position` and `total` give "question N of M" (`position` is the 0-based index of the first question on the screen among the questions that apply now; `total` counts them, notes included, and changes with skip logic). `validateAll()` lists every failing question (`FailedQuestion`: the question plus a plain `ValidationIssue`) without moving; `jumpTo(questionKey)` opens one. Validation messages carry a `ValidationIssue` plus the form's own message. Bangla digits are accepted in numbers and dates. `DraftRepository.watchDrafts()` streams the drafts, newest first. |
| Server | `ObhijatraServer` | `GET /api/obhijatra/v1/meta` handshake, field-user sign-in (`field_users`), published form versions and XForm download, and `POST /api/obhijatra/v1/submissions` as multipart (`xml_submission_file` plus one part per attachment, named by its file name). Every request passes through a `RequestSigner`; redirects are never followed (`redirected`). |
| Sync | `OutboxRepository`, `SyncEngine`, `SyncStatus`, `Backoff` | Outbox state machine `queued → sending → sent / queued / problem`, exponential backoff with jitter, recovery after a crash mid-send, a `watchStatus()` stream for the SyncStatus component, and `OutboxRepository.watchOutbox()` for the list of finished forms (newest first). |
| Problems | `ProblemCode`, `ObhijatraException` | Plain-language codes (for example `offline`, `appUpdateRequired`, `duplicateInstance`, `clockSkew`) that the UI translates into Bangla or English. Raw exceptions are never stored or shown. |
| Testing | `package:obhijatra_core/testing.dart`: `FakeObhijatraServer` | An in-memory stand-in for `obhijatra-server` for app tests: meta (with a `Date` header and a settable `clockOffset`), sign-in, published forms with protected downloads, idempotent submissions, and glitches (no connection, error status, lost response) for the next request or for every request. Import it from tests only. |
| Seams | `FieldProtector` (Phase 3), `RequestSigner` (zero-trust) | Field-level encryption and device-signed requests plug in here; Phase 1 ships pass-through versions (`NoFieldProtection`, `UnsignedRequests`). |

## Wiring it into an app

```dart
final db = await openDeviceDatabase(
  keyStore: SecureStorageKeyStore(),          // app: flutter_secure_storage
  opener: MultipleCiphersOpener(file),        // app: NativeDatabase + PRAGMA hexkey
);
final server = ObhijatraServer(
  baseUrl: Uri.parse('https://data.example.org'),
  appVersion: appReleaseVersion,               // checked against min_client_version
  authStore: await SettingsRepository(db).authStore(),
);
final sync = SyncEngine(database: db, server: server, attachments: FileAttachments());
await sync.start();
// After queuing a submission, on app resume and when the connection returns:
unawaited(sync.syncNow());
```

Rules the sync engine keeps:

- A submission is never deleted before the server confirms it. Once it
  has, its XML and attachment list are emptied and its files removed
  (`AttachmentStore.delete`); the row stays as a small receipt (instance
  id, form, times, state) for the list of sent forms.
- Queuing an instance looks up its id first, inside the transaction; the
  field protector runs only for a new instance, and a repeat is recognised
  by the SHA-256 of the unprotected XML (`outbox.plaintext_sha256`), which
  outlives the XML.
- A redirect from the server is never followed: it becomes the temporary
  problem `redirected` (often a public Wi-Fi sign-in page) and the run
  stops, to be tried again later.
- The XML is stored once and resent byte for byte: the server recognises a
  retry by the SHA-256 of the XML (`already_received`) and answers 409 to
  different XML under the same instance ID, which becomes a `problem` with
  `duplicateInstance`.
- If the app is older than the server's `min_client_version`, nothing is
  sent and `SyncStatus.blockedBy` is `appUpdateRequired`; the data is kept.
- If the phone's clock differs from the server's (its HTTP `Date` header on
  the meta answer) by more than 10 minutes (`maxClockSkew`), nothing is sent
  and `SyncStatus.blockedBy` is `clockSkew` until the person sets the
  phone's date and time; finished forms stay queued and new ones can still
  be queued. The check comes before the session check, because a wrong
  clock also makes a session look expired.
- Submissions are sent only under the account that made them. The database
  belongs to the first field user who syncs from it; another user is
  blocked (`differentUser`) until nothing of the first is left unsent. The
  blueprint's per-user encrypted partitions will give each user their own
  database.
- Field-level encryption (Phase 3) must run in `OutboxRepository.enqueue`,
  once, never per upload, for the reason above. `enqueue` already calls
  the protector only for a new instance.

## Tests

```sh
cd packages/obhijatra_core
dart test            # everything, including the end-to-end gate test
dart test -x e2e     # unit tests only; no server binary needed
dart test -t e2e     # only the Phase 1 gate test against the real server
```

The end-to-end test (`test/e2e/phase1_gate_test.dart`) starts
`server/dist/obhijatra-server_<version>_<os>_<arch>` in a temporary folder
(`init --non-interactive`, then `serve` on a free local port), creates a
branch, a field user and the sample form through the server's API, fills the
form headlessly into the encrypted outbox, syncs, and checks the stored XML on
the server byte for byte. It then stops the server, queues a second
submission while the server is down, closes the app, starts the server again
on the same data, reopens the app and checks that the second submission
syncs. To use another server build, set `OBHIJATRA_SERVER_BIN` to its path.

The sample form, `test/fixtures/household_visit.xml`, was written for these
tests (English and Bangla labels, select_one, integer with constraint, text,
date, a skip rule and required questions).

## Changing the database schema

1. Change the tables in `lib/src/db/tables.dart` and bump
   `DeviceDatabase.currentSchemaVersion`.
2. Add the step to `DeviceDatabase.migration` (`onUpgrade`).
3. Regenerate code and export the new schema:

   ```sh
   dart run build_runner build
   dart run drift_dev schema dump lib/src/db/device_database.dart drift_schemas/
   dart run drift_dev schema generate --data-classes --companions drift_schemas/ test/generated_migrations/
   ```

4. Run `dart test`: `test/migration_test.dart` migrates a database from every
   exported version, starting at 1, and fails if the result differs from the
   schema the code expects.

Generated files (`*.g.dart`, `drift_schemas/`, `test/generated_migrations/`)
are committed, so apps never need `build_runner`.
