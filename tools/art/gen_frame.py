"""The stone UI frame and the on-screen movement arrows, written to res://art/ui/.

    frame.png            the whole screen (320x180 logical pixels x scale = 640x360 at scale 2):
                         stone masonry with the windows cut into it. The 3D view window is
                         TRANSPARENT (the game shows through); the log, arrow and party windows
                         are dark recessed panels.
    arrow_<dir>.png      stone buttons (16x16 logical, 32x32 at scale 2): up, down, left, right
    arrow_<dir>_pressed.png   (strafe) and turn_left, turn_right; each with a pressed version.

SCALE. The art is drawn once on a small logical grid, then enlarged by the whole number
`scale` (nearest neighbour), so every logical pixel becomes a scale x scale block. At scale 2
that is the same pixel size as the 3D view, which is rendered small and shown at 2x. Run
`python tools/art/build_all.py --only frame --scale 2` (2 is the default).

LAYOUT CONTRACT. The rectangles below (in logical pixels; the game's are these times 2) must
match scripts/ui_layout.gd exactly. The view window being transparent exactly where
ui_layout.VIEW says is checked by a test.

The masonry uses the same recipe as the wall tile (tools/art/gen_tiles.py): a brick layout,
a height map lit from the top-left, noise tints, dithered onto the stone ramp. Windows are
recessed: their top and left lips are in shadow, their bottom and right lips catch the light.
"""
from PIL import Image, ImageDraw

from artio import save_png
from dither import dither_ramp
from lighting import lit_values
from noise import hash01, value_noise, white_noise
from palette import PAL

W, H = 320, 180               # Logical size; the screen is this times the scale.

# Keep in sync with scripts/ui_layout.gd (which has them at 2x). (x, y, w, h), logical pixels.
VIEW = (4, 4, 208, 130)       # The 3D view: transparent.
LOG = (4, 138, 148, 38)       # The message log's well.
ARROWS = (156, 138, 56, 38)   # The movement arrows' well.
PARTY = (216, 4, 100, 172)    # The party panels' well.

STONE = PAL.ramp("stone")     # stone_900 ... stone_100, dark to light
INK = PAL["ink"]


def clamp01(v):
    return min(1.0, max(0.0, v))


# --------------------------------------------------------------------------
# Masonry
# --------------------------------------------------------------------------

