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

The palette is `tools/art/palette.json` (32 colours, "Cursed Dungeon 32"). Every game image uses
only these colours; the importer snaps anything else to the nearest one (nearest colour, no
dithering unless asked), so prompt for the *mood* and let the snap do the exact values.

| Role | Names (dark to light) | Hex |
|---|---|---|
| Near-black and cold greys | `ink`, `stone_900`, `stone_800`, `stone_700`, `stone_500`, `stone_300`, `stone_100` | `#0b0a10` `#14131b` `#1f1e28` `#31303c` `#504f5e` `#7b7a88` `#aaa9b4` |
| Damp browns (wood, soil, leather) | `soil_900`, `wood_700`, `wood_500`, `leather_400` | `#1c1511` `#33261c` `#4f3a28` `#74553a` |
| Rust (dull, old iron and old fire) | `rust_700`, `rust_500`, `rust_300` | `#4e2a1a` `#7c4426` `#a8673a` |
| Dead moss and rot | `moss_900`, `moss_700`, `moss_500`, `slime_300` | `#161e1a` `#26382c` `#44624a` `#86a672` |
| Old bone (dirty, never white) | `bone_700`, `bone_500`, `bone_300` | `#6b6250` `#9c9278` `#c9c0a4` |
| **Torchlight** (the only warm light) | `torch_700`, `torch_500`, `torch_300` | `#9a5f1c` `#d99a36` `#f5cf80` |
| **Curse green** (the main accent) | `curse_700`, `curse_500`, `curse_300` | `#3a6b4c` `#7fb88a` `#cdeec0` |
| **Bruised purple** (accent) | `bruise_900`, `bruise_700`, `bruise_500` | `#1e1428` `#3b2850` `#6a4a86` |
| **Dried blood** (accent) | `blood_700`, `blood_500` | `#4a1418` `#7a2224` |

How much of each: in any picture, greys and browns should be roughly 80% or more of the pixels.
The three curse accents together are **a few percent**, placed where they mean something (eyes,
veins, runes, a glow around a magic thing, rot in a crack). If the accents are everywhere they
stop being a curse and become decoration. In particular: a creature's body is **grey or dark**, not
green; the green is in its eyes, runes and cracks.

Two lessons from the first test sprite: an image generator will happily make a whole skeleton pale
curse green if "green" is in the prompt (ask for grey, blackened bones and put the green only in
the eyes, runes and cracks), and "rusted chains" can come back as amber or gold specks (warm
colours are for torchlight only: ask for dark iron chains).

## Spell colour language

Every kind of magic has one colour, so players read a spell at a glance. These are fixed:

| Magic | Colour | Where it shows |
|---|---|---|
| Fire | **orange** (torch and rust tones, white-hot core) | Fireball, embers, scorch |
| Holy | **gold** (torch_300 / torch_500) | Heal, Bless, the holy symbol, Resurrection |
| Arcane | **cold pale blue** | Magic Missile, the Mage's other spells |
| Curse | **sickly green** (curse_500 / curse_300) | cracks, veins, the dead: **never used for a spell**, so green always reads as danger |

The palette has no blue, so arcane art is drawn in neutral grey and bone (stone_100 / bone_300 for the bright parts) and the game
tints it blue at run time (a tint above 1.0 so it blooms), with a pale blue light. Draw spell flipbooks with those greys, not with
blue pixels, or the palette snap turns them green or purple.

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
- **Resolution.** The 3D view is rendered at **416x260, twice the old 208x130 and exactly the
  pixels it occupies on the 640x360 base screen (1:1, nearest filtering)**. 3D art is drawn at **double** the old size so it
  carries more detail: a skeleton standing one tile in front of the player is about **150 screen
  pixels tall**, drawn from a **128-pixel-tall** sprite, so each art pixel is roughly one screen
  pixel. The UI is still drawn at 2x (each logical pixel is a 2x2 block). Never blur or smooth when
  resizing: **nearest-neighbour only**.

### UI pixel density

