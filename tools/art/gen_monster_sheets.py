"""Builds a monster's sprite sheet from PixelLab animation grids (the Creator's per-animation exports).

Pieces live in tools/art/pieces/monsters/<monster>/<anim>.png: a grid of frames, row by row, left to right, each cell the
monster's frame size (96x96 slimes, 96x128 skeletons); the SPECS table says how many frames each holds. Every pixel is snapped to
palette.json, the frames are joined into one row, art/monsters/<monster>/<monster>_sheet.png (+ .json), and the frame lists
(hframes, idle/attack/hurt/walk frames and their fps) are written into data/monsters/<monster>.tres.

    python tools/art/gen_monster_sheets.py slime_acid [--no-snap]
"""
import json
import re
import sys
from pathlib import Path

from PIL import Image

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent.parent
sys.path.insert(0, str(HERE))
from palette import Palette  # noqa: E402

# monster -> frame size, then per animation (frames in the grid, and the .tres lines to write).
SPECS = {
    "slime_acid": {
        "size": (96, 96),
        "anims": [("idle", 5), ("attack", 9), ("hurt", 5), ("walk", 9)],
        "idle_order": [0, 1, 2, 3, 4, 3, 2, 1],
        "fps": {"idle_fps": 5.0, "attack_fps": 14.0, "hurt_fps": 14.0, "walk_fps": 22.0},
    },
}


def cut(path, size, count):
    img = Image.open(path).convert("RGBA")
    cols = img.width // size[0]
    return [img.crop(((i % cols) * size[0], (i // cols) * size[1], (i % cols + 1) * size[0], (i // cols + 1) * size[1]))
            for i in range(count)]


def build(name, snap=True):
    spec = SPECS[name]
    w, h = spec["size"]
    pal = Palette.load()
    frames, starts, names = [], {}, {}
    for anim, count in spec["anims"]:
        starts[anim] = len(frames)
        for i, f in enumerate(cut(HERE / "pieces" / "monsters" / name / f"{anim}.png", spec["size"], count)):
            frames.append(pal.snap(f) if snap else f)
            names[f"{anim}_{i}"] = len(frames) - 1
    sheet = Image.new("RGBA", (w * len(frames), h), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        sheet.paste(f, (i * w, 0))
    out = ROOT / "art" / "monsters" / name
    out.mkdir(parents=True, exist_ok=True)
    sheet.save(out / f"{name}_sheet.png")
    info = {"frame_size": [w, h],
            "frames": {k: {"x": v * w, "y": 0, "w": w, "h": h} for k, v in names.items()},
            "animations": {a: [f"{a}_{i}" for i in range(c)] for a, c in spec["anims"]}}
    (out / f"{name}_sheet.json").write_text(json.dumps(info))
    patch_tres(name, spec, starts, len(frames))
    print(name, len(frames), "frames", sheet.size)


def patch_tres(name, spec, starts, total):
    path = ROOT / "data" / "monsters" / f"{name}.tres"
    text = path.read_text(encoding="utf-8")
    counts = dict(spec["anims"])

    def arr(values):
        return "PackedInt32Array(%s)" % ", ".join(str(v) for v in values)
    fields = {
        "hframes": str(total),
        "idle_frames": arr([starts["idle"] + i for i in spec.get("idle_order", range(counts["idle"]))]),
        "attack_frames": arr([starts["attack"] + i for i in range(counts["attack"])]),
        "hurt_frames": arr([starts["hurt"] + i for i in range(counts["hurt"])]),
        "walk_frames": arr([starts["walk"] + i for i in range(counts["walk"])]),
    }
    fields.update({k: str(v) for k, v in spec["fps"].items()})
    for key, value in fields.items():
        if re.search(rf"^{key} = ", text, re.M):
            text = re.sub(rf"^{key} = .*$", f"{key} = {value}", text, flags=re.M)
        else:
            text = text.replace("\npixel_size", f"\n{key} = {value}\npixel_size", 1)
    path.write_text(text, encoding="utf-8")


if __name__ == "__main__":
    for n in [a for a in sys.argv[1:] if not a.startswith("--")] or SPECS:
        build(n, snap="--no-snap" not in sys.argv)
