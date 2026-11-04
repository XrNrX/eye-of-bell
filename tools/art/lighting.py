"""Simple top-left lighting. Light comes from the top-left, so surfaces facing
up/left are bright and surfaces facing down/right are dark.

For textures (a height map in, a brightness grid out, then dither it):
    values = lit_values(heights, strength=4.0)
    img = dither_ramp(values, PAL.ramp("stone"))

For sprites (a set of pixels in, colours out):
    pixels = shade_mask(mask, PAL.ramp("bone"))     # {(x, y): rgb}
"""


def lit_values(heights, strength=3.0, base=0.5, wrap=True):
    """Brightness 0..1 per pixel from a height map [y][x] (0..1). A pixel is bright
    when its slope faces the top-left light, meaning the ground rises towards the
    bottom-right of it (the top-left side of a bump), and dark on the opposite side.
    wrap=True treats the grid as tiling, so lit textures stay seamless."""
    h, w = len(heights), len(heights[0])

    def at(x, y):
        if wrap:
            return heights[y % h][x % w]
        return heights[min(h - 1, max(0, y))][min(w - 1, max(0, x))]

    out = [[0.0] * w for _ in range(h)]
    for y in range(h):
        for x in range(w):
            slope = at(x + 1, y + 1) - at(x - 1, y - 1)
            out[y][x] = min(1.0, max(0.0, base + slope * strength))
    return out


def shade_mask(mask, ramp):
    """Colour a pixel mask with a [dark, mid, light] ramp (extra middle colours are
    ignored): light on top/left edges, dark on bottom/right edges, a soft diagonal
    gradient across the inside of bigger shapes."""
    dark, light = ramp[0], ramp[-1]
    mid = ramp[len(ramp) // 2]
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
