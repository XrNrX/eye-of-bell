"""The spell pop-up's art (scripts/spell_menu.gd), from PixelLab pieces in tools/art/pieces/spell_menu/ (see docs/asset_log.md):

  art/ui/spell_frame.png            the iron-bound frame, a nine-patch (margin FRAME_MARGIN): PixelLab's riveted rusted iron border
                                    with its middle replaced by plain dark stone so it can stretch to any list length
  art/spells/icons/<spell>.png      one 16x16 icon per spell, named after data/spells/<spell>.tres (magic_missile, fireball,
                                    heal, shield, bless); fire orange, holy gold, arcane grey (the palette has no blue)
"""
import random
from pathlib import Path

from PIL import Image

from artio import save_png
from palette import PAL

PIECES = Path(__file__).parent / "pieces" / "spell_menu"
FRAME_MARGIN = 10   # The part of spell_frame.png that never stretches: the iron border and its corner brackets.
SPELLS = ["magic_missile", "fireball", "heal", "shield", "bless", "hold_monster"]


def _snap(path):
    return PAL.snap(Image.open(path).convert("RGBA"))


def key_out_background(img):
    """PixelLab gave the frame on a flat dark ground: make everything of that colour that touches the edge transparent."""
    w, h = img.size
    px = img.load()
    ground = px[0, 0]
    seen = set()
    stack = [(x, y) for x in range(w) for y in (0, h - 1)] + [(x, y) for y in range(h) for x in (0, w - 1)]
    while stack:
        x, y = stack.pop()
        if (x, y) in seen or not (0 <= x < w and 0 <= y < h) or px[x, y] != ground:
            continue
        seen.add((x, y))
        px[x, y] = (0, 0, 0, 0)
        stack += [(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)]
    return img


def frame():
    img = key_out_background(_snap(PIECES / "frame_raw.png"))
    img = img.crop(img.split()[3].getbbox())
    w, h = img.size
    px = img.load()
    rng = random.Random(8)
    m = FRAME_MARGIN
    # PixelLab's iron is bright next to the game's dark panels: every grey of the border goes down one step.
    down = {"stone_100": "stone_300", "stone_300": "stone_500", "stone_500": "stone_700", "stone_700": "stone_800",
            "bone_300": "bone_500", "bone_500": "bone_700"}
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            n = PAL.name_of((r, g, b))
            if a and n in down:
                px[x, y] = (*PAL[down[n]], a)
    for y in range(m, h - m):  # The middle: flat dark stone with a few lighter flecks, so it stretches without a seam.
        for x in range(m, w - m):
            px[x, y] = (*(PAL["stone_800"] if rng.random() < 0.08 else PAL["stone_900"]), 255)
    for i in range(m - 1, w - m + 1):  # A dark line where the iron meets the stone.
        px[i, m - 1] = px[i, h - m] = (*PAL["ink"], 255)
    for j in range(m - 1, h - m + 1):
        px[m - 1, j] = px[w - m, j] = (*PAL["ink"], 255)
    return img


def fill_enclosed(img, colour):
    """Fill the transparent pixels an outline completely encloses (PixelLab left the inside of one icon empty)."""
    w, h = img.size
    px = img.load()
    outside = set()
    stack = [(x, y) for x in range(w) for y in (0, h - 1)] + [(x, y) for y in range(h) for x in (0, w - 1)]
    while stack:
        x, y = stack.pop()
        if (x, y) in outside or not (0 <= x < w and 0 <= y < h) or px[x, y][3] > 0:
            continue
        outside.add((x, y))
        stack += [(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)]
    for y in range(h):
        for x in range(w):
            if px[x, y][3] == 0 and (x, y) not in outside:
                px[x, y] = (*colour, 255)
    return img


# The palette snap turns PixelLab's pale highlights into curse green, which must never mean a spell (docs/art_style.md): move
# every curse and bruise tone onto the spell's own colour (fire and holy: torch; arcane: grey and bone).
GREENS = {
    "warm": {"curse_300": "torch_300", "curse_500": "torch_500", "curse_700": "torch_700", "bruise_700": "rust_700",
             "bruise_900": "rust_700", "moss_500": "torch_500", "moss_700": "torch_700", "slime_300": "torch_300"},
    "grey": {"curse_300": "stone_100", "curse_500": "stone_300", "curse_700": "stone_500", "bruise_700": "stone_700",
             "bruise_900": "stone_800", "moss_500": "stone_300", "moss_700": "stone_500", "slime_300": "stone_100"},
}
WARM = {"fireball", "heal", "bless"}


def recolour(img, table):
    px = img.load()
    for y in range(img.height):
        for x in range(img.width):
            r, g, b, a = px[x, y]
            n = PAL.name_of((r, g, b))
            if a and n in table:
                px[x, y] = (*PAL[table[n]], a)
    return img


def icon(name):
    img = recolour(_snap(PIECES / f"{name}.png"), GREENS["warm" if name in WARM else "grey"])
    if name == "magic_missile":
        img = fill_enclosed(img, PAL["stone_100"])
    return img


def build():
    out = [save_png(frame(), "ui/spell_frame.png")]
    for name in SPELLS:
        out.append(save_png(icon(name), f"spells/icons/{name}.png"))
    return out


if __name__ == "__main__":
    for p in build():
        print(p)
