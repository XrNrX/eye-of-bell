"""The stone UI frame at 1280x720 (hires-720 branch): art/ui/frame.png, drawn at the screen's real pixels and shown over the 640x360 canvas.

Same layout as gen_frame.py (the rectangles are scripts/ui_layout.gd's, times 2) but every line is finer: the blackened-brick tile is the
128x128 PixelLab piece tools/art/pieces/frame_stone_128.png (the old 32x32 tile redrawn at 4x the pixels, tiled at 1:1), the windows'
lips are 4 px rings (an ink ring, then a rusted lit/shaded one), the studs are round 12 px rivets and the corner skulls 12x12.
The 3D view's window stays exactly VIEW x 2 (asserted below), the only transparent part.

    python tools/art/gen_frame_hd.py
"""
import os
from pathlib import Path

from PIL import Image

from artio import save_png
from palette import PAL

K = 2                                   # Canvas units to texture pixels.
W, H = 640 * K, 360 * K
# scripts/ui_layout.gd's rectangles (x, y, w, h), canvas units.
VIEW = (112, 8, 416, 260)
LOG = (112, 276, 296, 76)
ARROWS = (416, 276, 112, 76)
PARTY_LEFT = (8, 8, 96, 344)            # The six-hero layout: a column of three hero panels each side of the view.
PARTY_RIGHT = (536, 8, 96, 344)
RING = 4                                # Each ring of a window's lip, in pixels.
INK = PAL["ink"]
TILE = Path(__file__).parent / "pieces" / "frame_stone_128.png"


def px_rect(r):
    return tuple(v * K for v in r)


def masonry():
    tile = Image.open(TILE).convert("RGBA")
    img = Image.new("RGBA", (W, H))
    for y in range(0, H, tile.height):
        for x in range(0, W, tile.width):
            img.paste(tile, (x, y))
    return PAL.snap(img)


def recess(img, rect, panel):
    """Cut a window into the masonry: transparent when `panel` is None, else the dark brick floor. Lip: an ink ring RING px wide outside,
    then a ring of rusted iron: shaded top and left, lit bottom and right."""
    px = img.load()
    rx, ry, rw, rh = px_rect(rect)
    for y in range(ry - 2 * RING, ry + rh + 2 * RING):
        for x in range(rx - 2 * RING, rx + rw + 2 * RING):
            if not (0 <= x < W and 0 <= y < H):
                continue
            inside = rx <= x < rx + rw and ry <= y < ry + rh
            if inside:
                px[x, y] = (0, 0, 0, 0) if panel is None else panel.getpixel((x, y))
                continue
            d = max(rx - x, x - (rx + rw - 1), ry - y, y - (ry + rh - 1))  # 1 = touching the window.
            if d > RING:
                px[x, y] = (*INK, 255)
            else:
                top_left = x < rx or y < ry
                bottom_right = x >= rx + rw or y >= ry + rh
                if top_left and not bottom_right:
                    px[x, y] = (*PAL["rust_700"], 255)
                elif bottom_right and not top_left:
                    px[x, y] = (*PAL["rust_300"], 255)
                else:
                    px[x, y] = (*PAL["rust_500"], 255)


def rivet(img, cx, cy, r=6):
    """A round rusted iron stud 2r px across: lit top-left, shaded bottom-right, with a short drop shadow."""
    px = img.load()
    for dy in range(-r - 3, r + 4):
        for dx in range(-r - 3, r + 4):
            x, y = cx + dx, cy + dy
            if not (0 <= x < W and 0 <= y < H):
                continue
            d = (dx * dx + dy * dy) ** 0.5
            sd = ((dx - 3) ** 2 + (dy - 3) ** 2) ** 0.5
            if d <= r:
                lit = (dx + dy) / (2.0 * r)  # -1 top-left .. 1 bottom-right
                name = "rust_300" if lit < -0.35 else ("rust_700" if lit > 0.35 else "rust_500")
                px[x, y] = (*PAL[name], 255)
                if d > r - 1.2:
                    px[x, y] = (*PAL["ink"], 255) if lit > 0.35 else px[x, y]
            elif sd <= r and px[x, y][3]:
                px[x, y] = (*INK, 255)


SKULL = (  # 12x12: a small skull set into each screen corner (. empty, b bone, h highlight, k ink).
    "...bbbbbb...",
    "..bhhbbbbb..",
    ".bhhbbbbbbb.",
    ".bhbbbbbbbb.",
    ".bbkkbbkkbb.",
    ".bbkkbbkkbb.",
    ".bbbbkkbbbb.",
    "..bbbkkbbb..",
    "..bbbbbbbb..",
    "...bkbkbkb..",
    "...bkbkbkb..",
    "....kkkkk...",
)


def skull(img, x0, y0):
    px = img.load()
    for dy, row in enumerate(SKULL):
        for dx, ch in enumerate(row):
            name = {"b": "bone_500", "h": "bone_300", "k": "ink"}.get(ch)
            if name:
                px[x0 + dx, y0 + dy] = (*PAL[name], 255)


def outer_bevel(img):
    """The screen's own edge, RING px thick: lit along the top and left, shaded along the bottom and right."""
    px = img.load()
    for i in range(RING):
        lit = PAL["stone_300"] if i < RING // 2 else PAL["stone_500"]
        for x in range(W):
            px[x, i] = (*lit, 255)
            px[x, H - 1 - i] = (*INK, 255)
        for y in range(H):
            px[i, y] = (*lit, 255)
            px[W - 1 - i, y] = (*INK, 255)


def frame():
    img = masonry()
    panel = img.copy()  # The recessed panels' floor is the same blackened brick.
    recess(img, ARROWS, panel)
    recess(img, LOG, panel)
    recess(img, PARTY_LEFT, panel)
    recess(img, PARTY_RIGHT, panel)
    recess(img, VIEW, None)
    outer_bevel(img)
    # Studs at the T-junctions of the dividers (the corners get skulls).
    x_div = (VIEW[0] + VIEW[2] + PARTY_RIGHT[0]) // 2 * K    # Between the view and the right party well.
    x_left = (PARTY_LEFT[0] + PARTY_LEFT[2] + VIEW[0]) // 2 * K  # Between the left party well and the view.
    y_div = (VIEW[1] + VIEW[3] + LOG[1]) // 2 * K            # Between the view and the log.
    x_mid = (LOG[0] + LOG[2] + ARROWS[0]) // 2 * K           # Between the log and the arrows.
    for cx, cy in ((x_div, 6), (x_div, H - 7), (x_div, y_div), (x_left, 6), (x_left, H - 7), (x_left, y_div), (x_mid, y_div), (x_mid, H - 7)):
        rivet(img, cx, max(cy, 6) if cy < 20 else min(cy, H - 7))
    for x0, y0 in ((6, 6), (W - 18, 6), (6, H - 18), (W - 18, H - 18)):
        skull(img, x0, y0)
    # The only transparent pixels are the 3D view's window, exactly VIEW x 2.
    vx, vy, vw, vh = px_rect(VIEW)
    alpha = img.getchannel("A")
    box = alpha.point(lambda a: 255 if a == 0 else 0).getbbox()
    assert box == (vx, vy, vx + vw, vy + vh), box
    return img


def build():
    os.environ["ART_OVERWRITE_IMPORTED"] = "1"  # frame.png is listed as imported art; this replaces it on purpose.
    return [save_png(frame(), "ui/frame.png")]


if __name__ == "__main__":
    for p in build():
        print(p)
