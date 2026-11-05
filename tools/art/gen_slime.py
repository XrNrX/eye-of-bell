"""Procedural slime monster (48x48, front-facing), palette-bound.

    python tools/art/gen_slime.py                                  # default green slime
    python tools/art/gen_slime.py --seed 5 --colour acid --contents skull --name slime_acid
    python tools/art/gen_slime.py --seed 2 --size 1.3 --canvas 64 --name slime_boss

Writes to res://art/monsters/<name>/ :
    idle_0.png idle_1.png idle_2.png
    attack_0.png attack_1.png attack_2.png
    hurt_0.png hurt_0_flash.png
    <name>_sheet.png + <name>_sheet.json

How it works
- The body is a dome whose outline is lumpy: seeded 1D noise nudges the dome's radius,
  per column on top and per row at the sides. The same noise is reused for every frame,
  so a slime keeps its lumps while it squashes and stretches.
- The body is shaded by turning the distance-to-edge into a height map, lighting it from
  the top-left (toolkit lighting) and dithering it onto a 4-tone colour ramp.
- Glossy highlight, a half-dissolved object floating inside, eyes, then a 1px outline.
"""
import argparse
import os
import math
from collections import deque

from PIL import Image

from artio import save_frames
from dither import dither_ramp
from lighting import lit_values
from noise import hash01, remap, value_noise
from outline import add_outline
from palette import PAL

# Body colour ramps, dark to light. "acid" is the red slime.
COLOURS = {
    "green": ["moss_900", "moss_700", "moss_500", "slime_300"],
    "acid": ["wood_700", "rust_700", "rust_500", "rust_300"],
    "amber": ["rust_700", "torch_700", "torch_500", "torch_300"],
    "grey": ["stone_800", "stone_700", "stone_500", "stone_300"],
}
SHOULDER = 2.5   # Dome fullness: 2 is an ellipse, higher is boxier. Slimes want fuller shoulders.
INK = PAL["ink"]
WHITE = PAL["bone_300"]   # The palette's white: eyes, gloss, and the flat hurt flash.

# Per-frame shape. sx/sy stretch the body, lean shears the top sideways, bob moves the
# floating object, eyes picks the face.
FRAMES = {
    "idle_0": dict(sx=1.00, sy=1.00, lean=0, bob=0, eyes="open"),
    "idle_1": dict(sx=0.95, sy=1.07, lean=1, bob=-1, eyes="open"),
    "idle_2": dict(sx=1.07, sy=0.93, lean=-1, bob=1, eyes="blink"),
    "attack_0": dict(sx=1.18, sy=0.74, lean=0, bob=1, eyes="angry"),           # Squash down.
    "attack_1": dict(sx=0.80, sy=1.28, lean=0, bob=-1, eyes="angry"),          # Stretch up tall.
    "attack_2": dict(sx=1.26, sy=0.60, lean=0, bob=1, eyes="angry", splat=True),  # Splat forward.
    "hurt_0": dict(sx=1.28, sy=0.60, lean=0, bob=1, eyes="hurt"),              # Flattened and wide.
}
ORDER = ["idle_0", "idle_1", "idle_2", "attack_0", "attack_1", "attack_2", "hurt_0", "hurt_0_flash"]
ANIMATIONS = {
    "idle": ["idle_0", "idle_1", "idle_2"],
    "attack": ["attack_0", "attack_1", "attack_2"],
    "hurt": ["hurt_0", "hurt_0_flash"],
}


def clamp01(v):
    return min(1.0, max(0.0, v))


def noise_line(seed, cells, n=64):
    """A smooth 1D noise curve of n samples in 0..1 with about `cells` bumps."""
    return remap(value_noise(n, 1, n / cells, seed, tileable=False))[0]


def sample(line, f):
    """Sample a noise line at f in -1..1 (clamped)."""
    return line[min(len(line) - 1, max(0, int((f + 1) / 2 * (len(line) - 1))))]


class Traits:
    """Everything a seed decides, so the lumps stay the same from frame to frame."""

    def __init__(self, seed, lumpiness):
        self.seed = seed
        self.lump = lumpiness
        self.top = noise_line(seed * 11 + 1, 3)    # Bumps along the top of the dome.
        self.left = noise_line(seed * 11 + 2, 4)   # Bumps up the left side.
        self.right = noise_line(seed * 11 + 3, 4)  # Bumps up the right side.
        self.eye_gap = (hash01(seed, 1, 0) - 0.5) * 2  # -1..1, nudges eye spacing.
        self.obj_dx = (hash01(seed, 2, 0) - 0.5) * 4   # Where the object floats sideways.
        self.dissolve_flip = hash01(seed, 3, 0) < 0.5  # Which end of the object dissolves.


