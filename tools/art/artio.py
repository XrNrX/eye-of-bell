"""Saving art into the Godot project (res://art/...) and keeping imports crisp.

    save_png(img, "tiles/wall.png")        # -> <project>/art/tiles/wall.png
    save_frames(images, order, animations, "slime")   # frames + sheet + JSON
"""
import json
import re
from pathlib import Path

from PIL import Image

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


def save_frames(images, order, animations, name, out_dir=None):
    """Save an animation set: one PNG per frame, a single-row sprite sheet and a JSON
    file with the frame rectangles and animation groups.

    images:     {frame_name: RGBA image}, all the same size
    order:      frame names, in sheet order
    animations: {"idle": ["idle_0", ...], ...}
    Goes to res://art/monsters/<name>/ unless out_dir is given. Returns the files written."""
    root, sub = (Path(out_dir), "") if out_dir else (None, f"monsters/{name}/")
    fw, fh = images[order[0]].size
    sheet = Image.new("RGBA", (fw * len(order), fh), (0, 0, 0, 0))
    rects, written = {}, []
    for i, frame in enumerate(order):
        written.append(save_png(images[frame], f"{sub}{frame}.png", root=root))
        sheet.paste(images[frame], (i * fw, 0))
        rects[frame] = {"x": i * fw, "y": 0, "w": fw, "h": fh}
    written.append(save_png(sheet, f"{sub}{name}_sheet.png", root=root))
    json_path = (root or ART_DIR) / sub / f"{name}_sheet.json"
    json_path.write_text(json.dumps({"frame_size": [fw, fh], "frames": rects, "animations": animations}, indent=2))
    written.append(json_path)
    return written


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
