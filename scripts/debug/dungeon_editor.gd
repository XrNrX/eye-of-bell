extends CanvasLayer
## The dungeon editor (roadmap E.1, "Squared paper and drawing"): F10 opens it from the main menu and from the game (debug builds
## only; it lives in scripts/debug, which a release export leaves out), F10 or Close or Escape leaves it. A sheet of squared paper on
## stained parchment in the iron frame of the M map: each square is wall (filled and cross-hatched, solid rock) or floor (blank).
##
## Left click or drag paints floor, right click or drag rubs it back to wall (the outer edge always stays wall); the middle mouse
## drag or W A S D pans, the wheel zooms (about the square under the mouse), and the square under the mouse is shown bottom right as
## (x,y), the same coordinates floor 1's data and the roadmap use (x across, y down, from the top left square (0,0)). Ctrl+Z undoes
## and Ctrl+Y (or Ctrl+Shift+Z) redoes a whole stroke, at least 50 deep (editor_config.gd undo_steps). New asks for a width and a
## height and starts a fresh sheet; Close leaves. In the game it pauses the world while open (and will not open over another screen
## that owns the pause).
##
## E.2 adds a TOOLBAR under the title: DRAW (the E.1 painting), SELECT, and a tool for each thing the game already has, using floor 1's
## own data shapes (editor_grid.gd level_data): door, locked door, gate (portcullis), cracked wall, lever, stairs down, the party start
## (one only, drawn as an arrow the way it faces) and a wall sconce (lit, unlit or empty). Doors, stairs, the start and cracked walls
## are placed by clicking a square; levers and sconces by clicking the EDGE of a square, on a wall face. Each is a small inked icon on
## the paper (drawn in code: a placeholder set, see docs/asset_log.md). Click a lever and then the door or gate it works (or the door,
## then the lever) to link them: a thin ink line joins them while either is selected; click the door again to unlink. SELECT picks a
## placed thing; Delete removes it; R turns it (the start a quarter turn, a lever or sconce to another wall face). The game's rules are
## kept (EditorGrid refuses what it would not allow, and a short message says why). Nothing is saved yet (E.4 builds a level).
##
## The paper is data (editor_grid.gd); this script draws it and turns the mouse and keys into strokes. Pixel rules: every line is one
## logical pixel, squares are a whole number of pixels (a multiple of 4, so the hatching of neighbours joins), no smooth gradients,
## palette colours only. The numbers (sheet size, zoom steps, undo depth) are in scripts/debug/editor_config.tres.

const EditorConfig := preload("res://scripts/debug/editor_config.gd")
const EditorGrid := preload("res://scripts/debug/editor_grid.gd")
const PARCHMENT := preload("res://art/ui/map_sheet.png")  # The stained paper of the M map (474x298), mirrored to cover the sheet.
const FRAME := preload("res://art/ui/map_frame.png")

# Palette colours (tools/art/palette.json).
const INK := Color("0b0a10")
const STONE_900 := Color("14131b")
const STONE_700 := Color("31303c")
const RUST_700 := Color("4e2a1a")
const RUST_500 := Color("7c4426")
const BONE_700 := Color("6b6250")
const BONE_500 := Color("9c9278")
const BONE_300 := Color("c9c0a4")
const BLOOD_500 := Color("7a2224")
const WOOD_500 := Color("4f3a28")
const LEATHER_400 := Color("74553a")
const STONE_500 := Color("504f5e")
const STONE_300 := Color("7b7a88")
const STONE_100 := Color("aaa9b4")
const TORCH_500 := Color("d99a36")
const TORCH_300 := Color("f5cf80")

const TOOLBAR_Y := 24                        # The toolbar strip between the title row and the paper.
const FRAME_RECT := Rect2(8, 46, 624, 294)   # The iron frame round the paper.
const BORDER := 4                            # Its thickness (map_frame.png).
const PAPER_RECT := Rect2(12, 50, 616, 286)  # The squared paper: the frame's inside.

enum Tool { DRAW, SELECT, DOOR, LOCKED, GATE, CRACKED, LEVER, STAIRS, START, SCONCE_LIT, SCONCE_UNLIT, SCONCE_EMPTY }
const TOOL_ORDER := [Tool.DRAW, Tool.SELECT, Tool.DOOR, Tool.LOCKED, Tool.GATE, Tool.CRACKED, Tool.LEVER, Tool.STAIRS, Tool.START, Tool.SCONCE_LIT, Tool.SCONCE_UNLIT, Tool.SCONCE_EMPTY]
const TOOL_NAMES := {Tool.DRAW: "DRAW", Tool.SELECT: "SELECT", Tool.DOOR: "DOOR", Tool.LOCKED: "LOCKED DOOR", Tool.GATE: "GATE", Tool.CRACKED: "CRACKED WALL",
		Tool.LEVER: "LEVER", Tool.STAIRS: "STAIRS DOWN", Tool.START: "PARTY START", Tool.SCONCE_LIT: "SCONCE LIT", Tool.SCONCE_UNLIT: "SCONCE UNLIT", Tool.SCONCE_EMPTY: "SCONCE EMPTY"}
const MESSAGE_SECONDS := 3.0
# The view moves the other way from the key's direction on the paper: W shows what is above.
const PAN_KEYS := {KEY_W: Vector2(0, 1), KEY_S: Vector2(0, -1), KEY_A: Vector2(1, 0), KEY_D: Vector2(-1, 0)}

