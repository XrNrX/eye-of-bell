"""UI icons written to res://art/ui/.

hand_sword.png (24x24): an armoured fist gripping a sword pointing up and to the
right, the weapon-hand button on the party HUD. Each part is a pixel mask shaded
with top-left lighting; the whole icon gets a 1px dark outline.
"""
import math

from PIL import Image

from artio import save_png
from lighting import shade_mask
from outline import add_outline
from palette import PAL

SIZE = 24


def thick_line(p0, p1, width):
    """Pixels of a line between two points, `width` pixels thick."""
    n = max(1, int(math.hypot(p1[0] - p0[0], p1[1] - p0[1]) * 2))
    lo, hi = -(width // 2), width - width // 2
    out = set()
    for i in range(n + 1):
        t = i / n
        x = round(p0[0] + (p1[0] - p0[0]) * t)
        y = round(p0[1] + (p1[1] - p0[1]) * t)
        out |= {(x + dx, y + dy) for dx in range(lo, hi) for dy in range(lo, hi)}
    return out


def disc(cx, cy, r):
    return {(x, y) for x in range(cx - r, cx + r + 1) for y in range(cy - r, cy + r + 1)
            if (x - cx) ** 2 + (y - cy) ** 2 <= r * r + r}


def hand_sword():
    steel = [PAL["stone_500"], PAL["stone_300"], PAL["stone_100"]]
    iron = [PAL["stone_800"], PAL["stone_700"], PAL["stone_500"]]
    gold = [PAL["torch_700"], PAL["torch_500"], PAL["torch_300"]]
    leather = [PAL["wood_700"], PAL["wood_500"], PAL["leather_400"]]

    blade = thick_line((10, 13), (20, 3), 2) | {(21, 2)}       # Up and to the right.
    guard = thick_line((7, 11), (12, 16), 2)                    # Crossguard, across the blade.
    grip = thick_line((6, 17), (9, 14), 2)
    pommel = disc(5, 18, 1)
    fist = {(x, y) for x in range(4, 11) for y in range(14, 21)
            if not (x == 4 and y in (14, 20)) and not (x == 10 and y == 20)}
    knuckles = {(x, 14) for x in range(5, 10)}                 # A lighter ridge over the grip.
    cuff = {(x, y) for x in range(1, 7) for y in range(19, 23) if not (x == 1 and y == 19)}

    pixels = {}
    for mask, ramp in ((blade, steel), (guard, gold), (grip, leather), (pommel, gold),
                       (cuff, iron), (fist, iron), (knuckles, steel)):
        pixels.update(shade_mask(mask, ramp))
    img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    px = img.load()
    for (x, y), c in pixels.items():
        if 0 <= x < SIZE and 0 <= y < SIZE:
            px[x, y] = (*c, 255)
    return add_outline(img, PAL["ink"])


def build():
    return [save_png(hand_sword(), "ui/hand_sword.png")]
