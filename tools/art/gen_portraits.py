"""Procedural party portraits (32x32, front-facing bust), palette-bound.

    python tools/art/gen_portraits.py                              # all 4 classes, default seeds
    python tools/art/gen_portraits.py --class fighter --seed 7      # reroll one face
    python tools/art/gen_portraits.py --class mage --seed 3 --name mage_old

Writes to res://art/portraits/<name>/ :
    portrait.png        the living face
    portrait_hurt.png   red-tinted flash, shown briefly when the hero is hit
    portrait_dead.png   greyed out, shown once the hero reaches 0 HP

How it works
- The head, head covering and chin/neck part are each a pixel mask (row half-widths,
  like the skeleton's skull), shaded with the toolkit's top-left lighting.
- A seed jitters the face shape and picks a skin tone, so rerolling a class keeps its
  identity (head covering, chin part, robe colour) but gives a different face.
- Every class picks ONE head covering (helmet/hood/hat/hair) and ONE chin part
  (beard/cowl/none) -- the two modular choices the brief asked for.
- hurt/dead are derived from the living portrait by recolouring every pixel and
  re-snapping (hurt) or remapping onto the grey stone ramp (dead), so they are
  palette-exact by construction.
"""
import argparse
from pathlib import Path

from PIL import Image

from artio import save_png
from lighting import shade_mask
from noise import hash01
from outline import add_outline
from palette import PAL

SIZE = 32
CX = 16

# Skin tones: 3 options, all drawn from existing ramps (no new palette colours).
SKIN_RAMPS = {
    "pale": [PAL["bone_700"], PAL["bone_500"], PAL["bone_300"]],
    "tan": [PAL["wood_700"], PAL["wood_500"], PAL["leather_400"]],
    "deep": [PAL["soil_900"], PAL["wood_700"], PAL["wood_500"]],
}
SKIN_NAMES = list(SKIN_RAMPS)
HAIR_RAMP = [PAL["bone_700"], PAL["bone_500"]]           # Warm tan/grey hair.
IRON = [PAL["stone_800"], PAL["stone_700"], PAL["stone_500"]]
CLOTH_DARK = [PAL["soil_900"], PAL["wood_700"]]
CLOTH_LIGHT = [PAL["stone_500"], PAL["stone_300"], PAL["stone_100"]]
TRIM = PAL["torch_500"]
ROBE_MOSS = [PAL["moss_900"], PAL["moss_700"], PAL["moss_500"]]
INK = PAL["ink"]

# Baseline face half-width per row, y=5..20 (16 rows): narrow brow, wide cheeks, chin.
FACE_PROFILE = [4, 5, 6, 7, 7, 8, 8, 8, 8, 8, 7, 7, 6, 5, 4, 3]
FACE_TOP = 5


def clamp(v, lo, hi):
    return max(lo, min(hi, v))


def rnd(seed, label, a, b=0):
    """Deterministic pseudo-random 0..1 from (seed, a text label, two ints)."""
    return hash01(seed + sum(map(ord, label)) * 40503, a, b)


def rows(cx, y0, half_widths):
    return {(x, y0 + i) for i, hw in enumerate(half_widths) for x in range(cx - hw, cx + hw + 1)}


# --------------------------------------------------------------------------
# Head
# --------------------------------------------------------------------------

def face_mask(seed):
    """The head outline, jittered per seed so every reroll has a slightly different
    face. Returns (mask, half_widths) -- other parts size themselves off the widths."""
    widths = []
    for i, base in enumerate(FACE_PROFILE):
        jitter = round((rnd(seed, "face", i) - 0.5) * 2)
        widths.append(clamp(base + jitter, 2, 10))
    return rows(CX, FACE_TOP, widths), widths


def eyes_and_mouth(skin_ramp):
    """Ink eyes with a skin-tone highlight above each, and a short mouth line."""
    pixels = {}
    for ex in (CX - 4, CX - 3, CX + 2, CX + 3):
        pixels[(ex, 12)] = INK
    pixels[(CX - 4, 11)] = skin_ramp[-1]
    pixels[(CX + 2, 11)] = skin_ramp[-1]
    for mx in range(CX - 2, CX + 2):
        pixels[(mx, 17)] = INK
    return pixels


