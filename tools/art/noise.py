"""Seeded noise. Same seed, same result, every run. Grids are lists indexed [y][x]
with values from 0.0 to 1.0.

    n = value_noise(64, 64, scale=16, seed=3, octaves=3)   # smooth, tiles seamlessly
    w = white_noise(64, 64, seed=3)                        # per-pixel grain
"""


def hash01(seed, a, b):
    """Deterministic pseudo-random 0..1 from a seed and two integers."""
    h = (seed * 2654435761 + a * 73856093 + b * 19349663) & 0xFFFFFFFF
    h ^= h >> 13
    h = (h * 0x5BD1E995) & 0xFFFFFFFF
    h ^= h >> 15
    return (h % 100000) / 100000.0


def _smooth(t):
    return t * t * (3 - 2 * t)


def white_noise(w, h, seed=0):
    return [[hash01(seed, x, y) for x in range(w)] for y in range(h)]


def value_noise(w, h, scale=16, seed=0, octaves=1, persistence=0.5, tileable=True):
    """Smooth value noise. `scale` is the feature size in pixels of the first octave.
    With tileable=True the lattice wraps, so the grid repeats seamlessly when the
    size is a multiple of the scale (64 with scale 8, 16, 32...)."""
    out = [[0.0] * w for _ in range(h)]
    total = 0.0
    amp = 1.0
    cells_x = max(1, round(w / scale))
    cells_y = max(1, round(h / scale))
    for o in range(octaves):
        cx, cy = cells_x * 2 ** o, cells_y * 2 ** o
        s = seed + o * 1013

        def lattice(ix, iy):
            if tileable:
                return hash01(s, ix % cx, iy % cy)
            return hash01(s, ix, iy)

        for y in range(h):
            fy = y * cy / h
            iy = int(fy)
            ty = _smooth(fy - iy)
            for x in range(w):
                fx = x * cx / w
                ix = int(fx)
                tx = _smooth(fx - ix)
                top = lattice(ix, iy) * (1 - tx) + lattice(ix + 1, iy) * tx
                bot = lattice(ix, iy + 1) * (1 - tx) + lattice(ix + 1, iy + 1) * tx
                out[y][x] += (top * (1 - ty) + bot * ty) * amp
        total += amp
        amp *= persistence
    return [[v / total for v in row] for row in out]


def remap(grid, lo=0.0, hi=1.0):
    """Stretch a grid so its min..max becomes lo..hi (gives noise full contrast)."""
    flat = [v for row in grid for v in row]
    a, b = min(flat), max(flat)
    span = (b - a) or 1.0
    return [[lo + (v - a) / span * (hi - lo) for v in row] for row in grid]
