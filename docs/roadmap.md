# Dungeon Crawler Roadmap

Nov 4, 2026 · @Bell

## The game in one line

A grim, cursed Eye of the Beholder-style dungeon crawler with a pitch-black sense of humour: the world is horrible, and the party won't stop complaining about it.

Tone rule: the world plays it straight (the curse, the monsters, the scares are never jokey); the comedy comes from the characters reacting to it. Party banter (Phase 7f) is a core feature, not polish.

## How to use this

The goal is one finished dungeon floor: walk in from a main menu, solve a door puzzle, fight a few monsters, find the stairs, see a win screen. Everything else waits until that exists.

- **One prompt, one feature.** Paste a prompt, run the game in Godot, test it, then commit before moving on.
- **Commit after every step.** Use git so a bad prompt is a 10-second undo, not a lost evening.
- **Sonnet by default.** Switch to Opus when Sonnet loops on the same bug twice, or for the design steps marked below.
- **Placeholders first, art second.** Grey cubes are fine until Phase 2. Never block on art. Until you have PixelLab credit, all art comes from Python scripts in tools/art/, saved under the file names PixelLab art would use, so real art can be swapped in later without code changes.
- **Keep a parking lot.** New ideas go in Phase 8's list, not into the current step.

First floor is done when: a stranger can start from the menu, reach the stairs, and either win or die without you explaining anything.

Finished phases (1 to 8 and the test room), with every prompt, now live in the Done tab: Done

## Next 10 steps (start here)

Do these first, in this order, ticking each one off. Each prompt sits right under its step. When all ten are ticked, carry on from the Build order below.

- [x] 1. Zombie gas prompt (Brown death): a quick fix before Saturday

```
Recolour the zombie's death gas so it reads as rot and disease, not
the curse. Read docs/art_style.md first: green is reserved for the
curse, so no green anywhere in the cloud.
- Colour: a sickly mustard-yellow core fading to murky brown at the
  edges, using palette colours only.
- Add a few dark specks drifting slowly inside it (flies or spores),
  so it says "plague cloud", not "fart".
- Replace the test VFX cloud with a proper one from PixelLab's VFX
  tool, palette-stepped like the other effects, no smooth alpha fade.
  Log it in docs/asset_log.md.
- If the cloud has a light or tint on nearby walls, make that
  yellow-brown too.
- Keep the colours and timings in the config.
- Banter (read docs/tone.md first; show me the lines before they go
  in): a couple of lines when the cloud appears, e.g. thief: "Was
  that the zombie or the fighter?" fighter: "Don't look at me."
Show me a screenshot of the cloud in the test room next to a curse
zone, so I can check the two never get mixed up. Run the tests and
commit.
```

- [ ] 2. Saturday playtest: normal mode first, then god mode. Post-its in three colours: bugs, confusion, fun. First run before the booze

- [ ] 3. Sort the Saturday Post-its with Claude: bugs into fixes, confusion onto the roadmap, nat 20s into the Ideas inbox. Big bugs may jump ahead of steps 4 to 10

- [x] 4. Foundations Step 12 (Levels as data)

```
Make levels loadable as data and let the party survive a change of level
(S6 in docs/code_review.md): add DungeonMap.use_level_data(dict) with
use_level(path) as a thin wrapper; move floor 1 out of dungeon_map.gd
into levels/floor_1.gd; add a RunState that carries the party between
floors using the save_state / load_state from Step 7; store a level id
(or seed) in the save; remove the main menu's hard-coded camera cell. No
behaviour change. Run the tests.
```

Check: F12 into the test room and back, New Game, and Continue all still start in the right place. Do this carefully: the editor relies on it.

- [x] 5. E.1 (Squared paper and drawing)

```
Do Foundations step 12 first if it is not ticked.

Add a dungeon editor, opened with a debug key from the main menu and the
test room (like F12). Follow docs/art_style.md: squared paper on
parchment, in the style of the full-screen map on M, inked lines, no
smooth gradients.
- A grid of squares the size of a level (new level: 32x32, set in the
  config). Each square is wall (filled, cross-hatched) or floor (blank).
- Left-click or drag paints floor; right-click or drag rubs back to
  wall. The outer edge always stays wall.
- Pan with the middle mouse or WASD, zoom with the wheel, coordinates of
  the square under the mouse in a corner (matching the (x,y) the
  roadmap uses).
- Undo and redo (Ctrl+Z, Ctrl+Y), at least 50 steps.
- A New button (asks for width and height) and a Close button.
No saving yet. Show me a screenshot of a small dungeon drawn in it, and
run the tests.
```

- [x] 6. E.2 (Doors, gates, levers, stairs and sconces)

```
Add a toolbar to the editor. Each tool places a thing the game already
has, using the same data floor 1 uses (read levels/floor_1.gd for the
shapes; add no new kinds of thing):
- Plain door, locked door, gate (portcullis), cracked wall, lever
  (linked to a door or gate: click the lever, then the door; draw a thin
  ink line between them while either is selected).
- Stairs down, and the party start (one only, with the direction the
  party faces, shown as an arrow).
- Sconce on a wall face (lit, unlit or empty), placed by clicking the
  edge of a square.
- Each thing is a small inked icon on the paper (PixelLab or by script,
  following docs/art_style.md; log them).
- Click a placed thing to select it; Delete removes it; R turns it.
- Things only go where the game allows them (a door between two walls, a
  sconce on a wall face): refuse anything else with a short message.
Run the tests and show me a screenshot.
```

- [x] 7. E.3 (Items and monsters)

```
Add items and monsters to the editor.
- A side panel listing every ItemDef in data/items and every MonsterDef
  in data/monsters, read from the folders, so new ones appear without
  touching the editor. Each shows its own icon or sprite, small.
- Click one, then a floor square, to place it. Items stack in a floor
  pile like the game's; monsters take the square and face a direction.
- Hover a square to see what's on it; click to select, Delete to remove.
- Keys: a placed key can be linked to a locked door, like levers.
- Keep the curse-zone rule: warn if anything above tier 1 is placed in a
  curse zone (once E.6 exists).
Run the tests and show me a screenshot with a few monsters and items.
```

- [x] 8. E.4 (Build and play): switch to Opus if Sonnet loops

```
Add Build to the editor: it turns the paper into a level and drops the
party into it in the 3D view, using DungeonMap.use_level_data and the
same building code as floor 1.
- Before building, check: there is a party start and stairs down; every
  floor square, item and monster can be reached from the start
  (flood-fill through doors, counting keys and levers like a player
  would); every lever and key is linked. Show problems as a list, with
  the squares marked in red ink. Missing start or stairs refuse the
  build; the rest are warnings.
- The party starts as the ready-made four with full HP and mana and
  their starting gear.
- A key (Tab) goes back to the paper with the party's square marked, and
  Build again puts the party back where it was.
- Nothing from a build-and-play is saved to the real save slot.
Run the tests, then build a small dungeon with a door, a lever, a gate,
two monsters and stairs, and show me a clip of walking it.
```

- [x] 9. E.5 (Save, load and the round-trip test)

```
Add Save and Open to the editor.
- Save writes levels/<name>.gd in the exact shape of levels/floor_1.gd
  (ask before overwriting). Open lists the files in levels/.
- Opening levels/floor_1.gd shows floor 1 on the paper with everything
  the editor knows about. Things it doesn't edit yet (puzzles, curse
  zones, ambushes, remains) are kept untouched when saving, and shown as
  grey "not editable yet" marks.
- Add tests/editor_test.gd: open floor 1, save it under a new name
  without changing anything, and check the saved data is identical to
  floor 1. Then draw a small level by script, save, open, and check it
  matches.
- Add the editor to CLAUDE.md (how to open it, what it can edit).
Run all the tests, then open floor 1, build it and walk a few squares.
```

- [ ] 10. 7e.1 (Puzzle framework)

```
Do Foundations step 9 first if it is not ticked.

Extend the puzzle framework that exists (scripts/puzzles.gd,
DungeonMap.PUZZLES) rather than adding a new one. See
docs/design/expansion_design.md section 3 "7e".
- New conditions: every monster in an area dead; every brazier in a
  group lit, or every one dark; an item (by file or by tag) on an altar;
  a plate held.
- New effects: seal and unseal an area's exits (the shared seal from
  7d.4 if it exists, else build it here), raise a reliquary on a cell
  with given items, clear a curse zone, play a sound.
- 50 XP when a puzzle is solved, if Party.add_xp exists.
- A list in the test room's H overlay: each puzzle, its conditions, and
  which are met.
Keep every existing puzzle working. Run the tests.
```

Five-minute jobs for any time: decide VFX.10 (Palette filter), and check whether the zombie at (15,11) needs a banter line when first seen.

## Build order: what's next

Work down this list. It comes from Fable's expansion design (docs/design/expansion\_design.md, section 6) and the classes plan (docs/design/new\_classes\_plan.md). Each phase ends by placing its own things on floor 1 and playing it, so the floor is never half-furnished.

1. Foundations Step 7 (Tolerant saves)
2. Mana prompt (Slower mana) and Mini-boss prompt (The Cursed Warden), both in Leftovers. Playtest before going on.
3. 7l.2 (Wall sconces) and 7l.4 (Throwing torches)
4. Foundations Step 12 (Levels as data), then Phase E (Dungeon editor) E.1 to E.5. Moved up on 19 Nov: Bell's pick for what to build next.
5. Foundations Step 9, then 7e.1 (Puzzle framework). 7l.6 needs its "every monster in an area dead" condition for the cave's curse zone.
6. 7l.3 (Curse zones), 7l.5 (Flask of oil), Plague rat prompt (in Leftovers), 7l.6 (Light on floor 1), then the rest of Phase 7e (7e.2 to 7e.7)
7. Foundations Step 10, then Phase 7d (Ambushes)
8. Phase 7j (Fallen adventurers)
9. Phase 7h (Resting)
10. Foundations Step 8, then Phase 7i (Levelling)
11. Foundations Step 11, then Phase 7g (Legendaries)
12. A balance pass and demo v0.8: the whole floor three times (rushing, thorough, careless with light)
13. Phase 8b (Party screen)
14. Phase C (New classes)

Any time: 7b.8 (Dead weight), 7f.3 to 7f.5 (more banter), 7k.3 (Bear trap: what is left), VFX.10 and VFX.11, E.6 (Editor: curse zones, puzzles and ambushes, once 7e and 7d exist), E.7 (donjon import). Later: Phase 9.

## Leftovers from finished phases

Loose ends from phases that are otherwise done, plus things the 13 Nov tech brief showed don't match the roadmap. Their phases moved to the Done tab; the steps and prompts live here until they're ticked.

- [x] 5.7 Enemy health bars (Phase 5)
- [ ] 7b.8 Dead weight: the party slows while carrying a dead character (Phase 7b)
- [x] Mini-boss: the Cursed Warden at the stairs (prompt below)
- [x] Plague rat: tier 1, fears fire, nests in the cave (prompt below)
- [x] Slower mana: 1 point per 6 s instead of 2.5 s (prompt below)
- [x] Zombie gas: recolour the death gas to rot and disease, not the curse (prompt below)
- [x] Parked work: turn the git stashes (boss-room ambush, fog of war) into named branches, e.g. wip/boss-ambush and wip/fog-of-war, and list them in CLAUDE.md under "Parked work". Do this before Step 7, so the refactors don't make them harder to apply.

**5.7 prompt (Enemy health bars)**

```
Add enemy health bars, following docs/art_style.md:
- A small pixel health bar floating just above each monster's sprite in
  the 3D view (a billboard, pixel-snapped, drawn at 1:1 with no
  smoothing). Blood red fill on a dark background, inside a thin rusted
  iron frame.
- Only show a monster's bar once it has been damaged or is the one
  directly in front of the party, so quiet corridors stay uncluttered.
  Fade it out (in palette steps, not smooth alpha) a few seconds after
  the monster stops taking damage.
- When damage lands, the lost chunk flashes white, then drains down
  over about half a second, so big hits feel big. Crits drain with a
  little shake.
- The monster in front also shows its name and bar in a slim strip at
  the top of the dungeon view (e.g. "Cursed Skeleton").
- Bosses and wall monsters (giant hand, tentacles) get a wide named bar
  across the top of the screen instead, with a curse-green trim.
- Add an Options toggle: "Enemy health bars: On / Boss only / Off", for
  players who want the old-school EotB feel.
- Keep sizes, colours and timings in the config, and add a station in
  the test room.
```

**7b.8 prompt (Dead weight)**

```
Add "dead weight": while any party member is dead, the party is
carrying their body, so movement slows until they're resurrected.
- Each step's move tween takes about 25% longer per dead character,
  capped at about 75% longer in total. Turning stays at normal speed so
  fights don't feel sluggish. Keep the numbers in the config.
- When someone dies, show "The party drags {name}'s body." in the
  message log (once). When they're resurrected, normal speed returns at
  once.
- Add a small icon on the movement arrows or near the party panel while
  slowed, so the reason is clear.
- If the banter system exists, add a few lines following docs/tone.md
  and docs/banter_ideas.md, e.g. the fighter carrying the cleric:
  "Heavier than he looks. Must be all the smugness."
- Make sure save/load keeps it consistent, and add it to the test room.
Keep it a nudge to resurrect, not a chore.
```

**Mana prompt (Slower mana)**

```
Change mana regeneration from 1 point per 2.5 s to 1 per 6 s
(Party.MANA_REGEN_TIME), as docs/design/expansion_design.md section 2
explains. Update the combat design page and the blueprint artifact, the
smoke test, and any README text that quotes the old rate. Do not change
any spell's cost. Then tell me how long a full Heal and a full Fireball
take to come back, so I can playtest it.
```

**Mini-boss prompt (The Cursed Warden)**

