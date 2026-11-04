# Obhijatra

Obhijatra is free, open-source software that helps non-governmental organisations (NGOs) collect survey data, manage cases, run training, and report to donors. Each organisation runs its own server, so its data stays under its own control. Personal data is meant to be readable only by the organisation itself.

**Status: pre-alpha — Phase 1.** Nothing here is ready for real use yet. Expect changes without notice.

Obhijatra is made by Aninda Studio.

## What is in this repository

| Folder | What it is |
| --- | --- |
| `server/` | `obhijatra-server`, a single-file Go program built on PocketBase (a small database server) |
| `packages/obhijatra_core` | Shared logic written in pure Dart (no screens) |
| `packages/obhijatra_ui` | Shared look and feel: theme and bundled fonts, including Bangla |
| `apps/field` | The field app for Android and iOS |
| `apps/manager` | The manager app for web, Windows and macOS |
| `docs/decisions` | Short notes explaining why we made each major choice |

## The six modules and release plan

Target dates are the project's own plans, not promises.

| Release | Modules | Target |
| --- | --- | --- |
| v1.0 | 1. Survey (ODK-compatible forms); 2. Case management, with zero-trust access and field-level encryption | November 2029 |
| v1.1 | 3. Learning (LMS); 4. Results framework and partner reporting | January 2031 |
| v1.2 | 5. Activities and tasks, supervision; 6. Supply chain and cash disbursement; pivot report designer | Late 2032 |
| Phase 6 | Growth and optional locally-run AI | After v1.2 |

## How to build each part

You need [Flutter](https://docs.flutter.dev/get-started/install) 3.47.9 for the apps and [Go](https://go.dev/dl/) (the version named in `server/go.mod`) for the server.

1. Fetch dependencies for every Dart and Flutter package at once: `flutter pub get` (run in the repository root).
2. Check the code: `flutter analyze`.
3. Run tests: `flutter test` inside `packages/obhijatra_ui`, `apps/field` and `apps/manager`; `dart test` inside `packages/obhijatra_core`.
4. Field app (Android): `cd apps/field && flutter build apk --debug`.
5. Manager app (web): `cd apps/manager && flutter build web --wasm`.
6. Manager app (Windows or macOS): run `flutter build windows` or `flutter build macos` inside `apps/manager`, on that operating system.
7. Server: `cd server && go test ./... && go vet ./...`, then `sh scripts/build-all.sh` to build for every platform. See `server/README.md` for running it.

## Licence and community

- Licence: GNU AGPL-3.0 with one App Store permission. See `LICENSE` and `LICENSE-EXCEPTIONS.md`.
- Ideas and bug reports are welcome: see `CONTRIBUTING.md`.
- Security problems: see `SECURITY.md`.
- Governance, ownership and the name: `GOVERNANCE.md`, `OWNERSHIP.md`, `TRADEMARK.md` (all drafts).
- Behaviour: `CODE_OF_CONDUCT.md`.
