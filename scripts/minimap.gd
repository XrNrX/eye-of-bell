extends Control
## A small, slightly see-through map of the cells around the player, with the player always in the
## middle (north is up) and a triangle for the way they face. Drawn by debug_overlay.gd on Tab.
## Everything is palette colours; the cell size is even so it lines up with the 2x pixel grid.

const DungeonMap := preload("res://scripts/dungeon_map.gd")

const CELL_PX := 6                 # One map cell, in 640x360 pixels.
const COLS := 11                   # How many cells wide and tall the window shows (odd: the player is in the middle).
const ROWS := 9
const ALPHA := 0.72                # Translucency of everything in the map.

const INK := Color("0b0a10")
const STONE_700 := Color("31303c")
const STONE_300 := Color("7b7a88")
const WOOD_500 := Color("4f3a28")
const RUST_300 := Color("a8673a")
const RUST_500 := Color("7c4426")
const TORCH_500 := Color("d99a36")
const TORCH_300 := Color("f5cf80")

var player: Node3D  # Assigned by debug_overlay.gd.


func _ready() -> void:
	custom_minimum_size = Vector2(COLS, ROWS) * CELL_PX
	clip_contents = true


func _a(c: Color) -> Color:
	return Color(c, ALPHA)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), _a(INK))
	if player == null:
		return
	var origin: Vector2i = player.cell - Vector2i(COLS / 2, ROWS / 2)  # Map cell drawn in the top-left corner.
	for row in ROWS:
		for col in COLS:
			var c := origin + Vector2i(col, row)
			if c.y < 0 or c.y >= DungeonMap.MAP.size() or c.x < 0 or c.x >= DungeonMap.MAP[c.y].size():
				continue  # Off the edge of the level: empty.
			var color := _cell_color(c)
			if color.a > 0.0:
				draw_rect(Rect2(Vector2(col, row) * CELL_PX, Vector2.ONE * CELL_PX), color)

	for monster_cell in DungeonMap.occupied:  # Monsters as small squares.
		var at: Vector2 = Vector2(monster_cell - origin) * CELL_PX
		if at.x >= 0 and at.y >= 0 and at.x < size.x and at.y < size.y:
			draw_rect(Rect2(at + Vector2.ONE * 2, Vector2.ONE * (CELL_PX - 4)), _a(RUST_300))

	# The player: a triangle pointing the way they face (map-up = north = -Z), in the middle.
	var centre := (Vector2(COLS / 2, ROWS / 2) + Vector2(0.5, 0.5)) * CELL_PX
	var forward := Vector2(player.DIRS[player.facing])
	var side := forward.orthogonal()
	var r := CELL_PX * 0.5
	draw_colored_polygon(PackedVector2Array([
		centre + forward * r,
		centre - forward * r * 0.7 + side * r * 0.7,
		centre - forward * r * 0.7 - side * r * 0.7,
	]), TORCH_300)
	draw_rect(Rect2(Vector2.ZERO, size), _a(STONE_300), false, 1.0)  # A thin frame.


## Floor is left to the dark background (alpha 0 = nothing drawn).
func _cell_color(c: Vector2i) -> Color:
	if DungeonMap.is_destructible(c):
		return _a(STONE_300)  # The crack shows on the map too.
	if DungeonMap.is_wall(c):
		return _a(STONE_700)
	if DungeonMap.is_stairs(c):
		return _a(TORCH_500)
	if DungeonMap.is_portcullis(c) and not DungeonMap.open_doors.has(c):
		return _a(STONE_300)  # A grate: lighter than a wooden door.
	if DungeonMap.is_door(c):
		if DungeonMap.is_locked(c):
			return _a(RUST_500)
		if not DungeonMap.open_doors.has(c):
			return _a(WOOD_500)
	return Color(0, 0, 0, 0)
