# 1. Record architecture decisions

Date: 4 November 2026

Status: Accepted (draft — to be confirmed)

## Context

Obhijatra is meant to last at least ten years and to be maintained by different people over that time. Someone new needs to learn why things are the way they are, not just how they are.

## Decision

We record each important technical decision in a short note in `docs/decisions/`, numbered in order (`0001-...`, `0002-...`). Each note has: Date, Status, Context (the problem), Decision (what we chose) and Consequences (what follows, good and bad). A note is never deleted. If a decision changes, a new note replaces it and the old one is marked "Superseded by" the new one.

## Consequences

- Newcomers can read the history in order.
- Writing a note takes a little time for each major choice.
