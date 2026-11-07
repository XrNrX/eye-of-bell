"""Item icons, written to res://art/items/ using only palette colours:

    <name>.png        24x24 inventory / cursor icon (x scale)
    <name>_hud.png    12x12 hand / quick slot icon (x scale)
    <name>_floor.png  12x12 version drawn on the floor at the feet of the view (3D, not scaled)

Items: short_sword, mace, leather_armour, healing_potion, scroll, dagger, darts,
spellbook, holy_symbol. The floor versions of the dagger and darts double as the
sprite that flies down the corridor when one is thrown.

How it works
- Each item is a list of parts. A part is a shape plus a colour ramp. Shapes are
  analytic inside-tests in a 24x24 coordinate system (segments, discs, rectangles),
  sampled at pixel centres, so exactly the same drawing renders at 24px and at 12px.
- Every part is shaded on its own with the toolkit's top-left lighting, later parts
  paint over earlier ones, then the toolkit adds a 1px ink outline.
- Keep shapes at least ~2 units thick and inside [2, 22) so they survive at 12px and
  leave room for the outline.
- The palette has no pure red, so the healing potion's "red" liquid is the rust ramp.
"""
import math

from PIL import Image

from artio import save_png
from lighting import shade_mask
from outline import add_outline
from palette import PAL

ICON = 24
FLOOR = 12

# Colour ramps, dark to light.
STEEL = [PAL["stone_500"], PAL["stone_300"], PAL["stone_100"]]
IRON = [PAL["stone_700"], PAL["stone_500"], PAL["stone_300"]]
GLASS = [PAL["stone_700"], PAL["stone_500"], PAL["stone_300"]]
GOLD = [PAL["torch_700"], PAL["torch_500"], PAL["torch_300"]]
WOOD = [PAL["wood_700"], PAL["wood_500"], PAL["leather_400"]]
LEATHER = [PAL["wood_500"], PAL["leather_400"], PAL["bone_700"]]
DARK = [PAL["soil_900"], PAL["soil_900"], PAL["wood_700"]]
LIQUID = PAL.ramp("rust")
PARCHMENT = PAL.ramp("bone")
PAPER_DARK = [PAL["bone_700"], PAL["bone_700"], PAL["bone_500"]]
GLINT = [PAL["bone_500"], PAL["bone_300"], PAL["bone_300"]]


# --------------------------------------------------------------------------
# Shapes: functions (x, y) -> bool in 24x24 space
# --------------------------------------------------------------------------

def seg(p0, p1, width):
    """A thick line segment with rounded ends."""
    (x0, y0), (x1, y1) = p0, p1
    dx, dy = x1 - x0, y1 - y0
    length2 = dx * dx + dy * dy

    def inside(x, y):
        t = max(0.0, min(1.0, ((x - x0) * dx + (y - y0) * dy) / length2)) if length2 else 0.0
        return math.hypot(x - (x0 + t * dx), y - (y0 + t * dy)) <= width / 2

    return inside


def disc(cx, cy, r):
    return lambda x, y: math.hypot(x - cx, y - cy) <= r


def rect(x0, y0, x1, y1):
    return lambda x, y: x0 <= x < x1 and y0 <= y < y1


def union(*shapes):
    return lambda x, y: any(s(x, y) for s in shapes)


def both(a, b):
    return lambda x, y: a(x, y) and b(x, y)


# --------------------------------------------------------------------------
# Items: lists of (shape, ramp), drawn in order
# --------------------------------------------------------------------------

def short_sword():
    return [
        (seg((9, 15), (17, 7), 3.8), STEEL),                      # Blade...
        (seg((17, 7), (20.5, 3.5), 2.2), STEEL),                  # ...tapering to the tip.
        (seg((10, 14), (17, 7), 1.0), IRON),                      # Fuller down the middle.
        (seg((5.5, 12.5), (11.5, 18.5), 2.6), GOLD),              # Crossguard.
        (seg((7.8, 16.2), (4.8, 19.2), 2.6), WOOD),               # Grip.
        (disc(4.0, 20.0, 1.7), GOLD),                             # Pommel.
    ]


