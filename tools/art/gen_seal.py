"""The curse seal and the reliquary of a purged room (roadmap 7e.2), from the PixelLab pieces in tools/art/pieces/seal/ and
pieces/reliquary/. The VFX tool's exports (<name>.png + .json atlases) become one-row sheets art/seal/<name>_sheet.png with
<name>_sheet.json {frames, fps, frame_w, frame_h}: 'seal' (the eye in a ring, looping, over a sealed door), 'crumble' (it falls
apart), 'mortar' (the glow in a sealed room's joints, and 'mortar_fade', it dissolving) and 'dust' (round the foot of the rising chest). 'chest' is the two
stills, closed then open, both standing on the bottom of the frame. Run: python tools/art/gen_seal.py"""
import json
import os

from PIL import Image

from artio import ART_DIR, save_png
from palette import PAL

HERE = os.path.dirname(os.path.abspath(__file__))
EFFECTS = {"seal": ("seal", "eye"), "crumble": ("seal", "crumble"), "mortar": ("seal", "mortar"), "dust": ("reliquary", "dust")}


def frames(folder, name):
    base = os.path.join(HERE, "pieces", folder, name)
    with open(base + ".json") as f:
        info = json.load(f)
    atlas = Image.open(base + ".png").convert("RGBA")
    entries = info["frames"]
    entries = list(entries.values()) if isinstance(entries, dict) else entries
    out = []
    for e in entries:
        r = e["frame"]
        full = Image.new("RGBA", (e["sourceSize"]["w"], e["sourceSize"]["h"]), (0, 0, 0, 0))
        full.paste(atlas.crop((r["x"], r["y"], r["x"] + r["w"], r["y"] + r["h"])), (e["spriteSourceSize"]["x"], e["spriteSourceSize"]["y"]))
        out.append(PAL.snap(full))
    return out, round(1000.0 / entries[0]["duration"], 2)


def standing(path):
    """A still moved down so its lowest pixel is on the bottom row (it stands on the floor)."""
    img = PAL.snap(Image.open(path).convert("RGBA"))
    box = img.getbbox()
    out = Image.new("RGBA", img.size, (0, 0, 0, 0))
    out.paste(img, (0, img.height - box[3]))
    return out


def dissolve(img, keep):
    """Only `keep` pixels in four, in a Bayer pattern: how the mortar's glow goes out (never a smooth fade)."""
    out = img.copy()
    order = ((0, 2), (3, 1))
    px = out.load()
    for y in range(out.height):
        for x in range(out.width):
            if order[(y // 2) % 2][(x // 2) % 2] >= keep:
                px[x, y] = (0, 0, 0, 0)
    return out


def sheet(name, pictures, fps):
    w, h = pictures[0].size
    row = Image.new("RGBA", (w * len(pictures), h), (0, 0, 0, 0))
    for i, p in enumerate(pictures):
        row.paste(p, (i * w, 0))
    png = save_png(row, "seal/%s_sheet.png" % name)
    meta = ART_DIR / ("seal/%s_sheet.json" % name)
    meta.write_text(json.dumps({"frames": len(pictures), "fps": fps, "frame_w": w, "frame_h": h}, indent=2))
    return [png, meta]


def build():
    written = []
    for name, (folder, piece) in EFFECTS.items():
        pictures, fps = frames(folder, piece)
        written += sheet(name, pictures, fps)
    glow = frames("seal", "mortar")[0][0]
    written += sheet("mortar_fade", [dissolve(glow, keep) for keep in (3, 2, 1)], 3)
    chest = os.path.join(HERE, "pieces", "reliquary")
    written += sheet("chest", [standing(os.path.join(chest, "chest_c.png")), standing(os.path.join(chest, "chest_open.png"))], 1)
    return written


if __name__ == "__main__":
    print("\n".join(str(p) for p in build()))
