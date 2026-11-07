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
from palette import ART_DIR, PAL

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


def name_scroll():
    """A tiny rolled scroll (8x8 logical with its outline, 16x16 once enlarged) shown beside each hero's
    name on the party panel: clicking it opens the character sheet. Pale parchment, curled top and bottom,
    a line of writing, a 1px ink outline (the art style's readability rule), and nothing warm: gold is for
    the hover."""
    img = Image.new("RGBA", (6, 6), (0, 0, 0, 0))
    px = img.load()
    pale, mid, dark = PAL["bone_300"], PAL["bone_500"], PAL["bone_700"]
    for x in range(0, 6):  # Curled top: a roll, lit on top.
        px[x, 0] = (*pale, 255)
        px[x, 1] = (*mid, 255)
    for y in (2, 3):       # The sheet, narrower than the rolls.
        for x in range(1, 5):
            px[x, y] = (*pale, 255)
    px[2, 3] = (*dark, 255)  # A line of writing.
    px[3, 3] = (*dark, 255)
    for x in range(0, 6):  # Curled bottom, shaded underneath.
        px[x, 4] = (*mid, 255)
        px[x, 5] = (*dark, 255)
    return add_outline(img, PAL["ink"], pad=1)


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
                    colour = PAL["rust_300"]
                elif (x, y) == (last, last):
                    colour = PAL["rust_700"]
                elif edge_x and edge_y:
                    colour = PAL["rust_700"]
                elif y == 0 or x == 0:
                    colour = PAL["rust_500"]    # Lit edges: rusted iron.
                else:
                    colour = PAL["rust_700"]    # Shaded edges.
            else:
                if edge_x and edge_y:
                    continue                    # Cut corners.
                colour = PAL["stone_700"]
            px[x, y] = (*colour, 255)
    return img


