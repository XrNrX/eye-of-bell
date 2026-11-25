"""The brazier (roadmap 7e.3), from the PixelLab pieces in tools/art/pieces/brazier/: art/brazier/brazier.png (the unlit iron bowl,
stood on the bottom of its 64x80 frame) and art/brazier/flame_sheet.png (+ .json {frames, fps, frame_w, frame_h}), the VFX tool's
'Brazier flame' as one row. Everything is snapped to the palette. Run: python tools/art/gen_brazier.py"""
import json
import os

from PIL import Image

from artio import ART_DIR, save_png
from gen_seal import standing
from palette import PAL

PIECES = os.path.join(os.path.dirname(os.path.abspath(__file__)), "pieces", "brazier")


def flame():
    with open(os.path.join(PIECES, "flame.json")) as f:
        info = json.load(f)
    atlas = Image.open(os.path.join(PIECES, "flame.png")).convert("RGBA")
    entries = info["frames"]
    entries = list(entries.values()) if isinstance(entries, dict) else entries
    w, h = entries[0]["sourceSize"]["w"], entries[0]["sourceSize"]["h"]
    row = Image.new("RGBA", (w * len(entries), h), (0, 0, 0, 0))
    for i, e in enumerate(entries):
        r = e["frame"]
        row.paste(atlas.crop((r["x"], r["y"], r["x"] + r["w"], r["y"] + r["h"])),
                  (i * w + e["spriteSourceSize"]["x"], e["spriteSourceSize"]["y"]))
    return PAL.snap(row), {"frames": len(entries), "fps": round(1000.0 / entries[0]["duration"], 2), "frame_w": w, "frame_h": h}


def build():
    sheet, meta = flame()
    info = ART_DIR / "brazier/flame_sheet.json"
    written = [save_png(standing(os.path.join(PIECES, "brazier.png")), "brazier/brazier.png"), save_png(sheet, "brazier/flame_sheet.png")]
    info.write_text(json.dumps(meta, indent=2))
    return written + [info]


if __name__ == "__main__":
    print("\n".join(str(p) for p in build()))
