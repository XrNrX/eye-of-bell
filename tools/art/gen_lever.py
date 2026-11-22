"""The wall lever sheet (art/sprites/lever.png): two frames of 64x64, off then on, from the PixelLab picture
tools/art/pieces/lever/lever_off_raw.png (a riveted iron plate with the handle up). The ON frame is the same plate with
turned upside down (the handle points down).
Run: python tools/art/gen_lever.py. The game's lever is dungeon_builder.LEVER_PIXEL_SIZE 0.0225 for 64 px frames."""
import os
from PIL import Image, ImageOps

from artio import save_png, save_sheet_info
from palette import PAL

HERE = os.path.dirname(os.path.abspath(__file__))
DROP = 4     # Rows the ON frame is lifted by (measured: the plate's top rows 4 and 8).
INNER = 0    # The whole picture is turned upside down for ON (the handle points down).


def frames():
    raw = Image.open(os.path.join(HERE, "pieces", "lever", "lever_off_raw.png")).convert("RGBA")
    box = raw.getbbox()
    cx, cy = (box[0] + box[2]) // 2, (box[1] + box[3]) // 2
    off = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
    off.alpha_composite(raw.crop((cx - 32, cy - 32, cx + 32, cy + 32)) if False else raw)
    off = PAL.snap(off)
    on = off.copy()
    b = off.getbbox()
    inner = (b[0] + INNER, b[1] + INNER, b[2] - INNER, b[3] - INNER)
    on.paste(ImageOps.flip(off.crop(inner)), inner[:2])
    # The flip moves the plate (the handle sticks out past one end): shift ON so its plate sits where OFF's does.
    shifted = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
    shifted.paste(on, (0, -DROP))
    return off, shifted


def build(scale=1):
    off, on = frames()
    sheet = Image.new("RGBA", (128, 64), (0, 0, 0, 0))
    sheet.paste(off, (0, 0))
    sheet.paste(on, (64, 0))
    return [save_png(sheet, "sprites/lever.png"), save_sheet_info("sprites/lever.png", (64, 64), 2, count_free=False)]


if __name__ == "__main__":
    print(build())
