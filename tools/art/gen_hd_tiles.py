"""The 256x256 door, locked door, cracked wall and corrupted wall textures (hires-720 branch) from PixelLab pieces in tools/art/pieces/tiles256/.

Each piece is the old 128 texture doubled and redrawn by PixelLab (img2img, init strength 140-150: it keeps the layout, so the cracked wall
keeps its 3x2 grid of cells), snapped to the palette. The floor and ceiling are made by gen_hd_floor_ceiling.py.

    python tools/art/gen_hd_tiles.py
"""
import os
from pathlib import Path

from artio import save_png
from palette import PAL
from PIL import Image

PIECES = Path(__file__).parent / "pieces" / "tiles256"
NAMES = ["door", "door_locked", "wall_cracked", "wall_corrupted"]


def build():
    os.environ["ART_OVERWRITE_IMPORTED"] = "1"  # These files are listed as imported art; this replaces them on purpose.
    written = []
    for n in NAMES:
        written.append(save_png(PAL.snap(Image.open(PIECES / f"{n}.png").convert("RGBA")), f"tiles/{n}.png"))
    return written


if __name__ == "__main__":
    for p in build():
        print(p)
