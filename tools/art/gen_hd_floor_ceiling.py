"""The 256x256 floor and ceiling (hires-720 branch) from PixelLab pieces in tools/art/pieces/tiles256/.

floor.png / ceiling.png are the raw PixelLab pictures (blue-grey, too bright for the game). The floor is re-toned the way gen_wall_decor does
for the stone variants: every pixel is ranked by brightness and given the colour of the same rank in floor_tone_ref.png (the old 128 floor), so
the structure is the new picture's but the grey and the light and dark balance are the old floor's. The ceiling is the picture ranked onto a dim
grey ramp (the raw one is purple), so the beams and stones show but it stays dark.

    python tools/art/gen_hd_floor_ceiling.py [--ceiling-gain 1.0]
"""
import os
import sys
from pathlib import Path

import numpy as np
from PIL import Image

from artio import save_png
from palette import PAL

PIECES = Path(__file__).parent / "pieces" / "tiles256"


def lum(rgb):
    return 0.2126 * rgb[..., 0] + 0.7152 * rgb[..., 1] + 0.0722 * rgb[..., 2]


def rank_tone(img, ref):
    a = np.asarray(img.convert("RGB"), dtype=np.float64)
    order = np.argsort(lum(a).reshape(-1), kind="stable")
    r = np.asarray(ref.convert("RGB"))
    ref_sorted = r.reshape(-1, 3)[np.argsort(lum(r.astype(np.float64)).reshape(-1), kind="stable")]
    idx = (np.arange(order.size) * (ref_sorted.shape[0] - 1) / max(1, order.size - 1)).astype(int)
    out = np.zeros((order.size, 3), np.uint8)
    out[order] = ref_sorted[idx]
    return Image.fromarray(out.reshape(a.shape[0], a.shape[1], 3), "RGB").convert("RGBA")


def build(ceiling_gain=1.0):
    os.environ["ART_OVERWRITE_IMPORTED"] = "1"  # floor.png and ceiling.png are listed as imported art; this replaces them on purpose.
    floor = rank_tone(Image.open(PIECES / "floor.png"), Image.open(PIECES / "floor_tone_ref.png"))
    # The ceiling: ranked onto a dim ramp (ink, stone 900/800/700 in 30/30/25/15 %), so its beams and stones show but it stays as dark as a ceiling
    # in a torch-lit dungeon should; `ceiling_gain` stretches the ramp (1 = as dark as that, 2 = brighter).
    ramp = [("ink", 30), ("stone_900", 30), ("stone_800", 25), ("stone_700", 15)]
    strip = []
    for name, pct in ramp:
        strip += [PAL[name]] * pct
    ref = Image.new("RGB", (len(strip), 1))
    for i, c in enumerate(strip):
        ref.putpixel((i, 0), tuple(min(255, int(v * ceiling_gain)) for v in c[:3]))
    ceiling = PAL.snap(rank_tone(Image.open(PIECES / "ceiling.png"), ref))
    return [save_png(PAL.snap(floor), "tiles/floor.png"), save_png(ceiling, "tiles/ceiling.png")]


if __name__ == "__main__":
    gain = float(sys.argv[sys.argv.index("--ceiling-gain") + 1]) if "--ceiling-gain" in sys.argv else 1.0
    for p in build(gain):
        print(p)