var cfg: Resource = EditorConfig.get_config()
var grid := EditorGrid.new()
var zoom_index := 2
var cell_px := 16
var origin := Vector2.ZERO        # Where the top left corner of the grid is, in the paper's own pixels.
var hover := Vector2i(-1, -1)     # The square under the mouse, or (-1,-1).
var mode := 0                     # What the mouse is doing: 0 nothing, 1 painting floor, 2 rubbing to wall, 3 panning.
var last_cell := Vector2i(-1, -1)
var opened_pause := false         # True if opening this paused the game (so closing unpauses it).
var tool := Tool.DRAW
var selected := {}                # {"kind": "cell", "cell": Vector2i} | {"kind": "lever", "index": int} | {"kind": "sconce", "index": int} | {"kind": "start"}, or {}.
var message := ""                 # A short line shown where the hints are (why something was refused), for MESSAGE_SECONDS.
var message_left := 0.0
var tool_buttons: Array = []

var root: Control
var paper: Control
var new_dialog: PanelContainer
var width_box: SpinBox
var height_box: SpinBox
var _tiles := {}                  # cell size -> the cross-hatched wall square (ImageTexture).
var _frame_box := StyleBoxTexture.new()


func _ready() -> void:
	layer = 20  # Over the full-screen map (18) and the pause menu (19).
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP  # Nothing under the editor gets a click.
	root.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	root.draw.connect(_draw_root)
	add_child(root)
	paper = Control.new()
	paper.position = PAPER_RECT.position
	paper.size = PAPER_RECT.size
	paper.clip_contents = true
	paper.mouse_filter = Control.MOUSE_FILTER_STOP
	paper.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	paper.draw.connect(_draw_paper)
	paper.gui_input.connect(_paper_input)
	paper.mouse_exited.connect(_on_mouse_left)
	root.add_child(paper)
	_frame_box.texture = FRAME
	_frame_box.set_texture_margin_all(BORDER)
	_frame_box.draw_center = false
	_frame_box.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	_frame_box.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	_build_toolbar()
	_add_button("NEW", Vector2(488, 3), _show_new_dialog)
	_add_button("CLOSE", Vector2(560, 3), close)
	_build_new_dialog()
	_new_sheet(cfg.new_width, cfg.new_height)


# --------------------------------------------------------------------------
# Opening and closing
# --------------------------------------------------------------------------

func is_open() -> bool:
	return visible


func open() -> void:
	if visible:
		return
	opened_pause = false
	if get_tree().paused:
		return  # Another screen (inventory, pause menu, end screens) owns the pause: leave it be.
	var scene := get_tree().current_scene
	if scene != null and scene.scene_file_path.ends_with("main.tscn"):
		get_tree().paused = true  # In the game the world waits. (The main menu has nothing to pause.)
		opened_pause = true
	get_tree().call_group("party_hud", "cancel_casting")
	visible = true
	new_dialog.visible = false
	mode = 0
	_redraw()


func close() -> void:
	if not visible:
		return
	visible = false
	mode = 0
	new_dialog.visible = false
	if opened_pause:
		get_tree().paused = false
	opened_pause = false


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if event.keycode == KEY_F10:
		if visible:
			close()
		else:
			open()
		get_viewport().set_input_as_handled()
		return
	if not visible:
		return
	if event.keycode == KEY_ESCAPE:
		if new_dialog.visible:
			new_dialog.visible = false
		elif not selected.is_empty():
			selected = {}
			_redraw()
		else:
			close()
		get_viewport().set_input_as_handled()
	elif (event.keycode == KEY_DELETE or event.keycode == KEY_BACKSPACE) and not new_dialog.visible:
		delete_selected()
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_R and not event.ctrl_pressed and not new_dialog.visible:
		rotate_selected()
		get_viewport().set_input_as_handled()
	elif event.ctrl_pressed and event.keycode == KEY_Z:
		if event.shift_pressed:
			redo()
		else:
			undo()
		get_viewport().set_input_as_handled()
	elif event.ctrl_pressed and event.keycode == KEY_Y:
		redo()
		get_viewport().set_input_as_handled()


# --------------------------------------------------------------------------
# The sheet
# --------------------------------------------------------------------------

## Start a fresh sheet of solid rock, centred on the paper at the opening zoom.
func _new_sheet(w: int, h: int) -> void:
	w = clampi(w, cfg.min_size, cfg.max_size)
	h = clampi(h, cfg.min_size, cfg.max_size)
	grid.setup(w, h, cfg.undo_steps)
	zoom_index = clampi(cfg.start_zoom, 0, cfg.cell_sizes.size() - 1)
	cell_px = cfg.cell_sizes[zoom_index]
	hover = Vector2i(-1, -1)
	mode = 0
	selected = {}
	_centre()
	_redraw()


func _centre() -> void:
	origin = ((PAPER_RECT.size - Vector2(grid.width, grid.height) * cell_px) * 0.5).floor()
	_clamp_offset()


## Keep a good part of the grid on the paper (never lose it off the edge).
func _clamp_offset() -> void:
	var size := Vector2(grid.width, grid.height) * cell_px
	var keep := 48.0
	origin.x = clampf(origin.x, keep - size.x, PAPER_RECT.size.x - keep)
	origin.y = clampf(origin.y, keep - size.y, PAPER_RECT.size.y - keep)
	origin = origin.round()