# --------------------------------------------------------------------------
# Body
# --------------------------------------------------------------------------

def body_mask(C, size, pose, tr):
    """Pixel set of the lumpy dome for one pose. Returns (mask, geometry dict)."""
    cx, bottom = C // 2, C - 4
    unit = C / 48 * size
    half_w = 15.0 * unit * pose["sx"]   # 30px wide at size 1, 48px canvas.
    h = 28.0 * unit * pose["sy"]
    mask = set()
    for y in range(bottom, int(bottom - h * 1.35), -1):
        t = (bottom - y) / h
        shift = round(pose["lean"] * t * unit)
        side_noise = (tr.left, tr.right)
        for x in range(C):
            dx = (x - shift - cx + 0.5) / half_w
            n_side = sample(side_noise[0 if dx < 0 else 1], t * 2 - 1)
            side = 1 + tr.lump * (2 * n_side - 1) * 0.9
            top = 1 + tr.lump * (2 * sample(tr.top, max(-1.0, min(1.0, dx))) - 1) * 0.45
            if (abs(dx) / side) ** SHOULDER + (t / top) ** SHOULDER <= 1:
                if y == bottom and abs(dx) > side * 0.93:
                    continue  # Round off the bottom corners.
                mask.add((x, y))
    return mask, {"cx": cx, "bottom": bottom, "half_w": half_w, "h": h, "unit": unit}


def add_splat(mask, C, geo, seed):
    """Droplets flung out around the body (the attack_2 'splat'): small blobs placed in the
    free space just outside it, at the sides and above."""
    xs = [p[0] for p in mask]
    ys = [p[1] for p in mask]
    x0, x1, top, bottom = min(xs), max(xs), min(ys), geo["bottom"]
    placed, i = 0, 0
    while placed < 8 and i < 80:
        i += 1
        x = x0 - 3 + round(hash01(seed, i, 10) * (x1 - x0 + 6))
        y = top - 6 + round(hash01(seed, i, 11) * (bottom - top + 4))
        size = 2 if hash01(seed, i, 12) < 0.55 else 1
        blob = {(x + dx, y + dy) for dx in range(size) for dy in range(size)}
        near = {(bx + dx, by + dy) for bx, by in blob for dx in (-2, -1, 0, 1, 2) for dy in (-2, -1, 0, 1, 2)}
        if near & mask or any(not (2 <= bx < C - 2 and 2 <= by < C - 2) for bx, by in blob):
            continue  # Keep droplets apart from the body and inside the canvas.
        mask |= blob
        placed += 1


