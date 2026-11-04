"""Procedural skeleton-warrior sprites (48x64, front-facing), palette-bound.

    python tools/art/gen_skeleton.py                         # default skeleton
    python tools/art/gen_skeleton.py --seed 7 --bone ash --weapon axe --helmet \
        --name skeleton_guard                                # a variant

Writes to res://art/monsters/<name>/ :
    idle_0.png idle_1.png
    attack_0.png attack_1.png attack_2.png
    hurt_0.png hurt_0_flash.png
    <name>_sheet.png + <name>_sheet.json   (one row of frames + frame rects/animations)

How it works
- Every body part (skull, jaw, ribcage, spine, pelvis, each arm/leg bone, hand, foot,
  helmet, weapon) is a separate pixel mask. A pose is just a few numbers that say where
  each part goes, so parts move independently from frame to frame.
- Each part is shaded on its own (toolkit lighting: light top-left, dark bottom-right),
  all parts are composited back to front, then the toolkit adds a 1px outline around the
  whole silhouette.
- Only palette.json colours are used; save_png refuses anything else.
"""
import argparse
import json
import math
import random
from pathlib import Path

from PIL import Image

from artio import save_frames
from lighting import shade_mask
from noise import hash01
from outline import add_outline
from palette import ART_DIR, PAL

W, H = 48, 64
CX = 24  # Horizontal centre line of the skeleton.

# Colour ramps, [dark, mid, light], all from the palette.
BONE_RAMPS = {
    "ivory": [PAL["bone_700"], PAL["bone_500"], PAL["bone_300"]],
    "ash": [PAL["stone_500"], PAL["stone_300"], PAL["stone_100"]],
    "mossy": [PAL["moss_700"], PAL["moss_500"], PAL["slime_300"]],
}
IRON = [PAL["stone_700"], PAL["stone_500"], PAL["stone_300"]]
RUST = PAL.ramp("rust")
WOOD = [PAL["wood_700"], PAL["wood_500"], PAL["leather_400"]]
OUTLINE = PAL["ink"]
FLASH = PAL["bone_300"]    # The palette's white, used flat for the hurt flash.
FLAKE = PAL["stone_300"]   # Bare metal showing through the rust.


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
    return hash01(seed + sum(map(ord, name)) * 40503, a, b)


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


def weapon_parts(kind, grip, ang, seed):
    """List of (mask, material, details) for the chosen weapon."""
    if kind == "none":
        return []
    rust_flake = FLAKE
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


def build_frame(pose, traits, opts, flash=False):
    """Composite one frame and return it as an RGBA image."""
    ramps = {"bone": BONE_RAMPS[opts["bone"]], "iron": IRON, "rust": RUST, "wood": WOOD}
    seed = opts["seed"]
    damage = opts["damage"]
    parts = []  # (name, mask, material, details, anchor), drawn in this order.

    def add(name, mask, mat, details=None, anchor=(0, 0)):
        parts.append((name, mask, mat, details or {}, anchor))

    hx, hy = pose["head"]
    rx, ry = pose["ribs"]
    px, py = pose["pelvis"]
    dark = OUTLINE

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
    for i, (mask, mat, det) in enumerate(weapon_parts(opts["weapon"], hand, pose["sword"], seed)):
        add(f"weapon_{i}", mask, mat, det, anchor=hand)
    add("hand_R", rect_mask(round(hand[0]) - 1, round(hand[1]) - 1, 3, 3), "bone", anchor=hand)

    # Shade every part on its own, then composite back to front.
    canvas = {}
    for name, mask, mat, details, anchor in parts:
        ramp = ramps[mat]
        layer = shade_mask(mask, ramp)
        for p in layer:
            if mat == "bone" and rnd(seed, name, p[0] - round(anchor[0]), p[1] - round(anchor[1])) < damage:
                layer[p] = ramp[0]  # Chips and cracks (darkest tone).
        for p, colour in details.items():
            if p in layer:
                layer[p] = colour
        canvas.update(layer)

    canvas = {p: c for p, c in canvas.items() if 0 <= p[0] < W and 0 <= p[1] < H}
    if flash:  # Hurt flash: the whole body goes white.
        canvas = {p: FLASH for p in canvas}

    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    px = img.load()
    for (x, y), c in canvas.items():
        px[x, y] = (*c, 255)
    return add_outline(img, OUTLINE)  # 1px outline around the whole silhouette.


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


ORDER = ["idle_0", "idle_1", "attack_0", "attack_1", "attack_2", "hurt_0", "hurt_0_flash"]


def render(seed=1, bone="ivory", weapon="sword", helmet=False, damage=0.04):
    """All frames as {name: RGBA image}."""
    opts = {"seed": seed, "bone": bone, "weapon": weapon, "helmet": helmet, "damage": damage}
    traits = make_traits(seed)
    images = {name: build_frame(p, traits, opts) for name, p in FRAMES.items()}
    images["hurt_0_flash"] = build_frame(FRAMES["hurt_0"], traits, opts, flash=True)
    return images


def build(name="skeleton", out_dir=None, **options):
    """Write the frames, sheet and sheet JSON. Default folder: res://art/monsters/<name>/.
    Options: seed, bone (ivory/ash/mossy), weapon (sword/axe/club/none), helmet, damage."""
    return save_frames(render(**options), ORDER, ANIMATIONS, name, out_dir)


def main():
    ap = argparse.ArgumentParser(description="Generate a skeleton warrior sprite set.")
    ap.add_argument("--seed", type=int, default=1, help="Body variation + rust/crack pattern.")
    ap.add_argument("--bone", default="ivory", choices=list(BONE_RAMPS), help="Bone colour ramp.")
    ap.add_argument("--weapon", default="sword", choices=["sword", "axe", "club", "none"])
    ap.add_argument("--helmet", action="store_true", help="Add an iron helmet.")
    ap.add_argument("--damage", type=float, default=0.04, help="Fraction of bone pixels chipped (0-0.2).")
    ap.add_argument("--name", default="skeleton", help="Output folder and sheet name.")
    ap.add_argument("--out", help="Output folder (default: art/monsters/<name>).")
    ap.add_argument("--preview", help="Also write a 6x enlarged preview PNG here.")
    args = ap.parse_args()
    options = {"seed": args.seed, "bone": args.bone, "weapon": args.weapon,
               "helmet": args.helmet, "damage": args.damage}
    written = build(args.name, args.out, **options)
    print(f"Wrote {len(written)} files, e.g. {written[0]}")

    if args.preview:
        images = render(**options)
        scale, pad = 6, 8
        prev = Image.new("RGBA", ((W * scale + pad) * len(ORDER) + pad, H * scale + pad * 2), (*PAL["stone_900"], 255))
        for i, frame in enumerate(ORDER):
            big = images[frame].resize((W * scale, H * scale), Image.NEAREST)
            prev.alpha_composite(big, (pad + i * (W * scale + pad), pad))
        prev.save(args.preview)
        print("Preview:", args.preview)


if __name__ == "__main__":
    main()
