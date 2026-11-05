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
python tools/art/build_all.py --only tiles    # one generator: tiles, sprites, items, skeleton, slime, swatch
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

**Scene tree** (`scenes/main.tscn`): `Dungeon` (builder; creates all meshes/sprites/lights in code), `Player` (with `Camera3D` and a torch light), `Party`, plus self-contained overlays `DebugOverlay` (Tab), `Hud`, `PartyHud`, `LevelComplete`, `GameOver`.

**Other top-level scenes:** `scenes/main_menu.tscn` (a minimal title + New Game button) is reached via `get_tree().change_scene_to_file()` from Game over's "Quit to Menu" button, not as a child of `main.tscn`.

**Decoupling is by node groups.** The player never holds references to the world; it calls `get_tree().call_group(...)`:
- `"dungeon"` (builder): `open_door`, `pull_lever`, `refresh` via `call_group`; `item_at`/`take_item`/`place_item` need a return value, so callers fetch the node directly instead (`get_tree().get_first_node_in_group("dungeon")`)
- `"hud"`: `show_message`
- `"level_complete"` / `"game_over"`: `show_screen`
- `"party"`: `attack(slot)`, `take_hit_from(monster)`

So the overlay, HUD and level-complete scenes can be deleted from `main.tscn` without breaking anything. Keep new UI the same way.

**Grid movement** (`player.gd`): input is polled in `_process`; a step or turn is a 0.2 s tween and input is ignored while it runs. Logical position (`cell`, `facing`) changes at the *start* of a move, and `_report_position()` publishes it via `DungeonMap.player_cell` plus a `refresh` call. F is edge-triggered (a held key must not repeat a lever pull). Facing indices: 0 N, 1 W, 2 S, 3 E (increasing = turning left).

**Doors, plates, levers** (all in `dungeon_builder.gd`): `_drive_door(cell, open)` is the single path that opens or closes any door. A door is only walkable once its slide finishes (`DungeonMap.open_doors`), closing blocks immediately, and a door never closes while the player or a monster stands in it. Doors with an ID in `DOOR_IDS` ignore F and are driven only by their plates/levers via `refresh()`; a door is open if *any* of its switches is active.

**Items** (`item_def.gd` resource in `data/items/*.tres`, listed by cell in `DungeonMap.ITEMS`): `dungeon_builder.gd` owns both the floor sprites and the run-time state (`item_at`/`take_item`/`place_item`), unlike monsters/doors there's no DungeonMap-level tracking. Left click picks up the item on the tile in front onto the cursor overlay (`cursor_item.gd`, group `"cursor"`, fetched directly like `"dungeon"`) or drops the held one there; the cursor is the party's single "hand" (one item), shared with the inventory screen. A locked door uses up a key from the cursor first, otherwise from any party member's backpack (`player._take_key` -> `Party.take_key`, dead members' packs included so a key can't be stranded on a corpse); it used to check only the cursor, which broke as soon as keys could be stored in the inventory. **What items do** (all in `party.gd`, no UI needed to test): an equipped **weapon** (first WEAPON in a hand slot, left first; a backpack weapon doesn't count) adds its `attack_bonus` and *replaces* the holder's bare-handed damage range in `effective_stats()`, which `attack()` uses -- never mutate the shared `CharacterDef`. `use_item(slot, def)` (right-click in the inventory) returns `{used, message, close}`: a **potion** (`heal_amount`) heals the member whose inventory it's in, capped at max HP, refused at full health or if dead; a **scroll** (`spell_damage_min/max`) hits the first monster in the straight line ahead (up to `MISSILE_RANGE` 4, stopped by walls and closed doors), never misses, is consumed, and closes the inventory so the result is visible. `defence_bonus` (armour) is still data only. Items have two icons: `icon` (24x24, slots and cursor) and `floor_icon` (12x12, the floor sprite; falls back to `icon`, as the 16x16 key does). Icons come from `tools/art/gen_items.py`. Pickup/drop isn't gated on the click actually landing on the sprite, only on the item being on the front tile -- deliberate, for headless-testability.

