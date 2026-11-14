"""A TRIAL of a different art style (14 Nov 2026): a monster as a 'digitised painting', after a reference the user liked: soft painted
shading with no outline, lit from the upper left with the far side lost in shadow, low resolution, and the grain of a scanned picture.

PixelLab only draws clean pixel art, so the look is made here, by script, from a monster's existing animation sheet
(art/monsters/<name>/<name>_sheet.png, every frame of it, so the full PixelLab animation is kept): each frame is blurred until
the outline and flat shading melt, lit from the upper left (SIDE: how far the lower right falls into shadow), shrunk to half size
and dithered onto the palette with a fixed 8x8 pattern (a fixed pattern, not error diffusion, so the grain does not crawl from
frame to frame). The hurt frames are washed blood red, as the reference's hit state is.

Writes art/monsters/<name>_painted/<name>_painted_sheet.png with the same frame count and order as the source, frames half the
size: the .tres is the source's with the new sheet and twice the pixel_size. Not run by build_all.

(The first version of this trial used one still picture, pieces/painted/skeleton_guard.png, moved about by script. Those pieces
are kept; the sheet made from them is not.)

    python tools/art/gen_painted_monster.py            # every monster in SHRINKS
    python tools/art/gen_painted_monster.py slime      # one

It also writes data/monsters/<name>_painted.tres: the source's, with the new sheet, the pixel_size multiplied by the shrink and
"Painted" in front of the name.
"""
import os
import re
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageEnhance, ImageFilter

from artio import save_png
from palette import PAL

ROOT = Path(__file__).resolve().parents[2]
SHRINKS = {"skeleton_guard": 2, "skeleton": 2, "slime": 2, "slime_acid": 2, "warden": 1}  # Source pixels per painted pixel (the Warden's old art is already coarse).
SIDE = 0.8                   # How much the light falls off towards the lower right (0 flat .. 1 black).
BRIGHT = 1.9                 # The lit side, before the fall-off.
SATURATION = 0.75
CONTRAST = 1.3
GRAIN = 16.0                 # Strength of the dither pattern, in colour levels.
BLOOD = (150, 28, 22)        # The hurt wash.
WASH = 0.8
BAYER = np.array([
    [0, 32, 8, 40, 2, 34, 10, 42], [48, 16, 56, 24, 50, 18, 58, 26], [12, 44, 4, 36, 14, 46, 6, 38], [60, 28, 52, 20, 62, 30, 54, 22],
    [3, 35, 11, 43, 1, 33, 9, 41], [51, 19, 59, 27, 49, 17, 57, 25], [15, 47, 7, 39, 13, 45, 5, 37], [63, 31, 55, 23, 61, 29, 53, 21],
], dtype=np.float32) / 64.0 - 0.5
COLOURS = np.array(sorted(PAL.allowed), dtype=np.float32)


