extends CanvasLayer
## The full-screen map (M): the whole level inked on stained parchment inside the rusted iron frame, with a legend.
## Same art and symbols as the corner map (minimap.gd): art/ui/map_parchment.png and map_frame.png, the PixelLab icons.
## Here floors are an ink wash (a checker of dark paper pixels), walls are inked only where they border floor (so solid
## rock stays blank paper, like a hand-drawn dungeon), doors, stairs, levers and found secrets are the 16x16 symbols and
## the party is the arrow, turned to face the way it faces. Monsters, traps and ambushes are never drawn.
## M or Escape closes it. It pauses the game while open, and will not open over another screen that owns the pause
## (inventory, pause menu, end screens).

const DungeonMap := preload("res://scripts/dungeon_map.gd")
const MapSymbols := preload("res://scripts/map_symbols.gd")
const PARCHMENT := preload("res://art/ui/map_parchment.png")
const FRAME := preload("res://art/ui/map_frame.png")

const CELL := 11                       # One map cell, in screen pixels (symbols are 16x16 and overhang 2 px).
const SHEET := preload("res://art/ui/map_sheet.png")  # 474x298: legend paper on the left, map paper on the right.
const LEGEND_W := 180                  # The left part of the sheet (the legend); the map is the rest.
const PANEL := Rect2(79, 27, 482, 306) # The framed sheet: the sheet plus the iron frame.
const BORDER := 4                      # The iron frame's thickness (as in map_frame.png).

const INK := Color("0b0a10")
const BONE_700 := Color("6b6250")
const RUST_700 := Color("4e2a1a")
const BLOOD_700 := Color("4a1418")

var icons := {}
var wash: Texture2D    # One cell of floor wash.
var canvas: Control
var frame_box := StyleBoxTexture.new()  # The iron frame stretched round the whole sheet (a nine-patch of map_frame.png).
var player: Node


func _ready() -> void:
	layer = 18  # Under the pause menu (19), over the inventory and everything else.
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	icons = MapSymbols.load_icons(false)
	wash = _make_wash()
	frame_box.texture = FRAME
	frame_box.set_texture_margin_all(BORDER)
	frame_box.draw_center = false
	frame_box.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	frame_box.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	canvas = Control.new()
	canvas.mouse_filter = Control.MOUSE_FILTER_STOP  # A click on the map does nothing, not a click on the dungeon behind it.
	canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	canvas.draw.connect(_draw_map)
	add_child(canvas)


func _make_wash() -> Texture2D:
	var img := Image.create(CELL, CELL, false, Image.FORMAT_RGBA8)
	for y in CELL:
		for x in CELL:
			if (x + y) % 2 == 0:
				img.set_pixel(x, y, BONE_700)
	return ImageTexture.create_from_image(img)


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if event.physical_keycode == KEY_M and not event.shift_pressed and not event.ctrl_pressed and not event.alt_pressed:
		if visible:
			close()
		elif not get_tree().paused:  # Another screen owns the pause: leave it be.
			open()
		else:
			return
		get_viewport().set_input_as_handled()
	elif visible and event.keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()


func open() -> void:
	player = get_tree().get_first_node_in_group("player")
	visible = true
	get_tree().paused = true
	get_tree().call_group("audio", "play", "ui_click")
	canvas.queue_redraw()


func close() -> void:
	visible = false
	get_tree().paused = false
	get_tree().call_group("audio", "play", "ui_click")


func _origin() -> Vector2:
	var rows: int = DungeonMap.MAP.size()
	var cols: int = DungeonMap.MAP[0].size()
	var inner := PANEL.grow(-BORDER)
	return Vector2(inner.position.x + LEGEND_W + (inner.size.x - LEGEND_W - cols * CELL) / 2.0,
			inner.position.y + (inner.size.y - rows * CELL) / 2.0)


