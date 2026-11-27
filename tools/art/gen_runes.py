"""Darkness runes (roadmap 7e.4), from the VFX tool's 'Darkness runes' in tools/art/pieces/runes/ (runes.png + .json): art/runes/
rune_sheet.png (+ .json {frames, fps, frame_w, frame_h}: the living ring, looping) and rune_fade_sheet.png (three frames of the first
one in darker curse greens, dim to bright: how they come and go in palette steps). Run: python tools/art/gen_runes.py"""
import json

from PIL import Image

from artio import ART_DIR, save_png
from gen_seal import frames
from palette import PAL

# The effect's three greens, darkest to lightest, and the darker palette greens each becomes on the way in.
GREENS = ["curse_700", "curse_500", "curse_300"]
STEPS = [{"curse_300": "moss_900", "curse_500": "moss_900", "curse_700": "moss_900"},
         {"curse_300": "moss_700", "curse_500": "moss_700", "curse_700": "moss_900"},
         {"curse_300": "curse_700", "curse_500": "curse_700", "curse_700": "moss_700"}]


def darker(img, table):
    out = img.copy()
    px = out.load()
    swap = {PAL[a]: PAL[b] for a, b in table.items()}
    for y in range(out.height):
        for x in range(out.width):
            r, g, b, a = px[x, y]
            if a and (r, g, b) in swap:
                px[x, y] = swap[(r, g, b)] + (a,)
    return out


def row(pictures):
    w, h = pictures[0].size
    out = Image.new("RGBA", (w * len(pictures), h), (0, 0, 0, 0))
    for i, p in enumerate(pictures):
        out.paste(p, (i * w, 0))
    return out


def build():
    pictures, fps = frames("runes", "runes")
    info = ART_DIR / "runes/rune_sheet.json"
    written = [save_png(row(pictures), "runes/rune_sheet.png"), save_png(row([darker(pictures[0], t) for t in STEPS]), "runes/rune_fade_sheet.png")]
    info.write_text(json.dumps({"frames": len(pictures), "fps": fps, "frame_w": pictures[0].width, "frame_h": pictures[0].height}, indent=2))
    return written + [info]


if __name__ == "__main__":
    print("\n".join(str(p) for p in build()))