def dithered(rgb, alpha):
    """An RGB image put on the palette through the fixed pattern; transparent where alpha is 0."""
    a = np.asarray(rgb, dtype=np.float32)
    h, w, _ = a.shape
    noise = np.tile(BAYER, (h // 8 + 1, w // 8 + 1))[:h, :w, None] * GRAIN
    a = np.clip(a + noise, 0, 255)
    d = ((a[:, :, None, :] - COLOURS[None, None, :, :]) ** 2).sum(axis=3)
    out = COLOURS[d.argmin(axis=2)].astype(np.uint8)
    al = np.asarray(alpha, dtype=np.uint8)
    return Image.fromarray(np.dstack([out * (al[:, :, None] > 0), al]), "RGBA")


def figure_box(sheet, frames, size):
    """The box round the figure in its first (standing) frame: the light falls across the body, not across the empty frame
    or the reach of a swung weapon."""
    return sheet.crop((0, 0, size, sheet.height)).getchannel("A").getbbox()


def light(width, height, box):
    """Brightness per pixel: full at the figure's upper left, falling to 1 - SIDE at its lower right."""
    x0, y0, x1, y1 = box
    xs = np.clip((np.arange(width, dtype=np.float32) - x0) / max(1, x1 - x0), 0, 1)
    ys = np.clip((np.arange(height, dtype=np.float32) - y0) / max(1, y1 - y0), 0, 1)
    t = 1.0 - (0.8 * xs[None, :] + 0.2 * ys[:, None])
    return ((1.0 - SIDE) + SIDE * t) * BRIGHT


def painted(frame, lum, wash=0.0, shrink=2):
    a = frame.getchannel("A")
    rgb = Image.new("RGB", frame.size, (20, 16, 24))
    rgb.paste(frame.convert("RGB"), (0, 0), a)
    rgb = rgb.filter(ImageFilter.MedianFilter(3)).filter(ImageFilter.GaussianBlur(1.3))
    rgb = ImageEnhance.Color(rgb).enhance(SATURATION)
    arr = np.asarray(rgb, dtype=np.float32) * lum[:, :, None]
    if wash:
        arr = arr * (1 - wash) + (arr * np.array([1.0, 0.35, 0.3], dtype=np.float32)) * wash
        arr = arr * (1 - wash * 0.18) + np.array(BLOOD, dtype=np.float32) * (wash * 0.18)
    rgb = ImageEnhance.Contrast(Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), "RGB")).enhance(CONTRAST)
    small = (frame.width // shrink, frame.height // shrink)
    sa = a.resize(small, Image.LANCZOS).point(lambda v: 255 if v > 110 else 0)
    return dithered(rgb.resize(small, Image.LANCZOS), sa)


def tres_values(name):
    text = (ROOT / "data" / "monsters" / f"{name}.tres").read_text(encoding="utf-8")
    frames = int(re.search(r"hframes = (\d+)", text).group(1))
    hurt = [int(v) for v in re.search(r"hurt_frames = PackedInt32Array\(([^)]*)\)", text).group(1).split(",")]
    return frames, set(hurt)


def sheet(name):
    src = Image.open(ROOT / "art" / "monsters" / name / f"{name}_sheet.png").convert("RGBA")
    frames, hurt = tres_values(name)
    size = src.width // frames
    shrink = SHRINKS.get(name, 2)
    lum = light(size, src.height, figure_box(src, frames, size))
    out = Image.new("RGBA", (src.width // shrink, src.height // shrink), (0, 0, 0, 0))
    for i in range(frames):
        f = painted(src.crop((i * size, 0, (i + 1) * size, src.height)), lum, WASH if i in hurt else 0.0, shrink)
        out.paste(f, (i * size // shrink, 0))
    return out


def write_tres(name):
    """data/monsters/<name>_painted.tres: the source's stats and frame lists with the painted sheet."""
    text = (ROOT / "data" / "monsters" / f"{name}.tres").read_text(encoding="utf-8")
    old = f"res://art/monsters/{name}/{name}_sheet.png"
    assert text.count(old) == 1, old
    text = text.replace(old, f"res://art/monsters/{name}_painted/{name}_painted_sheet.png")
    text = re.sub(r'display_name = "(.*)"', lambda m: 'display_name = "Painted %s"' % m.group(1).replace("Skeleton Guard", "Guard"), text, count=1)
    size = float(re.search(r"pixel_size = ([\d.]+)", text).group(1)) * SHRINKS.get(name, 2)
    text = re.sub(r"pixel_size = [\d.]+", "pixel_size = %s" % round(size, 5), text, count=1)
    text = text.replace("boss = true" + chr(10), "")   # The trial copy is not a boss (no boss bar or first-sight banter in the test room).
    (ROOT / "data" / "monsters" / f"{name}_painted.tres").write_text(text, encoding="utf-8", newline=chr(10))


def build(names=None):
    os.environ["ART_OVERWRITE_IMPORTED"] = "1"
    paths = []
    for name in names or list(SHRINKS):
        paths.append(save_png(sheet(name), f"monsters/{name}_painted/{name}_painted_sheet.png"))
        write_tres(name)
    return paths


if __name__ == "__main__":
    for p in build(sys.argv[1:]):
        print(p)
