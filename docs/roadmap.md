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

## Leftovers from finished phases

Loose ends from phases that are otherwise done, plus things the 13 Nov tech brief showed don't match the roadmap. Their phases moved to the Done tab; the steps and prompts live here until they're ticked.

- [x] 5.7 Enemy health bars (Phase 5)
- [ ] 7b.8 Dead weight: the party slows while carrying a dead character (Phase 7b)
- [ ] Mini-boss: 8.2 is ticked, but the 13 Nov tech brief says there's no mini-boss and tiers 3-4 are empty. Check the floor 1 map, and build one near the stairs if it's missing.
- [ ] Plague rat: planned in 4.3 and 7c.2 but not in the game (the acid slime took its place). The tier table and the bear trap expect one, as a tier 1 monster.
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
- [ ] VFX.9 Shockwave or heat-haze shader on impact, snapped to whole pixels (Opus)
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
* [ ] Step 7 Tolerant, per-system saves (S1, before 7d and 7i)
* [ ] Step 8 Hero stats layer (S3, before 7i and 8b)
* [ ] Step 9 Puzzles on the event bus (S7, before 7e)
* [ ] Step 10 Monster behaviours (S4, before 7d)
* [ ] Step 11 Item behaviour hooks (S5, before 7g)
* [ ] Step 12 Levels as data, party survives the stairs (S6, before a second floor or Phase 9)

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

Floor 1 is built and shipped. These phases add new features on top of it, in this order: ambushes, puzzles, banter, legendaries, campfire, levelling, fallen adventurers. Do them after the current queue is clear.

## Phase 7d: Ambushes and jump scares

The dungeon fights back: build-up, silence, then something bursts out of the wall and the party can't run.

Design rules: one or two per floor at most; always leave a clue for observant players; a surprise should hurt, never wipe the party; and players can turn down flashes and shake in Options.

- [ ] 7d.1 Ambush design pass (Opus)
- [ ] 7d.2 Trigger tiles and the scare sequence
- [ ] 7d.3 Wall-grab monsters: giant hand and tentacles
- [ ] 7d.4 Locking the party in
- [ ] 7d.5 Clues, accessibility and tuning
- [ ] 7d.5b Fake-out, then the real scare (double tap)
- [ ] 7d.6 Place ambushes in the floor 1 map

**7d.1 prompt (Ambush design pass, Opus)**

```
Read docs/combat_design.md. I want ambushes where a monster (a giant
cursed hand, tentacles) bursts out of a wall beside the party and forces
a fight. Before any code, extend the design doc with:

- Side attacks: a wall monster on the party's left or right attacks the
  character on that side of the 2x2 formation (front or back row), so
  formation swapping (6.9) matters.
- How the party fights back against a side threat: can everyone hit it,
  or only the characters on that side? Keep it simple.
- A "grabbed" state: what it does (the character can't act, takes
  damage over time) and how it ends (the limb takes enough damage).
- Damage limits so an ambush hurts but can't wipe a healthy party.
- How ambushes interact with save/load (a triggered ambush never fires
  again).
Wait for my OK before coding.
```

**7d.2 prompt (Trigger tiles and scare sequence)**

```
Add ambush trigger tiles to the level data: invisible tiles linked by
ID to an ambush definition (which wall tile, which monster, which side).
When the party steps on one, play the scare sequence:

1. Build-up (about 1.5-2 seconds): the torchlight dims and flickers,
   ambient sound and music fade out, a faint scraping sound plays. An ambush can include a setup exchange
   from the banter system here (e.g. cleric: "I smell evil." fighter:
   "Shut up."); the burst cuts in straight after the last line, so the
   joke lowers the player's guard.
   Player input is ignored during this.
2. Burst: the wall tile breaks apart using the destructible wall cubes
   from 7b, with a loud audio sting, a screen shake and a brief flash.
3. The camera snaps to face the threat with a quick turn, and the wall
   monster's reach-out animation plays.
4. Torchlight returns to normal and tense combat music starts.

Keep every timing, sound and effect in an ambush resource so I can tune
them. Each ambush fires only once and is saved as triggered. Sounds can
be placeholders for now.
```

**7d.3 prompt (Wall-grab monsters)**

