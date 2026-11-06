#!/usr/bin/env python3
"""Turn PixelLab (or any other) PNG exports into game art, replacing the procedural versions.

    python tools/art/import_pixellab.py                 # convert everything in tools/art/inbox/
    python tools/art/import_pixellab.py --dry-run       # report only; write and move nothing
    python tools/art/import_pixellab.py --list          # every asset the game expects, and its size
    python tools/art/import_pixellab.py --dither        # allow dithering when snapping colours
    python tools/art/import_pixellab.py --restore tiles/wall      # put the procedural version back
    python tools/art/import_pixellab.py --restore all

WHAT IT DOES TO EACH IMAGE
  1. Alpha: pixels at least half opaque become solid, the rest fully transparent (pixel art has
     no soft edges, and the palette check only knows solid pixels).
  2. Size: nearest-neighbour only, to the size of the art it replaces (read from the files in
     art/ at run time, so it follows whatever the game currently uses). UI art (items, portraits,
     ui/, except the full-resolution title screen ui/title, 640x360 as drawn) is stored at --scale
     (default 2) times its logical size: an export at the logical size is
     enlarged by the scale; one already at the stored size is left alone; any other whole-number
     factor is applied as is; anything else is resized with a warning.
  3. Colour: every pixel snapped to the nearest colour in palette.json. No dithering unless
     --dither (Floyd-Steinberg error diffusion).
  A hero's living portrait also produces its hurt (red-tinted) and dead (grey with a faint curse
  tint) portraits, unless those are supplied too or --no-variants is given.
  4. Name: written to the existing path, so the game needs no change.
  5. Back-up: the file it replaces is copied to tools/art/_old/ (same relative path) the first time
     only, so importing again never overwrites the procedural original. `--restore` undoes it.
  6. Protection: imported files are listed in tools/art/imported.json, and the generators
     (build_all.py) leave them alone; build_all.py --overwrite-imported regenerates them anyway.
  7. The processed files move to inbox/_done/ (--keep-inbox leaves them).

NAMING THE FILES YOU DROP IN THE INBOX
  Anything unique works; --list shows the keys. In order of preference:
    * a path inside the inbox that matches the key:   inbox/tiles/wall.png,
      inbox/portraits/fighter/portrait_hurt.png, inbox/monsters/skeleton/idle_0.png
    * a flat name that is unique:   wall.png, dagger_hud.png, fighter_portrait_dead.png,
      skeleton_idle_0.png, skeleton_sheet.png (or skeleton.png), torch.png
    * an ambiguous name (key.png is both items/key and sprites/key; portrait.png is four) needs a
      prefix or folder: items_key.png, sprites_key.png, fighter_portrait.png
    * anything else: list it in inbox/map.json,  {"my_export_17.png": "tiles/wall"}
  A file that matches nothing, or matches more than one asset, is reported and left in the inbox.

SPRITE SHEETS AND FRAMES
  A monster comes as individual frames (skeleton_idle_0.png ...) and/or one sheet (a single row
  of equal frames, skeleton_sheet.png). A sheet is sliced into frames, each resized to the frame
  size of the art it replaces, given the existing frame names (idle_0, attack_1, hurt_0_flash, ...)
  and written back as the frame PNGs, the sheet and its json. How many frames a sheet holds is a
  guess: the old count if the frames come out about the old shape, otherwise the count that gives
  the closest shape (square frames, or the old proportions); say otherwise with --frames
  skeleton=9, or with a layout file.
  A LAYOUT FILE (inbox/skeleton_sheet.layout.json, or skeleton.layout.json) states the animations:
      {"idle": 4, "attack": 3, "hurt": 2}
  The sheet is then read as 4 + 3 + 2 frames, in that order, named idle_0..3, attack_0..2, hurt_0..1,
  the old frame files that no longer exist are removed, and data/monsters/skeleton.tres is updated
  (hframes, idle_frames, attack_frames, hurt_frames), so extra frames work with no code change.
  Without a layout, a different frame count is reported as a mismatch: the first frames replace the
  old ones in order, extra frames are dropped, missing ones keep the procedural frame.
  The torch sheet may change its frame count freely (the game reads the count from the sheet);
  the lever must stay at exactly two frames (off, on).

REPORT: what was replaced, frame-count mismatches, unmatched and ambiguous files, new back-ups.
Exit status 1 if anything could not be converted.
"""
import argparse
import json
import re
import shutil
import sys
import time
from pathlib import Path

from PIL import Image

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

