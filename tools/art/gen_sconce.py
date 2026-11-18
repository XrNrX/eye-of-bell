"""The wall sconce's two dark states, from PixelLab pieces (docs/design/expansion_design.md 7l.2). A lit sconce is still the animated
torch (gen_sprites.py); these are what hangs on the wall when it is not burning:

    art/sprites/sconce_empty.png   a bare iron bracket (pieces/sconce/empty_raw.png, create_image_pixen, seed 7111)
    art/sprites/sconce_unlit.png   a bracket holding an unlit torch (pieces/sconce/unlit_b.png, seed 7112)

Both are 32x64, drawn in the scene at 0.015 world units per art pixel (the lit torch is 16x32 at 0.03: the same size on the wall).
PixelLab drew the unlit one with a flame however it was asked, so the flame (rows 0 to 18 above the rag head) is cut away here; the
game draws its own flame when the sconce is lit. Colours are snapped to the palette. Run: python tools/art/gen_sconce.py
"""
from pathlib import Path

from PIL import Image

from artio import save_png
from palette import PAL

PIECES = Path(__file__).parent / "pieces" / "sconce"
FLAME_ROWS = 19  # Rows of unlit_b.png that hold the flame; the rag head's outline starts on row 19.


def build():
    written = []
    empty = Image.open(PIECES / "empty_raw.png").convert("RGBA")
    unlit = Image.open(PIECES / "unlit_b.png").convert("RGBA")
    for y in range(FLAME_ROWS):
        for x in range(unlit.width):
            unlit.putpixel((x, y), (0, 0, 0, 0))
    written.append(save_png(PAL.snap(empty), "sprites/sconce_empty.png"))
    written.append(save_png(PAL.snap(unlit), "sprites/sconce_unlit.png"))
    return written


if __name__ == "__main__":
    for p in build():
        print("wrote", p)
