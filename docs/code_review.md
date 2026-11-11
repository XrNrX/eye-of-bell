# Code review: is Eye of Bell ready for the expansion?

Date: 2026-11-11, at commit `55a9af9`. A read-and-report pass: no code was changed and nothing was run.

**How far this review goes.** Read in full or nearly so: `party.gd` (structure, combat, casting, hits), `save_game.gd`,
`save_manager.gd`, `dungeon_map.gd`, `monster.gd`, `banter.gd`, `puzzles.gd`, the four definition resources, the dungeon
build and switch code in `dungeon_builder.gd`, movement in `player.gd`, the hit pause in `combat_feel.gd`, and every
timer and `await` in `scripts/`. Skimmed by search only: `party_hud.gd`, `spell_effects.gd`, the inventory scripts, audio,
menus, map. A finding marked "(not verified in play)" comes from reading alone.

## Verdict

**The foundations are good and floor 1's code can carry the expansion, but not as it stands.** Items, monsters, spells
and the level are already data; systems talk through groups, not hard references; there is one path for most things
(one place a monster dies, one place a hero dies, one function that drives a door).

Four things must be fixed before 7f, because banter is the first system that needs them and every later phase leans
on the same four:

1. **There is no way to announce "something happened".** Each new listener would mean another edit to `party.gd`.
2. **A hero's class, name and banter key are one string** (`CharacterDef.display_name`, "Cleric"). `{name}` cannot work,
   and the character generator would break banter, item restrictions and saves at once.
3. **The banter engine cannot do what the tone guide asks**: no placeholders, no once-only lines, no reply pairs, no
   silence during a fight.
4. **There is no safety net.** Two committed tests cover pop-ups and the test room. The refactors below touch combat
   and saving, so a small smoke test comes first.

Nothing found is a crash waiting to happen in normal play. The risks are listed at the end.

## Answers to the seven questions

1. **Events.** Partly. Commands go through `get_tree().call_group(...)` (28 kinds of call) and `Party` has 15 signals,
   but those are HUD feedback (`hp_changed`, `hero_hit`, `buff_cast`), not game events. There is no "monster killed",
   "hero died", "item picked up", "puzzle solved" or "fight ended". Banter is called directly from three places in
   `party.gd`. See M1 for the shape to build.
2. **Data or code.** Data: `ItemDef`, `MonsterDef`, `SpellDef`, `CharacterDef` are resources in `data/`, and levels are
   const scripts. What will hurt: item behaviour is a flat list of fields each with its own branch in `party.gd` (S5),
   hero stats are read straight off the shared `CharacterDef` (S3), every monster has the same brain (S4), and spell
   visuals are chosen by string in code (N3).
3. **Save/load.** Not saved: which level you are on, cooldowns, the fight state (`behind_warned`, `fight_left`), banter
   cooldowns and what has been said, ambush triggers, monster facing and animation, the random dice, play time. XP,
   levels and banter memory have nowhere to go, and the loader will clamp a levelled hero's HP back to the class
   base. See M5 and S1.
4. **Class and name.** No `if class == "cleric"` in the logic: the Cleric's special cases key on `magic == DIVINE`,
   which is right. But the class string is the identity everywhere else: 62 uses of `def.display_name` in `party.gd`,
   banter's `speaker`/`actor`, `ItemDef.cant_use`, the character sheet title. See M2.
5. **Map.** Better than expected: the level is fifteen fields that `DungeonMap.use_level` swaps, and the builder
   reads only those. What blocks a procedural mode: a level can only come from a script file, floor 1 lives inside
   `dungeon_map.gd` itself, saves assume floor 1, the party does not survive a change of level, and the main menu
   has a hard-coded camera cell. See S6.
6. **Coupling.** One autoload (`DisplayManager`), which is fine. Two god-scripts: `party.gd` (1,478 lines: combat,
   casting, inventory moves, equipping, food, resurrection, every log string) and `party_hud.gd` (1,286).
   `save_game.gd` reaches into the internals of the party, dungeon, cursor and `DungeonMap`. See S1 and N1.
7. **Bugs and risks.** Nothing serious found. See "Bugs and risks".

## MUST FIX before 7f (banter)

