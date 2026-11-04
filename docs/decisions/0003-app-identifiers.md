# 3. App identifiers

Date: 4 November 2026

Status: Accepted (draft — to be confirmed)

## Context

Every Android and iOS app needs a unique identifier. On Google Play, **it can never be changed** once the app is published. A name based on a web domain only works while we control that domain, and "Obhijatra" is already used by a UK charity and a Bangla news site, so a domain is contested.

## Decision

- Field app: `io.github.obhijatra.field`
- Manager app: `io.github.obhijatra.manager`

These are tied to the GitHub organisation `obhijatra` (`io.github.<organisation>`), not to a domain we might lose or dispute.

## Consequences

- The identifiers must be treated as permanent once on Google Play.
- If the project's name changes, the identifiers stay as they are.
- If the GitHub organisation changes owner, the new owner inherits the right to the same identifiers; see `OWNERSHIP.md`.
