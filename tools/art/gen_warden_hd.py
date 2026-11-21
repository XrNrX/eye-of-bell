"""The Cursed Warden's sheet: the user's PixelLab picture of the "hardcore warden" (tools/art/pieces/warden_hd_picture.png, a horned
warden in spiked red and black plate armour with a tall axe and chains, 256x256 with a transparent background, made in the PixelLab
gallery), animated with `animate_image_pixminimax` clips (1 generation each), kept at their native 256x256 in
pieces/monsters_hd/warden_256/: idle (the input and 4), attack (the input and 8, the held crouch at the end cut to the first 6 frames),
walk (the input and 8; the last frame is the input again, so it is dropped to make a loop).

**The hurt is made here, in code**, from idle_0: PixelLab's animator would not recoil him (three clips: two almost static, one that lost his
helmet; they are in pieces/monsters_hd/warden_rejected/). Two frames, as the game wants for a hurt ([hurt, flash]): leaning back a few
degrees with a small jolt up, then the same with the armour flashed pale.

The picture is painted (no outline), so there is no outline pass. The red armour is brightened a little before the palette snap, and the
sheet builder (gen_monster_sheets_hd.py, spec "warden") writes the sheet, the frame lists, the fps and `pixel_size` into data/monsters/warden.tres.

    python tools/art/gen_warden_hd.py          # halves the frames to 128 and builds the sheet
    python tools/art/gen_warden_hd.py 256      # keep the native 256 pixels (twice as fine as the other monsters)

This replaces the older single-pose placeholder (gen_warden.py, 11 frames of 96x128, no longer part of build_all).
"""
import shutil
import subprocess
import sys
from pathlib import Path

from PIL import Image

HERE = Path(__file__).resolve().parent
LIFT = 1.15  # Brightness before the palette snap: the dark armour must still read against the darkest wall (docs/art_style.md).
SRC = HERE / "pieces" / "monsters_hd" / "warden_256"
OUT = HERE / "pieces" / "monsters_hd" / "warden"


def _frame(im, size):
    if size != 256:
        a = im.getchannel("A").resize((size, size), Image.LANCZOS).point(lambda v: 255 if v > 110 else 0)
        im = im.resize((size, size), Image.LANCZOS)
        im.putalpha(a)
    return im


def _lifted(im):
    if LIFT == 1.0:
        return im
    r, g, b, a = im.split()
    return Image.merge("RGBA", [c.point(lambda v: min(255, int(v * LIFT))) for c in (r, g, b)] + [a])


def make_hurt(size):
    """The two hurt frames from idle_0 (see the header): a lean back about the feet with a jolt up, and the same flashed pale."""
    base = Image.open(SRC / "idle_0.png").convert("RGBA")
    out = []
    for flash in (False, True):
        big = base.rotate(4.0, resample=Image.BICUBIC, center=(base.width * 0.5, base.height - 2))  # Leans away: the top swings back.
        shifted = Image.new("RGBA", big.size, (0, 0, 0, 0))
        shifted.alpha_composite(big, (0, -6))  # The jolt of the blow.
        if flash:
            r, g, b, a = shifted.split()
            shifted = Image.merge("RGBA", [c.point(lambda v: v + (255 - v) * 45 // 100) for c in (r, g, b)] + [a])
        out.append(_frame(_lifted(shifted), size))
    return out


def prepare(size=128):
    if OUT.exists():
        shutil.rmtree(OUT)
    OUT.mkdir(parents=True)
    for f in sorted(SRC.glob("*.png")):
        _frame(_lifted(Image.open(f).convert("RGBA")), size).save(OUT / f.name)
    for i, frame in enumerate(make_hurt(size)):
        frame.save(OUT / f"hurt_{i}.png")


if __name__ == "__main__":
    size = int(sys.argv[1]) if len(sys.argv) > 1 else 128
    prepare(size)
    subprocess.run([sys.executable, str(HERE / "gen_monster_sheets_hd.py"), "warden"], check=True)
