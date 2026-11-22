extends RefCounted
## The level data (used via preload, see dungeon_builder.gd / player.gd).
## Edit MAP below like a text file:
## 1 = wall, 0 = floor, 2 = door (starts closed), 3 = locked door (needs a key),
## 4 = stairs down (stepping on any of them completes the level),
## 5 = portcullis (an iron grate: a door you can see through, never opened by hand; give it
## an ID in DOOR_IDS and only its linked lever or plate raises it),
## 6 = cracked wall (looks like a wall with an obvious crack; solid until a Fireball or a heavy
## weapon like the war hammer breaks it, after which it is walkable floor with rubble),
## 7 = corrupted wall (overgrown with the curse: pulsing green veins; weapons and Fireball just bounce off, only a Bless from a
## cleric purifies it, after which it is floor; CORRUPTION below says how many Blesses each one takes).
## Row index is Z (north at top), column index is X.
##
## The level fields (MAP ... MONSTERS, SIGNS, AMBUSHES, STATIONS, CURSE_ZONES) are static vars holding the level now in use. A level is
## DATA: use_level_data(dict) puts any dictionary of those fields in place (a generated level, later), and use_level(path) is the thin
## wrapper that reads a level script's consts into such a dictionary (use_level("") is floor 1, levels/floor_1.gd; use_level(
## "res://levels/test_room.gd") the test room). Fields a level leaves out become empty. A level file is a plain script of consts.

const TILE_SIZE := 2.0   # World units per grid tile.
const WALL_HEIGHT := 2.0

## The level fields: what the level now in use says (floor 1 until use_level / use_level_data replaces them). Their formats are
## documented with floor 1's data in levels/floor_1.gd; a level file is a plain script of consts with these names.
const FLOOR_1_PATH := "res://levels/floor_1.gd"
const FLOOR_1_ID := "floor_1"
const Floor1 := preload("res://levels/floor_1.gd")

static var MAP: Array = Floor1.MAP.duplicate(true)
static var START_TILE: Vector2i = Floor1.START_TILE   # (x, z) grid cell the player spawns in (the up-stairs landing).
static var START_FACING: int = Floor1.START_FACING    # 0 = north (-Z), 1 = west, 2 = south, 3 = east.
static var MENU_VIEW_CELL: Vector2i = Floor1.MENU_VIEW_CELL  # The main menu's camera cell (START_TILE if the level has none).

# Wall sconces as Vector4i(x, z, side, state): the floor cell they light, which of its walls they hang on (0 = north, 1 = west,
# 2 = south, 3 = east) and what is in them: SCONCE_LIT (a burning torch), SCONCE_UNLIT (a torch that is not burning: light it with a
# flame) or SCONCE_EMPTY (a bare bracket). The state at the start; what it is now is `sconce_state` (run state, saved). A plain
# Vector3i entry (an older level) is a lit one. Floor 1: 8 lit, 7 unlit and 10 empty (docs/design/expansion_design.md section 2).
const SCONCE_LIT := 0
const SCONCE_UNLIT := 1
const SCONCE_EMPTY := 2

static var TORCHES: Array = Floor1.TORCHES.duplicate(true)
static var CORRUPTION: Dictionary = Floor1.CORRUPTION.duplicate(true)
static var PUZZLES: Array = Floor1.PUZZLES.duplicate(true)
static var DOOR_IDS: Dictionary = Floor1.DOOR_IDS.duplicate(true)
static var PLATES: Array = Floor1.PLATES.duplicate(true)
static var STRUCTURES: Array = Floor1.STRUCTURES.duplicate(true)
static var LEVERS: Array = Floor1.LEVERS.duplicate(true)
static var ITEMS: Array = Floor1.ITEMS.duplicate(true)
static var MONSTERS: Array = Floor1.MONSTERS.duplicate(true)
static var SIGNS: Array = Floor1.SIGNS.duplicate(true)
static var ARMED_TRAPS: Array = Floor1.ARMED_TRAPS.duplicate(true)
static var AMBUSHES: Array = Floor1.AMBUSHES.duplicate(true)  # Test-room only (scripts/debug/).
static var STATIONS: Array = Floor1.STATIONS.duplicate(true)  # Test-room only.
static var CURSE_ZONES: Array = Floor1.CURSE_ZONES.duplicate(true)

