"""Spell effect flipbooks: art/spells/<spell>/<name>_sheet.png (a single row of frames) and <name>_sheet.json
({"frames": N, "fps": F, "frame_w": W, "frame_h": H}), plus the scorch decal art/spells/scorch.png.

The Fireball's three animations were made with PixelLab's effects tool (vfx_workbench) and exported as
atlases; the source pieces are in tools/art/pieces/spells/fireball/ (<name>.png + <name>.json, as exported):
    resurrection/portrait 62x78 and portrait_large 90x113 (a Cleric's): the column shrunk to stand over a portrait
    heal/portrait 58x74, bless/portrait 74x46 and shield/portrait 68x58: the same two effects shrunk to fit over a 64x64 party portrait (one-shot)
    resurrection/column   116x149, a column of gold light on a ring that fades in, sparkles rising, fades out (one-shot, 24 frames)
    shield/flash   94x80, a gold hex dome snapping up, shimmering and fading (one-shot)
    bless/ring   204x130, a gold ring sweeping out across the floor (one-shot)
    heal/burst   108x146, a gold flash and ring, then plus signs and sparkles rising round the party (one-shot)
    cast         48x48, a fiery flash at the party's hands (one-shot)
    projectile   56x56, a burning ball with flame licks (a loop)
    impact       96x96, flash, a billowing fire mass that burns out, a shockwave ring, debris, smoke (one-shot)
This slices each atlas along its JSON, drops blank frames at the end, snaps every pixel to the palette and writes a
row sheet at full resolution (not doubled: the game draws them as unshaded, additive billboards at the same
pixel density as the monsters, 0.014 world units a pixel). The frame durations in the JSON give the fps.

The scorch is a 32x32 soot blotch (ink core, stone_900 body, a rust scorched rim, a few rust embers) drawn procedurally; the
game projects it on the floor and walls as a Decal and fades it out over a few seconds.
"""
import json
from pathlib import Path

from PIL import Image

from artio import save_png
from noise import hash01
from palette import ART_DIR, PAL

PIECES = Path(__file__).parent / "pieces" / "spells"


def slice_atlas(spell, name):
    """The frames of an exported atlas, in order, with trailing blank frames removed."""
    atlas = Image.open(PIECES / spell / f"{name}.png").convert("RGBA")
    meta = json.loads((PIECES / spell / f"{name}.json").read_text())
    frames = []
    durations = []
    for f in meta["frames"]:
        r = f["frame"]
        frames.append(atlas.crop((r["x"], r["y"], r["x"] + r["w"], r["y"] + r["h"])))
        durations.append(f.get("duration", 71))
    while len(frames) > 1 and frames[-1].getchannel("A").getbbox() is None:
        frames.pop()
        durations.pop()
    fps = round(1000.0 / (sum(durations) / len(durations)), 2)
    return frames, fps


# Palette names a sheet's snapped pixels are moved off, per effect folder: the bear trap's white-hot sparks snap to the pale curse
# green, which is never used for anything but the curse (docs/art_style.md), so they become torch colours.
RECOLOUR = {"bear_trap": {"curse_300": "torch_300", "curse_500": "torch_500", "curse_700": "rust_500"}}


def build_sheet(spell, name):
    frames, fps = slice_atlas(spell, name)
    w, h = frames[0].size
    sheet = Image.new("RGBA", (w * len(frames), h), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        sheet.paste(f, (i * w, 0))
    sheet = PAL.snap(sheet)
    table = RECOLOUR.get(spell, {})
    if table:
        px = sheet.load()
        for y in range(sheet.height):
            for x in range(sheet.width):
                r, g, b, a = px[x, y]
                if a and PAL.name_of((r, g, b)) in table:
                    px[x, y] = (*PAL[table[PAL.name_of((r, g, b))]], a)
    written = [save_png(sheet, f"spells/{spell}/{name}_sheet.png")]
    info = {"frames": len(frames), "fps": fps, "frame_w": w, "frame_h": h}
    path = ART_DIR / "spells" / spell / f"{name}_sheet.json"
    path.write_text(json.dumps(info, indent=2))
    written.append(path)
    return written


def scorch():
    """A soot mark: an irregular blotch, darkest in the middle, with a dithered edge and a few dull embers."""
    size = 32
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    px = img.load()
    c = (size - 1) / 2.0
    for y in range(size):
        for x in range(size):
            dx, dy = x - c, y - c
            # A lumpy radius: the edge wanders with the angle so it is not a circle.
            ang = (x * 7 + y * 13) % 11 / 11.0
            reach = 13.0 + 3.0 * (hash01(3, x // 4, y // 4) - 0.5) * 2.0 + 1.5 * ang
            d = (dx * dx + dy * dy) ** 0.5
            if d > reach:
                continue
            t = d / reach
            noise = hash01(5, x, y)
            if t < 0.4:
                colour = PAL["ink"]
            elif t < 0.62:
                colour = PAL["stone_900"] if noise > 0.15 else PAL["ink"]
            elif t < 0.82:
                colour = PAL["rust_700"] if noise > 0.3 else PAL["stone_900"]  # A scorched rim: a dull rust ring that still shows on a dark floor.
            else:
                if noise < 0.6 - (t - 0.82) * 2.0:  # The edge breaks up into dither.
                    colour = PAL["rust_700"] if noise > 0.25 else PAL["soil_900"]
                else:
                    continue
            px[x, y] = (*colour, 255)
    for i in range(7):  # A few dull embers still glowing in the soot.
        x = int(c + (hash01(9, i, 1) - 0.5) * 16)
        y = int(c + (hash01(9, i, 2) - 0.5) * 16)
        if px[x, y][3]:
            px[x, y] = (*PAL["rust_500"], 255)
    return img


def build(scale=None):
    written = []
    # Fireball: fire colours. Magic Missile: neutral grey and bone only; the game tints it cold pale blue (the palette has no blue).
    # The holy spells (heal, bless, shield, resurrection): gold, one animation each (see HOLY_SHEETS).
    # Hold Monster: grey and bone runes, tinted cold pale blue in the game like Magic Missile (bind, held loop, shatter).
    # The bear trap's snap: rusted iron jaws, sparks and a spatter (drawn normally in the game, not added).
    for spell in ("fireball", "magic_missile", "heal", "bless", "shield", "resurrection", "hold_monster", "bear_trap"):
        for name in ("cast", "projectile", "impact", "burst", "ring", "flash", "column", "portrait", "portrait_large",
                     "bind", "held", "shatter", "snap"):
            if (PIECES / spell / f"{name}.png").exists():
                (ART_DIR / "spells" / spell).mkdir(parents=True, exist_ok=True)
                written += build_sheet(spell, name)
    written.append(save_png(scorch(), "spells/scorch.png"))
    return written


if __name__ == "__main__":
    for p in build():
        print(p)
