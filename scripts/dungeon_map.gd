extends RefCounted
## The level data (used via preload, see dungeon_builder.gd / player.gd).
## Edit MAP below like a text file:
## 1 = wall, 0 = floor, 2 = door (starts closed), 3 = locked door (needs a key),
## 4 = stairs down (stepping on any of them completes the level),
## 5 = portcullis (an iron grate: a door you can see through, never opened by hand; give it
## an ID in DOOR_IDS and only its linked lever or plate raises it),
## 6 = cracked wall (looks like a wall with an obvious crack; solid until a Fireball or a heavy
## weapon like the war hammer breaks it, after which it is walkable floor with rubble).
## Row index is Z (north at top), column index is X.

const TILE_SIZE := 2.0   # World units per grid tile.
const WALL_HEIGHT := 2.0

## The level is traced from a hand-drawn map (the 23x23 grid of map.png, shifted two rows down and one
## column right so there is a wall border and room for two closets north of room 7). Where the map
## drew a feature the game has no tile for, it became: archway = open floor, portcullis = a door
## driven by a lever or plate (DOOR_IDS), up stairs = the landing the player starts on.
## Numbers in the comments are the room numbers on that map.
## The level is traced from a hand-drawn map (the 23x23 grid of map.png, shifted two rows down and one
## column right so there is a wall border and room for two closets north of room 7). Where the map
## drew a feature the game has no tile for, it became: archway = open floor, portcullis = a door
## driven by a lever or plate (DOOR_IDS), up stairs = the landing the player starts on.
## Numbers in the comments are the room numbers on that map.
## The level is traced from a hand-drawn map (the 23x23 grid of map.png, shifted two rows down and one
## column right so there is a wall border and room for two closets north of room 7). Where the map
## drew a feature the game has no tile for, it became: archway = open floor, portcullis = a door
## driven by a lever or plate (DOOR_IDS), up stairs = the landing the player starts on.
## Numbers in the comments are the room numbers on that map.
## The level is traced from a hand-drawn map (the 23x23 grid of map.png, shifted two rows down and one
## column right so there is a wall border and room for two closets north of room 7). Where the map
## drew a feature the game has no tile for, it became: archway = open floor, portcullis = a door
## driven by a lever or plate (DOOR_IDS), up stairs = the landing the player starts on.
## Numbers in the comments are the room numbers on that map.
## The level is traced from a hand-drawn map (the 23x23 grid of map.png, shifted two rows down and one
## column right so there is a wall border and room for two closets north of room 7). Where the map
## drew a feature the game has no tile for, it became: archway = open floor, portcullis = a door
## driven by a lever or plate (DOOR_IDS), up stairs = the landing the player starts on.
## Numbers in the comments are the room numbers on that map.
## The level is traced from a hand-drawn map (the 23x23 grid of map.png, shifted two rows down and one
## column right so there is a wall border and room for two closets north of room 7). Where the map
## drew a feature the game has no tile for, it became: archway = open floor, portcullis = a door
## driven by a lever or plate (DOOR_IDS), up stairs = the landing the player starts on.
## Numbers in the comments are the room numbers on that map.
const MAP := [
	[1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1],  # 0
	[1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 1, 0, 1],  # 1
	[1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 2, 1, 3, 1],  # 2
	[1, 1, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 1],  # 3
	[1, 1, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 1],  # 4
	[1, 1, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 2, 0, 0, 0, 1],  # 5
	[1, 1, 6, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 2, 1, 1, 1, 5, 1],  # 6
	[1, 1, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 1],  # 7
	[1, 1, 1, 1, 1, 1, 0, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 1],  # 8
	[1, 1, 1, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 0, 0, 2, 0, 0, 0, 1],  # 9
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

const START_TILE := Vector2i(5, 9)  # (x, z) grid cell the player spawns in (the up-stairs landing).
const START_FACING := 3             # 0 = north (-Z), 1 = west, 2 = south, 3 = east.


# Wall torches as Vector3i(x, z, side): the floor cell they light, and which of
# its walls they hang on (0 = north, 1 = west, 2 = south, 3 = east).
const TORCHES: Array[Vector3i] = [
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
	Vector3i(16, 5, 0),
	Vector3i(19, 3, 0),
	Vector3i(19, 9, 2),
	Vector3i(13, 17, 0),
	Vector3i(17, 21, 2),
	Vector3i(8, 15, 0),
	Vector3i(9, 18, 3),
	Vector3i(18, 1, 0),
	Vector3i(20, 1, 0),
]

# --- Switches and linked doors ---
# Give a door an ID here and it is controlled only by switches that name that ID
# as their "target" (F does nothing on it). A door is open while ANY of its
# switches is active: a lever that is switched on, or a plate someone stands on.
const DOOR_IDS := {
	Vector2i(20, 6): "gate_n",
	Vector2i(19, 21): "gate_s",
}

# Pressure plates: open their target door while the player stands on "cell".
const PLATES := [
	{"cell": Vector2i(18, 21), "target": "gate_s"},
]

# Wall levers: "cell" is the floor tile you stand on, "side" the wall it hangs on
# (0 = north, 1 = west, 2 = south, 3 = east). Face that wall and press F to toggle.
const LEVERS := [
	{"cell": Vector2i(19, 7), "side": 0, "target": "gate_n"},
	{"cell": Vector2i(20, 5), "side": 3, "target": "gate_n"},
	{"cell": Vector2i(20, 20), "side": 3, "target": "gate_s"},
]

# Items lying on the floor at the start: the cell and an ItemDef resource (see
# scripts/item_def.gd). dungeon_builder.gd owns their sprites and run-time state
# (picked up / dropped); this is just the starting layout. Optional "count": a stack.
const ITEMS := [
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
	{"cell": Vector2i(13, 19), "def": "res://data/items/key.tres"},  # Room 4: key three (opens the locked closet).
	{"cell": Vector2i(14, 17), "def": "res://data/items/healing_potion.tres"},
	{"cell": Vector2i(16, 21), "def": "res://data/items/darts.tres", "count": 5},  # Room 6.
	{"cell": Vector2i(17, 21), "def": "res://data/items/dagger.tres"},
	{"cell": Vector2i(7, 17), "def": "res://data/items/scroll.tres"},  # The cave.
	{"cell": Vector2i(7, 18), "def": "res://data/items/healing_potion.tres", "count": 2},
	{"cell": Vector2i(8, 15), "def": "res://data/items/leather_armour.tres"},
	{"cell": Vector2i(20, 19), "def": "res://data/items/healing_potion.tres"},  # The corridor to the far stairs.
	{"cell": Vector2i(12, 10), "def": "res://data/items/war_hammer.tres"},  # Room 3, by the mace: the heavy weapon that breaks a cracked wall.
	{"cell": Vector2i(2, 3), "def": "res://data/items/healing_potion.tres", "count": 3},  # The secret closet behind the cracked wall.
	{"cell": Vector2i(2, 4), "def": "res://data/items/scroll.tres"},
	{"cell": Vector2i(2, 5), "def": "res://data/items/darts.tres", "count": 8},
	{"cell": Vector2i(2, 3), "def": "res://data/items/leather_armour.tres"},
]

# Monsters: the floor cell they start on and their definition resource (see
# scripts/monster_def.gd). New monsters are just new .tres files listed here.
const MONSTERS := [
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

# --- Run state (reset by reset_run() when the dungeon is built) ---
static var occupied := {}        # Tiles holding a monster (cell -> monster node).
static var open_doors := {}      # Doors that have finished opening (cell -> true).
static var broken_walls := {}    # Cracked walls that have been broken (cell -> true); saved.
static var unlocked_doors := {}  # Locked doors a key has been used on (cell -> true).
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
	return tile == 1 or (tile == 6 and not broken_walls.has(cell))


## True if the cell is a cracked wall that is still standing: the only kind that can break.
## Ordinary walls, doors and portcullises are never destructible.
static func is_destructible(cell: Vector2i) -> bool:
	if cell.y < 0 or cell.y >= MAP.size() or cell.x < 0 or cell.x >= MAP[cell.y].size():
		return false
	return MAP[cell.y][cell.x] == 6 and not broken_walls.has(cell)


## World-space centre of a grid cell (at floor level).
static func cell_to_world(cell: Vector2i) -> Vector3:
	return Vector3(cell.x * TILE_SIZE, 0.0, cell.y * TILE_SIZE)
