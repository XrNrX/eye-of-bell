extends SceneTree
## The dungeon editor (roadmap E.1; scripts/debug/dungeon_editor.gd, editor_grid.gd). Run:
##   timeout 120 "$G" --headless --path . -s tests/editor_test.gd      (exits non-zero on any failure)
## The paper as data (strokes, undo and redo, the outer edge), then the editor itself driven through real input routing
## (root.push_input with screen positions, not calls to its handlers): paint, drag, rub, zoom, pan, undo keys, F10, New.

const EditorGrid := preload("res://scripts/debug/editor_grid.gd")
const EditorConfig := preload("res://scripts/debug/editor_config.gd")
const DungeonEditor := preload("res://scripts/debug/dungeon_editor.gd")
var fails := 0


func check(name: String, ok: bool) -> void:
	print(("PASS " if ok else "FAIL ") + name)
	if not ok:
		fails += 1


func _init() -> void:
	_check_grid()
	await _check_editor()
	print("DONE fails=", fails)
	quit(fails)


func _check_grid() -> void:
	var cfg: Resource = EditorConfig.get_config()
	check("a new dungeon is 32x32 by default, set in the config", cfg.new_width == 32 and cfg.new_height == 32)
	check("the undo depth in the config is at least 50", cfg.undo_steps >= 50)
	var g := EditorGrid.new()
	g.setup(10, 8, 100)
	check("a fresh sheet is all wall", g.width == 10 and g.height == 8 and g.floor_count() == 0 and not g.is_floor(3, 3))
	check("painting floor changes a square", g.set_cell(3, 3, true) and g.is_floor(3, 3) and g.floor_count() == 1)
	check("painting the same again changes nothing", not g.set_cell(3, 3, true))
	var edge_ok := true
	for x in 10:
		edge_ok = edge_ok and not g.set_cell(x, 0, true) and not g.set_cell(x, 7, true)
	for y in 8:
		edge_ok = edge_ok and not g.set_cell(0, y, true) and not g.set_cell(9, y, true)
	check("the outer edge always stays wall", edge_ok and not g.set_cell(-1, 3, true) and not g.set_cell(3, 99, true) and g.floor_count() == 1)
	check("a square rubs back to wall", g.set_cell(3, 3, false) and not g.is_floor(3, 3))
	# A stroke is undone and redone whole.
	g.setup(12, 12, 100)
	g.begin_stroke()
	var n := g.line(Vector2i(2, 2), Vector2i(9, 2), true)
	g.end_stroke()
	check("a line paints every square along it (8 across)", n == 8 and g.floor_count() == 8)
	g.begin_stroke()
	var diag := g.line(Vector2i(2, 4), Vector2i(8, 9), true)
	g.end_stroke()
	check("a diagonal line has no gaps (6 columns, so at least 6 squares)", diag >= 6 and g.floor_count() == 8 + diag)
	check("undo takes the last stroke back whole", g.undo() and g.floor_count() == 8)
	check("and the one before", g.undo() and g.floor_count() == 0 and not g.can_undo())
	check("redo puts them back", g.redo() and g.floor_count() == 8 and g.redo() and g.floor_count() == 8 + diag and not g.can_redo())
	g.undo()
	g.set_cell(5, 5, true)
	check("a new stroke clears what could have been redone", not g.can_redo())
	# Depth.
	g.setup(40, 40, 100)
	for i in 120:
		g.begin_stroke()
		g.set_cell(1 + i % 38, 1 + i / 38, true)
		g.end_stroke()
	check("it keeps the last 100 strokes (at least 50)", g.undo_depth() == 100)
	var undone := 0
	while g.undo():
		undone += 1
	check("and takes back exactly those 100, not the 20 before", undone == 100 and g.floor_count() == 20)
	var twice := EditorGrid.new()
	twice.setup(10, 10, 100)
	twice.begin_stroke()
	twice.set_cell(4, 4, true)
	twice.set_cell(4, 4, false)
	twice.set_cell(4, 4, true)
	twice.end_stroke()
	twice.undo()
	check("a square changed three times in one stroke is undone to how it began", not twice.is_floor(4, 4))