## The level file now in use, or "" for floor 1 (and for the id of a level that was handed over as data, the id itself: anything
## but floor 1 refuses a save, see SaveGame.save).
static var level_path := ""
## The identity of the level now in use: FLOOR_1_ID, a level script's path, or the id given to use_level_data ("seed:123" for a
## generated one). The save stores it (SaveGame "level_id").
static var level_id := FLOOR_1_ID
const TEST_ROOM_PATH := "res://levels/test_room.gd"
const EDITOR_PATH := "res://scripts/debug/dungeon_editor.gd"  # F10: the dungeon editor (debug builds only, like the tools).
const EDITOR_PLAY_ID := "editor:play"  # The level id of a level built from the editor's paper (E.4): it cannot be saved.
const TOOLS_PATH := "res://scripts/debug/test_room_tools.gd"  # F12, the debug keys and the help overlay (debug builds only).
const LEVEL_FIELDS := ["MAP", "START_TILE", "START_FACING", "MENU_VIEW_CELL", "TORCHES", "CORRUPTION", "PUZZLES", "DOOR_IDS", "PLATES",
		"STRUCTURES", "LEVERS", "ITEMS", "MONSTERS", "SIGNS", "ARMED_TRAPS", "AMBUSHES", "STATIONS", "CURSE_ZONES"]


## Add the dungeon editor to the tree root, once (it lives there so it survives a Build changing the scene). Debug builds only: quiet if
## the editor's files are missing (a release export) or one exists already.
static func add_editor(tree: SceneTree) -> void:
	if not test_room_available() or not ResourceLoader.exists(EDITOR_PATH) or tree.get_first_node_in_group("dungeon_editor") != null:
		return
	tree.root.add_child.call_deferred(load(EDITOR_PATH).new())


## True in a debug build that has the test room's level file (a release export leaves it out).
## True in the "Test Room" export (custom feature "testroom"): the menu offers only the test room, and F12 does not leave it.
static func test_room_only() -> bool:
	return test_room_available() and OS.has_feature("testroom")


static func test_room_available() -> bool:
	return OS.is_debug_build() and ResourceLoader.exists(TEST_ROOM_PATH)


## Make `path` (a level script of consts) the current level, or "" for floor 1 (levels/floor_1.gd). Call before the dungeon is built.
## A thin wrapper: the script's consts are the level's data, and use_level_data does the work.
static func use_level(path: String) -> void:
	var source: String = path if path != "" else FLOOR_1_PATH
	use_level_data(load(source).get_script_constant_map(), FLOOR_1_ID if path == "" else path)


## Make a level given as DATA the current one: a dictionary with any of LEVEL_FIELDS (a field it leaves out becomes empty; a level
## with no MENU_VIEW_CELL gets its START_TILE for it). `id` says which level it is (FLOOR_1_ID, a script's path, or "seed:123" for a
## generated one): it is stored in the save and tells use_level_id how to build it again. The data is copied, so the caller's
## dictionary is never changed by the run. Starts a run (reset_run). Call before the dungeon is built.
static func use_level_data(data: Dictionary, id := FLOOR_1_ID) -> void:
	level_id = id
	level_path = "" if id == FLOOR_1_ID else id
	var floor_one: Dictionary = load(FLOOR_1_PATH).get_script_constant_map()
	for f in LEVEL_FIELDS:
		var value = data[f] if data.has(f) else _empty_like(floor_one[f])
		_set_field(f, value.duplicate(true) if value is Array or value is Dictionary else value)
	if not data.has("MENU_VIEW_CELL"):
		MENU_VIEW_CELL = START_TILE
	reset_run()


## Build the level a save names (its `level_id`; an older save has only a level path, "" for floor 1). Returns false if this game
## has no way to build it (a generated level's id, until generated levels exist).
static func use_level_id(id: String) -> bool:
	if id == "" or id == FLOOR_1_ID:
		use_level("")
		return true
	if id.begins_with("res://") and ResourceLoader.exists(id):
		use_level(id)
		return true
	return false


