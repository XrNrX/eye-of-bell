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
## The level fields (MAP ... MONSTERS, SIGNS, AMBUSHES, STATIONS) are static vars holding floor 1, so another level file can
## replace them: use_level("res://levels/test_room.gd") copies that file's consts of the same names over them (fields it
## leaves out become empty), use_level("") brings floor 1 back. A level file is a plain script of consts, nothing else.

const TILE_SIZE := 2.0   # World units per grid tile.
const WALL_HEIGHT := 2.0

## The level is traced from a hand-drawn map (the 23x23 grid of map.png, shifted two rows down and one
## column right so there is a wall border and room for two closets north of room 7). Where the map
## drew a feature the game has no tile for, it became: archway = open floor, portcullis = a door
## driven by a lever or plate (DOOR_IDS), up stairs = the landing the player starts on.
## Numbers in the comments are the room numbers on that map.
static var MAP := [
	[1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1],  # 0
	[1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 1, 0, 1],  # 1
	[1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 2, 1, 3, 1],  # 2
	[1, 1, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 1, 0, 0, 0, 1],  # 3
	[1, 1, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 7, 1, 0, 0, 0, 1],  # 4
	[1, 1, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 2, 0, 0, 0, 1],  # 5
	[1, 1, 6, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 2, 1, 1, 1, 5, 1],  # 6
	[1, 1, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 1],  # 7
	[1, 1, 1, 1, 1, 1, 0, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 1],  # 8
	[1, 1, 1, 1, 0, 0, 0, 7, 0, 0, 0, 1, 0, 0, 0, 0, 0, 2, 0, 0, 0, 1],  # 9
	[1, 1, 1, 1, 1, 1, 0, 1, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 2, 1, 1, 1],  # 10
	[1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 1, 1, 1],  # 11
	[1, 1, 1, 1, 1, 1, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 1, 1, 1],  # 12
	[1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 0, 1, 1, 1],  # 13
	[1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 1, 1, 1, 1, 1, 0, 1, 1, 1],  # 14
	[1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1],  # 15
	[1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 0, 1, 1, 1],  # 16
	[1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 0, 0, 0, 1],  # 17
	[1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 1, 1, 0, 0, 0, 1, 1, 1, 1, 1, 3, 1],  # 18
	[1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 1],  # 19
	[1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 1, 0, 1],  # 20
	[1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 5, 0, 1],  # 21
	[1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 1],  # 22
	[1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 4, 4, 0, 1],  # 23
	[1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1],  # 24
]

static var START_TILE := Vector2i(5, 9)  # (x, z) grid cell the player spawns in (the up-stairs landing).
static var START_FACING := 3             # 0 = north (-Z), 1 = west, 2 = south, 3 = east.


# Wall torches as Vector3i(x, z, side): the floor cell they light, and which of
# its walls they hang on (0 = north, 1 = west, 2 = south, 3 = east).
static var TORCHES := [
	Vector3i(3, 7, 0),
	Vector3i(5, 9, 2),
	Vector3i(6, 11, 1),
	Vector3i(6, 12, 3),
	Vector3i(9, 13, 2),
	Vector3i(12, 14, 1),
	Vector3i(14, 15, 0),
	Vector3i(17, 15, 2),
	Vector3i(18, 13, 3),
	Vector3i(18, 16, 1),
	Vector3i(20, 19, 3),
	Vector3i(20, 22, 3),
	Vector3i(9, 9, 0),
	Vector3i(14, 7, 0),
	Vector3i(12, 9, 1),
	Vector3i(14, 11, 2),
	Vector3i(16, 5, 1),
	Vector3i(19, 3, 0),
	Vector3i(19, 9, 2),
	Vector3i(13, 17, 0),
	Vector3i(17, 21, 2),
	Vector3i(8, 15, 0),
	Vector3i(9, 18, 3),
	Vector3i(18, 1, 0),
	Vector3i(20, 1, 0),
]

# Corrupted walls (tile 7): how many Blesses each takes to burn away (1 = thin, 2 = thick). Every tile 7 in MAP needs an entry.
static var CORRUPTION := {
	Vector2i(7, 9): 1,   # Right in front of the fighter at the start: the first thing anyone tries to smash. Opens the way into room 5.
	Vector2i(16, 4): 2,  # North of the nook above room 3 (a dead end that begs to be smashed): a closet of loot behind it.
}

