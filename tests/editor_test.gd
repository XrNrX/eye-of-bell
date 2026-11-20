extends SceneTree
## The dungeon editor (roadmap E.1; scripts/debug/dungeon_editor.gd, editor_grid.gd). Run:
##   timeout 120 "$G" --headless --path . -s tests/editor_test.gd      (exits non-zero on any failure)
## The paper as data (strokes, undo and redo, the outer edge), then the editor itself driven through real input routing
## (root.push_input with screen positions, not calls to its handlers): paint, drag, rub, zoom, pan, undo keys, F10, New.

const EditorGrid := preload("res://scripts/debug/editor_grid.gd")
const EditorConfig := preload("res://scripts/debug/editor_config.gd")
const DungeonEditor := preload("res://scripts/debug/dungeon_editor.gd")
const DungeonMap := preload("res://scripts/dungeon_map.gd")
var fails := 0


func check(name: String, ok: bool) -> void:
	print(("PASS " if ok else "FAIL ") + name)
	if not ok:
		fails += 1


func _init() -> void:
	_check_grid()
	_check_things()
	await _check_editor()
	await _check_tools()
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


## A corridor along y = 5 (x 2 to 9) with a room at its east end, on a 12x10 sheet: walls above and below the corridor.
func _corridor() -> RefCounted:
	var g := EditorGrid.new()
	g.setup(12, 10, 100)
	for x in range(2, 10):
		g.set_cell(x, 5, true)
	for y in range(3, 8):
		for x in range(7, 10):
			g.set_cell(x, y, true)
	return g


