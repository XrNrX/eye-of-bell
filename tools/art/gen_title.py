"""The title screen: art/ui/title.png, 640x360 (320x180 logical pixels drawn at 2x, the same chunky pixels as
the rest of the UI).

The picture is a PixelLab image (the entrance to a cursed dungeon at night: a ruined archway with a sickly green
glow, dead twisted trees, fog, a dark band of sky at the top left clear for the logo). The source piece is
tools/art/pieces/title.png (320x180); this snaps it to the palette and enlarges it. With no piece, a plain
dark gradient is written so the game still has a title background.
"""
from pathlib import Path

from PIL import Image

from artio import save_png
from palette import PAL

PIECE = Path(__file__).parent / "pieces" / "title.png"
W, H = 320, 180


def title():
    if PIECE.exists():
        return PAL.snap(Image.open(PIECE).convert("RGBA").resize((W, H), Image.NEAREST))
    img = Image.new("RGBA", (W, H))
    px = img.load()
    ramp = [PAL["ink"], PAL["stone_900"], PAL["stone_800"]]
    for y in range(H):
        for x in range(W):
            px[x, y] = (*ramp[min(2, y * 3 // H)], 255)
    return img


def build(scale=2):
    return [save_png(title(), "ui/title.png", scale=scale)]