# --- Puzzles ---
# A puzzle is data: when every condition in "when" holds, its "then" effects run, once (scripts/puzzles.gd).
#   conditions: {"kind": "wall_purified", "cell": Vector2i}   a corrupted wall has been burned away
#               {"kind": "lever_on", "cell": Vector2i, "side": int}   a wall lever is switched on
#   effects:    {"kind": "message", "text": String}           a line in the log
#               {"kind": "open_door", "id": String}           a DOOR_IDS door stays open for good (as if a switch held it)
#               {"kind": "break_wall", "cell": Vector2i}      a cracked wall breaks
#               {"kind": "purify_wall", "cell": Vector2i}     a corrupted wall is purified (a lever or plate can do it)
static var PUZZLES := [
	{"id": "nook_blessing", "when": [{"kind": "wall_purified", "cell": Vector2i(16, 4)}], "then": [
		{"kind": "message", "text": "The curse bleeds out of the stone. Somewhere in the dark, a latch gives way."},
		{"kind": "open_door", "id": "gate_n"},
	]},
]

# --- Switches and linked doors ---
# Give a door an ID here and it is controlled only by switches that name that ID
# as their "target" (F does nothing on it). A door is open while ANY of its
# switches is active: a lever that is switched on, or a plate someone stands on.
static var DOOR_IDS := {
	Vector2i(20, 6): "gate_n",
	Vector2i(19, 21): "gate_s",
}

# Pressure plates: open their target door while the player stands on "cell".
static var PLATES := [
	{"cell": Vector2i(18, 21), "target": "gate_s"},
]

# Hand-placed scenery (see wall_decor.gd): {"cell": the floor tile, "kind": "arch" | "pillar" | "alcove", "side": 0 north,
# 1 west, 2 south, 3 east (for a pillar or alcove: which wall of the tile it is on), "axis": "x" | "z" (arch only; the
# direction the corridor runs, found from the walls if left out)}. Nothing here blocks movement. Long corridors also
# get arches by rule (data/wall_decor.tres), so list only the spots you want to be sure of.
static var STRUCTURES := [
	{"cell": Vector2i(8, 13), "kind": "alcove", "side": 0},  # Beside the long first corridor: the first thing a player sees.
]

# Wall levers: "cell" is the floor tile you stand on, "side" the wall it hangs on
# (0 = north, 1 = west, 2 = south, 3 = east). Face that wall and press F to toggle.
static var LEVERS := [
	{"cell": Vector2i(19, 7), "side": 0, "target": "gate_n"},
	{"cell": Vector2i(20, 5), "side": 3, "target": "gate_n"},
	{"cell": Vector2i(20, 20), "side": 3, "target": "gate_s"},
]