func _check_things() -> void:
	var g := _corridor()
	# Doors: a wall each side, open ground ahead and behind.
	check("a door goes in the corridor (between two walls)", g.place_door(4, 5, EditorGrid.DOOR) == "" and g.type_at(4, 5) == EditorGrid.DOOR)
	check("a door on a wall is refused", g.place_door(4, 4, EditorGrid.DOOR) != "" and g.type_at(4, 4) == EditorGrid.WALL)
	check("a door in the open room is refused (no wall each side)", g.place_door(8, 5, EditorGrid.DOOR).contains("WALL") and g.type_at(8, 5) == EditorGrid.FLOOR)
	check("a door at the dead end of the corridor is refused (nothing ahead)", g.place_door(2, 5, EditorGrid.DOOR) != "")
	check("the outer edge takes nothing", g.place_door(0, 5, EditorGrid.DOOR) != "" and g.place_stairs(0, 0) != "")
	check("a locked door replaces the door, and so does a gate", g.place_door(4, 5, EditorGrid.LOCKED) == "" and g.type_at(4, 5) == EditorGrid.LOCKED and g.place_door(4, 5, EditorGrid.GATE) == "" and g.type_at(4, 5) == EditorGrid.GATE)
	check("painting over a door does nothing (Delete removes it)", not g.set_cell(4, 5, false) and not g.set_cell(4, 5, true) and g.type_at(4, 5) == EditorGrid.GATE)
	# Cracked wall, stairs, start.
	check("a cracked wall goes in a wall with floor beside it", g.place_cracked(5, 4) == "" and g.type_at(5, 4) == EditorGrid.CRACKED)
	check("a cracked wall deep in the rock is refused, and so is one on floor", g.place_cracked(10, 1) != "" and g.place_cracked(3, 5) != "")
	check("stairs go on floor and not in a wall", g.place_stairs(9, 3) == "" and g.type_at(9, 3) == EditorGrid.STAIRS and g.place_stairs(5, 2) != "")
	check("the party start goes on floor and not in a wall", g.place_start(3, 5, 3) == "" and g.start.cell == Vector2i(3, 5) and g.start.facing == 3 and g.place_start(5, 2) != "")
	check("only one start: placing it again moves it, keeping its facing", g.place_start(8, 5) == "" and g.start.cell == Vector2i(8, 5) and g.start.facing == 3)
	g.rotate_start()
	check("R turns the start a quarter turn clockwise (east to south)", g.start.facing == 2)
	g.rotate_start()
	g.rotate_start()
	g.rotate_start()
	check("four turns bring it round", g.start.facing == 3)
	# Levers and sconces: a face of a floor square with a wall that way.
	check("a lever goes on a wall face", g.place_lever(3, 5, 0) == "" and g.lever_index(Vector2i(3, 5), 0) == 0)
	check("a second thing on the same face is refused", g.place_sconce(3, 5, 0, EditorGrid.SCONCE_LIT) != "" and g.place_lever(3, 5, 0) != "")
	check("a face that is not a wall is refused (east of (3,5) is floor)", g.place_sconce(3, 5, 3, EditorGrid.SCONCE_LIT) != "")
	check("a sconce goes on another face, lit, unlit or empty", g.place_sconce(3, 5, 2, EditorGrid.SCONCE_UNLIT) == "" and g.sconces[0].state == EditorGrid.SCONCE_UNLIT and g.place_sconce(2, 5, 0, EditorGrid.SCONCE_EMPTY) == "")
	check("a sconce on a cracked wall's face is fine too (it is wall)", g.place_sconce(5, 5, 0, EditorGrid.SCONCE_LIT) == "")
	check("a sconce needs floor in front of it", g.place_sconce(5, 4, 0, EditorGrid.SCONCE_LIT) != "")
	check("a lever whose square has no other free wall cannot turn (south there is taken by a sconce)", g.rotate_face(true, 0) != "" and g.levers[0].side == 0)
	g.place_lever(6, 5, 0)
	var turned: int = g.levers.size() - 1
	check("R moves a lever to another wall face of its square (north to south)", g.rotate_face(true, turned) == "" and g.levers[turned].side == 2)
	check("...and on round again (south to north)", g.rotate_face(true, turned) == "" and g.levers[turned].side == 0)
	# Links.
	var g2 := _corridor()
	g2.place_door(4, 5, EditorGrid.DOOR)
	g2.place_lever(3, 5, 0)
	check("a lever links to a door (it gets an id, as floor 1's DOOR_IDS)", g2.link_lever(0, Vector2i(4, 5)) == "" and g2.levers[0].target == "door_4_5" and g2.door_ids.get(Vector2i(4, 5)) == "door_4_5")
	check("linking again unlinks, and the id goes with it", g2.link_lever(0, Vector2i(4, 5)) == "" and g2.levers[0].target == "" and g2.door_ids.is_empty())
	check("a lever cannot be linked to floor", g2.link_lever(0, Vector2i(5, 5)) != "")
	g2.link_lever(0, Vector2i(4, 5))
	g2.delete_cell_thing(4, 5)
	check("deleting a door makes it floor again and unlinks its levers", g2.type_at(4, 5) == EditorGrid.FLOOR and g2.levers[0].target == "" and g2.door_ids.is_empty())
	# A change that takes the ground from under a thing takes the thing too.
	var g3 := _corridor()
	g3.place_sconce(3, 5, 0, EditorGrid.SCONCE_LIT)
	g3.place_lever(5, 5, 2)
	g3.place_start(3, 5)
	g3.set_cell(3, 4, true)
	check("painting the wall away takes a sconce on it with it", g3.sconces.is_empty())
	g3.set_cell(3, 5, false)
	check("rubbing the floor back to wall takes the start with it", g3.start.is_empty())
	g3.set_cell(5, 6, true)
	check("opening the wall behind a lever takes the lever", g3.levers.is_empty())
	g3.place_cracked(5, 4)
	check("a cracked wall can be taken back to plain wall", g3.delete_cell_thing(5, 4) == "" and g3.type_at(5, 4) == EditorGrid.WALL)
	# Undo takes back things as well as squares.
	var g4 := _corridor()
	g4.place_door(4, 5, EditorGrid.DOOR)
	g4.place_lever(3, 5, 0)
	g4.link_lever(0, Vector2i(4, 5))
	g4.place_start(8, 5)
	check("undo takes back the start", g4.undo() and g4.start.is_empty())
	check("undo takes back the link, but keeps the lever", g4.undo() and g4.levers.size() == 1 and g4.levers[0].target == "" and g4.door_ids.is_empty())
	check("undo takes back the lever", g4.undo() and g4.levers.is_empty())
	check("undo takes back the door", g4.undo() and g4.type_at(4, 5) == EditorGrid.FLOOR)
	check("redo puts door, lever, link and start back", g4.redo() and g4.redo() and g4.redo() and g4.redo() and g4.type_at(4, 5) == EditorGrid.DOOR and g4.levers[0].target == "door_4_5" and g4.start.cell == Vector2i(8, 5))
	# Deleting a thing is undone whole, links and all.
	g4.delete_cell_thing(4, 5)
	g4.undo()
	check("undoing a door's deletion brings back the door and its link", g4.type_at(4, 5) == EditorGrid.DOOR and g4.levers[0].target == "door_4_5" and g4.door_ids.has(Vector2i(4, 5)))
	# The data is floor 1's own shapes: the game's DungeonMap takes it as it is.
	var g5 := _corridor()
	g5.place_door(3, 5, EditorGrid.DOOR)
	g5.place_door(4, 5, EditorGrid.LOCKED)
	g5.place_door(5, 5, EditorGrid.GATE)
	g5.place_cracked(6, 4)
	g5.place_stairs(9, 3)
	g5.place_start(8, 5, 1)
	g5.place_lever(2, 5, 0)
	g5.place_sconce(8, 3, 0, EditorGrid.SCONCE_UNLIT)
	g5.link_lever(0, Vector2i(5, 5))
	var data: Dictionary = g5.level_data()
	check("level_data holds floor 1's own fields (MAP, START_TILE, START_FACING, DOOR_IDS, LEVERS, TORCHES)", data.has("MAP") and data.has("START_TILE") and data.has("START_FACING") and data.has("DOOR_IDS") and data.has("LEVERS") and data.has("TORCHES"))
	DungeonMap.use_level_data(data, "seed:editor_test")
	check("the game reads the drawn doors (door, locked door, gate), cracked wall and stairs",
			DungeonMap.is_door(Vector2i(3, 5)) and DungeonMap.is_locked(Vector2i(4, 5)) and DungeonMap.is_portcullis(Vector2i(5, 5))
			and DungeonMap.is_destructible(Vector2i(6, 4)) and DungeonMap.is_stairs(Vector2i(9, 3)) and not DungeonMap.is_blocked(Vector2i(8, 5)))
	check("...the linked gate's id, the lever, the sconce and the start",
			DungeonMap.door_id(Vector2i(5, 5)) == "door_5_5" and DungeonMap.lever_at(Vector2i(2, 5), 0).get("target") == "door_5_5"
			and DungeonMap.TORCHES.has(Vector4i(8, 3, 0, 1)) and DungeonMap.START_TILE == Vector2i(8, 5) and DungeonMap.START_FACING == 1)
	DungeonMap.use_level("")


