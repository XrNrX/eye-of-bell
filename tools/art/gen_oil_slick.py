"""The oil slick: art/decals/oil_slick.png (128x128), laid flat on the floor tile where a flask of oil was thrown (scripts/oil_field.gd).
Source: tools/art/pieces/decals/oil_slick_raw.png (create_image_pixflux, 128x128, seed 8103: a flat black puddle). It came out as a flat black
blob, which vanishes on the dark floor, so this adds what a puddle of oil has: a thin brown rim at the edge, a few glints of the lamp's amber and
pale gloss arcs, all on palette colours. Run: python tools/art/gen_oil_slick.py"""
from pathlib import Path

from PIL import Image

from artio import save_png
from noise import hash01
from palette import PAL

RAW = Path(__file__).parent / "pieces" / "decals" / "oil_slick_raw.png"


def build():
    img = PAL.snap(Image.open(RAW).convert("RGBA"))
    px = img.load()
    w, h = img.size
    rim = PAL["wood_500"]
    inside = [(x, y) for y in range(h) for x in range(w) if px[x, y][3]]
    edge = set()
    for x, y in inside:
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, ny = x + dx, y + dy
            if not (0 <= nx < w and 0 <= ny < h) or px[nx, ny][3] == 0:
                edge.add((x, y))
    for x, y in edge:  # A rim a little lighter than the black, dithered so it is not a hard line.
        if (x + y) % 2 == 0:
            px[x, y] = (*rim, 255)
    cx = sum(x for x, _ in inside) / len(inside)
    cy = sum(y for _, y in inside) / len(inside)
    for x, y in inside:  # Gloss: a short bright arc up and to the left of the middle, and scattered amber glints.
        dx, dy = x - cx, y - cy
        d = (dx * dx + dy * dy) ** 0.5
        if 14 < d < 17 and dx < 0 and dy < 0 and (x + y) % 3 != 0:
            px[x, y] = (*PAL["stone_300"], 255)
        elif hash01(41, x // 2, y // 2) > 0.985 and (x, y) not in edge:
            px[x, y] = (*PAL["rust_300"], 255)
    return [save_png(img, "decals/oil_slick.png")]


if __name__ == "__main__":
    for p in build():
        print("wrote", p)
