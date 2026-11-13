"""The ambush tentacle: art/monsters/tentacle/, a kraken-like tentacle that bursts out of a wall (see
DungeonMap.AMBUSHES and data/monsters/tentacle.tres).

The picture is one PixelLab image (tools/art/pieces/tentacle.png, 96x128, drawn with create_image_pixflux; the
dark one, tentacle_alt.png, is the alternative). The frames are made from it here, not drawn: PixelLab was asked
for one pose and the movement comes from bending and scaling that pose, so it is stiff compared with the
skeleton's hand-animated frames.

    idle_0, idle_1, idle_2      sways (idle_frames 0, 1, 0, 2)
    attack_0, attack_1, attack_2  rears back, lunges at the camera, recoils
    hurt_0, hurt_flash          knocked back; the same, lit up
Sheet: 8 frames of 96x128 side by side (768x128), at full resolution (not doubled), like the other
PixelLab monsters. With no piece, a plain dark column is drawn so the game still runs.
"""
from pathlib import Path

from PIL import Image

from artio import save_frames
from palette import PAL

PIECE = Path(__file__).parent / "pieces" / "tentacle.png"
W, H = 96, 128


def base_image():
    if PIECE.exists():
        return Image.open(PIECE).convert("RGBA")
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    px = img.load()
    for y in range(20, H):
        for x in range(38, 58):
            px[x, y] = (*PAL["bruise_700"], 255)
    return img


def bend(img, amount, stretch=1.0, grow=1.0):
    """Lean the picture: each row slides sideways by `amount` pixels times how far up it is (the base stays put),
    then it is stretched taller (`stretch`) and wider (`grow`) about the bottom centre. Nearest neighbour only,
    so the pixels stay crisp, and the lowest pixel stays on the floor."""
    out = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    src = img.load()
    dst = out.load()
    for y in range(H):
        sy = H - 1 - (H - 1 - y) / stretch  # Which source row lands on this row.
        iy = int(round(sy))
        if not 0 <= iy < H:
            continue
        lean = amount * ((H - 1 - y) / (H - 1))
        for x in range(W):
            sx = W / 2 + (x - W / 2) / grow - lean
            ix = int(round(sx))
            if 0 <= ix < W:
                dst[x, y] = src[ix, iy]
    return out


def lit(img):
    """The hurt flash: every light pixel goes to bone_300 / stone_100, so the whole body flares."""
    out = img.copy()
    px = out.load()
    ink = PAL["ink"]
    for y in range(H):
        for x in range(W):
            r, g, b, a = px[x, y]
            if a and (r, g, b) != ink:
                lum = (0.3 * r + 0.59 * g + 0.11 * b)
                px[x, y] = (*(PAL["bone_300"] if lum > 70 else PAL["stone_100"]), 255)
    return out


def frames():
    base = base_image()
    f = {
        "idle_0": base,
        "idle_1": bend(base, 5),
        "idle_2": bend(base, -5),
        "attack_0": bend(base, -12, stretch=0.92),
        "attack_1": bend(base, 16, stretch=1.14, grow=1.22),
        "attack_2": bend(base, 6, stretch=1.05, grow=1.08),
        "hurt_0": bend(base, -14, stretch=0.9),
    }
    f["hurt_flash"] = lit(f["hurt_0"])
    return {k: PAL.snap(v) for k, v in f.items()}


ORDER = ["idle_0", "idle_1", "idle_2", "attack_0", "attack_1", "attack_2", "hurt_0", "hurt_flash"]
ANIMATIONS = {"idle": ["idle_0", "idle_1", "idle_2"], "attack": ["attack_0", "attack_1", "attack_2"], "hurt": ["hurt_0", "hurt_flash"]}


def build(scale=None):
    """Full resolution, whatever the world scale: the art is already drawn at the in-game size."""
    return save_frames(frames(), ORDER, ANIMATIONS, "tentacle", scale=1)


if __name__ == "__main__":
    print(build())
