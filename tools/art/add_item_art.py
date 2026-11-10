"""Install the art for a NEW item made in PixelLab (no placeholder to replace, so the importer has nothing to size against).

    python tools/art/add_item_art.py long_sword --steel

If there is no 48x48 piece, the 32x32 one is also used for the inventory icon and the floor sprite, centred on a transparent 48x48
canvas (not scaled: one art pixel stays one screen pixel, the item is just drawn smaller). The flail was made this way.

`--steel` puts plain steel's curse greens back to grey on the hand icon too (regrade_items.py does it for the 48x48 ones, but leaves the
native 32x32 hand icons alone, so it has to happen here).

Reads tools/art/pieces/items48/<name>.png (the 48x48 inventory icon, also used as the floor sprite: the same drawing) and
tools/art/pieces/items32/<name>.png (the native 32x32 hand / quick-slot icon), snaps both to the palette (nearest, like the importer)
and writes art/items/<name>.png, <name>_floor.png and <name>_hud.png. Then add the name to REMAPS / NATIVE32 (and LIFT_FLOOR if it
is hard to see on the floor) in regrade_items.py and run that: it takes the green off plain steel and adds the ink outline.
Delete the item's copies in pieces/regrade_src/items/ first if you are redoing one.
"""
import sys
from pathlib import Path

from PIL import Image

from palette import ART_DIR, PAL
from regrade_items import PLAIN_STEEL, REMAPS, remap

PIECES = Path(__file__).parent / "pieces"


def install(name, steel=False):
    written = []
    big = PIECES / "items48" / f"{name}.png"
    for src, dst, size in ((big if big.exists() else PIECES / "items32" / f"{name}.png", [f"{name}.png", f"{name}_floor.png"], 48),
                           (PIECES / "items32" / f"{name}.png", [f"{name}_hud.png"], 32)):
        img = Image.open(src).convert("RGBA")
        if size == 48 and img.size == (32, 32):  # Padded, not scaled.
            padded = Image.new("RGBA", (48, 48), (0, 0, 0, 0))
            padded.paste(img, (8, 8))
            img = padded
        if img.size != (size, size):
            raise SystemExit(f"{src} is {img.size}, expected {size}x{size}")
        snapped = PAL.snap(img)
        if steel and size == 32:
            remap(snapped, REMAPS.get(name, PLAIN_STEEL))
        for d in dst:
            target = ART_DIR / "items" / d
            snapped.save(target)
            written.append(target)
    return written


if __name__ == "__main__":
    for p in install(sys.argv[1], "--steel" in sys.argv):
        print(p)
