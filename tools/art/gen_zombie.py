"""The zombie's sheet: PixelLab's own animation of the styled picture (tools/art/pieces/zombie_styled.png, made with
`create_image_pro_from_style` in the style of the user's gallery spider), four clips from `animate_image_pixminimax` (1 generation
each) kept at their native 256x256 in pieces/monsters_hd/zombie_256/: idle 5 frames (the input and four), attack 9, hurt 5, walk 8
(the walk clip's last frame is the input again, so it is dropped to make a loop).

The pictures are painted, with no outline, so (unlike the skeletons) there is nothing to snap to an outline and no outline pass.

    python tools/art/gen_zombie.py            # writes pieces/monsters_hd/zombie/ and builds the sheet
    python tools/art/gen_zombie.py 256        # keep the native 256 pixels (a second, denser look)

SIZE 128 (the default) halves each frame (LANCZOS, then the sheet builder snaps to the palette), which puts the rat at about the pixel
density of the other monsters; 256 leaves it twice as fine as they are.
"""
import shutil
import subprocess
import sys
from pathlib import Path

from PIL import Image

HERE = Path(__file__).resolve().parent
LIFT = 1.15  # Brightness gain before the palette snap (the painted rags are near black; docs/art_style.md: dark is not invisible).
SRC = HERE / "pieces" / "monsters_hd" / "zombie_256"
OUT = HERE / "pieces" / "monsters_hd" / "zombie"


def prepare(size=128):
    if OUT.exists():
        shutil.rmtree(OUT)
    OUT.mkdir(parents=True)
    for f in sorted(SRC.glob("*.png")):
        im = Image.open(f).convert("RGBA")
        if LIFT != 1.0:
            r, g, b, a = im.split()
            im = Image.merge("RGBA", [c.point(lambda v: min(255, int(v * LIFT))) for c in (r, g, b)] + [a])
        if size != 256:
            a = im.getchannel("A").resize((size, size), Image.LANCZOS).point(lambda v: 255 if v > 110 else 0)
            im = im.resize((size, size), Image.LANCZOS)
            im.putalpha(a)
        im.save(OUT / f.name)


if __name__ == "__main__":
    size = int(sys.argv[1]) if len(sys.argv) > 1 else 128
    prepare(size)
    subprocess.run([sys.executable, str(HERE / "gen_monster_sheets_hd.py"), "zombie"], check=True)