def edge_distance(mask):
    """Distance (in pixels, 1 = on the edge) from each mask pixel to the outside."""
    dist, queue = {}, deque()
    for (x, y) in mask:
        if any((x + dx, y + dy) not in mask for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
            dist[(x, y)] = 1
            queue.append((x, y))
    while queue:
        x, y = queue.popleft()
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            p = (x + dx, y + dy)
            if p in mask and p not in dist:
                dist[p] = dist[(x, y)] + 1
                queue.append(p)
    return dist


def shade_body(mask, C, ramp, unit):
    """{pixel: colour}: a rounded bump from the edge distance, lit from the top-left,
    darker towards the bottom, dithered onto the ramp."""
    dist = edge_distance(mask)
    radius = 6.0 * unit
    heights = [[0.0] * C for _ in range(C)]
    for (x, y), d in dist.items():
        heights[y][x] = math.sqrt(min(1.0, d / radius))
    lit = lit_values(heights, strength=1.1, base=0.5, wrap=False)
    ys = [p[1] for p in mask]
    top, span = min(ys), max(1, max(ys) - min(ys))
    values = [[0.0] * C for _ in range(C)]
    for (x, y) in mask:
        v = 0.12 + lit[y][x] * 0.75 + (heights[y][x] - 0.5) * 0.22 - 0.16 * (y - top) / span
        values[y][x] = clamp01(v)
    img = dither_ramp(values, ramp, "checker").load()
    return {p: img[p][:3] for p in mask}, dist


# --------------------------------------------------------------------------
# Gloss, floating object, eyes
# --------------------------------------------------------------------------

def put(canvas, mask, p, colour, min_dist=0, dist=None):
    if p in mask and (dist is None or dist.get(p, 0) >= min_dist):
        canvas[p] = colour


def gloss(canvas, mask, unit):
    """Glossy highlight: a short bright arc and a dot, near the top-left of the body."""
    xs = [p[0] for p in mask]
    ys = [p[1] for p in mask]
    x0, y0, w, h = min(xs), min(ys), max(xs) - min(xs), max(ys) - min(ys)
    ox, oy = x0 + round(w * 0.24), y0 + round(h * 0.2)
    k = max(1, round(unit))
    for dx, dy in [(-4, 2), (-3, 1), (-2, 0), (-1, 0), (0, 0), (1, 0), (2, 0), (-4, 4), (-4, 5)]:
        for a in range(k):
            for b in range(k):
                put(canvas, mask, (ox + dx * k + a, oy + dy * k + b), WHITE)


def object_pixels(kind, k):
    """Floating object as [(dx, dy, u, colour)]; u is 0..1 across it, for dissolving."""
    px = []
    if kind == "bone":
        for i in range(-5, 6):                      # Shaft, a clear diagonal so it reads as a bone.
            y = round(-i * 0.5)
            px += [(i, y, "bone_300"), (i, y + 1, "bone_500")]
        for sign in (-1, 1):                        # A knobby pair at each end.
            ex = 5 * sign
            ey = round(-ex * 0.5)
            px += [(ex + sign, ey - 1, "bone_300"), (ex + sign, ey + 2, "bone_500"),
                   (ex + 2 * sign, ey, "bone_300"), (ex + 2 * sign, ey + 1, "bone_500")]
    elif kind == "coin":
        for dx in range(-3, 4):
            for dy in range(-3, 4):
                d = dx * dx + dy * dy
                if d <= 9:
                    px.append((dx, dy, "torch_700" if d >= 6 else "torch_500"))
        px.append((-1, -1, "torch_300"))
    elif kind == "skull":                           # A 9x7 skull with eye sockets and teeth.
        for dy, half in zip(range(-3, 3), (2, 3, 4, 4, 3, 3)):
            for dx in range(-half, half + 1):
                px.append((dx, dy, "bone_500" if dy >= 1 else "bone_300"))
        for dx in (-2, -1, 1, 2):                   # Eye sockets, two pixels each.
            px += [(dx, 0, "ink"), (dx, -1, "ink")] if dx in (-2, 2) else []
        px += [(-2, 0, "ink"), (-1, 0, "ink"), (1, 0, "ink"), (2, 0, "ink"), (0, 1, "bone_700")]
        for dx in (-2, 0, 2):                       # Teeth gaps.
            px.append((dx, 2, "bone_700"))
    else:
        return []
    xs = [p[0] for p in px]
    lo, hi = min(xs), max(xs)
    return [(dx, dy, (dx - lo) / max(1, hi - lo), PAL[c]) for dx, dy, c in px]


def floating_object(canvas, mask, dist, geo, pose, tr, kind, ramp):
    """Draw the object half-dissolved: solid at one end, then a checkerboard, then gone."""
    if kind == "none":
        return
    k = max(1, round(geo["unit"]))
    cx = geo["cx"] + round(tr.obj_dx * geo["unit"] * 0.6)
    cy = geo["bottom"] - round(geo["h"] * 0.26) + pose["bob"]
    for dx, dy, u, colour in object_pixels(kind, k):
        d = 1 - u if tr.dissolve_flip else u
        for a in range(k):
            for b in range(k):
                x, y = cx + dx * k + a, cy + dy * k + b
                if d < 0.55 or (d < 0.85 and (x + y) % 2 == 0):
                    put(canvas, mask, (x, y), colour, 2, dist)


def eyes(canvas, mask, geo, pose, tr):
    """Two simple eyes. States: open, blink (a line), angry (open + brows), hurt (X)."""
    unit = max(1.0, geo["unit"])
    ew, eh = max(3, round(4 * unit)), max(4, round(5 * unit))
    gap = max(ew + 1, round(geo["half_w"] * 0.4 + tr.eye_gap))
    ey = geo["bottom"] - round(geo["h"] * 0.52)
    lean = round(pose["lean"] * 0.5 * unit)
    for side in (-1, 1):
        ex = geo["cx"] + side * gap + lean
        state = pose["eyes"]
        if state in ("open", "angry"):
            for dx in range(-(ew // 2), ew - ew // 2):
                for dy in range(-(eh // 2), eh - eh // 2):
                    corner = abs(dx - (0 if ew % 2 else -0.5)) > ew / 2 - 0.5 and abs(dy + 0.5) > eh / 2 - 1
                    if not corner:
                        put(canvas, mask, (ex + dx, ey + dy), WHITE)
            for dx in range(max(1, ew // 2)):  # Pupil, looking straight out.
                for dy in range(max(2, eh // 2)):
                    put(canvas, mask, (ex - max(1, ew // 2) // 2 + dx + (ew % 2), ey + dy), INK)
            if state == "angry":  # Brow slants down towards the middle.
                for i in range(ew + 1):
                    bx = ex - side * (ew // 2) + side * i
                    put(canvas, mask, (bx, ey - eh // 2 - 2 + round(i * 0.5 * (1 if side else 1))), INK)
        elif state == "blink":
            for dx in range(-(ew // 2), ew - ew // 2):
                put(canvas, mask, (ex + dx, ey + eh // 4), INK)
        else:  # hurt: an X
            r = max(1, round(unit))
            for i in range(-r, r + 1):
                put(canvas, mask, (ex + i, ey + i), INK)
                put(canvas, mask, (ex + i, ey - i), INK)


# --------------------------------------------------------------------------
# Frames
# --------------------------------------------------------------------------

def render_frame(name, pose, traits, opts, flash=False):
    C, size = opts["canvas"], opts["size"]
    ramp = [PAL[n] for n in COLOURS[opts["colour"]]]
    mask, geo = body_mask(C, size, pose, traits)
    if pose.get("splat"):
        add_splat(mask, C, geo, traits.seed)
    canvas, dist = shade_body(mask, C, ramp, geo["unit"])
    floating_object(canvas, mask, dist, geo, pose, traits, opts["contents"], ramp)
    gloss(canvas, mask, geo["unit"])
    eyes(canvas, mask, geo, pose, traits)
    if flash:  # Hurt flash: the whole slime goes flat white.
        canvas = {p: WHITE for p in canvas}
    img = Image.new("RGBA", (C, C), (0, 0, 0, 0))
    px = img.load()
    for (x, y), c in canvas.items():
        px[x, y] = (*c, 255)
    return add_outline(img, INK)


def fit_size(opts):
    """Shrink `size` if the widest frame (the splat) would not fit the canvas."""
    widest = max(p["sx"] for p in FRAMES.values())
    need = 30.0 * (opts["canvas"] / 48) * opts["size"] * widest
    limit = opts["canvas"] - 6
    return opts["size"] * min(1.0, limit / need)


def render(seed=1, colour="green", size=1.0, contents="bone", lumpiness=0.12, canvas=48):
    """All frames as {name: RGBA image}."""
    opts = {"colour": colour, "size": size, "contents": contents, "canvas": canvas}
    opts["size"] = fit_size(opts)
    traits = Traits(seed, lumpiness)
    images = {n: render_frame(n, p, traits, opts) for n, p in FRAMES.items()}
    images["hurt_0_flash"] = render_frame("hurt_0", FRAMES["hurt_0"], traits, opts, flash=True)
    return images


def build(name="slime", out_dir=None, **options):
    """Write the frames, sheet and sheet JSON. Default folder: res://art/monsters/<name>/.
    Options: seed, colour (green/acid/amber/grey), size, contents (bone/coin/skull/none),
    lumpiness, canvas."""
    return save_frames(render(**options), ORDER, ANIMATIONS, name, out_dir)


def main():
    ap = argparse.ArgumentParser(description="Generate a slime monster sprite set.")
    ap.add_argument("--seed", type=int, default=1, help="Lump shape, eye spacing, object position.")
    ap.add_argument("--colour", default="green", choices=list(COLOURS), help="Body colour (acid = red).")
    ap.add_argument("--size", type=float, default=1.0, help="Body size; 1.0 fills most of the canvas.")
    ap.add_argument("--contents", default="bone", choices=["bone", "coin", "skull", "none"])
    ap.add_argument("--lumpiness", type=float, default=0.12, help="How lumpy the outline is (0-0.3).")
    ap.add_argument("--canvas", type=int, default=48, help="Frame size in pixels (use 64+ for a boss).")
    ap.add_argument("--name", default="slime", help="Output folder and sheet name.")
    ap.add_argument("--world-scale", type=int, default=2, help="Enlarge the frames this many times (default 2: 96x128 / 96x96).")
    ap.add_argument("--out", help="Output folder (default: art/monsters/<name>).")
    ap.add_argument("--preview", help="Also write a 6x enlarged preview PNG here.")
    args = ap.parse_args()
    os.environ["ART_WORLD_SCALE"] = str(args.world_scale)
    options = dict(seed=args.seed, colour=args.colour, size=args.size, contents=args.contents,
                   lumpiness=args.lumpiness, canvas=args.canvas)
    written = build(args.name, args.out, **options)
    print(f"Wrote {len(written)} files, e.g. {written[0]}")
    if args.preview:
        images = render(**options)
        scale, pad, c = 6, 8, args.canvas
        prev = Image.new("RGBA", ((c * scale + pad) * len(ORDER) + pad, c * scale + pad * 2), (*PAL["stone_900"], 255))
        for i, frame in enumerate(ORDER):
            prev.alpha_composite(images[frame].resize((c * scale, c * scale), Image.NEAREST), (pad + i * (c * scale + pad), pad))
        prev.save(args.preview)
        print("Preview:", args.preview)


if __name__ == "__main__":
    main()