import artio  # noqa: E402
from palette import ART_DIR, PAL, PROJECT_ROOT  # noqa: E402

DEFAULT_INBOX = HERE / "inbox"
DEFAULT_OLD = HERE / "_old"
DEFAULT_MANIFEST = artio.IMPORTED_MANIFEST
DEFAULT_DATA = PROJECT_ROOT / "data"
DEFAULT_SCALE = 2


# --------------------------------------------------------------------------
# What the game expects: read from the art folders, never hard-coded
# --------------------------------------------------------------------------

class Asset:
    """One file of art the game uses. kind: image | frame | monster_sheet | sprite_sheet."""

    def __init__(self, key, size, kind, ui, group=None):
        self.key, self.size, self.kind, self.ui, self.group = key, size, kind, ui, group
        self.rel = key + ".png"

    def __repr__(self):
        return f"Asset({self.key}, {self.size}, {self.kind}, ui={self.ui})"


def is_ui_art(key):
    """UI art is drawn on a logical grid and stored enlarged by the UI scale; 3D art (tiles,
    sprites, monsters, floor icons) is stored as drawn."""
    parts = key.split("/")
    if key == "ui/title":
        return False  # The title screen is full resolution (640x360 as drawn), not 2x blocks.
    if parts[0] in ("ui", "portraits"):
        return True
    return parts[0] == "items" and not parts[1].endswith("_floor")


def read_json(path):
    try:
        return json.loads(Path(path).read_text())
    except (OSError, ValueError):
        return None


def build_catalog(art_dir):
    """{key: Asset} for every PNG under art_dir (keys like 'tiles/wall', 'items/dagger_hud',
    'portraits/fighter/portrait', 'monsters/skeleton/idle_0', 'monsters/skeleton/skeleton_sheet')."""
    catalog = {}
    for png in sorted(Path(art_dir).rglob("*.png")):
        rel = png.relative_to(art_dir).as_posix()
        if rel.startswith("_"):
            continue
        key = rel[:-4]
        parts = key.split("/")
        with Image.open(png) as im:
            size = im.size
        if parts[0] == "monsters" and len(parts) == 3:
            info = read_json(art_dir / "monsters" / parts[1] / f"{parts[1]}_sheet.json") or {}
            if parts[2] == f"{parts[1]}_sheet":
                kind, group = "monster_sheet", parts[1]
            else:
                kind, group = "frame", parts[1]
                size = tuple(info.get("frame_size", size))
            catalog[key] = Asset(key, size, kind, False, group)
        elif parts[0] == "sprites" and (art_dir / (key + "_sheet.json")).exists():
            catalog[key] = Asset(key, size, "sprite_sheet", False, parts[1])
        else:
            catalog[key] = Asset(key, size, "image", is_ui_art(key))
    return catalog


def normalise(name):
    return re.sub(r"[\s\-]+", "_", name.strip().lower())


def build_aliases(catalog):
    """{alias: {keys}}: short names an inbox file can use. A name that maps to one key is usable;
    one that maps to several is reported as ambiguous."""
    aliases = {}

    def add(alias, key):
        aliases.setdefault(alias, set()).add(key)

    for key, asset in catalog.items():
        parts = key.split("/")
        add(parts[-1], key)
        add("_".join(parts[-2:]), key)
        add("_".join(parts), key)
        if asset.kind == "monster_sheet":
            add(asset.group, key)  # skeleton.png is the skeleton's sheet
        if asset.kind == "sprite_sheet":
            add(parts[-1], key)
    return aliases


def add_walk_frames(files, inbox, catalog, aliases):
    """A monster may gain a walk cycle: walk_0, walk_1, ... are valid frame names for any monster that
    has a sheet, even though the art does not have them yet (process_monster appends them to the
    sheet). Recognised as monsters/<name>/walk_<n>.png, <name>_walk_<n>.png or walk_<n>.png in a
    folder named for the monster."""
    sheets = {a.group for a in catalog.values() if a.kind == "monster_sheet"}
    for path in files:
        rel = normalise(path.relative_to(inbox).with_suffix("").as_posix())
        parts = rel.split("/")
        if parts[0] == "art":
            parts = parts[1:]
        mon = num = None
        if len(parts) >= 2 and re.fullmatch(r"walk_\d+", parts[-1]) and parts[-2] in sheets:
            mon, num = parts[-2], parts[-1]
        else:
            m = re.fullmatch(r"(.+)_(walk_\d+)", parts[-1])
            if m and m.group(1) in sheets:
                mon, num = m.group(1), m.group(2)
        if mon:
            key = f"monsters/{mon}/{num}"
            if key not in catalog:
                size = next(a.size for k, a in catalog.items() if a.kind == "frame" and a.group == mon)
                catalog[key] = Asset(key, size, "frame", False, mon)
                aliases.setdefault(f"{mon}_{num}", set()).add(key)


