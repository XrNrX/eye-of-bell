"""The title screen: art/ui/title.png, 640x360 at FULL RESOLUTION: one art pixel is one pixel of the 640x360
screen (the menu shows it 1:1, and the window then scales the whole screen by a whole number), so it has the
same fine pixels as the doubled dungeon art, finer than the 2x UI blocks. It is not enlarged here.

The picture is a PixelLab image drawn at 640x360 (create_image_pro: the entrance to a cursed dungeon at night, a
ruined archway with a sickly green glow from deep inside, dead twisted trees, fog, dark sky at the top left clear for
the logo). The source piece is tools/art/pieces/title.png (640x360; title_alt.png is an alternative drawn with
create_image_pixen); this only snaps it to the palette. The first version was 320x180 doubled: it is kept in
tools/art/_old/ui/. With no piece, a plain dark gradient is written so the game still has a title background.
"""
from pathlib import Path

from PIL import Image

from artio import save_png
from palette import PAL

PIECE = Path(__file__).parent / "pieces" / "title.png"
W, H = 640, 360


def title():
    if PIECE.exists():
        img = Image.open(PIECE).convert("RGBA")
        if img.size != (W, H):  # A smaller piece (e.g. the old 320x180) is enlarged by a whole number if it can be.
            img = img.resize((W, H), Image.NEAREST)
        return PAL.snap(img)
    img = Image.new("RGBA", (W, H))
    px = img.load()
    ramp = [PAL["ink"], PAL["stone_900"], PAL["stone_800"]]
    for y in range(H):
        for x in range(W):
            px[x, y] = (*ramp[min(2, y * 3 // H)], 255)
    return img


def build(scale=2):
    """`scale` is ignored on purpose: the title is full resolution, whatever the UI scale is."""
    return [save_png(title(), "ui/title.png", scale=1)]
