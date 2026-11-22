# Status report, 22 Nov 2026

For an assistant who cannot see the code. Facts come from `git log` (commits 13 to 21 Nov; 99 commits, about 36,000 lines added), the code and
`docs/roadmap.md`. Written 22 Nov at commit `7d784c5` plus the roadmap line `e4068e4`. Nothing is uncommitted except this file.

**The game:** Eye of the Beholder style first-person grid dungeon crawler, Godot 4.7 (GDScript), pixel art made with Python and PixelLab. One
floor ("floor 1") is playable start to finish; the party is four fixed heroes (Brannoc the fighter, Brother Felix the cleric, Wren the thief,
Fennick the mage). Five committed headless tests all pass: smoke 485 checks, test room 90, editor 232, pop-up layout 29, banter 109.

"Roadmap" below means a step number in `docs/roadmap.md`. "Extra" means built from a chat request and not in any step (the roadmap's
"Extra steps" section lists them all with commits; it was brought up to date today).

---

## 1. Built since 13 Nov

Commits of 12 Nov (just before the window) were Foundations Steps 0 to 6 (smoke test, event bus, `Party.hurt`/`heal`, class id and hero name,
fight tracker, run flags, banter engine) and the banter starter lines (7f.1, 7f.2). All ticked.

| Date | What | Roadmap? |
|---|---|---|
| 13 Nov | Status effects and **Hold Monster** spell; monster tier table for every status | 7k.1, 7k.1b |
| 13 Nov | **Rusty bear trap** (set from a hand or quick slot, snaps, holds) | 7k.2 |
| 13 Nov | **Monster pacing**: own step clock, reaction delay, queueing instead of surrounding, one flanker | Extra |
| 13 Nov | **Monster hit effects**: a PixelLab effect across the view with each landed blow | Extra |
| 13 Nov | Test room: every item goes into the heroes' backpacks on arrival | Extra |
| 13 Nov | Parked work turned into named branches (`wip/boss-ambush`, `wip/fog-of-war`) | Leftovers |
| 13 Nov | Docs: roadmap copied into the repo, `technical_brief.md`, zombie concept pictures, a painterly art trial (parked, see 5) | Extra |
| 14 Nov | **Cursed Warden** mini-boss (80 HP, tier 3) and **mana regen 1 per 6 s** (was 2.5 s) | Leftovers prompts |
| 14 Nov | **Torches and candles in hand**, no light follows the party, the dark is real | 7l.1 |
| 14 Nov | Bear trap can be set by dropping it from the cursor onto the tile ahead | Part of 7k.3 (unticked) |
| 14 Nov | **Loot pop-up** (right-click a floor item, choose whose backpack) | Extra |
| 14 Nov | Only a caster can hold a spellbook or holy symbol | Extra |
| 14 Nov | **Six-hero screen layout**: 3D view in the middle, three panels down each side | Extra |
| 14 Nov | `docs/design/expansion_design.md` and `open_questions.md` written | Design doc |
| 18 Nov | **Plague rat** (tier 1, fears fire, bite can sicken, raw meat drop) | Leftovers prompt |
| 18 Nov | Fireball and Magic Missile **shockwave ripple** | Extra |
| 18 Nov | **Saves**: each system saves itself, whole file validated first, version 2 | Foundations Step 7 |
| 18 Nov | **Wall sconces** (lit, unlit with a torch, empty bracket) | 7l.2 |
| 18 Nov | **Puzzles on the event bus**, memory conditions as run flags | Foundations Step 9 |
| 18 Nov | **Curse zones** (flames die inside, Bless makes a 20 s pocket) | 7l.3 |
| 18 Nov | **Flask of oil** (slicks, burning tiles, doused monsters) | 7l.5 |
| 18 Nov | **Throwing torches** (shift+click a hand) | 7l.4 |
| 18 Nov | `docs/design/new_classes_plan.md` written | Design doc |
| 19 Nov | Curse zone look pass (fog, sputtering flame, vignette) | Extra |
| 19 Nov | Test Room export preset, and a build that offers only the test room | Extra |
| 19 Nov | **Zombie** (tier 2) and its **death gas** (1 in 5, stings the party) | Extra |
| 19 Nov | Gas recoloured to rot (mustard, not curse green); new palette colour `mustard_500`; gas banter | Next 10 #1 |
| 19 Nov | Corner map moved top-right and translucent; food held on cursor can be put in a pack or fed by Shift+click on a portrait; inventory shows quick slots | Extra |
| 20 Nov | **Levels as data** (`use_level_data`, floor 1 in `levels/floor_1.gd`, `RunState` carries the party) | Foundations Step 12, Next 10 #4 |
| 20 Nov | **Dungeon editor** E.1 to E.5 (draw, doors/levers/sconces, items/monsters, build and play with a reachability check, save/open as a level file) | Phase E, Next 10 #5 to #9 |
| 20 Nov | Editor: double-click the party start to play from there; editor screenshots | Extra |
| 20 Nov | Mana Potion (5 mana) | Extra |
| 20 Nov | `docs/design/story_arc.md`; roadmap declared the master copy in this repo | Docs |
| 21 Nov | **Light on floor 1** (loose torches and candle, cave curse zone lifted when its rats die, -10 to hit in the dark) | 7l.6 |
| 21 Nov | **Campfire and bedroll art** (PixelLab fire, spit, one 3D bedroll per hero) | Extra |
| 21 Nov | **Making camp** (Bedroll item, camp screen, rest, clickable bedrolls) | 7h.2 |
| 21 Nov | **Cooking** at the fire (raw rat meat, mouldy bread) | 7h.3 |
| 21 Nov | Warden redrawn from the user's PixelLab "hardcore warden" picture | Extra |
| 21 Nov | **Background music** (Walen, "Dark Heart"), one player across scenes | Extra |
| 21 Nov | **Item behaviour hooks** and the **legendary item framework** | Foundations Step 11, 7g.1 |
| 21 Nov | **Azure Brand**, a legendary glowing blue sword with fire damage | Extra |
| 21 Nov | **Red Shaman** (ranged caster), then placed on floor 1 | Extra |
| 21 Nov | Trap snaps the party cannot see or hear are silent; level monsters may "hold ground" | Extra (bug fix) |
| 21 Nov | **Goblin** (tier 1 spear carrier), two on floor 1 | Extra |
| 21 Nov | **Message log scrolls** (wheel or bar, 200 lines of history) | Extra |

