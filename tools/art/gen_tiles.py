"""Dungeon tiles (64x64, all seamless): wall, floor, ceiling, door, locked door,
pressure plate and stairs. Written to res://art/tiles/ using only palette colours.

Most of them follow one recipe:
    height map -> top-left lighting -> add tint / grain / cracks -> dither onto a palette ramp
"""
import math

from PIL import Image

from artio import save_png
from dither import dither_ramp
from lighting import lit_values
from noise import hash01, remap, value_noise, white_noise
from palette import PAL

SIZE = 64
STONE = PAL.ramp("stone")  # stone_900 ... stone_100, dark to light
MOSS = PAL.ramp("moss")
WOOD = PAL.ramp("wood")


def clamp01(v):
    return min(1.0, max(0.0, v))


def grid(fn):
    return [[fn(x, y) for x in range(SIZE)] for y in range(SIZE)]


def to_image(rows):
    """Dict {(x, y): rgb} or an RGBA image -> RGBA image."""
    if isinstance(rows, Image.Image):
        return rows
    img = Image.new("RGBA", (SIZE, SIZE))
    px = img.load()
    for (x, y), c in rows.items():
        px[x, y] = (*c, 255)
    return img


# --------------------------------------------------------------------------
# Stone blocks: bricks, flagstones and plain slabs
# --------------------------------------------------------------------------

