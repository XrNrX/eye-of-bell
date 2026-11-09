"""Fix an intro shot from PixelLab, in place, before import:   python tools/art/fix_intro_shot.py FILE [--dim-moon]

create_image_pro at 640x360 returns about half its pictures inset: a complete 16:9 picture (usually about 446x251) centred in a flat
border, whatever the prompt says (docs/intro_prompts.md). This crops the border off and enlarges the picture to 640x360,
nearest-neighbour, so its pixels are coarser than a native shot's (usually 1.44x). A full-frame picture is left alone.

--dim-moon turns the moon's green pixels (top right) to dim grey, for the shots after the clouds close in (shot 6 onward).
--grey [X0 Y0 X1 Y1] takes the colour out of the whole picture or a box, for a sky that snapped tan or came out green.
"""
import argparse

from PIL import Image

W, H = 640, 360
MOON_BOX = (480, 0, 640, 70)


def fix_inset(img):
    """Returns (image, True if it was inset). Inset means every pixel of the outer margin is one flat colour."""
    rgb = img.convert("RGB")
    px = rgb.load()
    flat = px[2, 2]
    margin = 20  # Insets vary: most leave about 54 px top and bottom, one left 32.
    for y in range(H):
        for x in range(W):
            if (x < margin or x >= W - margin or y < margin or y >= H - margin) and px[x, y] != flat:
                return img, False
    xs, ys = [], []
    for y in range(H):
        for x in range(W):
            if px[x, y] != flat:
                xs.append(x)
                ys.append(y)
    box = (min(xs), min(ys), max(xs) + 1, max(ys) + 1)
    print(f"  inset picture {box[2] - box[0]}x{box[3] - box[1]}, enlarged {W / (box[2] - box[0]):.2f}x")
    return rgb.crop(box).resize((W, H), Image.NEAREST).convert("RGBA"), True


def dim_moon(img):
    px = img.load()
    count = 0
    for y in range(MOON_BOX[1], MOON_BOX[3]):
        for x in range(MOON_BOX[0], MOON_BOX[2]):
            r, g, b, a = px[x, y]
            if g > r + 12 and g > b + 8:
                v = int((r + g + b) / 3 * 0.42)
                px[x, y] = (v, v, v + 6, a)
                count += 1
    return count


def grey_out(img, box):
    """Take the colour out of a box, keeping its brightness. A mid grey that leans warm snaps to tan (bone_700), and a sky
    should not be green: the approved look keeps green to the moon and the arch's glow."""
    px = img.load()
    for y in range(box[1], box[3]):
        for x in range(box[0], box[2]):
            r, g, b, a = px[x, y]
            v = (r + g + b) // 3
            px[x, y] = (v, v, min(255, v + 20), a)  # Blue enough: a truly neutral mid grey is still nearest to bone_700.


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("file")
    ap.add_argument("--dim-moon", action="store_true")
    ap.add_argument("--grey", nargs="*", type=int, metavar="N",
                    help="take the colour out of the whole picture, or of the box X0 Y0 X1 Y1")
    args = ap.parse_args()
    img = Image.open(args.file).convert("RGBA")
    img, inset = fix_inset(img)
    moon = dim_moon(img) if args.dim_moon else 0
    if args.grey is not None:
        grey_out(img, args.grey if args.grey else (0, 0, W, H))
    img.save(args.file)
    print(f"{args.file}: {'INSET, enlarged' if inset else 'full frame'}, moon pixels dimmed {moon}")


if __name__ == "__main__":
    main()
