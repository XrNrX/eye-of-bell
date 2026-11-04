"""Generates the placeholder 64x64 pixel-art textures into res://textures/.

Run from the project root:  python tools/make_textures.py
Deterministic (seeded), so re-running reproduces the same PNGs.
Replace the PNGs with hand-made or AI-made art at any time; the game only
cares about the file names.
"""
import random
from pathlib import Path

from PIL import Image

SIZE = 64
OUT = Path(__file__).resolve().parent.parent / "textures"


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


def main():
    OUT.mkdir(exist_ok=True)
    blocks((120, 100, 85), (45, 38, 32), 16, 8, True, 1).save(OUT / "wall.png")
    blocks((85, 80, 75), (35, 32, 30), 32, 32, False, 2, noise=0.1).save(OUT / "floor.png")
    rough((60, 55, 52), 3).save(OUT / "ceiling.png")
    print("Wrote", [p.name for p in sorted(OUT.glob("*.png"))])


if __name__ == "__main__":
    main()
