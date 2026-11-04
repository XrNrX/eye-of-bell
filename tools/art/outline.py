"""1px outlines around sprites.

    sprite = add_outline(sprite, PAL["ink"], pad=1)
"""
from PIL import Image


def add_outline(img, color, diagonals=False, pad=0):
    """Return a copy of an RGBA image with a 1px outline drawn on the transparent
    pixels that touch the artwork (up/down/left/right; also diagonals if asked).
    `pad` grows the canvas on every side first, so outlines at the edge aren't cut off."""
    src = img.convert("RGBA")
    out = Image.new("RGBA", (src.width + 2 * pad, src.height + 2 * pad), (0, 0, 0, 0))
    out.paste(src, (pad, pad))
    px = out.load()
    w, h = out.size
    steps = [(-1, 0), (1, 0), (0, -1), (0, 1)]
    if diagonals:
        steps += [(-1, -1), (1, -1), (-1, 1), (1, 1)]
    edge = []
    for y in range(h):
        for x in range(w):
            if px[x, y][3]:
                continue
            for dx, dy in steps:
                nx, ny = x + dx, y + dy
                if 0 <= nx < w and 0 <= ny < h and px[nx, ny][3]:
                    edge.append((x, y))
                    break
    for x, y in edge:  # Collected first so new outline pixels don't spawn more outline.
        px[x, y] = (*color[:3], 255)
    return out