func undo() -> void:
	if grid.undo():
		_redraw()


func redo() -> void:
	if grid.redo():
		_redraw()


func _redraw() -> void:
	_fix_selection()
	paper.queue_redraw()
	root.queue_redraw()
	for b in tool_buttons:
		b.queue_redraw()


## The square under a point of the paper (its own pixel coordinates), or (-1,-1) off the grid.
func cell_at(p: Vector2) -> Vector2i:
	var c := Vector2i(floori((p.x - origin.x) / cell_px), floori((p.y - origin.y) / cell_px))
	return c if grid.in_bounds(c.x, c.y) else Vector2i(-1, -1)


func _zoom(steps: int, about: Vector2) -> void:
	var next := clampi(zoom_index + steps, 0, cfg.cell_sizes.size() - 1)
	if next == zoom_index:
		return
	var world := (about - origin) / float(cell_px)  # The grid point under the mouse stays under it.
	zoom_index = next
	cell_px = cfg.cell_sizes[zoom_index]
	origin = about - world * cell_px
	_clamp_offset()
	_redraw()


# --------------------------------------------------------------------------
# Mouse
# --------------------------------------------------------------------------

func _paper_input(event: InputEvent) -> void:
	if new_dialog.visible:
		return
	if event is InputEventMouseButton:
		var p: Vector2 = event.position
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_zoom(1, p)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_zoom(-1, p)
		elif event.button_index == MOUSE_BUTTON_LEFT and tool != Tool.DRAW:
			if event.pressed:
				_use_tool(p)
		elif event.button_index == MOUSE_BUTTON_RIGHT and tool != Tool.DRAW:
			pass  # (Only the DRAW tool rubs with the right button; Delete removes a selected thing.)
		elif event.button_index == MOUSE_BUTTON_LEFT or event.button_index == MOUSE_BUTTON_RIGHT:
			if event.pressed:
				mode = 1 if event.button_index == MOUSE_BUTTON_LEFT else 2
				grid.begin_stroke()
				last_cell = cell_at(p)
				_stamp(last_cell, last_cell)
			elif mode == 1 or mode == 2:
				grid.end_stroke()
				mode = 0
				_redraw()
		elif event.button_index == MOUSE_BUTTON_MIDDLE:
			mode = 3 if event.pressed else 0
		hover = cell_at(p)
		root.queue_redraw()
		paper.queue_redraw()
	elif event is InputEventMouseMotion:
		var p2: Vector2 = event.position
		var now := cell_at(p2)
		if mode == 3:
			origin += event.relative
			_clamp_offset()
			_redraw()
		elif mode == 1 or mode == 2:
			_stamp(last_cell, now)
			last_cell = now
		if now != hover:
			hover = now
			_redraw()


## Paint or rub every square from `a` to `b` (a straight run, so a quick drag leaves no gaps).
func _stamp(a: Vector2i, b: Vector2i) -> void:
	if b.x < 0:
		return
	var from := a if a.x >= 0 else b
	if grid.line(from, b, mode == 1) > 0:
		_redraw()


func _on_mouse_left() -> void:
	hover = Vector2i(-1, -1)
	if mode == 1 or mode == 2:
		grid.end_stroke()
	mode = 0
	_redraw()


func _process(delta: float) -> void:
	if message_left > 0.0:
		message_left -= delta
		if message_left <= 0.0:
			message = ""
			root.queue_redraw()
	if not visible or new_dialog.visible:
		return
	var dir := Vector2.ZERO
	for key in PAN_KEYS:
		if Input.is_physical_key_pressed(key) and not Input.is_key_pressed(KEY_CTRL):
			dir += PAN_KEYS[key]
	if dir != Vector2.ZERO:
		origin += dir.normalized() * cfg.pan_speed * delta
		_clamp_offset()
		_redraw()


# --------------------------------------------------------------------------
# Drawing
# --------------------------------------------------------------------------

## One cross-hatched wall square at this size: bone paper darkened to a solid, two families of inked diagonals ("/" in ink, "\" in
## bone_700) on a 4 pixel spacing, so a block of walls reads as one hatched mass.
func _wall_tile(size: int) -> Texture2D:
	if _tiles.has(size):
		return _tiles[size]
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	image.fill(BONE_500)
	for y in size:
		for x in size:
			if (x + y) % 4 == 0:
				image.set_pixel(x, y, INK)
			elif posmod(x - y, 4) == 0:
				image.set_pixel(x, y, BONE_700)
	var tex := ImageTexture.create_from_image(image)
	_tiles[size] = tex
	return tex


