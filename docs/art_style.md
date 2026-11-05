# Eye of Bell: art style guide

For anyone (a person, or a Claude session) writing PixelLab prompts or drawing art for this
game. Follow it for **all** art, and add the [prompt suffix](#the-prompt-suffix) to **every**
PixelLab request.

## The look in one paragraph

The lands are cursed, and so is everything in them. It is a 1991 dungeon crawler that has gone
rotten: very dark, gloomy and moody, seen through a small first-person window. Cold desaturated
greys, deep near-black shadows and damp brown wood and soil make up almost everything. The curse
shows in a few accent colours used sparingly: a **sickly pale green glow** (the main curse
colour), **bruised purple** and **dried-blood red**. The only warm colour is the party's own
torchlight, and it is weak. Nothing is clean, bright, cute or heroic.

## Palette

The palette is `tools/art/palette.json` (currently the original **24-colour** "Dark Stone Dungeon").
Every game image uses only these colours; the importer snaps anything else to the nearest one
(nearest colour, no dithering unless asked), so prompt for the *mood* and let the snap do the
exact values.

| Role | Names (dark to light) |
|---|---|
| Near-black and cold greys | `ink`, `stone_900`, `stone_800`, `stone_700`, `stone_500`, `stone_300`, `stone_100` |
| Damp browns (wood, soil, leather) | `soil_900`, `wood_700`, `wood_500`, `leather_400` |
| Rust (old iron, old fire) | `rust_700`, `rust_500`, `rust_300` |
| Dead moss, rot and the **curse green** | `moss_900`, `moss_700`, `moss_500`, `slime_300` |
| Old bone (dirty, never white) | `bone_700`, `bone_500`, `bone_300` |
| **Torchlight** (the only warm light) | `torch_700`, `torch_500`, `torch_300` |

**The curse accents.** The intended look uses a sickly pale green glow (the main curse colour),
bruised purple and dried-blood red, sparingly. Today only the green exists (the `moss_*` and
`slime_300` ramp); there is no purple and no true blood red in `palette.json`. A darker, colder
32-colour palette that adds `curse_*`, `bruise_*` and `blood_*` was proposed and **not applied**
(it is kept in a git stash); until a palette change is approved, approximate purple with
`stone_700`/`stone_800` and blood with `rust_700`.

How much of each: in any picture, greys and browns should be roughly 80% or more of the pixels.
The curse accents together are **a few percent**, placed where they mean something (eyes, veins,
runes, a glow around a magic thing, rot in a crack). If the accents are everywhere they stop being
a curse and become decoration.

## Light

- Light comes from **one side or above** and falls off quickly into darkness: a small pool of
  dim warm torchlight, then deep shadow. Lit surfaces face the top-left.
- Deep shadows. Never bright, flat, even lighting, and never a lit-from-everywhere look.
- Torchlight is the only warm colour and it is weak: dull amber, not golden or cheerful.
- Magic and curses give off their own faint **cold green** light (sometimes bruised purple),
  which is how they read in the dark.

## Monsters

Visibly cursed, unnatural, wrong, decayed. Never cute, never cartoonish, never friendly-looking.

- Glowing **green eyes** or **embers** in the sockets (curse green, sometimes a dim torch ember).
- **Corruption veins** (thin curse-green or bruised-purple lines under cracked skin or bone).
- Rot, **cracked or blackened** surfaces, missing chunks, dried blood stains.
- **Rusted chains**, rusted and notched weapons, scraps of rotted cloth and leather.
- Faint **runes** carved or burned into bone and armour, glowing a little.
- Proportions slightly off: too long, too thin, too still. A skeleton is not a cartoon skull;
  a slime is not a happy blob: it is a pool of something that was once alive.

## Environment

- Ancient **ruined masonry**: stone blocks, damp, stained, cracked, chipped.
- Creeping **rot and roots** breaking through stone; dead moss; wet streaks.
- Scattered **bones**, old blood, scratches, soot.
- **Faded carvings** of something once grand (a crest, a face, a border) that are now worn and
  half gone. The place was magnificent once; it is not any more.

## Items and UI

- Worn, battered, rusty, stained. Notched blades, cracked leather, tarnished metal, dented
  hilts. Nothing shiny and nothing new.
- Magic things (scrolls, potions, focus items, spells) carry a **faint curse glow**: curse green
  for the curse itself, bruised purple for the arcane, a dim torch glow for healing and holy.
- UI frame and icons are the same worn dark stone and iron as the dungeon, with the same
  1px dark outlines. Text and highlights use the palette's lightest greys and `torch_500`.

## Readability rule

**Dark does not mean invisible.** Every monster and item must read against the darkest wall.

1. A **clear silhouette** (a distinct outline shape, not a smear).
2. A **1px dark outline** (`ink`) all round.
3. A hint of **rim light or glow**: usually curse green, on the lit edge or in the eyes, so the
   shape separates from a dark background.

If a sprite disappears when placed on `stone_900`, it fails this rule: raise its rim light, not
the overall brightness.

## Technical rules

- **Limited palette** (`palette.json`, above). No colours outside it.
- **1px dark outlines** (`ink`, `#0b0a10`) around every sprite and icon.
- **No anti-aliasing**: hard pixel edges, no soft gradients, no blur, no painterly shading.
  Shading is dithered or banded in flat colours.
- **Monsters face the viewer** (front-facing, south) because the game is first-person.
- **Transparent background** for monsters, sprites and items (tiles and the UI frame fill their
  whole canvas).
- **Resolution.** The 3D view is rendered at **416x260, exactly the pixels it occupies on the
  640x360 base screen (1:1, nearest filtering)**. 3D art is drawn at **double** the old size so it
  carries more detail: a skeleton standing one tile in front of the player is about **150 screen
  pixels tall**, drawn from a **128-pixel-tall** sprite, so each art pixel is roughly one screen
  pixel. The UI is still drawn at 2x (each logical pixel is a 2x2 block). Never blur or smooth when
  resizing: **nearest-neighbour only**.

### Exact target sizes

Generate at the **native size** in the "make it this size" column and let the importer
(`python tools/art/import_pixellab.py`) snap the palette, resize and apply the 2x UI scale. The
importer reads its targets from the existing files in `art/`, so `import_pixellab.py --list` is
always the authority (and these numbers are what it prints).

**3D art (doubled: `--world-scale 2` in the generators, monster `pixel_size` halved so they keep the
same size in the world):**

| Asset | Make it this size | Game file | Notes |
|---|---|---|---|
| Wall, floor, ceiling, door, locked door, cracked wall, portcullis, plate, stairs tiles | **128x128** | 128x128 | Seamless where they tile (wall, floor, ceiling). The portcullis has a transparent background (bars only). The cracked wall carries a crack in each of the six cells a box face can show (see `gen_tiles.py`). |
| Skeleton, skeleton guard monster frames | **96x128** each | 96x128 | Front-facing, `pixel_size` 0.014. Sheet = 7 frames side by side (672x128): idle x2, attack x3, hurt x2 (hurt, flash). |
| Slime, acid slime monster frames | **96x96** each | 96x96 | Front-facing, `pixel_size` 0.02. Sheet = 8 frames (768x96): idle x3, attack x3, hurt x2. |

**3D art that is not doubled yet** (same world size, so it simply keeps its old pixel density next to the new art):
torch sheet 4 frames of 16x32 (64x32), lever sheet 2 frames of 16x16 (32x16), key floor sprite 16x16,
item floor sprites 12x12 (`*_floor`, NOT enlarged), and the spell effect bolt (7x7).

**UI art (drawn at 2x; make it the "logical" size and the importer doubles it):**

| Asset | Make it this size | Game file (after import) | Notes |
|---|---|---|---|
| Item inventory icon (sword, mace, hammer, armour, potion, scroll...) | **24x24** | 48x48 (2x) | |
| Item hand and quick-slot icon (`*_hud`) | **12x12** | 24x24 (2x) | |
| Key (inventory) | **16x16** | 32x32 (2x) | |
| Hero portraits (living, hurt, dead) | **32x32** each | 64x64 (2x) | Three stills per hero, not an animation. |
| Movement arrows (and pressed versions) | **16x16** | 32x32 (2x) | |
| Hand button | **24x24** / small **16x16** | 48x48 / 32x32 (2x) | |
| Quick slot (and empty, sweep) | **14x14** | 28x28 (2x) | |
| UI frame | **320x180** | 640x360 (2x) | The stone frame; its 3D-view hole must stay exactly where it is (416x260 at 8,8). |
| Digit strip (stack counts) | **50x7** | 100x14 (2x) | |

PixelLab cannot always make an exact size; generate at the nearest size it allows (an exact
multiple is best; `create_image_pixflux` takes up to 400 per side, `create_object_pro_flash`
multiples of 4 up to 256), and the importer will warn if an image is far bigger than its target.

## Avoid

- Bright, saturated colours; pure white; pure black fills (use `ink` and the dark greys).
- Clean, new, polished, shiny surfaces.
- A heroic, cheerful, cute or comic tone; big round friendly eyes.
- Soft painterly gradients, smooth airbrushing, glow halos with soft edges, anti-aliased edges.
- Warm light everywhere (torchlight is the *only* warm colour) and flat even lighting.
- Three-quarter or side views for monsters and anything else the player sees head-on.

## The prompt suffix

Add this to **every** PixelLab request, after the description of the thing:

```
dark cursed dungeon, gloomy, desaturated cold greys, deep near-black shadows, sickly pale green curse glow, decayed and rotten, 1991 pixel art, 1px dark outline, no anti-aliasing, limited palette, front view
```

Short form: `dark cursed dungeon, gloomy, desaturated, sickly green curse glow, decayed, 1991 pixel art, 1px dark outline, no anti-aliasing`

### Per-asset prompt starters

Write the subject first, then the suffix.

- **Monster:** `a cursed <creature>, glowing green eyes, corruption veins, cracked blackened
  <bone/skin>, rusted chains, faint glowing runes, facing the viewer, full body, idle pose,
  <suffix>`
- **Tile:** `<ancient ruined stone wall / flagstone floor / ...>, damp and stained, creeping rot
  and roots, faded carvings, seamless tile, <suffix>`
- **Item:** `a worn rusty <item>, battered and stained, faint green curse glow, single object,
  transparent background, <suffix>`
- **Portrait:** `a haggard <class> hero, hollow eyes, dirty and bruised, a hint of the curse in
  one eye, front-facing bust, <suffix>`

### PixelLab settings that help

Transparent background on (monsters, items, sprites); a single-colour dark outline; flat or low
shading rather than smooth; low-to-medium detail so edges stay clean at 48x64; a front-facing
view. Always follow the readability rule above (outline plus rim glow).

## Workflow

1. Prompt with the subject and the suffix above.
2. Save the result in `tools/art/inbox/` under the asset's key (`import_pixellab.py --list`).
3. `python tools/art/import_pixellab.py --dry-run`, then the real run: it snaps to the palette,
   resizes with nearest-neighbour, applies the 2x UI scale, slices sheets, backs up the
   procedural original to `tools/art/_old/` and reports mismatches.
4. Look at it in the game, in a dark corridor and next to the existing procedural art, before
   generating more. Style is approved one asset type at a time.

The procedural generators in `tools/art/` follow the same palette, so procedural and PixelLab art
share one look until the procedural ones are replaced.
