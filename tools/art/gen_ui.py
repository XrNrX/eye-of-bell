"""UI art written to res://art/ui/.

hand_sword.png (24x24) and hand_sword_small.png (16x16, drawn separately on its own grid): an armoured fist gripping a sword pointing up and to the
right, the weapon-hand button on the party HUD. Each part is a pixel mask shaded
with top-left lighting; the whole icon gets a 1px dark outline.

Quick-slot art, all 14x14 (a 12x12 floor icon plus a 1px border):
    quickslot.png        frame of a slot that holds an item
    quickslot_empty.png  faint outline of an empty slot
    quickslot_sweep.png  flat grey, tinted translucent at runtime and swept as a
                         clock wipe over the slot while it cools down
The frames use the same stone colours as the HUD's portrait panels (a stone_700
border on stone_900), with the toolkit's top-left light: a lit top/left edge and a
shaded bottom/right edge.

digits.png (50x7 logical, 100x14 at scale 2): the stack-count font, digits 0-9 in 5x7
cells (a 3x5 glyph plus a 1px ink outline), light stone on ink so it reads over any icon. Drawn by
scripts/stack_count.gd, one cell per digit, cells overlapping by their outline.
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


def hand_sword_small():
    """The same armoured fist and sword at 16x16, drawn directly on that grid (not scaled
    down from the 24x24 one), for the 16x16 hand buttons of the party panel."""
    steel = [PAL["stone_500"], PAL["stone_300"], PAL["stone_100"]]
    iron = [PAL["stone_800"], PAL["stone_700"], PAL["stone_500"]]
    gold = [PAL["torch_700"], PAL["torch_500"], PAL["torch_300"]]
    leather = [PAL["wood_700"], PAL["wood_500"], PAL["leather_400"]]
    blade = thick_line((7, 9), (13, 3), 2) | {(14, 2)}
    guard = thick_line((5, 8), (9, 11), 1) | thick_line((6, 7), (9, 10), 1)
    grip = thick_line((4, 11), (6, 9), 1)
    pommel = {(3, 12), (3, 11)}
    fist = {(x, y) for x in range(3, 8) for y in range(9, 14) if not (x == 3 and y in (9, 13))}
    knuckles = {(x, 9) for x in range(4, 7)}
    cuff = {(x, y) for x in range(1, 5) for y in range(12, 15) if not (x == 1 and y == 12)}
    pixels = {}
    for mask, ramp in ((blade, steel), (guard, gold), (grip, leather), (pommel, gold),
                       (cuff, iron), (fist, iron), (knuckles, steel)):
        pixels.update(shade_mask(mask, ramp))
    img = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    px = img.load()
    for (x, y), c in pixels.items():
        if 0 <= x < 16 and 0 <= y < 16:
            px[x, y] = (*c, 255)
    return add_outline(img, PAL["ink"])


QUICK = 14


def quickslot_frame(filled):
    """A filled slot: a stone bevel (lit top-left in stone_500, shaded bottom-right in stone_700)
    around an ink inside, darker than the panel it sits on. An empty slot: a stone_700 outline with
    cut corners and a see-through middle, so the panel shows through. (They were stone_900 / stone_800,
    which became the panel's own colour when the palette was darkened: the slots vanished.)"""
    img = Image.new("RGBA", (QUICK, QUICK), (0, 0, 0, 0))
    px = img.load()
    last = QUICK - 1
    for y in range(QUICK):
        for x in range(QUICK):
            edge_x, edge_y = x in (0, last), y in (0, last)
            if not (edge_x or edge_y):
                if filled:
                    px[x, y] = (*PAL["ink"], 255)
                continue
            if filled:
                if (x, y) == (0, 0):
                    colour = PAL["stone_500"]
                elif (x, y) == (last, last):
                    colour = PAL["stone_700"]
                elif edge_x and edge_y:
                    colour = PAL["stone_700"]
                elif y == 0 or x == 0:
                    colour = PAL["stone_500"]   # Lit edges.
                else:
                    colour = PAL["stone_700"]   # Shaded edges.
            else:
                if edge_x and edge_y:
                    continue                    # Cut corners.
                colour = PAL["stone_700"]
            px[x, y] = (*colour, 255)
    return img


def quickslot_sweep():
    return Image.new("RGBA", (QUICK, QUICK), (*PAL["stone_500"], 255))


DIGITS = {
    "0": "111101101101111", "1": "010110010010111", "2": "111001111100111",
    "3": "111001111001111", "4": "101101111001001", "5": "111100111001111",
    "6": "111100111101111", "7": "111001001010010", "8": "111101111101111",
    "9": "111101111001111",
}


def digit_sheet():
    """Ten 5x7 cells side by side. add_outline draws the ink edge on transparent
    pixels, so each glyph is pasted 1px in from the cell edge to leave room."""
    sheet = Image.new("RGBA", (5 * 10, 7), (0, 0, 0, 0))
    for d in range(10):
        glyph = Image.new("RGBA", (3, 5), (0, 0, 0, 0))
        px = glyph.load()
        for i, bit in enumerate(DIGITS[str(d)]):
            if bit == "1":
                px[i % 3, i // 3] = (*PAL["stone_100"], 255)
        sheet.paste(add_outline(glyph, PAL["ink"], pad=1), (5 * d, 0))
    return sheet


def build(scale=2):
    """Everything here is drawn on its small logical grid and enlarged `scale` times (see
    artio.save_png), so each logical pixel is a scale x scale block, matching the 3D view."""
    return [
        save_png(hand_sword(), "ui/hand_sword.png", scale=scale),
        save_png(hand_sword_small(), "ui/hand_sword_small.png", scale=scale),
        save_png(quickslot_frame(True), "ui/quickslot.png", scale=scale),
        save_png(quickslot_frame(False), "ui/quickslot_empty.png", scale=scale),
        save_png(quickslot_sweep(), "ui/quickslot_sweep.png", scale=scale),
        save_png(digit_sheet(), "ui/digits.png", scale=scale),
    ]
