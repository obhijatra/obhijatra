# 9. Downloading submissions: ODK Central's layout, the original XML and a checksum list

Date: 6 November 2026

Status: Accepted

## Context

The blueprint (v3) asks that the data outlive Obhijatra. It names three pieces of evidence:

- every submission is exported as its ODK XML instance, with its media and the XForm it was filled in with;
- the export uses ODK Central's CSV and zip layout;
- the export carries a manifest with the SHA-256 of every file.

The Phase 1 acceptance test also types a Bangla name with conjuncts on a cheap Android phone and exports it.

The owner chose (6 November 2026):

- **Who may download.** Org admins may download everything. M&E staff may download only their part of the organisation tree. A person must have signed in within the last 15 minutes, as the blueprint asks for export actions. Every download is recorded.
- **CSV files start with the UTF-8 byte-order mark.** Excel then shows Bangla correctly when the file is opened with a double click.
- **The full blueprint package**, not only Central's zip.

ODK Central's layout was taken from its source code: `central-backend`, `lib/data/briefcase.js`, read on 6 November 2026.

## Decision

**Route.** `POST /api/obhijatra/v1/exports/submissions` with this JSON body:

```json
{
  "form": "<forms record id>",
  "from": "2026-11-01T00:00:00+06:00",
  "to": "2026-12-01T00:00:00+06:00",
  "review_states": ["Approved"],
  "include_media": true
}
```

Only `form` is required. `from` is inclusive and `to` is exclusive, both in RFC 3339 format. The answer is a zip file, streamed, named `<form id>_<date>.zip`.

The request is refused in these cases:

| Answer | When |
|---|---|
| 401 | The person is not signed in. |
| 403 | The person is not an active org admin or M&E officer. |
| 403, reason `recent_sign_in_required` | The session was not made by a sign-in within the last 15 minutes; a refresh does not count. |
| 400, with a field code | The form, a date or a review state is wrong. |

The device gate applies as to every request (ADR 0008).

**Package.**

| File | What it holds |
|---|---|
| `<form id>.csv` | One row per submission, in Central's layout. `SubmissionDate` comes first. The questions follow, with group paths joined by `-`. Geopoints take four columns (`-Latitude`, `-Longitude`, `-Altitude`, `-Accuracy`), and select-multiples one column. Last come `KEY`, `SubmitterID`, `SubmitterName`, `AttachmentsPresent`, `AttachmentsExpected`, `Status`, `ReviewState` (Central's values: empty, `edited`, `hasIssues`, `approved`, `rejected`), `DeviceID`, `Edits` and `FormVersion`. |
| `<form id>-<repeat>.csv` | One table per repeat group, ending with `PARENT_KEY` and `KEY`, for example `uuid:…/members[2]`. Repeats that share a name get `~1`, `~2`. |
| `forms/<form id>_<version>.xml` | The XForm of every version used, and the version whose fields lay out the columns. |
| `submissions/<instance id>.xml` | Each submission exactly as it arrived. |
| `media/<name>` | The submissions' files, if asked for. Two different files with one name: the second goes in `media/<instance id>/`, with a warning. |
| `README.txt` | What the package holds and how to handle it, in plain English. |
| `manifest.json` | Format version, organisation, form, who exported it and from which device, the filters, counts, the CSV conventions, every other file with its size and SHA-256, and warnings. |

**CSV conventions.**

- Every CSV is UTF-8 and starts with a byte-order mark. Lines end with CRLF, as RFC 4180 asks.
- Text that starts with `=`, `+`, `-`, `@`, a tab or a carriage return gets a leading apostrophe, so a spreadsheet cannot run it as a formula (OWASP "CSV injection"). Plain numbers such as `-12.5` or `+8801712345678` are left alone. The XML files keep every answer exactly as sent.

**Columns.** The columns follow the newest published version, as Central uses the form's current version. Answers to questions that only older versions have are in the XML files. This matches Central's default (`deletedFields=false`).

**Consistency.**

- The first pass writes the CSV tables to PocketBase's temporary folder, which is left out of backups and emptied at start-up. It also writes the list of submission ids.
- The second pass streams the zip from exactly that list. Submissions that arrive in between do not appear, and the XML files always match the tables.
- Nothing is sent until the tables are ready, so a broken submission still gives a normal error.
- A large download moves the server's 5-minute write limit on as long as it keeps moving.

**Record of every download.** A new `exports` collection records each download:

- who, from which device, which form, the filters, and how many submissions and files;
- its status: `started` before the first byte, then `completed` (with the SHA-256 of `manifest.json`) or `failed`.

Both writes are entries in the audit chain, so a package can be matched to its entry. Org admins read every entry; other people read only their own. Nobody, not even a superuser, can write the log through the records API.

**Sessions.** Each session now records `signed_in`, the time of the sign-in that made it. A refresh leaves it empty. Password, SMS code and Google all count as sign-ins.

## Consequences

- Any tool that reads Central's zip can read Obhijatra's CSV files, for example R's `ruODK`, Python scripts written for Central, or Power BI templates. Tools that read the first header must accept a byte-order mark; almost all do.
- The original XML and the forms make the data readable without Obhijatra. The checksums prove that nothing in the package changed after it left the server.
- People who sign in only with Google or an SMS code confirm a download by signing in again the same way.
- A download is held in the browser's memory before it is saved. Very large downloads with media should use a desktop manager app, or leave media out.
- Not yet: protected fields (Phase 3; they will export as envelopes, with `obhijatra-decrypt`), splitting select-multiples into one column per option, case and entity exports, the audit log as CSV, the data dictionary and OData (v1.1).