### M0. No regression tests for combat or saving
- **Where:** `tests/` (only `popup_layout_test.gd`, `test_room_test.gd`).
- **What's wrong:** every fix below edits `party.gd` or `save_game.gd`, and the working habit has been throwaway scripts.
- **Why it matters:** a refactor by a smaller model with no test is how a shipped floor breaks quietly.
- **Fix:** one committed headless `tests/smoke_test.gd`: kill a monster, take a hit, cast each spell, eat, revive, save and
  load and compare the party and dungeon state before and after.

### M1. No event bus
- **Where:** `party.gd` (`_banter` line 1373; calls at 1210, 1227), `monster.gd` (`_die` line 304), `dungeon_builder.gd`
  (`pull_lever`, `break_wall`, `_purify`), `player.gd` (`_click_item`, `_arrive`).
- **What's wrong:** systems are told what happened by direct group calls written at each site. Banter knows about 8
  events because `party.gd` calls it 3 times. Nothing announces a kill, a death, a pick-up, a solved puzzle or the end
  of a fight.
- **Why it matters:** 7f banter, 7i XP, 7e puzzles and 7g legendary hooks all listen for the same events. Without a
  bus each one adds calls inside `party.gd` and `monster.gd`.
- **Fix:** an autoload `GameEvents` (a node of signals only, no logic), emitted at the existing single points. Start
  with: `monster_killed(def, cell, killer_hero)`, `hero_died(hero)`, `hero_revived(hero, by_scroll)`,
  `hero_hurt(hero, amount, source)`, `mana_low(hero)`, `item_picked_up(def, hero)`, `door_unlocked(cell)`,
  `lever_pulled(cell, on)`, `wall_broken(cell)`, `wall_purified(cell)`, `puzzle_solved(id)`, `fight_started()`,
  `fight_ended()`, `level_completed()`. Listeners connect in `_ready`; Godot drops the connection when a listener is
  freed, so a scene reload is safe. Keep `call_group` for commands ("do this"); the bus is for news ("this happened").
  In a `-s` test an autoload only exists after one `process_frame` (already noted in `CLAUDE.md`).

### M2. A hero's class, name and key are the same string
- **Where:** `character_def.gd` (`display_name`); `party.gd` (62 uses, e.g. every `_say("%s ..." % m.def.display_name)`);
  `banter.gd` `_fits` and `_living` (speakers matched by `display_name`); `item_def.gd` `cant_use` (class names);
  `party.gd` line 824 ("The %s can't wear that."); `character_sheet.gd` line 129.
- **What's wrong:** "Cleric" is at once the class, the name shown in the log, the banter speaker key and the key for
  item restrictions.
- **Why it matters:** 7f needs `{name}` and `{target}` (the tone guide forbids typed names); 8b renames heroes and adds
  classes. The day a hero is called "Felix", banter stops finding its speaker and the Mage can wear armour.
- **Fix:** give `CharacterDef` a `class_id` ("cleric") and a `hero_name` (default "Brother Felix"); keep
  `display_name` as the class label. Add `Member.name()` and use it in every log string. Banter's `speaker`, `actor`
  and `cant_use` match `class_id`. Do this before writing any new banter.

### M3. The banter engine is too small for the tone guide
- **Where:** `banter.gd` (98 lines), `data/banter.json`.
- **What's wrong:** (a) no `{name}` / `{target}` substitution, and the log prefix is the class; (b) the context is only
  `actor` and `weapon`, so a line cannot be about a second hero; (c) no once-per-run lines ("first death of the game");
  (d) no exchanges: a reply pair needs two lines in order with a short gap, and `always` only says two lines at once;
  (e) no rule for silence, so a crit bark fires in the middle of an ambush; (f) the cooldown is per event only, so two
  events in one second print two lines; (g) cooldowns use the real clock (`Time.get_ticks_msec`), which keeps running
  while the game is paused.
- **Why it matters:** 7f is this system. The tone guide's timing table (set up a scare, never interrupt one) cannot be
  followed without (d) and (e).
- **Fix:** listen to `GameEvents`; context carries `actor`, `target` and free fields; add per-line `once`, a `reply`
  list said after a delay, a global minimum gap between lines, a `quiet` switch other systems set (ambush), and count
  cooldowns in game time. Keep the JSON format and add fields to it.

