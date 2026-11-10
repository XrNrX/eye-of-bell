"""Normal maps for the 3D surfaces: art/normals/<folder>/<name>_n.png for every wall, floor, ceiling, door and decal texture.

Derived from each picture's own brightness (bright = raised), so mortar lines, cracks and chips catch torch and spell light
at a slant instead of the light only tinting a flat picture. Pixel art is noisy, so the height map is blurred first (a Gaussian,
`--blur`, in pixels; tiles wrap round their edges so the seams do not show) and only then differentiated (central differences):
a single dithered pixel then makes a soft ripple, not a speckle. `--strength` is how steep the slopes are in the picture.
The strength the game uses on top is adjustable at run time: data/wall_decor.tres, group "Normal maps" (`normal_strength`).

OpenGL convention (Godot's): red right, green up (the image's top), blue out. Decals (cut-outs) keep their alpha: the height
outside the shape is 0, so the edge of a decal rises off the wall a little.

    python tools/art/gen_normal_maps.py                 # all of them
    python tools/art/gen_normal_maps.py --blur 1.4 --strength 2.5
    python tools/art/gen_normal_maps.py --only wall     # names containing "wall"

The generator for the textures themselves (gen_tiles.py, gen_wall_decor.py) is untouched: run this after them.
"""
import argparse
from pathlib import Path

import numpy as np
from PIL import Image

from palette import ART_DIR

# folder -> (wrap at the edges, strength multiplier): tiles repeat, decals are single pictures. Overlays that are only a dithered
# dusting (grime) or a glowing vein have no stone relief, so they get none.
FOLDERS = {"tiles": (True, 1.0), "decals": (False, 0.8)}
SKIP = {"portcullis", "grime", "vein_1", "vein_2", "vein_3"}  # (The portcullis is a see-through grate; keep it flat.)


def gaussian_kernel(sigma):
    if sigma <= 0:
        return np.array([1.0])
    radius = max(1, int(round(sigma * 3)))
    x = np.arange(-radius, radius + 1)
    k = np.exp(-(x * x) / (2.0 * sigma * sigma))
    return k / k.sum()


def blur(a, sigma, wrap):
    k = gaussian_kernel(sigma)
    r = len(k) // 2
    if r == 0:
        return a
    mode = "wrap" if wrap else "edge"
    p = np.pad(a, ((0, 0), (r, r)), mode=mode)
    a = sum(k[i] * p[:, i:i + a.shape[1]] for i in range(len(k)))
    p = np.pad(a, ((r, r), (0, 0)), mode=mode)
    return sum(k[i] * p[i:i + a.shape[0], :] for i in range(len(k)))


def height_map(img):
    """Brightness 0..1, weighted by alpha so transparent pixels are flat (0)."""
    a = np.asarray(img.convert("RGBA"), dtype=np.float64) / 255.0
    lum = 0.299 * a[..., 0] + 0.587 * a[..., 1] + 0.114 * a[..., 2]
    return lum * a[..., 3], a[..., 3]


def normal_map(img, sigma, strength, wrap):
    h, alpha = height_map(img)
    h = blur(h, sigma, wrap)
    h = h - h.mean() if wrap else h
    mode = "wrap" if wrap else "edge"
    p = np.pad(h, 1, mode=mode)
    dx = (p[1:-1, 2:] - p[1:-1, :-2]) * 0.5
    dy = (p[2:, 1:-1] - p[:-2, 1:-1]) * 0.5  # Down the image.
    nx = -dx * strength
    ny = dy * strength  # Green is up the image, and a height that falls down the image faces down.
    nz = np.ones_like(nx)
    length = np.sqrt(nx * nx + ny * ny + nz * nz)
    n = np.stack([nx / length, ny / length, nz / length], axis=-1)
    rgb = ((n * 0.5 + 0.5) * 255.0 + 0.5).astype(np.uint8)
    out = np.dstack([rgb, np.full(rgb.shape[:2], 255, np.uint8)])
    return Image.fromarray(out, "RGBA")


def build(blur_sigma=1.2, strength=3.0, only=""):
    written = []
    for folder, (wrap, mult) in FOLDERS.items():
        src = ART_DIR / folder
        dst = ART_DIR / "normals" / folder
        dst.mkdir(parents=True, exist_ok=True)
        for path in sorted(src.glob("*.png")):
            if path.stem in SKIP or (only and only not in path.stem):
                continue
            img = Image.open(path)
            out = normal_map(img, blur_sigma, strength * mult, wrap)
            target = dst / f"{path.stem}_n.png"
            out.save(target)
            written.append(target)
    return written


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--blur", type=float, default=1.2, help="Gaussian sigma of the height map, in pixels")
    ap.add_argument("--strength", type=float, default=3.0, help="slope steepness baked into the picture")
    ap.add_argument("--only", default="", help="only textures whose name contains this")
    args = ap.parse_args()
    for p in build(args.blur, args.strength, args.only):
        print(p)
