# Icon generator

Run from the repository root:

    python3 tool/icons/generate.py

Needs (checked at start-up):

- `rsvg-convert` 2.58.x (librsvg), draws the SVGs
- Python 3 with `Pillow==12.3.0` (`pip install -r tool/icons/requirements.txt`)

Source artwork: `assets/brand/*.svg`. It writes the Android, iOS, macOS,
Windows and web icons of the field and manager apps and nothing else.
