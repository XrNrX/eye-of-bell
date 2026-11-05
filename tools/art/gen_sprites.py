"""Small sprites written to res://art/sprites/: the wall torch (4 animation frames of
16x32 side by side), the key (16x16) and the lever (2 frames of 16x16: off, on).
Every colour comes from the palette.
"""
from PIL import Image

from artio import save_png, save_sheet_info
from palette import PAL


def rgba(name):
    return (*PAL[name], 255)


def torch_sheet():
    fw, fh = 16, 32
    sheet = Image.new("RGBA", (fw * 4, fh), (0, 0, 0, 0))
    px = sheet.load()
    tops = [4, 2, 5, 3]    # Flame tip row per frame (lower number = taller flame).
    sways = [0, 1, 0, -1]  # Sideways lean of the tip per frame.
    for f in range(4):
        ox = f * fw
        for y in range(17, 32):  # Wooden handle, lit on the left.
            px[ox + 7, y] = rgba("wood_500")
            px[ox + 8, y] = rgba("wood_700")
        for x in range(4, 12):   # Iron cup.
            px[ox + x, 15] = rgba("stone_500")
        for x in range(5, 11):
            px[ox + x, 16] = rgba("stone_800")
        for x in range(5, 11):   # Bracket.
            px[ox + x, 24] = rgba("stone_500")
        height = 15 - tops[f]
        for i in range(height):  # Flame, drawn tip to base.
            t = i / height
            hw = round(3.4 * (t ** 0.6) * (1 - 0.35 * t))
            cx = 8 + round(sways[f] * (1 - t) * 2)
            for dx in range(-hw, hw + 1):
                if hw == 0:
                    c = "torch_500"
                elif abs(dx) <= hw * 0.35 and t > 0.4:
                    c = "torch_300"  # Hot core.
                elif abs(dx) <= hw * 0.7:
                    c = "torch_500"  # Mid flame.
                else:
                    c = "rust_300"   # Cooler outer edge.
                px[ox + cx + dx, tops[f] + i] = rgba(c)
    return sheet


def lever_sheet():
    sheet = Image.new("RGBA", (32, 16), (0, 0, 0, 0))
    px = sheet.load()
    for f in range(2):
        ox = f * 16
        for y in range(1, 15):  # Back plate.
            for x in range(4, 12):
                edge = x in (4, 11) or y in (1, 14)
                px[ox + x, y] = rgba("stone_800" if edge else "stone_500")
        for y in range(3, 13):  # Slot the handle moves in.
            px[ox + 7, y] = rgba("stone_800")
            px[ox + 8, y] = rgba("stone_800")
        for y in ((3, 4, 5, 6, 7, 8) if f == 0 else (8, 9, 10, 11, 12)):
            px[ox + 7, y] = rgba("stone_300")  # Handle shaft.
            px[ox + 8, y] = rgba("stone_300")
        ky = 2 if f == 0 else 13  # Knob at the free end.
        for dx in (-1, 0, 1, 2):
            for dy in (-1, 0, 1):
                px[ox + 7 + dx, ky + dy] = rgba("rust_500")
        px[ox + 6, 8] = rgba("stone_100")  # Pivot bolt.
        px[ox + 9, 8] = rgba("stone_100")
    return sheet


def key_sprite():
    """Small gold key pointing down-right, with a ring bow."""
    img = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    px = img.load()
    gold, light, shadow = rgba("torch_500"), rgba("torch_300"), rgba("torch_700")
    for dx, dy in [(-2, -1), (-2, 0), (-2, 1), (-1, -2), (0, -2), (1, -2),
                   (-1, 2), (0, 2), (1, 2), (2, -1), (2, 0), (2, 1)]:
        px[4 + dx + 1, 4 + dy + 1] = gold  # Bow (ring).
    px[4, 3] = light
    px[5, 3] = light
    for i in range(7, 14):  # Shaft.
        px[i - 1, i - 1] = gold
        px[i, i - 1] = shadow
    for (x, y) in [(11, 13), (12, 13), (13, 12), (13, 11)]:  # Teeth.
        px[x, y] = gold
    for (x, y) in [(10, 13), (13, 10)]:
        px[x, y] = shadow
    return img


def build():
    return [
        save_png(torch_sheet(), "sprites/torch.png"),
        save_sheet_info("sprites/torch.png", (16, 32), 4, count_free=True),    # The game reads the count from the sheet.
        save_png(key_sprite(), "sprites/key.png", scale=2),  # 32x32; the key's icon_pixel_size (0.015) is set for that
        save_png(lever_sheet(), "sprites/lever.png"),
        save_sheet_info("sprites/lever.png", (16, 16), 2, count_free=False),   # Exactly two states: off, on.
    ]
