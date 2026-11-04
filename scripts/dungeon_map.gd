extends RefCounted
## The level data (used via preload, see dungeon_builder.gd / player.gd). Edit MAP below like a text file: 1 = wall, 0 = floor.
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
	[1, 1, 1, 1, 0, 1, 1, 1, 0, 1],
	[1, 0, 0, 0, 0, 0, 0, 0, 0, 1],
	[1, 0, 1, 1, 1, 1, 1, 1, 1, 1],
	[1, 1, 1, 1, 1, 1, 1, 1, 1, 1],
]

const START_TILE := Vector2i(1, 1)  # (x, z) grid cell the player spawns in.
const START_FACING := 2             # 0 = north (-Z), 1 = west, 2 = south, 3 = east.


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
