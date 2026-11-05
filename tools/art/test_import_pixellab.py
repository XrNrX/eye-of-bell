"""Self-test for the PixelLab importer:   python tools/art/test_import_pixellab.py
Works on a temporary copy of a few real art files; never touches art/ or the inbox."""
import contextlib
import io
import json
import os
import random
import re
import shutil
import sys
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from PIL import Image  # noqa: E402

import artio  # noqa: E402
import import_pixellab as imp  # noqa: E402
from palette import ART_DIR, PAL, PROJECT_ROOT  # noqa: E402

failed = 0


def check(name, cond):
    global failed
    print(("PASS  " if cond else "FAIL  ") + name)
    failed += 0 if cond else 1


def noisy(size, seed=1, alpha=255):
    """An image full of off-palette colours."""
    rnd = random.Random(seed)
    img = Image.new("RGBA", size)
    px = img.load()
    for y in range(size[1]):
        for x in range(size[0]):
            px[x, y] = (rnd.randrange(256), rnd.randrange(256), rnd.randrange(256), alpha)
    return img


def sheet_of(frames):
    out = Image.new("RGBA", (sum(f.width for f in frames), frames[0].height))
    x = 0
    for f in frames:
        out.paste(f, (x, 0))
        x += f.width
    return out


def make_world(tmp):
    """A small copy of the real art and data folders, plus empty inbox / _old."""
    art, data = tmp / "art", tmp / "data" / "monsters"
    for rel in ["tiles/wall.png", "items/dagger.png", "items/dagger_hud.png", "items/dagger_floor.png", "items/key.png",
                "sprites/key.png", "sprites/torch.png", "sprites/torch_sheet.json", "sprites/lever.png", "sprites/lever_sheet.json",
                "portraits/fighter/portrait.png", "portraits/fighter/portrait_hurt.png", "portraits/fighter/portrait_dead.png", "portraits/mage/portrait.png",
                "ui/quickslot.png"]:
        (art / rel).parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(ART_DIR / rel, art / rel)
    shutil.copytree(ART_DIR / "monsters" / "skeleton", art / "monsters" / "skeleton", ignore=shutil.ignore_patterns("*.import"))
    data.mkdir(parents=True)
    shutil.copy2(PROJECT_ROOT / "data" / "monsters" / "skeleton.tres", data / "skeleton.tres")
    # The real skeleton has grown a walk cycle since this test was written. The tests below are about a
    # plain 7-frame monster, so the fixture is rebuilt as one (the walk frames are tested on their own).
    mdir = art / "monsters" / "skeleton"
    base7 = ["idle_0", "idle_1", "attack_0", "attack_1", "attack_2", "hurt_0", "hurt_0_flash"]
    for f in mdir.glob("walk_*.png"):
        f.unlink()
    frames7 = [Image.open(mdir / f"{n}.png").convert("RGBA") for n in base7]
    fw7, fh7 = frames7[0].size
    sheet7 = Image.new("RGBA", (fw7 * 7, fh7), (0, 0, 0, 0))
    for i, im in enumerate(frames7):
        sheet7.paste(im, (i * fw7, 0))
    sheet7.save(mdir / "skeleton_sheet.png")
    (mdir / "skeleton_sheet.json").write_text(json.dumps({
        "frame_size": [fw7, fh7],
        "frames": {n: {"x": i * fw7, "y": 0, "w": fw7, "h": fh7} for i, n in enumerate(base7)},
        "animations": {"idle": base7[0:2], "attack": base7[2:5], "hurt": base7[5:7]}}, indent=2))
    tres_text = (data / "skeleton.tres").read_text()
    tres_text = re.sub(r"^hframes = .*$", "hframes = 7", tres_text, flags=re.M)
    tres_text = re.sub(r"^walk_frames = .*$", "walk_frames = PackedInt32Array()", tres_text, flags=re.M)
    (data / "skeleton.tres").write_text(tres_text)
    for d in ("inbox", "old"):
        (tmp / d).mkdir()
    return tmp


