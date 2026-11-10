"""Builds a monster's hires sprite sheet (the hires-720 branch) from per-frame PixelLab exports.

Pieces live in tools/art/pieces/monsters_hd/<monster>/<anim>_<i>.png (idle, attack, hurt, walk; one 256x256 frame per file, or 192x192 for
the slimes). Every pixel is snapped to palette.json, the frames are joined into one row, art/monsters/<monster>/<monster>_sheet.png (+ .json),
and hframes, the frame lists, the fps and `pixel_size` are written into data/monsters/<monster>.tres. `pixel_size` is chosen so the figure
keeps the world height of the old 96x128 art (WORLD_HEIGHT below, measured from the old sheets): the monster is as tall as before and
has about twice the pixels.

    python tools/art/gen_monster_sheets_hd.py skeleton
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

ANIMS = ["idle", "attack", "hurt", "walk"]

# Height in world units of each monster's standing figure (old bbox height x old pixel_size): what the new pixel_size preserves.
SPECS = {
    "skeleton": {"world_height": 1.484, "fps": {"idle_fps": 5.0, "attack_fps": 10.0, "hurt_fps": 12.0, "walk_fps": 18.0}},
    "skeleton_guard": {"world_height": 1.68, "fps": {"idle_fps": 5.0, "attack_fps": 12.0, "hurt_fps": 12.0, "walk_fps": 18.0}},
    "slime": {"world_height": 1.42, "fps": {"idle_fps": 8.0, "attack_fps": 14.0, "hurt_fps": 14.0, "walk_fps": 16.0}},
    "slime_acid": {"world_height": 1.70, "fps": {"idle_fps": 8.0, "attack_fps": 14.0, "hurt_fps": 14.0, "walk_fps": 16.0}},
}


def load_frames(name, anim):
    folder = HERE / "pieces" / "monsters_hd" / name
    files = sorted(folder.glob(f"{anim}_*.png"), key=lambda p: int(p.stem.split("_")[1]))
    return [Image.open(p).convert("RGBA") for p in files]


def build(name, snap=True):
    spec = SPECS[name]
    pal = Palette.load()
    frames, starts, counts = [], {}, {}
    for anim in ANIMS:
        fs = load_frames(name, anim)
        starts[anim], counts[anim] = len(frames), len(fs)
        frames += [pal.snap(f) if snap else f for f in fs]
    w = max(f.width for f in frames)
    h = max(f.height for f in frames)
    sheet = Image.new("RGBA", (w * len(frames), h), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        sheet.paste(f, (i * w + (w - f.width) // 2, h - f.height))
    out = ROOT / "art" / "monsters" / name
    out.mkdir(parents=True, exist_ok=True)
    sheet.save(out / f"{name}_sheet.png")
    names = {}
    for anim in ANIMS:
        for i in range(counts[anim]):
            names[f"{anim}_{i}"] = starts[anim] + i
    info = {"frame_size": [w, h],
            "frames": {k: {"x": v * w, "y": 0, "w": w, "h": h} for k, v in names.items()},
            "animations": {a: [f"{a}_{i}" for i in range(counts[a])] for a in ANIMS}}
    (out / f"{name}_sheet.json").write_text(json.dumps(info))
    idle = frames[starts["idle"]:starts["idle"] + counts["idle"]]
    heights = [f.getchannel("A").getbbox()[3] - f.getchannel("A").getbbox()[1] for f in idle]
    pixel_size = spec["world_height"] / (sum(heights) / len(heights))
    patch_tres(name, spec, starts, counts, len(frames), pixel_size)
    print(name, len(frames), "frames", sheet.size, "pixel_size %.5f" % pixel_size)


def patch_tres(name, spec, starts, counts, total, pixel_size):
    path = ROOT / "data" / "monsters" / f"{name}.tres"
    text = path.read_text(encoding="utf-8")

    def arr(values):
        return "PackedInt32Array(%s)" % ", ".join(str(v) for v in values)
    n = counts["idle"]
    idle_order = list(range(n)) + list(range(n - 2, 0, -1))  # Forward, then back: a loop with no jump.
    fields = {
        "hframes": str(total),
        "idle_frames": arr([starts["idle"] + i for i in idle_order]),
        "attack_frames": arr([starts["attack"] + i for i in range(counts["attack"])]),
        "hurt_frames": arr([starts["hurt"] + i for i in range(counts["hurt"])]),
        "walk_frames": arr([starts["walk"] + i for i in range(counts["walk"])]),
        "pixel_size": "%.5f" % pixel_size,
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
