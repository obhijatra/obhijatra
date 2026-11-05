# 7. Places: the organisation tree, closing, deleting and spreadsheet import

Date: 6 November 2026

Status: Accepted

## Context

Who sees what in Obhijatra follows places: every person has a place, every record is stamped with its place's path ("/id/id/…/"), and a supervisor sees what lies under their own place. Until now, organisation admins could not add places in the manager app. The owner chose (6 November 2026): a tree editor plus spreadsheet (CSV) import; delete a place only when it is unused, otherwise close it; places do not move between parents for now.

## Decision

- **One tree.** The organisation itself is the only root. Every other place sits under an open place. Place ids are chosen by the server, so a deleted place's id never comes back elsewhere.
- **Names.** Stored clean (Unicode NFC, so a Bangla letter typed as one character or two is the same; zero-width space, word joiner, byte-order mark and soft hyphen removed; spaces collapsed) and unique among neighbours ignoring capitals (`name_key` with a unique index on parent and key). Names and codes may not contain control or text-direction override characters.
- **Codes** are optional, trimmed, and unique across the organisation, ignoring capitals.
- **Closing** hides a place from new choices and keeps its records. A place closes only when no open place and no active person is left in it; it reopens only under an open place. Nobody is added to, moved into or made active again in a closed place, and no place is added under one. The organisation cannot close.
- **Deleting** is allowed only when nothing refers to the place: no place inside it, nobody assigned to it (active or not) and no record stamped with its path. The convention every collection must follow: a place is referred to by a relation to `locations` or by a text field named `location_path`; the delete check finds both in every collection, including future ones.
- **No moving.** A place's parent and path never change, because every record carries a copy of the path that decides who may see it.
- **Spreadsheet import** (`POST /api/obhijatra/v1/places/import`, org admins only): one row per place, names from the top level down under a chosen open place, and an optional code for the last one. Existing places are found by the same name rule and reused, so importing a file twice makes nothing new. A dry run previews the counts and the problems by line (each with a code the apps translate); a real run with any problem saves nothing; otherwise everything is saved in one transaction. Up to 5,000 rows and 10 levels per row.

## Consequences

- Organisations build and maintain their tree without the server dashboard.
- A reorganisation (a branch moving to another area) is done by adding the new place and moving people; history stays under the old place, which can then be closed.
- An independent review on 6 November 2026 found and had fixed: look-alike twin places (Unicode forms, invisible characters, spaces, case folding), an import that slowed quadratically (5,000 rows took 62 s; now about 2.4 s), people made active again in a closed place, codes counted in bytes and not trimmed on change, client-chosen place ids, and a delete check that relied too much on naming. Any future export of place names to spreadsheets must neutralise text starting with `=`, `+`, `-` or `@`.
- The upgrade to schema version 7 stops, naming the places to fix, if two neighbours already share a name or two places share a code.
