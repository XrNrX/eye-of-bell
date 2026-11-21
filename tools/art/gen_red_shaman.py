"""The Red Shaman's sheet: the user's PixelLab gallery picture of a goblin shaman in a red hood with a skull staff
(tools/art/pieces/red_shaman_picture.png, 256x256, transparent), animated with four `animate_image_pixminimax` clips (1 generation each,
kept at their native 256x256 in pieces/monsters_hd/red_shaman_256/): idle (the input and 4 frames), attack (the input and 8: he raises the
staff and thrusts it forward with his mouth open and sparks flying: the cast), walk (the input and 8; the last frame is the input again,
so it is dropped to make a loop).

Used here: idle 0-4, attack 2-8 (the first two frames are the input and a barely moving wind-up; the cast is attack_3 of the seven kept, the
frame `attack_hit_frame` names), walk 0-7. **The hurt is made in code** from idle_0, as the Warden's was (PixelLab's hurt clip barely moved
him): two frames, as the game wants ([hurt, flash]): a lean back with a small jolt, then the same flashed pale.

The picture is painted (no outline), so there is no outline pass. Frames are halved to 128 with a small brightness lift before the palette
snap, and gen_monster_sheets_hd.py (spec "red_shaman") writes the sheet and the frame lists, fps and pixel_size into data/monsters/red_shaman.tres.

    python tools/art/gen_red_shaman.py        # 128 px frames
    python tools/art/gen_red_shaman.py 256    # the native 256 px
"""
import shutil
import subprocess
import sys
from pathlib import Path

from PIL import Image

HERE = Path(__file__).resolve().parent
LIFT = 1.12
SRC = HERE / "pieces" / "monsters_hd" / "red_shaman_256"
OUT = HERE / "pieces" / "monsters_hd" / "red_shaman"
KEEP = {"idle": range(0, 5), "attack": range(2, 9), "walk": range(0, 8)}


def _frame(im, size):
    if size != 256:
        a = im.getchannel("A").resize((size, size), Image.LANCZOS).point(lambda v: 255 if v > 110 else 0)
        im = im.resize((size, size), Image.LANCZOS)
        im.putalpha(a)
    return im


def _lifted(im):
    r, g, b, a = im.split()
    return Image.merge("RGBA", [c.point(lambda v: min(255, int(v * LIFT))) for c in (r, g, b)] + [a])


def make_hurt(size):
    base = Image.open(SRC / "idle_0.png").convert("RGBA")
    out = []
    for flash in (False, True):
        big = base.rotate(5.0, resample=Image.BICUBIC, center=(base.width * 0.5, base.height - 2))
        shifted = Image.new("RGBA", big.size, (0, 0, 0, 0))
        shifted.alpha_composite(big, (0, -5))
        if flash:
            r, g, b, a = shifted.split()
            shifted = Image.merge("RGBA", [c.point(lambda v: v + (255 - v) * 45 // 100) for c in (r, g, b)] + [a])
        out.append(_frame(_lifted(shifted), size))
    return out


def prepare(size=128):
    if OUT.exists():
        shutil.rmtree(OUT)
    OUT.mkdir(parents=True)
    for anim, indexes in KEEP.items():
        for n, i in enumerate(indexes):
            _frame(_lifted(Image.open(SRC / f"{anim}_{i}.png").convert("RGBA")), size).save(OUT / f"{anim}_{n}.png")
    for i, frame in enumerate(make_hurt(size)):
        frame.save(OUT / f"hurt_{i}.png")


if __name__ == "__main__":
    size = int(sys.argv[1]) if len(sys.argv) > 1 else 128
    prepare(size)
    subprocess.run([sys.executable, str(HERE / "gen_monster_sheets_hd.py"), "red_shaman"], check=True)