def match(path, inbox, catalog, aliases, mapping):
    """-> ('ok', key) | ('ambiguous', [keys]) | ('none', None)."""
    rel = path.relative_to(inbox)
    rel_posix = rel.as_posix()
    for name in (rel_posix, path.name):
        if name in mapping:
            target = mapping[name]
            return ("ok", target) if target in catalog else ("none", None)
    cand = normalise(rel.with_suffix("").as_posix())
    if cand.startswith("art/"):
        cand = cand[4:]
    if cand in catalog:
        return "ok", cand
    for name in (normalise("_".join(rel.with_suffix("").parts)), normalise(path.stem)):
        keys = aliases.get(name)
        if keys and len(keys) == 1:
            return "ok", next(iter(keys))
        if keys:
            return "ambiguous", sorted(keys)
    return "none", None


# --------------------------------------------------------------------------
# Converting pixels
# --------------------------------------------------------------------------

def binarise_alpha(img):
    """Alpha to 0 or 255. Returns (image, number of soft pixels that were rounded)."""
    img = img.convert("RGBA")
    px = img.load()
    soft = 0
    for y in range(img.height):
        for x in range(img.width):
            r, g, b, a = px[x, y]
            if 0 < a < 255:
                soft += 1
            px[x, y] = (r, g, b, 255) if a >= 128 else (0, 0, 0, 0)
    return img, soft


