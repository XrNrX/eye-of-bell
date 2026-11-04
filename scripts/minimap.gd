extends Control
## Draws the DungeonMap.MAP array top-down, with the player as an arrow.

const DungeonMap := preload("res://scripts/dungeon_map.gd")

const CELL_PX := 6  # Size of one map cell on screen, in internal-resolution pixels.
const WALL_COLOR := Color(0.7, 0.7, 0.7)
const FLOOR_COLOR := Color(0.12, 0.12, 0.12)
const DOOR_COLOR := Color(0.6, 0.4, 0.2)
const MONSTER_COLOR := Color(0.9, 0.15, 0.15)
const STAIRS_COLOR := Color(0.3, 0.6, 0.9)
const LOCKED_COLOR := Color(0.8, 0.2, 0.2)
const PLAYER_COLOR := Color(1.0, 0.3, 0.2)

var player: Node3D  # Assigned by debug_overlay.gd.


func _ready() -> void:
	var rows: int = DungeonMap.MAP.size()
	var cols: int = DungeonMap.MAP[0].size()
	custom_minimum_size = Vector2(cols, rows) * CELL_PX


func _draw() -> void:
	for z in DungeonMap.MAP.size():
		for x in DungeonMap.MAP[z].size():
			var color := FLOOR_COLOR
			if DungeonMap.MAP[z][x] == 1:
				color = WALL_COLOR
			elif DungeonMap.is_stairs(Vector2i(x, z)):
				color = STAIRS_COLOR
			elif DungeonMap.is_door(Vector2i(x, z)):
				var c := Vector2i(x, z)
				if DungeonMap.is_locked(c):
					color = LOCKED_COLOR
				elif not DungeonMap.open_doors.has(c):
					color = DOOR_COLOR
			draw_rect(Rect2(Vector2(x, z) * CELL_PX, Vector2.ONE * CELL_PX), color)

	for monster_cell in DungeonMap.occupied:  # Monsters as red squares.
		draw_rect(Rect2(Vector2(monster_cell) * CELL_PX + Vector2.ONE, Vector2.ONE * (CELL_PX - 2)), MONSTER_COLOR)

	if player == null:
		return

	# Triangle pointing the way the player faces (map-up = north = -Z).
	var centre := (Vector2(player.cell) + Vector2(0.5, 0.5)) * CELL_PX
	var forward := Vector2(player.DIRS[player.facing])
	var side := forward.orthogonal()
	var r := CELL_PX * 0.45
	draw_colored_polygon(PackedVector2Array([
		centre + forward * r,
		centre - forward * r * 0.7 + side * r * 0.7,
		centre - forward * r * 0.7 - side * r * 0.7,
	]), PLAYER_COLOR)