def mace():
    head = (15.5, 8.5)
    spikes = []
    for deg in range(0, 360, 45):
        a = math.radians(deg)
        spikes.append(seg((head[0] + 3.4 * math.cos(a), head[1] + 3.4 * math.sin(a)),
                          (head[0] + 5.9 * math.cos(a), head[1] + 5.9 * math.sin(a)), 1.9))
    return [
        (seg((4.8, 19.4), (13, 11.2), 2.8), WOOD),                # Handle.
        (seg((11.4, 12.8), (13.4, 10.8), 3.2), GOLD),             # Collar under the head.
        (union(*spikes), IRON),                                   # Spikes.
        (disc(head[0], head[1], 4.3), IRON),                      # Head.
        (disc(head[0] - 1.2, head[1] - 1.2, 1.4), STEEL),         # A bright spot on it.
    ]


def war_hammer():
    """A long handle and a heavy square steel head with a blunt face and a spiked peen: the
    heavy weapon that can break a cracked wall."""
    return [
        (seg((4.6, 19.6), (14.2, 10.0), 2.8), WOOD),              # Haft.
        (seg((11.0, 6.0), (18.0, 13.0), 6.4), IRON),              # Head.
        (seg((11.2, 6.2), (8.6, 3.6), 2.0), STEEL),               # Peen spike.
        (disc(18.0, 13.0, 2.6), STEEL),                           # Striking face.
        (seg((12.6, 7.6), (16.4, 11.4), 1.6), STEEL),             # A bright edge along the head.
        (seg((12.2, 12.0), (14.6, 9.6), 3.6), GOLD),              # Collar binding head to haft.
    ]


def leather_armour():
    return [
        (rect(3.5, 5.5, 8.5, 12), LEATHER),                       # Left sleeve.
        (rect(15.5, 5.5, 20.5, 12), LEATHER),                     # Right sleeve.
        (rect(6.5, 5.5, 17.5, 20), LEATHER),                      # Tunic body.
        (rect(5.5, 17, 18.5, 21), LEATHER),                       # Flared hem.
        (disc(12, 6.3, 2.5), DARK),                               # Neck opening.
        (seg((12, 8.5), (12, 13), 0.9), DARK),                    # Centre seam.
        (rect(6.5, 13, 17.5, 15.2), DARK),                        # Belt.
        (rect(10.6, 12.8, 13.4, 15.4), GOLD),                     # Buckle.
    ]


def healing_potion():
    bulb = disc(12, 15, 6.5)
    liquid = both(disc(12, 15, 5.4), lambda x, y: y >= 12.8)
    return [
        (union(bulb, rect(10, 6, 14, 10.5)), GLASS),              # Round flask and neck.
        (rect(9, 5, 15, 6.9), STEEL),                             # Lip.
        (rect(10, 2.5, 14, 5.3), WOOD),                           # Cork.
        (liquid, LIQUID),                                         # The red liquid.
        (seg((8.7, 14.6), (9.5, 17.6), 1.4), GLINT),              # Glint on the glass.
    ]


def scroll():
    return [
        (rect(5, 8, 19, 16), PARCHMENT),                          # The sheet.
        (rect(3.5, 6, 7, 18), PAPER_DARK),                        # Left roll.
        (rect(17, 6, 20.5, 18), PAPER_DARK),                      # Right roll.
        (seg((5.2, 8), (5.2, 16), 0.9), DARK),                    # Curl of the left roll.
        (seg((18.8, 8), (18.8, 16), 0.9), DARK),                  # Curl of the right roll.
        (seg((8.5, 10.2), (15.5, 10.2), 1.0), DARK),              # Writing.
        (seg((8.5, 12.2), (13.5, 12.2), 1.0), DARK),
        (seg((8.5, 14.2), (14.5, 14.2), 1.0), DARK),
        (disc(15.5, 16.5, 2.4), LIQUID),                          # Wax seal.
    ]


def scroll_resurrection():
    """The scroll with a faint gold seal and cord (gold is the holy colour, not the curse green)."""
    parts = scroll()[:-1]
    parts.append((disc(15.5, 16.5, 2.4), GOLD))  # Wax seal, in gold.
    parts.append((seg((12.5, 8), (12.5, 16), 0.6), GOLD))  # A thin gold cord round the middle.
    return parts


