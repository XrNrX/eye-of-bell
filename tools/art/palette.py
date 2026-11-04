"""The art palette: loads palette.json and checks that images stick to it.

    from palette import PAL
    PAL["stone_500"]        # -> (106, 98, 114)
    PAL.ramp("stone")       # -> list of RGB tuples, dark to light
    PAL.nearest((90, 90, 90))
    PAL.check(img, "wall.png")   # raises if any opaque pixel is off-palette
"""
import json
from pathlib import Path

HERE = Path(__file__).resolve().parent
PROJECT_ROOT = HERE.parent.parent
ART_DIR = PROJECT_ROOT / "art"  # res://art/


def hex_to_rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


class Palette:
    def __init__(self, data):
        self.name = data["name"]
        self.colors = {c["name"]: hex_to_rgb(c["hex"]) for c in data["colors"]}
        self.groups = {c["name"]: c["group"] for c in data["colors"]}
        self.names = list(self.colors)
        self.allowed = set(self.colors.values())
        self._ramps = data["ramps"]
        if len(self.allowed) != len(self.names):
            raise ValueError("palette.json has duplicate colours")

    @classmethod
    def load(cls, path=HERE / "palette.json"):
        return cls(json.loads(Path(path).read_text()))

    def __getitem__(self, name):
        return self.colors[name]

    def __len__(self):
        return len(self.names)

    def ramp(self, name):
        """Colours of a named ramp (stone, wood, rust, moss, bone, torch), dark to light."""
        return [self.colors[n] for n in self._ramps[name]]

    def name_of(self, rgb):
        for n, c in self.colors.items():
            if c == tuple(rgb[:3]):
                return n
        return None

    def nearest(self, rgb):
        """The palette colour closest to rgb (plain RGB distance)."""
        r, g, b = rgb[:3]
        return min(self.allowed, key=lambda c: (c[0] - r) ** 2 + (c[1] - g) ** 2 + (c[2] - b) ** 2)

    def snap(self, img):
        """Copy of an RGBA image with every opaque pixel moved to its nearest palette colour."""
        out = img.convert("RGBA")
        px = out.load()
        cache = {}
        for y in range(out.height):
            for x in range(out.width):
                r, g, b, a = px[x, y]
                if a:
                    c = cache.setdefault((r, g, b), self.nearest((r, g, b)))
                    px[x, y] = (*c, 255)
                else:
                    px[x, y] = (0, 0, 0, 0)
        return out

    def off_palette(self, img):
        """Set of RGB colours in the image's opaque pixels that are not in the palette."""
        rgba = img.convert("RGBA")
        px = rgba.load()
        bad = set()
        for y in range(rgba.height):
            for x in range(rgba.width):
                r, g, b, a = px[x, y]
                if a and (r, g, b) not in self.allowed:
                    bad.add((r, g, b))
        return bad

    def check(self, img, label="image"):
        bad = self.off_palette(img)
        if bad:
            shown = ", ".join("#%02x%02x%02x" % c for c in sorted(bad)[:6])
            raise ValueError(f"{label}: {len(bad)} colour(s) not in the palette, e.g. {shown}")


PAL = Palette.load()
