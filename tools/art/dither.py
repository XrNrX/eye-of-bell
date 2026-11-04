"""Dithering: turn a smooth 0..1 grid into pixels of only palette colours.

    img = dither_two(values, PAL["stone_700"], PAL["stone_500"])           # two colours
    img = dither_ramp(values, PAL.ramp("stone"), mode="bayer")             # a whole ramp

Modes: "bayer" (ordered 4x4, the classic pixel-art pattern), "checker" (hard
bands with a checkerboard between them), "random" (seeded noise, grainy).
"""
import math

from PIL import Image

from noise import hash01

BAYER4 = [
    [0, 8, 2, 10],
    [12, 4, 14, 6],
    [3, 11, 1, 9],
    [15, 7, 13, 5],
]


def _threshold(mode, x, y, frac, seed):
    """Return True if this pixel should take the lighter of the two colours."""
    if mode == "bayer":
        return frac > (BAYER4[y % 4][x % 4] + 0.5) / 16.0
    if mode == "checker":
        if frac < 0.25:
            return False
        if frac > 0.75:
            return True
        return (x + y) % 2 == 0
    if mode == "random":
        return frac > hash01(seed, x, y)
    raise ValueError(f"unknown dither mode {mode!r}")


def dither_ramp(values, colors, mode="bayer", seed=0):
    """values: grid [y][x] of 0..1. colors: two or more RGB tuples, dark to light.
    Each pixel lands between two neighbouring ramp colours and is dithered between them."""
    h, w = len(values), len(values[0])
    n = len(colors)
    img = Image.new("RGBA", (w, h))
    px = img.load()
    for y in range(h):
        for x in range(w):
            v = min(1.0, max(0.0, values[y][x])) * (n - 1)
            i = min(n - 2, int(math.floor(v)))
            frac = v - i
            c = colors[i + 1] if _threshold(mode, x, y, frac, seed) else colors[i]
            px[x, y] = (*c, 255)
    return img


def dither_two(values, dark, light, mode="bayer", seed=0):
    return dither_ramp(values, [dark, light], mode, seed)
