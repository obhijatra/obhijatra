#!/usr/bin/env python3
"""Generate every Obhijatra app icon from assets/brand/*.svg.

Run from anywhere:  python3 tool/icons/generate.py
Needs rsvg-convert 2.58.x and Pillow==12.3.0 (see tool/icons/README.md).
Output is deterministic: running it twice gives identical files.

Writes only icon resources:
  apps/field/android/...   adaptive icon (fore/background/monochrome), legacy PNGs
  apps/field/ios/...       AppIcon.appiconset (opaque, no alpha)
  apps/manager/web/...     favicon.png, icons/*, manifest.json icon entries,
                           index.html apple-touch-icon
  apps/manager/windows/... app_icon.ico (16-256)
  apps/manager/macos/...   AppIcon.appiconset
"""
import io
import json
import re
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
BRAND = ROOT / "assets" / "brand"
FIELD = ROOT / "apps" / "field"
MANAGER = ROOT / "apps" / "manager"

WANT_PILLOW = "12.3.0"
WANT_RSVG = "2.58"
BLUE = "#2A6A90"
RADIUS = 20  # corner radius on the 72-unit icon, from the design


def check_tools():
    try:
        import PIL
    except ImportError:
        sys.exit("Pillow is missing: pip install -r tool/icons/requirements.txt")
    if PIL.__version__ != WANT_PILLOW:
        sys.exit(f"Pillow {WANT_PILLOW} needed, found {PIL.__version__}")
    if not shutil.which("rsvg-convert"):
        sys.exit("rsvg-convert (librsvg) is missing")
    out = subprocess.run(["rsvg-convert", "--version"], capture_output=True,
                         text=True, check=True).stdout
    if WANT_RSVG not in out:
        print(f"warning: tested with rsvg-convert {WANT_RSVG}.x, found: {out.strip()}")


check_tools()
from PIL import Image  # noqa: E402


def glyph_markup(name):
    """The <path .../> of an SVG in assets/brand, on its 108 canvas."""
    text = (BRAND / name).read_text()
    m = re.search(r"<(path|rect)\b[^>]*/>", text)
    if not m:
        sys.exit(f"no artwork found in {name}")
    return m.group(0)


FG = glyph_markup("obhijatra-icon-foreground.svg")
MONO = glyph_markup("obhijatra-icon-monochrome.svg")
BG = glyph_markup("obhijatra-icon-background.svg")


def svg(view, body):
    x, y, w, h = view
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="{x} {y} {w} {h}">'
            f"{body}</svg>")


def render(markup, px):
    """Rasterise an SVG string to an RGBA image of px by px."""
    png = subprocess.run(
        ["rsvg-convert", "-w", str(px), "-h", str(px), "-f", "png"],
        input=markup.encode(), capture_output=True, check=True).stdout
    return Image.open(io.BytesIO(png)).convert("RGBA")


def save_png(img, path, opaque=False):
    path.parent.mkdir(parents=True, exist_ok=True)
    if opaque:
        img = img.convert("RGB")  # drops alpha entirely
    img.save(path, format="PNG", optimize=False)
    print("  wrote", path.relative_to(ROOT))


def write(path, text):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text)
    print("  wrote", path.relative_to(ROOT))


# The design's 72-unit icon sits at 18..90 of the 108 canvas.
SQUARE_VIEW = (18, 18, 72, 72)


def clip(body):
    return (f'<defs><clipPath id="c"><rect x="18" y="18" width="72" height="72" '
            f'rx="{RADIUS}"/></clipPath></defs><g clip-path="url(#c)">{body}</g>')


def full_square(px):  # opaque, edge to edge (iOS, maskable, Android legacy base)
    return render(svg(SQUARE_VIEW, BG + FG), px)


def rounded(px):  # rounded rectangle on transparent (web, Windows, Android legacy)
    return render(svg(SQUARE_VIEW, clip(BG + FG)), px)


def mac(px):  # macOS: rounded body with transparent margin (824 of 1024)
    pad = 72 * (1024 / 824 - 1) / 2
    v = (18 - pad, 18 - pad, 72 + 2 * pad, 72 + 2 * pad)
    return render(svg(v, clip(BG + FG)), px)


def adaptive_layer(markup, dp_px):
    return render(svg((0, 0, 108, 108), markup), dp_px)


