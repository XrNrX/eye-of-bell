"""The carved wooden frame round the 3D view (art/ui/frame_wood.png, 1280x720, transparent outside the ring and inside its opening),
laid over art/ui/frame.png by ui_frame.gd. Built from separate PixelLab pieces in `pieces/frame_wood/`, all `create_image_pro`:

- `corner_tl/tr/bl/br.png` (80x80, transparent): four different skulls (cracked, jawless, horned, split-browed) each on an L of thin planks,
  with tentacles through the eye sockets and green slime; each goes flush into its own corner of the 432x276 canvas (the view and its
  surround, in canvas units).
- `wood.png` (192x16): a weathered oak plank, tiled (and turned for the sides) between the corners; `THICK` units thick, so the 3D view stays big.
- `tentacles/*.png` (64x32): a tentacle coiled round a plank (its own plank is removed: only the grey tentacle is kept) and `drips/*.png`
  (64x32): slime hanging from an edge. Both are scattered along the bars at seeded random places (`SEED`), so the four sides differ.
  Slime is on this frame only, never the party panels.

Colours go onto the palette (slime to `curse_*` greens, tentacles to stone greys, the rest snapped), the picture is enlarged 2x, and the
opening must lie inside the 3D view (asserted).

    python tools/art/gen_frame_wood.py          # --seed N for another scatter
"""
import os
import random
import sys
from pathlib import Path

from PIL import Image

from artio import save_png
from palette import PAL

K = 2
W, H = 640 * K, 360 * K
VIEW = (112, 8, 416, 260)             # scripts/ui_layout.gd, canvas units.
ORIGIN = (VIEW[0] - 8, VIEW[1] - 8)   # Where the 432x276 canvas (the view and its 8 unit surround) sits on the screen.
CW, CH = 432, 276                     # The view and its surround, canvas units.
PIECES = Path(__file__).parent / "pieces" / "frame_wood"
THICK = 16
WOOD_DARKEN = 0.7                     # Wood brightness factor before it is put on the wood ramp.
BONE = ["bone_700", "bone_500", "bone_300"]
SEED = 7
TENTACLES = {"top": 3, "bottom": 3, "left": 2, "right": 2}   # Wraps per side.
DRIPS = {"top": 3, "bottom": 2, "left": 2, "right": 2}
DRIP_WIDTH, DRIP_LENGTH = 20, 22


def slime_name(lum):
    return "curse_300" if lum > 215 else ("curse_500" if lum > 135 else "curse_700")


def wood_name(lum):
    return "soil_900" if lum < 34 else ("wood_700" if lum < 58 else ("wood_500" if lum < 92 else "leather_400"))


def grey_name(lum):
    return "ink" if lum < 24 else ("stone_800" if lum < 44 else ("stone_700" if lum < 74 else ("stone_500" if lum < 108 else ("stone_300" if lum < 150 else "stone_100"))))


def recolour_piece(img, keep_only=None):
    """On the palette: slime -> curse greens, cool greys -> the stone ramp, everything else snapped. keep_only "grey" drops the
    warm (wood) pixels and the slime, "slime" keeps only slime and its dark outline."""
    img = img.convert("RGBA")
    px = img.load()
    for y in range(img.height):
        for x in range(img.width):
            r, g, b, a = px[x, y]
            if a < 128:
                px[x, y] = (0, 0, 0, 0)
                continue
            lum = 0.299 * r + 0.587 * g + 0.114 * b
            slime = g > r + 25 and g > b + 25
            warm = r - b > 10 and not slime
            if keep_only == "grey" and (warm or slime):
                px[x, y] = (0, 0, 0, 0)
            elif keep_only == "slime" and not slime and lum > 60:
                px[x, y] = (0, 0, 0, 0)
            elif slime:
                px[x, y] = (*PAL[slime_name(lum)], 255)
            elif not warm and lum < 150 and abs(r - b) <= 10:
                px[x, y] = (*PAL[grey_name(lum)], 255)
            elif warm and lum > 125:  # Bone.
                px[x, y] = (*PAL[BONE[0] if lum < 150 else (BONE[1] if lum < 190 else BONE[2])], 255)
            elif warm or abs(r - b) <= 10:  # Wood, darkened.
                px[x, y] = (*PAL[wood_name(lum * WOOD_DARKEN)], 255)
            else:
                px[x, y] = (r, g, b, 255)
    return PAL.snap(img)


def put(canvas, piece, x, y):
    """Composite `piece` at (x, y), clipping what runs off the canvas."""
    sx, sy = max(-x, 0), max(-y, 0)
    if sx >= piece.width or sy >= piece.height:
        return
    canvas.alpha_composite(piece, (max(x, 0), max(y, 0)), (sx, sy))


def load_pieces(folder, keep_only):
    return [recolour_piece(Image.open(p), keep_only) for p in sorted((PIECES / folder).glob("*.png"))]


def trim(img):
    box = img.getbbox()
    return img.crop(box) if box else img


