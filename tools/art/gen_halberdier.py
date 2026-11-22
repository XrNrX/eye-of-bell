"""The Goblin Halberdier's sheet: the user's PixelLab gallery picture of an armoured goblin with a halberd ("horrid wee goblin warrior",
tools/art/pieces/halberdier_picture.png, 256x256, transparent, gallery 1795276574656), animated with four `animate_image_pixminimax` clips (1 generation
each, kept at their native 256x256 in pieces/monsters_hd/halberdier_256/): idle (the input and 4 frames), attack (the input and 8: he draws the halberd
across his body and stabs it out), walk (the input and 8), hurt (the input and 4: head thrown back, mouth open).

Frames kept (source index -> sheet frame), chosen by eye: idle 0-4; attack 1-6 and then 0 (the halberd comes across and rises, then is thrust out in front
of him: `attack_hit_frame` 4 names the first thrust frame, source frame 5; source 7 and 8 repeat 6 and are dropped); walk 0-7; hurt 1-4. The picture is
painted (no outline), so there is no outline pass. The frames are lifted LIFT times before the palette snap and halved to 128. gen_monster_sheets_hd.py
(spec "halberdier") writes the sheet and the frame lists, fps and pixel_size into data/monsters/halberdier.tres.

    python tools/art/gen_halberdier.py        # 128 px frames
    python tools/art/gen_halberdier.py 256    # the native 256 px
"""
import shutil
import subprocess
import sys
from pathlib import Path

from PIL import Image

HERE = Path(__file__).resolve().parent
LIFT = 1.2
SRC = HERE / "pieces" / "monsters_hd" / "halberdier_256"
OUT = HERE / "pieces" / "monsters_hd" / "halberdier"
KEEP = {"idle": [0, 1, 2, 3, 4], "attack": [1, 2, 3, 4, 5, 6, 0], "walk": [0, 1, 2, 3, 4, 5, 6, 7], "hurt": [1, 2, 3, 4]}


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
    subprocess.run([sys.executable, str(HERE / "gen_monster_sheets_hd.py"), "halberdier"], check=True)
