# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A first-person, grid-based dungeon crawler in the style of Eye of the Beholder, in Godot 4.7 (Forward Plus, GDScript). Python (Pillow) generates all pixel art. Development is on Windows; use Git Bash or PowerShell.

## Design references

**Combat design blueprint:** https://claude.ai/artifact/BGAw8C4bkJfdBrSScE49yY

This page is the source of truth for combat rules. It covers stats, hit chance and damage formulas, cooldowns, party slots and melee, monster targeting, data structures, the script list, starting numbers, and the agreed decisions (swinging at air uses the cooldown; the back row steps up; adjacent monsters stop moving).
- Read it before any combat work, using the Artifact tool with `action: "read"` and that URL. Don't use WebFetch or curl; the page is private.
- Follow it rather than re-deriving or inventing rules.
- If the user changes a rule, update the code and the page together: republish to that same URL so the link stays stable. Then fix the summary under **Combat** below.

## Commands

Godot lives outside the repo; the install folder itself is named `.exe`:
`C:\Users\bucki\Desktop\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe`

```bash
G="C:/Users/bucki/Desktop/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64.exe"
"$G" --path .                      # run the game (main scene: scenes/main.tscn)
"$G" --headless --path . --import  # (re)import assets; run after adding/changing PNGs
"$G" --headless --path . -s some_test.gd   # run a SceneTree script (see Testing)
```

The Godot MCP (`run_project`, `get_debug_output`, `stop_project`) also works; an empty `errors` list means no parse or runtime errors.

Art (Python 3 + Pillow, run from the repo root):

```bash
python tools/art/build_all.py                 # regenerate ALL art, then patch .import files
python tools/art/build_all.py --only tiles    # one generator: tiles, sprites, skeleton, slime, swatch
python tools/art/test_toolkit.py              # self-test of the art helpers
python tools/art/gen_skeleton.py --seed 7 --bone ash --weapon axe --helmet --name skeleton_guard
python tools/art/gen_slime.py --seed 5 --colour acid --contents skull --name slime_acid
```

There is no linter and no committed game test suite.

## Testing

Nothing is checked in for the game itself. The working approach has been throwaway headless scripts that `extends SceneTree`, instantiate `res://scenes/main.tscn`, teleport the player (`p.cell = ...; p.position = ...; p._report_position()`), call `p._try_move(...)` / `p._interact()` / `monster._on_tick()` directly, `await create_timer(...)`, and print PASS/FAIL. Gotchas:
- A SceneTree script must call `quit()` on every path; a runtime error before it leaves Godot running forever. Wrap the run in `timeout 120`.
- Godot auto-names code-created nodes (`@Timer@2`), so find them by type, not `get_node("Timer")`.
- Input is polled (`Input.is_physical_key_pressed`), so tests call methods instead of simulating keys.

## Architecture

**Level data is a script, not a scene.** `scripts/dungeon_map.gd` holds `MAP` (0 floor, 1 wall, 2 door, 3 locked door, 4 stairs), start tile, and lists for `TORCHES`, `KEYS`, `MONSTERS`, `DOOR_IDS`, `PLATES`, `LEVERS`. It also holds *run state* as `static var`s (open doors, keys held, occupied tiles, `player_cell`). `reset_run()` is called from `dungeon_builder.gd::_ready`, which is what makes `reload_current_scene()` a full restart. Edit levels there; everything else reads from it.

**`DungeonMap` is `preload`ed, not a `class_name`.** Each script does `const DungeonMap := preload("res://scripts/dungeon_map.gd")`. A `class_name` isn't registered until the editor scans, so headless runs and fresh files fail with "Identifier not declared". Follow this for new shared scripts (`MonsterDef` is likewise referenced untyped).

**Scene tree** (`scenes/main.tscn`): `Dungeon` (builder; creates all meshes/sprites/lights in code), `Player` (with `Camera3D` and a torch light), plus self-contained overlays `DebugOverlay` (Tab), `Hud`, `LevelComplete`.

**Decoupling is by node groups.** The player never holds references to the world; it calls `get_tree().call_group(...)`:
- `"dungeon"` (builder): `open_door`, `pull_lever`, `remove_key`, `refresh`
- `"hud"`: `show_message`
- `"level_complete"` / `"game_over"`: `show_screen`
- `"party"`: `attack(slot)`, `take_hit_from(monster)`