```
Add wall monsters following the ambush design: they occupy a wall tile
(no movement), draw as a sprite layered on the wall face, and attack the
side of the party per docs/combat_design.md.

- Giant cursed hand: grabs one character (applies the grabbed state),
  then squeezes for damage over time until the hand is destroyed.
- Tentacles: two or three tentacles from one wall, each with its own
  HP, lashing at random characters on that side.

Art: follow docs/art_style.md (including its prompt suffix), at the
in-game monster size. A huge rotting hand with cracked grey skin, long
blackened nails and green curse veins; dark slick tentacles with pale
suckers and a faint green glow. Animations: reach out of the wall,
idle (twitching), attack or squeeze, hurt, and death (retreating or
crumbling into the wall). Use PixelLab if I have credit; otherwise use
the procedural toolkit as a placeholder with the same file names.
```

**7d.4 prompt (Locking the party in)**

```
Make ambushes force the fight. Support two lock-in types per ambush:
- Grab hold: while any grabbing limb is alive, the party can't move or
  turn away (show "You are held fast!" if they try).
- Trap shut: portcullises (from 3.5) slam down at both ends of the
  corridor, and open again only when every ambush monster is dead.
The ambush definition picks which type to use. When the fight ends,
play a short release sound and restore normal music.
```

**7d.5 prompt (Clues and accessibility)**

```
Add clues and options:
- Clue decorations placed near ambush walls: deep claw scratches, piled
  bones, a faint green glow in the mortar, wet drag marks on the floor.
  Generate them as wall and floor overlays following docs/art_style.md.
- Options menu: a "Reduce flashing and screen shake" toggle that softens
  the burst flash, screen shake and torch flicker in ambushes and
  spells.
- A debug key that triggers the nearest ambush instantly, so I can tune
  it without walking there each time.
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

**7d.6:** add the ambushes to the floor 1 map: one giant hand in a quiet corridor (grab hold), and the double tap: a fake-out a few tiles before a room with portcullises, where the real tentacle ambush traps the party (trap shut). Put clues near the real ambushes, and don't put them back to back.

Done when: a first-time player jumps at the first ambush, and afterwards says "I should have noticed those scratches."

## Phase 7e: Cursed puzzles

Old-school dungeon puzzles dressed in the cursed theme. Rewards are always something in the world (a door, a hidden nook, a relic), never a game-y pop-up or jingle.

- [ ] 7e.1 Puzzle framework (conditions and effects as data)
- [ ] 7e.2 Purge the room: the curse loosens its grip
- [ ] 7e.3 Braziers that push back the curse
- [ ] 7e.4 Paths that only appear in darkness
- [ ] 7e.5 Offering altars
- [ ] 7e.6 Weighted pressure plates
- [ ] 7e.7 Place puzzles in the floor 1 map

**7e.1 prompt (Puzzle framework)**

```
Add a data-driven puzzle system so new puzzles are mostly level data,
not new code. A Puzzle resource has:
- Conditions (all must be true): all monsters in an area dead; N
  braziers lit (or all unlit); specific item(s) on an altar; a pressure
  plate held down; a lever in a given position.
- Effects (run once when solved): open or unseal a door, raise a
  reliquary chest from the floor, reveal a hidden passage, break a wall,
  play a sound or message line.
Puzzles are linked to objects by ID in the level data, like levers and
doors already are. Solved puzzles are saved. Reuse the existing door,
lever, plate and destructible wall systems rather than duplicating them.
Add a debug overlay listing each puzzle's conditions and which are met.
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
Add braziers: a floor or wall object that can be lit by clicking it
with a torch item, or by hitting it with Fireball from range. Each lit
brazier gives off warm light and pushes back the curse around it (the
green glow in nearby walls fades). When all braziers in a group are lit,
their puzzle solves; e.g. four braziers around a warded door open it.
Braziers can be snuffed again by clicking with an empty hand. Generate
the brazier art (unlit, lit with flame frames) following
docs/art_style.md.
```

**7e.4 prompt (Darkness paths)**

```
Add hidden curse runes that only appear in darkness: wall overlays that
are invisible when there's enough light nearby (torches, lit braziers,
spell light), and fade in as a faint green glow when the area is dark.
Use them for a puzzle where the party must snuff the braziers in a room
to see which wall the runes are on; clicking that wall opens a secret
passage. Check light levels from nearby light sources rather than a
simple on/off flag, and make sure the runes are readable but subtle.
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

