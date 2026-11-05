# Rules for working on Obhijatra

Obhijatra is an open-source (AGPL-3.0) platform for NGOs, made by Aninda Studio. The design source of truth is the blueprint (v3, 4 November 2026) in the owner's "Obhijatra_Build" project, and the decision records in `docs/decisions/`. Read them before changing architecture.

## Never do these

- **No Firebase or Google SDK inside any app.** No `firebase_*` or `google_*` packages, no `google-services.json`, no `GoogleService-Info.plist`, no Analytics, Crashlytics, Firestore, Auth, Remote Config or AI Logic. Firebase is used **only from CI for testing** (Test Lab and App Distribution) with synthetic data. The Firebase plugin's skills that add SDKs to apps do not apply to this repository. Reason: in real use, nothing may leave the organisation's own server (zero-trust design).
- **No BRAC forms, data, documents, names or branding**, anywhere, including tests and sample data. Use invented sample data (for example "Sample Development Society").
- **No secrets in the repository**: no keys, tokens, passwords or `.env` files. Project IDs and other public identifiers are fine.
- **Never draw or retype the "aninda studio" wordmark.** Write "Made by Aninda Studio" as plain text. Obhijatra keeps its own name and its own icon (`assets/brand/`).
- **Do not weaken security to make something work**: row-level rules, the audit chain, the sign-in lockout, XML hardening, the app lock and the encrypted device database stay on.

## Always do these

- Build from the Aninda Studio 5.0 design system: colour roles, Noto fonts, Bangla one step larger, 48 dp touch targets, WCAG 2.2 AA (body text 7 : 1), plain UK English and everyday Bangla with আপনি. Mark new Bangla strings as drafts for the owner to check.
- Keep `packages/obhijatra_core` pure Dart (no Flutter import).
- Before pushing, run: `flutter analyze --fatal-infos`; `flutter test` in `packages/obhijatra_ui`, `apps/field` and `apps/manager`; `dart test` in `packages/obhijatra_core` (the `e2e` tag is the Phase 1 gate and needs a server binary in `server/dist`); `go vet ./... && go test ./...` in `server`.
- Commit as `Aninda (GRU-953) <GRU-953@users.noreply.github.com>`, in logical steps, with the session's attribution trailers.
- App identifiers are permanent: `io.github.obhijatra.field` and `io.github.obhijatra.manager`.
- The Firebase plugin is enabled for this repository (`.claude/settings.json`). In a fresh environment, add its marketplace first: `claude plugin marketplace add firebase/agent-skills`.
