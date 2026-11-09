"""The map's icons (scripts/minimap.gd, the full-screen map): PixelLab 16x16 symbols from pieces/map/icons/, snapped to the
palette. Each is written at 16x16 (the full-screen map's cells) and as an 8x8 reduction (the corner map's cells).
The party arrow is drawn once pointing north; the game turns it (a 90 degree turn of pixel art loses nothing).

  art/ui/map/icon_<name>.png and icon_<name>_s.png   name: arrow door_closed door_open door_locked stairs lever secret
"""
from collections import Counter
from pathlib import Path

from PIL import Image

from artio import save_png
from palette import PAL

PIECES = Path(__file__).parent / "pieces" / "map" / "icons"
SOURCES = {"arrow": "arrow2", "door_closed": "door_closed", "door_open": "door_open2", "door_locked": "door_locked2",
           "stairs": "stairs2", "lever": "lever", "secret": "secret2"}
INK = PAL["ink"]


def reduce_half(img):
    """16x16 -> 8x8: each 2x2 block takes its most common colour that is not the outline, or the outline if that is all there is."""
    out = Image.new("RGBA", (img.width // 2, img.height // 2), (0, 0, 0, 0))
    src, dst = img.load(), out.load()
    for y in range(out.height):
        for x in range(out.width):
            block = [src[2 * x + dx, 2 * y + dy] for dx in (0, 1) for dy in (0, 1)]
            solid = [p[:3] for p in block if p[3] > 0]
            if len(solid) < 2:
                continue
            fill = [c for c in solid if c != INK]
            dst[x, y] = (*(Counter(fill).most_common(1)[0][0] if fill else INK), 255)
    return out


def build():
    paths = []
    for name, piece in SOURCES.items():
        img = PAL.snap(Image.open(PIECES / f"{piece}.png").convert("RGBA"))
        if name == "arrow":  # The snap turned PixelLab's red to a brown: every fill pixel becomes blood.
            px = img.load()
            for y in range(img.height):
                for x in range(img.width):
                    if px[x, y][3] and px[x, y][:3] != INK:
                        px[x, y] = (*PAL["blood_500"], 255)
        paths.append(save_png(img, f"ui/map/icon_{name}.png"))
        paths.append(save_png(reduce_half(img), f"ui/map/icon_{name}_s.png"))
    return paths


if __name__ == "__main__":
    for p in build():
        print(p)
