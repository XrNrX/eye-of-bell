# PixelLab inbox

Drop PixelLab exports (PNG) here, then run

    python tools/art/import_pixellab.py --dry-run     # see what would happen
    python tools/art/import_pixellab.py               # do it

Each image is snapped to the palette, resized (nearest-neighbour) to the size of the art it
replaces, renamed to that art's file name, and written into `art/`. The procedural original goes to
`tools/art/_old/` (first time only) and the file is protected from `build_all.py`. Processed files
move to `_done/`.

Art made through the PixelLab MCP tools goes the same way: save the generated image or sheet
here under the key's name (below), then import it. Nothing is written into `art/` directly.

Name files so they can be recognised: `python tools/art/import_pixellab.py --list` prints every key
(`tiles/wall`, `items/dagger_hud`, `portraits/fighter/portrait`, `monsters/skeleton/idle_0`,
`monsters/skeleton/skeleton_sheet`, `sprites/torch`...). A file may be named by its key
(`tiles/wall.png` as a path, or flat `wall.png`), or listed in `map.json`:

    {"my_export_17.png": "tiles/wall"}

For a sprite sheet with a different number of frames, add a layout file next to it,
`skeleton_sheet.layout.json`:

    {"idle": 4, "attack": 3, "hurt": 2}

See the top of `tools/art/import_pixellab.py` for everything.
