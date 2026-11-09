"""The map panel's art (scripts/map_panel.gd): a torn, stained parchment and the small rusted iron frame around it.

Both start from PixelLab pieces in tools/art/pieces/map/ (parchment_raw.png 128x96, iron_raw.png 32x32; see docs/asset_log.md).
This crops, tears and palette-snaps them, and draws the frame round the parchment in the party panel's rust ramp.
Drawn at native pixels (1 art pixel = 1 screen pixel, like the party panel), not doubled.

  art/ui/map_parchment.png   104x80, torn edges are transparent
  art/ui/map_frame.png       112x88, the iron frame only: its middle is transparent (the map shows through)
  art/ui/map_sheet.png       474x298, the stained sheet behind the full-screen map (scripts/automap.gd), opaque
"""
import random
from pathlib import Path

from PIL import Image

from artio import save_png
from palette import PAL

PIECES = Path(__file__).parent / "pieces" / "map"
PW, PH = 104, 80       # Parchment size.
BORDER = 4             # Iron frame thickness.


def _snap(path):
    return PAL.snap(Image.open(path).convert("RGBA"))


# PixelLab drew bright yellow paper; the game is dark and desaturated, so every tone is moved down to the bone and
# rust steps (the stains and the border lines the piece came with become rust-dark blotches).
TONE = {"torch_300": "bone_500", "torch_500": "bone_700", "rust_300": "rust_500", "bruise_900": "rust_700",
        "leather_400": "bone_700", "blood_500": "rust_500", "blood_700": "rust_700", "stone_800": "rust_700",
        "stone_900": "rust_700", "ink": "rust_700"}
IRON = {"stone_800": "rust_700", "stone_700": "rust_700", "stone_500": "rust_500", "soil_900": "rust_700",
        "moss_900": "rust_700", "moss_700": "rust_700", "bone_700": "stone_500", "rust_300": "rust_300", "ink": "ink"}


def _remap(img, table):
    px = img.load()
    for y in range(img.height):
        for x in range(img.width):
            r, g, b, a = px[x, y]
            n = PAL.name_of((r, g, b))
            if a and n in table:
                px[x, y] = (*PAL[table[n]], a)
            elif a and table is IRON and (r + g + b) / 3 > 130:
                px[x, y] = (*PAL["rust_500"], a)  # No bright specks in the iron.
    return img


RAMP = ["rust_700", "rust_500", "bone_700", "bone_500"]
ANCHORS = [55, 85, 125, 190]  # Brightness of the PixelLab sheet that each RAMP step stands for.
BAYER = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]


def _tone(img):
    """Move every colour of the PixelLab sheet onto the dim bone/rust steps by brightness, keeping its stains."""
    px = img.load()
    for y in range(img.height):
        for x in range(img.width):
            r, g, b, a = px[x, y]
            lum = (r + g + b) / 3
            # Position on the ramp (0 = darkest), dithered with a Bayer 4x4 so the gradients stay in palette steps.
            t = 0.0 if lum <= ANCHORS[0] else float(len(ANCHORS) - 1)
            for i in range(len(ANCHORS) - 1):
                if ANCHORS[i] < lum <= ANCHORS[i + 1]:
                    t = i + (lum - ANCHORS[i]) / (ANCHORS[i + 1] - ANCHORS[i])
            i = int(t)
            if i < len(ANCHORS) - 1 and (t - i) > (BAYER[y % 4][x % 4] + 0.5) / 16:
                i += 1
            name = RAMP[i]
            px[x, y] = (*PAL[name], a)
    return img


