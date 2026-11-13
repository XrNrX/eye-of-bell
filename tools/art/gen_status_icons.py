"""Status icons drawn beside a monster's health bar (scripts/enemy_bars.gd), one per StatusDef that has an icon.

    art/ui/status_held.png   7x7, a padlock: the monster is held (Hold Monster)

Drawn 1:1 in the 3D view's own pixels, like the bars (no UI 2x scale). Small enough that PixelLab's 16 px minimum is no use.
"""
from PIL import Image

from artio import save_png
from palette import PAL

HELD = [
    "..kkk..",
    ".kbbbk.",
    ".kb.bk.",
    "kkkkkkk",
    "kbbbbbk",
    "kbbkbbk",
    "kkkkkkk",
]


def icon(rows, colours):
    img = Image.new("RGBA", (len(rows[0]), len(rows)), (0, 0, 0, 0))
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            if ch in colours:
                img.putpixel((x, y), (*PAL[colours[ch]], 255))
    return img


def build(scale=None):
    return [save_png(icon(HELD, {"k": "ink", "b": "stone_100"}), "ui/status_held.png")]


if __name__ == "__main__":
    for p in build():
        print(p)