static func _set_field(f: String, v) -> void:
	match f:
		"MAP":
			MAP = v
		"START_TILE":
			START_TILE = v
		"START_FACING":
			START_FACING = v
		"MENU_VIEW_CELL":
			MENU_VIEW_CELL = v
		"TORCHES":
			TORCHES = v
		"CORRUPTION":
			CORRUPTION = v
		"PUZZLES":
			PUZZLES = v
		"DOOR_IDS":
			DOOR_IDS = v
		"PLATES":
			PLATES = v
		"STRUCTURES":
			STRUCTURES = v
		"LEVERS":
			LEVERS = v
		"ITEMS":
			ITEMS = v
		"MONSTERS":
			MONSTERS = v
		"SIGNS":
			SIGNS = v
		"ARMED_TRAPS":
			ARMED_TRAPS = v
		"AMBUSHES":
			AMBUSHES = v
		"STATIONS":
			STATIONS = v
		"CURSE_ZONES":
			CURSE_ZONES = v


static func _empty_like(v):
	if v is Array:
		return []
	if v is Dictionary:
		return {}
	return v


# --- Run state (reset by reset_run() when the dungeon is built) ---
static var occupied := {}        # Tiles holding a monster (cell -> monster node).
static var open_doors := {}      # Doors that have finished opening (cell -> true).
static var broken_walls := {}    # Cracked walls that have been broken (cell -> true); saved.
static var unlocked_doors := {}  # Locked doors a key has been used on (cell -> true).
static var corrupted_left := {}  # Corrupted walls still standing: cell -> Blesses they still need (from CORRUPTION); saved.
static var purified := {}        # Corrupted walls that have been burned away (cell -> true); saved.
static var purify_pending := {}  # Walls whose purifying show is still running: they stay solid until it ends (cell -> true).
static var puzzles_done := {}    # Puzzles that have fired (id -> true); saved.
static var puzzle_doors := {}    # DOOR_IDS doors a puzzle holds open (id -> true); saved.
## Sconces (TORCHES): what each holds now, keyed by Vector3i(x, z, side): SCONCE_LIT, SCONCE_UNLIT or SCONCE_EMPTY. Filled from TORCHES by the
## builder (`init_sconces`), cleared by reset_run, saved. `sconce_seconds` is the burn time of the torch in each one that holds a
## torch (a torch costs nothing while it hangs there); `sconce_seen` the ones the party has seen (the map shows those).
static var sconce_state := {}
static var sconce_seconds := {}
static var sconce_seen := {}
## Run flags: things that have happened in this run that no other state records (a banter line that may only be said once, an
## ambush that has sprung, a secret found). Name -> a bool, a whole number, a float or a String; nothing else is saved. Cleared by
## reset_run, saved under "flags" (an older save has none, so it loads with none). Name them "system.what", e.g. "banter.first_death".
static var flags := {}
static var player_cell := Vector2i(-1, -1)  # Set by player.gd as it moves.


## Set a run flag (true by default).
static func set_flag(name: String, value = true) -> void:
	if typeof(value) not in [TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING]:
		push_warning("run flag '%s': only a bool, number or String can be saved" % name)
		return
	flags[name] = value


## A run flag's value, or `default` if it was never set.
static func flag(name: String, default = false):
	return flags.get(name, default)


static func has_flag(name: String) -> bool:
	return flags.has(name)


## The ID of a switch-controlled door, or "" for an ordinary door.
static func door_id(cell: Vector2i) -> String:
	return DOOR_IDS.get(cell, "")


## The lever on the wall at `side` of `cell`, or {} if there isn't one.
static func lever_at(cell: Vector2i, side: int) -> Dictionary:
	for lever in LEVERS:
		if lever.cell == cell and lever.side == side:
			return lever
	return {}


## True if a monster stands on (or is stepping onto) the cell.
static func is_occupied(cell: Vector2i) -> bool:
	return occupied.has(cell)


