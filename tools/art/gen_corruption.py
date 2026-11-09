"""The corrupted wall's art, written to res://art/:

    tiles/wall_corrupted.png      128x128, the wall's own texture (a PixelLab image, routed through import_pixellab.py;
                                  this file only writes a dark placeholder so the importer has a size to match)
    corruption/veins_sheet.png    the pulsing green curse veins, a looping row of frames (+ .json {frames, fps, ...})
    corruption/purge_sheet.png    the gold holy light that burns the veins away from the centre outward (one-shot)
    corruption/ash_sheet.png      the wall crumbling to ash and dust (one-shot)

The three animations were made with PixelLab's effects tool (vfx_workbench) and exported as atlases; the source pieces are
in tools/art/pieces/corruption/ (<name>.png + <name>.json, as exported; docs/asset_log.md has the details). Like the spell
flipbooks (gen_spell_fx.py) they are sliced along their JSON, trailing blank frames dropped, snapped to the palette and
written as one row at full resolution. Each frame covers one whole wall face (128x128).
"""
import json
from pathlib import Path

from PIL import Image

from artio import save_png
from palette import ART_DIR, PAL

PIECES = Path(__file__).parent / "pieces" / "corruption"
SHEETS = ("veins", "purge", "ash")


def slice_atlas(name):
    atlas = Image.open(PIECES / f"{name}.png").convert("RGBA")
    meta = json.loads((PIECES / f"{name}.json").read_text())
    frames, durations = [], []
    for f in meta["frames"]:
        r = f["frame"]
        frames.append(atlas.crop((r["x"], r["y"], r["x"] + r["w"], r["y"] + r["h"])))
        durations.append(f.get("duration", 83))
    while len(frames) > 1 and frames[-1].getchannel("A").getbbox() is None:
        frames.pop()
        durations.pop()
    return frames, round(1000.0 / (sum(durations) / len(durations)), 2)


def no_purple(img):
    """The palette snap sends some blended mid-greys of the translucent dust to bruise purple (violet is the nearest palette
    colour to a cold grey). These effects have no purple in them, so each bruise colour goes to the grey of its brightness."""
    swap = {tuple(PAL[b]): tuple(PAL[g]) for b, g in (("bruise_900", "stone_900"), ("bruise_700", "stone_700"), ("bruise_500", "stone_500"))}
    px = img.load()
    for y in range(img.height):
        for x in range(img.width):
            r, g, b, a = px[x, y]
            if a and (r, g, b) in swap:
                px[x, y] = (*swap[(r, g, b)], a)
    return img


def build_sheet(name):
    frames, fps = slice_atlas(name)
    w, h = frames[0].size
    sheet = Image.new("RGBA", (w * len(frames), h), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        sheet.paste(f, (i * w, 0))
    written = [save_png(no_purple(PAL.snap(sheet)), f"corruption/{name}_sheet.png")]
    path = ART_DIR / "corruption" / f"{name}_sheet.json"
    path.write_text(json.dumps({"frames": len(frames), "fps": fps, "frame_w": w, "frame_h": h}, indent=2))
    return written + [path]


def placeholder_wall():
    """A dark stone square: only for sizing. The real texture is the PixelLab one."""
    return Image.new("RGBA", (128, 128), (*PAL["stone_900"], 255))


def build(scale=None):
    written = [save_png(placeholder_wall(), "tiles/wall_corrupted.png", scale=1)]
    (ART_DIR / "corruption").mkdir(parents=True, exist_ok=True)
    for name in SHEETS:
        if (PIECES / f"{name}.png").exists():
            written += build_sheet(name)
    return written


if __name__ == "__main__":
    for p in build():
        print(p)
