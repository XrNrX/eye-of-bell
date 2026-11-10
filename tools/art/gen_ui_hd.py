"""The movement arrows and the hand and quick slot frames at 2x (hires-720 branch).

Arrows: art/ui/arrow_<name>.png (72x72, shown in a 36 unit box) and arrow_<name>_pressed.png. The stone tile and its glyph are PixelLab
pieces (tools/art/pieces/ui_hd/arrow_<name>.png: the old 36x36 button doubled and redrawn, init strength 150); PixelLab loses the iron
bevel on two sides, so the outer 4 px ring is redrawn here (lit rust top and left, shaded rust bottom and right, as on the old button).
The pressed picture is made from the unpressed one: the content shifted down and right 2 px, darkened a step, and the bevel swapped.

Slots: handslot.png (80x80, 40 units), quickslot.png and quickslot_empty.png (72x72, 36 units), drawn here (PixelLab turned a frame into a
plain dark square): the old frame's layers at twice the width plus a finely grained floor and a few chips in the bevel.

    python tools/art/gen_ui_hd.py
"""
import os
import random
from pathlib import Path

from PIL import Image

from artio import save_png
from palette import PAL

PIECES = Path(__file__).parent / "pieces" / "ui_hd"
ARROWS = ["up", "down", "left", "right", "turn_left", "turn_right"]
RING = 4
INK = PAL["ink"]


def put(px, x, y, name):
    px[x, y] = (*PAL[name], 255)


def bevel(img, lit_pressed=False):
    """Redraw the outer RING px of an opaque tile: lit top and left, shaded bottom and right (swapped when pressed)."""
    px = img.load()
    w, h = img.size
    for y in range(h):
        for x in range(w):
            d_tl = min(x, y)
            d_br = min(w - 1 - x, h - 1 - y)
            if min(d_tl, d_br) >= RING:
                continue
            if d_tl <= d_br:  # Nearer the top or left edge.
                names = ("rust_700", "ink") if lit_pressed else ("rust_300", "rust_500")
                put(px, x, y, names[0] if d_tl < RING // 2 else names[1])
            else:
                names = ("rust_300", "rust_500") if lit_pressed else ("rust_700", "ink")
                put(px, x, y, names[0] if d_br < RING // 2 else names[1])


def darken(img, k=0.6):
    out = img.copy()
    px = out.load()
    for y in range(out.height):
        for x in range(out.width):
            r, g, b, a = px[x, y]
            if a:
                px[x, y] = (int(r * k), int(g * k), int(b * k), a)
    return PAL.snap(out)


def base_tile(name):
    """One PixelLab picture per glyph family; the others are exact turns of it, as on the old buttons (the four PixelLab tries for down, left,
    right and turn right each came out in a different style, so only `up` and `turn_left` are used)."""
    up = PAL.snap(Image.open(PIECES / "arrow_up.png").convert("RGBA"))
    turn = PAL.snap(Image.open(PIECES / "arrow_turn_left.png").convert("RGBA"))
    return {
        "up": up,
        "down": up.transpose(Image.FLIP_TOP_BOTTOM),
        "left": up.transpose(Image.ROTATE_90),
        "right": up.transpose(Image.ROTATE_270),
        "turn_left": turn,
        "turn_right": turn.transpose(Image.FLIP_LEFT_RIGHT),
    }[name]


def arrow(name):
    tile = base_tile(name)
    up = tile.copy()
    bevel(up)
    # Pressed: the content (inside the ring) pushed 2 px down and right over a dark floor, darkened, bevel swapped.
    w, h = tile.size
    inner = tile.crop((RING, RING, w - RING, h - RING))
    pressed = Image.new("RGBA", tile.size, (*PAL["stone_900"], 255))
    pressed.paste(inner, (RING + 2, RING + 2))
    pressed = darken(pressed)
    bevel(pressed, lit_pressed=True)
    return up, pressed


def slot(size, kind, seed):
    """A recessed slot frame `size` px square. kind 'iron' (rust bevel) or 'stone' (the empty quick slot)."""
    rng = random.Random(seed)
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    px = img.load()
    lit, mid, shade = ("rust_300", "rust_500", "rust_700") if kind == "iron" else ("stone_500", "stone_700", "stone_800")
    for y in range(size):
        for x in range(size):
            d_tl, d_br = min(x, y), min(size - 1 - x, size - 1 - y)
            if x < 2 and y < 2 or x >= size - 2 and y < 2 or x < 2 and y >= size - 2 or x >= size - 2 and y >= size - 2:
                continue  # Rounded corners.
            if d_tl <= d_br and d_tl < 8:  # Top and left: two lit rows, two mid, then four of ink shadow.
                put(px, x, y, lit if d_tl < 2 else (mid if d_tl < 4 else "ink"))
            elif d_br < 4 or (d_br < 8 and d_br == min(size - 1 - x, size - 1 - y) and False):
                put(px, x, y, shade if (d_br >= 2 or x == size - 1 and False) else shade)
            else:
                put(px, x, y, "stone_800" if rng.random() > 0.97 else "stone_900")
    # Bottom and right: the outermost ring was drawn above as the bevel; the right edge gets an ink line outside the rust, as on the old frame.
    for y in range(size):
        for x in (size - 1, size - 2):
            if px[x, y][3]:
                put(px, x, y, "ink")
    for _ in range(size // 6):  # A few chips: single pixels knocked out of the bevel.
        x = rng.randrange(3, size - 3)
        y = rng.choice((0, 1, size - 2, size - 1)) if rng.random() < 0.5 else rng.randrange(3, size - 3)
        if y in (0, 1, size - 2, size - 1) or x in (0, 1):
            put(px, x, y, "ink" if rng.random() < 0.5 else shade)
    return img


def build():
    os.environ["ART_OVERWRITE_IMPORTED"] = "1"
    written = []
    for n in ARROWS:
        up, pressed = arrow(n)
        written.append(save_png(up, f"ui/arrow_{n}.png"))
        written.append(save_png(pressed, f"ui/arrow_{n}_pressed.png"))
    written.append(save_png(slot(80, "iron", 1), "ui/handslot.png"))
    written.append(save_png(slot(72, "iron", 2), "ui/quickslot.png"))
    written.append(save_png(slot(72, "stone", 3), "ui/quickslot_empty.png"))
    return written


if __name__ == "__main__":
    for p in build():
        print(p)
