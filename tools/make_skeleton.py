"""Procedural skeleton-warrior sprites (48x64, front-facing) for the dungeon crawler.

    python tools/make_skeleton.py                         # default skeleton
    python tools/make_skeleton.py --seed 7 --bone ash --weapon axe --helmet \
        --name skeleton_guard                             # a variant

Writes to res://art/monsters/<name>/ :
    idle_0.png idle_1.png
    attack_0.png attack_1.png attack_2.png
    hurt_0.png hurt_0_flash.png
    <name>_sheet.png + <name>_sheet.json   (one row of frames + frame rects/animations)

How it works
- Every body part (skull, jaw, ribcage, spine, pelvis, each arm/leg bone, hand, foot,
  helmet, weapon) is a separate pixel mask. A pose is just a few numbers that say where
  each part goes, so parts move independently from frame to frame.
- Each part is shaded on its own (light on the top-left edges, dark on the bottom-right),
  all parts are composited back to front, then a 1px outline is added around the whole
  silhouette.
- Only colours from PALETTE are used (checked at the end). Edit PALETTE below, or pass
  --palette my_palette.json with the same structure.
"""
import argparse
import json
import math
import random
from pathlib import Path

from PIL import Image

W, H = 48, 64
CX = 24  # Horizontal centre line of the skeleton.

# Palette. Ramps are [light, mid, dark]. Everything drawn comes from here.
PALETTE = {
    "outline": "#1b1521",
    "white": "#ffffff",
    "ivory": ["#efe6cc", "#c9bb97", "#8d7d62"],
    "ash": ["#cfd3d6", "#9fa6ad", "#656d77"],
    "mossy": ["#c8d0a0", "#94a070", "#5b6b45"],
    "iron": ["#9aa3b2", "#646b7c", "#3b4152"],
    "rust": ["#d08a45", "#9c5a2b", "#5e3419"],
    "wood": ["#7a5634", "#55391f", "#33210f"],
}


def hex_rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def load_palette(path=None):
    """Palette as RGB tuples. `path` is an optional JSON file shaped like PALETTE."""
    raw = json.loads(Path(path).read_text()) if path else PALETTE
    pal = {}
    for key, val in raw.items():
        pal[key] = [hex_rgb(c) for c in val] if isinstance(val, list) else hex_rgb(val)
    return pal


# --------------------------------------------------------------------------
# Pixel-mask helpers. A mask is a set of (x, y) integer pixels.
# --------------------------------------------------------------------------

def rows_mask(cx, y0, half_widths):
    """Stack of centred rows; row i is 2*half_widths[i] pixels wide."""
    return {(x, y0 + i) for i, hw in enumerate(half_widths) for x in range(cx - hw, cx + hw)}


def rect_mask(x, y, w, h):
    return {(x + i, y + j) for i in range(w) for j in range(h)}


