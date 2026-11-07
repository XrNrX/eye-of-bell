"""Free touch-ups to imported PixelLab art, no regeneration: run after importing an item or a monster sheet.

    python tools/art/regrade_items.py

- Stale bread and hard cheese: warm colours swapped for duller bone and browns (grim, not cosy).
- Plain weapons: the curse colours the palette snap left on their steel go back to grey (green means magic).
- Every item and monster frame gets the style guide's 1px ink outline.

The untouched images are copied to tools/art/pieces/regrade_src/ the first time and every run starts from those, so it
can be run again safely. An asset imported later replaces its art/ file but not its copy: delete that copy first.
"""
import shutil
from pathlib import Path

from PIL import Image

from outline import add_outline
from palette import PAL

ROOT = Path(__file__).resolve().parents[2]
ART = ROOT / "art"
SRC = Path(__file__).parent / "pieces" / "regrade_src"

GRIM_FOOD = {
    "torch_300": "bone_500", "torch_500": "leather_400", "torch_700": "wood_500",
    "rust_300": "wood_500", "rust_500": "wood_700", "rust_700": "soil_900",
}
GRIM_CHEESE = {
    "torch_300": "bone_500", "torch_500": "bone_700", "torch_700": "leather_400",
    "rust_300": "leather_400", "rust_500": "wood_500", "rust_700": "wood_700",
}
PLAIN_STEEL = {"curse_300": "stone_100", "curse_500": "stone_300", "curse_700": "stone_500"}

REMAPS = {
    "stale_bread": GRIM_FOOD, "hard_cheese": GRIM_CHEESE,
    "short_sword": PLAIN_STEEL, "dagger": PLAIN_STEEL, "mace": PLAIN_STEEL, "war_hammer": PLAIN_STEEL, "darts": PLAIN_STEEL,
}
# The slimes are left out: their current PixelLab art has its own outline (a second ring would double it).
MONSTERS = {"skeleton": 11, "skeleton_guard": 11}
# Hand and quick-slot icons made natively at 32x32 (tools/art/pieces/items32/): already outlined and steel-grey, so left alone.
NATIVE32 = {"short_sword", "war_hammer", "mace", "dagger", "darts"}


def source(rel):
    """The untouched copy of art/<rel>, made the first time."""
    copy = SRC / rel
    if not copy.exists():
        copy.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy(ART / rel, copy)
    return Image.open(copy).convert("RGBA")


def remap(img, mapping):
    table = {PAL[a]: PAL[b] for a, b in mapping.items()}
    px = img.load()
    for y in range(img.height):
        for x in range(img.width):
            r, g, b, a = px[x, y]
            if a and (r, g, b) in table:
                px[x, y] = (*table[(r, g, b)], a)
    return img


def outlined(img):
    return add_outline(img, PAL["ink"])


def build():
    written = []
    for path in sorted((ART / "items").glob("*.png")) + [ART / "sprites" / "key.png"]:
        if path.stem.endswith("_glow"):
            continue
        rel = path.relative_to(ART).as_posix()
        name = path.stem.removesuffix("_floor").removesuffix("_hud")
        if path.stem.endswith("_hud") and name in NATIVE32:
            continue
        img = source(rel)
        if name in REMAPS:
            remap(img, REMAPS[name])
        outlined(img).save(path)
        written.append(rel)
    for name, count in MONSTERS.items():
        for path in sorted((ART / "monsters" / name).glob("*.png")):
            rel = path.relative_to(ART).as_posix()
            img = source(rel)
            if path.stem.endswith("_sheet"):  # Frame by frame, so an outline can't bleed into the next frame.
                w = img.width // count
                out = Image.new("RGBA", img.size)
                for i in range(count):
                    out.paste(outlined(img.crop((i * w, 0, (i + 1) * w, img.height))), (i * w, 0))
                out.save(path)
            else:
                outlined(img).save(path)
            written.append(rel)
    return written


if __name__ == "__main__":
    print(len(build()), "files written")