func _draw_map() -> void:
	canvas.draw_rect(Rect2(Vector2.ZERO, Vector2(640, 360)), Color(INK, 0.78))  # Dims the dungeon behind.
	canvas.draw_rect(PANEL, INK)
	canvas.draw_texture(SHEET, PANEL.position + Vector2(BORDER, BORDER))
	var rows: int = DungeonMap.MAP.size()
	var origin := _origin()
	for y in rows:
		for x in DungeonMap.MAP[y].size():
			var c := Vector2i(x, y)
			var at := origin + Vector2(x, y) * CELL
			if DungeonMap.is_wall(c):
				if _borders_open(c):
					canvas.draw_rect(Rect2(at, Vector2(CELL, CELL)), INK)  # A wall that faces floor: inked.
					if DungeonMap.is_corrupted(c):
						canvas.draw_rect(Rect2(at + Vector2(3, 3), Vector2(CELL - 6, CELL - 6)), Color("3a6b4c"))  # curse_700
					elif DungeonMap.is_destructible(c):
						canvas.draw_rect(Rect2(at + Vector2(3, 3), Vector2(CELL - 6, CELL - 6)), RUST_700)
			else:
				canvas.draw_texture(wash, at)  # Floor, doors, stairs: a light ink wash.
	for y in rows:
		for x in DungeonMap.MAP[y].size():
			var icon := MapSymbols.icon_for(Vector2i(x, y))
			if icon != "":
				canvas.draw_texture(icons[icon], origin + Vector2(x, y) * CELL + Vector2(CELL, CELL) / 2.0 - Vector2(8, 8))
	for lever in DungeonMap.LEVERS:
		canvas.draw_texture(icons["lever"], origin + Vector2(lever.cell) * CELL + Vector2(CELL, CELL) / 2.0 - Vector2(8, 8))
	if player != null:  # The party: the arrow, turned to face the way they face (the art points north).
		var centre := origin + (Vector2(player.cell) + Vector2(0.5, 0.5)) * CELL
		canvas.draw_set_transform(centre, -player.facing * PI / 2.0)
		canvas.draw_texture(icons["arrow"], -icons["arrow"].get_size() / 2.0)
		canvas.draw_set_transform(Vector2.ZERO)
	canvas.draw_style_box(frame_box, PANEL)
	_draw_legend()


## A wall is inked only if one of the four cells beside it is not a wall (so it borders floor, a door or a gap).
func _borders_open(c: Vector2i) -> bool:
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		for _once in 1:
			var n: Vector2i = c + d
			if n.y >= 0 and n.y < DungeonMap.MAP.size() and n.x >= 0 and n.x < DungeonMap.MAP[n.y].size() \
					and not DungeonMap.is_wall(n):
				return true
	return false


func _draw_legend() -> void:
	var font := canvas.get_theme_default_font()
	var x := PANEL.position.x + BORDER + 24.0
	var y := PANEL.position.y + BORDER + 26.0
	_text(font, "LEGEND", Vector2(x, y), BLOOD_700)
	y += 12.0
	canvas.draw_rect(Rect2(x, y, 132, 1), INK)
	y += 10.0
	var rows := [
		["arrow", "YOU"], ["door_closed", "DOOR"], ["door_open", "OPEN DOOR"], ["door_locked", "LOCKED"],
		["stairs", "STAIRS"], ["lever", "LEVER"], ["secret", "SECRET FOUND"],
	]
	for row in rows:
		canvas.draw_texture(icons[row[0]], Vector2(x, y))
		_text(font, row[1], Vector2(x + 24, y + 12), INK)
		y += 22.0
	canvas.draw_rect(Rect2(x + 2, y + 2, 12, 12), INK)
	_text(font, "WALL", Vector2(x + 24, y + 12), INK)
	y += 22.0
	canvas.draw_texture(wash, Vector2(x + 2, y + 2))
	_text(font, "EXPLORED", Vector2(x + 24, y + 12), INK)
	y += 34.0
	_text(font, "M OR ESC", Vector2(x, y), BLOOD_700)
	_text(font, "CLOSES", Vector2(x, y + 12), BLOOD_700)


func _text(font: Font, s: String, at: Vector2, colour: Color) -> void:
	canvas.draw_string(font, at, s, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, colour)
