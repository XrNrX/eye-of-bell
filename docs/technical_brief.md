# Eye of Bell: technical brief

A compact overview of how the game is built, for sharing with an assistant that can't see the code. The full working notes
are `CLAUDE.md` in the repo; the combat rules live on a separate design page; the writing rules are `docs/tone.md`.

## What it is

A first-person, grid-based, real-time dungeon crawler in the style of Eye of the Beholder (1991). Grim, cursed, very dark
pixel art; the world plays it straight and only the four heroes are funny. One party of four fixed heroes moves as one
tile-sized unit through hand-built levels.

- **Engine:** Godot 4.7 (Forward Plus), GDScript only. Windows development.
- **Art:** Python 3 + Pillow generators (`tools/art/`) plus PixelLab AI pixel art (via MCP), all snapped to a fixed
  32-colour palette (`tools/art/palette.json`). Every animated effect comes from PixelLab's VFX tool.
- **Sound:** procedurally synthesised WAVs (`tools/audio/gen_sounds.py`).
- **Repo layout:** scripts are in one flat folder `scripts/`; data as Godot resources in `data/`; art in `art/`; levels as
  scripts in `levels/` (floor 1 is `scripts/dungeon_map.gd`); tests in `tests/`.

## Display

- Base resolution **640x360**, integer scaling only (1280x720, 1080p, 1440p), `canvas_items` stretch so UI is crisp at the
  window's scale. Starts in borderless fullscreen; Alt+Enter toggles.
- The 3D view is a `SubViewport` (416x260 logical, rendered at k times that) in the top-left, inside a stone and carved-wood
  frame; party panels on the right, message log and movement arrows along the bottom (`scripts/ui_layout.gd`).
- Nearest filtering everywhere, no mipmaps. UI placed on even pixels. Font: Press Start 2P at 8 or 16.

## Core architecture

- **Grid movement** (`player.gd`): one tile or a 90-degree turn per 0.2 s tween; WASD/QE or on-screen arrows. Facing 0 N,
  1 W, 2 S, 3 E.
- **Level data is a script, not a scene.** `dungeon_map.gd` holds the tile grid (0 floor, 1 wall, 2 door, 3 locked door,
  4 stairs, 5 portcullis, 6 cracked wall, 7 corrupted wall) and lists of torches, items, monsters, doors, plates, levers,
  puzzles, plus the run state as static vars (`reset_run()` makes a scene reload a full restart). `dungeon_builder.gd`
  builds every mesh, light and sprite in code. Other levels swap in with `DungeonMap.use_level(path)`.
- **Decoupling:** commands go through node groups (`get_tree().call_group("party", ...)`); news goes through an event bus
  autoload, `GameEvents` (signals only: `monster_killed`, `hero_hurt`, `hero_died`, `monster_held`, `fight_started`...).
  Listeners (banter, later XP and puzzles) connect to the bus; senders never know them.
- **Shared scripts are `preload`ed, not `class_name`** (headless runs fail otherwise).
- **Run flags:** `DungeonMap.set_flag("system.what", value)` for "this happened" memory; saved automatically.
- **Save/load:** one JSON slot (`save_game.gd`); loading reloads `main.tscn`, then applies the file. Saves the party, heroes,
  items, doors, levers, floor piles, monsters (with HP and status effects) and run flags.

## Combat (real time, no turns)

- **Rules:** hit % = 60 + 5 x (attack - defence), clamped 10-95; damage rolled min..max; hero action cooldown =
  max(0.8, 2.0 - 0.15 x speed). All maths in `combat_rules.gd` with a seedable RNG.
- **Party** (`party.gd`): four heroes in positions 0-3 (front row 0-1 melee; back row throws, shoots, casts). Formation
  swapped by dragging portraits. HP changes only through `Party.hurt` and `Party.heal`.
- **Heroes:** Fighter (Brannoc), Cleric (Brother Felix), Thief (Wren), Mage (Fennick). Names are data and renamable.
- **Hands act with what they hold:** melee weapons, throwables (dagger, darts), launchers with ammo (slingshot + stones,
  bow + arrows), a focus item (spellbook, holy symbol) that opens a spell list.
- **Crits and fails:** crit chance from class, dexterity, weapon and finesse, capped 40% (60% against a helpless monster);
  8% of misses are critical fails (stumble or the weapon slips).