# --- Head coverings: pick exactly one. Each returns (mask, ramp, extra pixels). ---

def helmet_part(seed):
    widths = [5, 6, 7, 7, 7, 7, 7, 7, 7, 6]  # Flatter top than a hood: less dome, more skullcap.
    mask = rows(CX, 2, widths)
    extra = {(x, 11): IRON[-1] for x in range(CX - widths[-1], CX + widths[-1] + 1)}  # Bright brow rim.
    for y in range(8, 14):  # Nose guard: a bright 2px bar down the centre of the face.
        extra[(CX - 1, y)] = IRON[-1]
        extra[(CX, y)] = IRON[0]
    return mask, IRON, extra


def hood_part(seed):
    widths = [7, 8, 9, 10, 10, 10, 9, 8]  # Draped lower and wider than the helmet.
    return rows(CX, 2, widths), CLOTH_DARK, {}


def hat_part(seed):
    n = 11
    mask = set()
    for i in range(n):
        hw = clamp(round(1 + (9 - 1) * i / (n - 1)), 1, 9)
        mask |= rows(CX, 1 + i, [hw])
    mask |= rows(CX, 11, [11])  # Brim.
    return mask, ROBE_MOSS, {}


def hair_part(seed):
    widths = [5, 6, 7, 7, 7]
    return rows(CX, 3, widths), HAIR_RAMP, {}


HEAD_PARTS = {"helmet": helmet_part, "hood": hood_part, "hat": hat_part, "hair": hair_part}

# --- Chin parts: beard, cowl (a draped hood collar) or none. ---

def beard_part(bushy):
    if bushy:  # Long wizard beard, past the chin.
        widths = [7, 8, 8, 7, 6, 4]
        return rows(CX, 17, widths), [PAL["bone_500"], PAL["bone_300"]]
    widths = [4, 3]  # Stubble, just under the chin.
    return rows(CX, 20, widths), [PAL["soil_900"], PAL["wood_700"]]


def cowl_part():
    mask = rows(CX, 19, [5, 6, 7, 8, 9])
    trim = {(x, y): TRIM for y in (19, 20) for x in range(CX - 5, CX + 6)}
    return mask, CLOTH_LIGHT, trim


# Per-class look: head covering, chin part, shoulder/robe ramp.
CLASSES = {
    "fighter": {"head": "helmet", "chin": "beard", "bushy_beard": False, "shoulders": IRON},
    "cleric": {"head": "hair", "chin": "cowl", "shoulders": CLOTH_LIGHT},
    "thief": {"head": "hood", "chin": "none", "shoulders": CLOTH_DARK},
    "mage": {"head": "hat", "chin": "beard", "bushy_beard": True, "shoulders": ROBE_MOSS},
}
DEFAULT_SEEDS = {"fighter": 1, "cleric": 4, "thief": 2, "mage": 6}


def shoulders_mask():
    widths = [clamp(round(4 + (15 - 4) * i / 9), 4, 15) for i in range(10)]
    return rows(CX, 22, widths)


def render(cls: str, seed: int) -> Image.Image:
    preset = CLASSES[cls]
    skin_name = SKIN_NAMES[int(rnd(seed, "skin", 0) * len(SKIN_NAMES))]
    skin_ramp = SKIN_RAMPS[skin_name]

    face, widths = face_mask(seed)
    canvas = shade_mask(face, skin_ramp)
    canvas.update(eyes_and_mouth(skin_ramp))

    neck = rows(CX, 20, [widths[-1] - 1, widths[-1] - 1])
    canvas.update(shade_mask(neck, skin_ramp))

    canvas.update(shade_mask(shoulders_mask(), preset["shoulders"]))

    head_mask, head_ramp, head_extra = HEAD_PARTS[preset["head"]](seed)
    canvas.update(shade_mask(head_mask, head_ramp))
    canvas.update(head_extra)

    if preset["chin"] == "beard":
        beard_mask, beard_ramp = beard_part(preset.get("bushy_beard", False))
        canvas.update(shade_mask(beard_mask, beard_ramp))
    elif preset["chin"] == "cowl":
        cowl_mask, cowl_ramp, trim_pixels = cowl_part()
        canvas.update(shade_mask(cowl_mask, cowl_ramp))
        canvas.update(trim_pixels)

    img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    px = img.load()
    for (x, y), c in canvas.items():
        if 0 <= x < SIZE and 0 <= y < SIZE:
            px[x, y] = (*c, 255)
    return add_outline(img, INK)