```
Add the floor 1 mini-boss from docs/design/expansion_design.md (sections 2
and 5). Bring the Cursed Warden's data and art over from the branch
wip/boss-ambush (data/monsters/warden.tres, its sheet and gen_warden.py);
do not bring its ambush code.
- Stats: tier 3, 80 HP, attack 5, defence 4, damage 3-9, a blow every
  2.0 s, sight 8. Set attack_hit_frame for his attack animation.
- He stands at (20,22) in the stairs corridor. Remove the acid slime at
  (20,21) and the guard at (20,22).
- Tier table: a monster of tier 3 or more can be caught by a bear trap
  once per fight (the fight tracker says when a fight ends). Add that
  rule and a smoke check for it.
- The sconces at (20,19) and (20,22) stay lit.
- Banter (read docs/tone.md first): one line when he is first seen, one
  when he falls.
- Add him to the test room's combat arena spawn list, run the tests, and
  redo the walk-through check of floor 1.
```

**Zombie gas prompt (Brown death)**

```
Recolour the zombie's death gas so it reads as rot and disease, not
the curse. Read docs/art_style.md first: green is reserved for the
curse, so no green anywhere in the cloud.
- Colour: a sickly mustard-yellow core fading to murky brown at the
  edges, using palette colours only.
- Add a few dark specks drifting slowly inside it (flies or spores),
  so it says "plague cloud", not "fart".
- Replace the test VFX cloud with a proper one from PixelLab's VFX
  tool, palette-stepped like the other effects, no smooth alpha fade.
  Log it in docs/asset_log.md.
- If the cloud has a light or tint on nearby walls, make that
  yellow-brown too.
- Keep the colours and timings in the config.
- Banter (read docs/tone.md first; show me the lines before they go
  in): a couple of lines when the cloud appears, e.g. thief: "Was
  that the zombie or the fighter?" fighter: "Don't look at me."
Show me a screenshot of the cloud in the test room next to a curse
zone, so I can check the two never get mixed up. Run the tests and
commit.
```

**Plague rat prompt (Plague rat)**

```
Add the plague rat from docs/design/expansion_design.md section 2: tier
1, 5 HP, attack 2, defence 1, damage 1-3, a blow every 1.4 s, a step
every 0.7 s, fears fire. A bite has a 20% chance of the food sickness (6
HP over 6 s, never kills). Drops raw rat meat 40% of the time (6 HP over
6 s, 50% sickness; cooked, 12 HP and none). Art and all four animations
from PixelLab following docs/art_style.md, one picture first for my OK;
a hit effect from the VFX tool; log it. Three nest in the cave at
(8,17), replacing the skeleton at (9,18). Run the tests.
```

## Spell VFX pass

Make every spell look as good as Fireball, based on Claude Code's spell audit (7 Nov). VFX.1 to VFX.10 are free (the PixelLab effects tool costs nothing). VFX.11 uses paid PixelLab generations to take the signature spells further. Spell colour language: fire orange, holy gold, arcane cold pale blue, curse green (green stays the enemy's colour, so players read it as danger). All spell sprites and flipbooks (cast, projectile, impact, holy bursts) are made with PixelLab's VFX suite through the MCP, not drawn in code, and every generated asset is recorded in docs/asset\_log.md (file, PixelLab tool used, date).

Model guide: Sonnet for everything unless marked. Switch to Opus where it says so.

- [x] VFX.1 Magic Missile gets the Fireball treatment: cast, projectile and impact flipbooks, synced light, pixel particles, small scorch (Sonnet)
- [x] VFX.2 Swap all alpha-fading particles for palette-stepped pixel particles (Sonnet)
- [x] VFX.3 Camera kick, hit-pause and brighter flash on spell impacts (Sonnet)
- [x] VFX.4 Glow tuning: threshold, intensity, blend mode in the config (Sonnet)
- [x] VFX.5 Shadows on spell lights, so light stops leaking through walls (Sonnet; switch to Opus if shadow artifacts get fiddly)
- [x] VFX.6 Holy spells (Heal, Bless, Shield, Resurrection): flipbook burst and rising light column with a synced light (Sonnet)
- [x] VFX.7 Light trails down corridors: additive streak behind bolts and a lit pool on the floor (Sonnet)
- [x] VFX.8 Normal maps on walls, derived from the stone by script (Sonnet; Opus if the normals come out noisy)
- [x] VFX.9 Shockwave or heat-haze shader on impact, snapped to whole pixels (Opus)
- [ ] VFX.10 Decide on the palette filter as default: an art call, compare once everything else looks right (you)
- [ ] VFX.11 Premium PixelLab pass to make spells look amazing (you have about 2000 generations, so be bold): generate one premium Fireball impact first and compare it in-game with the free version; if it's better, upgrade Fireball, Magic Missile, the holy light column and Resurrection, asking for 2-3 variations of each key effect and picking the best (Sonnet)

**VFX.1 prompt (Magic Missile upgrade)** (Sonnet)

```
Give Magic Missile the same treatment as Fireball. Use PixelLab's VFX
suite through the MCP, following docs/art_style.md, and log every asset
in docs/asset_log.md.
- Flipbooks for the cast flash, the projectile (looping) and the impact
  burst, in arcane cold pale blue (not green, which is reserved for the
  curse). Render them as unshaded, additive billboards so they glow.
- Drive the projectile's light from the animation: a flicker in flight,
  a spike on impact, a fade over about half a second.
- Use the same palette-stepped pixel particles as Fireball for the trail
  and sparks, and add a small scorch decal at the impact point.
- Keep timings and colours in the spell effects resource.
Show me a short clip or frame strip of Magic Missile and Fireball cast
down the same dark corridor. Commit when done.
```

**VFX.2 prompt (Pixel particles)** (Sonnet)

```
Find every particle effect that fades its alpha smoothly (the Magic
Missile trail and sparks, the motes for Heal, Bless and Shield, the
Resurrection column and burn, and the scorch decal's fade) and switch
them to the palette-stepped pixel style Fireball already uses: square
pixels, nearest filtering, palette colours only, stepping through 2-3
palette colours (bright to dark) before disappearing, with no smooth
alpha. List what you changed, show before-and-after frames, and commit.
```

**VFX.3 prompt (Impact punch)** (Sonnet)

```
Make spell impacts hit harder using the existing combat feel system:
- On every damaging spell impact: a brief hit-pause, a small camera
  kick away from the impact, and a brighter, shorter flash of the
  spell's light.
- Scale them by spell: Fireball biggest, Magic Missile small and snappy.
- Respect the "Reduce flashing and screen shake" option, and keep the
  strengths and durations in the spell effects resource.
Show me a clip of both spells hitting a monster, and commit.
```

**VFX.4 prompt (Glow tuning)** (Sonnet)

```
Tune the glow (bloom) so spells pop without washing out the pixel art:
- Move the glow threshold, intensity and blend mode into the spell
  effects config so I can tweak them.
- Aim for: spell sprites and impact flashes bloom clearly, torches glow
  gently, and walls, monsters and the UI never bloom.
- Show me three screenshots with different settings (subtle, medium,
  strong) in the same dark corridor during a Fireball impact, recommend
  one, and wait for my pick before committing.
```

**VFX.5 prompt (Spell shadows)** (Sonnet; switch to Opus if shadow artifacts get fiddly)

```
Turn on shadows for spell lights (and torches if performance allows),
so light stops leaking through walls and pillars and arches cast moving
shadows.
- Fix any shadow artifacts on the wall quads (acne, peter-panning,
  light leaking at wall corners) by tuning bias and normal bias.
- Check performance with several spells and torches at once, and tell
  me the frame-time cost.
- Add a "Spell shadows" toggle in Options for weaker machines.
Show me before-and-after screenshots of a Fireball passing a pillar, and
commit.
```

**VFX.6 prompt (Holy spell sprites)** (Sonnet)

```
Give the holy spells (Heal, Bless, Shield, Resurrection) proper sprites,
so they stop feeling flat next to Fireball. Use PixelLab's VFX suite
through the MCP, following docs/art_style.md, all in holy gold, and log
every asset in docs/asset_log.md.
- Heal: a soft gold burst rising around the party.
- Bless: a ring of gold light sweeping outward, matching the holy symbol
  glow on the cleric's portrait.
- Shield: a shimmering gold barrier flash in front of the party.
- Resurrection: a column of gold light rising in the dungeon view, in
  sync with the column over the portrait.
- Drive a gold light from each animation, keep the existing curse-glow
  dimming, and use palette-stepped particles.
Generate Heal first and show it in-game before doing the rest. Commit
each spell separately.
```

**VFX.7 prompt (Light trails)** (Sonnet)

```
Make spell light travel down corridors:
- Behind each projectile (Magic Missile and Fireball), drop a short-lived
  afterglow light about every tile, fading over about 0.5s, so the
  corridor lights up behind it like a wake. Cap the number of trail
  lights for performance.
- Add a stretched additive light streak behind each bolt and a lit pool
  on the floor beneath it as it travels.
- Make volumetric fog catch the spell light if it's enabled.
Test it in the test room's longest corridor, show me a clip, and commit.
```

**VFX.8 prompt (Normal maps)** (Sonnet; Opus if the normals come out noisy)

```
Add normal maps to the wall, floor and ceiling textures so torch and
spell light rakes across the stone instead of just tinting it.
- Derive them by script from each texture's brightness, with smoothing
  so pixel-art noise doesn't turn into speckles. Keep the strength
  adjustable in the config.
- Apply them to every wall variant and decal.
- Show me before-and-after screenshots of a torch-lit wall and a
  Fireball passing it, and commit.
```

**VFX.9 prompt (Shockwave shader)** (Opus)

```
Add a shockwave or heat-haze distortion on spell impacts, starting with
Fireball:
- A screen-space shader on the dungeon view that ripples outward from the
  impact point for about 0.3s.
- Snap the distortion to whole pixels so nothing blurs or smears the
  pixel art.
- Keep the strength, radius and duration in the spell effects resource,
  and respect the "Reduce flashing and screen shake" option.
Show me a clip of a Fireball impact with and without it, and commit.
```

**VFX.10:** no prompt needed; this one's your call. Once everything else looks right, ask Claude Code to show you the same corridor, fight and spell with the palette filter on and off, then decide whether to make it the default.

**VFX.11 prompt (Premium PixelLab pass)** (Sonnet)

```
Use PixelLab's VFX suite to make the signature spells look amazing. I
have plenty of generations, so be bold, but compare before replacing.
- First, generate ONE premium version of the Fireball impact with more
  frames and more detail than the current one, following
  docs/art_style.md. Show it in-game side by side with the current
  version, and don't replace anything yet.
- If I say it's better, upgrade Fireball (cast, projectile, impact),
  then Magic Missile, the holy light column and Resurrection. For each
  key effect, generate 2-3 variations and show them so I can pick the
  best.
- Log every asset in docs/asset_log.md, with generations used.
- Commit each spell separately.
```

Order: VFX.1 to VFX.4 as batch 1, then VFX.5 and VFX.6, then the rest. One commit per item.

Done when: casting Magic Missile and Fireball down the same dark corridor both look impressive, and no spell feels flat next to the others.

## Phase 7.5: Foundations (from the code review)

Fix the four foundations the expansion leans on before building anything new on floor 1. Based on Fable's code review of 11 Nov (docs/code\_review.md, commit 55a9af9): the code is in good shape, but banter, XP, puzzles and legendaries all need an event bus, real hero names, a bigger banter engine and saves that can grow.

Rules for this phase:

- One step per prompt, Sonnet for all of them. Commit after each.
- Every step is "no behaviour change": the game should play exactly as before. If it doesn't, undo and try again.
- "Run the tests" means tests/smoke\_test.gd, tests/test\_room\_test.gd and tests/popup\_layout\_test.gd. All three must pass before you commit.
- Do the in-game check after every step, even when the tests pass.
- Steps 0 to 6 come before any new banter lines (7f.2 onwards). Step 6 covers 7f.1 and more, since banter.gd already exists. Steps 7 to 12 each come before the phase named next to them.

* [x] Step 0 Smoke test for combat and saving (M0, before everything)
* [x] Step 1 Event bus, emit only (M1, before 7f)
* [x] Step 2 One path for hero damage and healing (S2, before 7f)
* [x] Step 3 Class id and hero name (M2, before 7f)
* [x] Step 4 Fight tracker (M4, before 7f)
* [x] Step 5 Run flags in the save (M5, before 7f)
* [x] Step 6 Banter engine upgrade (M3, before 7f.2; read docs/tone.md first)
* [x] Step 7 Tolerant, per-system saves (S1, before 7d and 7i)
* [ ] Step 8 Hero stats layer (S3, before 7i and 8b)
* [x] Step 9 Puzzles on the event bus (S7, before 7e)
* [ ] Step 10 Monster behaviours (S4, before 7d)
* [x] Step 11 Item behaviour hooks (S5, before 7g)
* [x] Step 12 Levels as data, party survives the stairs (S6, before a second floor or Phase 9)

**Step 0 prompt (Smoke test)**

```
Add tests/smoke_test.gd, a headless SceneTree test of floor 1, following
the Testing section of CLAUDE.md. Seed the combat dice. Check: a hero
kills a monster in front; a monster's hit lowers a hero's HP; Magic
Missile, Fireball, Heal, Bless and Shield each take effect and spend
mana; eating heals over time; a Scroll of Resurrection raises a dead
hero; saving then loading gives back the same party (hp, mana, items,
formation), player cell, open doors, levers, floor piles and monsters.
Print PASS or FAIL per check. Change no game code.
```

Check: the test passes. Nothing to check in-game.

**Step 1 prompt (Event bus)**

```
Add an autoload GameEvents (scripts/game_events.gd): signals only, as
listed in docs/code_review.md M1. Emit each from the one place the thing
happens (monster death in monster._die, hero death in
party.take_hit_from, revive in party.revive, key use, lever, wall broken,
wall purified, puzzle fired, stairs). Do not change any listener or
behaviour. Add a check to the smoke test that each signal fires once.
```

