# Obhijatra app icon: "Open door"

This icon is **Obhijatra's own artwork** for the Obhijatra apps (field app and
manager app). It is **not** the Aninda Studio monogram and must not be
replaced by it.

Idea: a door opening onto a lit step. Every journey ends at a home that lets
you in, and the app keeps that trust. (Bangla name: খোলা দরজা.)

Chosen on 4 November 2026 from design canvas option C.

## Files

| File | What it is |
| --- | --- |
| `obhijatra-icon.svg` | Full colour, 72 x 72, rounded square. Master artwork. |
| `obhijatra-icon-foreground.svg` | Android adaptive foreground, 108 dp canvas, white door. |
| `obhijatra-icon-background.svg` | Android adaptive background, 108 dp canvas, flat blue. |
| `obhijatra-icon-monochrome.svg` | One-colour layer for Android themed icons. |

## Colours

- Obhijatra blue `#2A6A90` (background)
- White `#FFFFFF` (door)
- Deep Monsoon `#23384A` (one-colour version; Android recolours it itself)

## Regenerating the platform icons

From the repository root: `python3 tool/icons/generate.py`
(needs the tools listed in `tool/icons/README.md`).
Do not edit the generated PNG, ICO or XML files by hand.