def bars():
    wood = recolour_piece(Image.open(PIECES / "wood.png"))
    if wood.height != THICK:
        wood = wood.resize((wood.width, THICK), Image.NEAREST)
    img = Image.new("RGBA", (CW, CH))
    for x in range(0, CW, wood.width):
        img.paste(wood, (x, 0))
        img.paste(wood.transpose(Image.FLIP_TOP_BOTTOM), (x, CH - THICK))
    v = wood.rotate(90, expand=True)
    for y in range(0, CH, v.height):
        img.paste(v, (0, y))
        img.paste(v.transpose(Image.FLIP_LEFT_RIGHT), (CW - THICK, y))
    return img


def scatter(img, rng):
    tents = [trim(t) for t in load_pieces("tentacles", "grey")]
    drips = load_pieces("drips", "slime")
    for side in ("top", "bottom", "left", "right"):
        long_side = CW if side in ("top", "bottom") else CH
        lo, hi = 90, long_side - 90
        for t in rng.sample(tents, TENTACLES[side]):
            if side == "top":
                put(img, t, rng.randint(lo, hi - t.width), THICK // 2 - t.height // 2)
            elif side == "bottom":
                put(img, t, rng.randint(lo, hi - t.width), CH - THICK // 2 - t.height // 2)
            elif side == "left":
                r = t.rotate(90, expand=True)
                put(img, r, THICK // 2 - r.width // 2, rng.randint(lo, hi - r.height))
            else:
                r = t.rotate(-90, expand=True)
                put(img, r, CW - THICK // 2 - r.width // 2, rng.randint(lo, hi - r.height))
        for d in rng.sample(drips, DRIPS[side]):
            d = trim(d)
            # A run of a few drips, no wider than DRIP_WIDTH and no longer than DRIP_LENGTH, hanging down over the wood from its top
            # edge (the bottom bar's too), so the slime sits on the frame; on the uprights it hangs down from a point on the bar.
            cut = rng.randint(0, max(d.width - DRIP_WIDTH, 0))
            run = d.crop((cut, 0, min(cut + DRIP_WIDTH, d.width), min(d.height, DRIP_LENGTH)))
            if side == "top":
                put(img, run, rng.randint(lo, hi - run.width), 1)
            elif side == "bottom":
                put(img, run, rng.randint(lo, hi - run.width), CH - THICK + 1)
            else:
                put(img, run, 0 if side == "left" else CW - THICK, rng.randint(lo, hi - 8))


def arm_centre(alpha, along_x, at, size):
    """Centre of the plank in a corner piece: the opaque run across the rows (along_x) or columns, sampled `at` pixels from the far end."""
    px = alpha.load()
    cells = [v for v in range(size) if (px[at, v] if along_x else px[v, at]) > 0]
    return (min(cells) + max(cells)) / 2.0 if cells else size / 2.0


def corners(img):
    """Each corner goes in so that the centre line of its two planks lies on the centre line of the bars (THICK / 2 from the edges)."""
    for name, right, low in (("tl", False, False), ("tr", True, False), ("bl", False, True), ("br", True, True)):
        piece = recolour_piece(Image.open(PIECES / f"corner_{name}.png"))
        a = piece.getchannel("A")
        w, h = piece.size
        sample_x = w - 6 if not right else 5           # A column on the far end of the horizontal plank.
        sample_y = h - 6 if not low else 5             # A row on the far end of the vertical plank.
        cy = arm_centre(a, True, sample_x, h)          # Where the horizontal plank sits in the piece.
        cx = arm_centre(a, False, sample_y, w)         # Where the vertical plank sits.
        x = round((CW - THICK / 2 - cx) if right else (THICK / 2 - cx))
        y = round((CH - THICK / 2 - cy) if low else (THICK / 2 - cy))
        put(img, piece, x, y)


def frame_wood(seed=SEED):
    img = bars()
    scatter(img, random.Random(seed))
    corners(img)
    a = img.getchannel("A").load()
    seen, stack = set(), [(CW // 2, CH // 2)]
    while stack:
        x, y = stack.pop()
        if (x, y) in seen or not (0 <= x < CW and 0 <= y < CH) or a[x, y]:
            continue
        seen.add((x, y))
        stack += [(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)]
    xs, ys = [x for x, _ in seen], [y for _, y in seen]
    box = (min(xs), min(ys), max(xs) + 1, max(ys) + 1)
    box = (box[0] + ORIGIN[0], box[1] + ORIGIN[1], box[2] + ORIGIN[0], box[3] + ORIGIN[1])
    assert box[0] >= VIEW[0] and box[1] >= VIEW[1] and box[2] <= VIEW[0] + VIEW[2] and box[3] <= VIEW[1] + VIEW[3], box
    print("opening", box, "of the view", (VIEW[0], VIEW[1], VIEW[0] + VIEW[2], VIEW[1] + VIEW[3]))
    big = img.resize((CW * K, CH * K), Image.NEAREST)
    out = Image.new("RGBA", (W, H))
    out.paste(big, (ORIGIN[0] * K, ORIGIN[1] * K))
    return out


def build():
    os.environ["ART_OVERWRITE_IMPORTED"] = "1"
    seed = int(sys.argv[sys.argv.index("--seed") + 1]) if "--seed" in sys.argv else SEED
    return [save_png(frame_wood(seed), "ui/frame_wood.png")]


if __name__ == "__main__":
    for p in build():
        print(p)