Check: play floor 1 for five minutes; kill something, pull a lever, break the cracked wall. Everything behaves exactly as before.

**Step 2 prompt (Hero damage and healing)**

```
In party.gd add hurt(m, amount, source) and heal(m, amount, source) and
make them the only places a hero's hp changes (see S2 in
docs/code_review.md for the seven sites). Death handling moves into
hurt. Emit GameEvents.hero_hurt and hero_died. No behaviour change. Run
the tests.
```

Check: take hits until a hero dies, eat, drink a potion, cast Heal, revive with a scroll. HP bars, sounds, portraits and Game over behave as before.

**Step 3 prompt (Class id and hero name)**

```
Give CharacterDef a class_id and a hero_name; set them in the four
data/party/*.tres (cleric / Brother Felix, fighter / Brannoc, thief /
Wren, mage / Fennick). Add Member.name(). Use it for every name shown to
the player in party.gd, the party HUD, inventory and character sheet (the
sheet still shows the class as a subtitle). Banter speakers, actor
conditions and ItemDef.cant_use match class_id. Update banter.json and
the item files. Run the tests.
```

Check: the panels and the log say Brannoc, Brother Felix, Wren, Fennick. The Mage still can't wear the leather armour. A crit or a fumble still gets a banter line.

**Step 4 prompt (Fight tracker)**

```
Add a fight tracker as described in M4 of docs/code_review.md and emit
GameEvents.fight_started and fight_ended. Replace fight_left /
behind_warned in party.gd with it. Show the state in the test room's H
overlay. Run the tests.
```

Check: in the test room arena, the overlay says a fight starts when you throw a dart at a monster and ends a few seconds after the last one dies. "Something's behind you!" still shows once per fight.

**Step 5 prompt (Run flags)**

```
Add a saved dictionary of run flags (DungeonMap.flags, cleared by
reset_run, written and read by save_game.gd with a default for older
saves). Add a smoke-test check that a flag survives save and load.
```

Check: save, load; nothing looks different. A save from before this step still loads.

**Step 6 prompt (Banter engine upgrade)**

```
Read docs/tone.md first. Then extend banter.gd as listed in M3 of
docs/code_review.md: listen to GameEvents, {name} and {target}
substitution, per-line once (stored in the run flags), reply lines after
a delay, a global minimum gap between lines, a quiet switch other
systems can set (for ambushes), and cooldowns counted in game time, not
the real clock. Keep existing lines working. Add tests for each. Write no
new lines yet.
```

Check: existing banter still appears, with the hero's name in front. Then carry on with 7f.2 for the new lines.

**Step 7 prompt (Tolerant saves)**

```
Give Party, the dungeon builder, Player and the cursor save_state() /
load_state(), and make save_game.gd gather them (S1 in
docs/code_review.md). Validate the whole file before changing the game;
refuse a bad file with a message and change nothing. Accept version 1
saves. Store the level path. Add smoke-test checks: a truncated file and
a file with a missing key are refused cleanly.
```

Check: an old save loads. Save in the middle of floor 1 with doors open and a lever pulled, quit to the menu, Continue: everything is where it was.

**Step 8 prompt (Hero stats layer)**

```
Give Member its own base stats copied from the class, and a single
Party.stats(m) for every number (S3 in docs/code_review.md). Replace all
direct reads of m.def.<stat> outside it. Save and load the base stats.
No behaviour change. Run the tests.
```

Check: the character sheet shows the same numbers as before for all four heroes, with and without a weapon and armour. In the test room, G and R still refill to the same HP and mana.

**Step 9 prompt (Puzzles on the event bus)**

```
Make Puzzles listen to GameEvents and re-check on any event, instead of
being called from pull_lever and _purify (S7 in docs/code_review.md).
Conditions that need memory (e.g. levers pulled in order) keep it in
DungeonMap.flags. Keep the when / then data shape, and keep every
existing puzzle working. No behaviour change. Run the tests.
```

Check: purify the thick wall at (16,4) and gate\_n still opens, before and after a save and load.

**Step 10 prompt (Monster behaviours)**

```
Add a behaviour field to MonsterDef that names a small behaviour script
(S4 in docs/code_review.md). Move the current chase, wander and
attack-when-adjacent logic into a walker behaviour, and keep take_hit,
death and drops shared in monster.gd. Every existing monster uses walker.
Don't build the wall_grabber yet (that's 7d.3), but make sure the design
leaves room for a monster that lives in a wall, doesn't occupy a floor
tile and holds the party in place. No behaviour change. Run the tests.
```

Check: all four monster types still chase, telegraph, attack and die as before.

**Step 11 prompt (Item behaviour hooks)**

```
Add an optional behaviour script to ItemDef with hooks on_equip,
on_unequip, on_hit, on_kill, on_tick and on_stowed, and have Party call
them at the right moments (S5 in docs/code_review.md). Ordinary items
keep the fields they have; don't convert them. No behaviour change. Run
the tests.
```

Check: the war hammer still breaks the cracked wall, and a potion, scroll, bread and slingshot still work.

**Step 12 prompt (Levels as data)**

```
Make levels loadable as data and let the party survive a change of level
(S6 in docs/code_review.md): add DungeonMap.use_level_data(dict) with
use_level(path) as a thin wrapper; move floor 1 out of dungeon_map.gd
into levels/floor_1.gd; add a RunState that carries the party between
floors using the save_state / load_state from Step 7; store a level id
(or seed) in the save; remove the main menu's hard-coded camera cell. No
behaviour change. Run the tests.
```

Check: F12 into the test room and back, New Game, and Continue all still start in the right place.

Also from the review, no step needed yet: two old issues are still open in docs/known\_issues.md, and saving mid-fight drops the fight state. That becomes a real hole in 7d (save inside an ambush, load, and the lock-in is gone), so 7d.4 must either save the ambush state or refuse saves during one.

Done when: all thirteen steps are ticked, the three tests pass, and floor 1 plays exactly as it did before you started.

## Floor 1 expansion: phases 7d to 7l

Floor 1 is built and shipped. These phases add new features on top of it, but build them in the order of the Build order list at the top, not the order they appear here.

## Phase 7d: Ambushes and jump scares

The dungeon fights back: build-up, silence, then something bursts out of the wall and the party can't run.

Design rules: one or two per floor at most; always leave a clue for observant players; a surprise should hurt, never wipe the party; and players can turn down flashes and shake in Options.

Updated 18 Nov from docs/design/expansion\_design.md (section 3 "7d" and section 5): two ambushes on floor 1, the giant hand by the key room and the double tap into room 2. Do Foundations Step 10 first.

- [ ] 7d.1 Ambush rules into the combat page
- [ ] 7d.2 Trigger tiles and the scare sequence
- [ ] 7d.3 The giant hand and the tentacles
- [ ] 7d.4 Locking the party in
- [ ] 7d.5 Clues and tuning
- [ ] 7d.5b Fake-out, then the real scare (double tap)
- [ ] 7d.6 Place ambushes in the floor 1 map

**7d.1 prompt (Ambush rules into the combat page)**

```
Copy the ambush rules from docs/design/expansion_design.md (section 3,
"7d", and the tier and monster tables in section 2) into
docs/combat_design.md and the combat blueprint artifact, replacing the
parked boss-ambush rules there. No code. Show me the two sections before
you publish the artifact.
```

**7d.2 prompt (Trigger tiles and the scare sequence)**

```
Do Foundations step 10 first if it is not ticked.

Build ambushes as data, following docs/design/expansion_design.md section
3 "7d". Start from the DungeonMap.AMBUSHES shape on the branch
wip/boss-ambush (pickup, trigger, seal, walls) and from the test room's
stand-in ambush, which already drives the banter quiet switch and the
ambush_warning / ambush_started / ambush_over events. Use those; add no
second set.
- An ambush has: id, armed_by (nothing, or picking up an item on a cell),
  trigger tiles, monsters, a lock-in kind, and its timings in a config.
- State is one run flag, ambush.<id>: armed, sprung or done.
- The sequence: build-up 1.8 s (input ignored, the party's light and
  sconces within 3 tiles sink to 30%, music and ambience fade, a scrape),
  burst (the cracked wall's cubes, a sting, a shake, a flash), snap (the
  party turns to face it in 0.15 s), fight.
- If the party holds no light, pulse the ambient green during the
  build-up instead.
- Reduce flashing: no flash or shake; the light sinks without flicker.
- Saving is refused during the build-up only. A save made while sprung
  restores the monsters and the lock-in on load, with no second scare.
- 60 XP when the last ambush monster dies, if Party.add_xp exists.
- A debug key in the test room that springs the nearest ambush.
Sounds can be placeholders, listed in docs/asset_log.md. Run the tests.
```

**7d.3 prompt (The giant hand and the tentacles)**

```
Add the two ambush monsters from docs/design/expansion_design.md (section
2 for numbers, section 3 "7d" for rules).
- The giant hand is a wall monster (MonsterDef.wall_monster): it sits in
  a wall tile, is registered in DungeonMap.occupied there so the tile in
  front of the party can be struck, draws on the wall face, never moves
  and is immune to every status. It grabs one living front-row hero:
  that hero cannot act and takes 2 damage every 1.5 s through Party.hurt.
  After 10 damage since the grab it lets go for 4 s. A squeeze cannot
  take a hero below 1 HP if they had half their HP or more when grabbed.
- Hold Monster on it costs nothing and says why, in one dry line.
- Tentacles are ordinary tier 1 monsters with a rooted behaviour: three
  sprout on free tiles beside the party (front, left, right). The party
  cannot step away while a living, unheld tentacle is beside it.
- Art with PixelLab, following docs/art_style.md, one first for my OK: a
  huge rotting hand with cracked grey skin, blackened nails and green
  veins; dark slick tentacles with pale suckers. Reach out, idle, attack
  or squeeze, hurt, death. Reuse the tentacle on wip/boss-ambush if it
  still fits the style. Log everything in docs/asset_log.md.
- Hit effects for both (MonsterDef.hit_effect) from the VFX tool.
- A test-room station with one of each. Smoke checks for the grab's
  limit, letting go, and the tentacles holding the party. Run the tests.
```

**7d.4 prompt (Locking the party in)**

```
Add the two lock-ins from docs/design/expansion_design.md section 3 "7d".
- Grab hold: while a grabbing limb lives the party cannot step or turn
  ("You are held fast!").
- Trap shut: every exit of the ambush's area closes and holds until its
  monsters are dead. Portcullises drop. Plain doors slam and take a curse
  seal. Build the seal as one shared mechanism (Dungeon.seal_area /
  unseal_area) because the purge room in 7e uses the same one.
- A door never closes on the party or a monster standing in it (the rule
  that exists).
- The lock-in is worked out from the living ambush monsters, never
  stored on its own, so a loaded save has it right.
- The inventory, the map and the loot pop-up still open while locked in.
Run the tests, and add a smoke check that saving and loading inside a
trap-shut room leaves the doors shut.
```

**7d.5 prompt (Clues and tuning)**

```
Add ambush clues, following docs/design/expansion_design.md section 3
"7d". The Reduce flashing option already exists; do not add another.
- Clue decals near an ambush wall: deep claw scratches, piled bones, wet
  drag marks (these need light to see), and a faint green glow in the
  mortar (an emissive decal, like the curse veins, so it shows best in
  the dark).
- A scraping sound when the party is within 2 tiles of an armed ambush,
  at most once every 20 s.
- Every ambush must have at least two clues, one of which needs no light.
  Make the level check this when it loads and warn in the log if not.
- Art from PixelLab following docs/art_style.md; log it.
Run the tests.
```

**7d.5b prompt (Double-tap fake-out)**

```
Add fake-out scares that chain into a real ambush (the horror "double
tap"):

- A fake-out uses the same build-up as an ambush, including a banter
  setup (cleric: "I smell evil." fighter: "Shut up."), then a BOOM that
  turns out to be harmless: a section of wall crumbling to reveal
  nothing, a skull dropping from a niche, or a shrieking bat bursting
  out and flying off. Same sting and shake, no fight.
- Then relief: lights return to normal, calm ambient sound comes back,
  and the party reacts with relief banter (e.g. fighter: "It was a bat."
  cleric: "Evil comes in many forms."). Following docs/tone.md, write a
  few lines for this.
- The fake-out arms a linked real ambush: it fires a few tiles later
  (set per ambush in the level data), with NO build-up and NO banter, so
  it hits while the player's guard is down: tentacles bursting from the
  walls and portcullises slamming shut (trap shut lock-in).
- As the real fight starts, a quick battle-cry exchange plays (cleric:
  "I did say!" fighter: "Shut up, cleric!"). After the fight, the
  cleric, grudgingly: "You're not so bad with a sword."
- Use the double tap once per floor at most, or it stops working.
```

**7d.6 prompt (Ambushes on floor 1)**

```
Place the ambushes from docs/design/expansion_design.md section 5.
- The hand: wall tile (7,10), armed by picking up key one at (10,10),
  trigger tiles (7,9) and (7,11), bursting into whichever the party is
  on. Grab hold. Clues on both faces of (7,10). Move the bear trap from
  (7,11) to (6,12).
- The double tap: a fake-out at (18,12) (a skull drops from a niche; add
  the alcove), then tentacles in room 2 with no build-up, three steps in.
  Trap shut on the doors at (18,10) and (17,9) and the gate at (20,6).
  Remove the skeleton at (19,8).
- Banter lines for the fake-out's set-up and relief (read docs/tone.md
  first; show me the lines before they go in).
Redo the walk-through check, run the tests, and tell me what a first run
through each felt like in numbers: HP lost, seconds, mana spent.
```

Done when: a first-time player jumps at the first ambush, and afterwards says "I should have noticed those scratches."

## Phase 7e: Cursed puzzles

Old-school dungeon puzzles dressed in the cursed theme. Rewards are always something in the world (a door, a hidden nook, a relic), never a game-y pop-up or jingle.

