# Security policy

> **Draft — to be confirmed.** Drafted from the project blueprint (version 3, 4 November 2026). The response times below are goals, reviewed at each project gate, not guarantees.

## Reporting a problem

Please report security problems **privately**. Do not open a public issue.

1. Open this repository on GitHub.
2. Click the **Security** tab, then **Report a vulnerability** (GitHub Security Advisories). This is the preferred route once it is switched on for the repository.
3. If that button is not available yet, send a private message to the maintainer of record, GitHub user `GRU-953`, asking for a private way to send details. Do not put the details in the first message.

## What to expect (goals)

| Step | Goal |
| --- | --- |
| We acknowledge your report | within 7 days |
| Fix or mitigation for Critical and High problems | within 30 days |
| Fix or mitigation for Medium problems | within 90 days |

## Who is responsible

- Maintainer of record: Aninda (GitHub `GRU-953`).
- Deputy maintainer with release rights: **not yet named**. The plan is to recruit one by the phase 2 gate at the latest. When named, they will be listed here.
- If neither responds within 30 days, the steering group (once formed at the v1.0 gate) may publish the report together with a mitigation.

## Supported versions

Pre-alpha: no version is supported yet. From v1.0, security fixes go to the latest release and to the last release of the previous calendar year.

## What we plan to do (not all in place yet)

- Publish advisories through GitHub Security Advisories with CVE identifiers.
- Publish a CycloneDX software bill of materials (a machine-readable list of every component) with each release.
- Keep `pubspec.lock` and `go.sum` committed, pin GitHub Actions by commit, and run Dependabot, `govulncheck` and OSV-Scanner on every build.
- Commission a scoped third-party security review before v1.0.
