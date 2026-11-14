"""The Cursed Warden, the boss of the key room: art/monsters/warden/ (see DungeonMap.AMBUSHES and
data/monsters/warden.tres).

The picture is one PixelLab image (tools/art/pieces/warden.png, 96x128, drawn with create_image_pixflux: a hulking
horned undead giant in black plate with a rusted war hammer; its gold horns were recoloured to bone so torchlight
stays the only warm colour; warden_alt1.png and warden_alt2.png are the other two candidates). The frames are
made from it here, not drawn: PixelLab was asked for one pose and the movement comes from bending, stretching and
bobbing that pose (gen_tentacle.bend), so it is stiff compared with a hand-animated sprite.

    idle_0, idle_1               a slow breath
    attack_0, attack_1, attack_2   rears back, lunges at the camera, recoils
    hurt_0, hurt_flash            knocked back; the same, lit up
    walk_0 .. walk_3              a heavy stomp: bob up and down, leaning left and right
Sheet: 11 frames of 96x128 side by side (1056x128), the same order as the skeleton (idle 2, attack 3, hurt 2,
walk 4), at full resolution. With no piece, a plain dark block is drawn so the game still runs.
"""
from pathlib import Path

from PIL import Image

from artio import save_frames
from gen_tentacle import bend, lit
from palette import PAL

PIECE = Path(__file__).parent / "pieces" / "warden.png"
W, H = 96, 128


def base_image():
    if PIECE.exists():
        return Image.open(PIECE).convert("RGBA")
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    px = img.load()
    for y in range(20, H):
        for x in range(24, 72):
            px[x, y] = (*PAL["stone_700"], 255)
    return img


def bob(img, lift, lean):
    """The picture lifted `lift` pixels (both feet off the floor for a step: the game puts the lowest pixel back on
    the floor, so this reads as a bounce) and leaned `lean` pixels at the top."""
    leaned = bend(img, lean)
    out = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    out.paste(leaned, (0, -lift), leaned)
    return out


def frames():
    base = base_image()
    f = {
        "idle_0": base,
        "idle_1": bend(base, 0, stretch=1.025),
        "attack_0": bend(base, -9, stretch=1.05),
        "attack_1": bend(base, 14, stretch=0.93, grow=1.16),
        "attack_2": bend(base, 5, stretch=0.98, grow=1.05),
        "hurt_0": bend(base, -12, stretch=0.92),
        "walk_0": bob(base, 0, 3),
        "walk_1": bob(base, 3, 0),
        "walk_2": bob(base, 0, -3),
        "walk_3": bob(base, 3, 0),
    }
    f["hurt_flash"] = lit(f["hurt_0"])
    return {k: PAL.snap(v) for k, v in f.items()}


ORDER = ["idle_0", "idle_1", "attack_0", "attack_1", "attack_2", "hurt_0", "hurt_flash", "walk_0", "walk_1", "walk_2", "walk_3"]
ANIMATIONS = {"idle": ["idle_0", "idle_1"], "attack": ["attack_0", "attack_1", "attack_2"], "hurt": ["hurt_0", "hurt_flash"],
              "walk": ["walk_0", "walk_1", "walk_2", "walk_3"]}


def build(scale=None):
    """Full resolution, whatever the world scale: the art is already drawn at the in-game size."""
    return save_frames(frames(), ORDER, ANIMATIONS, "warden", scale=1)


if __name__ == "__main__":
    print(build())
