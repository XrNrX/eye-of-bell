"""Legendary item art: art/ui/legend_frame.png (a worn-gold slot frame, a 32x32 nine-patch with a clear centre) and
art/ui/legend_shimmer_sheet.png (+ .json: a row of 16 frames of 27x34, 12 fps, a slow loop of golden glints).

Source pieces are in tools/art/pieces/legend/ (PixelLab, see docs/asset_log.md "Legendary items"):
    frame_b.png   32x32  `create_image_pixflux` "worn hammered antique gold item slot frame": a gold border round a filled black centre.
                         The centre is cleared here (so the item shows through) and everything is snapped to the palette. (frame_a.png, a muddier
                         one from the same prompt, is unused.)
    shimmer.png   atlas of 16 frames of 27x34 + shimmer.json: the VFX tool's `item_glint` part ("Legendary shimmer"), blue-white as exported; its
                  colours are mapped onto the gold ramp here: gold only, never curse green (docs/art_style.md).
"""
import json
from pathlib import Path

from PIL import Image

from artio import save_png
from palette import ART_DIR, PAL

PIECES = Path(__file__).parent / "pieces" / "legend"
FRAME_INSET = 4   # The border is at most this many pixels thick; everything inside it is cleared.
SHIMMER_FPS = 12


def frame():
    img = Image.open(PIECES / "frame_b.png").convert("RGBA")
    px = img.load()
    w, h = img.size
    for y in range(FRAME_INSET, h - FRAME_INSET):
        for x in range(FRAME_INSET, w - FRAME_INSET):
            px[x, y] = (0, 0, 0, 0)
    return PAL.snap(img)


def shimmer_frames():
    atlas = Image.open(PIECES / "shimmer.png").convert("RGBA")
    meta = json.loads((PIECES / "shimmer.json").read_text())
    frames = []
    for f in meta["frames"]:
        r = f["frame"]
        frames.append(atlas.crop((r["x"], r["y"], r["x"] + r["w"], r["y"] + r["h"])))
    return frames


def _gold(rgb):
    """The glint's pale blue-white onto the gold ramp by lightness: torch_300 for the bright core, torch_500 and torch_700 for its edge."""
    lum = 0.299 * rgb[0] + 0.587 * rgb[1] + 0.114 * rgb[2]
    return PAL["torch_300"] if lum > 175 else PAL["torch_500"] if lum > 100 else PAL["torch_700"]


def shimmer_sheet():
    frames = shimmer_frames()
    w, h = frames[0].size
    sheet = Image.new("RGBA", (w * len(frames), h), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        px = f.load()
        for y in range(f.height):
            for x in range(f.width):
                r, g, b, a = px[x, y]
                if a:
                    px[x, y] = (*_gold((r, g, b)), 255)
        sheet.paste(f, (i * w, 0))
    return PAL.snap(sheet), len(frames), w, h


def build(scale=None):
    written = [save_png(frame(), "ui/legend_frame.png")]
    sheet, n, w, h = shimmer_sheet()
    written.append(save_png(sheet, "ui/legend_shimmer_sheet.png"))
    info = ART_DIR / "ui" / "legend_shimmer_sheet.json"
    info.write_text(json.dumps({"frames": n, "fps": SHIMMER_FPS, "frame_w": w, "frame_h": h}, indent=2))
    written.append(info)
    return written


if __name__ == "__main__":
    for p in build():
        print(p)
