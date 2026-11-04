"""Saving art into the Godot project (res://art/...) and keeping imports crisp.

    save_png(img, "tiles/wall.png")        # -> <project>/art/tiles/wall.png
"""
import re

from palette import ART_DIR, PAL

# Godot import settings every pixel-art PNG should have: no mipmaps, no 3D auto-detect,
# lossless. (The editor creates a .import file with defaults the first time it sees a PNG.)
CRISP = {"mipmaps/generate": "false", "detect_3d/compress_to": "0", "compress/mode": "0"}


def save_png(img, rel_path, check=True, root=None):
    """Save an image under res://art/<rel_path>, creating folders as needed. Raises if
    any opaque pixel is off-palette (pass check=False only for deliberate exceptions).
    `root` overrides the art folder (used by tests)."""
    dest = (root or ART_DIR) / rel_path
    if check:
        PAL.check(img, str(rel_path))
    dest.parent.mkdir(parents=True, exist_ok=True)
    img.save(dest)
    return dest


def patch_imports(root=None):
    """Set the crisp import options in every .import file under res://art/. Returns the
    list of files that changed. Run again after Godot imports new PNGs."""
    changed = []
    for path in sorted((root or ART_DIR).rglob("*.png.import")):
        text = path.read_text()
        new = text
        for key, value in CRISP.items():
            new = re.sub(rf"^{re.escape(key)}=.*$", f"{key}={value}", new, flags=re.M)
        if new != text:
            path.write_text(new)
            changed.append(path)
    return changed