# Items lying on the floor at the start: the cell and an ItemDef resource (see
# scripts/item_def.gd). dungeon_builder.gd owns their sprites and run-time state
# (picked up / dropped); this is just the starting layout. Optional "count": a stack.
static var ITEMS := [
	{"cell": Vector2i(6, 10), "def": "res://data/items/short_sword.tres"},  # In front of the start.
	{"cell": Vector2i(6, 11), "def": "res://data/items/leather_armour.tres"},
	{"cell": Vector2i(6, 8), "def": "res://data/items/healing_potion.tres"},
	{"cell": Vector2i(4, 7), "def": "res://data/items/darts.tres", "count": 4},
	{"cell": Vector2i(10, 10), "def": "res://data/items/key.tres"},  # Room 5: key one (opens the way to the stairs).
	{"cell": Vector2i(10, 9), "def": "res://data/items/healing_potion.tres"},
	{"cell": Vector2i(8, 11), "def": "res://data/items/dagger.tres"},
	{"cell": Vector2i(12, 11), "def": "res://data/items/mace.tres"},  # Room 3.
	{"cell": Vector2i(14, 7), "def": "res://data/items/scroll.tres"},
	{"cell": Vector2i(16, 11), "def": "res://data/items/healing_potion.tres"},
	{"cell": Vector2i(12, 7), "def": "res://data/items/darts.tres", "count": 3},
	{"cell": Vector2i(16, 5), "def": "res://data/items/scroll.tres"},  # The nook north of room 3.
	{"cell": Vector2i(20, 3), "def": "res://data/items/key.tres"},  # Room 7: key two.
	{"cell": Vector2i(20, 9), "def": "res://data/items/healing_potion.tres"},  # Room 2.
	{"cell": Vector2i(18, 1), "def": "res://data/items/healing_potion.tres", "count": 3},  # Closet behind the plain door.
	{"cell": Vector2i(20, 1), "def": "res://data/items/scroll.tres"},  # Closet behind the locked door: the best loot.
	{"cell": Vector2i(20, 1), "def": "res://data/items/healing_potion.tres", "count": 2},
	{"cell": Vector2i(20, 1), "def": "res://data/items/darts.tres", "count": 6},
	{"cell": Vector2i(20, 1), "def": "res://data/items/scroll_resurrection.tres"},  # Rare: the locked closet.
	{"cell": Vector2i(13, 19), "def": "res://data/items/key.tres"},  # Room 4: key three (opens the locked closet).
	{"cell": Vector2i(14, 17), "def": "res://data/items/healing_potion.tres"},
	{"cell": Vector2i(16, 21), "def": "res://data/items/darts.tres", "count": 5},  # Room 6.
	{"cell": Vector2i(17, 21), "def": "res://data/items/dagger.tres"},
	{"cell": Vector2i(9, 16), "def": "res://data/items/slingshot.tres"},  # The cave: a ranged weapon that spends stones...
	{"cell": Vector2i(10, 16), "def": "res://data/items/stone.tres", "count": 10},
	{"cell": Vector2i(6, 7), "def": "res://data/items/stone.tres", "count": 6},  # ...and more stones near the start and in room 3.
	{"cell": Vector2i(14, 9), "def": "res://data/items/stone.tres", "count": 8},
	{"cell": Vector2i(19, 9), "def": "res://data/items/bow.tres"},  # Room 2: a better launcher than the slingshot, with its arrows.
	{"cell": Vector2i(18, 9), "def": "res://data/items/arrow.tres", "count": 8},
	{"cell": Vector2i(13, 7), "def": "res://data/items/arrow.tres", "count": 6},  # Room 3.
	{"cell": Vector2i(18, 19), "def": "res://data/items/arrow.tres", "count": 6},  # The corridor to the far stairs.
	{"cell": Vector2i(15, 19), "def": "res://data/items/flail.tres"},  # The passage into room 6: a wild, heavy weapon.
	{"cell": Vector2i(7, 17), "def": "res://data/items/scroll.tres"},  # The cave.
	{"cell": Vector2i(7, 18), "def": "res://data/items/healing_potion.tres", "count": 2},
	{"cell": Vector2i(8, 15), "def": "res://data/items/leather_armour.tres"},
	{"cell": Vector2i(20, 19), "def": "res://data/items/healing_potion.tres"},  # The corridor to the far stairs.
	{"cell": Vector2i(15, 9), "def": "res://data/items/long_sword.tres"},  # Room 3: a better sword than the short one, with the mace and hammer.
	{"cell": Vector2i(12, 10), "def": "res://data/items/war_hammer.tres"},  # Room 3, by the mace: the heavy weapon that breaks a cracked wall.
	{"cell": Vector2i(2, 3), "def": "res://data/items/healing_potion.tres", "count": 3},  # The secret closet behind the cracked wall.
	{"cell": Vector2i(2, 4), "def": "res://data/items/scroll.tres"},
	{"cell": Vector2i(2, 5), "def": "res://data/items/darts.tres", "count": 8},
	{"cell": Vector2i(2, 5), "def": "res://data/items/scroll_resurrection.tres"},  # Rare: the secret closet.
	{"cell": Vector2i(16, 3), "def": "res://data/items/healing_potion.tres", "count": 3},  # The closet behind the thick corrupted wall.
	{"cell": Vector2i(16, 3), "def": "res://data/items/scroll.tres"},
	{"cell": Vector2i(16, 3), "def": "res://data/items/dried_meat.tres", "count": 2},
	{"cell": Vector2i(2, 3), "def": "res://data/items/leather_armour.tres"},
	# Food: scavenged rations (heal slowly; the mouldy bread is a gamble).
	{"cell": Vector2i(6, 9), "def": "res://data/items/stale_bread.tres"},  # Near the start.
	{"cell": Vector2i(10, 11), "def": "res://data/items/withered_apple.tres"},  # Room 5.
	{"cell": Vector2i(16, 10), "def": "res://data/items/hard_cheese.tres"},  # Room 3.
	{"cell": Vector2i(20, 8), "def": "res://data/items/mouldy_bread.tres"},  # Room 2: tempting, and risky.
	{"cell": Vector2i(14, 18), "def": "res://data/items/dried_meat.tres"},  # Room 4.
	{"cell": Vector2i(7, 16), "def": "res://data/items/mouldy_bread.tres"},  # The cave.
	{"cell": Vector2i(20, 1), "def": "res://data/items/dried_meat.tres", "count": 2},  # The locked closet.
	{"cell": Vector2i(2, 4), "def": "res://data/items/hard_cheese.tres"},  # The secret closet.
]