def line_mask(p0, p1, width=2):
    """Thick line between two (float) points."""
    n = max(1, int(math.hypot(p1[0] - p0[0], p1[1] - p0[1]) * 2))
    lo, hi = -(width // 2), width - width // 2
    mask = set()
    for i in range(n + 1):
        t = i / n
        x = round(p0[0] + (p1[0] - p0[0]) * t)
        y = round(p0[1] + (p1[1] - p0[1]) * t)
        for dx in range(lo, hi):
            for dy in range(lo, hi):
                mask.add((x + dx, y + dy))
    return mask


def bone_mask(p0, p1):
    """A limb bone: a 2px line with a little knob at each joint."""
    mask = line_mask(p0, p1, 2)
    for p in (p0, p1):
        x, y = round(p[0]), round(p[1])
        mask |= {(x, y), (x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)}
    return mask


def ik(a, b, l1, l2, side):
    """Two-bone IK: knee position for a leg from hip `a` to planted foot `b`.
    `side` (-1 left, +1 right) picks which way the knee bows."""
    dx, dy = b[0] - a[0], b[1] - a[1]
    d = min(math.hypot(dx, dy), l1 + l2 - 0.01)
    x = (l1 * l1 - l2 * l2 + d * d) / (2 * d)
    h = math.sqrt(max(0.0, l1 * l1 - x * x))
    ux, uy = dx / d, dy / d
    px, py = -uy, ux
    if px * side < 0:
        px, py = -px, -py
    return (a[0] + ux * x + px * h, a[1] + uy * x + py * h)


def rnd(seed, name, a, b):
    """Deterministic pseudo-random 0..1 from (seed, part name, two ints)."""
    h = (seed * 2654435761 + sum(map(ord, name)) * 40503 + a * 73856093 + b * 19349663) & 0xFFFFFFFF
    h ^= h >> 13
    h = (h * 0x5BD1E995) & 0xFFFFFFFF
    h ^= h >> 15
    return (h % 1000) / 1000.0


def shade(mask, ramp):
    """Colour a mask: light top-left edges, dark bottom-right edges, a soft
    diagonal gradient on the interior of bigger parts."""
    light, mid, dark = ramp
    xs = [p[0] for p in mask]
    ys = [p[1] for p in mask]
    x0, y0 = min(xs), min(ys)
    span = max(1, (max(xs) - x0) + (max(ys) - y0))
    out = {}
    for (x, y) in mask:
        lit = (x - 1, y) not in mask or (x, y - 1) not in mask
        shadow = (x + 1, y) not in mask or (x, y + 1) not in mask
        if lit and not shadow:
            out[(x, y)] = light
        elif shadow and not lit:
            out[(x, y)] = dark
        elif lit and shadow:
            out[(x, y)] = mid
        else:
            t = ((x - x0) + (y - y0)) / span
            out[(x, y)] = light if t < 0.33 else (dark if t > 0.66 else mid)
    return out


# --------------------------------------------------------------------------
# Weapons. Built in (u, v) space: u along the weapon from the grip, v across it.
# --------------------------------------------------------------------------

def stamp(grip, ang, u0, u1, v0, v1, uv=None):
    """Mask of the u/v rectangle, rotated so +u points along `ang` (0 = down,
    positive = towards +x, 180 = up). Optionally records each pixel's (u, v)."""
    a = math.radians(ang)
    dx, dy = math.sin(a), math.cos(a)
    nx, ny = dy, -dx
    mask = set()
    u = u0
    while u <= u1 + 1e-6:
        v = v0
        while v <= v1 + 1e-6:
            p = (round(grip[0] + dx * u + nx * v), round(grip[1] + dy * u + ny * v))
            mask.add(p)
            if uv is not None and p not in uv:
                uv[p] = (u, v)
            v += 0.5
        u += 0.5
    return mask


def weapon_parts(kind, grip, ang, seed, pal):
    """List of (mask, material, details) for the chosen weapon."""
    if kind == "none":
        return []
    rust_flake = pal["iron"][0]
    if kind == "sword":
        uv = {}
        blade = stamp(grip, ang, 2, 10, -1, 1, uv) | stamp(grip, ang, 10.5, 13, -0.5, 0.5, uv)
        flakes = {p: rust_flake for p, (u, v) in uv.items()
                  if rnd(seed, "rust", round(u * 2), round(v * 2)) < 0.2}
        return [
            (stamp(grip, ang, -3, 0.5, -0.5, 0.5), "wood", {}),            # Grip.
            (stamp(grip, ang, -4, -3.5, -1, 1), "iron", {}),               # Pommel.
            (stamp(grip, ang, 1, 1.5, -3, 3), "iron", {}),                 # Crossguard.
            (blade, "rust", flakes),                                       # Rusty blade.
        ]
    if kind == "axe":
        uv = {}
        head = stamp(grip, ang, 9, 13, -0.5, 4, uv) | stamp(grip, ang, 10, 12, 4, 5.5, uv)
        flakes = {p: rust_flake for p, (u, v) in uv.items()
                  if rnd(seed, "rust", round(u * 2), round(v * 2)) < 0.2}
        return [
            (stamp(grip, ang, -3, 12, -0.5, 0.5), "wood", {}),             # Haft.
            (head, "rust", flakes),                                        # Rusty head.
        ]
    if kind == "club":
        head = set()
        u = 0.0
        while u <= 11:
            hv = 1 + u * 0.18
            head |= stamp(grip, ang, u, u + 0.5, -hv, hv)
            u += 0.5
        return [(stamp(grip, ang, -3, 0, -0.5, 0.5), "wood", {}), (head, "wood", {})]
    raise ValueError(f"unknown weapon {kind!r}")


# --------------------------------------------------------------------------
# Skeleton parts
# --------------------------------------------------------------------------

def make_traits(seed):
    """Per-seed body variation: skull width, rib count/lengths, missing tooth."""
    r = random.Random(seed)
    skull = [3, 5, 6, 7, 7, 7, 7, 7, 7, 6, 6, 5, 5]
    if r.random() < 0.4:
        for i in range(3, 9):
            skull[i] -= 1
    ribs = r.choice([3, 4, 4])
    rib_half = [min(9, max(5, h + r.choice([-1, 0, 0]))) for h in [8, 8, 7, 6][:ribs]]
    return {"skull": skull, "rib_half": rib_half, "missing_tooth": r.randrange(4)}


def dir_vec(deg):
    a = math.radians(deg)
    return (math.sin(a), math.cos(a))


def arm_points(shoulder, upper, fore, l1=7.0, l2=7.0):
    """Forward kinematics: elbow, wrist and hand centre. Angles: 0 = straight down,
    positive = towards +x, 180 = straight up."""
    ux, uy = dir_vec(upper)
    fx, fy = dir_vec(fore)
    elbow = (shoulder[0] + ux * l1, shoulder[1] + uy * l1)
    wrist = (elbow[0] + fx * l2, elbow[1] + fy * l2)
    hand = (wrist[0] + fx * 1.5, wrist[1] + fy * 1.5)
    return elbow, wrist, hand


def build_frame(pose, traits, pal, opts, flash=False):
    """Composite one frame and return it as an RGBA image."""
    ramps = {"bone": pal[opts["bone"]], "iron": pal["iron"], "rust": pal["rust"], "wood": pal["wood"]}
    seed = opts["seed"]
    damage = opts["damage"]
    parts = []  # (name, mask, material, details, anchor), drawn in this order.

    def add(name, mask, mat, details=None, anchor=(0, 0)):
        parts.append((name, mask, mat, details or {}, anchor))

    hx, hy = pose["head"]
    rx, ry = pose["ribs"]
    px, py = pose["pelvis"]
    dark = pal["outline"]

    # Legs, hips fixed to the pelvis and feet planted on the floor (IK bends the knees).
    for side, sx, hip_dx, foot_dx in (("L", -1, -5, -7), ("R", 1, 4, 6)):
        hip = (CX + hip_dx + px, 43 + py)
        foot = (CX + foot_dx, 61)
        knee = ik(hip, foot, 9.2, 9.2, sx)
        add(f"femur_{side}", bone_mask(hip, knee), "bone", anchor=hip)
        add(f"tibia_{side}", bone_mask(knee, foot), "bone", anchor=knee)
        fx0 = foot[0] - 3 if side == "L" else foot[0] - 1
        add(f"foot_{side}", rect_mask(fx0, foot[1], 5, 2), "bone", anchor=foot)

    # Pelvis with a gap between the hip bones.
    pelvis = rows_mask(CX + px, 37 + py, [8, 8, 7, 7, 6, 5, 4, 3])
    for y in range(40 + py, 44 + py):
        pelvis -= {(CX + px - 1, y), (CX + px, y)}
    add("pelvis", pelvis, "bone", anchor=(CX + px, 37 + py))

    # Spine: vertebrae from the base of the skull to the top of the pelvis.
    top = (CX + hx, 15 + hy)
    bottom = (CX + px, 38 + py)
    steps = max(1, int(math.hypot(bottom[0] - top[0], bottom[1] - top[1]) / 3))
    spine = set()
    for i in range(steps + 1):
        t = i / steps
        spine |= rect_mask(round(top[0] + (bottom[0] - top[0]) * t) - 1,
                           round(top[1] + (bottom[1] - top[1]) * t) - 1, 2, 2)
    add("spine", spine, "bone", anchor=top)

    # Ribcage: collar bone, sternum and curved ribs.
    yt = 22 + ry  # Leaves a visible neck between the jaw and the collar bone.
    ribs = rect_mask(CX + rx - 10, yt, 20, 2)
    n = len(traits["rib_half"])
    ribs |= rect_mask(CX + rx - 1, yt + 2, 2, 3 * n + 1)
    for i, half in enumerate(traits["rib_half"]):
        y = yt + 3 + i * 3
        ribs |= rect_mask(CX + rx - 1 - half, y, half - 1, 2)
        ribs |= rect_mask(CX + rx + 1, y, half, 2)
        ribs |= {(CX + rx - 1 - half, y + 2), (CX + rx + half, y + 2)}  # Curled tips.
    add("ribcage", ribs, "bone", anchor=(CX + rx, yt))

    # Left arm (viewer's left), behind the skull.
    shoulder_l = (CX - 10 + rx, 23 + ry)
    elbow, wrist, hand = arm_points(shoulder_l, *pose["L"])
    add("upper_arm_L", bone_mask(shoulder_l, elbow), "bone", anchor=shoulder_l)
    add("forearm_L", bone_mask(elbow, wrist), "bone", anchor=elbow)
    add("hand_L", rect_mask(round(hand[0]) - 1, round(hand[1]) - 1, 3, 3), "bone", anchor=hand)

    # Skull: cranium rows, eye sockets and nose cut as dark details.
    y0 = 2 + hy
    skull = rows_mask(CX + hx, y0, traits["skull"])
    details = {}
    for ex in (CX + hx - 5, CX + hx + 2):
        for p in rect_mask(ex, y0 + 5, 3, 3):
            details[p] = dark
    details[(CX + hx - 1, y0 + 9)] = dark
    details[(CX + hx, y0 + 9)] = dark
    add("skull", skull, "bone", details, anchor=(CX + hx, y0))

    # Jaw: moves down by pose["jaw"]; alternate pixels removed on the top row as teeth.
    jy = y0 + 13 + pose["jaw"]
    jaw = rows_mask(CX + hx, jy, [5, 5, 4, 3])
    gaps = [CX + hx - 3, CX + hx - 1, CX + hx + 1, CX + hx + 3]
    for gx in gaps:
        jaw.discard((gx, jy))
    jaw.discard((gaps[traits["missing_tooth"]] + 1, jy))  # The missing tooth.
    add("jaw", jaw, "bone", anchor=(CX + hx, jy))

    if opts["helmet"]:
        helmet = rows_mask(CX + hx, y0 - 1, [4, 6, 7, 8, 8, 8])
        helmet |= rect_mask(CX + hx - 1, y0 + 5, 2, 4)  # Nasal guard between the eyes.
        add("helmet", helmet, "iron", anchor=(CX + hx, y0))

    # Right arm (viewer's right), holding the weapon in front of its hand.
    shoulder_r = (CX + 9 + rx, 23 + ry)
    elbow, wrist, hand = arm_points(shoulder_r, *pose["R"])
    add("upper_arm_R", bone_mask(shoulder_r, elbow), "bone", anchor=shoulder_r)
    add("forearm_R", bone_mask(elbow, wrist), "bone", anchor=elbow)
    for i, (mask, mat, det) in enumerate(weapon_parts(opts["weapon"], hand, pose["sword"], seed, pal)):
        add(f"weapon_{i}", mask, mat, det, anchor=hand)
    add("hand_R", rect_mask(round(hand[0]) - 1, round(hand[1]) - 1, 3, 3), "bone", anchor=hand)

    # Shade every part on its own, then composite back to front.
    canvas = {}
    for name, mask, mat, details, anchor in parts:
        ramp = ramps[mat]
        layer = shade(mask, ramp)
        for p in layer:
            if mat == "bone" and rnd(seed, name, p[0] - round(anchor[0]), p[1] - round(anchor[1])) < damage:
                layer[p] = ramp[2]  # Chips and cracks.
        for p, colour in details.items():
            if p in layer:
                layer[p] = colour
        canvas.update(layer)

    canvas = {p: c for p, c in canvas.items() if 0 <= p[0] < W and 0 <= p[1] < H}
    if flash:  # Hurt flash: the whole body goes white.
        canvas = {p: pal["white"] for p in canvas}

    # 1px outline around the whole silhouette (including the gaps between bones).
    outline = {}
    for (x, y) in canvas:
        for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
            if (nx, ny) not in canvas and 0 <= nx < W and 0 <= ny < H:
                outline[(nx, ny)] = pal["outline"]
    canvas.update(outline)

    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    for (x, y), c in canvas.items():
        img.putpixel((x, y), (*c, 255))
    return img


# --------------------------------------------------------------------------
# Poses and frames. Arm angles: 0 = straight down, +ve towards +x, 180 = up.
# --------------------------------------------------------------------------

BASE = {"head": (0, 0), "jaw": 0, "ribs": (0, 0), "pelvis": (0, 0),
        "R": (25, 160), "L": (-15, -8), "sword": 175}


def pose(**kw):
    p = dict(BASE)
    p.update(kw)
    return p


FRAMES = {
    "idle_0": pose(),
    "idle_1": pose(head=(0, 1), jaw=2, ribs=(0, 1), pelvis=(0, 1), sword=172),
    "attack_0": pose(head=(1, -1), jaw=1, ribs=(0, -1), R=(100, 170), L=(-55, -30), sword=180),
    "attack_1": pose(head=(-1, 2), jaw=3, ribs=(-1, 1), pelvis=(0, 1), R=(55, 25), L=(-20, -10), sword=-50),
    "attack_2": pose(head=(-2, 3), jaw=2, ribs=(-1, 2), pelvis=(-1, 1), R=(30, -20), L=(-50, -60), sword=-80),
    "hurt_0": pose(head=(3, -1), jaw=3, ribs=(1, 0), R=(50, 130), L=(-50, -130), sword=200),
}
ANIMATIONS = {
    "idle": ["idle_0", "idle_1"],
    "attack": ["attack_0", "attack_1", "attack_2"],
    "hurt": ["hurt_0", "hurt_0_flash"],
}


def main():
    root = Path(__file__).resolve().parent.parent
    ap = argparse.ArgumentParser(description="Generate a skeleton warrior sprite set.")
    ap.add_argument("--seed", type=int, default=1, help="Body variation + rust/crack pattern.")
    ap.add_argument("--bone", default="ivory", help="Bone colour ramp from the palette (ivory/ash/mossy).")
    ap.add_argument("--weapon", default="sword", choices=["sword", "axe", "club", "none"])
    ap.add_argument("--helmet", action="store_true", help="Add an iron helmet.")
    ap.add_argument("--damage", type=float, default=0.04, help="Fraction of bone pixels chipped (0-0.2).")
    ap.add_argument("--name", default="skeleton", help="Output folder and sheet name.")
    ap.add_argument("--out", help="Output folder (default: art/monsters/<name>).")
    ap.add_argument("--palette", help="JSON palette file shaped like PALETTE.")
    ap.add_argument("--preview", help="Also write a 6x enlarged preview PNG here.")
    args = ap.parse_args()

    pal = load_palette(args.palette)
    if args.bone not in pal or not isinstance(pal[args.bone], list):
        raise SystemExit(f"--bone must be a colour ramp in the palette, got {args.bone!r}")
    opts = {"seed": args.seed, "bone": args.bone, "weapon": args.weapon,
            "helmet": args.helmet, "damage": args.damage}
    traits = make_traits(args.seed)

    images = {name: build_frame(p, traits, pal, opts) for name, p in FRAMES.items()}
    images["hurt_0_flash"] = build_frame(FRAMES["hurt_0"], traits, pal, opts, flash=True)
    order = ["idle_0", "idle_1", "attack_0", "attack_1", "attack_2", "hurt_0", "hurt_0_flash"]

    # Safety check: nothing outside the palette.
    allowed = set()
    for val in pal.values():
        allowed.update(val if isinstance(val, list) else [val])
    for name, img in images.items():
        px = img.load()
        for y in range(H):
            for x in range(W):
                r, g, b, a = px[x, y]
                if a and (r, g, b) not in allowed:
                    raise SystemExit(f"{name}: colour {(r, g, b)} is not in the palette")

    out = Path(args.out) if args.out else root / "art" / "monsters" / args.name
    out.mkdir(parents=True, exist_ok=True)
    sheet = Image.new("RGBA", (W * len(order), H), (0, 0, 0, 0))
    rects = {}
    for i, name in enumerate(order):
        images[name].save(out / f"{name}.png")
        sheet.paste(images[name], (i * W, 0))
        rects[name] = {"x": i * W, "y": 0, "w": W, "h": H}
    sheet.save(out / f"{args.name}_sheet.png")
    (out / f"{args.name}_sheet.json").write_text(json.dumps(
        {"frame_size": [W, H], "frames": rects, "animations": ANIMATIONS}, indent=2))
    print(f"Wrote {len(order)} frames + {args.name}_sheet.png/.json to {out}")

    if args.preview:
        scale = 6
        pad = 8
        pw = (W * scale + pad) * len(order) + pad
        prev = Image.new("RGBA", (pw, H * scale + pad * 2), (52, 46, 60, 255))
        for i, name in enumerate(order):
            big = images[name].resize((W * scale, H * scale), Image.NEAREST)
            prev.alpha_composite(big, (pad + i * (W * scale + pad), pad))
        Path(args.preview).parent.mkdir(parents=True, exist_ok=True)
        prev.save(args.preview)
        print("Preview:", args.preview)


if __name__ == "__main__":
    main()
