"""The map's torchlight flicker: art/ui/map/torchlight_sheet.png, a 4x3 grid of 12 frames of 104x80 (10 fps, loops).
Made with PixelLab's VFX suite (vfx_workbench, effect "eye-of-bell-map-torchlight", two warm pools of light that swell and
drift); the export is tools/art/pieces/map/torch_flicker.png. scripts/minimap.gd lays it over the parchment with additive
blending at a low strength, so it only warms the paper a little. This just snaps the colours to the palette.
"""
from pathlib import Path

from PIL import Image

from artio import save_png
from palette import PAL

PIECE = Path(__file__).parent / "pieces" / "map" / "torch_flicker.png"


def build():
    return [save_png(PAL.snap(Image.open(PIECE).convert("RGBA")), "ui/map/torchlight_sheet.png")]


if __name__ == "__main__":
    for p in build():
        print(p)