### M4. Nothing knows when a fight starts or ends
- **Where:** `party.gd` lines 111-113 and 147-151 (`fight_left`, set only when a monster attacks the party).
- **What's wrong:** "in a fight" exists only as a private timer used for one message. A fight the party starts (a
  thrown dagger, a Fireball) is not a fight until something hits back.
- **Why it matters:** banter timing (bark, silence, react afterwards), "can't rest, monsters nearby" in 7h, and locking
  the party in during 7d all need the same fact.
- **Fix:** move it to a small fight tracker (in `Party` or its own node): a fight starts when a monster notices or is
  struck, ends some seconds after the last blow or when no monster is in sight; emit `fight_started` / `fight_ended`.

### M5. Banter memory and any new run state have nowhere to be saved
- **Where:** `save_game.gd` (`serialize` line 96, `apply` line 190).
- **What's wrong:** the save is one hand-written dictionary. There is no general place for "things that have happened"
  (lines already said, ambushes sprung, secrets found).
- **Why it matters:** a once-only banter line would be said again after every load.
- **Fix:** add one saved dictionary of run flags (`DungeonMap.flags` or a `RunState`), read with `.get` so older saves
  load. Banter's once-only lines and, later, ambushes and puzzles store their memory there. The fuller save rework is S1.

## SHOULD FIX before the phase that needs it

### S1. Save format: brittle to read, hard to extend (before 7i; partly before 7d)
- **Where:** `save_game.gd`.
- **What's wrong:**
  - `read_file` checks only that the file is a dictionary with `version == 1`. `apply` then reads `data.party.heroes`,
    `d.unlocked_doors`, `d.levers`, `d.items`, `d.monsters`, `h.hands`, `h.buffs` with no default. A damaged or
    hand-edited file stops with a script error part-way through, leaving a half-loaded game. (The header says a bad
    file is rejected before anything changes; that is true only for the formation.)
  - The version test is equality. The first time `VERSION` is raised, every existing save is refused.
  - `m.hp = clampi(int(h.hp), 0, m.def.max_hp)` (line 217) and the same for mana: a levelled hero loads at the class base.
  - Heroes are matched by `hero_index` into the four fixed defs. The level is not stored; `load_game` always calls
    `use_level("")`.
  - `save_game.gd` knows the private fields of `Party.Member`, `dungeon.items`, `dungeon.lever_on` and nine
    `DungeonMap` dictionaries, so every new system means editing it.
- **Why it matters:** 7i adds XP, levels and perks; 7d adds sprung ambushes and locked doors; 7e adds puzzle memory; 8b
  makes heroes player-made, so the save must hold the heroes themselves; 9 needs the level's seed.
- **Fix:** each system gets `save_state() -> Dictionary` and `load_state(d)`, and `SaveGame` only gathers and hands
  them back. Validate the whole file before touching the game. Accept older versions and fill defaults. Store the
  level id. Load max HP and mana from the hero's own stats (S3), not the class.

### S2. Hero damage and healing are written out in seven places (before 7d)
- **Where:** `party.gd` lines 186, 198, 657, 1107, 1149, 1394 (and `save_game.gd` 217).
- **What's wrong:** only `take_hit_from` can kill a hero, and it does the death work inline (clear buffs, sound,
  signals, wipe check). Heals each clamp to `m.def.max_hp` by hand.
- **Why it matters:** 7d wall-grab monsters, traps, 7h interrupted rests and 7g cursed items all hurt or heal heroes
  from new places. Each would need to copy the death and wipe handling, and one will forget.
- **Fix:** `Party.hurt(m, amount, source)` and `Party.heal(m, amount, source)` as the only places `hp` changes; they
  emit `hero_hurt`, `hero_died`, `wiped`.

### S3. Hero stats live on the shared class resource (before 7i; needed again for 8b)
- **Where:** `party.gd` (23 direct reads of `m.def.max_hp`, `.max_mana`, `.speed`, `.attack` ...), `party_hud.gd` (7),
  `character_sheet.gd` (7), `inventory_screen.gd`, `save_game.gd`, `test_room_tools.gd`.