---

## 2. Built but not on the roadmap

What each does and what it touches. All are listed in the roadmap's "Extra steps" section.

- **Monster pacing** (`monster.gd`, `monster_def.gd`, `data/monster_ai.tres`): monsters move on their own clock, wait before the first blow, queue instead of surrounding the party. Touches combat, AI, tests.
- **Monster hit effects** (`hit_overlay.gd`, `art/spells/hit_fx/`): a VFX flipbook across the view on each landed blow, placed by side. Touches `Party.monster_struck`, combat feel.
- **Loot pop-up** (`loot_menu.gd`): right-click a floor pile to pick whose backpack takes it, or take all. Touches the pop-up layer, `Party` stowing, `Player`.
- **Caster-only focus items**: a spellbook or holy symbol only goes in a hand of a matching caster. Touches `Party.can_equip`, inventory.
- **Six-hero layout** (`ui_layout.gd`, frame art): six panel slots, two empty because the game still has four heroes. Touches every HUD script and the frame art generators.
- **Shockwave ripple**: a pixel-exact screen ripple on Fireball and Magic Missile impacts. Touches `spell_effects`, a shader, options.
- **Curse zone look pass**: fog creeping from the zone edge, screen-edge vignette, flame wisps. Touches `curse_zones.gd`, VFX art, options.
- **Test Room export and test-room-only build**: a debug export preset. Touches `export_presets.cfg`, the main menu.
- **Zombie and death gas** (`gas_field.gd`): a slow tier 2 monster whose death may leave a cloud that stings the party. Touches monsters, party damage, VFX, banter.
- **UI conveniences**: corner map top-right and translucent; food on the cursor goes into a pack or is fed by Shift+click; quick slots in the inventory; I key opens the inventory. Touch HUD, inventory, party.
- **Mana Potion**: restores 5 mana, stacks to 9. Touches items, `Party.use_item`.
- **Editor extras**: double-click the start to play from it; screenshots folder. Touches the editor only.
- **Camp art and 3D camp** (`camp_site.gd`): PixelLab campfire, spit and a bedroll per hero as level scenery. Touches level structures, lighting, sprite lights.
- **Warden redraw**: new PixelLab art and animations for the mini-boss. Touches art generators only.
- **Background music**: one persistent player across scenes, credit file kept. Touches `audio.gd`, settings.
- **Azure Brand**: legendary sword with fire damage, never slips; its blue glow is a run-time tint and light (a first version added a blue palette ramp, removed again 22 Nov). Touches the legendary framework, item icons, sprite lighting.
- **Red Shaman and the ranged attack** (`MonsterDef.ranged_range`, `monster_bolt.gd`): casts a bolt from up to 4 tiles down a clear line; damage lands when the bolt arrives; `Party.side_of` now works for non-adjacent attackers. Touches monster AI, party, VFX, audio.
- **Trap witness rule** (`TrapField.witness`): a snap the party cannot see (10 tiles with a line) or hear (6) makes no log line, sound or event. Level monsters may carry `"holds": true` to stop wandering. Touches traps, monsters, level data.
- **Goblin**: tier 1 melee fodder. Touches monsters and floor 1 data.
- **Scrollable log** (`hud.gd`): wheel or bar, 200 lines, keeps your place. Touches the HUD only.
- **Docs and demos**: `technical_brief.md`, demo READMEs v0.6 to v0.11, `story_arc.md`, `new_classes_plan.md`.

