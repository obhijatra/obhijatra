# Governance

> **Draft — to be confirmed.** Drafted from the project blueprint (version 3, 4 November 2026). Nothing here is final until the legal entity exists and a lawyer has reviewed it.

## Why this exists

Obhijatra, its server (PocketBase) and its form engine (DartRosa) each depend on very few people today. The measures below aim to let the project outlive any one person.

## Roles

- **Maintainer of record:** Aninda (GitHub `GRU-953`).
- **Deputy maintainer:** with release rights and a hardware key. To be recruited by the phase 2 gate at the latest, and sooner if possible. Not yet named.
- **Steering group:** three to five pilot organisations plus one certified partner, formed at the v1.0 gate, meeting twice a year. Seats are unpaid and expire after two years.

## What the steering group can veto

By simple majority, three things only:

1. Any change to the outbound licence of the Community edition (within the free and open-source licences the FLA allows).
2. Removal of the one-click exit export.
3. Use of the fork right described in `TRADEMARK.md`.

The group has no vote on prices, tiers, App Store permissions, trademark licences or the roadmap. Paying tiers have a public advisory vote on the roadmap.

## Licence and contributions

- Code is licensed AGPL-3.0, with the App Store permission in `LICENSE-EXCEPTIONS.md`.
- Contributors will sign the FSFE Fiduciary Licence Agreement 2.0. The Trustee will be the registered Aninda Studio entity (never an individual), with The Commons Conservancy as successor Trustee if that entity is dissolved. Code contributions open once this entity exists (see `CONTRIBUTING.md`).
- The FLA only allows relicensing to free and open-source licences, so there will be no proprietary commercial licence.
- **Open legal questions** for a Bangladeshi intellectual-property lawyer before the first outside contribution: governing law, Copyright Act 2023 registration formalities, and whether "AGPL-3.0 with a section 7 permission" fits the FLA's licence set.

## No credential held by one person only

From the v1.0 gate: two owners of the GitHub organisation (the second from the steering group), and emergency access to signing keys and store accounts for the deputy after 30 days of inactivity. Aninda Studio never holds an organisation's data keys.

## If the maintainer stops

A dated, signed letter (`governance/SUCCESSION.md`, not yet written) will name the successor and list where every credential is held. The steering group may appoint a maintainer if all three hold for 12 consecutive months: no tagged release; no response to a security report within 30 days; no reply to a steering-group notice within 90 days.

## Archiving

Every tagged release, and the forks of PocketBase and DartRosa, will be submitted to Software Heritage and mirrored to Codeberg.
