extends Control
## The in-world map: the cells around the player, with the player always in the middle (north is up) and a
## triangle for the way they face, inked on a torn parchment inside a small rusted iron frame
## (art/ui/map_parchment.png and map_frame.png from tools/art/gen_map_art.py, native pixels).
## STAGE 1 (frame and parchment only): the cells are still the plain ones, drawn as ink; fog of war, the icons
## and the full-screen map come next. Drawn by debug_overlay.gd on Tab. Everything is palette colours.

const DungeonMap := preload("res://scripts/dungeon_map.gd")

const PARCHMENT := preload("res://art/ui/map_parchment.png")
const FRAME := preload("res://art/ui/map_frame.png")
const ICON_DIR := "res://art/ui/map/icon_%s_s.png"  # 8x8 reductions of the 16x16 PixelLab symbols (gen_map_icons.py).
const ARROW := "res://art/ui/map/icon_arrow.png"  # The party arrow is drawn full size (16x16): it is the one mark that must not get lost.
const ICON_NAMES := ["door_closed", "door_open", "door_locked", "stairs", "lever", "secret"]
const BORDER := 4                  # Thickness of the iron frame, in pixels.

const CELL_PX := 8                 # One map cell, in 640x360 pixels.
const COLS := 13                   # How many cells wide and tall the window shows (odd: the player is in the middle).
const ROWS := 10
const ALPHA := 0.85                # Ink is slightly thinned so the paper shows through.

const INK := Color("0b0a10")
const STONE_700 := Color("31303c")
const STONE_300 := Color("7b7a88")
const WOOD_500 := Color("4f3a28")
const RUST_300 := Color("a8673a")
const RUST_500 := Color("7c4426")
const TORCH_500 := Color("d99a36")
const CURSE_700 := Color("3a6b4c")  # Palette curse_700: a corrupted wall.
const RUST_700 := Color("4e2a1a")
const BLOOD_500 := Color("7a2224")
const TORCH_300 := Color("f5cf80")

var player: Node3D  # Assigned by debug_overlay.gd.
var icons := {}     # name -> Texture2D, loaded once.


func _ready() -> void:
	for n in ICON_NAMES:
		icons[n] = load(ICON_DIR % n)
	icons["arrow"] = load(ARROW)
	custom_minimum_size = FRAME.get_size()
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	clip_contents = true


func _a(c: Color) -> Color:
	return Color(c, ALPHA)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), INK)  # Behind the torn edges of the paper.
	draw_texture(PARCHMENT, Vector2(BORDER, BORDER))
	if player == null:
		draw_texture(FRAME, Vector2.ZERO)
		return
	var origin: Vector2i = player.cell - Vector2i(COLS / 2, ROWS / 2)  # Map cell drawn in the top-left corner.
	draw_set_transform(Vector2(BORDER, BORDER))
	for row in ROWS:
		for col in COLS:
			var c := origin + Vector2i(col, row)
			if c.y < 0 or c.y >= DungeonMap.MAP.size() or c.x < 0 or c.x >= DungeonMap.MAP[c.y].size():
				continue  # Off the edge of the level: empty.
			var color := _cell_color(c)
			if color.a > 0.0:
				draw_rect(Rect2(Vector2(col, row) * CELL_PX, Vector2.ONE * CELL_PX), color)

	# (Monsters are not drawn: the map is the party's own sketch, and shows nothing it has not met.
	# Traps and ambushes are not drawn either.)
	for row in ROWS:
		for col in COLS:
			var icon := _cell_icon(origin + Vector2i(col, row))
			if icon != "":
				draw_texture(icons[icon], Vector2(col, row) * CELL_PX)
	for lever in DungeonMap.LEVERS:
		var at: Vector2i = lever.cell - origin
		if at.x >= 0 and at.y >= 0 and at.x < COLS and at.y < ROWS:
			draw_texture(icons["lever"], Vector2(at) * CELL_PX)

	# The party: the arrow, turned to the way they face (the art points north; facing 1 is west = a quarter turn left).
	var centre := (Vector2(COLS / 2, ROWS / 2) + Vector2(0.5, 0.5)) * CELL_PX
	draw_set_transform(Vector2(BORDER, BORDER) + centre, -player.facing * PI / 2.0)
	draw_texture(icons["arrow"], -icons["arrow"].get_size() / 2.0)
	draw_set_transform(Vector2.ZERO)
	draw_texture(FRAME, Vector2.ZERO)


## Floor is left to the dark background (alpha 0 = nothing drawn).
func _cell_color(c: Vector2i) -> Color:
	if DungeonMap.is_destructible(c):
		return _a(RUST_700)  # The crack shows on the map too.
	if DungeonMap.is_corrupted(c):
		return _a(CURSE_700)  # So does the green rot.
	if DungeonMap.is_wall(c):
		return _a(INK)  # Walls are inked in.
	if DungeonMap.is_stairs(c) or DungeonMap.is_door(c):
		return Color(0, 0, 0, 0)  # Drawn as symbols instead (_cell_icon).
	return Color(0, 0, 0, 0)


## The symbol for what stands on a cell, or "" for none: doors (closed, open, locked), stairs, and a secret that
## has been found (a cracked wall broken open, or a corrupted one purified).
func _cell_icon(c: Vector2i) -> String:
	if DungeonMap.is_door(c):
		if DungeonMap.is_locked(c):
			return "door_locked"
		return "door_open" if DungeonMap.open_doors.has(c) else "door_closed"
	if DungeonMap.is_stairs(c):
		return "stairs"
	if DungeonMap.broken_walls.has(c) or DungeonMap.purified.has(c):
		return "secret"
	return ""