---

## 3. Roadmap mismatches

**Ticked but not really built:** none found. I checked 7k.1 to 7l.6, 7h.2, 7h.3, 7g.1, E.1 to E.5 and Foundations 7, 9, 11, 12 against code and tests.
Two small things: the ticked "Parked work" step left `wip/painted-style` unlisted in `CLAUDE.md`; and the roadmap says finished phases live in a
"Done tab" while `docs/roadmap_done.md` (which `CLAUDE.md` says to create) does not exist.

**Built (wholly or partly) but not ticked:**
- **7h.1** (resting rules into the combat page): done inside `docs/combat_design.md` "Making camp" when 7h.2 was built. Interruption numbers are not in it (7h.4).
- **7e.1** (puzzle framework): the engine exists (Step 9, `puzzles.gd`), with a "monsters dead" condition, a "clear curse zone" effect and one floor 1 puzzle. Missing: brazier and altar conditions, seal/reliquary/sound effects, XP, the H-overlay puzzle list (not checked).
- **7k.3** (bear trap, what is left): tier 3 once-per-fight and drop-to-set are built and smoke-tested. Left: a plague rat check and the plate weight (waits for 7e.6).
- **7f.3** (more banter events): events for lights going out, gas, oil, traps, curse zones and legendaries exist. Not built: low HP, loot and food finds, first sight of a monster, darkness for a while, failed puzzle, standing still.
- **Step 8** (hero stats layer) and **Step 10** (monster behaviours) are unticked and not built.

**Stale facts in docs:** `CLAUDE.md` says the smoke test has 275 checks (now 485) and that three tests are committed (five are). `docs/known_issues.md` lists two failures in an `inventory_click_test` that is not in `tests/`, so they cannot be re-run.
The roadmap's own tests rule says "three tests"; there are five.

---

## 4. Changed plans (built differently from the prompt or design)