def dagger():
    return [
        (seg((10, 14), (18.5, 5.5), 2.8), STEEL),                 # Short blade...
        (seg((18.5, 5.5), (20.5, 3.5), 1.6), STEEL),              # ...to a point.
        (seg((7, 13), (11, 17), 2.4), IRON),                      # Small crossguard.
        (seg((8.6, 15.4), (5.2, 18.8), 2.4), LEATHER),            # Wrapped grip.
        (disc(4.6, 19.4, 1.5), IRON),                             # Pommel.
    ]


def darts():
    """A bundle of three darts, fanned."""
    parts = []
    for (x0, y0), (x1, y1) in (((5, 18), (17, 6)), ((7, 20), (20, 9)), ((4, 15), (14, 4))):
        parts.append((seg((x0, y0), (x0 + (x1 - x0) * 0.35, y0 + (y1 - y0) * 0.35), 2.6), LIQUID))  # Fletching.
        parts.append((seg((x0, y0), (x1, y1), 1.4), WOOD))                                         # Shaft.
        parts.append((seg((x1 - (x1 - x0) * 0.15, y1 - (y1 - y0) * 0.15), (x1, y1), 2.0), STEEL))  # Tip.
    return parts


def spellbook():
    return [
        (rect(4.5, 4, 19.5, 20), PARCHMENT),                      # Page edges, under the cover.
        (rect(4, 3, 18, 19.5), LEATHER),                          # Cover.
        (rect(4, 3, 6.5, 19.5), DARK),                            # Spine.
        (disc(12, 11, 3.6), GOLD),                                # Gold seal on the cover...
        (disc(12, 11, 1.6), LIQUID),                              # ...with a rust gem.
        (rect(16, 9.5, 20, 12.5), GOLD),                          # Clasp.
    ]


def holy_symbol():
    return [
        (seg((12, 2.5), (12, 6.5), 1.2), IRON),                   # Loop for the chain.
        (seg((12, 6), (12, 21.5), 3.6), GOLD),                    # Upright of the cross.
        (seg((5.5, 11.5), (18.5, 11.5), 3.6), GOLD),              # Arms.
        (disc(12, 11.5, 2.6), GOLD),
        (disc(12, 11.5, 1.3), PARCHMENT),                         # A pale stone in the middle.
    ]


def stale_bread():
    """Placeholder (replaced by PixelLab art): a dry loaf."""
    return [(union(rect(5, 10, 19, 18), disc(12, 10, 7)), WOOD)]


def dried_meat():
    """Placeholder (replaced by PixelLab art): a strip of jerky."""
    return [(seg((7, 17), (17, 7), 3.6), LEATHER)]


def hard_cheese():
    """Placeholder (replaced by PixelLab art): a wedge."""
    return [(rect(5, 9, 19, 17), GOLD)]


def withered_apple():
    """Placeholder (replaced by PixelLab art): a shrivelled apple."""
    return [(disc(12, 13, 6.5), LIQUID)]


def mouldy_bread():
    """Placeholder (replaced by PixelLab art): bread with a green tinge."""
    return [(union(rect(5, 10, 19, 18), disc(12, 10, 7)), PAPER_DARK)]


ITEMS = {
    "short_sword": short_sword,
    "mace": mace,
    "war_hammer": war_hammer,
    "leather_armour": leather_armour,
    "healing_potion": healing_potion,
    "scroll": scroll,
    "dagger": dagger,
    "scroll_resurrection": scroll_resurrection,
    "darts": darts,
    "spellbook": spellbook,
    "holy_symbol": holy_symbol,
    "stale_bread": stale_bread,
    "dried_meat": dried_meat,
    "hard_cheese": hard_cheese,
    "withered_apple": withered_apple,
    "mouldy_bread": mouldy_bread,
}


def render(parts, size):
    """Rasterise the parts at `size` px (24 = full icon, 12 = floor version)."""
    k = size / ICON
    pixels = {}
    for shape, ramp in parts:
        mask = {(x, y) for y in range(size) for x in range(size)
                if shape((x + 0.5) / k, (y + 0.5) / k)}
        if mask:
            pixels.update(shade_mask(mask, ramp))
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    px = img.load()
    for (x, y), colour in pixels.items():
        px[x, y] = (*colour, 255)
    return add_outline(img, PAL["ink"])


