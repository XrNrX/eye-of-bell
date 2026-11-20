extends CanvasLayer
## The dungeon editor (roadmap E.1, "Squared paper and drawing"): F10 opens it from the main menu and from the game (debug builds
## only; it lives in scripts/debug, which a release export leaves out), F10 or Close or Escape leaves it. A sheet of squared paper on
## stained parchment in the iron frame of the M map: each square is wall (filled and cross-hatched, solid rock) or floor (blank).
##
## Left click or drag paints floor, right click or drag rubs it back to wall (the outer edge always stays wall); the middle mouse
## drag or W A S D pans, the wheel zooms (about the square under the mouse), and the square under the mouse is shown bottom right as
## (x,y), the same coordinates floor 1's data and the roadmap use (x across, y down, from the top left square (0,0)). Ctrl+Z undoes
## and Ctrl+Y (or Ctrl+Shift+Z) redoes a whole stroke, at least 50 deep (editor_config.gd undo_steps). New asks for a width and a
## height and starts a fresh sheet; Close leaves. Nothing is saved yet (E.4 builds a level from it). In the game it pauses the world
## while open (and will not open over another screen that owns the pause).
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

const FRAME_RECT := Rect2(8, 22, 624, 318)   # The iron frame round the paper.
const BORDER := 4                            # Its thickness (map_frame.png).
const PAPER_RECT := Rect2(12, 26, 616, 310)  # The squared paper: the frame's inside.
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
		else:
			close()
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
	paper.queue_redraw()
	root.queue_redraw()


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
	root.draw_string(font, Vector2(14, 352), "L: FLOOR  R: WALL  MID/WASD: PAN  WHEEL: ZOOM  CTRL+Z/Y: UNDO  F10: CLOSE", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, BONE_700)


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
