# PixelLab asset log

One line for every PixelLab asset: file path, PixelLab tool, date, generations used. **Add a line after generating any asset** (rule in `CLAUDE.md`). All animated effects (spells, fire, glows, smoke, dust, sparks, curse effects, bursts) must come from the VFX suite (`vfx_workbench`); code-drawn ones are placeholders and are listed at the bottom.

Entries before 2026-11-09 were filled in afterwards from the git history and the session records. A `?` means it wasn't recorded.

| File | Tool | Date | Generations |
|---|---|---|---|
| `art/spells/fireball/cast_sheet.png` (source `tools/art/pieces/spells/fireball/cast.png`) | `vfx_workbench` (`impact_burst`, recoloured) | before 2026-11-07 | ? (free tool) |
| `art/spells/fireball/projectile_sheet.png` | `vfx_workbench` (`energy_orb` recoloured, plus flame licks) | before 2026-11-07 | ? (free tool) |
| `art/spells/fireball/impact_sheet.png` | `vfx_workbench` (`explosion` preset) | before 2026-11-07 | ? (free tool) |
| `art/spells/magic_missile/cast_sheet.png`, `projectile_sheet.png`, `impact_sheet.png` | `vfx_workbench` (inferred: the sources carry the "PixelLab VFX Creator" tag) | before 2026-11-07 | ? (free tool) |
| `tools/art/pieces/ui/ruin_stone.png` (stone for `art/ui/arrow_*.png`) | `create_image_pixflux` | 2026-11-07 | 1 |
| `art/ui/arrow_*.png` first attempts (shaded and ruined arrows, replaced by the script version) | `edit_image_pixen` | 2026-11-07 | 17 (1 + 1 + 1 + 12 + 2 rejected tries; discarded) |
| `art/tiles/wall_corrupted.png` (kept; source `tools/art/pieces/corruption/wall_raw.png`, which is `wall_try4_roots.png`: dark stones with dead rotting roots clawing over them; the first version was a moss-speckled cobble texture, now `wall_try3_moss_cobbles.png`) | `create_image_pixflux` | 2026-11-09 | 5 in all (the 2 for this version: roots, kept, and a mossy brick; earlier 3: a dark brick, an archway, a moss cobble) |
| `art/spells/bless/portrait_sheet.png` (74x46, 12 frames at 14 fps) and `art/spells/shield/portrait_sheet.png` (68x58, 16 frames at 12 fps), sources `tools/art/pieces/spells/{bless,shield}/portrait.png` + `.json`: the Bless ring and Shield dome scaled down to fit a 64x64 party portrait, played over each portrait that got the buff (the 3D versions no longer play for these two spells) | `vfx_workbench` (the Bless and Shield effects with the `scale` op, 0.34 and 0.7, then `fit_canvas`; effects "eye-of-bell-bless-portrait" d23637f4-0db0-47b2-8ad5-84d88a423e8a and "eye-of-bell-shield-portrait" d2519b8b-db85-48d3-be52-fc8f3ddfea29) | 2026-11-10 | 0 (free tool) |
| `art/spells/heal/portrait_sheet.png` (58x74, 12 frames at 12 fps, source `tools/art/pieces/spells/heal/portrait.png` + `.json`): the Heal burst scaled to half and fitted to the canvas, played over the portrait of the hero healed (the 3D version no longer plays for Heal) | `vfx_workbench` (the Heal effect with the `scale` op 0.5 then `fit_canvas`; effect "eye-of-bell-heal-portrait", id 4c77bc99-54d9-4371-bf18-439143945104) | 2026-11-10 | 0 (free tool) |
| `art/spells/resurrection/portrait_sheet.png` (62x78) and `portrait_large_sheet.png` (90x113, a Cleric's), 24 frames at 12 fps, sources `tools/art/pieces/spells/resurrection/portrait.png` / `portrait_large.png` + `.json`: the Resurrection column scaled to 0.5 and 0.75 and fitted to the canvas, standing over the raised hero's portrait with its foot on the portrait's foot, stretched to `revive_column_seconds`; it replaces the code-drawn gold column there | `vfx_workbench` (the Resurrection effect with the `scale` op and `fit_canvas`; effects "eye-of-bell-resurrection-portrait" d014403f-928e-43eb-9870-43e749726f95 and "...-portrait-large" 33eaa27b-59e4-4ac1-b3c8-677ffb480266) | 2026-11-10 | 0 (free tool) |
| `art/spells/resurrection/column_sheet.png` (source `tools/art/pieces/spells/resurrection/column.png` + `.json`, 24 frames (23 kept) of 116x149 at 12 fps, one-shot, gold): a column of gold light on a ring that fades in, bursts with rising sparkles, holds and fades out; the game plays it over `revive_column_seconds` so it ends with the column over the portrait (Resurrection). First try was `sky_beam` (a beam slamming down, not a column rising): replaced by `heal_column` in gold with its opacity keyed in and out | `vfx_workbench` (part `heal_column`, gold ramp, width 16, brightness 0.8, sparkles x2, retimed to 24 frames; effect "eye-of-bell-resurrection", id 11f2ae2f-ba3e-4288-8137-59b17220205c) | 2026-11-10 | 0 (free tool) |
| `art/spells/shield/flash_sheet.png` (source `tools/art/pieces/spells/shield/flash.png` + `.json`, 16 frames of 94x80 at 12 fps, one-shot, gold): a hex dome that snaps up in front of the party, shimmers and fades, with a few glints (Shield; it was blue before). Tries: `hex_dome` plus a `flash_burst` core (a sun disc in the middle, dropped) and `shield_block` (a one-sided arc, not a barrier); the dome's opacity was keyed to snap in and fade out | `vfx_workbench` (parts `hex_dome`, `twinkles`, gold ramp; effect "eye-of-bell-shield", id 74fdef87-2f3f-4c2b-b8d1-33d180cb4a13) | 2026-11-10 | 0 (free tool) |
| `art/spells/bless/ring_sheet.png` (source `tools/art/pieces/spells/bless/ring.png` + `.json`, 12 frames of 204x130 at 14 fps, one-shot, gold): a gold ring on the floor that swells and sweeps outward in two bands, sparkles drifting over it (Bless). The first version had a flash core and silver dust specks: the core was dropped and the dust recoloured to gold | `vfx_workbench` (parts `shockwave_ring`, `twinkles`, recoloured to the palette's gold ramp; effect "eye-of-bell-bless", id 6a3c3062-fded-4752-be41-2d23355de018) | 2026-11-10 | 0 (free tool) |
| `art/items/flail.png` + `flail_floor.png` (48x48, the same drawing; source `tools/art/pieces/items48/flail.png`, seed 9402) and `art/items/flail_hud.png` (native 32x32, `tools/art/pieces/items32/flail.png`, seed 9402): the Flail, a short handle, a chain and a big spiked iron ball. Redone from a first set of five 32x32 tries (seeds 9201, 9202, 9301-9303: a pickaxe head, a green orb, and long thin sticks with a tiny ball) at 48x48 with a prompt asking for a big ball and a short handle: seeds 9401 and 9403 came out as a ball on a stick (the mace again), 9402 was the only one with a visible chain. Its ball came out bruise purple, so `regrade_items.py` (icon) and `add_item_art.py --steel` (hand icon) grey that and the curse greens | `create_image_pixflux` (transparent, single colour outline, medium shading) | 2026-11-10 | 10 (5 first tries, then 3 at 48x48 and 2 hand icons) |
| `art/items/long_sword.png` + `_floor.png` (48x48, the same drawing; source `tools/art/pieces/items48/long_sword.png`, seed 9102) and `art/items/long_sword_hud.png` (native 32x32, `tools/art/pieces/items32/long_sword.png`, seed 9102, prompt without the curse-glow words): the Long Sword. Two 48x48 tries (seeds 9102, 9103) both came out with bright green blades; 9102 was kept, and `regrade_items.py` (icon) and `add_item_art.py --steel` (hand icon) put the greens back to grey | `create_image_pixflux` (transparent, single colour outline, medium shading) | 2026-11-10 | 3 |
| `art/spells/heal/burst_sheet.png` (source `tools/art/pieces/spells/heal/burst.png` + `.json`, 12 frames of 108x146 at 12 fps, one-shot, gold): a flash and a ring, then gold plus signs and sparkles rising round the party over a warm glow pool, drawn as an additive billboard with a gold light driven by its frames (Heal). First tries (a pick-up pop and rising embers, then a flat disc from the plus layer's outline glow) were redone | `vfx_workbench` (parts `soft_glow`, `ember_rise`, `heal_plus` (its outline-glow layer removed), `twinkles`, `flash_burst`, all recoloured to the palette's gold ramp; effect "eye-of-bell-heal", id 8cec8091-404c-467e-903b-8dd9f1c16e1f) | 2026-11-10 | 0 (free tool) |
| `art/corruption/veins_sheet.png` (source `tools/art/pieces/corruption/veins.png`): the pulsing green curse veins, a 12-frame loop. Redone 2026-11-09 as curved, tapering roots with side-branches and a pulse that runs outward from the heart (the first version was jagged lightning-like `bolt` layers) | `vfx_workbench` (own layers: smooth `shape` strokes with `reveal` for the travelling pulse, plus a `glow`; effect "eye-of-bell-corruption-veins", exported with `--replace`) | 2026-11-09 | 0 (free tool) |
| `art/corruption/purge_sheet.png` (source `.../purge.png`): the gold holy light burning the veins away from the centre outward, 14 frames. Redone 2026-11-09: a second, slower ring, gold cracks that race outward along the same roots as the green veins (so it reads as burning along them) and then cool and fade, instead of one plain ring | `vfx_workbench` (own layers: `glow`, two `ring`s, `shape` strokes with `reveal` on the veins' own paths, `rays`, `particles`; "eye-of-bell-holy-purge", exported with `--replace`) | 2026-11-09 | 0 (free tool) |
| `art/corruption/ash_sheet.png` (source `.../ash.png`): the wall crumbling to ash and dust, 17 frames. Redone 2026-11-09: the dust is now two ragged, drifting layers that thin to a haze (the first version was one flat blob) | `vfx_workbench` (own layers: two `noise` discs on a dark ramp with growing radius and fading opacity, falling `particles`; "eye-of-bell-ash-crumble", exported with `--replace`) | 2026-11-09 | 0 (free tool) |
| `art/corruption/halo_sheet.png` (source `tools/art/pieces/corruption/halo.png`): a soft green halo that breathes with the veins' heartbeat, with drifting spores, a 12-frame loop. It replaced the hand-typed heartbeat table: the light's strength is now read from this sheet's own brightness | `vfx_workbench` (own layers: `glow` with lub-dub keys, a `noise` mist, rising `particles`; "eye-of-bell-corruption-halo") | 2026-11-09 | 0 (free tool) |
| `art/corruption/rot_sheet.png` (source `.../rot.png`): black rot creeping over the face from the centre, covering it, then crumbling away in grain and falling flecks, 23 frames. It replaced the code tweens that blackened the block and sank it into the floor | `vfx_workbench` (own layers: a growing `noise` disc with `blocks` breakup and dissolve, falling `droplet` and `chunk` `particles`; "eye-of-bell-rot-crumble") | 2026-11-09 | 0 (free tool) |
| `art/ui/map_parchment.png` (source `tools/art/pieces/map/parchment_raw.png` = `try_d.png`, 200x148, seed 5302 request id d; `gen_map_art.py` crops 104x80 from the stained lower-left, mirrors that side onto the right, maps brightness onto the bone/rust steps with a Bayer dither and tears the edges). Redone 2026-11-09 for heavier stains; the first version (a plain 128x96 sheet, seed 4101) was replaced. Unused tries kept in `pieces/map/try_a..e.png` | `create_image_pixflux` | 2026-11-09 | 6 in all (1 first version; 3 at 128x96 that drew scrolls; 2 at 200x148, `try_d` used) |
| `art/ui/map_frame.png` (source `tools/art/pieces/map/iron_raw.png`, 32x32 rusted iron plate, seed 4102; the frame is drawn round the parchment by `gen_map_art.py`) | `create_image_pixflux` | 2026-11-09 | 1 |
| `art/ui/map/icon_*.png` and `icon_*_s.png` (arrow, door_closed, door_open, door_locked, stairs, lever, secret; sources `tools/art/pieces/map/icons/`, made 16x16 by `gen_map_icons.py`, which also writes the 8x8 reductions the corner map uses). Seeds 6001-6007 first round, 6101-6105 second round (arrow, open and locked door, stairs and secret were redone: the first versions drew a diagonal arrow, a dome, a scroll and a chest; the first closed door and lever were kept). The arrow is recoloured to blood by the script | `create_image_pixen` | 2026-11-09 | 12 (7 + 5) |
| `art/ui/map/torchlight_sheet.png` (source `tools/art/pieces/map/torch_flicker.png` + `.json`, 12 frames of 104x80 at 10 fps, a loop): two warm pools of light that swell and drift, laid additively and faintly over the map parchment | `vfx_workbench` (own layers: two `glow` layers with sine-driven radius and drift; effect "eye-of-bell-map-torchlight", id fec44b58-339a-480e-b282-2e3cfd93e3a4) | 2026-11-09 | 0 (free tool) |
| `art/ui/map_sheet.png` (source `tools/art/pieces/map/sheet_raw.png` = `sheet_try1.png`, 584x328, seed 7001; `gen_map_art.sheet()` joins the clean paper left and right of its scroll roller into 474x298 and paints out the roller caps): the stained paper behind the full-screen map. I tried a mirrored tile of the corner map's parchment first; it looked like wallpaper | `create_image_pixen` | 2026-11-09 | 1 |
| `art/ui/spell_frame.png` (source `tools/art/pieces/spell_menu/frame_raw.png`, 64x64, seed 8001; `gen_spell_menu.py` keys out its flat ground, crops it to 50x47, darkens the iron one step and replaces the middle with plain dark stone so it works as a nine-patch): the spell pop-up's riveted rusted iron frame | `create_image_pixen` | 2026-11-09 | 1 |
| `art/spells/icons/{magic_missile,fireball,heal,shield,bless}.png` (sources `tools/art/pieces/spell_menu/<name>.png`, 16x16, seeds 8011-8015 and 8021-8022; the script moves the greens the palette snap made onto each spell's own colour and fills the Magic Missile bolt's empty inside). First tries of Magic Missile (drawn on a stone checker) and Shield (a grey dome) were redone: `magic_missile_try1.png`, `shield_try1.png` | `create_image_pixen` | 2026-11-09 | 7 (5 + 2 redone) |
| `art/intro/shot_01_road.png` | `create_image_pro` | 2026-11-07 | 25 |
| `art/intro/shot_02_travellers.png` | `create_image_pro` | 2026-11-07 | 50 (one rejected try) |
| `art/intro/shot_03_crow.png` | `create_image_pro` | 2026-11-07 | 25 |
| `art/intro/shot_04_trees.png` | `create_image_pro` | 2026-11-07 | 100 (three rejected tries) |
| `art/intro/shot_05_boots.png` | `create_image_pro` | 2026-11-07 | 25 |
| `art/intro/shot_06_ruins.png` | `create_image_pro` | 2026-11-07 | 25 |
| `art/intro/shot_07_silhouette.png` | `create_image_pro` | 2026-11-07 | 50 (one rejected try) |
| `art/intro/shot_08_holy_symbol.png` | `create_image_pro` | 2026-11-07 | 25 |
| `art/intro/shot_09_sword.png` | `create_image_pro` | 2026-11-07 | 25 |
| `art/intro/shot_10_entrance.png` | `create_image_pro` | 2026-11-07 | 25 |
| `art/intro/shot_11_archway.png` | `create_image_pro` | 2026-11-07 | 25 |
| `art/intro/shot_12_tunnel.png` | `create_image_pro` | 2026-11-07 | 25 |
| `art/intro/shot_13_inside.png` | `create_image_pro` | 2026-11-07 | 25 |
| `art/intro/shot_14_looking_out.png` | `create_image_pro` | 2026-11-07 | 25 |

Older PixelLab art (items, monsters, portraits, walls, decals, the title screen, UI pieces) predates this log and isn't listed.

## Derived by script (no PixelLab)
`art/normals/tiles/*_n.png` and `art/normals/decals/*_n.png`: normal maps made from the textures' own brightness by `tools/art/gen_normal_maps.py` (2026-11-10, 0 generations). Lighting data, not palette art, so they are not palette-checked.

## Code-drawn effects: placeholders

None of these were made with the VFX suite, so they should be replaced.

**Spells**
- `art/spells/scorch.png`: soot decal drawn by `tools/art/gen_spell_fx.py`.
- Magic Missile fallback bolt: a 7x7 sprite built in `scripts/spell_effects.gd` (used only if the flipbooks are missing).
- Fireball fallback orb and explosion (`_fireball_basic`, `_explosion_basic`): square orbs built in code, used only if the sheets are missing.
- Pixel particles (embers, sparks, smoke, and the Heal, Bless and Shield motes): 1x1 squares emitted by `scripts/pixel_particles.gd`.
- Heal, Bless and Shield: light pulses and motes only, no flipbook.
- `art/items/holy_symbol_glow.png`: three frames drawn by `gen_items.holy_symbol_glow`, the holy burst on the party panel.
- Resurrection gold column and the burning-icon effect: built in code in `party_hud.gd` (`_revive_column_texture`).
- Wall debris dust puff when a cracked wall breaks (`wall_debris.gd`) and its rubble cubes.

**Fire, glows, auras, curse**
- Wall torch flame: `art/sprites/torch_sheet.png`, 4 frames drawn by `tools/art/gen_sprites.py`, plus the flickering torch lights in `dungeon_builder.gd` and `main.tscn`.
- Alcove candle flicker (`wall_decor.gd`): a light that flutters in code.
- Curse veins on walls: a pulsing emissive decal (`wall_decor.gd`, `start_pulse`).
- The cracked wall's green crack glow and its dimming (`Dungeon.dim_curse`).
- Volumetric fog and bloom (`SpellEffectsConfig.apply_environment`): an engine effect, not art.
- Monster hurt flashes and telegraph glow (`monster.gd`) and the party panel's buff rings and food flares (`party_hud.gd`).
- Ambush bursts and legendary item glows: none exist yet; when they do they must be made with the VFX suite.

**Corrupted walls** (everything that moves on them is in the table above; what is left in code)
- The heartbeat light (`corrupt_wall.gd`): a faint green `OmniLight3D`. A real light cannot be art, but its strength each frame is read from the PixelLab halo sheet's own brightness (`beat_curve`), so the animation sets the beat.
- The burn-away mask (`shaders/corruption_add.gdshader`): hides the veins from the centre outward to follow the PixelLab ring. It reveals PixelLab art, it draws none.
- The camera shake and the `rumble` sound when it crumbles.

**Intro**
- `art/intro/fx/`: lightning, flash, fog and rain, and the three `<shot>_glow.png` layers, drawn by `tools/art/gen_intro.py`.

**Debug**
- Wall signs (`scripts/wall_signs.gd`, used by the test room): a flat dark quad and a Press Start 2P `Label3D` in palette colours, not drawn art. Replace with a PixelLab sign if a real level needs one.

**Monster animation sets (existing Creator gallery images, 0 new generations)**
- `art/monsters/slime_acid/slime_acid_sheet.png` (28 frames of 96x96: idle 5, attack 9, hurt 5, walk 9), built by `tools/art/gen_monster_sheets.py` from the grids in `tools/art/pieces/monsters/slime_acid/` (PixelLab Creator gallery `b4c8d36e` attack, `3d82c59d` idle, `0505e2a8` hurt, `118c63a4` walk; 2026-11-10). Replaces the single-image, script-animated 12-frame sheet.
- Same set for the other three (2026-11-10, same grids in `tools/art/pieces/monsters/<name>/`): `slime` (idle `f854260f`, attack `3fcd792c`, hurt `3b004ae2`, walk `69ef2f73`; the dark green slime), `skeleton` (the unarmed shambler: idle `6d6a2c1e`, attack `48d5de37`, hurt `b330a027`, walk `fcd9bb46`) and `skeleton_guard` (the armed warrior: idle `5dcd0584`, attack `03c5f44f`, hurt `32efa320`, walk `b1459acd`). All 28 frames each; sizes match the old art (96x128, 96x96), so `pixel_size` is unchanged. The skeletons were taken out of `regrade_items.py` (their own outline now).