def fit(img, target, ui, scale):
    """Nearest-neighbour resize to `target` (w, h). Returns (image, [notes])."""
    if img.size == target:
        return img, []
    notes = []
    w, h = img.size
    tw, th = target
    logical = (tw // scale, th // scale) if ui and tw % scale == 0 and th % scale == 0 else None
    if logical and img.size == logical:
        notes.append(f"{w}x{h} -> {tw}x{th} (UI scale {scale}x)")
    elif tw % w == 0 and th % h == 0 and tw // w == th // h:
        notes.append(f"{w}x{h} -> {tw}x{th} (enlarged {tw // w}x)")
    elif w % tw == 0 and h % th == 0 and w // tw == h // th:
        notes.append(f"{w}x{h} -> {tw}x{th} (reduced {w // tw}x)")
    elif abs(w / h - tw / th) < 1e-6:
        notes.append(f"WARNING {w}x{h} -> {tw}x{th}: not a whole-number factor, pixels will be uneven")
    else:
        notes.append(f"WARNING {w}x{h} -> {tw}x{th}: different shape, the picture is stretched")
    return img.resize(target, Image.NEAREST), notes


def snap(img, dither=False):
    """Move every opaque pixel to the nearest palette colour (plain RGB distance). With `dither`,
    spread each pixel's error onto its unprocessed neighbours (Floyd-Steinberg)."""
    img = img.convert("RGBA")
    px = img.load()
    w, h = img.size
    if not dither:
        cache = {}
        for y in range(h):
            for x in range(w):
                r, g, b, a = px[x, y]
                if a:
                    px[x, y] = (*cache.setdefault((r, g, b), PAL.nearest((r, g, b))), 255)
        return img
    err = [[[0.0, 0.0, 0.0] for _ in range(w)] for _ in range(h)]
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if not a:
                continue
            want = [min(255.0, max(0.0, c + err[y][x][i])) for i, c in enumerate((r, g, b))]
            got = PAL.nearest(tuple(int(round(c)) for c in want))
            px[x, y] = (*got, 255)
            diff = [want[i] - got[i] for i in range(3)]
            for dx, dy, f in ((1, 0, 7 / 16), (-1, 1, 3 / 16), (0, 1, 5 / 16), (1, 1, 1 / 16)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < w and 0 <= ny < h and px[nx, ny][3]:
                    for i in range(3):
                        err[ny][nx][i] += diff[i] * f
    return img


class Context:
    """Everything one run needs; the paths are parameters so tests can use a temporary tree."""

    def __init__(self, art_dir, old_dir, manifest_path, data_dir, scale, dither, dry_run, frames, derive_variants=True):
        self.derive_variants = derive_variants
        self.art_dir, self.old_dir, self.manifest_path = Path(art_dir), Path(old_dir), Path(manifest_path)
        self.data_dir, self.scale, self.dither, self.dry_run, self.frames = Path(data_dir), scale, dither, dry_run, frames
        self.manifest = read_json(self.manifest_path) or {"files": {}}
        self.manifest.setdefault("files", {})
        self.replaced, self.notes, self.mismatches, self.errors = [], [], [], []
        self.unmatched, self.ambiguous, self.backups, self.patched = [], [], [], []
        self.used_files = []

    def convert(self, img, target, ui, label):
        img, soft = binarise_alpha(img)
        if soft:
            self.notes.append(f"{label}: {soft} soft-alpha pixel(s) rounded to solid or clear")
        img, notes = fit(img, target, ui, self.scale)
        self.notes += [f"{label}: {n}" for n in notes]
        img = snap(img, self.dither)
        PAL.check(img, label)
        return img

    def backup(self, rel):
        """Copy the current file to _old the first time it is replaced (never over an old back-up)."""
        src, dst = self.art_dir / rel, self.old_dir / rel
        if src.exists() and rel not in self.manifest["files"] and not dst.exists():
            self.backups.append(rel)
            if not self.dry_run:
                dst.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(src, dst)

    def write_image(self, img, rel, source):
        self.backup(rel)
        if not self.dry_run:
            dest = self.art_dir / rel
            dest.parent.mkdir(parents=True, exist_ok=True)
            img.save(dest)
        self.manifest["files"][rel] = {"source": source, "imported": time.strftime("%Y-%m-%d %H:%M:%S")}

    def write_text(self, text, rel, backup_to=None):
        dest = self.art_dir / rel if backup_to is None else backup_to[0]
        old = self.old_dir / (rel if backup_to is None else backup_to[1])
        if dest.exists() and not old.exists():
            self.backups.append(rel)
            if not self.dry_run:
                old.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(dest, old)
        if not self.dry_run:
            dest.write_text(text)

    def save_manifest(self):
        if not self.dry_run:
            self.manifest_path.write_text(json.dumps(self.manifest, indent=2, sort_keys=True))


# --------------------------------------------------------------------------
# Sheets
# --------------------------------------------------------------------------

def slice_sheet(img, count):
    fw = img.width // count
    return [img.crop((i * fw, 0, (i + 1) * fw, img.height)) for i in range(count)]


def guess_count(img, expected, forced, frame_size=None):
    """How many frames a one-row sheet holds. Forced (--frames, or a layout file) wins. Otherwise
    the old count, if it divides the width and its frames are about the shape of the old ones
    (within 15%); else whichever count that divides the width gives frames closest in shape to the
    old frames (square frames, or the old aspect). Returns (count, why) or (None, advice)."""
    if forced:
        return forced, "given with --frames or a layout file"
    w, h = img.size
    want = (frame_size[0] / frame_size[1]) if frame_size else None

    def aspect(count):
        return (w / count) / h

    candidates = []
    if expected and w % expected == 0:
        candidates.append((expected, "same count as the art it replaces"))
    if h and w % h == 0:
        candidates.append((w // h, "square frames"))
    if want:
        by_shape = round((w / h) / want)
        if by_shape >= 1 and w % by_shape == 0:
            candidates.append((by_shape, "frames the shape of the old ones"))
    if not candidates:
        return None, "the width doesn't divide into equal frames; say how many with --frames NAME=N"
    if want and expected and candidates[0][0] == expected and abs(aspect(expected) - want) / want <= 0.15:
        return candidates[0]
    if want:
        return min(candidates, key=lambda c: abs(aspect(c[0]) - want))
    return candidates[0]


def load_layout(path):
    """A layout file: {"idle": 4, "attack": 3, ...}, animation name -> frame count, in order."""
    data = read_json(path)
    if isinstance(data, dict) and data and all(isinstance(v, int) and v > 0 for v in data.values()):
        return data
    return None


def find_layout(inbox_file):
    for name in (inbox_file.with_suffix("").name + ".layout.json", inbox_file.with_suffix("").name.replace("_sheet", "") + ".layout.json"):
        p = inbox_file.parent / name
        if p.exists():
            return p
    return None


def patch_monster_tres(ctx, name, hframes, anims, only=None):
    """Update the frame numbers in data/monsters/<name>.tres to match a new layout."""
    tres = ctx.data_dir / "monsters" / f"{name}.tres"
    if not tres.exists():
        ctx.errors.append(f"monsters/{name}: no {tres} to update with the new frame layout")
        return
    text = tres.read_text()
    indices, n = {}, 0
    for anim, count in anims.items():
        indices[anim] = list(range(n, n + count))
        n += count

    def arr(a):
        return "PackedInt32Array(" + ", ".join(map(str, indices.get(a, []))) + ")"

    new = re.sub(r"^hframes = .*$", f"hframes = {hframes}", text, flags=re.M)
    for field, anim in (("idle_frames", "idle"), ("attack_frames", "attack"), ("hurt_frames", "hurt"), ("walk_frames", "walk")):
        if anim in indices and (only is None or anim in only):  # `only`: leave the other animations' hand-set frame lists alone
            new = re.sub(rf"^{field} = .*$", f"{field} = {arr(anim)}", new, flags=re.M)
    if new != text:
        ctx.write_text(new, f"data/monsters/{name}.tres", backup_to=(tres, f"data/monsters/{name}.tres"))
        ctx.patched.append(f"data/monsters/{name}.tres (hframes {hframes}, idle {indices.get('idle')}, attack {indices.get('attack')}, hurt {indices.get('hurt')})")


def process_monster(ctx, name, parts):
    """parts: {"sheet": (Path, key) or None, "frames": {frame_name: Path}}."""
    mdir = ctx.art_dir / "monsters" / name
    info = read_json(mdir / f"{name}_sheet.json")
    if not info:
        ctx.errors.append(f"monsters/{name}: no {name}_sheet.json to read the frame layout from")
        return
    fw, fh = info["frame_size"]
    order = list(info["frames"])
    anims = info.get("animations", {})
    incoming, layout = {}, None
    sources = []
    new_order, new_anims = order, anims

    if parts.get("sheet"):
        path, _ = parts["sheet"]
        sources.append(path)
        sheet = Image.open(path).convert("RGBA")
        lay_path = find_layout(path)
        layout = load_layout(lay_path) if lay_path else None
        if lay_path:
            sources.append(lay_path)
            if layout is None:
                ctx.errors.append(f"monsters/{name}: {lay_path.name} isn't a layout like {{\"idle\": 4, \"attack\": 3}}")
        forced = sum(layout.values()) if layout else ctx.frames.get(name)
        count, why = guess_count(sheet, len(order), forced, (fw, fh))
        if count is None:
            ctx.errors.append(f"monsters/{name}: {path.name}: {why}")
            return
        ctx.notes.append(f"monsters/{name}: sheet {sheet.width}x{sheet.height} read as {count} frame(s) ({why})")
        if sheet.width % count:
            ctx.errors.append(f"monsters/{name}: {path.name} is {sheet.width} wide: not {count} equal frames")
            return
        frames = [ctx.convert(f, (fw, fh), False, f"monsters/{name}/frame {i}") for i, f in enumerate(slice_sheet(sheet, count))]
        if layout:
            new_order = [f"{a}_{i}" for a, n in layout.items() for i in range(n)]
            new_anims = {a: [f"{a}_{i}" for i in range(n)] for a, n in layout.items()}
            incoming = dict(zip(new_order, frames))
            if len(new_order) != len(order) or new_order != order:
                ctx.mismatches.append(f"monsters/{name}: layout of {count} frames ({', '.join(f'{a} {n}' for a, n in layout.items())}) replaces {len(order)} ({', '.join(f'{a} {len(v)}' for a, v in anims.items())})")
        elif count == len(order):
            incoming = dict(zip(order, frames))
        else:
            ctx.mismatches.append(f"monsters/{name}: sheet has {count} frame(s), the game's art has {len(order)}; "
                                  f"{'the extra ' + str(count - len(order)) + ' dropped' if count > len(order) else str(len(order) - count) + ' kept from the old art'} "
                                  f"(add {name}_sheet.layout.json to use them all)")
            for n, f in zip(order, frames):
                incoming[n] = f

    added_walk = False
    for fname, path in parts.get("frames", {}).items():
        if fname not in new_order and re.fullmatch(r"walk_\d+", fname):
            # A walk cycle is optional: its frames join the end of the sheet (a new animation "walk").
            if new_order is order:
                new_order, new_anims = list(order), {a: list(v) for a, v in anims.items()}
            new_order.append(fname)
            new_anims.setdefault("walk", []).append(fname)
            added_walk = True
        if fname not in new_order:
            ctx.errors.append(f"monsters/{name}/{fname}: not a frame of this monster (frames: {', '.join(new_order)})")
            continue
        sources.append(path)
        incoming[fname] = ctx.convert(Image.open(path), (fw, fh), False, f"monsters/{name}/{fname}")

    final = {}
    for n in new_order:
        if n in incoming:
            final[n] = incoming[n]
        elif (mdir / f"{n}.png").exists():
            final[n] = Image.open(mdir / f"{n}.png").convert("RGBA")
        else:
            ctx.errors.append(f"monsters/{name}: no image for frame {n}")
            return
    sheet_img = Image.new("RGBA", (fw * len(new_order), fh), (0, 0, 0, 0))
    rects = {}
    for i, n in enumerate(new_order):
        sheet_img.paste(final[n], (i * fw, 0))
        rects[n] = {"x": i * fw, "y": 0, "w": fw, "h": fh}
        if n in incoming:
            ctx.write_image(final[n], f"monsters/{name}/{n}.png", sources[0].name)
    ctx.write_image(sheet_img, f"monsters/{name}/{name}_sheet.png", sources[0].name)
    ctx.write_text(json.dumps({"frame_size": [fw, fh], "frames": rects, "animations": new_anims}, indent=2), f"monsters/{name}/{name}_sheet.json")
    if layout:
        for old in order:  # Frames the new layout doesn't have any more.
            if old not in new_order and (mdir / f"{old}.png").exists():
                ctx.backup(f"monsters/{name}/{old}.png")
                if not ctx.dry_run:
                    (mdir / f"{old}.png").unlink()
                    imp = mdir / f"{old}.png.import"
                    if imp.exists():
                        imp.unlink()
        patch_monster_tres(ctx, name, len(new_order), layout)
    if added_walk and not layout:
        patch_monster_tres(ctx, name, len(new_order), {a: len(v) for a, v in new_anims.items()}, only=("walk",))  # hframes + walk_frames only
    ctx.replaced.append(f"monsters/{name} ({len(incoming)} of {len(new_order)} frame(s) from the inbox, sheet rebuilt)")
    ctx.used_files += sources


def process_sprite_sheet(ctx, asset, path):
    info = read_json(ctx.art_dir / (asset.key + "_sheet.json")) or {}
    fw, fh = info.get("frame_size", (asset.size[1], asset.size[1]))
    expected = info.get("frames")
    free = info.get("count_free", False)
    sheet = Image.open(path).convert("RGBA")
    count, why = guess_count(sheet, expected, ctx.frames.get(asset.group), (fw, fh))
    if count is None or sheet.width % count:
        ctx.errors.append(f"{asset.key}: {path.name}: {why}")
        return
    if count != expected:
        if free:
            ctx.mismatches.append(f"{asset.key}: {count} frame(s) instead of {expected}; accepted, the game reads the count from the sheet")
        else:
            ctx.mismatches.append(f"{asset.key}: {count} frame(s) but the game needs exactly {expected}; not imported")
            ctx.errors.append(f"{asset.key}: wrong frame count ({count}, need {expected})")
            return
    frames = [ctx.convert(f, (fw, fh), False, f"{asset.key} frame {i}") for i, f in enumerate(slice_sheet(sheet, count))]
    out = Image.new("RGBA", (fw * count, fh), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        out.paste(f, (i * fw, 0))
    ctx.write_image(out, asset.rel, path.name)
    info.update({"frame_size": [fw, fh], "frames": count})
    ctx.write_text(json.dumps(info, indent=2), asset.key + "_sheet.json")
    ctx.replaced.append(f"{asset.key} ({count} frame(s) of {fw}x{fh})")
    ctx.used_files.append(path)


def derive_portrait_variants(ctx, singles, catalog):
    """A hero's hurt and dead portraits are not drawn, they are tinted from the living one: hurt is
    the living portrait blended toward rust red (a brief flash when the hero is hit); dead is greyed
    out with a faint curse-green tint. Done for every living portrait in this import whose hurt or
    dead picture was not supplied too (those are used as given). Same tinting as the procedural
    portraits (gen_portraits.py), so a PixelLab hero and a procedural one are treated alike."""
    import gen_portraits as gp
    for key, path in list(singles.items()):
        parts = key.split("/")
        if not (len(parts) == 3 and parts[0] == "portraits" and parts[2] == "portrait"):
            continue
        asset = catalog[key]
        living = ctx.convert(Image.open(path), asset.size, asset.ui, key + " (for its variants)")
        for suffix, make, what in (("portrait_hurt", gp.hurt_variant, "red-tinted"), ("portrait_dead", gp.cursed_dead_variant, "greyed with a faint curse tint")):
            vkey = f"portraits/{parts[1]}/{suffix}"
            if vkey in singles or vkey not in catalog:
                continue
            ctx.write_image(make(living), catalog[vkey].rel, f"{path.name} (derived)")
            ctx.replaced.append(f"{vkey} ({what}, derived from the living portrait)")


def process_image(ctx, asset, path):
    img = ctx.convert(Image.open(path), asset.size, asset.ui, asset.key)
    ctx.write_image(img, asset.rel, path.name)
    note = f" ({Image.open(path).size[0]}x{Image.open(path).size[1]} -> {asset.size[0]}x{asset.size[1]})" if Image.open(path).size != asset.size else ""
    ctx.replaced.append(asset.key + note)
    ctx.used_files.append(path)


# --------------------------------------------------------------------------
# The run
# --------------------------------------------------------------------------

def run(inbox, ctx, keep_inbox=False):
    inbox = Path(inbox)
    catalog = build_catalog(ctx.art_dir)
    aliases = build_aliases(catalog)
    mapping = read_json(inbox / "map.json") or {}
    files = sorted(p for p in inbox.rglob("*.png") if "_done" not in p.relative_to(inbox).parts)
    add_walk_frames(files, inbox, catalog, aliases)

    singles, monsters = {}, {}
    for path in files:
        kind, result = match(path, inbox, catalog, aliases, mapping)
        if kind == "none":
            ctx.unmatched.append(path.relative_to(inbox).as_posix())
            continue
        if kind == "ambiguous":
            ctx.ambiguous.append(f"{path.relative_to(inbox).as_posix()} (could be: {', '.join(result)})")
            continue
        asset = catalog[result]
        if asset.kind in ("frame", "monster_sheet"):
            group = monsters.setdefault(asset.group, {"frames": {}, "sheet": None})
            if asset.kind == "monster_sheet":
                if group["sheet"]:
                    ctx.ambiguous.append(f"{path.name}: a second sheet for {asset.group} (using {group['sheet'][0].name})")
                    continue
                group["sheet"] = (path, result)
            else:
                group["frames"][asset.key.split("/")[-1]] = path
        else:
            if result in singles:
                ctx.ambiguous.append(f"{path.name}: {result} was already given by {singles[result].name}")
                continue
            singles[result] = path

    for key, path in singles.items():
        asset = catalog[key]
        try:
            (process_sprite_sheet if asset.kind == "sprite_sheet" else process_image)(ctx, asset, path)
        except Exception as e:  # Report and carry on with the rest.
            ctx.errors.append(f"{key}: {e}")
    if ctx.derive_variants:
        derive_portrait_variants(ctx, singles, catalog)
    for name, parts in monsters.items():
        try:
            process_monster(ctx, name, parts)
        except Exception as e:
            ctx.errors.append(f"monsters/{name}: {e}")

    ctx.save_manifest()
    if not keep_inbox and not ctx.dry_run:
        done = inbox / "_done"
        for path in ctx.used_files:
            dest = done / path.relative_to(inbox)
            dest.parent.mkdir(parents=True, exist_ok=True)
            shutil.move(str(path), str(dest))
    return len(files)


def report(ctx, inbox, total, dry):
    lines = []
    head = f"{'Would import' if dry else 'Imported'} from {inbox}: {total} file(s) found"
    lines.append(head + f", palette snap {'with dithering' if ctx.dither else 'nearest (no dithering)'}, UI scale {ctx.scale}x")
    lines.append(f"  {'would replace' if dry else 'replaced'} ({len(ctx.replaced)}):")
    lines += [f"    {r}" for r in ctx.replaced] or ["    nothing"]
    if ctx.mismatches:
        lines.append(f"  frame-count mismatches ({len(ctx.mismatches)}):")
        lines += [f"    {m}" for m in ctx.mismatches]
    if ctx.patched:
        lines.append("  data updated:")
        lines += [f"    {p}" for p in ctx.patched]
    warn = [n for n in ctx.notes if "WARNING" in n or "soft-alpha" in n]
    if warn:
        lines.append(f"  warnings ({len(warn)}):")
        lines += [f"    {w}" for w in warn]
    if ctx.unmatched:
        lines.append(f"  didn't match an expected asset ({len(ctx.unmatched)}), left in the inbox (see --list, or add map.json):")
        lines += [f"    {u}" for u in ctx.unmatched]
    if ctx.ambiguous:
        lines.append(f"  ambiguous or duplicated ({len(ctx.ambiguous)}), left in the inbox:")
        lines += [f"    {a}" for a in ctx.ambiguous]
    if ctx.errors:
        lines.append(f"  errors ({len(ctx.errors)}):")
        lines += [f"    {e}" for e in ctx.errors]
    lines.append(f"  procedural originals backed up: {len(ctx.backups)} new file(s) in {ctx.old_dir}")
    return "\n".join(lines)


def restore(ctx, what):
    """Put the procedural art back from _old and drop it from the protected list."""
    files = ctx.manifest["files"]
    chosen = [rel for rel in list(files) if what == "all" or rel == what or rel == what + ".png" or rel.startswith(what.rstrip("/") + "/")]
    if not chosen:
        print(f"Nothing imported matches {what!r}.")
        return 1
    for rel in chosen:
        old = ctx.old_dir / rel
        if old.exists():
            if not ctx.dry_run:
                shutil.copy2(old, ctx.art_dir / rel)
            print(f"  restored {rel}")
        else:
            print(f"  {rel}: no back-up in {ctx.old_dir} (regenerate it with build_all.py --overwrite-imported)")
        files.pop(rel, None)
    for tres in sorted((ctx.old_dir / "data" / "monsters").glob("*.tres")) if (ctx.old_dir / "data" / "monsters").exists() else []:
        if what == "all" or what.startswith(f"monsters/{tres.stem}"):
            if not ctx.dry_run:
                shutil.copy2(tres, ctx.data_dir / "monsters" / tres.name)
            print(f"  restored data/monsters/{tres.name}")
    ctx.save_manifest()
    return 0


def main(argv=None):
    ap = argparse.ArgumentParser(description="Convert PixelLab exports into game art.")
    ap.add_argument("--inbox", default=str(DEFAULT_INBOX), help="folder with the exports (default tools/art/inbox)")
    ap.add_argument("--dither", action="store_true", help="dither (Floyd-Steinberg) when snapping to the palette")
    ap.add_argument("--scale", type=int, default=DEFAULT_SCALE, help="UI art pixel scale (default 2)")
    ap.add_argument("--dry-run", action="store_true", help="report what would happen; write and move nothing")
    ap.add_argument("--keep-inbox", action="store_true", help="leave processed files in the inbox")
    ap.add_argument("--no-variants", action="store_true", help="do not derive a hero's hurt and dead portraits from the living one (they are tinted by default)")
    ap.add_argument("--frames", action="append", default=[], metavar="NAME=N", help="frames in a sheet, e.g. skeleton=9 or torch=8")
    ap.add_argument("--list", action="store_true", help="list every asset the game expects and exit")
    ap.add_argument("--restore", metavar="KEY", help="restore the procedural art for KEY (a path, a folder like monsters/skeleton, or 'all')")
    ap.add_argument("--art-dir", default=str(ART_DIR))
    ap.add_argument("--old-dir", default=str(DEFAULT_OLD))
    ap.add_argument("--manifest", default=str(DEFAULT_MANIFEST))
    ap.add_argument("--data-dir", default=str(DEFAULT_DATA))
    args = ap.parse_args(argv)

    frames = {}
    for item in args.frames:
        name, _, n = item.partition("=")
        if not n.isdigit():
            ap.error(f"--frames wants NAME=N, got {item!r}")
        frames[name.strip()] = int(n)
    ctx = Context(args.art_dir, args.old_dir, args.manifest, args.data_dir, args.scale, args.dither, args.dry_run, frames, derive_variants=not args.no_variants)

    if args.list:
        catalog = build_catalog(ctx.art_dir)
        for key, a in sorted(catalog.items()):
            tag = {"image": "", "frame": "monster frame", "monster_sheet": "monster sheet", "sprite_sheet": "sprite sheet"}[a.kind]
            extra = [t for t in (tag, f"UI art, {a.size[0] // args.scale}x{a.size[1] // args.scale} logical" if a.ui else "") if t]
            print(f"{key:44s} {a.size[0]}x{a.size[1]:<4} {', '.join(extra)}".rstrip())
        return 0
    if args.restore:
        return restore(ctx, args.restore)

    inbox = Path(args.inbox)
    inbox.mkdir(parents=True, exist_ok=True)
    total = run(inbox, ctx, args.keep_inbox)
    print(report(ctx, inbox, total, args.dry_run))
    return 1 if ctx.errors else 0


if __name__ == "__main__":
    sys.exit(main())
