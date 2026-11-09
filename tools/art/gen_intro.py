"""The intro cutscene's art, written to art/intro/, all at FULL RESOLUTION like the title screen.

Shots: art/intro/<shot>.png, 640x360. These are only placeholders here: the real pictures are PixelLab images routed through
import_pixellab.py (prompts and costs in docs/intro_prompts.md). The importer sizes an export against the file already in
art/, so a new shot needs its name in SHOTS first. save_png leaves imported shots alone, so this never undoes an import.

Effect layers (art/intro/fx/), drawn here, transparent with hard pixel edges (density comes from dithering, never soft alpha):
    lightning_1..3.png   a bolt with branches, 200x320
    flash.png            the full-screen flash, 640x360, dithered, densest at the top
    fog_thin.png, fog_thick.png   640x180, sit on the bottom of the screen, repeat seamlessly sideways
    rain_0..7.png        128x176, tile in both directions, and frame 7 runs into frame 0
    <shot>_glow.png      only the glowing pixels of a shot (GLOWS), which the player pulses. Re-run after importing that shot.
"""
import random
from pathlib import Path

from PIL import Image

from artio import save_png
from dither import BAYER4
from noise import value_noise
from palette import PAL

W, H = 640, 360
SHOTS = (
    "shot_01_road", "shot_02_travellers", "shot_03_crow", "shot_04_trees", "shot_05_boots", "shot_06_ruins", "shot_07_silhouette",
    "shot_08_holy_symbol", "shot_09_sword", "shot_10_entrance", "shot_11_archway", "shot_12_tunnel", "shot_13_inside",
    "shot_14_looking_out",
)
GLOWS = {"shot_08_holy_symbol": "torch", "shot_10_entrance": "curse", "shot_12_tunnel": "curse"}  # Shot -> colour that pulses.
BOLT_W, BOLT_H = 200, 320
FOG_H = 180
RAIN_W, RAIN_H, RAIN_FRAMES = 128, 176, 8
RAIN_STEP = (-4, RAIN_H // RAIN_FRAMES)  # One frame's fall. Eight of them are exactly one tile high, so it loops.


def placeholder():
    img = Image.new("RGBA", (W, H))
    px = img.load()
    ramp = [PAL["ink"], PAL["stone_900"], PAL["stone_800"]]
    for y in range(H):
        for x in range(W):
            px[x, y] = (*ramp[min(2, y * 3 // H)], 255)
    return img


def _bayer(x, y):
    return (BAYER4[y % 4][x % 4] + 0.5) / 16.0


def _jagged(rnd, x0, y0, x1, y1, spread):
    """Midpoint displacement: a list of points from (x0, y0) to (x1, y1)."""
    if y1 - y0 < 8:
        return [(x0, y0), (x1, y1)]
    mid = (x0 + x1) / 2 + rnd.uniform(-spread, spread)
    y = (y0 + y1) // 2
    return _jagged(rnd, x0, y0, mid, y, spread * 0.55)[:-1] + _jagged(rnd, mid, y, x1, y1, spread * 0.55)


def _line(points):
    """Every whole pixel along a list of points."""
    out = []
    for (ax, ay), (bx, by) in zip(points, points[1:]):
        steps = max(1, int(max(abs(bx - ax), abs(by - ay))))
        out += [(round(ax + (bx - ax) * i / steps), round(ay + (by - ay) * i / steps)) for i in range(steps + 1)]
    return out


def lightning(seed):
    """A bolt from the top edge, with a pale core (the palette has no white), a grey edge and a few thin branches."""
    rnd = random.Random(seed)
    img = Image.new("RGBA", (BOLT_W, BOLT_H), (0, 0, 0, 0))
    px = img.load()
    main = _jagged(rnd, BOLT_W / 2 + rnd.uniform(-30, 30), 0, BOLT_W / 2 + rnd.uniform(-50, 50), BOLT_H - 1, 46)

    def put(x, y, colour):
        if 0 <= x < BOLT_W and 0 <= y < BOLT_H:
            px[x, y] = (*colour, 255)
    branches = []
    for _ in range(4):
        x, y = rnd.choice(main[len(main) // 6:-len(main) // 4])
        side = rnd.choice((-1, 1))
        branches.append(_line(_jagged(rnd, x, y, x + side * rnd.randint(25, 70), y + rnd.randint(35, 90), 14)))
    for branch in branches:
        for x, y in branch:
            put(x, y, PAL["stone_300"])
    body = _line(main)
    for x, y in body:  # Edge first, so the core stays on top.
        for dx in (-1, 2):
            put(x + dx, y, PAL["stone_100"])
    for x, y in body:
        put(x, y, PAL["bone_300"])
        put(x + 1, y, PAL["bone_300"])
    return img


def flash():
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    px = img.load()
    for y in range(H):
        density = 0.75 - 0.45 * y / H
        for x in range(W):
            if density > _bayer(x, y):
                px[x, y] = (*PAL["stone_100"], 255)
    return img


def fog(seed, strength, dense_from, light, dense):
    """Drifting banks that thicken toward the bottom edge. Only the sideways direction has to repeat; 640 and the
    4-pixel dither pattern and the noise cells all divide evenly, so the two ends meet."""
    grid = value_noise(W, FOG_H, scale=80, seed=seed, octaves=4, persistence=0.55, tileable=True)
    img = Image.new("RGBA", (W, FOG_H), (0, 0, 0, 0))
    px = img.load()
    for y in range(FOG_H):
        rise = min(1.0, (y / FOG_H) * 1.35)
        for x in range(W):
            amount = max(0.0, grid[y][x] - 0.38) / 0.45 * rise * strength
            if amount > _bayer(x, y):
                px[x, y] = (*(dense if amount > dense_from else light), 255)
    return img


def rain_frames():
    rnd = random.Random(9101)
    drops = [(rnd.randrange(RAIN_W), rnd.randrange(RAIN_STEP[1]), rnd.randrange(RAIN_FRAMES), rnd.randint(5, 9),
              PAL["stone_300"] if rnd.random() < 0.3 else PAL["stone_500"]) for _ in range(46)]
    frames = []
    for f in range(RAIN_FRAMES):
        img = Image.new("RGBA", (RAIN_W, RAIN_H), (0, 0, 0, 0))
        px = img.load()
        for x0, y0, phase, length, colour in drops:
            # A drop's own clock restarts as it wraps off the bottom, so its sideways drift never shows a jump.
            t = (f + phase) % RAIN_FRAMES
            x, y = x0 + RAIN_STEP[0] * t, y0 + RAIN_STEP[1] * t
            for i in range(length):
                px[(x + (-i * RAIN_STEP[0]) // RAIN_STEP[1]) % RAIN_W, (y - i) % RAIN_H] = (*colour, 255)
        frames.append(img)
    return frames


def glow_mask(shot, ramp):
    """The pixels of a shot in one colour family, the rest clear. None if the shot isn't there yet."""
    path = Path(__file__).resolve().parents[2] / "art" / "intro" / f"{shot}.png"
    if not path.exists():
        return None
    colours = {tuple(PAL[name]) for name in (f"{ramp}_700", f"{ramp}_500", f"{ramp}_300")}
    img = Image.open(path).convert("RGBA")
    px = img.load()
    for y in range(img.height):
        for x in range(img.width):
            if px[x, y][:3] not in colours:
                px[x, y] = (0, 0, 0, 0)
    return img


def build(scale=2):
    """`scale` is ignored on purpose: everything here is full resolution, whatever the UI scale is."""
    written = [save_png(placeholder(), f"intro/{name}.png", scale=1) for name in SHOTS]
    for i, seed in enumerate((31, 47, 73), 1):
        written.append(save_png(lightning(seed), f"intro/fx/lightning_{i}.png", scale=1))
    written.append(save_png(flash(), "intro/fx/flash.png", scale=1))
    written.append(save_png(fog(4401, 0.42, 2.0, PAL["stone_500"], PAL["stone_300"]), "intro/fx/fog_thin.png", scale=1))
    written.append(save_png(fog(4402, 0.95, 0.72, PAL["stone_500"], PAL["stone_300"]), "intro/fx/fog_thick.png", scale=1))
    for i, frame in enumerate(rain_frames()):
        written.append(save_png(frame, f"intro/fx/rain_{i}.png", scale=1))
    for shot, ramp in GLOWS.items():
        mask = glow_mask(shot, ramp)
        if mask:
            written.append(save_png(mask, f"intro/fx/{shot}_glow.png", scale=1))
    return written
