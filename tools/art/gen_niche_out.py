"""The wall niche with its candle put out (curse zones, docs/design/expansion_design.md section 3): art/decals/niche_out.png is art/decals/niche.png
with the candle's flame taken away (a dark wick left), shown instead of the niche while a curse zone is near (scripts/curse_zones.gd). Its normal map
art/normals/decals/niche_out_n.png is the niche's own (the shape is the same, minus the flame). Run it after gen_wall_decor.py regenerates niche.png:

    python tools/art/gen_niche_out.py

No PixelLab: it is a few pixels cut out of a PixelLab picture.
"""
import shutil

from PIL import Image

from artio import save_png
from palette import ART_DIR, PAL

FLAME_ROWS = 96  # Rows above the candle's wax (it starts on row 96 of the 128 px picture); everything warm above it is flame.


def build():
    img = Image.open(ART_DIR / "decals" / "niche.png").convert("RGBA")
    px = img.load()
    flame = {PAL["torch_300"], PAL["torch_500"]}
    for y in range(FLAME_ROWS):
        for x in range(img.width):
            r, g, b, a = px[x, y]
            if a and (r, g, b) in flame:
                px[x, y] = (0, 0, 0, 0)
    for y in (94, 95):  # A dark wick, as wide as the flame's root.
        for x in (42, 43):
            px[x, y] = (*PAL["ink"], 255)
    written = [save_png(img, "decals/niche_out.png")]
    src = ART_DIR / "normals" / "decals" / "niche_n.png"
    dst = ART_DIR / "normals" / "decals" / "niche_out_n.png"
    if src.exists():
        shutil.copyfile(src, dst)
        written.append(dst)
    return written


if __name__ == "__main__":
    for p in build():
        print("wrote", p)
