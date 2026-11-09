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

**Intro**
- `art/intro/fx/`: lightning, flash, fog and rain, and the three `<shot>_glow.png` layers, drawn by `tools/art/gen_intro.py`.
