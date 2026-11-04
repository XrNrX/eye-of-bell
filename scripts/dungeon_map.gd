extends RefCounted
## The level data (used via preload, see dungeon_builder.gd / player.gd).
## Edit MAP below like a text file: 1 = wall, 0 = floor, 2 = door (starts closed).
## Row index is Z (north at top), column index is X.

const TILE_SIZE := 2.0   # World units per grid tile.
const WALL_HEIGHT := 2.0

const MAP := [
	[1, 1, 1, 1, 1, 1, 1, 1, 1, 1],
	[1, 0, 0, 0, 1, 0, 0, 0, 0, 1],
	[1, 0, 1, 0, 1, 0, 1, 1, 0, 1],
	[1, 0, 1, 0, 0, 0, 0, 1, 0, 1],
	[1, 0, 1, 1, 1, 1, 0, 1, 0, 1],
	[1, 0, 0, 0, 0, 1, 0, 0, 0, 1],
	[1, 1, 1, 1, 2, 1, 1, 1, 2, 1],
	[1, 0, 0, 0, 0, 0, 0, 0, 0, 1],
	[1, 0, 1, 1, 1, 1, 1, 1, 1, 1],
	[1, 1, 1, 1, 1, 1, 1, 1, 1, 1],
]

const START_TILE := Vector2i(1, 1)  # (x, z) grid cell the player spawns in.
const START_FACING := 2             # 0 = north (-Z), 1 = west, 2 = south, 3 = east.


# Wall torches as Vector3i(x, z, side): the floor cell they light, and which of
# its walls they hang on (0 = north, 1 = west, 2 = south, 3 = east).
const TORCHES: Array[Vector3i] = [
	Vector3i(1, 1, 0),
	Vector3i(5, 1, 0),
	Vector3i(1, 5, 1),
	Vector3i(3, 7, 2),
	Vector3i(8, 7, 2),
]

## Doors that have finished opening (cell -> true). Reset by dungeon_builder.gd.
static var open_doors := {}


## True if the cell is a door (open or closed).
static func is_door(cell: Vector2i) -> bool:
	if cell.y < 0 or cell.y >= MAP.size() or cell.x < 0 or cell.x >= MAP[cell.y].size():
		return false
	return MAP[cell.y][cell.x] == 2


## True if the player can't walk into the cell: a wall or a door that isn't open yet.
static func is_blocked(cell: Vector2i) -> bool:
	return is_wall(cell) or (is_door(cell) and not open_doors.has(cell))


## True if the cell is a wall. Anything outside the map counts as wall.
static func is_wall(cell: Vector2i) -> bool:
	if cell.y < 0 or cell.y >= MAP.size():
		return true
	if cell.x < 0 or cell.x >= MAP[cell.y].size():
		return true
	return MAP[cell.y][cell.x] == 1


## World-space centre of a grid cell (at floor level).
static func cell_to_world(cell: Vector2i) -> Vector3:
	return Vector3(cell.x * TILE_SIZE, 0.0, cell.y * TILE_SIZE)
