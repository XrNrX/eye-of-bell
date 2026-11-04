"""Self-test for the art toolkit:   python tools/art/test_toolkit.py
Writes only to a temporary folder."""
import sys
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from PIL import Image  # noqa: E402

from artio import CRISP, patch_imports, save_png  # noqa: E402
from dither import dither_ramp, dither_two  # noqa: E402
from lighting import lit_values, shade_mask  # noqa: E402
from noise import remap, value_noise, white_noise  # noqa: E402
from outline import add_outline  # noqa: E402
from palette import PAL  # noqa: E402

failed = 0


def colours(img):
    """Opaque RGB values in an image, one per pixel."""
    px = img.convert("RGBA").load()
    return [px[x, y][:3] for y in range(img.height) for x in range(img.width) if px[x, y][3]]


def check(name, cond):
    global failed
    print(("PASS  " if cond else "FAIL  ") + name)
    failed += 0 if cond else 1


# Palette
check("palette has 24 distinct colours", len(PAL) == 24 and len(PAL.allowed) == 24)
check("every ramp colour exists", all(c in PAL.allowed for r in ("stone", "wood", "rust", "moss", "bone", "torch") for c in PAL.ramp(r)))
check("nearest snaps to a palette colour", PAL.nearest((100, 100, 110)) in PAL.allowed)
off = Image.new("RGBA", (2, 1), (*PAL["ink"], 255))
off.putpixel((1, 0), (1, 2, 3, 255))
check("off-palette pixel is detected", PAL.off_palette(off) == {(1, 2, 3)})
check("transparent pixels are ignored", PAL.off_palette(Image.new("RGBA", (4, 4), (9, 9, 9, 0))) == set())
check("snap fixes an off-palette image", not PAL.off_palette(PAL.snap(off)))

# Noise
a, b = value_noise(64, 64, 16, seed=5, octaves=2), value_noise(64, 64, 16, seed=5, octaves=2)
check("noise is deterministic", a == b)
check("different seeds differ", a != value_noise(64, 64, 16, seed=6, octaves=2))
flat = [v for r in a for v in r]
check("noise stays in 0..1", min(flat) >= 0 and max(flat) <= 1)
seam = max(abs(a[y][0] - a[y][63]) for y in range(64))
inner = max(abs(a[y][31] - a[y][32]) for y in range(64))
check("noise tiles seamlessly (edge step like an inner step)", seam <= inner * 1.5 + 0.02)
check("white noise is deterministic", white_noise(8, 8, 1) == white_noise(8, 8, 1))

# Dithering
vals = [[x / 63 for x in range(64)] for _ in range(8)]
two = dither_two(vals, PAL["stone_700"], PAL["stone_300"])
cols = set(colours(two))
check("dither_two uses exactly the two colours", cols == {PAL["stone_700"], PAL["stone_300"]})
for mode in ("bayer", "checker", "random"):
    img = dither_ramp(vals, PAL.ramp("stone"), mode=mode, seed=2)
    check(f"dither_ramp '{mode}' stays on the ramp", set(colours(img)) <= set(PAL.ramp("stone")))

# Lighting
hill = [[max(0.0, 1 - (((x - 16) ** 2 + (y - 16) ** 2) ** 0.5) / 14) for x in range(32)] for y in range(32)]
lit = lit_values(hill, strength=4.0)
check("top-left of a hill is brighter than bottom-right", lit[10][10] > 0.5 > lit[22][22])
mask = {(x, y) for x in range(8) for y in range(8)}
shaded = shade_mask(mask, PAL.ramp("bone"))
check("shade_mask: top-left light, bottom-right dark", shaded[(0, 0)] == PAL.ramp("bone")[-1] and shaded[(7, 7)] == PAL.ramp("bone")[0])

# Outline
sprite = Image.new("RGBA", (4, 4), (0, 0, 0, 0))
for x in range(1, 3):
    for y in range(1, 3):
        sprite.putpixel((x, y), (*PAL["bone_500"], 255))
out = add_outline(sprite, PAL["ink"], pad=1)
check("outline grows the canvas by the pad", out.size == (6, 6))
check("outline ring is 8 pixels for a 2x2 block (4-neighbour)", colours(out).count(PAL["ink"]) == 8)
check("outline diagonals add the corners", colours(add_outline(sprite, PAL["ink"], True, 1)).count(PAL["ink"]) == 12)

# Whole pipeline: noise -> light -> dither -> outline -> save
heights = value_noise(64, 64, 16, seed=9, octaves=3)
tex = dither_ramp(lit_values(remap(heights), strength=3.0), PAL.ramp("stone"))
with tempfile.TemporaryDirectory() as tmp:
    root = Path(tmp)
    path = save_png(add_outline(tex, PAL["ink"], pad=1), "tiles/test.png", root=root)
    check("save_png writes into the art folder structure", path == root / "tiles" / "test.png" and path.exists())
    try:
        save_png(off, "tiles/bad.png", root=root)
        check("save_png rejects off-palette images", False)
    except ValueError:
        check("save_png rejects off-palette images", not (root / "tiles" / "bad.png").exists())
    imp = root / "tiles" / "test.png.import"
    imp.write_text("[params]\ncompress/mode=2\nmipmaps/generate=true\ndetect_3d/compress_to=1\n")
    check("patch_imports rewrites import settings", len(patch_imports(root)) == 1
          and all(f"{k}={v}" in imp.read_text() for k, v in CRISP.items()))

print("\nAll good." if not failed else f"\n{failed} check(s) failed.")
sys.exit(1 if failed else 0)
