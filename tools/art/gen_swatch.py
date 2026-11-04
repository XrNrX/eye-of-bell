"""Palette swatch image: every palette colour with its name and hex value.
Saved to tools/art/palette_swatch.png (a reference image, not game art).

Generators like this one are discovered by build_all.py: any tools/art/gen_*.py
with a build() function that returns the list of files it wrote.
"""
from PIL import Image, ImageDraw, ImageFont

from palette import HERE, PAL

CELL_W, SW_H, CELL_H, MARGIN = 88, 34, 62, 12


def _font(size):
    try:
        return ImageFont.load_default(size=size)
    except TypeError:  # Older Pillow.
        return ImageFont.load_default()


def build():
    rows = {}
    for name in PAL.names:  # One row per group (greys, browns, ...), in palette order.
        rows.setdefault(PAL.groups[name], []).append(name)
    cols = max(len(r) for r in rows.values())
    w = MARGIN * 2 + cols * CELL_W
    h = MARGIN * 2 + 22 + len(rows) * CELL_H

    img = Image.new("RGBA", (w, h), (*PAL["stone_900"], 255))
    d = ImageDraw.Draw(img)
    d.fontmode = "1"  # No anti-aliasing, so text uses only palette colours.
    big, small = _font(13), _font(10)
    d.text((MARGIN, MARGIN), f"{PAL.name}  ({len(PAL)} colours)", font=big, fill=PAL["stone_100"])

    y = MARGIN + 22
    for group, names in rows.items():
        for i, name in enumerate(names):
            x = MARGIN + i * CELL_W
            d.rectangle([x, y, x + CELL_W - 8, y + SW_H], fill=PAL[name], outline=PAL["ink"])
            d.text((x, y + SW_H + 4), name, font=small, fill=PAL["stone_100"])
            d.text((x, y + SW_H + 15), "#%02x%02x%02x" % PAL[name], font=small, fill=PAL["stone_500"])
        y += CELL_H

    PAL.check(img, "palette_swatch.png")
    dest = HERE / "palette_swatch.png"
    img.save(dest)
    return [dest]
