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


def locked_door(seed):
    """The plain door with a big brass padlock and keyhole on top."""
    img = door(seed)
    px = img.load()
    brass, dark = (200, 160, 50), (20, 14, 8)
    for x in range(26, 38):                       # Shackle (arch above the lock body).
        for y in range(18, 30):
            if (x in (26, 27, 36, 37)) or (y in (18, 19) and 28 <= x <= 35):
                px[x, y] = (150, 150, 160)
    for y in range(28, 46):                       # Lock body.
        for x in range(22, 42):
            edge = x in (22, 41) or y in (28, 45)
            px[x, y] = shade(brass, 0.7 if edge else (1.15 if y < 33 else 1.0))
    for y in range(34, 40):                       # Keyhole.
        for x in (31, 32):
            px[x, y] = dark
    for y in range(39, 43):
        px[31, y] = dark
        px[32, y] = dark
    for x in (30, 33):
        px[x, 36] = dark
    return img


def plate(seed):
    """Pressure plate: a bevelled stone slab with a ring and a gold diamond rune."""
    img = blocks((100, 95, 90), (40, 38, 36), SIZE, SIZE, False, seed, noise=0.05)
    px = img.load()
    cx = cy = SIZE // 2
    for y in range(SIZE):
        for x in range(SIZE):
            d = ((x - cx) ** 2 + (y - cy) ** 2) ** 0.5
            if 17 <= d < 19:                       # Carved ring.
                px[x, y] = (45, 42, 40)
            if abs(x - cx) + abs(y - cy) <= 8:     # Gold diamond.
                px[x, y] = (215, 175, 60) if abs(x - cx) + abs(y - cy) <= 5 else (140, 105, 35)
    return img


def lever_sheet():
    """Wall lever, 2 frames of 16x16 side by side: handle up (off), handle down (on)."""
    sheet = Image.new("RGBA", (32, 16), (0, 0, 0, 0))
    px = sheet.load()
    iron, dark, steel, knob = (88, 90, 98, 255), (40, 42, 48, 255), (170, 172, 180, 255), (200, 50, 40, 255)
    for f in range(2):
        ox = f * 16
        for y in range(1, 15):                     # Back plate.
            for x in range(4, 12):
                edge = x in (4, 11) or y in (1, 14)
                px[ox + x, y] = dark if edge else iron
        for y in range(3, 13):                     # Slot the handle moves in.
            px[ox + 7, y] = dark
            px[ox + 8, y] = dark
        for y in ((3, 4, 5, 6, 7, 8) if f == 0 else (8, 9, 10, 11, 12)):
            px[ox + 7, y] = steel                  # Handle shaft.
            px[ox + 8, y] = steel
        ky = 2 if f == 0 else 13                   # Red knob at the free end.
        for dx in (-1, 0, 1, 2):
            for dy in (-1, 0, 1):
                px[ox + 7 + dx, ky + dy] = knob
        px[ox + 6, 8] = px[ox + 9, 8] = (230, 230, 235, 255)   # Pivot bolt.
    return sheet


def key_sprite():
    """Small gold key, 16x16, drawn pointing up-right with a ring bow."""
    img = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    px = img.load()
    gold, light, shadow = (235, 190, 60, 255), (255, 235, 140, 255), (150, 105, 25, 255)
    for dx, dy in [(-2, -1), (-2, 0), (-2, 1), (-1, -2), (0, -2), (1, -2),   # Bow (ring).
                   (-1, 2), (0, 2), (1, 2), (2, -1), (2, 0), (2, 1)]:
        px[4 + dx + 1, 4 + dy + 1] = gold
    px[4, 3] = light
    px[5, 3] = light
    for i in range(7, 14):                         # Shaft, diagonal down-right.
        px[i - 1, i - 1] = gold
        px[i, i - 1] = shadow
    for (x, y) in [(11, 13), (12, 13), (13, 12), (13, 11)]:   # Teeth.
        px[x, y] = gold
    for (x, y) in [(10, 13), (13, 10)]:
        px[x, y] = shadow
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
    locked_door(4).save(OUT / "door_locked.png")
    plate(5).save(OUT / "plate.png")
    print("Wrote", [p.name for p in sorted(OUT.glob("*.png"))])

    sprites = OUT.parent / "sprites"
    sprites.mkdir(parents=True, exist_ok=True)
    torch_sheet().save(sprites / "torch.png")
    key_sprite().save(sprites / "key.png")
    lever_sheet().save(sprites / "lever.png")
    print("Wrote", [p.name for p in sorted(sprites.glob("*.png"))])


if __name__ == "__main__":
    main()