Updated 18 Nov from docs/design/expansion\_design.md (section 3 "7e" and section 5): the brazier closet in room 7, the purge room in room 6 and the darkness runes in room 4. Offering altars go in the test room only. Do Foundations Step 9 first.

- [ ] 7e.1 Puzzle framework (conditions and effects as data)
- [ ] 7e.2 Purge the room: the curse loosens its grip
- [ ] 7e.3 Braziers that push back the curse
- [ ] 7e.4 Paths that only appear in darkness
- [ ] 7e.5 Offering altars
- [ ] 7e.6 Weighted pressure plates
- [ ] 7e.7 Place puzzles in the floor 1 map

**7e.1 prompt (Puzzle framework)**

```
Do Foundations step 9 first if it is not ticked.

Extend the puzzle framework that exists (scripts/puzzles.gd,
DungeonMap.PUZZLES) rather than adding a new one. See
docs/design/expansion_design.md section 3 "7e".
- New conditions: every monster in an area dead; every brazier in a
  group lit, or every one dark; an item (by file or by tag) on an altar;
  a plate held.
- New effects: seal and unseal an area's exits (the shared seal from
  7d.4 if it exists, else build it here), raise a reliquary on a cell
  with given items, clear a curse zone, play a sound.
- 50 XP when a puzzle is solved, if Party.add_xp exists.
- A list in the test room's H overlay: each puzzle, its conditions, and
  which are met.
Keep every existing puzzle working. Run the tests.
```

**7e.2 prompt (Purge the room)**

```
Add a "purge the room" puzzle: entering a marked area seals its doors
with glowing green curse seals (overlays on the doors). When every
monster in the area is dead, the curse loosens its grip: the green glow
in the room's mortar fades out, the door seals crumble to dust, and a
sealed reliquary chest grinds up out of the floor with a low rumble and
dust particles. The reliquary holds items set in the level data. No
jingle or sparkle: just the sound of stone and the curse retreating.
Generate the seals and reliquary following docs/art_style.md.
```

**7e.3 prompt (Braziers)**

```
Add braziers, following docs/design/expansion_design.md sections 2 and 3.
- A prop on a floor tile that does not block it, lit or dark, in a named
  group. Saved.
- Lit by: clicking it with a lit torch or candle in a hand; a Fireball
  that passes or lands within a tile; a thrown torch landing on its
  tile; burning oil beside it. Snuffed by clicking with empty hands.
- A lit brazier is a light (energy 1.4, range 7) in the sprite_lights
  group, so monsters and items beside it are lit. It will not light
  inside a curse zone.
- Art and flames from PixelLab (the flames from the VFX tool), following
  docs/art_style.md; log it. One picture first for my OK.
- A test-room station: two braziers and a warded door.
Run the tests.
```

**7e.4 prompt (Paths that only appear in darkness)**

```
Add darkness runes, following docs/design/expansion_design.md section 3.
- A decal on a wall face that shows only when the light reaching the
  floor tile in front of it is no more than the ambient. Use
  sprite_lighting.gd's light_at for this; do not write a second light
  query. The party's own held light counts.
- It fades in over a second in palette steps, never a smooth fade.
- While the runes show, clicking the wall (or F) opens it, as a purified
  wall opens. A puzzle condition "runes_read".
- Art from the VFX tool, in the curse greens; log it.
- A test-room station: a room with two lit braziers and a sign.
Run the tests, and show me the room lit, then dark.
```

**7e.5 prompt (Offering altars)**

```
Add offering altars: a wall or floor altar that accepts items placed
with the click-to-place system. The level data says what it wants
(a specific item, or any item with a tag such as "bone" or "cursed").
The right offering triggers its puzzle; a wrong one is rejected with a
message like "The altar ignores your offering." Add a carved hint near
each altar (wall text overlay). Add a bone and a skull item to use as
offerings, following docs/art_style.md.
```

**7e.6 prompt (Weighted pressure plates)**

```
Extend pressure plates so items dropped on them can hold them down:
each item has a weight, and each plate a required weight. Show a subtle
click and the plate sinking when it's held. Make sure monsters standing
on plates also count. Build a test where the party drops a heavy item
on a plate to keep a door open, then walks through.
```

**7e.7 prompt (Puzzles on floor 1)**

```
Place the puzzles from docs/design/expansion_design.md section 5.
- Room 7: braziers at (18,3) and (20,3); the closet door (18,2) is
  warded until both burn. Move key two to (19,4). The closet holds three
  potions, two flasks of oil and one bedroll.
- Room 6: a purge room. Add a plain door at (15,19). A skeleton at
  (17,20), a guard at (16,21), an acid slime at (18,19). The reliquary
  rises at (17,20) with whatever 7g has put in it (a placeholder scroll
  until then). The plate at (18,21) needs weight 3.
- Room 4: lit braziers at (12,19) and (14,17), runes on the north wall
  (13,16), which opens onto (13,15). A sign: "What the light hides."
Redo the walk-through check and run the tests.
```

Done when: each puzzle can be solved without a guide, and solving one feels like pushing the curse back, not pressing a button.

## Phase 7f: Party banter and dark humour (core feature)

This is the game's personality. The party talks back: short, dry, grim-funny lines when things happen, and the humour spreads into item text, death screens and tips. The cleric leads the way: smug, holier-than-thou and no help at all.

- [x] 7f.0 Tone guide and character voices
- [x] 7f.1 Banter system
- [x] 7f.2 Starter lines and bickering
- [ ] 7f.3 More events to react to
- [ ] 7f.4 Humour beyond the party: items, deaths, tips
- [ ] 7f.5 Personalities in the character generator

**7f.0 prompt (Tone guide)**

```
Create docs/tone.md, the writing guide for all in-game text, and add a
line to CLAUDE.md telling future sessions to follow it for any line,
message, item description or menu text.

- The game: a grim, cursed dungeon crawler with pitch-black humour.
- Core rule: the world plays it straight. The curse, monsters and
  scares are never jokey. The comedy comes from the characters
  reacting to how awful it all is.
- Style: short (fits one message-log line), dry, deadpan, grim-funny.
  British/Scottish-flavoured understatement is welcome. No modern
  slang, memes or fourth-wall breaking.
- Timing: comedy can SET UP a scare, never interrupt one. A quick
  exchange right before an ambush is great (cleric: "I smell evil."
  fighter: "Shut up." ... BOOM), because the laugh lowers the player's
  guard. Once the burst happens, only a quick battle-cry exchange as the
  fight starts (cleric: "I did say!" fighter: "Shut up, cleric!"), then
  nothing until the fight is over;
  then the party can react.
- Voices:
  - Cleric: smug, holier-than-thou, passive-aggressive, no help at all.
    ("You didn't have the faith, my son.")
  - Fighter: blunt, tired, eats anything, has seen too much.
  - Thief: sarcastic, greedy, always eyeing the loot.
  - Mage: nervous, bookish, over-explains, terrified of everything.
- Boundaries: dark, not cruel. Punch up at the curse, the gods and the
  party's own failings.
Include 3 example lines per voice and a few bad examples of what to
avoid.
```

**7f.1 prompt (Banter system)**

```
Add a data-driven party banter system:

- Lines live in a data file (e.g. data/banter.json), keyed by speaker
  class and event, with optional conditions (e.g. "speaker is alive",
  "target is the fighter"). Use {name} and {target} placeholders so
  lines work with names from the character generator.
- Events to start with: a party member dies; a party member is revived
  (and who got revived first); a character runs out of mana; the cleric
  is shaken after resurrection; an ambush starts; a puzzle is solved;
  a level is completed.
- When an event fires, pick a random valid line from a living character
  (never from the dead, except the revived one), show it in the message
  log in that character's colour, and briefly flash their portrait.
- Cooldowns: a global cooldown (e.g. 20 seconds) and per-line memory so
  the same line doesn't repeat for a while. Each event has a chance to
  fire rather than always, so banter stays a treat, not spam.
- Optional replies: a line can name a reply event, so another character
  can answer it a second or two later.
- Add an Options toggle for party banter, and a debug key that fires a
  random event so I can test lines.
```

**7f.2 prompt (Starter lines and bickering)**

```
Before writing lines, read docs/tone.md and docs/code_review.md M3. Use the
new banter engine features: {name} and {target} placeholders (never typed
names), speakers matched by class_id, `once` for first-time lines (first
death, first revival), `reply` for the exchanges below instead of firing
two lines at once, and respect the quiet switch so nothing interrupts an
ambush. Use the GameEvents signals as the event names.

Fill data/banter.json with starter lines. Keep them short (one line in
the message log), dry and grim-funny, fitting a cursed dungeon.

The cleric is smug, holier-than-thou and unhelpful. Include these:
- Fighter dies: "You didn't have the faith, my son."
- Thief dies: "The Light does not protect those who pick its pockets."
- Mage dies: "All that reading, and not one prayer."
- Someone else revived before him: "Oh, him first. Naturally."
- Out of mana: "My god is not a well you can keep drawing from."
- Revived himself: "I was at peace. There was light. And you dragged me
  back here for this?"

The fighter is the party's protector: blunt, tired, and when a fight
starts he goes berserk. Include this ambush sequence:
- As the fight starts: cleric: "I did say!" fighter: "Shut up,
  cleric!" (a battle cry as he charges in).
- After the fight, the cleric, grudgingly: "You're not so bad with a
  sword."

Then write 2-3 lines for each event for the cleric, and 1-2 per event
for the fighter (blunt, tired, protective), thief (sarcastic, greedy)
and mage (nervous, bookish). Add a few reply pairs where someone snaps
back at the cleric, e.g. the fighter, after being revived: "Faith
didn't buy that scroll." Show me all the lines grouped by character so
I can edit them before testing in-game.
```

**7f.3 prompt (More events to react to)**

```
Following docs/tone.md, add more banter events and lines:
- A character drops to low HP; the party is all low HP.
- Finding loot (a thief line for anything shiny), finding a rare item,
  finding food (and mouldy food).
- Walking in darkness for a while; a torch going out.
- The first time each monster type is seen and killed.
- Opening a trapped door (and the thief failing to disarm it).
- A failed attempt at a puzzle; standing still for a long time.
- After an ambush ends (never during the build-up).
- The cleric being shaken after resurrection, and when it wears off.
Add one-time "first" moments: the first time any party member dies,
the fighter cries "NOOOO! My comrade!" (only ever once per game). If
that character is later resurrected, the fighter instantly denies it:
"I wasn't bothered." and the revived character can call him out
("I heard you."), and the fighter changes the subject fast: "*cough*
I'm hungry. Someone get a fire on." Add rare solidarity moments too: when someone is near
death, the sniping stops for a moment (e.g. the cleric heals the
fighter without a single smug remark), and once everyone's safe,
someone says "Don't make it weird." Keep these rare so they land.
Add relationship pairs, e.g. the cleric and the thief constantly
sniping at each other, with replies. Keep the cooldowns and chances so
it stays a treat.
```

**7f.4 prompt (Humour beyond the party)**

```
Following docs/tone.md, spread the humour beyond the party:
- Item descriptions shown when examining an item (right-click in the
  inventory): one dry line each, e.g. stale bread: "Baked in a better
  century."
- Game over screen: a random grim epitaph for the party.
- Level complete screen: a short tally with commentary (e.g. "Secrets
  found: 1 of 4. The dungeon is disappointed in you.").
- Loading or New Game tips, e.g. "Plague rats are not friendly. We
  checked."
- Wall carvings and altar hints written in-world but with a dark wink.
Show me every line grouped by type so I can edit them.
```

**7f.5 prompt (Personalities)**

```
Add personalities to the character generator (Phase 8b), so banter
isn't only decided by class. Each character gets a personality picked
at creation (or randomised): Smug, Grumpy, Coward, Greedy, Zealot,
Deadpan. Banter lines can be keyed by personality as well as class, and
the system prefers personality lines when both exist. Keep the cleric's
default personality as Smug. Write 2-3 lines per personality for the
main events, following docs/tone.md, and show them to me before
testing.
```

Done when: playtesters quote a line back to you afterwards, nobody hears the same one twice in a single fight, and the scares still land.

## Phase 7g: Legendary items

A handful of unique items, each with a personality. Rules: only two or three per floor; they change how you play, not just the numbers; the cursed land's best gear comes at a price; and every one gets a dry description and a hook into the banter system.

Updated 18 Nov from docs/design/expansion\_design.md (section 3 "7g"): floor 1 gets three, Grudge (mid-floor), Penitent's Mace (the purge room's reliquary) and the Unquenchable (dropped by the Cursed Warden). 7g.3, 7g.4, 7g.5 and 7g.7 wait for later floors; the Shield and the Crown need slots the game doesn't have yet. Do Foundations Step 11 first.

- [x] 7g.1 Legendary item framework
- [ ] 7g.2 Grudge, the talking sword
- [ ] 7g.3 The Too Old For This Shield
- [ ] 7g.4 The Gilded Hand
- [ ] 7g.5 Tome of Screams
- [ ] 7g.6 Penitent's Mace
- [ ] 7g.7 The Rat King's Crown
- [ ] 7g.7b The Unquenchable, a legendary torch (after 7l.1)
- [ ] 7g.8 Place legendaries in floor 1

**7g.1 prompt (Legendary framework)**

```
Do Foundations step 11 first if it is not ticked.

Add legendary items, following docs/design/expansion_design.md section 3
"7g". No design pass is needed: the table there is the design.
- ItemDef.legendary, and a behaviour script using the hooks from step
  11 (on_equip, on_unequip, on_hit, on_kill, on_tick, on_stowed).
- A worn-gold slot frame and a slow shimmer in the inventory, hand
  slots and loot pop-up. Gold, never curse green. Art from PixelLab,
  the shimmer from the VFX tool; log both.
- Its description, powers and price show in the item's tooltip and on
  the character sheet. Not on right-click: that splits a stack in the
  inventory and opens the loot pop-up on the floor.
- GameEvents.legendary_found(item, hero), once per item per run (a run
  flag). 30 XP if Party.add_xp exists. A banter event of the same name.
- Class limits through ItemDef.cant_use, as the spellbook does.
Run the tests.
```