def block_layout(bw, bh, offset_rows):
    """For every pixel: which block it is in, and its position inside that block.
    Offset rows (bricks) shift every second row by half a block. Tiles seamlessly."""
    cells = {}
    for y in range(SIZE):
        row = y // bh
        shift = bw // 2 if offset_rows and row % 2 else 0
        for x in range(SIZE):
            sx = x + shift
            cells[(x, y)] = ((row, (sx % SIZE) // bw), sx % bw, y % bh)
    return cells


def cracks(seed, count, length, drop):
    """Random wandering crack lines as a {(x, y): brightness drop} map (wraps at the edges)."""
    out = {}
    for i in range(count):
        x = int(hash01(seed, i, 1) * SIZE)
        y = int(hash01(seed, i, 2) * SIZE)
        dx, dy = (1, 0) if hash01(seed, i, 3) < 0.5 else (0, 1)
        for step in range(length):
            out[(x % SIZE, y % SIZE)] = drop
            r = hash01(seed, i * 100 + step, 4)
            if r < 0.3:
                dx, dy = dy, dx  # Turn.
            x += dx
            y += dy
    return out


def stone_blocks(bw, bh, offset_rows, seed, ramp, base, tint=0.12, grain=0.2,
                 crack_lines=0, moss_amount=0.0):
    """A block pattern lit from the top-left and dithered onto `ramp`.
    base is the average brightness (0..1); moss_amount (0..~0.3) sprinkles moss."""
    layout = block_layout(bw, bh, offset_rows)
    heights = grid(lambda x, y: 0.0 if layout[(x, y)][1] == 0 or layout[(x, y)][2] == 0 else 1.0)
    lit = lit_values(heights, strength=0.3, base=0.0)
    bump = value_noise(SIZE, SIZE, 8, seed + 1, octaves=2)
    fine = white_noise(SIZE, SIZE, seed + 2)
    tints = {}
    crack = cracks(seed + 3, crack_lines, 14, 0.3) if crack_lines else {}

    def value(x, y):
        key, lx, ly = layout[(x, y)]
        mortar = lx == 0 or ly == 0
        t = tints.setdefault(key, (hash01(seed, key[0], key[1]) - 0.5) * 2 * tint)
        v = base + t + (bump[y][x] - 0.5) * 0.16 + (fine[y][x] - 0.5) * grain
        v += lit[y][x] - (0.3 if mortar else 0.0) - crack.get((x, y), 0.0)
        return clamp01(v)

    values = grid(value)
    img = dither_ramp(values, ramp, "bayer", seed)
    if moss_amount > 0:  # Same lighting, moss colours, only where a noise field is high.
        patches = value_noise(SIZE, SIZE, 16, seed + 7, octaves=3, persistence=0.6)
        moss = dither_ramp(values, MOSS, "bayer", seed)
        mp, ip = moss.load(), img.load()
        for y in range(SIZE):
            for x in range(SIZE):
                if patches[y][x] > 1.0 - moss_amount and layout[(x, y)][2] > 0:
                    ip[x, y] = mp[x, y]
    return img


def wall():
    return stone_blocks(16, 8, True, 1, STONE[:5], base=0.5, tint=0.14, grain=0.08, moss_amount=0.28)


def floor():
    return stone_blocks(32, 32, False, 2, STONE[:5], base=0.42, tint=0.12, grain=0.1,
                        crack_lines=3, moss_amount=0.1)


def ceiling():
    """Dark mottled rock: coarse blotches plus fine grain, no mortar."""
    blotch = remap(value_noise(SIZE, SIZE, 16, 3, octaves=3))
    fine = white_noise(SIZE, SIZE, 4)
    values = grid(lambda x, y: clamp01(0.15 + blotch[y][x] * 0.45 + (fine[y][x] - 0.5) * 0.1))
    return dither_ramp(values, STONE[:4], "bayer", 3)


# --------------------------------------------------------------------------
# Doors
# --------------------------------------------------------------------------

def door(seed=4):
    """Vertical planks with a lit left edge and shaded right edge, two iron bands with
    rivets, and a ring handle."""
    tints = [(hash01(seed, i, 0) - 0.5) * 0.18 for i in range(SIZE // 16)]

    def value(x, y):
        lx = x % 16
        if lx == 0:
            return 0.0  # Gap between planks.
        v = 0.5 + tints[x // 16] + (hash01(seed, x, y // 6) - 0.5) * 0.16
        v += (hash01(seed + 1, x, y) - 0.5) * 0.03
        if lx == 1:
            v += 0.14
        elif lx == 15:
            v -= 0.14
        return clamp01(v)

    img = dither_ramp(grid(value), WOOD, "bayer", seed)
    px = img.load()
    iron_light, iron, iron_dark = PAL["stone_300"], PAL["stone_500"], PAL["stone_700"]
    for band in (8, 48):
        for y in range(band, band + 6):
            for x in range(SIZE):
                if y == band:
                    c = iron_light
                elif y == band + 5:
                    c = iron_dark
                else:
                    c = iron_dark if hash01(seed + 2, x, y) < 0.15 else iron
                px[x, y] = (*c, 255)
        for x in range(4, SIZE, 16):
            px[x, band + 2] = (*PAL["stone_100"], 255)  # Rivet.
    for dx, dy in [(-3, 0), (-2, -2), (0, -3), (2, -2), (3, 0), (2, 2), (0, 3), (-2, 2)]:
        px[50 + dx, 30 + dy] = (*iron_light, 255)  # Handle ring.
    px[50, 30] = (*PAL["ink"], 255)
    return img


def locked_door():
    """The plain door with a big brass padlock and keyhole."""
    img = door()
    px = img.load()
    for x in range(26, 38):  # Shackle.
        for y in range(18, 30):
            if x in (26, 27, 36, 37) or (y in (18, 19) and 28 <= x <= 35):
                px[x, y] = (*PAL["stone_300"], 255)
    for y in range(28, 46):  # Lock body.
        for x in range(22, 42):
            if x in (22, 41) or y in (28, 45):
                c = PAL["torch_700"]
            elif y < 33:
                c = PAL["torch_300"]
            else:
                c = PAL["torch_500"]
            px[x, y] = (*c, 255)
    ink = (*PAL["ink"], 255)
    for y in range(34, 43):  # Keyhole: a 2px stem with a wider round top.
        for x in (31, 32):
            px[x, y] = ink
    for x in (30, 33):
        px[x, 36] = ink
    return img


# --------------------------------------------------------------------------
# Pressure plate and stairs
# --------------------------------------------------------------------------

def plate():
    """A bevelled slab with a carved ring and a gold diamond."""
    img = stone_blocks(SIZE, SIZE, False, 5, STONE[:5], base=0.55, tint=0.0, grain=0.06)
    px = img.load()
    c = SIZE // 2
    for y in range(SIZE):
        for x in range(SIZE):
            d = math.hypot(x - c, y - c)
            if 17 <= d < 19:
                px[x, y] = (*PAL["stone_800"], 255)
            m = abs(x - c) + abs(y - c)
            if m <= 5:
                px[x, y] = (*PAL["torch_500"], 255)
            elif m <= 8:
                px[x, y] = (*PAL["torch_700"], 255)
    return img


def stairs():
    """Steps going down, seen from above: each band darker than the one above, with a
    lit front edge, between two lighter side rails. The dithering makes the gradient."""
    def value(x, y):
        grain = (hash01(6, x, y) - 0.5) * 0.08
        if x < 6 or x >= SIZE - 6:  # Rails stay level and light.
            return clamp01(0.62 + grain + (0.1 if x in (0, SIZE - 6) else 0.0))
        step, edge = y // 8, y % 8
        v = 0.78 - 0.085 * step + grain
        if edge == 0:
            v += 0.16
        elif edge == 7:
            v -= 0.16
        return clamp01(v)

    return dither_ramp(grid(value), STONE[:5], "bayer", 6)


def build():
    written = []
    for name, make in (("wall", wall), ("floor", floor), ("ceiling", ceiling), ("door", door),
                       ("door_locked", locked_door), ("plate", plate), ("stairs", stairs)):
        written.append(save_png(to_image(make()), f"tiles/{name}.png"))
    return written
