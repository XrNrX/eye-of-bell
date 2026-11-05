"""Wall decorations that are not part of a tile: a carved curse-rune panel and a hidden stone
button. Placeholder drawings (flat stone with a few marks); the real art comes from PixelLab through
import_pixellab.py. Not used by the game yet (no mechanic reads them)."""
from PIL import Image

from artio import save_png
from palette import PAL


def _panel(size, glow):
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    px = img.load()
    for y in range(size):
        for x in range(size):
            edge = x in (0, size - 1) or y in (0, size - 1)
            px[x, y] = (*PAL["ink"], 255) if edge else (*PAL["stone_700"], 255)
    if glow:
        for i in range(8, size - 8, 4):
            px[i, size // 2] = (*PAL["curse_700"], 255)
            px[size // 2, i] = (*PAL["curse_500"], 255)
    return img


def build(scale=1):
    return [
        save_png(_panel(48, True), "decals/rune_panel.png"),
        save_png(_panel(32, False), "decals/hidden_button.png"),
    ]


if __name__ == "__main__":
    print(build())