def run(tmp, *extra):
    argv = ["--inbox", str(tmp / "inbox"), "--art-dir", str(tmp / "art"), "--old-dir", str(tmp / "old"),
            "--manifest", str(tmp / "imported.json"), "--data-dir", str(tmp / "data"), *extra]
    out = io.StringIO()
    with contextlib.redirect_stdout(out):
        code = imp.main(argv)
    return code, out.getvalue()


def load(path):
    return Image.open(path).convert("RGBA")


def all_in_palette(img):
    return not PAL.off_palette(img)


real_wall = (ART_DIR / "tiles/wall.png").read_bytes()
# The real manifest and back-up folder may exist (real imports have been made): note them, and check afterwards they are unchanged.
_MANIFEST = Path(__file__).resolve().parent / "imported.json"
real_manifest_before = _MANIFEST.read_bytes() if _MANIFEST.exists() else None
real_old_before = sorted(str(q) for q in imp.DEFAULT_OLD.rglob("*")) if imp.DEFAULT_OLD.exists() else None

with tempfile.TemporaryDirectory() as t:
    tmp = make_world(Path(t))
    art, inbox, old = tmp / "art", tmp / "inbox", tmp / "old"
    original_wall = (art / "tiles/wall.png").read_bytes()

    # ---- the catalogue comes from the folders
    cat = imp.build_catalog(art)
    check("catalogue reads sizes from the art folders (wall 128x128, dagger 48x48, hud 24x24, floor 12x12)",
          cat["tiles/wall"].size == (128, 128) and cat["items/dagger"].size == (48, 48) and cat["items/dagger_hud"].size == (24, 24) and cat["items/dagger_floor"].size == (12, 12))
    check("UI art is flagged (items, portraits, ui), 3D art is not (tiles, floor icons, sprites)",
          cat["items/dagger"].ui and cat["portraits/fighter/portrait"].ui and cat["ui/quickslot"].ui and not cat["tiles/wall"].ui and not cat["items/dagger_floor"].ui and not cat["sprites/key"].ui)
    check("monster frames know their frame size and the sheet its kind", cat["monsters/skeleton/idle_0"].size == (96, 128) and cat["monsters/skeleton/skeleton_sheet"].kind == "monster_sheet" and cat["sprites/torch"].kind == "sprite_sheet")

    # ---- palette snapping
    snapped = imp.snap(noisy((16, 16)))
    check("every colour is snapped to the palette", all_in_palette(snapped))
    mid = Image.new("RGBA", (4, 4), (100, 100, 110, 255))
    check("nearest colour, same as PAL.nearest", imp.snap(mid).getpixel((0, 0))[:3] == PAL.nearest((100, 100, 110)))
    ramp = Image.new("RGBA", (32, 8))
    for x in range(32):
        for y in range(8):
            ramp.putpixel((x, y), (60 + x * 4, 55 + x * 4, 65 + x * 4, 255))
    plain, dith = imp.snap(ramp), imp.snap(ramp, dither=True)
    check("no dithering by default: a gradient becomes flat bands (few runs along a row)", len({plain.getpixel((x, 0)) for x in range(32)}) <= 7 and
          sum(plain.getpixel((x, 0)) != plain.getpixel((x + 1, 0)) for x in range(31)) <= 7)
    check("--dither mixes neighbouring colours: more changes along a row, still all palette colours",
          sum(dith.getpixel((x, 0)) != dith.getpixel((x + 1, 0)) for x in range(31)) > sum(plain.getpixel((x, 0)) != plain.getpixel((x + 1, 0)) for x in range(31)) and all_in_palette(dith))
    check("transparent pixels stay transparent", imp.snap(Image.new("RGBA", (3, 3), (9, 9, 9, 0))).getpixel((1, 1))[3] == 0)
    a, soft = imp.binarise_alpha(Image.new("RGBA", (2, 1), (10, 20, 30, 140)))
    b, _ = imp.binarise_alpha(Image.new("RGBA", (2, 1), (10, 20, 30, 100)))
    check("alpha becomes solid or clear (140 -> solid, 100 -> clear), soft pixels counted", a.getpixel((0, 0))[3] == 255 and b.getpixel((0, 0))[3] == 0 and soft == 2)

    # ---- resizing rules
    check("a logical-size UI export is enlarged by the UI scale (24 -> 48)", imp.fit(noisy((24, 24)), (48, 48), True, 2)[0].size == (48, 48) and "UI scale" in imp.fit(noisy((24, 24)), (48, 48), True, 2)[1][0])
    check("an export already at the stored size is untouched", imp.fit(noisy((48, 48)), (48, 48), True, 2) [1] == [])
    check("a 4x bigger export is reduced (256 -> 64) without a warning", imp.fit(noisy((256, 256)), (64, 64), False, 2)[1][0].startswith("256x256 -> 64x64 (reduced 4x)"))
    check("a non-integer resize works but warns", "WARNING" in imp.fit(noisy((40, 40)), (64, 64), False, 2)[1][0])
    check("a different shape warns that it is stretched", "stretched" in imp.fit(noisy((40, 20)), (64, 64), False, 2)[1][0])
    nn = Image.new("RGBA", (2, 2)); nn.putpixel((0, 0), (255, 0, 0, 255)); nn.putpixel((1, 0), (0, 255, 0, 255))
    big = imp.fit(nn, (4, 4), False, 2)[0]
    check("resizing is nearest-neighbour: exact 2x2 blocks, no blending", big.getpixel((0, 0)) == big.getpixel((1, 1)) == (255, 0, 0, 255) and big.getpixel((2, 0)) == (0, 255, 0, 255))

    # ---- matching names
    aliases = imp.build_aliases(cat)
    def m(name, mapping=None):
        p = inbox / name
        return imp.match(p, inbox, cat, aliases, mapping or {})
    check("a flat unique name matches (wall.png, dagger_hud.png)", m("wall.png") == ("ok", "tiles/wall") and m("dagger_hud.png") == ("ok", "items/dagger_hud"))
    check("a key as a path matches (tiles/wall.png, art/tiles/wall.png)", m("tiles/wall.png") == ("ok", "tiles/wall") and m("art/tiles/wall.png") == ("ok", "tiles/wall"))
    check("spaces, hyphens and capitals are forgiven (Short-Sword hud)", m("Dagger HUD.png") == ("ok", "items/dagger_hud"))
    check("class + stem matches a portrait (fighter_portrait_hurt.png)", m("fighter_portrait_hurt.png") == ("ok", "portraits/fighter/portrait_hurt"))
    check("monster frame and sheet names (skeleton_idle_0.png, skeleton_sheet.png, skeleton.png)", m("skeleton_idle_0.png") == ("ok", "monsters/skeleton/idle_0") and m("skeleton_sheet.png") == ("ok", "monsters/skeleton/skeleton_sheet") and m("skeleton.png") == ("ok", "monsters/skeleton/skeleton_sheet"))
    check("key.png is ambiguous (items/key, sprites/key), items_key.png and sprites_key.png are not",
          m("key.png")[0] == "ambiguous" and m("items_key.png") == ("ok", "items/key") and m("sprites_key.png") == ("ok", "sprites/key"))
    check("portrait.png is ambiguous between classes", m("portrait.png")[0] == "ambiguous")
    check("an unknown name matches nothing", m("banana.png") == ("none", None))
    check("map.json can name anything", m("my_export_17.png", {"my_export_17.png": "tiles/wall"}) == ("ok", "tiles/wall"))

    # ---- a full import: single images
    noisy((256, 256), 2).save(inbox / "wall.png")
    noisy((24, 24), 3).save(inbox / "dagger.png")
    noisy((64, 64), 4).save(inbox / "fighter_portrait.png")
    noisy((12, 12), 5).save(inbox / "dagger_floor.png")
    noisy((8, 8), 6).save(inbox / "banana.png")
    noisy((8, 8), 7).save(inbox / "key.png")
    code, out = run(tmp, "--dry-run")
    check("--dry-run writes nothing and moves nothing", (art / "tiles/wall.png").read_bytes() == original_wall and (inbox / "wall.png").exists() and not (old / "tiles").exists() and not (tmp / "imported.json").exists())
    check("...but reports what it would do", "Would import" in out and "tiles/wall" in out and "banana.png" in out)
    code, out = run(tmp)
    wall = load(art / "tiles/wall.png")
    check("wall: 256x256 export -> 128x128, palette colours only", wall.size == (128, 128) and all_in_palette(wall))
    dag = load(art / "items/dagger.png")
    check("dagger: 24x24 export -> 48x48 (2x UI scale), palette colours only", dag.size == (48, 48) and all_in_palette(dag))
    check("dagger_floor stays 12x12 (3D art is not scaled)", load(art / "items/dagger_floor.png").size == (12, 12))
    check("portrait: 64x64 export kept at 64x64", load(art / "portraits/fighter/portrait.png").size == (64, 64))
    check("the existing file names are kept (nothing new in tiles/, items/)", sorted(p.name for p in (art / "tiles").iterdir()) == ["wall.png"])
    check("the procedural original is backed up to _old", (old / "tiles/wall.png").read_bytes() == original_wall)
    hurt = load(art / "portraits/fighter/portrait_hurt.png"); dead = load(art / "portraits/fighter/portrait_dead.png")
    check("importing a living portrait derives its hurt and dead pictures (tinted, not drawn)", hurt.size == (64, 64) and dead.size == (64, 64) and "derived from the living portrait" in out and all_in_palette(hurt) and all_in_palette(dead))
    check("the derived hurt picture is the living one tinted toward red (warmer than it)", sum(p[0] - p[2] for p in hurt.getdata() if p[3]) > sum(p[0] - p[2] for p in load(art / "portraits/fighter/portrait.png").getdata() if p[3]))
    check("the derived dead picture is greyed with at most a faint tint (most opaque pixels near grey)", sum(1 for p in dead.getdata() if p[3] and max(p[:3]) - min(p[:3]) <= 40) >= 0.8 * sum(1 for p in dead.getdata() if p[3]))
    check("the derived pictures are in the manifest (protected from a rebuild)", "portraits/fighter/portrait_hurt.png" in json.loads((tmp / "imported.json").read_text())["files"])
    check("the report lists replaced, unmatched and ambiguous files", "replaced (6)" in out and "banana.png" in out and "key.png" in out and "could be" in out)
    check("processed files moved to _done, unmatched ones stay", (inbox / "_done/wall.png").exists() and not (inbox / "wall.png").exists() and (inbox / "banana.png").exists() and (inbox / "key.png").exists())
    check("the imported files are listed in the manifest", {"tiles/wall.png", "items/dagger.png", "portraits/fighter/portrait.png", "items/dagger_floor.png"} <= set(json.loads((tmp / "imported.json").read_text())["files"]))
    check("exit status 0: unmatched files are reported, not an error", code == 0)

    # ---- importing again does not overwrite the back-up
    noisy((64, 64), 9).save(inbox / "wall.png")
    run(tmp)
    check("a second import leaves the first back-up (the procedural original) alone", (old / "tiles/wall.png").read_bytes() == original_wall)

    # ---- the generators leave imported art alone
    real_manifest = artio.IMPORTED_MANIFEST
    artio.IMPORTED_MANIFEST = tmp / "imported.json"
    try:
        before = (art / "tiles/wall.png").read_bytes()
        with contextlib.redirect_stdout(io.StringIO()):
            artio.save_png(Image.new("RGBA", (64, 64), (*PAL["ink"], 255)), "tiles/wall.png", root=None)
        protected = artio.is_protected("tiles/wall.png")
        os.environ["ART_OVERWRITE_IMPORTED"] = "1"
        overridden = not artio.is_protected("tiles/wall.png")
        del os.environ["ART_OVERWRITE_IMPORTED"]
        check("save_png refuses to overwrite an imported file (is_protected), unless ART_OVERWRITE_IMPORTED is set", protected and overridden)
        check("a tests' root override is never protected", not artio.is_protected("tiles/wall.png", root=tmp / "x"))
    finally:
        artio.IMPORTED_MANIFEST = real_manifest
    check("the real art folder, back-ups and manifest were never touched by this test", (ART_DIR / "tiles/wall.png").read_bytes() == real_wall and (_MANIFEST.read_bytes() if _MANIFEST.exists() else None) == real_manifest_before and (sorted(str(q) for q in imp.DEFAULT_OLD.rglob("*")) if imp.DEFAULT_OLD.exists() else None) == real_old_before)

    # ---- restoring
    code, out = run(tmp, "--restore", "tiles/wall")
    check("--restore puts the procedural file back and unprotects it", (art / "tiles/wall.png").read_bytes() == original_wall and "tiles/wall.png" not in json.loads((tmp / "imported.json").read_text())["files"])

    # ---- monster sheets
    skel_json = json.loads((art / "monsters/skeleton/skeleton_sheet.json").read_text())
    order = list(skel_json["frames"])
    old_tres = (tmp / "data/monsters/skeleton.tres").read_text()
    old_idle = (art / "monsters/skeleton/idle_1.png").read_bytes()
    frames = [noisy((64, 64), 20 + i) for i in range(len(order))]
    sheet_of(frames).save(inbox / "skeleton_sheet.png")
    code, out = run(tmp)
    check("a 7-frame sheet of 64x64 frames is sliced and resized to 96x128 frames", load(art / "monsters/skeleton/skeleton_sheet.png").size == (96 * 7, 128) and "frame" in out)
    check("every frame file got the old name and size", all(load(art / f"monsters/skeleton/{n}.png").size == (96, 128) for n in order))
    check("the frames and sheet are palette-only", all_in_palette(load(art / "monsters/skeleton/skeleton_sheet.png")))
    sheet = load(art / "monsters/skeleton/skeleton_sheet.png")
    check("the sheet is the frames side by side, in the old order",
          all(sheet.crop((i * 96, 0, (i + 1) * 96, 128)).tobytes() == load(art / f"monsters/skeleton/{n}.png").tobytes() for i, n in enumerate(order)))
    check("the json keeps the same frame names and layout", json.loads((art / "monsters/skeleton/skeleton_sheet.json").read_text())["frames"] == skel_json["frames"])
    check("same frame count: no mismatch, the .tres is untouched", "mismatches" not in out and (tmp / "data/monsters/skeleton.tres").read_text() == old_tres)
    check("the old frame is backed up", (old / "monsters/skeleton/idle_1.png").read_bytes() == old_idle)

    # ---- wrong frame count without a layout
    shutil.rmtree(old); old.mkdir()
    artio_files = json.loads((tmp / "imported.json").read_text()); artio_files["files"] = {}; (tmp / "imported.json").write_text(json.dumps(artio_files))
    sheet_of([noisy((96, 128), 40 + i) for i in range(9)]).save(inbox / "skeleton_sheet.png")
    code, out = run(tmp, "--frames", "skeleton=9")
    check("9 frames for 7: reported as a mismatch, extras dropped, still imported", "mismatches (1)" in out and "9 frame" in out and "extra 2 dropped" in out and code == 0)
    check("the sheet still has the game's 7 frames", load(art / "monsters/skeleton/skeleton_sheet.png").size == (96 * 7, 128))
    sheet_of([noisy((96, 128), 60 + i) for i in range(5)]).save(inbox / "skeleton_sheet.png")
    code, out = run(tmp, "--frames", "skeleton=5")
    check("5 frames for 7: mismatch, the last 2 keep the old frames", "2 kept from the old art" in out and load(art / "monsters/skeleton/skeleton_sheet.png").size == (96 * 7, 128))
    sheet_of([noisy((96, 128), 70 + i) for i in range(7)]).save(inbox / "skeleton_sheet.png")
    (tmp / "inbox" / "skeleton_sheet.png").write_bytes((tmp / "inbox" / "skeleton_sheet.png").read_bytes())
    # a sheet whose width does not divide
    Image.new("RGBA", (101, 64), (255, 0, 0, 255)).save(inbox / "skeleton_sheet.png")
    code, out = run(tmp)
    check("a sheet that doesn't divide into frames is an error with advice, exit status 1", code == 1 and "--frames" in out)
    (inbox / "skeleton_sheet.png").unlink()

    # ---- extra frames with a layout file: the .tres follows
    sheet_of([noisy((96, 128), 80 + i) for i in range(10)]).save(inbox / "skeleton_sheet.png")
    (inbox / "skeleton_sheet.layout.json").write_text(json.dumps({"idle": 4, "attack": 4, "hurt": 2}))
    code, out = run(tmp)
    j = json.loads((art / "monsters/skeleton/skeleton_sheet.json").read_text())
    check("a layout file renames the frames idle_0..3, attack_0..3, hurt_0..1", list(j["frames"]) == ["idle_0", "idle_1", "idle_2", "idle_3", "attack_0", "attack_1", "attack_2", "attack_3", "hurt_0", "hurt_1"])
    check("the sheet is 10 frames wide", load(art / "monsters/skeleton/skeleton_sheet.png").size == (960, 128))
    tres = (tmp / "data/monsters/skeleton.tres").read_text()
    check("the monster definition now says hframes = 10 and the new frame lists", "hframes = 10" in tres and "idle_frames = PackedInt32Array(0, 1, 2, 3)" in tres and "attack_frames = PackedInt32Array(4, 5, 6, 7)" in tres and "hurt_frames = PackedInt32Array(8, 9)" in tres)
    check("other settings in the .tres are untouched (hp, fps, pixel size)", "max_hp = 12" in tres and "idle_fps = 2.0" in tres and "pixel_size = 0.014" in tres)
    check("the old frames that no longer exist were removed (attack_2 yes, hurt_0_flash gone), the originals backed up", not (art / "monsters/skeleton/hurt_0_flash.png").exists() and (old / "monsters/skeleton/hurt_0_flash.png").exists())
    check("the .tres is backed up too, and the report says what was updated", (old / "data/monsters/skeleton.tres").read_text() == old_tres and "data/monsters/skeleton.tres" in out)
    check("--restore monsters/skeleton brings the .tres back", run(tmp, "--restore", "monsters/skeleton")[0] == 0 and (tmp / "data/monsters/skeleton.tres").read_text() == old_tres)

    # ---- individual monster frames
    (art / "monsters/skeleton/hurt_0_flash.png").parent.mkdir(exist_ok=True)
    (inbox / "skeleton_sheet.layout.json").unlink(missing_ok=True)
    # (the folder was changed above; rebuild a fresh world for the remaining cases)

