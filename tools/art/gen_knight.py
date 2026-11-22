"""The Horned Knight's sheet: the user's PixelLab gallery picture of a heavy black-armoured knight with a horned helm and a greatsword
(tools/art/pieces/knight_picture.png, 256x256, transparent, gallery 1795294603931), animated with four `animate_image_pixminimax` clips
(1 generation each, kept at their native 256x256 in pieces/monsters_hd/knight_256/): idle (the input and 4 frames), attack (the input and 8: he
heaves the greatsword overhead and brings it down, ending with it planted point down), walk (the input and 8), hurt (the input and 4).

Frames kept (source index -> sheet frame), chosen by eye: idle 0-4; attack 1, 2, 3, 4 (the sword going up and held overhead), then 7, 8 (the blow
has landed and the sword stands planted; the frames between, 5 and 6, have white slash crescents painted on them and are dropped, so the chop is one
hard cut from the raised sword to the planted one, which is the impact the game wants: `attack_hit_frame` 4 names the first planted frame) and
0 (back to standing); walk 0-7 (the 9th is the input again); hurt 1-4. The picture is painted (no outline), so there is no outline pass. It is very
dark, so the frames are lifted LIFT times before the palette snap; they are halved to 128. gen_monster_sheets_hd.py (spec "knight") writes the sheet and
the frame lists, fps and pixel_size into data/monsters/knight.tres.

    python tools/art/gen_knight.py        # 128 px frames
    python tools/art/gen_knight.py 256    # the native 256 px
"""
import shutil
import subprocess
import sys
from pathlib import Path

from PIL import Image

HERE = Path(__file__).resolve().parent
LIFT = 1.3
SRC = HERE / "pieces" / "monsters_hd" / "knight_256"
OUT = HERE / "pieces" / "monsters_hd" / "knight"
KEEP = {"idle": [0, 1, 2, 3, 4], "attack": [1, 2, 3, 4, 7, 8, 0], "walk": [0, 1, 2, 3, 4, 5, 6, 7], "hurt": [1, 2, 3, 4]}


def _frame(im, size):
    if size != 256:
        a = im.getchannel("A").resize((size, size), Image.LANCZOS).point(lambda v: 255 if v > 110 else 0)
        im = im.resize((size, size), Image.LANCZOS)
        im.putalpha(a)
    return im


def _lifted(im):
    r, g, b, a = im.split()
    return Image.merge("RGBA", [c.point(lambda v: min(255, int(v * LIFT))) for c in (r, g, b)] + [a])


def prepare(size=128):
    if OUT.exists():
        shutil.rmtree(OUT)
    OUT.mkdir(parents=True)
    for anim, indexes in KEEP.items():
        for n, i in enumerate(indexes):
            _frame(_lifted(Image.open(SRC / f"{anim}_{i}.png").convert("RGBA")), size).save(OUT / f"{anim}_{n}.png")


if __name__ == "__main__":
    size = int(sys.argv[1]) if len(sys.argv) > 1 else 128
    prepare(size)
    subprocess.run([sys.executable, str(HERE / "gen_monster_sheets_hd.py"), "knight"], check=True)