## True if nothing solid (wall or closed door) lies between the two cells, so
## one can see the other. Samples the straight line between the cell centres.
static func has_line_of_sight(a: Vector2i, b: Vector2i) -> bool:
	var d := b - a
	var n: int = maxi(absi(d.x), absi(d.y))
	for i in range(1, n):
		var c := Vector2i(roundi(a.x + d.x * float(i) / n), roundi(a.y + d.y * float(i) / n))
		if is_blocked(c) and not is_portcullis(c):  # Bars block feet, not eyes.
			return false
	return true


static func reset_run() -> void:
	occupied.clear()
	open_doors.clear()
	unlocked_doors.clear()
	broken_walls.clear()
	corrupted_left = CORRUPTION.duplicate()
	purified.clear()
	purify_pending.clear()
	puzzles_done.clear()
	puzzle_doors.clear()
	sconce_state.clear()
	sconce_seconds.clear()
	sconce_seen.clear()
	flags.clear()


## Has a puzzle lifted this curse zone for good?
static func zone_cleared(id: String) -> bool:
	return flag("curse_zone.%s.cleared" % id, false) == true


## Lift a curse zone for good (a puzzle effect). Saved with the run flags.
static func clear_zone(id: String) -> void:
	set_flag("curse_zone.%s.cleared" % id, true)


## The id of the curse zone still in force on this tile, or "" for none (cleared zones are gone).
static func curse_zone_at(cell: Vector2i) -> String:
	for zone in CURSE_ZONES:
		if cell in zone.tiles and not zone_cleared(zone.id):
			return zone.id
	return ""


## The id of a curse zone in force with a tile within `reach` tiles of this one (a square, as the haze reaches a little past its tiles), or "".
## The haze spreads over open ground, so a tile that is not in the zone itself only counts if it can see the zone tile (a wall between,
## like the one between the long corridor and the cave, stops it: the sconce on the far side stays lit).
## Wall sconces use it: a torch on a wall within 2 tiles of the haze goes out too.
static func curse_zone_near(cell: Vector2i, reach: int) -> String:
	for zone in CURSE_ZONES:
		if zone_cleared(zone.id):
			continue
		for tile in zone.tiles:
			var d: Vector2i = (tile - cell).abs()
			if maxi(d.x, d.y) <= reach and (d == Vector2i.ZERO or has_line_of_sight(cell, tile)):
				return zone.id
	return ""


## Monsters the level places in a curse zone that are above tier 1: [{"zone", "def", "tier", "cell"}]. The design says nothing in a zone may
## be above tier 1 (the party is fighting blind there); the builder warns about each when the level loads.
static func zone_tier_violations() -> Array:
	var out := []
	for entry in MONSTERS:
		var zone := curse_zone_at(entry.cell)
		if zone == "":
			continue
		var def: Resource = load(entry.def)
		if def != null and def.tier > 1:
			out.append({"zone": zone, "def": entry.def, "tier": def.tier, "cell": entry.cell})
	return out


## Is this tile a camp spot: old ash on the floor, where a rest is rarely disturbed? A level lists them as STRUCTURES entries
## {"cell": Vector2i, "kind": "camp_spot"} (wall_decor.gd lays the ash). Nothing else uses them yet (the interruption rolls are 7h.4).
static func camp_spot_at(cell: Vector2i) -> bool:
	for entry in STRUCTURES:
		if entry.get("kind", "") == "camp_spot" and entry.cell == cell:
			return true
	return false


## Is a campfire burning on this tile? Nobody walks through it (the player and monsters check this; it does not block sight or missiles, as a
## fire does not, so it is not part of is_blocked).
static func is_campfire(cell: Vector2i) -> bool:
	for entry in STRUCTURES:
		if entry.get("kind", "") == "campfire" and entry.cell == cell:
			return true
	return false


## Is an ambush trigger tile within `reach` tiles of this one (a square)? The party may not make camp beside one. (AMBUSHES is the test
## room's stand-in; the real ambush system will list its triggers the same way.)
static func ambush_trigger_near(cell: Vector2i, reach: int) -> bool:
	for a in AMBUSHES:
		var d: Vector2i = (a.trigger - cell).abs()
		if maxi(d.x, d.y) <= reach:
			return true
	return false