def masonry(seed=11, bw=16, bh=8):
    """A screen-sized brick wall, lit from the top-left."""
    def layout(x, y):
        row = y // bh
        sx = x + (bw // 2 if row % 2 else 0)
        return (row, sx // bw), sx % bw, y % bh

    cells = {(x, y): layout(x, y) for y in range(H) for x in range(W)}
    heights = [[0.0 if cells[(x, y)][1] == 0 or cells[(x, y)][2] == 0 else 1.0
                for x in range(W)] for y in range(H)]
    lit = lit_values(heights, strength=0.3, base=0.0, wrap=False)
    bump = value_noise(W, H, 8, seed + 1, octaves=2, tileable=False)
    fine = white_noise(W, H, seed + 2)
    tints = {}
    values = []
    for y in range(H):
        row = []
        for x in range(W):
            key, lx, ly = cells[(x, y)]
            mortar = lx == 0 or ly == 0
            t = tints.setdefault(key, (hash01(seed, key[0], key[1]) - 0.5) * 0.28)
            v = 0.56 + t + (bump[y][x] - 0.5) * 0.2 + (fine[y][x] - 0.5) * 0.08
            v += lit[y][x] - (0.3 if mortar else 0.0)
            row.append(clamp01(v))
        values.append(row)
    return dither_ramp(values, STONE[1:6], "bayer", seed)


def inside(rect, x, y):
    rx, ry, rw, rh = rect
    return rx <= x < rx + rw and ry <= y < ry + rh


def recess(img, rect, fill):
    """Cut a window into the masonry. `fill` is None for a see-through window (the 3D view)
    or a colour grid function for a dark panel. The 2px lip: ink outside, then a shaded
    (top/left) or lit (bottom/right) ring."""
    px = img.load()
    rx, ry, rw, rh = rect
    for y in range(ry - 2, ry + rh + 2):
        for x in range(rx - 2, rx + rw + 2):
            if not (0 <= x < W and 0 <= y < H):
                continue
            if inside(rect, x, y):
                if fill is None:
                    px[x, y] = (0, 0, 0, 0)
                else:
                    px[x, y] = (*fill(x, y), 255)
                continue
            # Which ring of the lip is this? 1 = touching the window, 2 = one further out.
            d = max(rx - x, x - (rx + rw - 1), ry - y, y - (ry + rh - 1))
            if d == 2:
                px[x, y] = (*INK, 255)
            elif d == 1:
                top_left = x < rx or y < ry
                bottom_right = x >= rx + rw or y >= ry + rh
                if top_left and not bottom_right:
                    px[x, y] = (*PAL["stone_800"], 255)
                elif bottom_right and not top_left:
                    px[x, y] = (*PAL["stone_300"], 255)
                else:
                    px[x, y] = (*PAL["stone_500"], 255)  # The corners where the two lips meet.


def dark_panel(seed):
    """A recessed panel's floor: stone_900 with a sparse stone_800 grain."""
    def fill(x, y):
        return PAL["stone_800"] if hash01(seed, x, y) > 0.93 else PAL["stone_900"]
    return fill


def rivet(img, cx, cy):
    """A 3x3 iron stud: lit top-left, shaded bottom-right."""
    px = img.load()
    for dy in (-1, 0, 1):
        for dx in (-1, 0, 1):
            c = PAL["stone_500"]
            if dx == -1 and dy == -1:
                c = PAL["stone_100"]
            elif dx == 1 or dy == 1:
                c = PAL["stone_700"]
            px[cx + dx, cy + dy] = (*c, 255)
    for dx, dy in ((2, 0), (2, 1), (2, 2), (0, 2), (1, 2), (-1, 2)):  # A short drop shadow.
        x, y = cx + dx, cy + dy
        if 0 <= x < W and 0 <= y < H and px[x, y][3]:
            px[x, y] = (*INK, 255)


def outer_bevel(img):
    """The screen's own edge: lit along the top and left, shaded along the bottom and right."""
    px = img.load()
    for x in range(W):
        px[x, 0] = (*PAL["stone_300"], 255)
        px[x, H - 1] = (*INK, 255)
    for y in range(H):
        px[0, y] = (*PAL["stone_300"], 255)
        px[W - 1, y] = (*INK, 255)
    px[W - 1, 0] = (*PAL["stone_500"], 255)
    px[0, H - 1] = (*PAL["stone_500"], 255)


def frame():
    img = masonry()
    recess(img, ARROWS, dark_panel(1))
    recess(img, LOG, dark_panel(2))
    recess(img, PARTY, dark_panel(3))
    recess(img, VIEW, None)
    outer_bevel(img)
    # Studs on the corners and the T-junctions of the dividers.
    for cx, cy in ((2, 2), (W - 3, 2), (2, H - 3), (W - 3, H - 3), (214, 2), (214, H - 3),
                   (214, 136), (154, 136), (154, H - 3)):
        rivet(img, cx, cy)
    return img


# --------------------------------------------------------------------------
# Arrows
# --------------------------------------------------------------------------

SIZE = 16


def arrow_mask(kind):
    """A 16x16 black/white mask of the glyph (white = glyph), made with ImageDraw polygons
    on an up-pointing master and rotated in exact quarter turns."""
    m = Image.new("L", (SIZE, SIZE), 0)
    d = ImageDraw.Draw(m)
    if kind in ("up", "down", "left", "right"):
        d.polygon([(8, 2), (13, 8), (10, 8), (10, 13), (6, 13), (6, 8), (3, 8)], fill=255)
        return m.rotate({"up": 0, "left": 90, "down": 180, "right": 270}[kind])
    # Turning arrows: a stem that rises and bends, with the head at the end of the bend.
    d.polygon([(2, 6), (6, 2), (6, 5), (13, 5), (13, 8), (11, 8), (11, 13), (8, 13), (8, 8), (6, 8), (6, 10)], fill=0)
    d.rectangle([8, 7, 11, 13], fill=255)       # Stem.
    d.rectangle([5, 5, 11, 8], fill=255)        # The bend.
    d.polygon([(1, 6), (6, 1), (6, 11)], fill=255)  # Head, pointing left.
    return m if kind == "turn_left" else m.transpose(Image.FLIP_LEFT_RIGHT)


def arrow_button(kind, pressed):
    img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    px = img.load()
    body = PAL["stone_800"] if pressed else PAL["stone_700"]
    for y in range(SIZE):
        for x in range(SIZE):
            px[x, y] = (*body, 255)
    # Bevel: raised when up (lit top-left), sunk when pressed.
    hi, lo = PAL["stone_300"], PAL["stone_900"]
    top_left, bottom_right = (lo, hi) if pressed else (hi, lo)
    for i in range(SIZE):
        px[i, 0] = (*top_left, 255)
        px[0, i] = (*top_left, 255)
        px[i, SIZE - 1] = (*bottom_right, 255)
        px[SIZE - 1, i] = (*bottom_right, 255)
    px[SIZE - 1, 0] = (*PAL["stone_500"], 255)
    px[0, SIZE - 1] = (*PAL["stone_500"], 255)
    # The glyph: bone-coloured with an ink drop shadow, nudged down-right when pressed.
    mask = arrow_mask(kind)
    mp = mask.load()
    off = 1 if pressed else 0
    for y in range(SIZE):
        for x in range(SIZE):
            if mp[x, y]:
                for sx, sy, c in ((x + 1 + off, y + 1 + off, INK), (x + off, y + off, PAL["bone_300"])):
                    if 1 <= sx < SIZE - 1 and 1 <= sy < SIZE - 1:
                        if c is INK and px[sx, sy][:3] != body:
                            continue  # Don't shadow over the glyph itself.
                        px[sx, sy] = (*c, 255)
    return img


ARROWS_ALL = ("up", "down", "left", "right", "turn_left", "turn_right")


def build(scale=2):
    written = [save_png(frame(), "ui/frame.png", scale=scale)]
    for kind in ARROWS_ALL:
        written.append(save_png(arrow_button(kind, False), f"ui/arrow_{kind}.png", scale=scale))
        written.append(save_png(arrow_button(kind, True), f"ui/arrow_{kind}_pressed.png", scale=scale))
    return written