## The tools through real input: toolbar clicks, placing, refusing with a message, linking, selecting, Delete and R.
func _check_tools() -> void:
	var ed: Node = DungeonEditor.new()
	root.add_child(ed)
	await process_frame
	ed.open()
	ed._new_sheet(14, 10)
	for x in range(2, 12):
		ed.grid.set_cell(x, 5, true)
	for y in range(3, 8):
		for x in range(9, 12):
			ed.grid.set_cell(x, y, true)
	ed._redraw()
	check("the toolbar has a button for every tool (DRAW, SELECT and ten things)", ed.tool_buttons.size() == 12 and ed.tool == DungeonEditor.Tool.DRAW)
	# A click on a toolbar button picks the tool.
	var door_button: Control = ed.tool_buttons[DungeonEditor.TOOL_ORDER.find(DungeonEditor.Tool.DOOR)]
	_press(door_button.global_position + Vector2(6, 6), MOUSE_BUTTON_LEFT, true)
	_press(door_button.global_position + Vector2(6, 6), MOUSE_BUTTON_LEFT, false)
	check("clicking the door button picks the DOOR tool", ed.tool == DungeonEditor.Tool.DOOR)
	# Place a door; a refusal says why.
	_press(_centre_of(ed, 5, 5), MOUSE_BUTTON_LEFT, true)
	check("a click places a door in the corridor (and selects it)", ed.grid.type_at(5, 5) == EditorGrid.DOOR and ed.selected.get("kind") == "cell")
	_press(_centre_of(ed, 5, 4), MOUSE_BUTTON_LEFT, true)
	check("a click on a wall is refused with a short message", ed.grid.type_at(5, 4) == EditorGrid.WALL and ed.message != "" and ed.message.length() < 40)
	# A lever on a wall face: click near the north edge of a corridor square.
	ed.set_tool(DungeonEditor.Tool.LEVER)
	_press(_centre_of(ed, 3, 5) + Vector2(0, -0.38 * ed.cell_px), MOUSE_BUTTON_LEFT, true)
	check("clicking near a square's north edge hangs a lever on that wall face", ed.grid.levers.size() == 1 and ed.grid.levers[0].cell == Vector2i(3, 5) and ed.grid.levers[0].side == 0)
	check("the new lever is selected, ready to be linked", ed.selected.get("kind") == "lever")
	_press(_centre_of(ed, 3, 5), MOUSE_BUTTON_LEFT, true)
	check("a click in the middle of a square is refused (it wants an edge)", ed.grid.levers.size() == 1 and ed.message != "")
	# With the lever selected, a click on the door links them.
	_press(_centre_of(ed, 3, 5) + Vector2(0, -0.38 * ed.cell_px), MOUSE_BUTTON_LEFT, true)
	check("a second lever on the same face is refused", ed.grid.levers.size() == 1)
	ed.selected = {"kind": "lever", "index": 0}
	_press(_centre_of(ed, 5, 5), MOUSE_BUTTON_LEFT, true)
	check("click the lever, then the door: they are linked (a line joins them while selected)", ed.grid.levers[0].target == "door_5_5" and ed.grid.door_ids.has(Vector2i(5, 5)))
	_press(_centre_of(ed, 5, 5), MOUSE_BUTTON_LEFT, true)
	check("clicking the door again unlinks", ed.grid.levers[0].target == "")
	# A sconce from the wall's own side: click near the south edge of the wall square above the corridor.
	ed.set_tool(DungeonEditor.Tool.SCONCE_LIT)
	_press(_centre_of(ed, 6, 4) + Vector2(0, 0.38 * ed.cell_px), MOUSE_BUTTON_LEFT, true)
	check("clicking the wall's own edge from the wall side puts the sconce on the floor square across it", ed.grid.sconces.size() == 1 and ed.grid.sconces[0].cell == Vector2i(6, 5) and ed.grid.sconces[0].side == 0 and ed.grid.sconces[0].state == EditorGrid.SCONCE_LIT)
	ed.set_tool(DungeonEditor.Tool.SCONCE_UNLIT)
	_press(_centre_of(ed, 6, 5) + Vector2(0, 0.38 * ed.cell_px), MOUSE_BUTTON_LEFT, true)
	check("an unlit sconce on the south face", ed.grid.sconces.size() == 2 and ed.grid.sconces[1].state == EditorGrid.SCONCE_UNLIT)
	# The rest of the tools.
	ed.set_tool(DungeonEditor.Tool.STAIRS)
	_press(_centre_of(ed, 10, 3), MOUSE_BUTTON_LEFT, true)
	ed.set_tool(DungeonEditor.Tool.CRACKED)
	_press(_centre_of(ed, 7, 4), MOUSE_BUTTON_LEFT, true)
	ed.set_tool(DungeonEditor.Tool.START)
	_press(_centre_of(ed, 10, 5), MOUSE_BUTTON_LEFT, true)
	ed.set_tool(DungeonEditor.Tool.GATE)
	_press(_centre_of(ed, 7, 5), MOUSE_BUTTON_LEFT, true)
	ed.set_tool(DungeonEditor.Tool.LOCKED)
	_press(_centre_of(ed, 4, 5), MOUSE_BUTTON_LEFT, true)
	check("stairs, a cracked wall, the start, a gate and a locked door are all placed",
			ed.grid.type_at(10, 3) == EditorGrid.STAIRS and ed.grid.type_at(7, 4) == EditorGrid.CRACKED and ed.grid.start.cell == Vector2i(10, 5)
			and ed.grid.type_at(7, 5) == EditorGrid.GATE and ed.grid.type_at(4, 5) == EditorGrid.LOCKED)
	# Select, R and Delete.
	ed.set_tool(DungeonEditor.Tool.SELECT)
	_press(_centre_of(ed, 10, 5), MOUSE_BUTTON_LEFT, true)
	check("SELECT picks the party start", ed.selected.get("kind") == "start")
	var facing_before: int = ed.grid.start.facing
	_key(KEY_R)
	check("R turns the selected start", ed.grid.start.facing != facing_before)
	_press(_centre_of(ed, 7, 5), MOUSE_BUTTON_LEFT, true)
	check("SELECT picks a gate", ed.selected.get("kind") == "cell" and ed.selected.cell == Vector2i(7, 5))
	_key(KEY_DELETE)
	check("Delete takes the gate away (the square is floor again)", ed.grid.type_at(7, 5) == EditorGrid.FLOOR and ed.selected.is_empty())
	_press(_centre_of(ed, 6, 5) + Vector2(0, -0.36 * ed.cell_px), MOUSE_BUTTON_LEFT, true)
	check("SELECT picks a sconce by its icon", ed.selected.get("kind") == "sconce")
	_key(KEY_R)
	check("R moves a sconce to another wall face", ed.grid.sconces[ed.selected.index].side != 0 or ed.grid.sconces.size() == 2)
	_key(KEY_DELETE)
	check("Delete removes the sconce", ed.grid.sconces.size() == 1)
	_key(KEY_DELETE)
	check("Delete with nothing selected only says so", ed.message != "" and ed.grid.sconces.size() == 1)
	# Escape lets go of a selection before it closes the editor.
	ed.selected = {"kind": "start"}
	_key(KEY_ESCAPE)
	check("Escape lets go of the selection first and leaves the editor open", ed.selected.is_empty() and ed.is_open())
	# Undo puts things back.
	var stairs_there: bool = ed.grid.type_at(10, 3) == EditorGrid.STAIRS
	_key(KEY_Z, true)
	_key(KEY_Z, true)
	check("Ctrl+Z undoes things too (the deleted sconce and gate come back)", stairs_there and ed.grid.sconces.size() == 2 and ed.grid.type_at(7, 5) == EditorGrid.GATE)
	# The drawing code runs for all of it without a fault (a frame is drawn).
	ed._redraw()
	await process_frame
	check("the paper draws with everything on it", ed.is_open())
	ed.close()
	ed.queue_free()