## The stained paper at its own pixel size, mirrored across and down (a flipped copy meets the edge it came from, so no seams).
func _draw_parchment(rect: Rect2) -> void:
	var w := float(PARCHMENT.get_width())
	var h := float(PARCHMENT.get_height())
	for ty in ceili(rect.size.y / h):
		for tx in ceili(rect.size.x / w):
			var sx := -1.0 if tx % 2 == 1 else 1.0
			var sy := -1.0 if ty % 2 == 1 else 1.0
			var corner := Vector2(tx * w + (w if sx < 0.0 else 0.0), ty * h + (h if sy < 0.0 else 0.0))
			paper.draw_set_transform(corner, 0.0, Vector2(sx, sy))
			paper.draw_texture(PARCHMENT, Vector2.ZERO)
	paper.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_paper() -> void:
	var rect := Rect2(Vector2.ZERO, PAPER_RECT.size)
	_draw_parchment(rect)
	var first := Vector2i(maxi(0, floori(-origin.x / cell_px)), maxi(0, floori(-origin.y / cell_px)))
	var last := Vector2i(mini(grid.width, ceili((rect.size.x - origin.x) / cell_px)), mini(grid.height, ceili((rect.size.y - origin.y) / cell_px)))
	var tile := _wall_tile(cell_px)
	for y in range(first.y, last.y):
		for x in range(first.x, last.x):
			if grid.cells[y * grid.width + x] == 1:
				paper.draw_texture(tile, origin + Vector2(x, y) * cell_px)
	# The squared paper: one pixel ink lines on every square's edge.
	var top := origin.y + first.y * cell_px
	var bottom := origin.y + last.y * cell_px
	var left := origin.x + first.x * cell_px
	var right := origin.x + last.x * cell_px
	for x in range(first.x, last.x + 1):
		paper.draw_rect(Rect2(origin.x + x * cell_px, top, 1, bottom - top), BONE_700)
	for y in range(first.y, last.y + 1):
		paper.draw_rect(Rect2(left, origin.y + y * cell_px, right - left, 1), BONE_700)
	# The edge of the sheet, inked heavier.
	paper.draw_rect(Rect2(origin, Vector2(grid.width, grid.height) * cell_px), INK, false, 2.0)
	if hover.x >= 0:  # The square under the pen: a red ink outline.
		paper.draw_rect(Rect2(origin + Vector2(hover) * cell_px, Vector2(cell_px, cell_px)), BLOOD_500, false, 2.0)
	_draw_things()
	# Bottom right corner: which square (x,y) the pen is over.
	var font := paper.get_theme_default_font()
	var text := "(%d,%d)" % [hover.x, hover.y] if hover.x >= 0 else "(-,-)"
	var tsize := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8)
	var box := Rect2(rect.size.x - tsize.x - 14, rect.size.y - 18, tsize.x + 10, 14)
	paper.draw_rect(box, STONE_900)
	paper.draw_rect(box, RUST_500, false, 1.0)
	paper.draw_string(font, Vector2(box.position.x + 5, box.position.y + 10), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, BONE_300)


func _draw_root() -> void:
	root.draw_rect(Rect2(0, 0, 640, 360), INK)
	_frame_box.draw(root.get_canvas_item(), FRAME_RECT)
	var font := root.get_theme_default_font()
	root.draw_string(font, Vector2(14, 15), "DUNGEON EDITOR", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, BONE_300)
	root.draw_string(font, Vector2(148, 15), "%dx%d  %d FLOOR" % [grid.width, grid.height, grid.floor_count()], HORIZONTAL_ALIGNMENT_LEFT, -1, 8, BONE_500)
	root.draw_string(font, Vector2(300, 15), "TOOL: " + TOOL_NAMES[tool], HORIZONTAL_ALIGNMENT_LEFT, -1, 8, BONE_300)
	if message != "":
		root.draw_string(font, Vector2(14, 352), message, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color("a8673a"))
	else:
		root.draw_string(font, Vector2(14, 352), "DEL: REMOVE  R: TURN  MID/WASD: PAN  WHEEL: ZOOM  CTRL+Z/Y: UNDO  F10: CLOSE", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, BONE_700)


# --------------------------------------------------------------------------
# Buttons and the New dialog
# --------------------------------------------------------------------------