def parchment():
    img = _tone(_snap(PIECES / "parchment_raw.png"))
    img = img.crop((28, 50, 28 + PW, 50 + PH))  # The middle of the sheet: the PixelLab picture shows rollers and a table round it.
    # The stains cluster on the left of the crop: turn a copy of that side round onto the right, so the sheet is
    # stained all over (the seam sits in clean paper).
    left = img.crop((0, 0, 40, PH)).transpose(Image.ROTATE_180)
    img.paste(left, (PW - 40, 0))
    px = img.load()
    rng = random.Random(41)
    # Torn edge: each side loses a ragged strip, a few deeper bites, and the corners are chewed.
    def depth(i, n):
        d = 1 + int(2 * abs(((i * 7 + rng.randint(0, 3)) % 11) - 5) / 5)
        return d
    for x in range(PW):
        for y in range(depth(x, PW)):
            px[x, y] = (0, 0, 0, 0)
        for y in range(depth(x + 3, PW)):
            px[x, PH - 1 - y] = (0, 0, 0, 0)
    for y in range(PH):
        for x in range(depth(y + 5, PH)):
            px[x, y] = (0, 0, 0, 0)
        for x in range(depth(y + 2, PH)):
            px[PW - 1 - x, y] = (0, 0, 0, 0)
    for _ in range(5):  # A few deeper bites.
        cx, cy, r = rng.randrange(PW), rng.choice((0, PH - 1)), rng.randint(2, 4)
        for y in range(PH):
            for x in range(PW):
                if (x - cx) ** 2 + (y - cy) ** 2 <= r * r:
                    px[x, y] = (0, 0, 0, 0)
    # Darken the edge a step where it meets the tear, as if scorched and stained.
    dark = {PAL["bone_300"]: PAL["bone_500"], PAL["bone_500"]: PAL["bone_700"], PAL["bone_700"]: PAL["rust_500"]}
    out = img.copy()
    po = out.load()
    for y in range(PH):
        for x in range(PW):
            if px[x, y][3] == 0:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if not (0 <= nx < PW and 0 <= ny < PH) or px[nx, ny][3] == 0:
                    c = px[x, y][:3]
                    po[x, y] = (*dark.get(c, c), 255)
                    break
    return out


def frame():
    W, H = PW + 2 * BORDER, PH + 2 * BORDER
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    px = img.load()
    iron = _remap(_snap(PIECES / "iron_raw.png"), IRON).load()
    # Iron: the PixelLab plate, pulled down to the rust and ink steps so it sits with the party panel's lips.
    ramp = [PAL["ink"], PAL["rust_700"], PAL["rust_700"], PAL["rust_500"]]
    for y in range(H):
        for x in range(W):
            if BORDER <= x < W - BORDER and BORDER <= y < H - BORDER:
                continue
            px[x, y] = iron[x % 32, y % 32]
    last_x, last_y = W - 1, H - 1
    for i in range(W):
        px[i, 0] = (*PAL["rust_300"], 255)         # Lit outer edge.
        px[i, last_y] = (*PAL["ink"], 255)
        px[i, last_y - 1] = (*PAL["rust_700"], 255)
        px[i, BORDER - 1] = (*PAL["ink"], 255) if BORDER <= i < W - BORDER + 0 else px[i, BORDER - 1]
    for j in range(H):
        px[0, j] = (*PAL["rust_300"], 255)
        px[last_x, j] = (*PAL["ink"], 255)
        px[last_x - 1, j] = (*PAL["rust_700"], 255)
    for i in range(BORDER - 1, W - BORDER + 1):    # Dark line between the iron and the parchment.
        px[i, BORDER - 1] = (*PAL["ink"], 255)
        px[i, H - BORDER] = (*PAL["ink"], 255)
    for j in range(BORDER - 1, H - BORDER + 1):
        px[BORDER - 1, j] = (*PAL["ink"], 255)
        px[W - BORDER, j] = (*PAL["ink"], 255)
    for cx, cy in ((2, 2), (W - 3, 2), (2, H - 3), (W - 3, H - 3)):  # Rivets in the corners.
        px[cx, cy] = (*PAL["rust_300"], 255)
        px[cx + 1, cy + 1] = (*PAL["ink"], 255)
    return img


SHEET_W, SHEET_H = 474, 298


def sheet():
    """The full-screen map's paper, 474x298. PixelLab's picture (pieces/map/sheet_raw.png, 584x328) has a scroll roller across
    it, so the clean paper left of the roller (for the legend) and the clean block right of it (for the map) are joined, the
    roller cut out: the join reads as a fold in the paper."""
    raw = _snap(PIECES / "sheet_raw.png")
    out = Image.new("RGBA", (SHEET_W, SHEET_H))
    out.paste(raw.crop((4, 16, 184, 16 + SHEET_H)), (0, 0))
    out.paste(raw.crop((244, 16, 538, 16 + SHEET_H)), (180, 0))
    # The roller's dark end caps poke into the top and bottom rows: paint them out with the paper just inside, reflected.
    px = out.load()
    band = 40
    def dark(c):
        return sum(c[:3]) / 3 < 45
    for x in range(SHEET_W):
        for y in list(range(band)) + list(range(SHEET_H - band, SHEET_H)):
            if dark(px[x, y]):
                ry = 2 * band - y if y < band else 2 * (SHEET_H - band) - 2 - y
                px[x, y] = px[x, ry] if not dark(px[x, ry]) else (*PAL["bone_700"], 255)
    return out


def build():
    return [
        save_png(parchment(), "ui/map_parchment.png"),
        save_png(frame(), "ui/map_frame.png"),
        save_png(sheet(), "ui/map_sheet.png"),
    ]


if __name__ == "__main__":
    for p in build():
        print(p)
