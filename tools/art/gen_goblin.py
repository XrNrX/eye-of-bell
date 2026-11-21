"""The Goblin's sheet: the user's PixelLab gallery picture of a puny green goblin with a spear
(tools/art/pieces/goblin_picture.png, 256x256, transparent, gallery 1795296411171), animated with four `animate_image_pixminimax` clips
(1 generation each, kept at their native 256x256 in pieces/monsters_hd/goblin_256/): idle (the input and 4 frames), attack (the input and 8:
he draws the spear back and jabs it out), walk (the input and 8), hurt (the input and 4: he is jerked back with his head thrown up).

Frames kept (source index -> sheet frame), chosen by eye: idle 0-4; attack 1, 2, 4, 5, 6, 7, 8 (frame 3 has a white slash artifact painted
across it, dropped; the spear is at full stretch on the 4th kept frame, the one `attack_hit_frame` names); walk 0-7 (the 9th is the input
again); hurt 2, 3, 4 (frame 1 has a red splash painted on it, dropped; three frames play in order, no flash). The picture is painted (no
outline), so there is no outline pass. Frames are halved to 128 with a small brightness lift before the palette snap, and
gen_monster_sheets_hd.py (spec "goblin") writes the sheet and the frame lists, fps and pixel_size into data/monsters/goblin.tres.

    python tools/art/gen_goblin.py        # 128 px frames
    python tools/art/gen_goblin.py 256    # the native 256 px
"""
import shutil
import subprocess
import sys
from pathlib import Path

from PIL import Image

HERE = Path(__file__).resolve().parent
LIFT = 1.12
SRC = HERE / "pieces" / "monsters_hd" / "goblin_256"
OUT = HERE / "pieces" / "monsters_hd" / "goblin"
KEEP = {"idle": [0, 1, 2, 3, 4], "attack": [1, 2, 4, 5, 6, 7, 8], "walk": [0, 1, 2, 3, 4, 5, 6, 7], "hurt": [2, 3, 4]}


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
    subprocess.run([sys.executable, str(HERE / "gen_monster_sheets_hd.py"), "goblin"], check=True)
