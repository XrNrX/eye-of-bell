"""Saving art into the Godot project (res://art/...) and keeping imports crisp.

    save_png(img, "tiles/wall.png")        # -> <project>/art/tiles/wall.png
    save_png(img, "ui/frame.png", scale=2) # enlarged 2x first (each pixel becomes a 2x2 block)
    save_frames(images, order, animations, "slime")   # frames + sheet + JSON
"""
import json
import os
import re
from pathlib import Path

from PIL import Image

from palette import ART_DIR, PAL

# Godot import settings every pixel-art PNG should have: no mipmaps, no 3D auto-detect,
# lossless. (The editor creates a .import file with defaults the first time it sees a PNG.)
CRISP = {"mipmaps/generate": "false", "detect_3d/compress_to": "0", "compress/mode": "0"}


# Art that tools/art/import_pixellab.py has replaced (hand-made or PixelLab, not procedural) is
# listed in tools/art/imported.json. The generators must not overwrite it, so save_png skips those
# files (and says so). Set ART_OVERWRITE_IMPORTED=1, or pass `build_all.py --overwrite-imported`,
# to regenerate them anyway; `import_pixellab.py --restore` brings the procedural version back.
IMPORTED_MANIFEST = Path(__file__).resolve().parent / "imported.json"


def imported_paths():
    """Set of art-relative paths (forward slashes) that were imported, per imported.json."""
    try:
        return set(json.loads(IMPORTED_MANIFEST.read_text()).get("files", {}))
    except (OSError, ValueError):
        return set()


def is_protected(rel_path, root=None):
    """True if this file is imported art the generators must leave alone. Only ever true for the
    real art folder (a `root` override, used by tests, is never protected)."""
    if root is not None or os.environ.get("ART_OVERWRITE_IMPORTED"):
        return False
    return str(rel_path).replace("\\", "/") in imported_paths()


def world_scale():
    """How many times larger the 3D art (wall, floor, ceiling and door tiles, monster frames) is
    drawn than its logical grid: 2 now (tiles 128x128, monsters 96x128 / 96x96). Set with
    --world-scale on build_all.py or a generator, or the ART_WORLD_SCALE environment variable.
    Separate from the UI `scale` (the HUD's 2x logical pixels). Enlargement is nearest-neighbour:
    the procedural art keeps its look and gains resolution, which PixelLab art then fills with detail."""
    return max(1, int(os.environ.get("ART_WORLD_SCALE", "2")))


def save_png(img, rel_path, check=True, root=None, scale=1):
    """Save an image under res://art/<rel_path>, creating folders as needed. Raises if
    any opaque pixel is off-palette (pass check=False only for deliberate exceptions).
    `root` overrides the art folder (used by tests). `scale` enlarges the image by that
    whole number first, nearest-neighbour, so the art is drawn once on a small logical grid
    and every logical pixel becomes a scale x scale block (UI art uses 2: the same pixel
    size as the 3D view, which is rendered small and shown at 2x)."""
    dest = (root or ART_DIR) / rel_path
    if is_protected(rel_path, root):
        print(f"    kept imported art: {rel_path}")
        return dest
    if scale != 1:
        img = img.resize((img.width * scale, img.height * scale), Image.NEAREST)
    if check:
        PAL.check(img, str(rel_path))
    dest.parent.mkdir(parents=True, exist_ok=True)
    img.save(dest)
    return dest


def save_frames(images, order, animations, name, out_dir=None, scale=None):
    """Save an animation set: one PNG per frame, a single-row sprite sheet and a JSON
    file with the frame rectangles and animation groups.

    images:     {frame_name: RGBA image}, all the same size
    order:      frame names, in sheet order
    animations: {"idle": ["idle_0", ...], ...}
    Goes to res://art/monsters/<name>/ unless out_dir is given. Returns the files written."""
    root, sub = (Path(out_dir), "") if out_dir else (None, f"monsters/{name}/")
    scale = world_scale() if scale is None else scale
    if scale != 1:
        images = {k: v.resize((v.width * scale, v.height * scale), Image.NEAREST) for k, v in images.items()}
    fw, fh = images[order[0]].size
    sheet = Image.new("RGBA", (fw * len(order), fh), (0, 0, 0, 0))
    rects, written = {}, []
    for i, frame in enumerate(order):
        written.append(save_png(images[frame], f"{sub}{frame}.png", root=root))
        sheet.paste(images[frame], (i * fw, 0))
        rects[frame] = {"x": i * fw, "y": 0, "w": fw, "h": fh}
    written.append(save_png(sheet, f"{sub}{name}_sheet.png", root=root))
    json_path = (root or ART_DIR) / sub / f"{name}_sheet.json"
    if not is_protected(f"{sub}{name}_sheet.png", root):  # Imported sheet: its json describes the imported art.
        json_path.write_text(json.dumps({"frame_size": [fw, fh], "frames": rects, "animations": animations}, indent=2))
    written.append(json_path)
    return written


def save_sheet_info(rel_png, frame_size, frames, count_free, root=None):
    """Write <name>_sheet.json beside a one-row sprite sheet (art/sprites/torch.png ->
    torch_sheet.json): the size of one frame and how many there are. The importer reads these to
    know what a replacement sheet must look like; count_free says whether the game copes with a
    different number of frames (the torch does, it reads the count from the sheet)."""
    rel_json = str(rel_png).rsplit(".", 1)[0] + "_sheet.json"
    dest = (root or ART_DIR) / rel_json
    if is_protected(rel_png, root):
        return dest
    dest.write_text(json.dumps({"frame_size": list(frame_size), "frames": frames, "count_free": count_free}, indent=2))
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