func _press(pos: Vector2, button: int, pressed: bool) -> void:
	var e := InputEventMouseButton.new()
	e.position = pos
	e.global_position = pos
	e.button_index = button
	e.pressed = pressed
	root.push_input(e, true)


func _move(pos: Vector2, relative := Vector2.ZERO, mask := 0) -> void:
	var e := InputEventMouseMotion.new()
	e.position = pos
	e.global_position = pos
	e.relative = relative
	e.button_mask = mask
	root.push_input(e, true)


func _key(code: int, ctrl := false, shift := false) -> void:
	var e := InputEventKey.new()
	e.keycode = code
	e.physical_keycode = code
	e.pressed = true
	e.ctrl_pressed = ctrl
	e.shift_pressed = shift
	root.push_input(e, false)


## The screen position of a square's middle, from the editor's own view.
func _centre_of(ed: Node, x: int, y: int) -> Vector2:
	return DungeonEditor.PAPER_RECT.position + ed.origin + (Vector2(x, y) + Vector2(0.5, 0.5)) * ed.cell_px


func _check_editor() -> void:
	var ed: Node = DungeonEditor.new()
	root.add_child(ed)
	await process_frame
	check("the editor starts closed", not ed.is_open())
	_key(KEY_F10)
	await process_frame
	check("F10 opens it", ed.is_open())
	check("it opens on a 32x32 sheet of rock, at the 16 pixel zoom", ed.grid.width == 32 and ed.grid.height == 32 and ed.cell_px == 16 and ed.grid.floor_count() == 0)
	# The square under the mouse is the (x,y) the roadmap uses.
	_move(_centre_of(ed, 17, 21))
	await process_frame
	check("the square under the mouse is (17,21)", ed.hover == Vector2i(17, 21))
	# Left click paints floor.
	_press(_centre_of(ed, 15, 15), MOUSE_BUTTON_LEFT, true)
	_press(_centre_of(ed, 15, 15), MOUSE_BUTTON_LEFT, false)
	check("a left click paints floor", ed.grid.is_floor(15, 15) and ed.grid.floor_count() == 1)
	# Left drag paints a run (the mouse jumps three squares at once: no gaps).
	_press(_centre_of(ed, 16, 15), MOUSE_BUTTON_LEFT, true)
	_move(_centre_of(ed, 19, 15), Vector2(48, 0), MOUSE_BUTTON_MASK_LEFT)
	_move(_centre_of(ed, 19, 18), Vector2(0, 48), MOUSE_BUTTON_MASK_LEFT)
	_press(_centre_of(ed, 19, 18), MOUSE_BUTTON_LEFT, false)
	var run_ok := true
	for x in range(15, 20):
		run_ok = run_ok and ed.grid.is_floor(x, 15)
	for y in range(15, 19):
		run_ok = run_ok and ed.grid.is_floor(19, y)
	check("a drag paints a run with no gaps (an L of floor)", run_ok and ed.grid.floor_count() == 5 + 3)
	# Right click rubs a square back to wall, and a right drag rubs a run.
	_press(_centre_of(ed, 15, 15), MOUSE_BUTTON_RIGHT, true)
	_press(_centre_of(ed, 15, 15), MOUSE_BUTTON_RIGHT, false)
	check("a right click rubs a square back to wall", not ed.grid.is_floor(15, 15))
	_press(_centre_of(ed, 19, 15), MOUSE_BUTTON_RIGHT, true)
	_move(_centre_of(ed, 19, 18), Vector2(0, 48), MOUSE_BUTTON_MASK_RIGHT)
	_press(_centre_of(ed, 19, 18), MOUSE_BUTTON_RIGHT, false)
	check("a right drag rubs a run", not ed.grid.is_floor(19, 16) and not ed.grid.is_floor(19, 18) and ed.grid.is_floor(18, 15))
	# The edge stays wall even when painted over (pan so the corner shows).
	ed.origin = Vector2(40, 40)
	_press(_centre_of(ed, 0, 0), MOUSE_BUTTON_LEFT, true)
	_move(_centre_of(ed, 3, 0), Vector2(48, 0), MOUSE_BUTTON_MASK_LEFT)
	_press(_centre_of(ed, 3, 0), MOUSE_BUTTON_LEFT, false)
	check("painting along the outer edge does nothing", not ed.grid.is_floor(0, 0) and not ed.grid.is_floor(2, 0))
	# Undo and redo through the keys.
	var floors: int = ed.grid.floor_count()
	_key(KEY_Z, true)
	check("Ctrl+Z undoes a stroke", ed.grid.floor_count() != floors)
	_key(KEY_Y, true)
	check("Ctrl+Y redoes it", ed.grid.floor_count() == floors)
	_key(KEY_Z, true)
	_key(KEY_Z, true, true)
	check("Ctrl+Shift+Z redoes too", ed.grid.floor_count() == floors)
	# Zoom with the wheel about the mouse.
	ed.origin = Vector2(40, 40)
	var under := _centre_of(ed, 8, 8)
	var cell_before: Vector2i = ed.cell_at(under - DungeonEditor.PAPER_RECT.position)
	_press(under, MOUSE_BUTTON_WHEEL_UP, true)
	check("the wheel zooms in a step (16 to 20 pixels)", ed.cell_px == 20)
	check("and the square under the mouse stays under it", ed.cell_at(under - DungeonEditor.PAPER_RECT.position) == cell_before)
	_press(under, MOUSE_BUTTON_WHEEL_DOWN, true)
	_press(under, MOUSE_BUTTON_WHEEL_DOWN, true)
	_press(under, MOUSE_BUTTON_WHEEL_DOWN, true)
	_press(under, MOUSE_BUTTON_WHEEL_DOWN, true)
	check("zoom stops at the smallest square (8 pixels)", ed.cell_px == 8)
	# Pan with the middle mouse.
	var o0: Vector2 = ed.origin
	_press(under, MOUSE_BUTTON_MIDDLE, true)
	_move(under + Vector2(30, 10), Vector2(30, 10), MOUSE_BUTTON_MASK_MIDDLE)
	_press(under + Vector2(30, 10), MOUSE_BUTTON_MIDDLE, false)
	check("the middle mouse drag pans the paper", ed.origin == (o0 + Vector2(30, 10)).round() or ed.origin.x > o0.x)
	# The squares are still where the mouse says after all that.
	_move(_centre_of(ed, 4, 4))
	check("coordinates follow the pan and the zoom", ed.hover == Vector2i(4, 4))
	# New: asks for a size and starts a fresh sheet.
	ed._show_new_dialog()
	check("New opens the size dialog, starting from the current size", ed.new_dialog.visible and int(ed.width_box.value) == 32)
	ed.width_box.value = 20
	ed.height_box.value = 12
	ed._create_new()
	check("Create makes a fresh 20x12 sheet of rock (undo history gone)", ed.grid.width == 20 and ed.grid.height == 12 and ed.grid.floor_count() == 0 and not ed.grid.can_undo() and not ed.new_dialog.visible)
	ed.width_box.value = 3
	check("the spin boxes keep to the configured limits (8 to 128)", ed.width_box.value == 8)
	# Close.
	_key(KEY_F10)
	check("F10 closes it", not ed.is_open())
	_key(KEY_F10)
	_key(KEY_ESCAPE)
	check("Escape closes it too", not ed.is_open())
	ed.open()
	ed.close()
	check("the Close button's close() leaves it closed", not ed.is_open())
	# It will not open over a screen that owns the pause.
	paused = true
	ed.open()
	check("it will not open while another screen owns the pause", not ed.is_open())
	paused = false
	ed.queue_free()