def holy_symbol_glow():
    """The cleric's holy symbol glowing: three frames side by side (dim, medium, bright), each
    16x16 logical (32x32 once enlarged: the size of a hand button), drawn over the symbol's own
    24x24 hand icon with ADDITIVE blending in the party panel. Gold is kept to the glow: only some
    of the symbol's lit pixels turn torch gold (more of them as the glow strengthens), so the
    metal still looks worn, and a halo of torch-coloured rings spreads around the silhouette.
    Built from art/items/holy_symbol_hud.png, so it follows whatever art the symbol has."""
    from pathlib import Path
    from artio import ART_DIR
    src = Image.open(Path(ART_DIR) / "items" / "holy_symbol_hud.png").convert("RGBA")
    logical = src.resize((src.width // 2, src.height // 2), Image.NEAREST)  # Back to logical pixels (12x12).
    w, h = logical.size
    ox, oy = (16 - w) // 2, (16 - h) // 2
    aura = {PAL["curse_700"], PAL["moss_700"]}  # The icon's own faint green glow is not part of the symbol.
    solid = {(x + ox, y + oy) for y in range(h) for x in range(w)
             if logical.getpixel((x, y))[3] > 0 and logical.getpixel((x, y))[:3] not in aura}
    colours = {(x + ox, y + oy): logical.getpixel((x, y))[:3] for y in range(h) for x in range(w) if (x + ox, y + oy) in solid}
    ink = PAL["ink"]
    inside = {p for p in solid if colours[p] != ink}

    def ring(cells, steps):
        """Cells within `steps` of the silhouette, not in it (4-neighbour spread)."""
        out = {}
        frontier = set(cells)
        for d in range(1, steps + 1):
            nxt = set()
            for (x, y) in frontier:
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    q = (x + dx, y + dy)
                    if 0 <= q[0] < 16 and 0 <= q[1] < 16 and q not in cells and q not in out:
                        out[q] = d
                        nxt.add(q)
            frontier = nxt
        return out

    halo = ring(solid, 2)
    sheet = Image.new("RGBA", (48, 16), (0, 0, 0, 0))
    spec = [  # (symbol pixels turned gold, ring colours by distance)
        (0.40, {1: PAL["torch_700"]}),
        (0.70, {1: PAL["torch_500"], 2: PAL["torch_700"]}),
        (1.00, {1: PAL["torch_300"], 2: PAL["torch_500"]}),
    ]
    for f, (share, rings) in enumerate(spec):
        px = sheet.load()
        for (x, y), d in halo.items():
            if d in rings and (d == 1 or (x + y) % 2 == 0):  # The outer ring is dithered, so it reads as a glow, not a blob.
                px[f * 16 + x, y] = (*rings[d], 255)
        for (x, y) in inside:
            if ((x * 7 + y * 13) % 10) / 10.0 < share:
                lit = sum(colours[(x, y)]) > 3 * 110  # Light metal goes bright gold, dark metal a deeper gold.
                px[f * 16 + x, y] = (*(PAL["torch_300"] if lit else PAL["torch_500"]), 255)
    return sheet


def build(scale=2):
    """Per item: <name>.png (24x24 logical: inventory slots and the cursor), <name>_hud.png
    (12x12 logical: hand and quick slots on the party panel) -- both enlarged `scale` times to
    match the UI's pixel size -- and <name>_floor.png (the full icon drawing at 48x48: the sprite
    in the 3D world, whose view is drawn at 1:1, so it needs the detail. Always enlarged 2x, whatever
    `scale` is, because each item's `icon_pixel_size` in its .tres (0.01) is set for 48 px)."""
    written = []
    for name, make in ITEMS.items():
        parts = make()
        written.append(save_png(render(parts, ICON), f"items/{name}.png", scale=scale))
        written.append(save_png(render(parts, FLOOR), f"items/{name}_hud.png", scale=scale))
        written.append(save_png(render(parts, ICON), f"items/{name}_floor.png", scale=2))
    # The key's sprite lives in gen_sprites (it is also the 3D floor sprite); its inventory
    # icon is that same drawing, enlarged.
    from gen_sprites import key_sprite
    written.append(save_png(key_sprite(), "items/key.png", scale=scale))
    written.append(save_png(holy_symbol_glow(), "items/holy_symbol_glow.png", scale=2))
    return written