**7g.2 prompt (Grudge, the talking sword)**

```
Add Grudge, a cursed sentient sword (fighter only). It hits hard and
joins the banter system as its own speaker, with a low, gravelly,
resentful voice. It hates the cleric even more than the fighter does.
Lines (following docs/tone.md), e.g.: "Can I stab the priest? Just a
little?", after a kill: "More.", when unequipped: "Back in the bag
again. Typical." Downside: if left in the backpack for a while, it sulks
and deals less damage for its next few fights.
```

**7g.3 prompt (Too Old For This Shield)**

```
Add the Too Old For This Shield (fighter). It blocks more the lower the
wearer's HP is: barely better than a normal shield at full health, and
excellent when they're nearly dead. Description: "Older than you.
Tougher than you. Still complaining." Give the fighter a few grumbling
banter lines for when it saves him at low HP.
```

**7g.4 prompt (The Gilded Hand)**

```
Add the Gilded Hand, a dagger (thief). Every kill made with it has a
chance to snatch an extra item or food from the monster. Downside: now
and then it quietly steals a small item from another party member's
backpack into the thief's (shown in the message log a little later:
"Something of yours has gone missing."). The thief always denies it in
banter.
```

**7g.5 prompt (Tome of Screams)**

```
Add the Tome of Screams (mage, held in hand like a spellbook). Fireball
and Magic Missile deal much more damage while it's held. Downside: every
cast makes the book shriek (a sound plus a message), waking and drawing
nearby monsters towards the party. The mage gets nervous banter about
how much it frightens him.
```

