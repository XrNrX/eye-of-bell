"""The webbing laid over the 3D view while the party is stuck in a spider's web (art/ui/web_net.png, drawn by scripts/web_overlay.gd).

Source: pieces/spells/web/web_net_b.png, a 208x128 PixelLab picture (create_image_pixflux, seed 82, 1 generation) of an orb web on a transparent
background. The palette has no white, so it is snapped to dull pale greys (a first version in `bone_300` glared across the whole view): the brightest strands `bone_500`, the rest `stone_300` and `stone_500`.
It is shown at 2x over the dungeon view (a 416x256 block, 208x128 art pixels).
"""
from pathlib import Path

from PIL import Image

from artio import save_png
from palette import PAL

SRC = Path(__file__).resolve().parent / "pieces" / "spells" / "web" / "web_net_b.png"


def build(scale=None):
    img = Image.open(SRC).convert("RGBA")
    px = img.load()
    for y in range(img.height):
        for x in range(img.width):
            r, g, b, a = px[x, y]
            if a < 128:
                px[x, y] = (0, 0, 0, 0)
                continue
            luma = 0.299 * r + 0.587 * g + 0.114 * b
            name = "bone_500" if luma > 200 else ("stone_300" if luma > 140 else "stone_500")
            px[x, y] = (*PAL[name], 255)
    return [save_png(img, "ui/web_net.png")]


if __name__ == "__main__":
    for p in build():
        print(p)