with tempfile.TemporaryDirectory() as t:
    tmp = make_world(Path(t))
    art, inbox, old = tmp / "art", tmp / "inbox", tmp / "old"
    check("(fresh world) the monster has its original 7 frames", len(json.loads((art / "monsters/skeleton/skeleton_sheet.json").read_text())["frames"]) == 7)
    noisy((60, 80), 90).save(inbox / "skeleton_idle_0.png")
    noisy((96, 128), 91).save(inbox / "skeleton_attack_1.png")
    noisy((96, 128), 92).save(inbox / "skeleton_dancing_0.png")
    code, out = run(tmp)
    check("individual frames replace just those frames and the sheet is rebuilt from all 7", "2 of 7 frame" in out and load(art / "monsters/skeleton/skeleton_sheet.png").size == (672, 128))
    check("a frame name the monster doesn't have is reported", "dancing_0" in out)
    sheet = load(art / "monsters/skeleton/skeleton_sheet.png")
    check("the replaced frames are in the sheet at the right places (idle_0 first, attack_1 fourth)",
          sheet.crop((0, 0, 96, 128)).tobytes() == load(art / "monsters/skeleton/idle_0.png").tobytes() and sheet.crop((288, 0, 384, 128)).tobytes() == load(art / "monsters/skeleton/attack_1.png").tobytes())
    check("a 60x80 export is not a whole-number factor of 96x128: reported as a warning", "WARNING" in out and "not a whole-number factor" in out)

    # ---- a walk cycle: walk_0.. are new frames at the end of the sheet, the .tres gets walk_frames
    shutil.rmtree(old); old.mkdir()
    for f in list(inbox.glob("*")):
        if f.is_file(): f.unlink()
    walk_dir = inbox / "monsters" / "skeleton"
    walk_dir.mkdir(parents=True)
    for i in range(4):
        noisy((96, 128), 300 + i).save(walk_dir / f"walk_{i}.png")
    tres_before = (tmp / "data/monsters/skeleton.tres").read_text()
    code, out = run(tmp)
    sheet_w = load(art / "monsters/skeleton/skeleton_sheet.png")
    check("4 walk frames are accepted for a monster that has none (not 'unmatched')", code == 0 and "didn't match" not in out and "4 of 11 frame" in out)
    check("they join the end of the sheet: 7 frames became 11", sheet_w.size == (96 * 11, 128))
    jw = json.loads((art / "monsters/skeleton/skeleton_sheet.json").read_text())
    check("the json lists walk_0..walk_3 after the old frames and a walk animation", list(jw["frames"])[-4:] == ["walk_0", "walk_1", "walk_2", "walk_3"] and jw["animations"]["walk"] == ["walk_0", "walk_1", "walk_2", "walk_3"])
    tres_after = (tmp / "data/monsters/skeleton.tres").read_text()
    check("the definition now has hframes = 11 and walk_frames = (7, 8, 9, 10)", "hframes = 11" in tres_after and "walk_frames = PackedInt32Array(7, 8, 9, 10)" in tres_after)
    check("its idle, attack and hurt lists are untouched", all(l in tres_after for l in [x for x in tres_before.splitlines() if x.startswith(("idle_frames", "attack_frames", "hurt_frames"))]))
    check("the walk frames are palette-only", all_in_palette(sheet_w))
    check("the sheet is the frames side by side (walk_2 sits in slot 9)", sheet_w.crop((9 * 96, 0, 10 * 96, 128)).tobytes() == load(art / "monsters/skeleton/walk_2.png").tobytes())
    # Flat names work too.
    for f in walk_dir.glob("*"): f.unlink()
    noisy((96, 128), 310).save(inbox / "skeleton_walk_4.png")
    code, out = run(tmp)
    check("skeleton_walk_4.png is recognised (a fifth walk frame)", "didn't match" not in out and load(art / "monsters/skeleton/skeleton_sheet.png").size == (96 * 12, 128))

    # ---- sprite sheets: the torch may change its frame count, the lever may not
    torch_frames = [noisy((16, 32), 100 + i) for i in range(8)]
    sheet_of(torch_frames).save(inbox / "torch.png")
    code, out = run(tmp)
    torch = load(art / "sprites/torch.png")
    check("torch: 8 frames accepted (the game reads the count from the sheet), reported", torch.size == (128, 32) and "8 frame" in out and "accepted" in out)
    check("torch_sheet.json follows", json.loads((art / "sprites/torch_sheet.json").read_text())["frames"] == 8)
    sheet_of([noisy((16, 16), 110 + i) for i in range(3)]).save(inbox / "lever.png")
    code, out = run(tmp)
    check("lever: 3 frames refused (exactly two: off, on), exit status 1, original kept", code == 1 and "exactly 2" in out and load(art / "sprites/lever.png").size == (32, 16))
    sheet_of([noisy((32, 32), 120 + i) for i in range(2)]).save(inbox / "lever.png")
    code, out = run(tmp)
    check("lever: 2 frames of 32x32 -> 16x16 frames, 2 wide", code == 0 and load(art / "sprites/lever.png").size == (32, 16))

    # ---- misc
    (inbox / "skeleton_sheet.png").write_bytes(b"not a png")
    code, out = run(tmp)
    check("a corrupt file is an error in the report, not a crash", code == 1 and "errors" in out)
    (inbox / "skeleton_sheet.png").unlink()
    noisy((64, 64), 130).save(inbox / "wall.png")
    code, out = run(tmp, "--keep-inbox")
    check("--keep-inbox imports but leaves the file in the inbox (nothing copied to _done)", code == 0 and "tiles/wall" in out and (inbox / "wall.png").exists() and not (inbox / "_done" / "wall.png").exists())

print()
print("All good." if not failed else f"{failed} failed.")
sys.exit(1 if failed else 0)
