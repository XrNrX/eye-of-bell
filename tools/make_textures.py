"""Generates the placeholder pixel art: 64x64 tiles into res://art/tiles/ (wall,
floor, ceiling, door) and the torch sprite sheet into res://art/sprites/.

Run from the project root:  python tools/make_textures.py
Deterministic (seeded), so re-running reproduces the same PNGs.
Replace the PNGs with hand-made or AI-made art at any time; the game only
cares about the file names.
"""
import random
from pathlib import Path

from PIL import Image

SIZE = 64
OUT = Path(__file__).resolve().parent.parent / "art" / "tiles"


def shade(color, f):
    """Multiply an RGB colour by factor f, clamped to 0-255."""
    return tuple(max(0, min(255, int(c * f))) for c in color)


def blocks(base, mortar, bw, bh, offset_rows, seed, noise=0.07):
    """Tileable block pattern (bricks or flagstones) with per-block tint,
    per-pixel noise, a lit top edge and a shadowed bottom edge."""
    rng = random.Random(seed)
    img = Image.new("RGB", (SIZE, SIZE))
    px = img.load()
    rows = SIZE // bh
    tints = {}
    for y in range(SIZE):
        row = y // bh
        shift = (bw // 2) if (offset_rows and row % 2) else 0
        for x in range(SIZE):
            bx = ((x + shift) % SIZE) // bw
            key = (row, bx)
            if key not in tints:
                tints[key] = rng.uniform(0.85, 1.15)
            lx = (x + shift) % bw
            ly = y % bh
            if lx == 0 or ly == 0:
                c = shade(mortar, rng.uniform(0.9, 1.1))
            else:
                f = tints[key] * (1 + rng.uniform(-noise, noise))
                if ly == 1:
                    f *= 1.25          # highlight under the top mortar line
                elif ly == bh - 1:
                    f *= 0.75          # shadow above the bottom mortar line
                if lx == 1:
                    f *= 1.1
                c = shade(base, f)
            px[x, y] = c
    return img


def rough(base, seed):
    """Dark mottled stone for the ceiling."""
    rng = random.Random(seed)
    img = Image.new("RGB", (SIZE, SIZE))
    px = img.load()
    # Coarse 8x8 blotches blended with fine noise.
    coarse = [[rng.uniform(0.8, 1.2) for _ in range(SIZE // 8)] for _ in range(SIZE // 8)]
    for y in range(SIZE):
        for x in range(SIZE):
            f = coarse[y // 8][x // 8] * rng.uniform(0.9, 1.1)
            px[x, y] = shade(base, f)
    return img


def door(seed):
    """Wooden plank door: vertical planks, two iron bands with rivets, a handle ring."""
    rng = random.Random(seed)
    img = Image.new("RGB", (SIZE, SIZE))
    px = img.load()
    plank_tints = [rng.uniform(0.85, 1.15) for _ in range(SIZE // 16)]
    wood = (110, 72, 40)
    iron = (58, 60, 66)
    for y in range(SIZE):
        for x in range(SIZE):
            if x % 16 == 0:                      # Gap between planks.
                px[x, y] = (28, 18, 10)
                continue
            grain = 1.0 + (0.08 if (x + y // 7) % 5 == 0 else 0.0) + rng.uniform(-0.05, 0.05)
            px[x, y] = shade(wood, plank_tints[x // 16] * grain)
    for band_y in (8, 48):                       # Iron bands.
        for y in range(band_y, band_y + 6):
            for x in range(SIZE):
                f = 1.3 if y == band_y else (0.7 if y == band_y + 5 else 1.0)
                px[x, y] = shade(iron, f * rng.uniform(0.95, 1.05))
        for x in range(4, SIZE, 16):             # Rivets, one per plank.
            px[x, band_y + 2] = (150, 150, 160)
    for dx, dy in [(-3, 0), (-2, -2), (0, -3), (2, -2), (3, 0), (2, 2), (0, 3), (-2, 2)]:
        px[50 + dx, 30 + dy] = (150, 150, 160)   # Handle ring.
    px[50, 30] = (20, 14, 8)
    return img


def torch_sheet():
    """Wall torch, 4 animation frames of 16x32 laid out left to right (64x32)."""
    fw, fh = 16, 32
    sheet = Image.new("RGBA", (fw * 4, fh), (0, 0, 0, 0))
    px = sheet.load()
    tops = [4, 2, 5, 3]      # Flame tip row per frame (lower number = taller flame).
    sways = [0, 1, 0, -1]    # Sideways lean of the tip per frame.
    for f in range(4):
        ox = f * fw
        for y in range(17, 32):                  # Wooden handle.
            for x in (7, 8):
                px[ox + x, y] = (95, 60, 32, 255) if x == 7 else (70, 44, 24, 255)
        for x in range(4, 12):                   # Iron cup at the top of the handle.
            px[ox + x, 15] = (70, 72, 80, 255)
        for x in range(5, 11):
            px[ox + x, 16] = (45, 46, 52, 255)
        for x in range(5, 11):                   # Iron bracket lower down.
            px[ox + x, 24] = (70, 72, 80, 255)
        height = 15 - tops[f]
        for i in range(height):                  # Flame, drawn tip to base.
            t = i / height
            hw = round(3.4 * (t ** 0.6) * (1 - 0.35 * t))
            cx = 8 + round(sways[f] * (1 - t) * 2)
            for dx in range(-hw, hw + 1):
                if hw == 0:
                    color = (255, 200, 70, 255)
                elif abs(dx) <= hw * 0.35 and t > 0.4:
                    color = (255, 245, 190, 255)     # Hot core.
                elif abs(dx) <= hw * 0.7:
                    color = (255, 190, 60, 255)      # Mid flame.
                else:
                    color = (225, 90, 25, 255)       # Cool outer edge.
                px[ox + cx + dx, tops[f] + i] = color
    return sheet


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    blocks((120, 100, 85), (45, 38, 32), 16, 8, True, 1).save(OUT / "wall.png")
    blocks((85, 80, 75), (35, 32, 30), 32, 32, False, 2, noise=0.1).save(OUT / "floor.png")
    rough((60, 55, 52), 3).save(OUT / "ceiling.png")
    door(4).save(OUT / "door.png")
    print("Wrote", [p.name for p in sorted(OUT.glob("*.png"))])

    sprites = OUT.parent / "sprites"
    sprites.mkdir(parents=True, exist_ok=True)
    torch_sheet().save(sprites / "torch.png")
    print("Wrote", [p.name for p in sorted(sprites.glob("*.png"))])


if __name__ == "__main__":
    main()
