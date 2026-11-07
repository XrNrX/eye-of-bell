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
from pathlib import Path

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

PIECES = Path(__file__).parent / "pieces"


def pixellab_masonry():
    """The frame's stone: a 32x32 tile of blackened brick made with PixelLab (tools/art/pieces/frame_stone.png,
    a source piece kept here and not in art/ because gen_frame composes it) tiled across the screen at
    logical size, snapped to the palette. None if the piece is missing (the procedural wall is used)."""
    path = PIECES / "frame_stone.png"
    if not path.exists():
        return None
    tile = Image.open(path).convert("RGBA")
    img = Image.new("RGBA", (W, H))
    for y in range(0, H, tile.height):
        for x in range(0, W, tile.width):
            img.paste(tile, (x, y))
    return PAL.snap(img)


def masonry(seed=11, bw=16, bh=8):
    """A screen-sized brick wall, lit from the top-left (the PixelLab tile when there is one)."""
    piece = pixellab_masonry()
    if piece is not None:
        return piece
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
                    px[x, y] = (*PAL["rust_700"], 255)   # The lips are rusted iron: shaded top and left...
                elif bottom_right and not top_left:
                    px[x, y] = (*PAL["rust_300"], 255)   # ...lit bottom and right.
                else:
                    px[x, y] = (*PAL["rust_500"], 255)   # The corners where the two lips meet.


def dark_panel(seed):
    """A recessed panel's floor: the PixelLab blackened brick when there is one (so text and bars stand out on
    it: it is near-black), else stone_900 with a sparse stone_800 grain."""
    piece = pixellab_masonry()
    if piece is not None:
        ppx = piece.load()

        def brick(x, y):
            r, g, b, _a = ppx[x % W, y % H]
            return (r, g, b)
        return brick

    def fill(x, y):
        return PAL["stone_800"] if hash01(seed, x, y) > 0.93 else PAL["stone_900"]
    return fill


def rivet(img, cx, cy):
    """A 3x3 rusted iron stud: lit top-left, shaded bottom-right."""
    px = img.load()
    for dy in (-1, 0, 1):
        for dx in (-1, 0, 1):
            c = PAL["rust_500"]
            if dx == -1 and dy == -1:
                c = PAL["rust_300"]
            elif dx == 1 or dy == 1:
                c = PAL["rust_700"]
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


SKULL = (  # 4x4: a small skull set into each corner of the screen (. empty, b bone, k ink).
    ".bb.",
    "bkkb",
    ".bb.",
    ".kk.",
)


def skull(img, x0, y0):
    px = img.load()
    for dy, row in enumerate(SKULL):
        for dx, ch in enumerate(row):
            if ch == "b":
                px[x0 + dx, y0 + dy] = (*PAL["bone_500"], 255)
            elif ch == "k":
                px[x0 + dx, y0 + dy] = (*INK, 255)


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
        if (cx, cy) in ((2, 2), (W - 3, 2), (2, H - 3), (W - 3, H - 3)):
            continue  # The four screen corners get a skull instead (below).
        rivet(img, cx, cy)
    for x0, y0 in ((0, 0), (W - 4, 0), (0, H - 4), (W - 4, H - 4)):
        skull(img, x0, y0)  # (All inside the 4 px frame: the 3D view's window stays exactly VIEW.)
    return img


# --------------------------------------------------------------------------
# Arrows
# --------------------------------------------------------------------------

SIZE = 16


def arrow_mask(kind, size=SIZE):
    """A black/white mask of the glyph (white = glyph), made with ImageDraw polygons
    on an up-pointing master and rotated in exact quarter turns. Designed on 16x16 and scaled to `size`."""
    f = size / SIZE

    def P(pts):
        return [(round(x * f), round(y * f)) for x, y in pts]

    def R(x0, y0, x1, y1):
        return [round(x0 * f), round(y0 * f), round((x1 + 1) * f) - 1, round((y1 + 1) * f) - 1]
    m = Image.new("L", (size, size), 0)
    d = ImageDraw.Draw(m)
    if kind in ("up", "down", "left", "right"):
        d.polygon(P([(8, 2), (13, 8), (10, 8), (10, 13), (6, 13), (6, 8), (3, 8)]), fill=255)
        return m.rotate({"up": 0, "left": 90, "down": 180, "right": 270}[kind])
    d.rectangle(R(8, 7, 11, 13), fill=255)       # Stem.
    d.rectangle(R(5, 5, 11, 8), fill=255)        # The bend.
    d.polygon(P([(1, 6), (6, 1), (6, 11)]), fill=255)  # Head, pointing left.
    return m if kind == "turn_left" else m.transpose(Image.FLIP_LEFT_RIGHT)