- **What's wrong:** `effective_stats()` already layers gear and buffs for attack, defence and damage, but max HP, max
  mana, speed and crit values are read straight from `CharacterDef`, which is shared and must never be changed.
- **Why it matters:** a level-up, a perk or a rolled stat has nowhere to live.
- **Fix:** per-hero base stats on `Member` (copied from the class at creation, raised by levels), and one
  `Party.stats(m)` that returns everything (max HP, max mana, speed, crit, attack, defence, damage). Replace the direct
  reads. Do it as its own step with no behaviour change.

### S4. Every monster has the same brain (before 7d)
- **Where:** `monster.gd` (`_on_tick`, `_process`, `_next_to_player`, `_attack`).
- **What's wrong:** chase, wander and "attack when adjacent" are the only behaviour. `MonsterDef.boss` and
  `wall_monster` exist but only change the health bar.
- **Why it matters:** a wall-grab monster does not walk, does not occupy a floor tile, holds the party in place and
  may attack from inside a wall. Bolting that onto `monster.gd` with flags will tangle the walker.
- **Fix:** keep `monster.gd` as the walker and add a `behaviour` field on `MonsterDef` naming a small script for the
  different kinds (`walker`, `wall_grabber`). Share `take_hit`, death and drops.

### S5. Item behaviour is a list of fields and branches (before 7g)
- **Where:** `item_def.gd` (heal, scroll, food, resurrection, ammo, `breaks_walls`, `never_slips`, `finesse` ...) and the
  matching branches in `party.gd` (`use_item`, `action_for`, `_swing_at_wall`, `_critical_fail`).
- **What's wrong:** each new behaviour so far added exported fields plus an `if` in `party.gd`. `never_slips` was added
  ahead of time for one sword.
- **Why it matters:** legendaries are all special cases (a sword that talks and sulks, a dagger that steals, a mace
  that apologises). Ten of them this way adds ten flags to every item and ten branches to the largest script.
- **Fix:** an optional `behaviour` script on `ItemDef` with a few hooks (`on_equip`, `on_hit`, `on_kill`, `on_tick`,
  `on_stowed`) that `Party` calls, plus the event bus for banter. Ordinary items keep the fields they have.

### S6. Levels come only from script files, and the party dies with the scene (before 9; partly before any second floor)
- **Where:** `dungeon_map.gd` (`use_level`, `_field` / `_set_field`, floor 1's data in the same file), `party.gd` `_ready`,
  `player.gd` `_arrive`, `main_menu.gd` `VIEW_CELL`, `save_game.gd` line 80.
- **What's wrong:** `use_level(path)` reads consts from a script, so a generated level cannot be handed over as data.
  Floor 1 is the default inside `dungeon_map.gd` and is restored with `use_level("")`. The party is rebuilt from
  `hero_defs` whenever `main.tscn` loads, so walking down the stairs cannot carry HP, items or levels to another
  floor. The stairs only show "Level complete".
- **Why it matters:** blocks 9, and blocks a hand-made floor 2 just the same.
- **Fix:** `DungeonMap.use_level_data(dict)` with `use_level(path)` as a thin wrapper; move floor 1 to
  `levels/floor_1.gd`; a `RunState` that holds the party between floors (the same `save_state` / `load_state` from S1
  does the carrying); a level id or seed in the save. The builder and the rest already read only the fifteen fields,
  so nothing else needs to change.

### S7. Puzzles are checked from two hand-picked places (before 7e)
- **Where:** `puzzles.gd`, `dungeon_builder.gd` (`pull_lever`, `_purify`).
- **What's wrong:** `Puzzles.check` runs only after a lever pull or a purified wall. A new condition kind (plate
  pressed, item placed, monster killed, door opened) needs a new call site each time. Conditions are read from the
  live world, so one with memory ("levers pulled in order") has nowhere to keep it.
- **Why it matters:** 7e is a framework of conditions and effects.
- **Fix:** `Puzzles` listens to the event bus and re-checks on any event; conditions with memory use the run flags
  from M5. The data shape (`when` / `then`) is already right.

## NICE TO HAVE

- **N1. Split `party.gd` along its seams** when S2 and S3 are done: inventory and equipping moves (lines 700-1070)
  into their own script, log strings into one place. Not urgent; do not do it as one big change.