## The key of a TORCHES entry in the sconce dictionaries.
static func sconce_key(entry) -> Vector3i:
	return Vector3i(entry.x, entry.y, entry.z)


## The state a TORCHES entry starts in (a plain Vector3i is a lit torch).
static func sconce_start_state(entry) -> int:
	return entry.w if entry is Vector4i else SCONCE_LIT


## Fill the sconce run state from TORCHES: every torch the level starts with burns for `torch_seconds` once it is taken out.
static func init_sconces(torch_seconds: float) -> void:
	sconce_state.clear()
	sconce_seconds.clear()
	sconce_seen.clear()
	for entry in TORCHES:
		var start := sconce_start_state(entry)
		sconce_state[sconce_key(entry)] = start
		sconce_seconds[sconce_key(entry)] = torch_seconds if start != SCONCE_EMPTY else 0.0


## True if the cell is a door of any kind (open, closed, locked or a portcullis).
static func is_door(cell: Vector2i) -> bool:
	if cell.y < 0 or cell.y >= MAP.size() or cell.x < 0 or cell.x >= MAP[cell.y].size():
		return false
	return MAP[cell.y][cell.x] == 2 or MAP[cell.y][cell.x] == 3 or MAP[cell.y][cell.x] == 5


## True if the cell is a portcullis (open or closed): the iron grate. It blocks movement and
## missiles like a door while shut, but not sight (see has_line_of_sight).
static func is_portcullis(cell: Vector2i) -> bool:
	if cell.y < 0 or cell.y >= MAP.size() or cell.x < 0 or cell.x >= MAP[cell.y].size():
		return false
	return MAP[cell.y][cell.x] == 5


## True if the cell is the stairs down.
static func is_stairs(cell: Vector2i) -> bool:
	if cell.y < 0 or cell.y >= MAP.size() or cell.x < 0 or cell.x >= MAP[cell.y].size():
		return false
	return MAP[cell.y][cell.x] == 4


## True if the cell is a locked door that hasn't been unlocked yet.
static func is_locked(cell: Vector2i) -> bool:
	return is_door(cell) and MAP[cell.y][cell.x] == 3 and not unlocked_doors.has(cell)


## True if the cell is solid terrain: a wall or a door that isn't open yet.
## (Monsters are separate, see is_occupied.)
static func is_blocked(cell: Vector2i) -> bool:
	return is_wall(cell) or (is_door(cell) and not open_doors.has(cell))


## True if the cell is a wall. Anything outside the map counts as wall, and so does a cracked
## wall until it has been broken.
static func is_wall(cell: Vector2i) -> bool:
	if cell.y < 0 or cell.y >= MAP.size():
		return true
	if cell.x < 0 or cell.x >= MAP[cell.y].size():
		return true
	var tile: int = MAP[cell.y][cell.x]
	return tile == 1 or (tile == 6 and not broken_walls.has(cell)) or (tile == 7 and (not purified.has(cell) or purify_pending.has(cell)))


## True if the cell is a cracked wall that is still standing: the only kind that can break.
## Ordinary walls, doors and portcullises are never destructible.
static func is_destructible(cell: Vector2i) -> bool:
	if cell.y < 0 or cell.y >= MAP.size() or cell.x < 0 or cell.x >= MAP[cell.y].size():
		return false
	return MAP[cell.y][cell.x] == 6 and not broken_walls.has(cell)


## True if the cell is a corrupted wall that has not been purified yet (one being purified still counts until the show ends).
static func is_corrupted(cell: Vector2i) -> bool:
	if cell.y < 0 or cell.y >= MAP.size() or cell.x < 0 or cell.x >= MAP[cell.y].size():
		return false
	return MAP[cell.y][cell.x] == 7 and (not purified.has(cell) or purify_pending.has(cell))


## World-space centre of a grid cell (at floor level).
static func cell_to_world(cell: Vector2i) -> Vector3:
	return Vector3(cell.x * TILE_SIZE, 0.0, cell.y * TILE_SIZE)