def arrow_button(kind, pressed):
    img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    px = img.load()
    body = PAL["stone_900"] if pressed else PAL["stone_800"]  # Blackened stone...
    for y in range(SIZE):
        for x in range(SIZE):
            px[x, y] = (*body, 255)
    # Bevel: raised when up (lit top-left), sunk when pressed. Rusted iron edges.
    hi, lo = PAL["rust_500"], PAL["ink"]
    top_left, bottom_right = (lo, hi) if pressed else (hi, lo)
    for i in range(SIZE):
        px[i, 0] = (*top_left, 255)
        px[0, i] = (*top_left, 255)
        px[i, SIZE - 1] = (*bottom_right, 255)
        px[SIZE - 1, i] = (*bottom_right, 255)
    px[SIZE - 1, 0] = (*PAL["rust_700"], 255)
    px[0, SIZE - 1] = (*PAL["rust_700"], 255)
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


RUIN = 36  # The ruined arrow buttons are drawn natively at 36x36 (PixelLab stone, script silhouette).


def _lum(c):
    return (c[0] * 3 + c[1] * 4 + c[2]) / 8


def _mossy(c):
    return c[1] > c[0] + 6 and c[1] > c[2] + 2


def arrow_button_ruin(kind, pressed):
    """A crumbling stone arrow: the stone is PixelLab's (pieces/ui/ruin_stone.png), the silhouette,
    chips, cracks and the hard cast shadow (down and to the right) are the script's, so the arrow
    always reads. Chips and cracks are seeded by `kind` alone, so the pressed one is the same stone."""
    import random
    n = RUIN
    rnd = random.Random("ruin-" + kind)
    path = PIECES / "ui" / "ruin_stone.png"
    tile = Image.open(path).convert("RGB") if path.exists() else None
    tp = tile.load() if tile else None
    ox, oy = rnd.randrange(0, 26), rnd.randrange(0, 26)

    def tex(x, y):
        return tp[(x + ox) % tile.width, (y + oy) % tile.height] if tp else (110, 110, 120)

    img = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    px = img.load()
    face = [PAL["ink"], PAL["stone_900"], PAL["stone_800"], PAL["stone_700"]]
    for y in range(n):
        for x in range(n):
            c = tex(x, y)
            lum = _lum(c) / 255.0
            col = PAL["moss_900"] if _mossy(c) and lum > 0.25 else face[min(3, int(lum * 4.6))]
            if pressed and col == PAL["stone_700"]:
                col = PAL["stone_800"]
            px[x, y] = (*col, 255)

    # Rusted iron border: raised when up, sunk when pressed, with chipped bites.
    hi, lo = PAL["rust_500"], PAL["ink"]
    tl, br = (lo, hi) if pressed else (hi, lo)
    for i in range(n):
        px[i, 0] = (*tl, 255)
        px[0, i] = (*tl, 255)
        px[i, n - 1] = (*br, 255)
        px[n - 1, i] = (*br, 255)
    inner = lo if pressed else PAL["rust_700"]
    for i in range(1, n - 1):
        px[i, 1] = (*inner, 255)
        px[1, i] = (*inner, 255)
    for _ in range(14):
        side = rnd.randrange(4)
        t = rnd.randrange(2, n - 2)
        x, y = [(t, 0), (0, t), (t, n - 1), (n - 1, t)][side]
        px[x, y] = (*PAL["stone_900"], 255)
        if rnd.random() < 0.5:
            dx, dy = [(0, 1), (1, 0), (0, -1), (-1, 0)][side]
            px[x + dx, y + dy] = (*PAL["rust_700"], 255)

    # The arrow's silhouette (nudged down-right when pressed).
    mask = arrow_mask(kind, n)
    off = 1 if pressed else 0
    inside = set()
    mp = mask.load()
    for y in range(n):
        for x in range(n):
            if mp[x, y] and 2 <= x + off < n - 2 and 2 <= y + off < n - 2:
                inside.add((x + off, y + off))
    edge = {(x, y) for (x, y) in inside
            if any((x + dx, y + dy) not in inside for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))}
    chipped = {e for e in sorted(edge) if rnd.random() < 0.16}   # The rim crumbles in places.
    cracks = set()                                               # Short ink random walks.
    cells = sorted(inside)
    for _ in range(3):
        x, y = cells[rnd.randrange(len(cells))]
        dx, dy = rnd.choice(((1, 1), (1, 0), (0, 1), (-1, 1)))
        for _ in range(rnd.randrange(5, 10)):
            cracks.add((x, y))
            if rnd.random() < 0.4:
                dx, dy = rnd.choice(((1, 1), (1, 0), (0, 1), (-1, 1), (1, -1)))
            x, y = x + dx, y + dy
    solid = inside - chipped

    # Hard cast shadow, down and to the right of the slab: 3 px long (1 px when pressed).
    length = 1 if pressed else 3
    for (x, y) in solid:
        for d in range(1, length + 1):
            sx, sy = x + d, y + d
            if (sx, sy) not in solid and 1 < sx < n - 1 and 1 < sy < n - 1:
                px[sx, sy] = (*PAL["ink"], 255)
    # The slab, lit from the top-left.
    ramp = [PAL["stone_700"], PAL["stone_500"], PAL["stone_300"], PAL["stone_100"], PAL["bone_500"]]
    if pressed:
        ramp = [PAL["stone_800"], PAL["stone_700"], PAL["stone_500"], PAL["stone_300"], PAL["bone_700"]]
    for (x, y) in solid:
        c = tex(x, y)
        lum = _lum(c) / 255.0
        col = PAL["moss_500"] if _mossy(c) and lum > 0.3 else ramp[min(4, int(lum * 6.0))]
        if (x, y) in cracks:
            col = PAL["ink"]
        elif (x - 1, y) not in solid or (x, y - 1) not in solid:
            col = PAL["bone_300"] if not pressed else PAL["bone_500"]      # Lit top-left edge.
        elif (x + 1, y) not in solid or (x, y + 1) not in solid:
            col = PAL["stone_700"] if not pressed else PAL["stone_800"]    # Shaded bottom-right edge.
        px[x, y] = (*col, 255)
    return img