func _style(fill: Color, edge: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = edge
	box.set_border_width_all(2)
	box.content_margin_left = 4
	box.content_margin_right = 4
	box.content_margin_top = 0
	box.content_margin_bottom = 0
	return box


func _skin(b: Button) -> void:
	b.add_theme_stylebox_override("normal", _style(STONE_900, RUST_500))
	b.add_theme_stylebox_override("hover", _style(STONE_700, BONE_500))
	b.add_theme_stylebox_override("pressed", _style(RUST_700, BONE_300))
	b.add_theme_stylebox_override("focus", _style(STONE_900, BONE_500))
	b.add_theme_color_override("font_color", BONE_300)
	b.add_theme_color_override("font_hover_color", BONE_300)
	b.add_theme_color_override("font_pressed_color", BONE_300)
	b.add_theme_font_size_override("font_size", 8)
	b.focus_mode = Control.FOCUS_NONE  # (Keys like WASD must never move a button's focus.)


func _add_button(text: String, at: Vector2, on_press: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.clip_text = true
	b.custom_minimum_size = Vector2(64, 16)
	_skin(b)
	b.pressed.connect(on_press)
	root.add_child(b)
	b.position = at
	b.size = Vector2(64, 16)
	return b


func _build_new_dialog() -> void:
	new_dialog = PanelContainer.new()
	new_dialog.add_theme_stylebox_override("panel", _style(STONE_900, RUST_500))
	new_dialog.visible = false
	new_dialog.mouse_filter = Control.MOUSE_FILTER_STOP
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	new_dialog.add_child(box)
	var title := Label.new()
	title.text = "NEW DUNGEON"
	title.add_theme_font_size_override("font_size", 8)
	title.add_theme_color_override("font_color", BONE_300)
	box.add_child(title)
	width_box = _spin_row(box, "WIDTH", cfg.new_width)
	height_box = _spin_row(box, "HEIGHT", cfg.new_height)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	box.add_child(row)
	for spec in [["CREATE", _create_new], ["CANCEL", _hide_new_dialog]]:
		var b := Button.new()
		b.text = spec[0]
		b.custom_minimum_size = Vector2(64, 16)
		_skin(b)
		b.pressed.connect(spec[1])
		row.add_child(b)
	root.add_child(new_dialog)
	new_dialog.position = Vector2(230, 120)


func _spin_row(parent: Control, label: String, value: int) -> SpinBox:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	parent.add_child(row)
	var l := Label.new()
	l.text = label
	l.custom_minimum_size = Vector2(56, 0)
	l.add_theme_font_size_override("font_size", 8)
	l.add_theme_color_override("font_color", BONE_500)
	row.add_child(l)
	var spin := SpinBox.new()
	spin.min_value = cfg.min_size
	spin.max_value = cfg.max_size
	spin.value = value
	spin.step = 1
	spin.custom_minimum_size = Vector2(88, 0)
	spin.get_line_edit().add_theme_font_size_override("font_size", 8)
	row.add_child(spin)
	return spin


func _show_new_dialog() -> void:
	width_box.value = grid.width
	height_box.value = grid.height
	new_dialog.visible = true


func _hide_new_dialog() -> void:
	new_dialog.visible = false


func _create_new() -> void:
	new_dialog.visible = false
	_new_sheet(int(width_box.value), int(height_box.value))


# --------------------------------------------------------------------------
# The toolbar and the tools (E.2)
# --------------------------------------------------------------------------

func _build_toolbar() -> void:
	for i in TOOL_ORDER.size():
		var t: int = TOOL_ORDER[i]
		var b := Control.new()
		b.position = Vector2(12 + i * 30, TOOLBAR_Y)
		b.size = Vector2(28, 20)
		b.custom_minimum_size = b.size
		b.mouse_filter = Control.MOUSE_FILTER_STOP
		b.tooltip_text = TOOL_NAMES[t]
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		b.draw.connect(_draw_tool_button.bind(b, t))
		b.gui_input.connect(_tool_button_input.bind(t))
		root.add_child(b)
		tool_buttons.append(b)


func _tool_button_input(event: InputEvent, t: int) -> void:
	if new_dialog.visible:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		set_tool(t)


func set_tool(t: int) -> void:
	tool = t
	_redraw()


func _draw_tool_button(b: Control, t: int) -> void:
	var on := tool == t
	b.draw_rect(Rect2(Vector2.ZERO, b.size), STONE_700 if on else STONE_900)
	b.draw_rect(Rect2(Vector2.ZERO, b.size), BONE_300 if on else RUST_500, false, 2.0)
	_icon(b, _tool_icon(t), Rect2(6, 2, 16, 16), 0, 3)


func _tool_icon(t: int) -> String:
	match t:
		Tool.DRAW:
			return "draw"
		Tool.SELECT:
			return "select"
		Tool.DOOR:
			return "door"
		Tool.LOCKED:
			return "locked"
		Tool.GATE:
			return "gate"
		Tool.CRACKED:
			return "cracked"
		Tool.LEVER:
			return "lever"
		Tool.STAIRS:
			return "stairs"
		Tool.START:
			return "start"
		Tool.SCONCE_LIT:
			return "sconce_lit"
		Tool.SCONCE_UNLIT:
			return "sconce_unlit"
	return "sconce_empty"


func _say(text: String) -> void:
	message = text
	message_left = MESSAGE_SECONDS
	root.queue_redraw()


## A click on the paper with a thing tool: place, select or link.
func _use_tool(p: Vector2) -> void:
	var cell := cell_at(p)
	if tool == Tool.SELECT or tool == Tool.LEVER:
		if _link_click(p, cell):
			return
	match tool:
		Tool.SELECT:
			_select_at(p)
		Tool.DOOR, Tool.LOCKED, Tool.GATE:
			if cell.x < 0:
				return
			var kind: int = EditorGrid.DOOR if tool == Tool.DOOR else (EditorGrid.LOCKED if tool == Tool.LOCKED else EditorGrid.GATE)
			_done(grid.place_door(cell.x, cell.y, kind), {"kind": "cell", "cell": cell})
		Tool.CRACKED:
			if cell.x >= 0:
				_done(grid.place_cracked(cell.x, cell.y), {"kind": "cell", "cell": cell})
		Tool.STAIRS:
			if cell.x >= 0:
				_done(grid.place_stairs(cell.x, cell.y), {"kind": "cell", "cell": cell})
		Tool.START:
			if cell.x >= 0:
				_done(grid.place_start(cell.x, cell.y), {"kind": "start"})
		Tool.LEVER:
			var face := _face_at(p)
			if not face.is_empty():
				_done(grid.place_lever(face.cell.x, face.cell.y, face.side), {"kind": "lever", "index": grid.levers.size() - 1})
		Tool.SCONCE_LIT, Tool.SCONCE_UNLIT, Tool.SCONCE_EMPTY:
			var side_face := _face_at(p)
			if not side_face.is_empty():
				var state: int = EditorGrid.SCONCE_LIT if tool == Tool.SCONCE_LIT else (EditorGrid.SCONCE_UNLIT if tool == Tool.SCONCE_UNLIT else EditorGrid.SCONCE_EMPTY)
				_done(grid.place_sconce(side_face.cell.x, side_face.cell.y, side_face.side, state), {"kind": "sconce", "index": grid.sconces.size() - 1})
	_redraw()


## A placement's outcome: "" selects what was placed, anything else is the reason it was refused.
func _done(reason: String, pick: Dictionary) -> void:
	if reason == "":
		selected = pick
		get_tree().call_group("audio", "play", "drop")
	else:
		_say(reason)


## The wall face under a point: {"cell": the floor square, "side": the wall's side}, or {} (with a message) if the point is not near
## the edge of a square that has a wall on that side. Clicking the wall square's own edge, from the wall side, works too.
func _face_at(p: Vector2) -> Dictionary:
	var cell := cell_at(p)
	if cell.x < 0:
		return {}
	var local := (p - origin) / float(cell_px) - Vector2(cell)
	var edges := [local.y, local.x, 1.0 - local.y, 1.0 - local.x]  # Distance to the north, west, south and east edges.
	var side := 0
	for i in 4:
		if edges[i] < edges[side]:
			side = i
	if edges[side] > 0.4:
		_say("CLICK NEAR THE EDGE OF A SQUARE")
		return {}
	var t := grid.type_at(cell.x, cell.y)
	if grid.is_wall_type(t):  # From the wall's side: the face belongs to the floor square across that edge.
		var across: Vector2i = cell + EditorGrid.DIRS[side]
		if grid.type_at(across.x, across.y) != EditorGrid.FLOOR:
			_say("THAT SIDE IS NOT A WALL FACE")
			return {}
		return {"cell": across, "side": (side + 2) % 4}
	return {"cell": cell, "side": side}


## Where a lever or sconce's icon sits on the paper (just inside its floor square, towards its wall).
func _face_pos(cell: Vector2i, side: int) -> Vector2:
	return origin + (Vector2(cell) + Vector2(0.5, 0.5) + Vector2(EditorGrid.DIRS[side]) * 0.36) * cell_px


func _cell_centre(cell: Vector2i) -> Vector2:
	return origin + (Vector2(cell) + Vector2(0.5, 0.5)) * cell_px


## With a lever selected, a click on a door or gate links them (again: unlinks); with a door selected, a click on a lever does.
func _link_click(p: Vector2, cell: Vector2i) -> bool:
	if selected.get("kind") == "lever" and cell.x >= 0 and grid.is_door_type(grid.type_at(cell.x, cell.y)):
		var why := grid.link_lever(int(selected.index), cell)
		if why != "":
			_say(why)
		_redraw()
		return true
	if selected.get("kind") == "cell" and grid.is_door_type(grid.type_at(selected.cell.x, selected.cell.y)):
		var lever := _lever_near(p)
		if lever >= 0:
			var why2 := grid.link_lever(lever, selected.cell)
			if why2 != "":
				_say(why2)
			_redraw()
			return true
	return false


func _lever_near(p: Vector2) -> int:
	var best := -1
	var best_d := maxf(8.0, cell_px * 0.45)
	for i in grid.levers.size():
		var d := _face_pos(grid.levers[i].cell, grid.levers[i].side).distance_to(p)
		if d < best_d:
			best_d = d
			best = i
	return best


## Select what is under a point: a lever or sconce icon first, then a door, stairs or cracked wall, then the start.
func _select_at(p: Vector2) -> void:
	var reach := maxf(8.0, cell_px * 0.45)
	var best := {}
	var best_d := reach
	for i in grid.levers.size():
		var d := _face_pos(grid.levers[i].cell, grid.levers[i].side).distance_to(p)
		if d < best_d:
			best_d = d
			best = {"kind": "lever", "index": i}
	for i in grid.sconces.size():
		var d2 := _face_pos(grid.sconces[i].cell, grid.sconces[i].side).distance_to(p)
		if d2 < best_d:
			best_d = d2
			best = {"kind": "sconce", "index": i}
	if best.is_empty():
		var cell := cell_at(p)
		if cell.x >= 0:
			var t := grid.type_at(cell.x, cell.y)
			if grid.is_door_type(t) or t == EditorGrid.STAIRS or t == EditorGrid.CRACKED:
				best = {"kind": "cell", "cell": cell}
			elif not grid.start.is_empty() and grid.start.cell == cell:
				best = {"kind": "start"}
	selected = best


func delete_selected() -> void:
	match selected.get("kind", ""):
		"cell":
			var why := grid.delete_cell_thing(selected.cell.x, selected.cell.y)
			if why != "":
				_say(why)
		"lever":
			grid.delete_lever(int(selected.index))
		"sconce":
			grid.delete_sconce(int(selected.index))
		"start":
			grid.clear_start()
		_:
			_say("SELECT SOMETHING FIRST")
			return
	selected = {}
	_redraw()


func rotate_selected() -> void:
	match selected.get("kind", ""):
		"start":
			grid.rotate_start()
		"lever":
			var why := grid.rotate_face(true, int(selected.index))
			if why != "":
				_say(why)
		"sconce":
			var why2 := grid.rotate_face(false, int(selected.index))
			if why2 != "":
				_say(why2)
		"cell":
			_say("THAT ONE DOES NOT TURN")
		_:
			_say("SELECT SOMETHING FIRST")
			return
	_redraw()


## A selection that no longer points at anything (after an undo, a deletion or a cleanup) is dropped.
func _fix_selection() -> void:
	match selected.get("kind", ""):
		"cell":
			var t := grid.type_at(selected.cell.x, selected.cell.y)
			if not (grid.is_door_type(t) or t == EditorGrid.STAIRS or t == EditorGrid.CRACKED):
				selected = {}
		"lever":
			if int(selected.index) >= grid.levers.size():
				selected = {}
		"sconce":
			if int(selected.index) >= grid.sconces.size():
				selected = {}
		"start":
			if grid.start.is_empty():
				selected = {}


# --------------------------------------------------------------------------
# Drawing the things
# --------------------------------------------------------------------------

func _draw_things() -> void:
	var c := float(cell_px)
	for y in grid.height:  # (Only the squares on the paper.)
		if origin.y + (y + 1) * c < 0.0 or origin.y + y * c > PAPER_RECT.size.y:
			continue
		for x in grid.width:
			if origin.x + (x + 1) * c < 0.0 or origin.x + x * c > PAPER_RECT.size.x:
				continue
			var t := grid.type_at(x, y)
			if t < EditorGrid.DOOR:
				continue
			var r := Rect2(origin + Vector2(x, y) * c, Vector2(c, c)).grow(-1.0)
			var kind: String = {EditorGrid.DOOR: "door", EditorGrid.LOCKED: "locked", EditorGrid.GATE: "gate", EditorGrid.STAIRS: "stairs", EditorGrid.CRACKED: "cracked"}[t]
			var axis := 0 if grid.is_wall_type(grid.type_at(x - 1, y)) and grid.is_wall_type(grid.type_at(x + 1, y)) else 1
			_icon(paper, kind, r, axis, 3)
	if not grid.start.is_empty():
		_icon(paper, "start", Rect2(origin + Vector2(grid.start.cell) * c, Vector2(c, c)).grow(-2.0), 0, int(grid.start.facing))
	for l in grid.levers:
		var lp := _face_pos(l.cell, l.side)
		_icon(paper, "lever", Rect2(lp - Vector2(c, c) * 0.3, Vector2(c, c) * 0.6), 0, 3)
	for sc in grid.sconces:
		var sp := _face_pos(sc.cell, sc.side)
		var skind: String = ["sconce_lit", "sconce_unlit", "sconce_empty"][int(sc.state)]
		_icon(paper, skind, Rect2(sp - Vector2(c, c) * 0.3, Vector2(c, c) * 0.6), 0, 3)
	_draw_links()
	_draw_selection()


## A thin ink line joins a selected lever to its door, or a selected door to every lever that works it.
func _draw_links() -> void:
	var kind: String = selected.get("kind", "")
	if kind == "lever":
		var l: Dictionary = grid.levers[int(selected.index)]
		for cell in grid.door_ids:
			if grid.door_ids[cell] == l.target:
				paper.draw_line(_face_pos(l.cell, l.side), _cell_centre(cell), INK, 1.0)
	elif kind == "cell":
		var id := grid.door_id_of(selected.cell)
		if id != "":
			for l2 in grid.levers:
				if l2.target == id:
					paper.draw_line(_face_pos(l2.cell, l2.side), _cell_centre(selected.cell), INK, 1.0)


func _draw_selection() -> void:
	var c := float(cell_px)
	var r := Rect2()
	match selected.get("kind", ""):
		"cell":
			r = Rect2(origin + Vector2(selected.cell) * c, Vector2(c, c))
		"start":
			r = Rect2(origin + Vector2(grid.start.cell) * c, Vector2(c, c))
		"lever":
			var l: Dictionary = grid.levers[int(selected.index)]
			r = Rect2(_face_pos(l.cell, l.side) - Vector2(c, c) * 0.4, Vector2(c, c) * 0.8)
		"sconce":
			var sc: Dictionary = grid.sconces[int(selected.index)]
			r = Rect2(_face_pos(sc.cell, sc.side) - Vector2(c, c) * 0.4, Vector2(c, c) * 0.8)
		_:
			return
	paper.draw_rect(r, BLOOD_500, false, 2.0)


## One inked icon in the 16 unit box of `r` (`axis` 0: a door in a corridor that runs north to south, 1: east to west; `facing` for the
## start's arrow: 0 north, 1 west, 2 south, 3 east). Placeholder art, drawn in code (docs/asset_log.md).
func _icon(ci: CanvasItem, kind: String, r: Rect2, axis: int, facing: int) -> void:
	var s := r.size.x / 16.0
	var o := r.position
	var w := maxf(1.0, roundf(s))
	match kind:
		"door", "locked":
			var leaf := Rect2(o + Vector2(1, 6) * s, Vector2(14, 4) * s) if axis == 0 else Rect2(o + Vector2(6, 1) * s, Vector2(4, 14) * s)
			ci.draw_rect(leaf, LEATHER_400)
			ci.draw_rect(leaf, INK, false, w)
			if kind == "locked":
				var lock := Rect2(o + Vector2(6, 5) * s, Vector2(4, 6) * s)
				ci.draw_rect(lock, BLOOD_500)
				ci.draw_rect(lock, INK, false, w)
			else:
				ci.draw_rect(Rect2(o + Vector2(11, 7) * s, Vector2(2, 2) * s), BONE_300)
		"gate":
			if axis == 0:
				ci.draw_line(o + Vector2(1, 5) * s, o + Vector2(15, 5) * s, INK, w)
				ci.draw_line(o + Vector2(1, 11) * s, o + Vector2(15, 11) * s, INK, w)
				for bx in [3, 6, 9, 12]:
					ci.draw_line(o + Vector2(bx, 3) * s, o + Vector2(bx, 13) * s, STONE_300, w)
			else:
				ci.draw_line(o + Vector2(5, 1) * s, o + Vector2(5, 15) * s, INK, w)
				ci.draw_line(o + Vector2(11, 1) * s, o + Vector2(11, 15) * s, INK, w)
				for by in [3, 6, 9, 12]:
					ci.draw_line(o + Vector2(3, by) * s, o + Vector2(13, by) * s, STONE_300, w)
		"cracked":
			var wall := Rect2(o + Vector2(1, 1) * s, Vector2(14, 14) * s)
			ci.draw_rect(wall, BONE_500)
			ci.draw_rect(wall, INK, false, w)
			ci.draw_polyline(PackedVector2Array([o + Vector2(9, 1) * s, o + Vector2(6, 6) * s, o + Vector2(10, 9) * s, o + Vector2(7, 15) * s]), INK, w)
		"stairs":
			for step in [[2.0, 2.0, 12.0, 4.0], [2.0, 7.0, 9.0, 4.0], [2.0, 12.0, 6.0, 3.0]]:
				var sr := Rect2(o + Vector2(step[0], step[1]) * s, Vector2(step[2], step[3]) * s)
				ci.draw_rect(sr, STONE_500)
				ci.draw_rect(sr, INK, false, w)
		"start":
			var tri: Array = [[Vector2(8, 1), Vector2(2, 14), Vector2(14, 14)], [Vector2(1, 8), Vector2(14, 2), Vector2(14, 14)],
					[Vector2(8, 15), Vector2(2, 2), Vector2(14, 2)], [Vector2(15, 8), Vector2(2, 2), Vector2(2, 14)]][facing]
			var pts := PackedVector2Array([o + tri[0] * s, o + tri[1] * s, o + tri[2] * s])
			ci.draw_colored_polygon(pts, BLOOD_500)
			ci.draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[0]]), INK, w)
		"lever":
			var plate := Rect2(o + Vector2(2, 11) * s, Vector2(12, 3) * s)
			ci.draw_rect(plate, STONE_500)
			ci.draw_rect(plate, INK, false, w)
			ci.draw_line(o + Vector2(8, 11) * s, o + Vector2(12, 4) * s, INK, maxf(1.0, w * 1.5))
			ci.draw_rect(Rect2(o + Vector2(11, 2) * s, Vector2(3, 3) * s), BLOOD_500)
		"sconce_lit", "sconce_unlit", "sconce_empty":
			var bracket := Rect2(o + Vector2(5, 11) * s, Vector2(6, 3) * s)
			ci.draw_rect(bracket, STONE_500)
			ci.draw_rect(bracket, INK, false, w)
			if kind != "sconce_empty":
				var stick := Rect2(o + Vector2(7, 5) * s, Vector2(2, 6) * s)
				ci.draw_rect(stick, WOOD_500)
				ci.draw_rect(stick, INK, false, w)
				if kind == "sconce_lit":
					ci.draw_colored_polygon(PackedVector2Array([o + Vector2(8, 0) * s, o + Vector2(5, 5) * s, o + Vector2(11, 5) * s]), TORCH_500)
					ci.draw_colored_polygon(PackedVector2Array([o + Vector2(8, 2) * s, o + Vector2(7, 5) * s, o + Vector2(9, 5) * s]), TORCH_300)
				else:
					ci.draw_rect(Rect2(o + Vector2(7, 4) * s, Vector2(2, 2) * s), INK)
		"select":
			var arrow := PackedVector2Array([o + Vector2(3, 2) * s, o + Vector2(3, 13) * s, o + Vector2(6, 10) * s, o + Vector2(9, 15) * s, o + Vector2(11, 14) * s, o + Vector2(8, 9) * s, o + Vector2(12, 9) * s])
			ci.draw_colored_polygon(arrow, STONE_100)
			ci.draw_polyline(PackedVector2Array([arrow[0], arrow[1], arrow[2], arrow[3], arrow[4], arrow[5], arrow[6], arrow[0]]), INK, w)
		"draw":
			ci.draw_rect(Rect2(o + Vector2(1, 8) * s, Vector2(7, 7) * s), BONE_300)
			ci.draw_rect(Rect2(o + Vector2(8, 8) * s, Vector2(7, 7) * s), BONE_500)
			ci.draw_rect(Rect2(o + Vector2(1, 8) * s, Vector2(14, 7) * s), INK, false, w)
			ci.draw_line(o + Vector2(3, 6) * s, o + Vector2(12, 1) * s, INK, maxf(1.0, w * 1.5))
			ci.draw_rect(Rect2(o + Vector2(2, 5) * s, Vector2(2, 2) * s), BLOOD_500)
