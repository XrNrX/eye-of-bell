"""The camp: art/camp/{pit,pit_front,spit,quilt,kindling}.png and art/camp/flame_sheet.png (+ .json: one row of 8 frames, 10 fps).

Source pieces are in tools/art/pieces/camp/ (PixelLab, see docs/asset_log.md "Campfire and bedroll"):
    pit_e_nodisc.png  64x56  crossed charred logs on an ember bed, no flame, no stone disc
    bed_d.png         64x40  a dark grey-brown quilted blanket on a pallet (the 3D bedroll's look; the bedroll itself is built in code)
    kindling_a.png    48x32  sticks over a bed of glowing coals (its painted flame is removed here: the animated flame stands on it)
    spit_a.png        64x48  two iron-forked posts with a rod and a piece of meat (cropped to its box)
    flame.png         3x3 grid of 8 frames of 48x76, the VFX tool's campfire flame
quilt.png is drawn here (32x16): the top of a bedroll's blanket, a quilted bone-grey with dark stitching.
Everything is snapped to the palette. The flame's colours are mapped onto the torch and rust ramps by lightness. Drawn at their native size (not doubled): the game shows them
as billboards at 0.022 world units an art pixel (scripts/camp_site.gd).
"""
import json
from pathlib import Path

from PIL import Image

from artio import save_png
from palette import ART_DIR, PAL

PIECES = Path(__file__).parent / "pieces" / "camp"
FRAME_W, FRAME_H, FRAMES, FPS = 48, 76, 8, 10
FRONT_FROM = 42   # pit_front keeps the pit's rows from here down (of 56)


def _recolour(img, fn):
    px = img.load()
    for y in range(img.height):
        for x in range(img.width):
            r, g, b, a = px[x, y]
            if a:
                px[x, y] = (*fn((r, g, b)), a)
    return img


def _grey(rgb):
    """A blue-grey pixel (PixelLab stone) as the same lightness in neutral grey, before the palette snap picks a stone colour."""
    v = round(0.299 * rgb[0] + 0.587 * rgb[1] + 0.114 * rgb[2])
    return (v, v, v) if rgb[2] >= rgb[0] and abs(rgb[0] - rgb[1]) < 40 else rgb


def flame_sheet():
    grid = Image.open(PIECES / "flame.png").convert("RGBA")
    sheet = Image.new("RGBA", (FRAME_W * FRAMES, FRAME_H), (0, 0, 0, 0))
    for i in range(FRAMES):
        f = grid.crop(((i % 3) * FRAME_W, (i // 3) * FRAME_H, (i % 3) * FRAME_W + FRAME_W, (i // 3) * FRAME_H + FRAME_H))
        sheet.paste(f, (i * FRAME_W, 0))
    # The VFX tool's fire colours move onto the torch and rust ramps by lightness (a plain nearest-colour snap flattened it to two tones):
    # torch_300 for the hot core, torch_500, rust_300, rust_500, rust_700 and ink for the outline.
    ramp = [(40, "ink"), (75, "rust_700"), (110, "rust_500"), (150, "rust_300"), (190, "torch_500"), (240, "torch_300"), (256, "torch_300")]

    def fire(c):
        lum = 0.299 * c[0] + 0.587 * c[1] + 0.114 * c[2]
        for limit, name in ramp:
            if lum < limit:
                return PAL[name]
        return PAL["torch_300"]
    _recolour(sheet, fire)
    return PAL.snap(sheet)


def kindling():
    """kindling_a without its painted flame: the bright yellow-orange flame pixels above the coal bed (the top 16 rows) are cleared, the red
    coals and the sticks stay."""
    img = Image.open(PIECES / "kindling_a.png").convert("RGBA")
    px = img.load()
    for y in range(min(16, img.height)):
        for x in range(img.width):
            r, g, b, a = px[x, y]
            if a and r > 170 and g > 60 and r > b + 60 and (g > 90 or r > 235):
                px[x, y] = (0, 0, 0, 0)
    return PAL.snap(img)


def pit_front():
    """The lower part of the pit (rows from FRONT_FROM down): drawn in front of the flame so the fire burns from inside the pile."""
    img = Image.open(ART_DIR / "camp" / "pit.png").convert("RGBA")
    px = img.load()
    for y in range(min(FRONT_FROM, img.height)):
        for x in range(img.width):
            px[x, y] = (0, 0, 0, 0)
    return img


def quilt():
    """The top of a bedroll's blanket: bone-grey squares (3 x 2) with dark stitching between them and a darker hem, a little worn."""
    w, h = 32, 16
    img = Image.new("RGBA", (w, h), (*PAL["bone_700"], 255))
    px = img.load()
    for y in range(h):
        for x in range(w):
            edge = x in (0, w - 1) or y in (0, h - 1)
            stitch = (x % 11 == 10 and 0 < x < w - 1) or (y == 7 and 0 < x < w - 1)
            if edge:
                px[x, y] = (*PAL["wood_700"], 255)
            elif stitch:
                px[x, y] = (*PAL["wood_500"], 255)
            elif (x * 7 + y * 13) % 17 == 0:   # a few worn, lighter threads
                px[x, y] = (*PAL["bone_500"], 255)
    return img


def build(scale=None):
    out = ART_DIR / "camp"
    out.mkdir(parents=True, exist_ok=True)
    written = []
    for name, piece, grey in (("pit", "pit_e_nodisc.png", False), ("spit", "spit_a.png", False)):
        img = Image.open(PIECES / piece).convert("RGBA")
        if name == "spit":
            img = img.crop(img.getbbox())
        if grey:
            _recolour(img, _grey)
        written.append(save_png(PAL.snap(img), f"camp/{name}.png"))
    written.append(save_png(flame_sheet(), "camp/flame_sheet.png"))
    written.append(save_png(quilt(), "camp/quilt.png"))
    written.append(save_png(kindling(), "camp/kindling.png"))
    written.append(save_png(pit_front(), "camp/pit_front.png"))
    info = out / "flame_sheet.json"
    info.write_text(json.dumps({"frames": FRAMES, "fps": FPS, "frame_w": FRAME_W, "frame_h": FRAME_H}, indent=2))
    written.append(info)
    return written


if __name__ == "__main__":
    for p in build():
        print(p)