**7g.6 prompt (Penitent's Mace)**

```
Add Penitent's Mace (cleric). Each hit heals the cleric a little. The
cleric complains about the violence every single time (a short line
with its own cooldown, so it's funny, not spammy), e.g. "Forgive me.",
"This is beneath me.", "I'll pray about that later."
```

**7g.7 prompt (Rat King's Crown)**

```
Add the Rat King's Crown (any class, head or armour slot). Rats never
attack the wearer, though they still attack the rest of the party.
Downside: while it's worn, the rest of the party starts to smell, and
the banter never lets the wearer forget it. Add a few lines from each
class about the smell.
```

**7g.7b prompt (The Unquenchable, legendary torch)**

```
Add the Unquenchable, a legendary torch, from
docs/design/expansion_design.md sections 2 and 3.
- A light (ItemDef.Type.LIGHT): energy 1.8, range 10, burn_seconds 0
  meaning it never burns down (make 0 mean that everywhere burn time is
  read, and hide the burn bar).
- A curse zone cannot put it out. A critical fail cannot make it slip
  (never_slips). Stowed, it gives no light, like any torch.
- While it is lit in a hand, every monster's sight range is 2 tiles
  longer. Write that in docs/combat_design.md.
- It mutters: a banter speaker of its own, rarely, never in a fight.
  Read docs/tone.md first and show me the lines.
- The Cursed Warden carries it: he is lit by it while he lives, and it
  drops where he falls, always.
Run the tests.
```

**7g.8:** place two or three legendaries in floor 1, each behind something that feels earned: a puzzle reliquary, a Fireball-only secret, or after the double-tap ambush. Save the rest for later floors and the procedural mode.

Done when: players remember the legendaries by name, and at least one of them causes an argument in the party.

## Phase 7h: Campfire and resting

A place to catch your breath: make camp, heal up, cook, and let the party talk. It's the calm between scares, and the home of the quieter character moments.

Updated 18 Nov from docs/design/expansion\_design.md (section 3 "7h"): one bedroll makes one camp, there is no tinderbox, and camp is made by using the bedroll like any other item. Camp spots are placed with 7j's remains.

- [ ] 7h.1 Resting rules into the combat page
- [x] 7h.2 Making camp
- [x] 7h.3 Cooking at the fire
- [ ] 7h.4 Interrupted rests
- [ ] 7h.5 Campfire banter
- [ ] 7h.6 Camp spots and bedroll in floor 1

**7h.1 prompt (Resting rules into the combat page)**

```
Copy the resting rules and numbers from docs/design/expansion_design.md
(sections 2 and 3 "7h") into docs/combat_design.md. No code. There is no
tinderbox.
```

**7h.2 prompt (Making camp)**

```
Add making camp, following docs/design/expansion_design.md sections 2
and 3 "7h".
- Bedroll is an item (stacks to 3). Using it (from a hand, a quick slot
  or the inventory) makes camp, if no living monster is within 4 tiles
  or in sight, the party is not in a fight, and no armed ambush trigger
  is within 2 tiles. Otherwise refuse with a line and spend nothing.
- Camp view: the dungeon view sinks to near black round a small fire
  that lights the walls beside it (a light in the sprite_lights group).
  HP and mana climb evenly to full over 30 s. A Stop button, and any
  movement key, ends it and keeps what was gained.
- A rest clears shaken and sickness, gives the rest of a running meal at
  once, clears spell recasts, and pauses every burn timer.
- Camp spots (DungeonMap.CAMP_SPOTS): old ash on the floor, a symbol on
  the map once seen. The interruption chances in section 2 depend on it.
- Making camp saves the game. F5 and the pause menu still save.
- GameEvents.camp_made and camp_ended(interrupted).
- The fire from the VFX tool, the bedroll and ash from PixelLab; log.
- A test-room station replacing the "not built yet" campfire.
Run the tests.
```

**7h.3 prompt (Cooking)**

```
Add cooking: while camped, raw food can be cooked at the fire (click
the food on the fire, or a Cook button in the camp view). Cooked food
heals more and faster than raw, and cooking mouldy bread removes its
sickness chance. Add raw meat (dropped by some monsters) that can't be
eaten raw without a sickness chance. Show a short sizzle and a message
("{name} burns the meat. Nobody mentions it.").
```

**7h.4 prompt (Interrupted rests)**

```
Add interrupted rests with the numbers in
docs/design/expansion_design.md section 2: three rolls a rest, at 10, 20
and 30 s, never in the first 10 s, never two rests running. On one: the
fire spits, the view cuts back, one or two tier 1 monsters appear 2
tiles away on a free tile the party can see, and a fight begins. The
party keeps what it healed and any level it gained. A short sting, not
the ambush build-up. One groggy line once the fight is over.
Run the tests, with a smoke check that seeds the dice for an
interruption and for none.
```

**7h.5 prompt (Campfire banter)**

```
Add campfire banter, following docs/tone.md: while resting, the party
has short exchanges around the fire, slower and quieter than combat
banter. Mix grim jokes with rare softer moments (the fighter and cleric
grudgingly agreeing on something, the mage admitting he's scared, the
thief sharing stolen food). Lines can reference what happened recently
(who died, who was revived, which legendary was found). Include the
fighter's "*cough* I'm hungry. Someone get a fire on." as a line that
can prompt making camp.
```

**7h.6:** add one or two safe-ish camp spots to the floor 1 map (cleared rooms with a door to shut), and place bedroll sparingly: enough for two or three rests in total.

Done when: making camp feels like a relief, being woken by a monster feels like a betrayal, and the campfire chats are where players get attached to the party.

## Phase 7i: Levelling up

The party grows stronger as they survive. XP is earned for clever play as well as fighting, and levels land at the campfire.

Updated 18 Nov from docs/design/expansion\_design.md (sections 2 and 3 "7i"): level 3 at the stairs for most parties, 4 for thorough ones; level 5 waits for floor 2. Everyone shares XP, dead or alive. Do Foundations Steps 7 and 8 first.

- [ ] 7i.1 Levelling rules into the combat page
- [ ] 7i.2 Shared XP
- [ ] 7i.3 Level up at the campfire
- [ ] 7i.4 Class perks
- [ ] 7i.5 Banter, character sheet and saving

**7i.1 prompt (Levelling rules into the combat page)**

```
Copy the XP table, the level curve, the per-level gains and the perks
from docs/design/expansion_design.md section 2 (and the rules in section
3 "7i") into docs/combat_design.md and the blueprint artifact. No code.
```

**7i.2 prompt (Shared XP)**

```
Do Foundations steps 7 and 8 first if they are not ticked.

Add shared party XP, following docs/design/expansion_design.md sections
2 and 3 "7i".
- Party.add_xp(amount, reason) and Party.level_up_party(): the test
  room's X and U keys already call these names.
- Award XP by listening to GameEvents: monster_killed (by the monster's
  tier), puzzle_solved, wall_broken and wall_purified where they open a
  hidden room, legendary_found, remains_searched, and the ambush's end.
- Everyone shares, dead or alive.
- The log shows the XP as its own short line under the event's line.
- A waiting level shows as a small warm mark on the portrait and is
  applied at the next camp, or at the stairs.
- A thin XP bar on the character sheet.
Run the tests.
```

**7i.3 prompt (Level up at the campfire)**

```
Apply level ups at the campfire: when the party makes camp, any
character with a level waiting levels up during the rest, one at a time.
For each: a warm golden pulse on their portrait from the fire, the new
level, and their HP and mana gains rolling up like the stat roll in the
character generator. If a perk is unlocked, show a short panel
explaining it. Keep it quick and skippable, and following
docs/art_style.md, not flashy or jingly: a quiet moment by the fire.
```

**7i.4 prompt (Class perks)**

```
Add the level 3 perks from docs/design/expansion_design.md section 2:
Follow-through (Fighter), Firm hand (Cleric), Light fingers (Thief),
Deep breath (Mage). Each is a line of data on the class and one hook in
the system it touches; no special cases by class name. Each shows on the
character sheet with a one-line description (read docs/tone.md first and
show me the four lines). Leave level 5 perks as named placeholders.
Run the tests.
```

**7i.5 prompt (Banter, sheet and saving)**

```
Finish levelling:
- Banter (following docs/tone.md): a line when each class levels up,
  e.g. fighter: "Feel stronger. Still hungry." cleric: "The Light
  rewards the faithful." Add a reply event so if the fighter levels up
  again soon after the cleric, the cleric is quietly furious.
- Character sheet: show level, XP to next level and unlocked perks.
- Save/load stores XP, levels, pending level ups and perks, and old
  saves without them still load.
- Add a line about levelling to CLAUDE.md.
```

Done when: levelling up by the fire feels like a reward for surviving, and the party is noticeably tougher at the stairs than at the start.

## Phase 7j: Fallen adventurers

The remains of those who came before, slumped in alcoves and corridors. Search them and you might find something useful... or not.

- [ ] 7j.1 Searchable remains
- [ ] 7j.2 Place remains in floor 1

**7j.1 prompt (Searchable remains)**

```
Add searchable remains, following docs/design/expansion_design.md
section 3 "7j".
- A prop against a wall on a floor tile; it does not block the tile.
  Four looks from PixelLab following docs/art_style.md. One first, shown
  in the game, for my OK.
- Search with F facing it, or a click, once. Afterwards it looks
  disturbed and the map marks it.
- DungeonMap.REMAINS sets the result: items (dropped on the tile in
  front, taken with the usual clicks and the loot pop-up), a note (a
  small parchment panel), nothing and a dry line, a bite (1-3 damage to
  the searcher through Party.hurt, and a closed bear trap to take), or
  it sits up (a skeleton beside the party; an ordinary fight).
- GameEvents.remains_searched(kind, hero); 5 XP if Party.add_xp exists.
- Banter for each kind (read docs/tone.md first; show me the lines).
- Saved. A test-room station with one of each kind.
Run the tests.
```

**7j.2 prompt (Remains on floor 1)**

```
Place the six remains from docs/design/expansion_design.md section 5:
1 at (8,13) in the alcove: bedroll. 2 at (8,9): nothing. 3 at (16,5):
a candle and Bellius's note (ask me for the text). 4 at (20,17):
bedroll, with old ash beside it (a camp spot). 5 at (16,15): it bites;
a bear trap and a flask of oil (remove the loose trap at (18,14)). 6 at
(14,19): it sits up. Run the tests.
```

Done when: players hesitate before searching a body, and search it anyway.

## Phase 7k: Traps and Hold Monster

Ways to stop a monster in its tracks, built on the new slower monster pacing: a held monster gives the party the same breather a step back does. Do 7k.1 first, because it creates the "held" status that 7k.2 reuses.

- [x] 7k.1 Monster status effects and the Hold Monster spell
- [x] 7k.1b Monster tiers (one table for every status effect)
- [x] 7k.2 Rusty bear trap
- [ ] 7k.3 Bear trap: what is left

**7k.1 prompt (Hold Monster spell)**

```
Add a small status-effect system for monsters, then a Hold Monster spell
that uses it. Check docs/combat_design.md first and add the rules there.

Status effects:
- A monster can carry timed statuses (start with "held"; design it so
  "slowed" or "poisoned" can be added later as data, not new code).
- Held: the monster can't move, turn or attack, and its move and attack
  timers pause. It can still be hit. Its sprite freezes on its current
  frame with a faint overlay, and its health bar shows a small held icon.
- Held monsters are helpless: attacks on them get a crit bonus (the thief
  most of all, it's a stab in the back).
- Emit GameEvents.monster_held(monster, source) and
  monster_released(monster). Save and load held state and time left
  (use the run flags or the monster state, whichever fits the current
  save code).

Hold Monster spell (mage, using the existing SpellDef and spell system):
- Targets the monster in the tile in front. Holds for about 5 seconds
  (tunable).
- Resistance: each MonsterDef gets a hold_resist chance (rat low,
  skeleton medium, slime immune: there's nothing to hold). Bosses are
  held for half the time; wall monsters are immune. On a resist:
  "The skeleton shrugs off the spell."
- Mana cost and cooldown set so it's a tactical choice, not spammed.
- Visuals in the arcane colour (cold pale blue, per the spell colour
  language): pale blue chains or runes wrap the monster, a soft blue
  light on it while held, and the chains shatter when it ends. Make the
  effect with PixelLab's VFX tools through the MCP, following
  docs/art_style.md, and log it in docs/asset_log.md.
- Banter hooks (following docs/tone.md), e.g. mage, proud for once:
  "It worked! It actually... ahem. As expected." Thief, stabbing a held
  monster: "Hold still. Good lad."
- Add it to the test room (a held-monster station) and run the tests.
```

**7k.1b:** done from a chat prompt on 13 Nov. Each MonsterDef has a tier (1 fodder to 4 boss), and one table, data/tiers.tres, sets every status effect's chance to land and duration per tier (held: 90/65/35/15%, tiers 3-4 half time). Slimes are held for less time. New status effects (slowed, poisoned, the bear trap) just add a row.

**7k.2 prompt (Rusty bear trap)**

```
Add a placeable trap item that uses the "held" status from Hold Monster.
Check docs/combat_design.md first and add the rules there.

Rusty bear trap (Item resource, stacks to 2):
- Use: with the trap in hand or a quick slot, click the empty floor tile
  in front to set it (only on an empty tile: not on doors, stairs,
  pressure plates or a monster). Setting takes a moment (about 1.5s; the
  thief sets it in half the time). It shows on the floor as an open,
  armed trap.
- Trigger: the first monster to step onto it gets snapped. It takes small
  damage, is held for about 3 seconds (using the existing held status
  and the monster's hold_resist, halved), and the trap closes. The slime
  oozes through it ("The slime oozes through the trap.") and wall
  monsters can't trigger it.
- After it fires, the closed trap lies on the tile and can be picked up
  and reused, with a small chance it breaks ("The trap's spring snaps.").
- The party can step onto an armed trap safely (they know it's there),
  with a dry message, e.g. "{name} steps carefully over the trap."
  Clicking an armed trap in front picks it back up, disarmed.
- Emit GameEvents.trap_triggered(trap, monster). Save and load armed
  traps, their tiles and closed traps.
- Art following docs/art_style.md (rusted, bloodstained iron): an inventory
  icon, the floor version open and closed, and a snap effect. Log it in
  docs/asset_log.md.
- Banter hooks, e.g. fighter, as a monster gets caught: "Ha. Stay." Cleric:
  "Crude. But effective." Thief, when the spring snaps: "Typical."
- Place one or two in floor 1 (one near a corridor where something chases
  you), add it to the test room, and run the tests.
```

**7k.3 prompt (Bear trap: what is left)**

```
The bear trap is built. Finish it from docs/design/expansion_design.md
section 3 "7k.2". The tier 3 "once per fight" rule came in with the
Cursed Warden: check it works and has its smoke check, don't rebuild
it. Check a plague rat is caught like any tier 1 monster. Give the trap
a weight of 3 for plates (only if 7e.6 weighted plates exist; otherwise
leave it for 7e.6). Update docs/combat_design.md. Run the tests.
```

Done when: you can drop a trap while backing down a corridor, watch a skeleton walk into it, and get two free swings in, and Hold Monster feels like a clever save, not an "I win" button.

## Phase 7l: Light and darkness

Light becomes something you manage. Core rule: a torch or candle takes up a hero's hand, so lighting the way costs a shield, a weapon or a backup, and who carries the light is a real choice. Ties into 7e.3 braziers (lit with a torch), 7e.4 darkness paths (put the torch out to see the runes), 7f.3 banter (darkness and torches going out) and 7d ambush clues (easy to miss in the dark).

Updated 18 Nov from docs/design/expansion\_design.md (sections 2 and 3 "7l"): only the first stretch of floor 1 stays lit (8 lit sconces, 7 unlit with a torch, 10 empty brackets), a sconce torch is a two-minute stub so torches are never created, and a hero with no light on their tile hits 10 less often with weapons. Do Foundations Step 7 first.

- [x] 7l.1 Torches and candles in hand
- [x] 7l.2 Wall sconces you can light and take
- [x] 7l.3 Curse zones that snuff flames
- [x] 7l.4 Throwing torches
- [x] 7l.5 Flask of oil
- [x] 7l.6 Place light and darkness in floor 1

**7l.1 prompt (Torches and candles in hand)**

```
Make light a resource the party carries. Check docs/combat_design.md and
docs/art_style.md first and add the rules there.

Darkness first:
- Today the party has an always-on light that follows it. Replace it
  with a faint "eyes adjusted" ambient, enough to make out nearby walls
  and silhouettes (the art style's readability rule still applies), plus
  whatever light the party is holding. Show me before-and-after
  screenshots of the same corridor and wait for my OK on how dark it is.

Torch and candle items (ItemDef, using the existing hands system):
- Torch: a strong warm light with a big radius, burns about 4 minutes
  (tunable). Candle: dimmer and smaller, burns about 10 minutes. Both
  stack in the backpack.
- A light only works held in a hand, and it takes that hand: no shield,
  weapon or focus item there. If several heroes hold lights, the
  brightest counts (cap any stacking).
- The torch hand's action is a weak swing with a little fire damage.
  Add a fears_fire flag to MonsterDef; monsters with it (slimes, and the
  rat when it exists) recoil from a torch hit.
- Burn time only runs while lit in a hand, shown as a thin bar on the
  hand slot; the flame flickers near the end, then "{name}'s torch
  gutters out." and the stub disappears. Stowing a lit light puts it out
  and keeps its remaining time.
- Quick slots accept torches and candles, so you can light the way while
  exploring and swap to a shield fast when something attacks.
- Critical fails can make a held torch slip: it rolls onto the floor
  tile in front, still burning, so the light moves there. Pick it back
  up as normal.
- Emit GameEvents.light_out(hero) and light_changed(level). Save and load
  burn times, lit state and torches lying on the floor.
- Banter hooks (following docs/tone.md), e.g. cleric holding a torch:
  "I am a priest, not a lamp." Fighter, when the torch dies mid-fight:
  "Brilliant."
- Art following docs/art_style.md: torch and candle icons, floor
  versions, and a held-flame effect from PixelLab's VFX tools. Log them
  in docs/asset_log.md.
- Give the party one torch and two candles at the start, add a
  light station to the test room, and run the tests.
```

**7l.2 prompt (Wall sconces you can light and take)**

```
Do Foundations step 7 first if it is not ticked.

Turn the wall torches into sconces, following
docs/design/expansion_design.md sections 2 and 3 "7l".
- DungeonMap.TORCHES entries gain a state: lit, unlit (holding a torch)
  or empty (a bare bracket). Saved.
- Light an unlit one by clicking it with a lit torch or candle in a
  hand, or with a Fireball or a thrown torch. It stays lit.
- Take the torch from a lit or unlit sconce with an empty hand: you get
  a torch with 120 s on it, and the bracket is empty.
- Put a torch into an empty bracket: it lights that stretch for good,
  keeps the burn time it had, and loses none while it hangs there.
  Taken out again, it has that same time.
- So torches are never created: check that lighting a sconce and taking
  its torch back cannot be repeated for free, with a smoke check.
- The map shows a sconce once seen, lit or dark.
- A bracket's art (empty, with an unlit torch) from PixelLab; log it.
- Both kinds in the test room's light room. Run the tests.
```

**7l.3 prompt (Curse zones that snuff flames)**

```
Add curse zones, following docs/design/expansion_design.md section 3.
- DungeonMap.CURSE_ZONES: an id and its tiles.
- Inside one: held torches and candles sputter for a second and go out,
  and will not relight; sconces and braziers will not light; a burning
  torch lying or thrown there goes out; oil will not catch. The
  Unquenchable and spell light are untouched.
- Bless makes a pocket for 20 s: the party's tile and the tiles beside
  it, where flames can be lit and stay lit.
- A thin green haze on the floor of the zone (the VFX tool), visible
  from the tile before it. No message until a flame dies: "The air here
  hates fire."
- A puzzle effect clears a zone for good (a run flag).
- GameEvents.entered_curse_zone and left_curse_zone; banter hooks.
- Nothing above tier 1 may be placed in a zone: warn at load if so.
- A zone in the test room's light room. Run the tests.
```

**7l.4 prompt (Throwing torches)**

```
Let a lit torch be thrown, with the numbers in
docs/design/expansion_design.md section 2. Reuse the thrown-weapon code
and light_field.gd, which already keeps a slipped torch burning on the
floor. It flies up to 4 tiles with its light, does 1-3 fire to a monster
it hits (which recoils if it fears fire), and burns where it lands.
Monsters that fear fire will not step onto its tile. Picking it up sends
it home to the hand it left, as other throwables do. A candle cannot be
thrown. Run the tests.
```

**7l.5 prompt (Flask of oil)**

```
Add a Flask of oil (ItemDef, stacks to 3) with the numbers in
docs/design/expansion_design.md section 2 and the rules in section 3,
reusing the thrown-item and fire systems. Add the rules to
docs/combat_design.md.
- Throw it at the floor: it always lands on the tile in front, never
  under the party, and leaves an oil slick (lasts until lit or 120 s).
  It bursts into flame when fire touches it (a thrown torch, a torch
  swing on that tile, a Fireball) and burns for 6 s, lighting the area.
- A burning tile does 2 a second to a monster on it and 1 a second to a
  hero. Monsters that fear fire will not cross it.
- Throw it at a monster: it is doused for 30 s, and the next fire hit
  does +6 and sets it burning for 2 a second over 3 s. "Doused" is a
  StatusDef with its own row in data/tiers.tres; slimes can be doused.
- Use it on a weapon: the next 3 landed hits do +2 fire.
- The throw is refused, and nothing spent, while the party stands in a
  curse zone.
- It combos with the bear trap: a trapped monster on a slick can be lit.
- Burning oil is a light in the sprite_lights group.
- Emit GameEvents.oil_ignited(cell). Save and load slicks, burning tiles
  and doused monsters.
- Banter hooks (following docs/tone.md), e.g. a hero walking into the
  party's own fire: "{name} has made a terrible decision."
- Art following docs/art_style.md: a grimy flask icon and floor version,
  an oil slick decal, and the burst and flames from PixelLab's VFX
  tools. Log them in docs/asset_log.md.
- Add it to the test room's light room and run the tests.
```

**7l.6 prompt (Light and darkness on floor 1)**

```
Do 7e.1 (Puzzle framework) first if it is not ticked: the cave's
curse zone lifting needs its "every monster in an area dead" condition.

Place the light from docs/design/expansion_design.md section 5: the
three lists of sconces (8 lit, 7 unlit with a torch, 10 empty), loose
torches at (15,15) and in room 2, a candle in room 3, the curse zone
over the cave (x 6-10, y 15-19) which lifts when its three plague rats
are dead, and add the -10 to hit for a hero whose tile gets no light
beyond the ambient (weapons only, never spells, never monsters). Then
play the floor three ways and give me the numbers: seconds of torch and
candle left at the Warden's door for a careful run, a careless one, and
a full clear.
```

Done when: you hesitate before throwing your last torch, argue with yourself about whether the fighter should give up his shield to carry it, and walk into a curse zone and feel the dark close in.

## Phase 8b: Character generator

You don't roll four strangers: you're handed Brannoc, Brother Felix, Wren and Fennick, and you may change their names, portraits and rolled scores. Play is lit from the start. Updated 18 Nov from docs/design/expansion\_design.md (section 3 "8b"): no races for now, one hero per role always (Phase C adds the class choice within each role). Do Foundations Step 8 first.

- [ ] 8b.1 Stats rules into the combat page
- [ ] 8b.2 Party screen
- [ ] 8b.3 Scores and rolling
- [ ] 8b.4 Portrait picker and names
- [ ] 8b.5 Finishing the generator

**8b.1 prompt (Stats rules into the combat page)**

```
Copy the character generator's rules from
docs/design/expansion_design.md section 3 "8b" into
docs/combat_design.md: six scores, the modifier, the formula table, the
key-score minimums. No races. Then give the four heroes scores that
produce exactly today's numbers and show me the table. No code.
```

**8b.2 prompt (Party screen)**

```
Do Foundations step 8 first if it is not ticked.

Add the party screen from docs/design/expansion_design.md section 3
"8b", at 640x360 in the stone UI style. New Game opens it (after the
intro on a first launch). It shows Brannoc, Brother Felix, Wren and
Fennick in their 2x2 formation with Play already lit: one click starts
the game with the party as it is today. Clicking a hero opens their
editor (next step). Dragging one portrait onto another swaps places, as
in the game. Show me a screenshot of the layout before going on.
```

**8b.3 prompt (Scores and rolling)**

```
Add the hero editor's scores, from docs/design/expansion_design.md
section 3 "8b". The class of a slot cannot be changed. Six scores,
rolled 4d6 dropping the lowest, all six at once, with a quick tumble of
the numbers and no limit on rerolls. Under them, the HP, attack,
defence, mana and crit they give, with the change from the ready-made
hero in the sheet's better/worse colours. A roll below 9 in the class's
key score is refused with a line. A Reset button puts the ready-made
scores back. Saved with the hero. Run the tests.
```

**8b.4 prompt (Portrait and name)**

```
Add the name and portrait to the hero editor. A name of up to 14
letters with a Random button (a short list per class; read docs/tone.md
and show me the lists first). Three portraits per class to flick
through: the one that exists and two new ones from PixelLab at the same
size and style, generated one at first for my OK, with hurt and dead
versions derived as the existing ones were. Log them. Run the tests.
```

**8b.5 prompt (Finishing the generator)**

```
Finish the party screen: starting gear stays the class's own
(CharacterDef.start_hands and start_quick); the formation chosen on the
screen is the one the game starts in; the save stores scores, name and
portrait, and an older save loads with the ready-made heroes. There is
no Quick Party button: the screen already starts full. Add a paragraph
to CLAUDE.md. Run the tests.
```

Done when: you can roll a party from scratch in under two minutes, and their stats noticeably change how fights go (a weak mage feels weak, a strong fighter hits hard).

Parking lot for later: alignment, multi-classing, importing a party into the next floor.

## Phase C: New classes (four roles, three classes each)

The party is always four heroes, one per role; a slot's role never changes, but the class inside it can. Front line: Fighter, Barbarian, Monk. Healer: Cleric, Druid, Paladin. Sneak: Thief, Ranger, Bard. Caster: Mage, Necromancer, Spellsword. The ready-made four stay, so New Game is still one click. The full plan, with every number and banter line, is docs/design/new\_classes\_plan.md.

Do this phase last: every C step comes after the whole build order up to 8b, because the classes lean on resting, levelling, curse zones, oil, the grab and the party screen.

- [ ] C.1 Roles and the class picker
- [ ] C.2 Class abilities and the ability button
- [ ] C.3 Banter groundwork and the new voices
- [ ] C.4 Corpses
- [ ] C.5 Minions and the third row
- [ ] C.6 Placeholder portraits
- [ ] C.7 Barbarian (batch 1)
- [ ] C.8 Bard (batch 1)
- [ ] C.9 Ranger (batch 1)
- [ ] C.10 Necromancer (batch 1)
- [ ] C.11 Batch 1 check
- [ ] C.12 Monk (batch 2)
- [ ] C.13 Spellsword (batch 2)
- [ ] C.14 Druid (batch 2)
- [ ] C.15 Paladin (batch 2)
- [ ] C.16 Batch 2 check

**C.1 prompt (Roles and the class picker)**

```
Read docs/design/new_classes_plan.md sections 1-3 and the 8b page of
docs/design/expansion_design.md with its addendum. Add CharacterDef.role
(front, healer, sneak, caster), set it on the four existing classes, and
add data/classes.tres listing every class file. Give the party screen's
four slots a class choice: arrows step through the classes of that
slot's role only; changing class resets the slot's name, portrait and
scores to the class defaults; Play stays lit with the ready-made four.
Fill Party.hero_defs from the screen. Save each slot's class_id; an
older save loads as the ready-made four. The healer slot always starts
with the lit torch and two candles. Keep the smoke test on the
ready-made four and add tests/classes_test.gd. Show me the screen
before going further.
```

**C.2 prompt (Class abilities and the ability button)**

```
Read the plan's section 4 opening. Add CharacterDef.abilities (SpellDef
files) and a small button beside each hero's name that opens that list
in the spell list's frame, through the pop-up layer. Abilities use the
spell rules that exist: mana, the action wait, recast waits, sounds.
Add the SpellDef fields the classes need (toggled song, shape, weapon
enchantment, raise, corpse cost, no-mana once per rest) without using
them yet. The Cleric and Mage keep their holy symbol and spellbook as
they are. Add CharacterDef.refuses (item kinds) and the no-weapons /
no-armour flags. Test with a dummy ability in the test room.
```

**C.3 prompt (Banter groundwork and the new voices)**

```
Read docs/tone.md and the plan's section 6. Add role speakers
(role:front etc., spoken only when the slot's class has no line for the
event), the `with` condition (class ids that must be in the party), and
the {minion} and {was} placeholders. Give every existing line that
names a job or answers a particular class a `with`. Extend
tests/banter_test.gd: every class or its role must cover fight_started,
hero_died, hero_revived, ambush_warning, ambush_started, ambush_over
and boss_seen. Add the plan's 16 role lines. Add a voice entry for each
new class to docs/tone.md section 6, from the plan. No class lines yet.
```

**C.4 prompt (Corpses)**

```
Read the plan's Necromancer section. A slain skeleton, skeleton guard
or plague rat leaves a corpse on its tile for 45 s: a placeholder heap
sprite, tinted by sprite_lighting, never blocking, never on the map,
never saved. Slimes, tentacles, the giant hand and minions leave none;
the Warden's crumbles at once. Call them corpses, never remains (7j).
GameEvents.corpse_left / corpse_gone. Add MonsterDef.undead and
.cursed and set them as the plan says. Smoke checks.
```

**C.5 prompt (Minions and the third row)**

```
Read the plan's Necromancer section and "the third row". A minion is a
party member without a class: it sits in a spare panel (positions 4
and 5), has the stats the plan gives, strikes by itself only from the
front row, can be dragged like a hero, is never healed, and falls apart
on the plan's four conditions. Widen the party code to three rows: a
blow from behind lands on the rearmost occupied row; who can swing is
unchanged. Names from the plan's list on the panel and in the log.
Minions are saved. No Necromancer yet: spawn one with a test-room key.
```

**C.6 prompt (Placeholder portraits)**

```
Make placeholder portraits for the plan's section 8 list by script from
the existing portraits (recoloured, with the class's initial), at the
real portrait size, with hurt and dead versions derived as usual. List
every one in the placeholder list of docs/asset_log.md. Do not spend
PixelLab generations.
```

**C.7 prompt (Barbarian)**

```
Read the plan's Barbarian section, his row in section 3 and his
banter. Build him: data file, rage bar in the mana row (5 per HP lost,
10 per kill, ignites at 100 for 10 s: damage x1.5 and no grab; drains 5
a second out of a fight; empties at camp), refuses potions and scrolls,
the grab rule, level gains and Blood up. Add his banter and the
Barbarian scroll pairs. Smoke and class-test checks, a test-room key,
docs and the blueprint. Run all tests and the game.
```

**C.8 prompt (Bard)**

```
Read the plan's Bard section and his banter. Build him: data file, the
three songs as toggled abilities (1 mana to start, 1 every 3 s; one at
a time; never on himself; stop on no mana, death, camp or grab), the
note on his panel, four short lute sounds (log them in
docs/asset_log.md), level gains and Encore. Add his 25 lines and the
Bard pairs with the Cleric and the Paladin. Checks, a test-room key,
docs and the blueprint. Run all tests and the game.
```

**C.9 prompt (Ranger)**

```
Read the plan's Ranger section and his banter. Build him: data file,
tracking (2 tiles ahead along open tiles, a paw mark at the top of the
view and one log line per monster, works in the dark, never sees an
ambush or an unsearched body), +2 attack and half of misses recoverable
with a launcher, no sickness from raw or mouldy food, level gains and
Keen nose. His banter. Checks, a test-room key, docs and the blueprint.
Run all tests and the game.
```

**C.10 prompt (Necromancer)**

```
Read the plan's Necromancer section and his banter. Build him on C.4
and C.5: Raise Dead, Life Drain (nothing back from the undead), Bone
Armour (does not add to Shield), refused healing from the Cleric and
the Paladin, the minion's watch at camp, level gains and Dear departed.
His banter (including the offer over a fallen hero) and nothing for the
Paladin pairs yet. Checks, a test-room key, docs and the blueprint. Run
all tests and the game.
```

**C.11 prompt (Batch 1 check)**

```
Play floor 1 start to stairs with each batch 1 class in its slot (four
runs, the rest ready-made), then once with all four. Fix what breaks,
note what feels off, measure the new front and sneak numbers against
the plan's section 3, and report. Build a demo only if I ask.
```

**C.12 prompt (Monk)**

```
Read the plan's Monk section and his banter. Build him: data file, no
weapons or armour (a light is allowed), fists and defence by level,
dodge 15% and the counter, a 4-slot backpack that Take all skips,
"LIGHT PACK" in the loot pop-up, Still water, Grudge's refusal. His
banter and the Monk and Thief pairs. Checks, a test-room key, docs and
the blueprint. Run all tests and the game.
```

**C.13 prompt (Spellsword)**

```
Read the plan's Spellsword section and his banter. Build him: data
file, Enchant (fire, frost, shock; 4 hits or 20 s; one at a time), the
slowed status with its tier row, fire counting as a torch's fire with
oil, the blade's light, fire going out in a curse zone, level gains and
Spellstrike (Magic Missile). His banter. Checks, a test-room key, docs
and the blueprint. Run all tests and the game.
```

**C.14 prompt (Druid)**

```
Read the plan's Druid section and her banter. Build her: data file,
Poultice on its own track, Reclaim (purifies corruption and makes the
curse-zone pocket as Bless does), bear and wolf (a stat and portrait
swap; no casting, items or quick slots; a held light is stowed; the
wolf tracks and ignores the dark), Change back, level gains and Deep
roots. Her banter and the Ranger and Druid pair. Checks, a test-room
key, docs and the blueprint. Run all tests and the game.
```

**C.15 prompt (Paladin)**

```
Read the plan's Paladin section and his banter. Build him: data file,
Lay on Hands once per rest (refused on the Necromancer), the +1 defence
aura, Smite (undead and cursed, the flash on minions, purifying and the
pocket with no monster in front), the Vow (only monsters that struck or
were struck count), level gains and Steadfast. His banter and the
Paladin pairs with the Necromancer and the Bard. Checks, a test-room
key, docs and the blueprint. Run all tests and the game.
```

**C.16 prompt (Batch 2 check)**

```
As C.11, for batch 2, then three runs with mixed parties chosen to be
hard (Barbarian with Paladin; Monk with Necromancer; Bard, Ranger and
Spellsword together). Report what is too strong and too weak against
the plan's section 3, with numbers, before changing any.
```

Done when: every class is selectable in its role's slot with working abilities, no party is ever silent, and the three hard mixed parties can all reach the stairs.

## Phase E: Dungeon editor (squared paper)

Draw a dungeon on squared paper, click Build, and walk it in 3D: the way Eye of the Beholder players mapped dungeons with a pencil, except the paper builds the dungeon. It's a debug tool first (like the test room), and could become a "build your own dungeon" mode later. It makes floor 2, puzzle rooms and Phase 9's room templates (9.4) much quicker to make. Do Foundations Step 12 first: the editor saves and loads levels as data.

Rules for this phase:

- Sonnet for every step; switch to Opus if E.4 gets tangled.
- The editor only writes level data. It never adds a second way of building the dungeon: Build uses the same code that builds floor 1.
- Every step keeps floor 1 playing exactly as before. Run the tests, plus tests/editor\_test.gd once E.5 adds it.

- [x] E.1 Squared paper and drawing
- [x] E.2 Doors, gates, levers, stairs and sconces
- [x] E.3 Items and monsters
- [x] E.4 Build and play
- [x] E.5 Save, load and the round-trip test
- [ ] E.6 Curse zones, puzzles and ambushes (later, once 7e and 7d exist)
- [ ] E.7 donjon import (optional)

**E.1 prompt (Squared paper and drawing)**

```
Do Foundations step 12 first if it is not ticked.

Add a dungeon editor, opened with a debug key from the main menu and the
test room (like F12). Follow docs/art_style.md: squared paper on
parchment, in the style of the full-screen map on M, inked lines, no
smooth gradients.
- A grid of squares the size of a level (new level: 32x32, set in the
  config). Each square is wall (filled, cross-hatched) or floor (blank).
- Left-click or drag paints floor; right-click or drag rubs back to
  wall. The outer edge always stays wall.
- Pan with the middle mouse or WASD, zoom with the wheel, coordinates of
  the square under the mouse in a corner (matching the (x,y) the
  roadmap uses).
- Undo and redo (Ctrl+Z, Ctrl+Y), at least 50 steps.
- A New button (asks for width and height) and a Close button.
No saving yet. Show me a screenshot of a small dungeon drawn in it, and
run the tests.
```

**E.2 prompt (Doors, gates, levers, stairs and sconces)**

```
Add a toolbar to the editor. Each tool places a thing the game already
has, using the same data floor 1 uses (read levels/floor_1.gd for the
shapes; add no new kinds of thing):
- Plain door, locked door, gate (portcullis), cracked wall, lever
  (linked to a door or gate: click the lever, then the door; draw a thin
  ink line between them while either is selected).
- Stairs down, and the party start (one only, with the direction the
  party faces, shown as an arrow).
- Sconce on a wall face (lit, unlit or empty), placed by clicking the
  edge of a square.
- Each thing is a small inked icon on the paper (PixelLab or by script,
  following docs/art_style.md; log them).
- Click a placed thing to select it; Delete removes it; R turns it.
- Things only go where the game allows them (a door between two walls, a
  sconce on a wall face): refuse anything else with a short message.
Run the tests and show me a screenshot.
```

**E.3 prompt (Items and monsters)**

```
Add items and monsters to the editor.
- A side panel listing every ItemDef in data/items and every MonsterDef
  in data/monsters, read from the folders, so new ones appear without
  touching the editor. Each shows its own icon or sprite, small.
- Click one, then a floor square, to place it. Items stack in a floor
  pile like the game's; monsters take the square and face a direction.
- Hover a square to see what's on it; click to select, Delete to remove.
- Keys: a placed key can be linked to a locked door, like levers.
- Keep the curse-zone rule: warn if anything above tier 1 is placed in a
  curse zone (once E.6 exists).
Run the tests and show me a screenshot with a few monsters and items.
```

**E.4 prompt (Build and play)** (Sonnet; Opus if it gets tangled)

```
Add Build to the editor: it turns the paper into a level and drops the
party into it in the 3D view, using DungeonMap.use_level_data and the
same building code as floor 1.
- Before building, check: there is a party start and stairs down; every
  floor square, item and monster can be reached from the start
  (flood-fill through doors, counting keys and levers like a player
  would); every lever and key is linked. Show problems as a list, with
  the squares marked in red ink. Missing start or stairs refuse the
  build; the rest are warnings.
- The party starts as the ready-made four with full HP and mana and
  their starting gear.
- A key (Tab) goes back to the paper with the party's square marked, and
  Build again puts the party back where it was.
- Nothing from a build-and-play is saved to the real save slot.
Run the tests, then build a small dungeon with a door, a lever, a gate,
two monsters and stairs, and show me a clip of walking it.
```

**E.5 prompt (Save, load and the round-trip test)**

```
Add Save and Open to the editor.
- Save writes levels/<name>.gd in the exact shape of levels/floor_1.gd
  (ask before overwriting). Open lists the files in levels/.
- Opening levels/floor_1.gd shows floor 1 on the paper with everything
  the editor knows about. Things it doesn't edit yet (puzzles, curse
  zones, ambushes, remains) are kept untouched when saving, and shown as
  grey "not editable yet" marks.
- Add tests/editor_test.gd: open floor 1, save it under a new name
  without changing anything, and check the saved data is identical to
  floor 1. Then draw a small level by script, save, open, and check it
  matches.
- Add the editor to CLAUDE.md (how to open it, what it can edit).
Run all the tests, then open floor 1, build it and walk a few squares.
```

**E.6 prompt (Curse zones, puzzles and ambushes)** (later, once 7e and 7d exist)

```
Add the remaining level things to the editor, each from the data the
game already uses: curse zones (paint squares in a translucent curse
green), ambush trigger tiles and their wall, braziers and their groups,
darkness runes, altars, pressure plates and their weight, remains and
their result, camp spots. Puzzles: pick a puzzle, then click its
conditions and effects on the paper; show the links as ink lines. Keep
the round-trip test passing with floor 1. Run the tests.
```

**E.7 prompt (donjon import)** (optional)

```
Add an Import button to the editor that reads a JSON export from
donjon.bin.sh/d20/dungeon/. First read the sample in
tools/donjon/samples/ and tell me how it stores cells, rooms, doors,
stairs and secret doors, before writing code. Import walls, floor,
doors (secure ones become locked doors with no key), portcullises,
secret doors as cracked walls, and the stairs. Ignore donjon's monsters,
traps and treasure. Room numbers become labels on the paper that I can
hide. Then I finish it by hand in the editor. Run the tests.
```

Done when: you can draw a small dungeon on the paper in ten minutes, click Build, walk it, go back and move a door, and save it, without opening a single script.

## Phase 9: Procedural mode (after floor one ships)

A second game mode that builds a new dungeon every run. The handcrafted floor stays as the main game.

- [ ] 9.1 Seeded layout generator
- [ ] 9.2 Solvable key-and-door placement
- [ ] 9.3 Monsters and loot scaled by distance
- [ ] 9.4 Hand-built room pieces stitched together
- [ ] 9.5 New Run screen with a seed

**9.1 prompt (Seeded layout generator)**

```
Create a DungeonGenerator script that outputs the same level array format
as my handmade floor (1 = wall, 0 = floor), from a seed, so the same seed
always gives the same map. Approach: place 6-10 non-overlapping rectangular
rooms in a 32x32 grid, connect them with 1-tile corridors so every room is
reachable, and put the start in one room and the stairs in the room
farthest from it. Add a debug key (F5) that regenerates with a new seed
and shows it on the minimap.
```

**9.2 prompt (Key-and-door placement, Opus)**

```
Add lock-and-key placement to the generator so every dungeon is always
solvable. Work out the path from start to stairs, place 1-2 locked doors
along it, and put each door's key somewhere reachable without passing
through that door. Optionally link a lever to one door the same way. Add a
validation step that flood-fills from the start, simulating picking up
keys, and confirms the stairs can be reached. Regenerate if it fails.
```

**9.3 prompt (Monsters and loot by distance)**

```
Place monsters and items using distance from the start as a difficulty
scale: weak monsters and basic loot near the start, tougher monsters and
better items near the stairs, and a mini-boss guarding the stairs room.
Keep the counts and difficulty tiers in one config resource so I can
tweak the balance without touching code.
```

**9.4 prompt (Room templates)**

```
Let me hand-design small room templates (e.g. 5x5 to 9x9) as text files,
with markers for doorways, lever spots, monster spawns and decorations.
Update the generator to fill some rooms with random templates (rotated or
mirrored) instead of plain rectangles. Start with 5 templates I'll write:
a trap room, a shrine, a storeroom, a pillar hall and a dead end with a
secret button.
```

**9.5 prompt (New Run screen)**

```
Add a New Run option to the main menu that starts a procedural dungeon.
Show the seed on the run screen and the death and win screens, and let me
type a seed in to replay a specific dungeon.
```

Done when: ten runs in a row are all beatable, and at least a few of them surprise you.

**Parking lot: ideas for after floor one**

- More floors and a bigger final boss
- Full spell system and character classes
- Character creation at the start
- Wall-text riddles and secret buttons
- Automap
- Story and NPC encounters
- Voxel v2 experiment: a separate prototype project with fully voxel, destructible dungeons, only after floor one ships
- Cooking mini-game at the campfire: cook monster meat with pots, pans and ingredients found in the dungeon

## Extra steps (built outside the plan)

Things built from chat prompts that no step above covers. All done; added so the roadmap matches the build. Each line has the commit that made it.

- [x] Test room: a debug-only level with stations, wall signs, debug keys and the H overlay (`0572759`)
- [x] Test Room export preset, and a build that offers only the test room (`178e4a4`, `8d9f701`)
- [x] Hires-720: 2D UI at the window's real resolution, 256px monsters, walls, floor and decals, 128px portraits, frame at 1280x720 (`ef163f1`, `6bc2a34`, `12030cc`, `968fe56`, `cc8a5e0`, `0e91d76`)
- [x] Carved wooden frame round the 3D view (`07c22de`, `9f02144`)
- [x] Six-hero screen layout: the 3D view in the middle, three panels down each side (`108f3a3`)
- [x] Corrupted walls: only a Bless purifies them, PixelLab veins, purge and rot, a small puzzle system (`825d1c1` and the commits after it)
- [x] Full-screen map on M, the corner map restyled, map icons and torchlight flicker (`7349d8c`, `423569a`, `8c1d444`, `af6a385`, `d1c5d84`)
- [x] Pop-up layer and the new spell list (`e9026d4`, `7802bd0`)
- [x] Loot pop-up: right-click a floor item to choose whose backpack takes it (`2362911`)
- [x] Critical hits and fails (`c295c16`)
- [x] Food: five slow-healing items, mouldy bread, monster drops (`5c0b4aa`)
- [x] Hits from behind and the sides: directional jolt, glow and sound (`c68c362`)
- [x] Monster hit effects: a PixelLab effect across the view with each landed blow (`f8210f2`)
- [x] Monster pacing and attack timing (`7a0c0d2`, `939a461`)
- [x] Intro cutscene (`1779f51`)
- [x] Title screen and UI art pass (`8607bf0`, `1d29cf2`)
- [x] Scroll of Resurrection (`5211b38`)
- [x] Character sheet discoverability, equip from the cursor and the floor (`a008fd8`, `453b77f`, `5839ee9`)
- [x] New weapons: long sword, flail, slingshot and stones, bow and arrows (`b96fed3`, `d0825fe`, `553b527`, `70fb329`)
- [x] Only a caster holds a spellbook or holy symbol (`0462061`)
- [x] Key pick-up banner (`ea68b11`)
- [x] Fireball and Magic Missile shockwave ripple (`46080ea`, `d110025`)
- [x] Curse zone look pass: murky fog creeping from the edges, sputtering flame with a wisp, slow edge-glow vignette, Bless pocket recoil, Reduce flashing (`5a81a22`)
- [x] Zombie: a PixelLab-styled, animated tier 2 monster in the test room and on floor 1, room 3 at (15,11) (`64d971b`)
- [x] Zombie death gas: a 1 in 5 chance of a toxic cloud within a tile of the body that stings the party, with a test VFX cloud (`6ec327b`)
- [x] Design docs and demo READMEs: `docs/design/expansion_design.md` (`9cadb9c`), the classes plan (`69d9eca`), `docs/code_review.md`, `docs/tone.md`, `docs/technical_brief.md`, demo READMEs v0.2 to v0.11
- [x] Editor: double-click the party start (or Enter with it selected) to build and play the map from there (`d0ddbc9`)
- [x] Zombie gas gets its own palette colour, `mustard_500` for rot and disease, and a smoke-puff VFX cloud with dark flies (`f0ecca9`)
- [x] Minimap moved to the top-right corner of the 3D view and made slightly translucent (`e69ac12`)
- [x] Food held on the cursor and clicked onto a portrait goes into that hero's backpack; Shift+click feeds them (`c2bf36c`)
- [x] Inventory shows the hero's two quick slots beside hands and armour; I opens and closes the inventory (`653b1b8`)
- [x] Mana Potion: restores 5 mana (`ItemDef.mana_amount`), violet PixelLab art, in the test room's item table (`274528e`)
- [x] Story arc design doc, `docs/design/story_arc.md`, "The Prisoner in the Dungeon" (`1cbb8c4`), and the roadmap becoming the master copy in this repo (`b70a89f`)
- [x] Screenshots of the dungeon editor, E.1 to E.5, in `screenshots/dungeon_editor/` (`62e575d`)
- [x] Camp art and the test room's campfire station: PixelLab campfire (crossed logs, ember bed, animated VFX flame), cooking spit and one 3D bedroll for each hero, shown as scenery by `scripts/camp_site.gd` (STRUCTURES kind `campfire`); no camping yet, that is 7h.2 (`0585a00`, then the kindling and front logs in `05e5279`)
- [x] The Cursed Warden redrawn from the user's PixelLab "hardcore warden" picture: PixelLab idle, attack and walk clips, a hurt made in code, 128px frames (`f379bf8`)
- [x] Background music: Walen's "Dark Heart" loops over the menu and the game from one player that survives scene changes; credit in `audio/music/CREDITS.md` (`ea9a59c`)
- [x] The Azure Brand: a legendary glowing blue long sword with flame damage, built on the 7g framework (PixelLab art recoloured to palette steel greys; its blue is a run-time tint and light: no blue colours in the palette), in the test room (`a3df5fd`)
- [x] The Red Shaman: a goblin caster from the user's PixelLab picture with a ranged bolt attack (`MonsterDef.ranged_range`), animated, VFX bolt and impact, in the test room arena (`ca0f8fb`)
- [x] Traps: a snap the party can neither see nor hear is silent (`TrapField.witness`: seen within 10 tiles with a clear line, heard within 6, else no log, sound or news), and level monsters may hold their ground (`"holds": true`) so the test room's trap skeleton stops wandering onto the trap (`3dd06ce`)
- [x] The Goblin: a tier 1 spear carrier from the user's PixelLab picture, animated; two guard floor 1's west corridor, one in the test room arena (`6254d0e`)
- [x] Message log scrolls back: mouse wheel or a thin bar, 200 lines of history, your place kept when a new line arrives (`7d784c5`)
- [x] Hover tooltips restyled: 8 px text in a stone-black box with a rust edge, from one project theme (`12baaf0`)
- [x] Camp beds made rounded: soft mat, puffy quilt, rounder pillow and a rolled blanket at the foot (`fa43a54`)
- [x] Camp beds redrawn from the user's own bedroll picture with PixelLab: a top-down bedroll, first flat on a thin body (`ea32e4e`), then wrapped over a thick rounded 3D mat resting on the floor, fixed in place, tinted per hero (`8371c46`)

## Ideas inbox

New ideas land here first, instead of going into finished phases. Once the current queue is clear, we sort them into proper steps together.

- (Now covered by the Spell VFX pass) Reactive spell lighting: lights that travel down corridors with a fading light trail, moving shadows, pixel-art normal maps on walls, fog that catches spell light (prompt given in chat on 7 Nov). Also the Fireball VFX recipe: PixelLab flipbooks, synced lights, pixel particles, scorch marks, palette shader.
- (Now covered by Phase C) Bard class: songs as party buffs and monster debuffs (one song at a time, draining mana while it plays), a chiptune lute for each song, and a bard who narrates the party's failures in verse (e.g. "The Ballad of the Fumbled Sword"). Needs a design pass and a slot in the character generator (8b).
- Game 2: the party meets Bellius the bard, who has already escaped this dungeon. Possible foreshadowing in game 1: traces he left behind (a carved "Bellius was here", a torn song sheet, a snapped lute string, a skeleton audience arranged in rows).
- Story arc, "The Tales of Bellius": torn pages scattered through the dungeon as collectibles, each a short tale in Bellius's own voice. Near the end, the thief reads the last page and discovers they're Bellius's relation, unlocking a single bard song that helps in the final boss fight (the cleric is furious the thief got the gift). Sets up game 2: go find the old man.
- (Built, except fog of war, which is parked: see Leftovers) Minimap makeover: replace the debug minimap with a hand-drawn parchment map in a rusted iron frame, fog of war (only explored tiles drawn), PixelLab icons for the party arrow, doors, stairs, levers, campfires and found secrets (no traps or ambushes), a faint torchlight flicker from the VFX suite, and a full-screen automap on M. Coordinates move behind the debug overlay (prompt given in chat on 9 Nov).
- (Built in Foundations Step 3; check whether the Rename button exists, otherwise 8b.4 covers it) Character names instead of class labels: default names on the party panel (e.g. Brannoc, Brother Felix, Wren, Fennick), the class moved to the tooltip and character sheet, a Rename option with a random-name button, and all messages and banter using {name} (prompt given in chat on 7 Nov).
- Feeli the dungeon cat, as a companion: first met asleep at a campfire spot (stares at the party, then flops over for a belly rub, giving a small morale boost or heal). Later joins the party and sniffs out traps, secret doors and hidden items (stares at the spot, swishes his tail, hisses at trapped doors). He also sees ghosts: invisible spirits only show themselves through Feeli staring at an empty corridor, fur up, growling. Banter: the fighter goes soft ("...who's a good lad."), the cleric pretends not to care but pets him anyway. Synergy: with Feeli in the party alongside Brother Felix (the smug cleric), the party gets a big boon, "The Two Felixes" (e.g. stronger Bless and heals, and Feeli's senses sharpened), plus banter about which Felix is holier.
- Smudge, the friendly ghost: in memory of Bell's cat Smudge (aka Smug, Smugger), 19 years of naughty, rebellious fun. Somewhere in the dungeon, Feeli stares at an empty corner, but instead of growling, his tail goes up and he purrs. She's never seen, only her mischief: "Feeli watches something invisible knock a candle off the shelf.
