"""Ancient wall art: the stone-block wall variants, the wall decals, and the grime overlay.

PixelLab pieces live in tools/art/pieces/walls/stone_<n>.png (128x128, n = 1..) and
tools/art/pieces/decals/<name>.png (transparent). This turns them into game art:
  art/tiles/wall_stone_1..4.png  stone variants. Any stone_<n> piece that exists is used as it is; the rest
                                 are made from stone_1 by flipping and shifting (a stand-in until more are generated)
  art/decals/<name>.png          the decals, copied (palette-checked); pieces named <name>_raw.png are fixed up first (see FIXES)
  art/decals/web_l|web_r, tally, vein_1..3   drawn here by script (cobwebs for the top corners, scratched tally marks, curse veins)
  art/decals/grime.png           a dithered dark overlay, heavy at the bottom of a wall face and light at the top
which scripts/wall_decor.gd places on the walls (settings in data/wall_decor.tres).
"""
from pathlib import Path

from PIL import Image

from artio import save_png
from palette import PAL

PIECES = Path(__file__).parent / "pieces"
VARIANTS = 4
BAYER = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]


def stone_variants():
    src = PIECES / "walls"
    base = Image.open(src / "stone_1.png").convert("RGBA")
    shift = lambda im, dx, dy: Image.fromarray(__import__("numpy").roll(__import__("numpy").array(im), (dy, dx), axis=(0, 1)))
    out = [base]
    for n in range(2, VARIANTS + 1):
        piece = src / f"stone_{n}.png"
        if piece.exists():
            out.append(Image.open(piece).convert("RGBA"))
        else:  # A stand-in: the first stone, turned and shifted.
            im = base.transpose(Image.FLIP_LEFT_RIGHT) if n % 2 == 0 else base
            out.append(shift(im, 40 * n, 24 * n))
    return out


def grime(size=128):
    """Black pixels only (ink), so it's a pure darkening. The bottom 45% rises from nothing to 75% dark towards the floor;
    the top 14% to 40% dark towards the ceiling. Thresholded by an ordered dither, so it is hard pixels, not a soft fade."""
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    px = img.load()
    for y in range(size):
        t = y / (size - 1)
        down = max(0.0, (t - 0.55) / 0.45) ** 1.5 * 0.6
        up = max(0.0, (0.14 - t) / 0.14) ** 1.3 * 0.4
        density = max(down, up)
        for x in range(size):
            if density > (BAYER[y % 4][x % 4] + 0.5) / 16.0:
                px[x, y] = (*PAL["ink"], 255)
    return img


def remap(im, table):
    px = im.load()
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, a = px[x, y]
            if a and (r, g, b) in table:
                px[x, y] = (*table[(r, g, b)], a)
    return im


def fix_roots(im):
    """PixelLab drew a whole dead tree stump. Keep the root flare at the bottom and hang it from the top edge."""
    w, h = im.size
    flare = im.crop((0, int(h * 0.55), w, h))
    flare = flare.crop(flare.getbbox())
    return flare.transpose(Image.FLIP_TOP_BOTTOM)


def fix_blood(im):
    """Dried, not fresh: one step darker."""
    return remap(im, {PAL["blood_500"]: PAL["blood_700"], PAL["rust_300"]: PAL["blood_500"], PAL["rust_500"]: PAL["blood_700"]})


def fix_niche(im):
    """The surround was brighter than the walls round it: knock the stone back a step. The candle flame keeps its colours."""
    return remap(im, {PAL["stone_100"]: PAL["stone_300"], PAL["stone_300"]: PAL["stone_500"], PAL["bone_300"]: PAL["bone_500"]})


FIXES = {"roots": fix_roots, "blood": fix_blood, "niche": fix_niche}


def cobweb(left=True, size=40):
    """A web across a top corner: radial threads and a few sagging arcs, thin bone-grey lines."""
    import math
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    px = img.load()
    cx, cy = (0, 0) if left else (size - 1, 0)

    def put(x, y, c):
        if 0 <= x < size and 0 <= y < size:
            px[x, y] = (*c, 255)
    for k in range(5):  # Threads from the corner, fanned across the quarter circle below it.
        ang = math.radians(8 + k * 18)
        for t in range(size):
            x = cx + (t * math.cos(ang) if left else -t * math.cos(ang))
            put(round(x), round(t * math.sin(ang)), PAL["stone_500"])
    for r in (10, 19, 28):  # Sagging arcs between the threads.
        for k in range(0, 91, 2):
            ang = math.radians(k)
            sag = 2 if 18 < k < 72 else 0
            x = cx + (r * math.cos(ang) if left else -r * math.cos(ang))
            put(round(x), round(r * math.sin(ang)) + sag, PAL["stone_700"])
    return img


def tally(size=(44, 24)):
    """Scratched tally marks: groups of four strokes with a slash through them, two groups and a start of a third."""
    img = Image.new("RGBA", size, (0, 0, 0, 0))
    px = img.load()
    for g, count in enumerate((5, 5, 2)):
        x0 = 2 + g * 15
        for i in range(min(count, 4)):
            for y in range(3, 20):
                px[x0 + i * 3 + (y % 5 == 0), y] = (*PAL["stone_300"], 255)
        if count == 5:
            for t in range(13):
                px[x0 + t, 17 - t] = (*PAL["stone_300"], 255)
    return img


def vein(seed, size=96):
    """Faint curse-green veins: a few branching random walks in two greens. The game makes them glow and pulse."""
    import random
    rng = random.Random(seed)
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    px = img.load()

    def walk(x, y, dx, dy, steps, depth):
        for _ in range(steps):
            if not (0 <= x < size and 0 <= y < size):
                return
            px[int(x), int(y)] = (*PAL["curse_700"], 255)
            if rng.random() < 0.18:
                dx, dy = max(-1, min(1, dx + rng.choice((-1, 0, 1)))), max(-1, min(1, dy + rng.choice((-1, 0, 1))))
                if (dx, dy) == (0, 0):
                    dx = 1
            if depth < 2 and rng.random() < 0.06:
                walk(x, y, -dy or 1, dx, rng.randint(10, 24), depth + 1)
            x, y = x + dx, y + dy
    for _ in range(2):
        walk(rng.randint(0, size - 1), 0 if rng.random() < .5 else rng.randint(0, size // 2), rng.choice((-1, 0, 1)), 1, rng.randint(60, 90), 0)
    for y in range(size):  # A slightly brighter core on a few pixels (never the palette's pale green: it glared).
        for x in range(size):
            if px[x, y][3] and rng.random() < 0.12:
                px[x, y] = (*PAL["curse_500"], 255)
    return img


def build():
    written = []
    for i, im in enumerate(stone_variants(), 1):
        written.append(save_png(im, f"tiles/wall_stone_{i}.png"))
    for piece in sorted((PIECES / "decals").glob("*.png")):
        im = Image.open(piece).convert("RGBA")
        name = piece.stem
        if name.endswith("_raw"):
            name = name[:-4]
            im = FIXES[name](im)
        written.append(save_png(im, f"decals/{name}.png"))
    written.append(save_png(cobweb(True), "decals/web_l.png"))
    written.append(save_png(cobweb(False), "decals/web_r.png"))
    written.append(save_png(tally(), "decals/tally.png"))
    for i in range(1, 4):
        written.append(save_png(vein(100 + i), f"decals/vein_{i}.png"))
    written.append(save_png(grime(), "decals/grime.png"))
    return written


if __name__ == "__main__":
    print(len(build()), "files")