**The hero portraits set the standard: one art pixel is one screen pixel (64x64 art shown at 64x64).** Party panel art matches
that, drawn 1:1 with no 2x blocks: slot frames (`quickslot`, `quickslot_empty` 28x28, `handslot` 32x32, a 2 px worn bevel with
a 2 px inner shadow, `gen_ui.bevel_frame`), the name scroll (16x16), the stack-count digits (Press Start 2P's own 8x8 digits)
and item icons in hand and quick slots. **Hand buttons are 40x40 and quick slots 36x36; the icon (`*_hud`) is a native 32x32
PixelLab image, so it fits the quick slot's inside exactly and sits centred with a 2 px margin in a hand button. The weapons
(short sword, war hammer, mace, dagger, darts) are 32x32 now; every other item's `*_hud` is still 24x24, drawn centred, until it
is redone** (generate 32x32, keep the outline, and put the piece in `tools/art/pieces/items32/`; add the name to `NATIVE32` in
`regrade_items.py`). The hand cooldown is a clock wipe over the button, not a bar. Text is Press Start 2P at its native 8 px with a 1 px ink
drop shadow, never scaled or smoothed (`antialiasing=0`, `hinting=0`). HP, mana and cooldown bars are flat 1:1 rectangles. Still
drawn at 2x blocks and so coarser than the portraits: the main screen frame, the movement arrows, the quick-slot cooldown sweep
and the inventory's frames. New party-panel art should be made 1:1; do not draw it on a half-size grid and enlarge it.

### Exact target sizes

Generate at the **native size** in the "make it this size" column and let the importer
(`python tools/art/import_pixellab.py`) snap the palette, resize and apply the 2x UI scale. The
importer reads its targets from the existing files in `art/`, so `import_pixellab.py --list` is
always the authority (and these numbers are what it prints).

**3D art (doubled: `--world-scale 2` in the generators, monster `pixel_size` halved so they keep the
same size in the world):**

| Asset | Make it this size | Game file | Notes |
|---|---|---|---|
| Wall, floor, ceiling, door, locked door, cracked wall, portcullis, plate, stairs tiles | **128x128** | 128x128 | Make them at a true 128x128. **The current floor and ceiling are 64x64 images enlarged 2x**, so their pixels are twice as coarse as the other tiles' and the monsters'; every other tile is a true 128x128. Seamless where they tile (wall, floor, ceiling). The wall you see is now `wall_stone_1..4` (128x128 PixelLab stone, see `gen_wall_decor.py`); `wall`, `wall_2` and `wall_3` are the old brick, kept only as the fallback when `data/wall_decor.tres` has `enabled` off. The portcullis has a transparent background (bars only). The cracked wall carries a crack in each of the six cells a box face can show (see `gen_tiles.py`). |
| Title screen (`ui/title`) | **640x360, full resolution** | 640x360 | Not UI art: no 2x blocks, one art pixel per screen pixel, shown 1:1 behind the main menu, so it matches the fine pixels of the doubled dungeon art. Made at full size with `create_image_pro` (limits: pixflux 400x400; pixen 768 per side, area up to 512x512; pro 688x384 for 16:9, so 640x360 fits in one image, no layers needed). The entrance to a cursed dungeon at night: ruined archway, sickly green glow from deep inside, dead twisted trees, fog, dark sky at the top left clear for the logo. The importer leaves a 640x360 export as is. |
| Wall decals (`decals/<name>`, placed by `wall_decor.gd`) | crack 45x51, stain/roots/blood 64x64, niche 64x64 (all PixelLab, transparent), cobwebs 40x40, tally marks 44x24, veins 96x96 (drawn by script) | as made | One art pixel is one wall-texture pixel (2/128 world units), so decals match the wall's pixel density. Prompt for the decal alone on a transparent background; ask for "a patch of ..." and say "no stone block, no frame", or PixelLab draws an object. Curse veins are emissive and kept dim: pale green glares. |
| Spell effect flipbooks (`spells/<spell>/<name>_sheet`) | **at the in-game pixel density**: a flipbook frame is drawn so one art pixel is one monster pixel (0.014 world units). Fireball: cast 48x48, projectile 56x56 (loop), impact 96x96 | one row of frames + a `_sheet.json` | Made with PixelLab's effects tool (`vfx_workbench`), unshaded and additive in game (black adds nothing, so the sprite's dark outline disappears and the colours glow), so draw the light parts bright and keep the palette. Sources live in `tools/art/pieces/spells/`. |
| Skeleton, skeleton guard monster frames | **96x128** each | 96x128 | Front-facing, `pixel_size` 0.014. Sheet = 11 frames side by side (1056x128): idle x2, attack x3, hurt x2 (hurt, flash), **walk x4** (a stride that loops while it steps toward the party). The lowest pixel of each frame is put on the floor by the game, so empty space under the feet is fine. |
| Slime, acid slime monster frames | **96x96** each | 96x96 | Front-facing, `pixel_size` 0.02. Sheet = 12 frames (1152x96): idle x3, attack x3, hurt x2, walk x4 (a squash-and-crawl). The game stands the lowest pixel of each frame on the floor. |

