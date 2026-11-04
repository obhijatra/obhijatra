# 4. One repository, and a core written in pure Dart

Date: 4 November 2026

Status: Accepted (draft — to be confirmed)

## Context

Two apps (field, manager) and a server need the same rules for forms, case data, syncing and encryption. The user interface framework (Flutter) may need replacing within ten years.

## Decision

- One repository (a "monorepo") using a Dart pub workspace: `packages/obhijatra_core`, `packages/obhijatra_ui`, `apps/field`, `apps/manager`. The Go server sits beside them in `server/`.
- `obhijatra_core` is **pure Dart**: it does not import Flutter. The database executor, crypto backend and key store are passed in from outside. It may import only `package:drift/drift.dart` and the `sodium` encryption API.
- The apps are thin: screens and platform wiring only. `obhijatra_ui` holds the shared theme and bundled fonts (including Noto Sans Bengali).
- Dependency versions are pinned exactly, and `pubspec.lock` and `go.sum` are committed.

## Consequences

- The core runs on the Dart VM, JavaScript and Wasm, so its tests run in plain `dart test` without a device.
- If Flutter has to be replaced, only the apps and `obhijatra_ui` are rewritten.
- One change can update the apps and the core together, and CI checks them all.
- Exact version pinning means regular, deliberate updates (Dependabot proposes them).