# Monsters: the floor cell they start on and their definition resource (see
# scripts/monster_def.gd). New monsters are just new .tres files listed here.
static var MONSTERS := [
	{"cell": Vector2i(9, 10), "def": "res://data/monsters/slime.tres"},
	{"cell": Vector2i(9, 13), "def": "res://data/monsters/skeleton.tres"},
	{"cell": Vector2i(15, 15), "def": "res://data/monsters/slime.tres"},
	{"cell": Vector2i(14, 9), "def": "res://data/monsters/skeleton_guard.tres"},
	{"cell": Vector2i(13, 8), "def": "res://data/monsters/slime_acid.tres"},
	{"cell": Vector2i(19, 4), "def": "res://data/monsters/skeleton.tres"},
	{"cell": Vector2i(19, 3), "def": "res://data/monsters/slime_acid.tres"},
	{"cell": Vector2i(19, 8), "def": "res://data/monsters/skeleton.tres"},
	{"cell": Vector2i(19, 17), "def": "res://data/monsters/skeleton_guard.tres"},
	{"cell": Vector2i(20, 21), "def": "res://data/monsters/slime_acid.tres"},
	{"cell": Vector2i(20, 22), "def": "res://data/monsters/skeleton_guard.tres"},
	{"cell": Vector2i(17, 20), "def": "res://data/monsters/skeleton.tres"},
	{"cell": Vector2i(13, 17), "def": "res://data/monsters/slime_acid.tres"},
	{"cell": Vector2i(8, 16), "def": "res://data/monsters/skeleton_guard.tres"},
	{"cell": Vector2i(9, 18), "def": "res://data/monsters/skeleton.tres"},
]

# Wall signs: {"cell": the floor tile you stand on, "side": the wall it hangs on (0 north, 1 west, 2 south, 3 east), "text": String}.
# Floor 1 has none; the test room labels its stations with them (wall_signs.gd).
static var SIGNS := []

# Test-room only (read by scripts/debug/, never by the game): trap tiles that spawn monsters when stepped on
# ({"trigger": Vector2i, "text": String, "monsters": [{"cell": Vector2i, "def": String}]}, re-armed when the party leaves the
# station's rows) and the named places T teleports to ({"name": String, "cell": Vector2i, "facing": int}).
static var AMBUSHES := []
static var STATIONS := []

## The level file now in use, or "" for floor 1.
static var level_path := ""
const TEST_ROOM_PATH := "res://levels/test_room.gd"
const TOOLS_PATH := "res://scripts/debug/test_room_tools.gd"  # F12, the debug keys and the help overlay (debug builds only).
const LEVEL_FIELDS := ["MAP", "START_TILE", "START_FACING", "TORCHES", "CORRUPTION", "PUZZLES", "DOOR_IDS", "PLATES",
		"STRUCTURES", "LEVERS", "ITEMS", "MONSTERS", "SIGNS", "AMBUSHES", "STATIONS"]
static var _floor1 := {}


## True in a debug build that has the test room's level file (a release export leaves it out).
static func test_room_available() -> bool:
	return OS.is_debug_build() and ResourceLoader.exists(TEST_ROOM_PATH)


## Make `path` (a level script of consts) the current level, or "" for floor 1. Call before the dungeon is built.
static func use_level(path: String) -> void:
	if _floor1.is_empty():
		for f in LEVEL_FIELDS:
			_floor1[f] = _field(f)
	level_path = path
	var consts: Dictionary = {}
	if path != "":
		consts = load(path).get_script_constant_map()
	for f in LEVEL_FIELDS:
		var value = _floor1[f] if path == "" else consts.get(f, _empty_like(_floor1[f]))
		_set_field(f, value.duplicate(true) if value is Array or value is Dictionary else value)
	reset_run()


static func _field(f: String):
	match f:
		"MAP":
			return MAP
		"START_TILE":
			return START_TILE
		"START_FACING":
			return START_FACING
		"TORCHES":
			return TORCHES
		"CORRUPTION":
			return CORRUPTION
		"PUZZLES":
			return PUZZLES
		"DOOR_IDS":
			return DOOR_IDS
		"PLATES":
			return PLATES
		"STRUCTURES":
			return STRUCTURES
		"LEVERS":
			return LEVERS
		"ITEMS":
			return ITEMS
		"MONSTERS":
			return MONSTERS
		"SIGNS":
			return SIGNS
		"AMBUSHES":
			return AMBUSHES
		"STATIONS":
			return STATIONS
	return null


static func _set_field(f: String, v) -> void:
	match f:
		"MAP":
			MAP = v
		"START_TILE":
			START_TILE = v
		"START_FACING":
			START_FACING = v
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
		"AMBUSHES":
			AMBUSHES = v
		"STATIONS":
			STATIONS = v


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
static var player_cell := Vector2i(-1, -1)  # Set by player.gd as it moves.


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