So the overlay, HUD and level-complete scenes can be deleted from `main.tscn` without breaking anything. Keep new UI the same way.

**Grid movement** (`player.gd`): input is polled in `_process`; a step or turn is a 0.2 s tween and input is ignored while it runs. Logical position (`cell`, `facing`) changes at the *start* of a move, and `_report_position()` publishes it via `DungeonMap.player_cell` plus a `refresh` call. F is edge-triggered (a held key must not repeat a lever pull). Facing indices: 0 N, 1 W, 2 S, 3 E (increasing = turning left).

**Doors, plates, levers** (all in `dungeon_builder.gd`): `_drive_door(cell, open)` is the single path that opens or closes any door. A door is only walkable once its slide finishes (`DungeonMap.open_doors`), closing blocks immediately, and a door never closes while the player or a monster stands in it. Doors with an ID in `DOOR_IDS` ignore F and are driven only by their plates/levers via `refresh()`; a door is open if *any* of its switches is active.

**Monsters** (`monster.gd` + `MonsterDef` resource in `data/monsters/*.tres`): new monsters are data plus a line in `MONSTERS`. A monster claims its destination tile in `DungeonMap.occupied` when a step starts and frees the old one when it ends. AI is a staggered timer: chase if within sight range (grid distance) with `has_line_of_sight`, else wander; orthogonal moves only. Next to the party a monster stops moving and attacks on its own `attack_interval` timer.

**Combat** (rules come from the blueprint under *Design references*; this is only a summary). Real time, no turns. `combat_rules.gd` holds all the maths (hit % = 60 + 5 × (attack − defence), clamped 10–95; damage rolled from damage_min to damage_max; hero cooldown = max(0.8, 2.0 − 0.15 × speed)) and a seedable RNG (`CombatRules.seed_rng(n)` in tests). `CharacterDef` and `MonsterDef` share the stat fields, so `resolve_attack` works either way. The `Party` node (group `"party"`, heroes in slots 0–3, front row = 0–1) owns hero HP and cooldowns. `attack(slot)` hits the monster in `DungeonMap.occupied` in front of the player; `take_hit_from(monster)` picks a target by which side the monster is on. The party HUD reacts only to `Party` signals. Level complete and Game over share `end_screen.gd`, configured by `group_name`.

**Rendering.** `project.godot` renders at 320x200 with `viewport` stretch. All pixel art must use nearest filtering and no mipmaps: materials set `TEXTURE_FILTER_NEAREST`, and each PNG's `.import` needs `mipmaps/generate=false`, `detect_3d/compress_to=0`, `compress/mode=0`. Godot rewrites `.import` defaults for new PNGs, so after importing run `build_all.py` (it patches them). The editor also rewrites `project.godot` and may strip comments.

## Art pipeline (`tools/art/`)

- `palette.json` is the 24-colour palette. Every generated image must use only those colours; `artio.save_png()` raises on any off-palette pixel. Use `PAL`/ramps from `palette.py`, not literal RGB.
- Helpers are flat modules (`from noise import ...`, no package): `noise` (seeded, tileable), `dither`, `outline`, `lighting` (light from the top-left), `artio` (`save_png`; `save_frames` for animation sets: frame PNGs + sheet + JSON; `patch_imports`).
- `build_all.py` runs every `gen_*.py` that defines `build()` returning the written paths. To add art, drop in a new `gen_<name>.py`.
- `art/` PNGs are **generated outputs**: edit the generators, or the next `build_all.py` overwrites your change. To use hand-made or PixelLab art instead, keep the same filenames and stop that generator from overwriting it.
- Frame/file names are the contract with the game (e.g. `art/monsters/skeleton/skeleton_sheet.png`, 7 frames of 48x64, referenced by `data/monsters/skeleton.tres`).
- `tools/.gdignore` keeps Godot from importing anything under `tools/`.

## Environment notes

- A PixelLab MCP server is configured (local scope) but the trial generations are used up; art has been generated procedurally instead.
- `node_2d.tscn` at the repo root predates the game code and isn't used.
- Git prints CRLF-to-LF warnings on Windows; they are harmless (`.gitattributes` handles it).
- Run Python with `-B` or ignore `__pycache__`; it is gitignored.