**3D art that is not doubled yet** (same world size, so it simply keeps its old pixel density next to the new art):
torch sheet 4 frames of 16x32 (64x32), lever sheet 2 frames of 16x16 (32x16), item and key floor sprites 48x48
(`*_floor` and `sprites/key`, the same drawing as the icon; `icon_pixel_size` 0.01 in each `.tres`, so about 41 screen pixels at one tile), and the spell effect bolt (7x7).
Scorch decal 32x32. `decals/rune_panel` (48x48) and `decals/hidden_button` (32x32) exist but nothing in the game uses them yet.

**Items are finer than the rest of the UI.** A 48x48 or 24x24 export is stored as it is, not doubled, and all the current item art is that way: one art pixel per screen pixel inside a UI drawn in 2x2 blocks. **The importer treats `items/x`, `items/x_hud` and `items/x_floor` as three separate images, so a new item needs all three in the inbox** (a 48x48 export of each works: the hud one is reduced to 24x24). Importing only `items/x` leaves the placeholder in the hand, quick slot and on the floor.

**UI art (drawn at 2x; make it the "logical" size and the importer doubles it):**

| Asset | Make it this size | Game file (after import) | Notes |
|---|---|---|---|
| Item inventory icon (sword, mace, hammer, armour, potion, scroll, food, key...) | **48x48** (or 24x24, doubled) | 48x48 | The current art is native 48x48. |
| Item hand and quick-slot icon (`*_hud`) | **48x48** reduced, or 12x12 doubled | 24x24 | The current art is native 24x24. The key has none. |
| Hero portraits (living, hurt, dead) | **64x64** each (native: finer than the 2x UI pixels) | 64x64 | Three stills per hero, not an animation. Only the living one is generated: the importer tints hurt (red) and dead (grey with a faint curse tint) from it. Prompt for an **extreme close-up** whose head fills the whole 64x64 from top to bottom and edge to edge (hood, helmet or hat cropped by the frame): a bust leaves the face small in its panel. A grim flat mouth, lit from the left. |
| Movement arrows (and pressed versions) | **16x16** | 32x32 (2x) | |
| Hand button | **24x24** / small **16x16** | 48x48 / 32x32 (2x) | |
| Quick slot (and empty, sweep) | **14x14** | 28x28 (2x) | |
| UI frame | **320x180** | 640x360 (2x) | The stone frame; its 3D-view hole must stay exactly where it is (416x260 at 8,8). |
| Digit strip (stack counts) | **50x7** | 100x14 (2x) | |
| Name scroll button | **8x8** | 16x16 (2x) | |
| Empty hand and armour slot placeholders | made from the item icons by `gen_ui.py` | 48x48 | One flat colour, drawn at 30% strength. |

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
  one eye, extreme close-up, the head filling the whole frame, <suffix>`

### PixelLab settings that help

Transparent background on (monsters, items, sprites); a single-colour dark outline; flat or low
shading rather than smooth; low-to-medium detail so edges stay clean at 96x128; a front-facing
view. Always follow the readability rule above (outline plus rim glow).

## Workflow

1. Prompt with the subject and the suffix above.
2. Save the result in `tools/art/inbox/` under the asset's key (`import_pixellab.py --list`).
3. `python tools/art/import_pixellab.py --dry-run`, then the real run: it snaps to the palette,
   resizes with nearest-neighbour, applies the 2x UI scale, slices sheets, backs up the
   procedural original to `tools/art/_old/` and reports mismatches.
4. For an item or monster sheet, delete its copy in `tools/art/pieces/regrade_src/` and run
   `python tools/art/regrade_items.py`, which adds the ink outline.
5. Look at it in the game, in a dark corridor and next to the existing procedural art, before
   generating more. Style is approved one asset type at a time.

The procedural generators in `tools/art/` follow the same palette, but sharing a palette does not
give procedural and PixelLab art one look. Most game art is PixelLab now; what is still procedural is
the UI icons, the frame's iron, the scorch mark and the effects of every spell except Fireball.