ARROWS_ALL = ("up", "down", "left", "right", "turn_left", "turn_right")


def stone_panel():
    """The overlays' window (scripts/stone_panel.gd): the frame's blackened brick inside a rusted iron lip, 40x40 logical. The
    4 px border is the part that never tiles and the 32x32 middle is one whole brick tile, so it repeats without a seam."""
    size = 40
    img = Image.new("RGBA", (size, size), (*PAL["ink"], 255))
    px = img.load()
    piece = PIECES / "frame_stone.png"
    tile = PAL.snap(Image.open(piece).convert("RGBA")).load() if piece.exists() else None
    # One step darker than the frame's brick, because small text sits on this one: only the mortar lines and a faint brick show.
    def dim(colour):
        lit = sum(colour) / 3
        return PAL["stone_800"] if lit > 60 else (PAL["stone_900"] if lit > 26 else PAL["ink"])
    for y in range(4, size - 4):
        for x in range(4, size - 4):
            px[x, y] = (*(dim(tile[x - 4, y - 4][:3]) if tile else PAL["stone_900"]), 255)
    last = size - 1
    for i in range(size):
        for a, b in ((i, 0), (0, i)):  # The lit outer edge (top and left).
            px[a, b] = (*PAL["rust_300"], 255)
        for a, b in ((i, last), (last, i)):  # The shaded outer edge.
            px[a, b] = (*PAL["rust_700"], 255)
    for i in range(1, last):
        for a, b in ((i, 1), (1, i), (i, last - 1), (last - 1, i)):
            px[a, b] = (*PAL["rust_500"], 255)
    for i in range(2, last - 1):  # A dark line between the iron and the brick.
        for a, b in ((i, 2), (2, i), (i, last - 2), (last - 2, i)):
            px[a, b] = (*PAL["ink"], 255)
    return img


def build(scale=2):
    written = [save_png(frame(), "ui/frame.png", scale=scale)]
    written.append(save_png(stone_panel(), "ui/panel_stone.png", scale=scale))
    for kind in ARROWS_ALL:
        written.append(save_png(arrow_button_ruin(kind, False), f"ui/arrow_{kind}.png", scale=1))
        written.append(save_png(arrow_button_ruin(kind, True), f"ui/arrow_{kind}_pressed.png", scale=1))
    return written