# --------------------------------------------------------------------------
# Hurt (red tint) and dead (greyed out) variants
# --------------------------------------------------------------------------

def hurt_variant(img: Image.Image, amount: float = 0.55) -> Image.Image:
    """Blend every opaque pixel towards a rust/red and snap back onto the palette.
    The palette has no pure red, so this reads as a warm orange-red flash."""
    tint = PAL["rust_500"]
    out = img.convert("RGBA").copy()
    px = out.load()
    for y in range(out.height):
        for x in range(out.width):
            r, g, b, a = px[x, y]
            if a:
                px[x, y] = (round(r + (tint[0] - r) * amount), round(g + (tint[1] - g) * amount),
                           round(b + (tint[2] - b) * amount), 255)
    return PAL.snap(out)


def _luminance(rgb):
    return 0.299 * rgb[0] + 0.587 * rgb[1] + 0.114 * rgb[2]


def dead_variant(img: Image.Image) -> Image.Image:
    """Map every opaque pixel onto the closest-luminance grey from the stone ramp, so
    the result is true grey (never tinted) and already palette-exact."""
    stone = PAL.ramp("stone")
    stone_lum = [_luminance(c) for c in stone]
    out = img.convert("RGBA").copy()
    px = out.load()
    cache = {}
    for y in range(out.height):
        for x in range(out.width):
            r, g, b, a = px[x, y]
            if a:
                key = (r, g, b)
                if key not in cache:
                    lum = _luminance(key)
                    cache[key] = min(stone, key=lambda c: abs(_luminance(c) - lum))
                px[x, y] = (*cache[key], 255)
    return out


def build(name: str = None, out_dir: str = None, cls: str = "fighter", seed: int = None):
    """Generate one character's three portraits, or (name=None) all four classes at
    their default seeds. Returns the files written."""
    if name is None:
        written = []
        for c, s in DEFAULT_SEEDS.items():
            written += build(c, out_dir, c, s)
        return written

    seed = DEFAULT_SEEDS.get(cls, 1) if seed is None else seed
    living = render(cls, seed)
    root, sub = (Path(out_dir), "") if out_dir else (None, f"portraits/{name}/")
    written = [
        save_png(living, f"{sub}portrait.png", root=root),
        save_png(hurt_variant(living), f"{sub}portrait_hurt.png", root=root),
        save_png(dead_variant(living), f"{sub}portrait_dead.png", root=root),
    ]
    return written


def main():
    ap = argparse.ArgumentParser(description="Generate a party portrait (living/hurt/dead).")
    ap.add_argument("--class", dest="cls", default="fighter", choices=list(CLASSES),
                    help="Head covering, chin part and robe colour come from the class.")
    ap.add_argument("--seed", type=int, help="Face shape + skin tone. Omit for the class default.")
    ap.add_argument("--name", help="Output folder name (default: the class name).")
    ap.add_argument("--out", help="Output folder (default: art/portraits/<name>).")
    ap.add_argument("--preview", help="Also write a 6x enlarged preview PNG of all three variants here.")
    args = ap.parse_args()
    name = args.name or args.cls
    written = build(name, args.out, args.cls, args.seed)
    print(f"Wrote {len(written)} files, e.g. {written[0]}")

    if args.preview:
        seed = args.seed if args.seed is not None else DEFAULT_SEEDS.get(args.cls, 1)
        living = render(args.cls, seed)
        frames = [living, hurt_variant(living), dead_variant(living)]
        scale, pad = 6, 8
        prev = Image.new("RGBA", ((SIZE * scale + pad) * len(frames) + pad, SIZE * scale + pad * 2),
                         (*PAL["stone_900"], 255))
        for i, frame in enumerate(frames):
            prev.alpha_composite(frame.resize((SIZE * scale, SIZE * scale), Image.NEAREST),
                                 (pad + i * (SIZE * scale + pad), pad))
        prev.save(args.preview)
        print("Preview:", args.preview)


if __name__ == "__main__":
    main()