- **Hit direction:** monsters hitting from the side or behind reach different heroes, with directional shake, glow and sound.
- **Monsters** (`monster.gd` + `MonsterDef` data in `data/monsters/`): skeleton, skeleton guard, slime, acid slime. They move
  on their own clock (`step_interval` 1.1-1.6 s, the party moves a tile in 0.2 s), wait a beat before following
  (`reaction_delay`), can't strike right after arriving (`arrival_recovery`, then a wind-up), and queue instead of
  surrounding the party (one flanker at a time after `flank_after` seconds). The attack animation's impact frame lands with
  the damage.
- **Status effects:** `StatusDef` resources (`data/statuses/`), carried by monsters (`Monster.add_status`, `try_status`).
  Only "held" exists: no moving or attacking, clocks paused, frozen sprite, crit bonus against it.
- **Monster tiers:** `MonsterDef.tier` (1 fodder to 4 boss) and one table, `data/tiers.tres`, giving each status's chance to
  land and duration per tier (held: 90/65/35/15%, tiers 3-4 half time). Per-monster overrides for flavour (slimes are held
  for less time and "quiver against the runes").
- **Fight tracker:** knows when a fight starts and ends (used for banter timing, later resting and ambushes).

## Spells (data: `data/spells/*.tres`, `SpellDef`)

Mage: Magic Missile (3 mana), Shield (4), Fireball (6, splash, breaks cracked walls), Hold Monster (5, 12 s recast wait).
Cleric: Heal (4), Bless (5, also purifies corrupted walls). Mana regenerates 1 per 2.5 s. A spell that can't take effect
costs nothing. Visuals: PixelLab flipbooks with lights synced to their frames and palette-stepped pixel particles; arcane is
cold pale blue, holy is gold, fire is orange, curse green is never a spell.

## Items and inventory

`ItemDef` resources in `data/items/`. Everything that holds items holds an `ItemStack` (def + count). Eye of the Beholder
click-to-click cursor (no drag and drop): two hands, one armour slot, a 12-slot backpack, two quick slots per hero (keys 1-8).
Potions, scrolls, food (heals over time, mouldy bread can sicken), Scroll of Resurrection, keys, weapons, armour. Floor
tiles hold piles. Thrown weapons remember whose hand they came from.

## World features

Doors, locked doors and keys, portcullises driven by levers and pressure plates, cracked walls (War Hammer or Fireball),
corrupted walls (only Bless burns them away), a small data-driven puzzle system, wall signs, a parchment corner map and a
full-screen map (M), enemy health bars, spell and torch shadows, volumetric fog, normal-mapped walls.

## Writing and banter

`banter.gd` + `data/banter.json`: lines keyed to events (crits, fumbles, deaths, holds, ambush warnings...), with chance,
cooldown, speaker by class, conditions, once-per-run lines and replies. Every line follows `docs/tone.md` (40 characters,
55 at most; no typed hero names, only `{name}` / `{actor}` / `{target}`; no jokes during a scare).

## Debug and tests

- **Test room** (F12 or the main menu, debug builds only): a hall of stations (combat arena, wall types, item table, ambush
  corridor, puzzle room, monster pacing, held monster) and debug keys (H help, G god mode, R refill, Z kill all, V spawn,
  T teleport, I spawn a pack, O/[ ]/Y tune monster pacing live, 9/0 hold and free).
- **Tests** are headless Godot scripts: `tests/smoke_test.gd` (140 checks: combat, spells, holding, food, resurrection,
  events, save/load), `tests/test_room_test.gd`, `tests/banter_test.gd` (also checks every line against the tone rules),
  `tests/popup_layout_test.gd`. Run: `godot --headless --path . -s tests/smoke_test.gd` (exit code = failures).

## Not built yet

Ambush system (only a test-room stand-in; a boss-room ambush is parked in a git stash), a mini-boss and bosses (tiers 3-4
are empty), the rat, the bear trap and other traps, slowed/poisoned statuses (the data fields exist), XP and levelling,
resting and campfires, fog of war (stashed), legendary items with personalities (Grudge the talking sword), Feeli the
dungeon cat, Bellius the bard's pages, more floors.