- **N2. `party_hud.gd` (1,286 lines)** mixes panels, formation drag, spell targeting and effect overlays. Split only
  when 7i adds XP bars and level-up feedback to it.
- **N3. Spell visuals are chosen by string in code**: `party.gd` `_fx` and `cast` (`effect in ["heal", "bless",
  "shield"]`), `spell_effects.gd` `HOLY_SHEETS`. A new perk spell needs code. Move the "plays over portraits" choice to
  a field on `SpellDef`.
- **N4. `dungeon_map.gd` `_field` / `_set_field`** are two 15-branch `match` blocks; a new level field means editing
  three places. A dictionary of level data (S6) removes them.
- **N5. Log strings are built inline** with `%s` in about 60 places. When `Member.name()` exists (M2) they are correct;
  a later pass could move them to a table so the tone guide can be applied in one file.

## Bugs and risks

None of these was seen failing; they come from reading.

- **R1. A damaged save can half-load** (see S1). Real, but needs a broken file. Low chance, bad result.
- **R2. The game can be left in slow motion.** `combat_feel.gd` `hit_pause` sets `Engine.time_scale` and restores it
  after an `await`. If the scene is replaced during that fraction of a second, the node is freed and the restore
  never runs. A new `main.tscn` resets it in `_ready` (line 48), but the main menu does not. The window is about a
  tenth of a second, so it is unlikely (not verified in play). Fix: reset it in `CombatFeel._exit_tree` and in the menu.
- **R3. Effect clean-up timers run while the game is paused.** `get_tree().create_timer(...)` keeps counting during a
  pause (about ten sites in `spell_effects.gd` and `party_hud.gd`) while particles and tweens stop. Open the inventory
  mid-spell and the clean-up fires early: cosmetic only (not verified in play).
- **R4. Banter cooldowns use the real clock**, so a long pause clears them (M3g). Cosmetic.
- **R5. Freed nodes and signals: no problem found.** Timer lambdas guard with `is_instance_valid` or `is_inside_tree`, or
  belong to a node whose freeing drops the connection. `DungeonMap.occupied` holds monster nodes, is cleared in
  `reset_run`, monsters release their tiles in `_exit_tree`, and `_melee` checks validity before use.
- **R6. Two stale checks are already listed in `docs/known_issues.md`** (key pick-up test assumption; the held item not
  following the mouse while paused, unconfirmed). Still open.
- **R7. Saving is allowed in the middle of a fight** and the fight state is not saved, so a load drops the party next
  to a monster with every cooldown ready. Fine today; it becomes a real hole in 7d (save inside a sprung ambush, load,
  and the lock-in is gone) unless ambush state is saved or saving is refused during one.

## Suggested order: small, separate steps

Each is one prompt for Sonnet. Do them in order; commit after each. "Run the tests" means
`tests/smoke_test.gd`, `tests/test_room_test.gd` and `tests/popup_layout_test.gd`.

**Step 0. Smoke test (M0).**
Prompt: "Add `tests/smoke_test.gd`, a headless SceneTree test of floor 1, following the Testing section of CLAUDE.md.
Seed the combat dice. Check: a hero kills a monster in front; a monster's hit lowers a hero's HP; Magic Missile,
Fireball, Heal, Bless and Shield each take effect and spend mana; eating heals over time; a Scroll of Resurrection
raises a dead hero; saving then loading gives back the same party (hp, mana, items, formation), player cell, open
doors, levers, floor piles and monsters. Print PASS or FAIL per check. Change no game code."
In-game check: none needed; the test passing is the check.

**Step 1. Event bus, emit only (M1).**
Prompt: "Add an autoload `GameEvents` (`scripts/game_events.gd`): signals only, as listed in `docs/code_review.md` M1.
Emit each from the one place the thing happens (monster death in `monster._die`, hero death in
`party.take_hit_from`, revive in `party.revive`, key use, lever, wall broken, wall purified, puzzle fired, stairs).
Do not change any listener or behaviour. Add a check to the smoke test that each signal fires once."
In-game check: play floor 1 for five minutes; kill something, pull a lever, break the cracked wall. Everything
behaves exactly as before.

