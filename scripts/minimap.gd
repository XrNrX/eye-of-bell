extends Control
## Draws the DungeonMap.MAP array top-down, with the player as an arrow.

const DungeonMap := preload("res://scripts/dungeon_map.gd")

const CELL_PX := 6  # Size of one map cell on screen, in internal-resolution pixels.
const WALL_COLOR := Color(0.7, 0.7, 0.7)
const FLOOR_COLOR := Color(0.12, 0.12, 0.12)
const PLAYER_COLOR := Color(1.0, 0.3, 0.2)

var player: Node3D  # Assigned by debug_overlay.gd.


func _ready() -> void:
	var rows: int = DungeonMap.MAP.size()
	var cols: int = DungeonMap.MAP[0].size()
	custom_minimum_size = Vector2(cols, rows) * CELL_PX


func _draw() -> void:
	for z in DungeonMap.MAP.size():
		for x in DungeonMap.MAP[z].size():
			var color := WALL_COLOR if DungeonMap.MAP[z][x] == 1 else FLOOR_COLOR
			draw_rect(Rect2(Vector2(x, z) * CELL_PX, Vector2.ONE * CELL_PX), color)

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