- **Build order.** The 14-step build order has Phase E at position 4 (moved up on 19 Nov at the user's pick, ahead of 7e, 7d and 7j) and puts 7h and 7g after 7d and 7j. 7h.2, 7h.3 and 7g.1 were built on 21 Nov on request, before 7d (ambushes), 7e (puzzles) and 7j. Foundations Step 11 was done before 8 and 10.
- **The Warden.** The design says to bring him back from `wip/boss-ambush`. He was rebuilt fresh with the design's numbers (80 HP, attack 5, defence 4, damage 3-9) and stands in the stairs corridor at (20,22) with no ambush room. A trap holds him 1.5 s once a fight and Hold lands 35% for 2.5 s, as the design says, through the tier table (tier 3 is held half the time). The Unquenchable he should carry does not exist.
- **Mana 1 per 6 s** is in as designed; the design says it needs a playtest first, and the playtest (Next 10 #2) is still open.
- **Ranged monsters were not in the plan.** The caster mechanism went straight into `monster.gd` (and `holds_ground`, status effects, pacing) instead of the Step 10 "behaviour script per monster" split, which is still undone. `monster.gd` is the file most at risk of growing too big.
- **Palette grew from 32 to 33 colours:** `mustard_500` (rot and disease, so gas is never curse green). A blue `arcane_*` ramp added on 21 Nov for the Azure Brand was removed again on 22 Nov at the user's instruction: **legendaries never add colours**; the sword's art is steel grey and its blue is a run-time tint and light, like a spell's.
- **Curse zones:** a zone's reach stops at walls (a sconce two tiles away through a wall stays lit). Added while building; not in the design.
- **Fighting in the dark** costs -10 to hit for weapons only (design: spells and monsters unaffected, as built).
- **Traps:** unseen snaps are silent (new rule, not in the design).
- **New monsters outside the design's table:** zombie, red shaman, goblin. The design's tentacle and giant hand are not built.
- **Six-hero layout:** the roadmap and design assume four heroes. The UI now has six slots (two empty), which Phase C's "third row" (C.5) may use.
- **Message log history** went from 40 to 200 lines.

---

## 5. Half-done, parked, known issues

- **`wip/boss-ambush`**: the sealed key room, the giant boss, a wall tentacle. Old; it predates the fight tracker, banter quiet switch, tiers and pacing. Belongs to 7d.
- **`wip/fog-of-war`**: a first fog of war for the maps. Shelved; the map code has changed a lot since. Unseen cells still show.
- **`wip/painted-style`** (14 Nov): "digitised paintings" art trial for monsters. Parked; **not listed in `CLAUDE.md`'s Parked work table**.
- `hires-720` is merged into `main`; the branch still exists.
- **Test room stations marked "NOT BUILT YET":** XP and levels, secret wall, braziers, altar.
- **Not built at all yet:** ambushes (7d), puzzles beyond the framework (7e.2 to 7e.7), most legendaries (7g.2 to 7g.8), camp interruptions, banter and floor placement (7h.4 to 7h.6), XP and levelling (7i), fallen adventurers (7j), character generator (8b), new classes (Phase C), procedural mode (Phase 9), dead weight (7b.8), editor curse zones/puzzles/ambushes (E.6) and donjon import (E.7). `Party.add_xp` does not exist.
- **Unplayed:** the Saturday playtest (Next 10 #2) and sorting its notes (#3) are not ticked. Balance of the new monsters (goblin, shaman, zombie gas, mana rate) is untested by a human.
- **Small gaps:** the goblin and shaman cast sounds are synthesised and never auditioned; the goblin has no hit effect; the shaman's hurt animation is made in code; the goblin's jab goes sideways; no TODO or FIXME markers exist in code.
- **Docs to refresh:** the stale items listed in section 3.

---

## 6. New or changed design docs

- `docs/design/expansion_design.md` (new 14 Nov, edited 18 and 21 Nov): decisions on ten open questions, the shared numbers table, a page per phase 7d to 7l and 8b, floor 1 pacing plan, replacement prompts. Edited to drop the tinderbox and to set the bedroll rules.
- `docs/design/open_questions.md` (new 14 Nov): the ten questions, answered "your picks"; touched again on 21 Nov.
- `docs/design/new_classes_plan.md` (new 18 Nov): four roles, three classes each; a plan only, no code.
- `docs/design/story_arc.md` (new 20 Nov): "The Prisoner in the Dungeon", acts 1 to 3; a design doc, not a step.
- `docs/technical_brief.md` (new 13 Nov): compact technical overview for sharing; one line edited 19 Nov.
- `docs/combat_design.md`: 21 commits; now holds light, oil, traps, status effects, making camp, cooking, the Red Shaman. It is the rules source with the combat blueprint page.
- `docs/art_style.md`: palette now 33 colours; notes on mustard (gas); the rule "legendaries never add colours" (22 Nov).
- `docs/tone.md`: only small edits (about 20 lines) with the banter engine work on 12 Nov.
- `docs/game_overview.md`: "Systems built" list updated with each feature.
- `docs/asset_log.md`: every PixelLab asset since 13 Nov with generation counts.
- `docs/roadmap.md`: master copy in the repo since 20 Nov; Extra steps section brought up to date 22 Nov.
- `docs/known_issues.md`, `docs/code_review.md`, `docs/banter_ideas.md`: unchanged.

---

## 7. Build order as it stands, and what I would do next

The roadmap's own order: the Next 10 list ends with **7e.1** (puzzle framework). After that: Foundations Step 10, Phase 7d (ambushes), 7j,
7h (rest), Step 8 then 7i (levelling), 7g (legendaries), a balance pass and demo, 8b, Phase C. Any time: 7b.8, 7f.3 to 7f.5, 7k.3, VFX.10 and VFX.11, E.6, E.7. Later: Phase 9.

My view of what is next:

1. **Playtest first** (Next 10 #2 and #3). A lot of unplayed systems stacked up on 18 to 21 Nov (light, curse zones, oil, camp, three new monsters, mana rate). Fixes from it should jump the queue.
2. **Housekeeping**, short: tick 7h.1 (and note 7e.1, 7k.3 and 7f.3 as partly done), list `wip/painted-style` in `CLAUDE.md`, refresh the stale test counts, fix or delete `known_issues.md`.
3. **Foundations Step 10** (monster behaviours), then **7d ambushes**. The monster code has grown past one file's comfort and 7d needs wall monsters and a locking seal.
4. **7e.1 then the rest of 7e**, because 7d.4's seal is shared with it and floor 1 still has only one puzzle.
5. **Step 8 then 7i** (XP and levelling), which the camp already waits for: `Party.add_xp` is called in two places only if it exists, and the test room's XP station is empty.
6. 7j, 7g.2 onwards, a balance pass with a demo, then 8b and Phase C.