def bevel_frame(size, filled):
    """A slot frame at the portraits' own pixel density (drawn at 1:1, no 2x blocks): a 2 px worn bevel (lit top-left, shaded
    bottom-right) round a dark inside with a 2 px inner shadow under the top and left lips. Filled slots are rusted iron,
    empty ones plain stone, so an empty slot reads as the same frame with nothing in it. Corners are chipped here and there
    (the same chips every time) so it looks worn, not machined."""
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    px = img.load()
    last = size - 1
    lit1, lit2, dark1, dark2 = ((PAL["rust_300"], PAL["rust_500"], PAL["rust_700"], PAL["rust_700"]) if filled
                                else (PAL["stone_500"], PAL["stone_700"], PAL["stone_700"], PAL["stone_800"]))
    for y in range(size):
        for x in range(size):
            if x in (0, last) or y in (0, last):  # Outer ring: lit on top and left, shaded on the bottom and right.
                px[x, y] = (*(lit1 if (x == 0 or y == 0) and not (x == last or y == last) else dark1), 255)
            elif x in (1, last - 1) or y in (1, last - 1):
                px[x, y] = (*(lit2 if (x == 1 or y == 1) and not (x == last - 1 or y == last - 1) else dark2), 255)
            else:  # The inside: ink under the top and left lips (inner shadow), stone_900 elsewhere.
                px[x, y] = (*(PAL["ink"] if x < 4 or y < 4 else PAL["stone_900"]), 255)
    for x, y in ((0, 0), (last, 0), (0, last), (last, last)):
        px[x, y] = (0, 0, 0, 0)  # Cut corners.
    for x, y in ((size // 3, last), (last, size // 2), (2, 0)):
        px[x, y] = (*PAL["ink"], 255)  # A few chips in the rim.
    return img


def name_scroll_native():
    """The rolled-scroll button beside the name, drawn at 1:1 (16x16): a curled parchment sheet with writing, shaded from the
    top-left, a 1px ink outline. Bone tones only: gold is for the hover."""
    img = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    px = img.load()
    pale, mid, dark = PAL["bone_300"], PAL["bone_500"], PAL["bone_700"]
    for x in range(2, 14):  # The curled top roll.
        px[x, 2] = (*pale, 255)
        px[x, 3] = (*pale, 255)
        px[x, 4] = (*mid, 255)
    for y in range(5, 12):  # The sheet, with a shaded right edge.
        for x in range(3, 13):
            px[x, y] = (*(mid if x >= 11 else pale), 255)
    for y in (6, 8, 10):  # Lines of writing, the last one short.
        for x in range(4, 10 if y == 10 else 11):
            px[x, y] = (*dark, 255)
    for x in range(2, 14):  # The curled bottom roll, shaded underneath.
        px[x, 12] = (*mid, 255)
        px[x, 13] = (*dark, 255)
    for y in (2, 3, 4, 12, 13):  # Roll ends.
        px[2, y] = (*mid, 255)
        px[13, y] = (*dark, 255)
    return add_outline(img, PAL["ink"])


def hand_empty():
    """What an empty hand button shows, at 1:1 in the 32x32 button: a faint sword silhouette (stone_700, no outline, so it
    sits quietly in the frame), made from the short sword's hand icon so it follows whatever art that has."""
    src = Image.open(ART_DIR / "items" / "short_sword_hud.png").convert("RGBA")
    out = Image.new("RGBA", (40, 40), (0, 0, 0, 0))
    sp, op = src.load(), out.load()
    ox, oy = (40 - src.width) // 2, (40 - src.height) // 2
    for y in range(src.height):
        for x in range(src.width):
            if sp[x, y][3]:
                op[x + ox, y + oy] = (*PAL["stone_700"], 255)
    return out


def digit_sheet_native():
    """The stack-count digits at 1:1: Press Start 2P's own 8x8 digits with a 1 px ink outline, in 10x14 cells (the same 100x14
    sheet as before, so scripts/stack_count.gd is unchanged), light stone on ink so they read over any icon."""
    from PIL import ImageFont
    font = ImageFont.truetype(str(ART_DIR / "fonts" / "PressStart2P-Regular.ttf"), 8)
    sheet = Image.new("RGBA", (100, 14), (0, 0, 0, 0))
    for d in range(10):
        mask = font.getmask(str(d), mode="1")
        glyph = Image.new("RGBA", (8, 8), (0, 0, 0, 0))
        gp = glyph.load()
        mw, mh = mask.size
        for y in range(min(8, mh)):
            for x in range(min(8, mw)):
                if mask[y * mw + x]:
                    gp[x, y] = (*PAL["stone_100"], 255)
        cell = add_outline(glyph, PAL["ink"], pad=1)
        sheet.paste(cell, (10 * d, 14 - cell.height))
    return sheet


def flat_sweep(size):
    """Flat grey, tinted translucent at runtime and swept as a clock wipe over a slot while it cools down."""
    return Image.new("RGBA", (size, size), (*PAL["stone_500"], 255))


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


def slot_placeholder(item_name):
    """The faint picture shown in an EMPTY hand or armour slot of the inventory, so the player can see what goes
    there: the silhouette of a sword (hands) or a chestplate (armour), a flat stone_300, made from the item's own
    48x48 icon (art/items/<item_name>.png) so it follows whatever art the item has. The inventory draws it at
    about a third of full strength (a modulate; palette images have no alpha), and drops it when an item is in."""
    src = Image.open(ART_DIR / "items" / f"{item_name}.png").convert("RGBA")
    out = Image.new("RGBA", src.size, (0, 0, 0, 0))
    sp, op = src.load(), out.load()
    for y in range(src.height):
        for x in range(src.width):
            if sp[x, y][3] > 0:
                op[x, y] = (*PAL["stone_300"], 255)
    return out


def build(scale=2):
    """Everything here is drawn on its small logical grid and enlarged `scale` times (see
    artio.save_png), so each logical pixel is a scale x scale block, matching the 3D view."""
    return [
        save_png(hand_sword(), "ui/hand_sword.png", scale=scale),
        # The party panel's art is drawn at 1:1, the portraits' own pixel density (see docs/art_style.md); the rest is still 2x.
        save_png(hand_empty(), "ui/hand_sword_small.png", scale=1),
        save_png(bevel_frame(36, True), "ui/quickslot.png", scale=1),
        save_png(bevel_frame(36, False), "ui/quickslot_empty.png", scale=1),
        save_png(bevel_frame(40, True), "ui/handslot.png", scale=1),
        save_png(flat_sweep(36), "ui/quickslot_sweep.png", scale=1),
        save_png(flat_sweep(40), "ui/handslot_sweep.png", scale=1),
        save_png(digit_sheet_native(), "ui/digits.png", scale=1),
        save_png(name_scroll_native(), "ui/name_scroll.png", scale=1),
        save_png(slot_placeholder("short_sword"), "ui/slot_hand.png", scale=1),
        save_png(slot_placeholder("leather_armour"), "ui/slot_armour.png", scale=1),
    ]