**7e.7:** add two or three puzzles to the floor 1 map: a purge room with a reliquary, a brazier-warded door (Fireball can solve it early), and either a darkness-rune secret or an offering altar. Spread them out, and don't put one straight after an ambush.

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

- [ ] 7g.1 Legendary item framework (Opus for the design)
- [ ] 7g.2 Grudge, the talking sword
- [ ] 7g.3 The Too Old For This Shield
- [ ] 7g.4 The Gilded Hand
- [ ] 7g.5 Tome of Screams
- [ ] 7g.6 Penitent's Mace
- [ ] 7g.7 The Rat King's Crown
- [ ] 7g.7b The Unquenchable, a legendary torch (after 7l.1)
- [ ] 7g.8 Place legendaries in floor 1

**7g.1 prompt (Legendary framework; Opus for the design, Sonnet to build)**

```
Add legendary items. First, update docs/combat_design.md with how
legendaries work and the balance for each one below; wait for my OK.
Then build the framework:
- A Legendary flag on the Item resource, plus a list of special effects
  (hooks such as on_hit, on_kill, on_cast, on_damage_taken, on_equip,
  periodic) so each legendary is mostly data plus a small effect script.
- Optional downsides, defined the same way, shown in the description.
- A unique worn-gold slot frame and a faint gold shimmer in the
  inventory, distinct from the curse-green of cursed items.
- Examine text (right-click) with the item's name, a one-line dry
  description following docs/tone.md, its powers and its price.
- Banter hooks: legendaries can add lines to the banter system, and the
  first time one is picked up, its finder gets a reaction line.
- Art following docs/art_style.md: battered, ancient, clearly special,
  not shiny.
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
Add the Unquenchable, a legendary torch, using the torch item from 7l.1
and the legendary framework:
- It never burns down, ignores curse zones and rain, and gives a slightly
  bigger, steadier light than a normal torch.
- Downside: it's so bright that monsters notice the party from further
  away, and it's never fully quiet: it crackles, pops and now and then
  mutters. Show the longer detection range in docs/combat_design.md.
- Description (following docs/tone.md), e.g. "It has outlived every
  hand that held it."
- Banter hooks: the cleric is jealous that a stick is holier than him,
  the mage finds it unsettling, and the fighter likes it.
- Like the other legendaries, it still takes a hand.
```

**7g.8:** place two or three legendaries in floor 1, each behind something that feels earned: a puzzle reliquary, a Fireball-only secret, or after the double-tap ambush. Save the rest for later floors and the procedural mode.

Done when: players remember the legendaries by name, and at least one of them causes an argument in the party.

## Phase 7h: Campfire and resting

A place to catch your breath: make camp, heal up, cook, and let the party talk. It's the calm between scares, and the home of the quieter character moments.

- [ ] 7h.1 Resting design pass (Opus)
- [ ] 7h.2 Making camp
- [ ] 7h.3 Cooking at the fire
- [ ] 7h.4 Interrupted rests
- [ ] 7h.5 Campfire banter
- [ ] 7h.6 Camp spots and firewood in floor 1

**7h.1 prompt (Resting design pass, Opus)**

```
Read docs/combat_design.md. Before any code, add resting rules:
- What's needed to make camp: a Firewood item (consumed) plus a
  tinderbox, and no monsters within a few tiles or in sight.
- What resting restores (HP and mana, at what rate) and how long a rest
  takes in game time.
- How it interacts with food (cooked food heals more), the cleric's
  "shaken" state (a rest clears it), poison and sickness.
- The chance of a rest being interrupted by wandering monsters, and how
  that scales (e.g. higher in the open, lower in a cleared room with the
  door shut).
- Keep firewood scarce enough that resting is a decision, not a habit.
Wait for my OK before coding.
```

**7h.2 prompt (Making camp)**

