"""The Bone Spider's sheet: the user's PixelLab gallery picture of a giant spider with a ribcage for a back
(tools/art/pieces/spider_picture.png, 256x256, transparent, gallery 1794988017946), animated with four `animate_image_pixminimax` clips (1 generation
each, kept at their native 256x256 in pieces/monsters_hd/spider_256/): idle (the input and 4 frames), attack, walk (the input and 8) and hurt.

What was kept, and what is made here, chosen by eye:
- idle 0-4 and walk 0-7 as they are. The picture fills its whole 256 square, so every frame is first shrunk to BASE (0.9) about the bottom centre,
  which leaves room to scale a frame UP toward the camera for the lunge.
- attack: PixelLab's clip drifts the spider sideways across frames 2 to 6 (it was animated facing south-west) and only raises its front legs and fangs at
  frame 7, so the lunge is made from clean frames instead: a crouch (frame 1 squashed), the front legs rearing (7), the strike (7 grown to the
  full canvas, `attack_hit_frame` 2), the bite held (8 at full size), settling (8 shrunk) and back to standing (0).
- hurt: the clip's hurt frames carry red splashes painted on them and barely move, so the hurt is made in code from idle_0 (two frames, as the game wants:
  a lean back and a flash). Same as the Red Shaman's.
The picture is painted (no outline), so there is no outline pass. It is dark brown, so the frames are lifted LIFT times before the palette snap; they are
halved to 128. gen_monster_sheets_hd.py (spec "spider") writes the sheet and the frame lists, fps and pixel_size into data/monsters/spider.tres.

    python tools/art/gen_spider.py        # 128 px frames
    python tools/art/gen_spider.py 256    # the native 256 px
"""
import shutil
import subprocess
import sys
from pathlib import Path

from PIL import Image

HERE = Path(__file__).resolve().parent
LIFT = 1.25
BASE = 0.9
SRC = HERE / "pieces" / "monsters_hd" / "spider_256"
OUT = HERE / "pieces" / "monsters_hd" / "spider"
# (animation, source frame, scale relative to the full canvas, squash: vertical share), in play order.
ATTACK = [(1, BASE * 0.97, 0.9), (7, BASE * 0.97, 1.0), (7, 1.0, 1.0), (8, 1.0, 1.0), (8, BASE * 1.02, 1.0), (0, BASE, 1.0)]


def _load(anim, i):
    return Image.open(SRC / f"{anim}_{i}.png").convert("RGBA")


def _fit(im, scale, squash=1.0):
    """The picture scaled by `scale` (and its height by `squash`) about its bottom centre, back on a 256 canvas."""
    w, h = im.size
    nw, nh = max(1, round(w * scale)), max(1, round(h * scale * squash))
    big = im.resize((nw, nh), Image.LANCZOS)
    a = big.getchannel("A").point(lambda v: 255 if v > 110 else 0)
    big.putalpha(a)
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    out.alpha_composite(big, ((w - nw) // 2, h - nh))
    return out


def _lifted(im):
    r, g, b, a = im.split()
    return Image.merge("RGBA", [c.point(lambda v: min(255, int(v * LIFT))) for c in (r, g, b)] + [a])


def _half(im, size):
    if size == 256:
        return im
    a = im.getchannel("A").resize((size, size), Image.LANCZOS).point(lambda v: 255 if v > 110 else 0)
    im = im.resize((size, size), Image.LANCZOS)
    im.putalpha(a)
    return im


def make_hurt():
    base = _fit(_load("idle", 0), BASE)
    out = []
    for flash in (False, True):
        tilted = base.rotate(4.0, resample=Image.BICUBIC, center=(base.width * 0.5, base.height - 2))
        moved = Image.new("RGBA", tilted.size, (0, 0, 0, 0))
        moved.alpha_composite(tilted, (0, 4))   # Knocked down onto its legs a little.
        if flash:
            r, g, b, a = moved.split()
            moved = Image.merge("RGBA", [c.point(lambda v: v + (255 - v) * 40 // 100) for c in (r, g, b)] + [a])
        out.append(moved)
    return out


def prepare(size=128):
    if OUT.exists():
        shutil.rmtree(OUT)
    OUT.mkdir(parents=True)
    frames = {"idle": [_fit(_load("idle", i), BASE) for i in range(5)],
              "walk": [_fit(_load("walk", i), BASE) for i in range(8)],
              "attack": [_fit(_load("attack", i), s, q) for i, s, q in ATTACK],
              "hurt": make_hurt()}
    for anim, ims in frames.items():
        for n, im in enumerate(ims):
            _half(_lifted(im), size).save(OUT / f"{anim}_{n}.png")


if __name__ == "__main__":
    size = int(sys.argv[1]) if len(sys.argv) > 1 else 128
    prepare(size)
    subprocess.run([sys.executable, str(HERE / "gen_monster_sheets_hd.py"), "spider"], check=True)
