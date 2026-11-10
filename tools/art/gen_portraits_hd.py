"""The 128x128 party portraits (hires-720 branch) from PixelLab pieces in tools/art/pieces/portraits_hd/<hero>.png.

Each piece is the old 64x64 portrait doubled and redrawn by PixelLab (img2img, init strength 130: same face and pose, far finer drawing).
PixelLab flattens the old transparent background onto a flat grey, so every pixel of exactly that colour (the corner pixel's) becomes
transparent again. The picture is snapped to the palette and saved as portrait.png; the hurt and dead pictures are derived from it as
before (gen_portraits.hurt_variant / cursed_dead_variant), now at 128. party_hud scales a portrait to its 64x64 box
(`ignore_texture_size`), so no code depends on the size.

    python tools/art/gen_portraits_hd.py
"""
import os
from pathlib import Path

import numpy as np
from PIL import Image

from artio import save_png
from gen_portraits import cursed_dead_variant, hurt_variant
from palette import PAL

PIECES = Path(__file__).parent / "pieces" / "portraits_hd"
HEROES = ["fighter", "cleric", "thief", "mage"]


def keyed(path):
    img = Image.open(path).convert("RGBA")
    a = np.asarray(img).copy()
    bg = a[0, 0, :3].copy()
    same = (a[..., :3] == bg).all(axis=2)
    a[same, 3] = 0
    return Image.fromarray(a, "RGBA")


def build():
    os.environ["ART_OVERWRITE_IMPORTED"] = "1"  # The portraits are listed as imported art; this replaces them on purpose.
    written = []
    for h in HEROES:
        living = PAL.snap(keyed(PIECES / f"{h}.png"))
        written.append(save_png(living, f"portraits/{h}/portrait.png"))
        written.append(save_png(hurt_variant(living), f"portraits/{h}/portrait_hurt.png"))
        written.append(save_png(cursed_dead_variant(living), f"portraits/{h}/portrait_dead.png"))
    return written


if __name__ == "__main__":
    for p in build():
        print(p)