```
Add making camp, following the resting rules in docs/combat_design.md:
- With Firewood and a tinderbox, a Rest button (and R key) makes camp.
  If monsters are nearby, refuse with a message ("Not with that thing
  watching.").
- Camp view: the dungeon view dims to near-black except a crackling
  campfire in the centre, lighting the nearby walls with warm, flickering
  light (the warmest light in the game). The party's portraits glow
  faintly orange.
- Time passes with a slow fade, HP and mana tick up on the bars, and
  the player can stop resting at any time.
- Resting at a camp also saves the game (a natural save point).
- Generate the campfire (flame frames), firewood and tinderbox following
  docs/art_style.md: a small, desperate fire in a cursed place, not a
  cosy one.
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
Add interrupted rests: each stretch of rest rolls against the
interruption chance from the design doc. On an interruption, the fire
flares and sputters, the camp view cuts back to the dungeon, the party
is woken with partial healing so far, and wandering monsters arrive
from a nearby tile. Give it a short, sharp sting, not a full ambush
build-up, and a groggy banter line once the fight is over ("Five more
minutes...").
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

**7h.6:** add one or two safe-ish camp spots to the floor 1 map (cleared rooms with a door to shut), and place firewood sparingly: enough for two or three rests in total.

Done when: making camp feels like a relief, being woken by a monster feels like a betrayal, and the campfire chats are where players get attached to the party.

## Phase 7i: Levelling up

The party grows stronger as they survive. XP is earned for clever play as well as fighting, and levels land at the campfire.

- [ ] 7i.1 Levelling design pass (Opus)
- [ ] 7i.2 Shared XP
- [ ] 7i.3 Level up at the campfire
- [ ] 7i.4 Class perks
- [ ] 7i.5 Banter, character sheet and saving

**7i.1 prompt (Levelling design pass, Opus)**

```
Read docs/combat_design.md. Before any code, add levelling rules:
- Shared party XP from kills, solved puzzles, found secrets, survived
  ambushes and legendary finds, so clever play is rewarded, not just
  fighting. Give amounts per source.
- An XP curve with a level cap of 5 for floor 1 (later floors raise it).
- What each level gives: HP and mana gains per class (using ability
  scores from the character generator if it exists), and a class perk
  at levels 3 and 5.
- Perks, kept small and simple, e.g. fighter: an extra attack chance;
  mage: a new spell; thief: better trap disarming and loot chances;
  cleric: a stronger heal or a new prayer.
- Check the numbers against current monsters, legendaries and ambushes
  so a level-5 party at the end of floor 1 is strong but not bored.