**Inventory** (`inventory_screen.gd` + `inventory_slot.gd`/`inventory_floor_drop.gd`, group `"inventory"`, opened by clicking a portrait on `party_hud.gd` or inside the screen itself): shows one "focused" `Party.Member`'s two hand slots, armour slot and 12-slot backpack (new `Member` fields: `hands`, `armour`, `backpack`, pure data -- nothing in combat reads them yet), plus a strip of every member's portrait. **One input system, Eye of the Beholder click-to-click, no drag and drop:** the cursor is the hand; click a slot to pick up, click a slot to put down (swap if occupied, refuse with a status-line message if the type doesn't fit), click a portrait to put the held item in that member's backpack or, empty-handed, to switch to them, click outside the window to drop it on the floor in front. Handlers act on the mouse **press**: Godot routes the release to whichever control received the press, wherever the pointer ends up, so a release-based handler can't tell where the player let go (this was the "item lands in the wrong slot" bug, along with an earlier drag-and-drop system competing with the cursor). Item slots are 24x24 and draw their icon at native size, centred; portrait slots are 16x16 and scale the 32x32 portrait to exactly half. **A `TextureRect` needs `expand_mode = EXPAND_IGNORE_SIZE` to be smaller than its texture** -- without it the strip portraits drew 32x32 over their neighbours while the hit boxes stayed 16x16. The window must stay inside the 320x200 viewport (check with a layout probe after changing slot sizes). Right-click on a consumable uses it (see Items). The screen pauses the game (`PROCESS_MODE_ALWAYS`); `CursorItem` must also be `PROCESS_MODE_ALWAYS` and on a canvas layer above the inventory (15 vs 11), or the held icon freezes / draws behind the window. The window panel stays mouse-filter Stop so a click between slots does nothing instead of dropping the item on the floor. **Test GUI input through real routing** (`root.push_input(event, true)` with viewport-space positions), not by calling `_gui_input` directly -- direct calls skip routing and passed while the real game was broken.

**Monsters** (`monster.gd` + `MonsterDef` resource in `data/monsters/*.tres`): new monsters are data plus a line in `MONSTERS`. A monster claims its destination tile in `DungeonMap.occupied` when a step starts and frees the old one when it ends. AI is a staggered timer: chase if within sight range (grid distance) with `has_line_of_sight`, else wander; orthogonal moves only. Next to the party a monster stops moving and attacks on its own `attack_interval` timer.

**Stacks** (`item_stack.gd`, `stack_count.gd`): every place an item can sit -- hand, armour, backpack cell, quick slot, the cursor, a floor tile (`dungeon_builder.items[cell].stack`) -- holds an `ItemStack` (`def` + `count`) or null, never a bare `ItemDef`. `ItemDef.max_stack` (default 1 = never stacks; Healing Potion 9; scrolls stay 1) decides what merges. `ItemStack.wrap()` turns an `ItemDef` into a stack of one, so `cursor.hold(def)`, `set_quick`, `place_item` accept either. Never share one stack object between two places; `take_one()` makes a new one. Rules: picking up (slot, world) takes the whole stack; clicking a held stack onto a matching backpack/quick stack merges up to `max_stack` and the remainder stays on the cursor; right-click on a stack of 2+ splits one onto the cursor (or adds one to a matching stack already held), a single item is picked up (quick slot) or used (inventory backpack); hands and armour take one item only; `Party.add_to_backpack` (portrait click) tops up matching stacks first. A potion in a quick slot uses one per use. **Inventory right-click on a stack splits rather than uses**; shift+right-click uses one (`event.shift_pressed`), as does a quick slot. The count is a 3x5 pixel digit in the icon's corner (`art/ui/digits.png` from `gen_ui.py`); `StackCount` sizes itself to its parent control by hand because anchors left it 0x0 inside an already-laid-out slot. A `Resource` is also a `RefCounted`: test `is Resource` first when telling an `ItemDef` from an `ItemStack`.

**Quick slots** (`quick_slot.gd`, two under each portrait in `party_hud.gd`; contents in `Party.Member.quick[2]` / `quick_cooldown[2]`, never on the shared `CharacterDef`): consumables only (`Party.quick_accepts`). Same click-to-click cursor as the inventory, acting on press: left click with a held item puts it in (swap if full), left click empty-handed uses it on that hero (`Party.use_quick` -> `use_item`; spent only if it actually worked, then a `QUICK_COOLDOWN` 1.0 s per-slot cooldown drawn as a grey clock-wipe), right click lifts it onto the cursor. Hover shows the item name in the message line (`Hud.show_message(text, hold)` / `clear_message(only_if)`). Dead heroes' slots can't be used or filled, but right-click still lifts the item out so nothing is stranded. **Keys 1-8 are the quick slots** (hero 1 = 1,2; hero 2 = 3,4...; `player.gd`); the old 1-4 attack hotkeys are gone, attack by clicking a hand button. Not usable while the inventory is open. Art: `gen_ui.py` (`quickslot*.png`, 14x14).

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