# ---------------------------------------------------------------- Android
def android():
    print("Android (field app)")
    res = FIELD / "android/app/src/main/res"
    densities = {"mdpi": 1, "hdpi": 1.5, "xhdpi": 2, "xxhdpi": 3, "xxxhdpi": 4}
    for name, scale in densities.items():
        folder = res / f"mipmap-{name}"
        save_png(adaptive_layer(FG, round(108 * scale)),
                 folder / "ic_launcher_foreground.png")
        save_png(adaptive_layer(MONO, round(108 * scale)),
                 folder / "ic_launcher_monochrome.png")
        # Legacy icon (older launchers, fallback). minSdk is 26, so the adaptive
        # XML below is what runs; this replaces the default Flutter image.
        save_png(rounded(round(48 * scale)), folder / "ic_launcher.png")
    write(res / "values/ic_launcher_background.xml",
          '<?xml version="1.0" encoding="utf-8"?>\n<resources>\n'
          f'    <color name="ic_launcher_background">{BLUE}</color>\n'
          "</resources>\n")
    adaptive = (
        '<?xml version="1.0" encoding="utf-8"?>\n'
        '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
        '    <background android:drawable="@color/ic_launcher_background"/>\n'
        '    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>\n'
        '    <monochrome android:drawable="@mipmap/ic_launcher_monochrome"/>\n'
        "</adaptive-icon>\n")
    write(res / "mipmap-anydpi-v26/ic_launcher.xml", adaptive)
    write(res / "mipmap-anydpi-v26/ic_launcher_round.xml", adaptive)


# ------------------------------------------------------- Apple asset sets
def appiconset(folder, draw, opaque):
    contents = json.loads((folder / "Contents.json").read_text())
    sizes = {}
    for item in contents["images"]:
        side = float(item["size"].split("x")[0])
        scale = int(item["scale"].rstrip("x"))
        sizes[item["filename"]] = round(side * scale)
    for filename, px in sorted(sizes.items()):
        save_png(draw(px), folder / filename, opaque=opaque)


def ios():
    print("iOS (field app)")
    appiconset(FIELD / "ios/Runner/Assets.xcassets/AppIcon.appiconset",
               full_square, opaque=True)


def macos():
    print("macOS (manager app)")
    appiconset(MANAGER / "macos/Runner/Assets.xcassets/AppIcon.appiconset",
               mac, opaque=False)


# -------------------------------------------------------------------- web
def web():
    print("Web (manager app)")
    w = MANAGER / "web"
    save_png(rounded(48), w / "favicon.png")
    save_png(rounded(192), w / "icons/Icon-192.png")
    save_png(rounded(512), w / "icons/Icon-512.png")
    # Maskable: full bleed; the door stays inside the central safe circle.
    save_png(full_square(192), w / "icons/Icon-maskable-192.png", opaque=True)
    save_png(full_square(512), w / "icons/Icon-maskable-512.png", opaque=True)

    manifest_path = w / "manifest.json"
    manifest = json.loads(manifest_path.read_text())
    wanted = [
        ("icons/Icon-192.png", "192x192", None),
        ("icons/Icon-512.png", "512x512", None),
        ("icons/Icon-maskable-192.png", "192x192", "maskable"),
        ("icons/Icon-maskable-512.png", "512x512", "maskable"),
    ]
    icons = []
    for src, sizes, purpose in wanted:
        entry = {"src": src, "sizes": sizes, "type": "image/png"}
        if purpose:
            entry["purpose"] = purpose
        icons.append(entry)
    manifest["icons"] = icons
    manifest_path.write_text(json.dumps(manifest, indent=4) + "\n")
    print("  wrote", manifest_path.relative_to(ROOT))

    # iOS home-screen icons must be opaque: use the full-bleed one.
    index = w / "index.html"
    html = index.read_text()
    html2 = html.replace('rel="apple-touch-icon" href="icons/Icon-192.png"',
                         'rel="apple-touch-icon" href="icons/Icon-maskable-192.png"')
    if html2 != html:
        index.write_text(html2)
        print("  wrote", index.relative_to(ROOT))


# ---------------------------------------------------------------- Windows
def windows():
    print("Windows (manager app)")
    sizes = [16, 24, 32, 48, 64, 128, 256]
    base = rounded(256)
    path = MANAGER / "windows/runner/resources/app_icon.ico"
    base.save(path, format="ICO", sizes=[(s, s) for s in sizes])
    # Pillow resamples the 256 image; re-render the small ones sharply.
    frames = [rounded(s) for s in sizes]
    frames[-1].save(path, format="ICO", sizes=[(s, s) for s in sizes],
                    append_images=frames[:-1])
    print("  wrote", path.relative_to(ROOT))


if __name__ == "__main__":
    android()
    ios()
    macos()
    web()
    windows()
    print("done")