Wait for my OK before coding.
```

**7i.2 prompt (Shared XP)**

```
Add shared party XP following the levelling rules. Award XP for each
source in the design doc, with a short message in the log (e.g. "Secret
found. +50 XP."). Dead characters don't earn XP until revived. Show a
thin XP bar on the character sheet. XP builds up, but levels are only
applied at the campfire (next step); show a small glowing marker on a
portrait when that character has a level waiting.
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
Implement the class perks from the design doc at levels 3 and 5, with
each one shown on the character sheet with a one-line description
following docs/tone.md. Hook them into the existing systems (combat,
spells, trap disarming, loot) rather than adding special cases.
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
Add searchable fallen adventurers, Eye of the Beholder style:
- A remains object that can sit against a wall or in an alcove (from
  the wall structure work), drawn as a sprite. Generate 3-4 variants
  with PixelLab following docs/art_style.md: a skeleton in rusted armour,
  a hooded corpse slumped over a pack, a skeleton still clutching a
  broken sword, one half-buried in rubble.
- Clicking it (or pressing E facing it) searches it once. The level data
  sets the result, or a weighted random table picks it: an item, food,
  a readable note, nothing but a dry message (e.g. "He died as he
  lived: broke."), a trap (reusing the trap system), or rarely a
  skeleton that sits up and attacks.
- Searched remains look disturbed afterwards and are saved, so they
  can't be searched again.
- Readable notes open a small parchment panel with a short text, so
  remains can carry lore later.
- Banter (following docs/tone.md and docs/banter_ideas.md, if the
  banter system exists): the thief loots shamelessly, the cleric mutters
  a reluctant prayer, the fighter takes the boots.
- Add a station for it in the test room.
Generate one remains variant first and show it in-game before the rest.
```

**7j.2:** place 4-6 remains in the floor 1 map: mostly small rewards or jokes, one with a genuinely useful item, one trap, and one that sits up. Put at least one near an ambush, so players learn to be nervous about them.

Done when: players hesitate before searching a body, and search it anyway.

## Phase 7k: Traps and Hold Monster

Ways to stop a monster in its tracks, built on the new slower monster pacing: a held monster gives the party the same breather a step back does. Do 7k.1 first, because it creates the "held" status that 7k.2 reuses.

- [x] 7k.1 Monster status effects and the Hold Monster spell
- [x] 7k.1b Monster tiers (one table for every status effect)
- [ ] 7k.2 Rusty bear trap

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

Done when: you can drop a trap while backing down a corridor, watch a skeleton walk into it, and get two free swings in, and Hold Monster feels like a clever save, not an "I win" button.

## Phase 7l: Light and darkness

Light becomes something you manage. Core rule: a torch or candle takes up a hero's hand, so lighting the way costs a shield, a weapon or a backup, and who carries the light is a real choice. Ties into 7e.3 braziers (lit with a torch), 7e.4 darkness paths (put the torch out to see the runes), 7f.3 banter (darkness and torches going out) and 7d ambush clues (easy to miss in the dark).

- [ ] 7l.1 Torches and candles in hand
- [ ] 7l.2 Wall sconces you can light and take
- [ ] 7l.3 Curse zones that snuff flames
- [ ] 7l.4 Throwing torches
- [ ] 7l.5 Flask of oil
- [ ] 7l.6 Place light and darkness in floor 1

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
Turn the wall torches in the level data into sconces with a lit or unlit
state:
- Unlit sconces are dark. Clicking one with a lit torch or candle in hand
  lights it, and a Fireball hit lights it too. Once lit it stays lit
  (save the state).
- A lit sconce's torch can be taken: click it with an empty hand to pull
  the torch out. You gain a torch with a full burn time, and that stretch
  of corridor goes dark. Put a torch back to relight it.
- Show sconces on the corner map once seen.
- Banter hooks, e.g. thief taking a torch: "They won't miss it."
- Add both kinds to the test room's light station and run the tests.
```

**7l.3 prompt (Curse zones that snuff flames)**

```
Add curse zones: areas in the level data where the cursed air smothers
fire.
- Inside a zone, held torches and candles sputter for a moment, then go
  out ("The air here hates fire."). They can't be relit there, and
  sconces inside won't light.
- Spell light still works, since it's magic, not flame. Bless pushes the
  curse back for a short time: a small pocket around the party where
  flames can be lit again.
- Visual: a thin, slow green miasma layer on the floor and a faint green
  tint, using the existing fog, following docs/art_style.md.
- A zone can be cleared for good by a puzzle effect (so a 7e purge room
  could lift one), stored in the run flags.
- Emit GameEvents.entered_curse_zone and left_curse_zone, add banter hooks,
  add a zone to the test room, and run the tests.
```

**7l.4 prompt (Throwing torches)**

```
Let torches be thrown, reusing the thrown-weapon system:
- A lit torch in hand can be thrown down the corridor in front. It flies
  with its light, lands up to a few tiles away and keeps burning on the
  floor (its burn timer keeps running), lighting the area around it.
- Monsters with fears_fire won't step onto a tile with a burning torch.
  A torch that hits a monster does a little fire damage.
- A torch thrown into a curse zone fizzles out where it lands.
- Picking it up again works like other throwables (auto-return to the
  hand it came from if that's free).
- Banter hooks, e.g. mage, as the torch lights up a skeleton: "Oh. Oh
  no." Run the tests.
```

**7l.5 prompt (Flask of oil)**

```
Add a Flask of oil (ItemDef, stacks to 3), reusing the thrown-item and
fire systems from 7l.1 and 7l.4. Check docs/combat_design.md first and
add the rules there.

- Throw it at the floor: it smashes and leaves an oil slick on that tile.
  Nothing happens until fire touches it: a thrown torch, a torch swing
  on that tile, or a Fireball. Then it bursts into flame and burns for a
  few seconds (tunable), lighting the area.
- Wall of fire: monsters with fears_fire won't cross a burning tile;
  anything else that does takes fire damage each tick.
- Throw it at a monster: it's doused, and the next fire hit on it (torch
  swing, thrown torch, Fireball, burning tile) does big bonus damage.
  Track "doused" as a status effect using the existing status system and
  tier table.
- Oil a weapon: use the flask on a hero's weapon hand to coat it for a
  few hits of extra fire damage, so the fighter can fight with fire
  without giving up his shield.
- Curse zones smother it like any flame: a slick there won't light.
- Burning tiles hurt the party too if they walk in: small damage and a
  dry message, e.g. "{name} has made a terrible decision."
- It combos with the bear trap: a trapped monster on a slick can be lit.
- Emit GameEvents.oil_ignited(cell). Save and load slicks, burning tiles
  and doused monsters.
- Banter hooks (following docs/tone.md), e.g. mage: "Unregulated
  combustion. Wonderful." Thief: "I could sell that." Fighter, after the
  party walks into its own fire: "Again."
- Art following docs/art_style.md: a grimy flask icon and floor version,
  an oil slick decal, and the burst and burning flames from PixelLab's
  VFX tools. Log them in docs/asset_log.md.
- Add it to the test room's light station and run the tests.
```

**7l.6:** place light and darkness in the floor 1 map: a few torches, candles and flasks of oil (scarce enough that light matters), unlit sconces along key corridors, one or two you can take a torch from, and one curse zone, ideally near the darkness-rune puzzle from 7e.4. Check that ambush clues can be spotted with a torch but are easy to miss without one.

Done when: you hesitate before throwing your last torch, argue with yourself about whether the fighter should give up his shield to carry it, and walk into a curse zone and feel the dark close in.

## Phase 8b: Character generator

Before entering the dungeon, you roll up your own party of four, EotB style.

- [ ] 8b.1 Stats design pass (Opus)
- [ ] 8b.2 Party creation screen
- [ ] 8b.3 Race, class and stat rolling
- [ ] 8b.4 Portrait picker and names
- [ ] 8b.5 Starting gear, Quick Party, and hooking it into New Game

**8b.1 prompt (Stats design pass, Opus)**

```
Read docs/combat_design.md. I want an Eye of the Beholder-style character
generator. Before any code, extend the design doc with:

- Six ability scores (Strength, Intelligence, Wisdom, Dexterity,
  Constitution, Charisma), rolled 4d6 drop lowest.
- Races: human, dwarf, elf, halfling, each with small stat modifiers and
  minimum/maximum limits, and which of my four classes (fighter, cleric,
  thief, mage) each race may take.
- Class requirements (e.g. mage needs Intelligence 9+) and each class's
  key stat.
- Exactly how ability scores feed the existing combat stats: HP, attack,
  defence, mana, hit chance, thief disarm chance, and so on. Keep the
  formulas simple and list them in one table.
- Starting gear per class.
Check the numbers against the current monsters so a rolled party is
roughly as strong as the old fixed party. Wait for my OK before coding.
```

**8b.2 prompt (Party creation screen)**

```
Create a Party Creation scene at 640x360 in the same stone UI style as
the HUD. It shows four empty portrait slots in a 2x2 grid matching the
party formation. Clicking an empty slot starts creating a character;
clicking a finished one offers Edit, Delete or Cancel. A Play button
unlocks only when all four slots are filled. Show a screenshot of the
layout before adding the creation steps.
```

**8b.3 prompt (Race, class and stats)**

```
Add the creation steps from docs/combat_design.md, one panel at a time
with Back buttons: choose race, then class (only showing allowed
classes, with greyed-out ones explaining why), then roll stats. The stat
panel shows all six scores with racial modifiers applied, the derived
combat stats (HP, attack, defence, mana) underneath, and a Reroll button
with a quick number-tumble animation. Add a Keep button to accept. If
the rolled stats don't meet the class requirements, say so and allow a
reroll.
```

**8b.4 prompt (Portrait and name)**

```
Add the portrait and name step. Use my tools/art/ procedural portrait
script to show a portrait matched to the chosen race and class, with
left/right arrows to flick through variations and a Randomise button
that rerolls the seed. Store the seed on the character so the same face
can be regenerated anywhere. Then a name field (max 10 characters to fit
under the portrait) with a Random Name button that picks from a small
list of fantasy names per race.
```

**8b.5 prompt (Starting gear and Quick Party)**

```
Finish the generator:
- Give each new character the starting gear from the design doc,
  placed in their hands, armour slot and quick slots.
- Add a Quick Party button that instantly fills all four slots with a
  sensible default party (dwarf fighter, human cleric, halfling thief,
  elf mage) with decent stats, for fast testing.
- Main menu New Game now goes to Party Creation, then into floor 1 with
  the created party in their chosen formation.
- Make sure save/load (7.3) stores the new ability scores, race and
  portrait seed, and that old saves without them fail gracefully.
- Add a line about the character system to CLAUDE.md.
```

Done when: you can roll a party from scratch in under two minutes, and their stats noticeably change how fights go (a weak mage feels weak, a strong fighter hits hard).

Parking lot for later: alignment, multi-classing, importing a party into the next floor.

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

## Ideas inbox

New ideas land here first, instead of going into finished phases. Once the current queue is clear, we sort them into proper steps together.

- (Now covered by the Spell VFX pass) Reactive spell lighting: lights that travel down corridors with a fading light trail, moving shadows, pixel-art normal maps on walls, fog that catches spell light (prompt given in chat on 7 Nov). Also the Fireball VFX recipe: PixelLab flipbooks, synced lights, pixel particles, scorch marks, palette shader.
- Bard class: songs as party buffs and monster debuffs (one song at a time, draining mana while it plays), a chiptune lute for each song, and a bard who narrates the party's failures in verse (e.g. "The Ballad of the Fumbled Sword"). Needs a design pass and a slot in the character generator (8b).
- Game 2: the party meets Bellius the bard, who has already escaped this dungeon. Possible foreshadowing in game 1: traces he left behind (a carved "Bellius was here", a torn song sheet, a snapped lute string, a skeleton audience arranged in rows).
- Story arc, "The Tales of Bellius": torn pages scattered through the dungeon as collectibles, each a short tale in Bellius's own voice. Near the end, the thief reads the last page and discovers they're Bellius's relation, unlocking a single bard song that helps in the final boss fight (the cleric is furious the thief got the gift). Sets up game 2: go find the old man.
- (Built, except fog of war, which is parked: see Leftovers) Minimap makeover: replace the debug minimap with a hand-drawn parchment map in a rusted iron frame, fog of war (only explored tiles drawn), PixelLab icons for the party arrow, doors, stairs, levers, campfires and found secrets (no traps or ambushes), a faint torchlight flicker from the VFX suite, and a full-screen automap on M. Coordinates move behind the debug overlay (prompt given in chat on 9 Nov).
- (Built in Foundations Step 3; check whether the Rename button exists, otherwise 8b.4 covers it) Character names instead of class labels: default names on the party panel (e.g. Brannoc, Brother Felix, Wren, Fennick), the class moved to the tooltip and character sheet, a Rename option with a random-name button, and all messages and banter using {name} (prompt given in chat on 7 Nov).
- Feeli the dungeon cat, as a companion: first met asleep at a campfire spot (stares at the party, then flops over for a belly rub, giving a small morale boost or heal). Later joins the party and sniffs out traps, secret doors and hidden items (stares at the spot, swishes his tail, hisses at trapped doors). He also sees ghosts: invisible spirits only show themselves through Feeli staring at an empty corridor, fur up, growling. Banter: the fighter goes soft ("...who's a good lad."), the cleric pretends not to care but pets him anyway. Synergy: with Feeli in the party alongside Brother Felix (the smug cleric), the party gets a big boon, "The Two Felixes" (e.g. stronger Bless and heals, and Feeli's senses sharpened), plus banter about which Felix is holier.
- Smudge, the friendly ghost: in memory of Bell's cat Smudge (aka Smug, Smugger), 19 years of naughty, rebellious fun. Somewhere in the dungeon, Feeli stares at an empty corner, but instead of growling, his tail goes up and he purrs. She's never seen, only her mischief: "Feeli watches something invisible knock a candle off the shelf.
