"""The carved wooden frame round the 3D view (art/ui/frame_wood.png, 1280x720, transparent outside the ring and inside its opening),
laid over art/ui/frame.png by ui_frame.gd.

`pieces/frame_wood/ring.png` is one PixelLab picture (`create_image_pro`, 432x276 = the view and its surround in canvas units, with a
style reference, the opening flat magenta): oak planks, four different skulls with tentacles through their eye sockets, tentacles
coiled at random and green slime dripping at random. Here the magenta opening is keyed out, the colours are put onto the palette (slime
-> `curse_*` greens by brightness, wood -> the wood ramp, skulls -> bone, tentacles -> stone) and the picture is enlarged 2x (each
art pixel a 2x2 block, like the older UI art). The opening must lie inside the 3D view (asserted), so the ring covers a little of
the view's edge and nothing of the stone shows through it. Slime is on this frame only, never the party panels.

    python tools/art/gen_frame_wood.py
"""
import os
from pathlib import Path

from PIL import Image

from artio import save_png
from palette import PAL

K = 2
W, H = 640 * K, 360 * K
VIEW = (8, 8, 416, 260)               # scripts/ui_layout.gd, canvas units.
RING = Path(__file__).parent / "pieces" / "frame_wood" / "ring.png"
WOOD = ["soil_900", "wood_700", "wood_500", "leather_400"]
BONE = ["bone_700", "bone_500", "bone_300"]


def is_magenta(p):
    return p[0] > 170 and p[2] > 170 and p[1] < 90


def recolour(img):
    """Key the opening (magenta reached from the middle) to transparent and move every other colour onto the palette."""
    px = img.load()
    w, h = img.size
    hole, stack = set(), [(w // 2, h // 2)]
    while stack:
        x, y = stack.pop()
        if (x, y) in hole or not (0 <= x < w and 0 <= y < h) or not is_magenta(px[x, y]):
            continue
        hole.add((x, y))
        stack += [(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)]
    out = Image.new("RGBA", img.size)
    op = out.load()
    for y in range(h):
        for x in range(w):
            if (x, y) in hole:
                continue
            r, g, b = px[x, y][:3]
            lum = 0.299 * r + 0.587 * g + 0.114 * b
            if g > r + 25 and g > b + 25:  # Slime.
                name = "curse_300" if lum > 215 else ("curse_500" if lum > 135 else "curse_700")
            elif r - b > 14 and lum > 125:  # Skull.
                name = BONE[0] if lum < 150 else (BONE[1] if lum < 190 else BONE[2])
            elif r - b > 10:  # Wood.
                name = WOOD[0] if lum < 38 else (WOOD[1] if lum < 66 else (WOOD[2] if lum < 100 else WOOD[3]))
            else:  # Tentacles, outlines and shadow: the stone greys.
                name = "ink" if lum < 24 else ("stone_800" if lum < 44 else ("stone_700" if lum < 74 else ("stone_500" if lum < 108 else ("stone_300" if lum < 150 else "stone_100"))))
            op[x, y] = (*PAL[name], 255)
    return out, hole


def frame_wood():
    src = Image.open(RING).convert("RGB")
    ring, hole = recolour(src)
    xs = [x for x, _ in hole]
    ys = [y for _, y in hole]
    box = (min(xs), min(ys), max(xs) + 1, max(ys) + 1)
    assert box[0] >= VIEW[0] and box[1] >= VIEW[1] and box[2] <= VIEW[0] + VIEW[2] and box[3] <= VIEW[1] + VIEW[3], box
    big = ring.resize((ring.width * K, ring.height * K), Image.NEAREST)
    img = Image.new("RGBA", (W, H))
    img.paste(big, (0, 0))
    return img


def build():
    os.environ["ART_OVERWRITE_IMPORTED"] = "1"
    return [save_png(frame_wood(), "ui/frame_wood.png")]


if __name__ == "__main__":
    for p in build():
        print(p)