**Step 2. One path for hero damage and healing (S2).**
Prompt: "In `party.gd` add `hurt(m, amount, source)` and `heal(m, amount, source)` and make them the only places a
hero's `hp` changes (see S2 for the seven sites). Death handling moves into `hurt`. Emit `GameEvents.hero_hurt`,
`hero_died`. No behaviour change. Run the tests."
In-game check: take hits until a hero dies, eat, drink a potion, cast Heal, revive with a scroll. HP bars, sounds,
portraits and Game over behave as before.

**Step 3. Class id and hero name (M2).**
Prompt: "Give `CharacterDef` a `class_id` and a `hero_name`; set them in the four `data/party/*.tres` (cleric / Brother
Felix, fighter / Brannoc, thief / Wren, mage / Fennick). Add `Member.name()`. Use it for every name shown to the
player in `party.gd`, the party HUD, inventory and character sheet (the sheet still shows the class as a subtitle).
Banter speakers, `actor` conditions and `ItemDef.cant_use` match `class_id`. Update `banter.json` and the item files.
Run the tests."
In-game check: the panels and the log say Brannoc, Brother Felix, Wren, Fennick. The Mage still cannot wear the
leather armour. A crit or a fumble still gets a banter line.

**Step 4. Fight tracker (M4).**
Prompt: "Add a fight tracker as described in M4 and emit `GameEvents.fight_started` and `fight_ended`. Replace
`fight_left` / `behind_warned` in `party.gd` with it. Show the state in the test room's H overlay. Run the tests."
In-game check: in the test room arena, the overlay says a fight starts when you throw a dart at a monster and ends a
few seconds after the last one dies. 'Something's behind you!' still shows once a fight.

**Step 5. Run flags in the save (M5).**
Prompt: "Add a saved dictionary of run flags (`DungeonMap.flags`, cleared by `reset_run`, written and read by
`save_game.gd` with a default for older saves). Add a smoke-test check that a flag survives save and load."
In-game check: save, load; nothing looks different. An old save from before this step still loads.

**Step 6. Banter engine (M3). Read `docs/tone.md` first.**
Prompt: "Extend `banter.gd` as listed in M3: listen to `GameEvents`, `{name}` and `{target}` substitution, per-line
`once` (stored in the run flags), `reply` lines after a delay, a global minimum gap, a `quiet` switch, cooldowns in
game time. Keep existing lines working. Add tests for each. Write no new lines yet."
In-game check: existing banter still appears with the hero's name in front. Then add the lines for 7f as their own step.

**Step 7. Tolerant, per-system saves (S1). Before 7d and 7i.**
Prompt: "Give `Party`, the dungeon builder, `Player` and the cursor `save_state()` / `load_state()`, and make
`save_game.gd` gather them. Validate the whole file before changing the game; refuse a bad file with a message and
change nothing. Accept version 1 saves. Store the level path. Add smoke-test checks: a truncated file and a file with
a missing key are refused cleanly."
In-game check: an old save loads. Save in the middle of floor 1 with doors open and a lever pulled, quit to the menu,
Continue: everything is where it was.

**Step 8. Hero stats layer (S3). Before 7i.**
Prompt: "Give `Member` its own base stats copied from the class, and a single `Party.stats(m)` for every number
(S3). Replace all direct reads of `m.def.<stat>` outside it. Save and load the base stats. No behaviour change."
In-game check: the character sheet shows the same numbers as before for all four heroes, with and without a weapon
and armour. In the test room, G / R still refill to the same HP and mana.

**Step 9. Puzzles on the bus (S7). Before 7e.**
**Step 10. Monster behaviours (S4). Before 7d.**
**Step 11. Item behaviour hooks (S5). Before 7g.**
**Step 12. Levels as data and a party that survives the stairs (S6). Before a second floor or 9.**
Write these four prompts when their phase comes, from the matching finding above; each has the same shape (one
finding, no behaviour change, run the tests). In-game checks: 9, purify the thick wall at (16,4) and `gate_n` still
opens, before and after a save and load; 10, all four monsters still chase, telegraph, attack and die as before; 11,
the war hammer still breaks the cracked wall and a potion, scroll, bread and slingshot still work; 12, F12 into the
test room and back, New Game, and Continue all still start in the right place.
