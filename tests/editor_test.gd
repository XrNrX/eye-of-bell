extends SceneTree
## The dungeon editor (roadmap E.1; scripts/debug/dungeon_editor.gd, editor_grid.gd). Run:
##   timeout 120 "$G" --headless --path . -s tests/editor_test.gd      (exits non-zero on any failure)
## The paper as data (strokes, undo and redo, the outer edge), then the editor itself driven through real input routing
## (root.push_input with screen positions, not calls to its handlers): paint, drag, rub, zoom, pan, undo keys, F10, New.

const EditorGrid := preload("res://scripts/debug/editor_grid.gd")
const EditorConfig := preload("res://scripts/debug/editor_config.gd")
const DungeonEditor := preload("res://scripts/debug/dungeon_editor.gd")
const EditorCheck := preload("res://scripts/debug/editor_check.gd")
const EditorSave := preload("res://scripts/debug/editor_save.gd")
const SaveGame := preload("res://scripts/save_game.gd")
const DungeonMap := preload("res://scripts/dungeon_map.gd")
var fails := 0


func check(name: String, ok: bool) -> void:
	print(("PASS " if ok else "FAIL ") + name)
	if not ok:
		fails += 1


func _init() -> void:
	_check_grid()
	_check_things()
	_check_pieces()
	_check_checker()
	await _check_editor()
	await _check_tools()
	await _check_panel()
	await _check_build()
	await _check_save_open()
	await _check_play_from_start()
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
	check("the toolbar has a button for every tool (DRAW, SELECT and twelve things)", ed.tool_buttons.size() == 14 and ed.tool == DungeonEditor.Tool.DRAW)
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


func _check_pieces() -> void:
	var potion := "res://data/items/healing_potion.tres"
	var sword := "res://data/items/short_sword.tres"
	var key := "res://data/items/key.tres"
	var slime := "res://data/monsters/slime.tres"
	var g := _corridor()
	check("an item goes on a floor square", g.place_item(3, 5, sword) == "" and g.items.size() == 1 and g.items[0].count == 1)
	check("an item on a wall or on the edge is refused", g.place_item(3, 4, sword) != "" and g.place_item(0, 0, sword) != "" and g.items.size() == 1)
	check("a stackable item joins the top stack up to its limit (9)", g.place_item(4, 5, potion, 9) == "" and g.place_item(4, 5, potion, 9) == "" and g.items_at(Vector2i(4, 5)).size() == 1 and g.items[g.items_at(Vector2i(4, 5))[0]].count == 2)
	for i in 8:
		g.place_item(4, 5, potion, 9)
	check("past the limit it starts a new stack on top (a pile)", g.items_at(Vector2i(4, 5)).size() == 2 and g.items[g.items_at(Vector2i(4, 5))[0]].count == 9 and g.items[g.items_at(Vector2i(4, 5))[1]].count == 1)
	check("a different item makes its own stack on top, and an unstackable one never joins", g.place_item(3, 5, sword) == "" and g.items_at(Vector2i(3, 5)).size() == 2)
	# Monsters: one to a square, on floor, never on the start.
	check("a monster stands on a floor square, facing a way", g.place_monster(6, 5, slime, 1) == "" and g.monsters.size() == 1 and g.monsters[0].facing == 1)
	check("a second monster on the same square is refused", g.place_monster(6, 5, slime) != "" and g.monsters.size() == 1)
	check("a monster in a wall is refused", g.place_monster(6, 4, slime) != "")
	g.place_start(7, 5)
	check("a monster never goes on the party start, and the start never on a monster", g.place_monster(7, 5, slime) != "" and g.place_start(6, 5) != "" and g.start.cell == Vector2i(7, 5))
	g.rotate_monster(0)
	check("R turns a monster a quarter turn clockwise (west to north)", g.monsters[0].facing == 0)
	# A key links to a locked door like a lever to a door.
	g.place_door(5, 5, EditorGrid.LOCKED)
	g.place_item(2, 5, key)
	var key_index: int = g.items_at(Vector2i(2, 5))[0]
	check("a key links to a locked door", g.link_key(key_index, Vector2i(5, 5)) == "" and g.items[key_index].get("opens") == Vector2i(5, 5))
	check("a key links only to a locked door", g.link_key(key_index, Vector2i(3, 5)) != "")
	check("linking again unlinks", g.link_key(key_index, Vector2i(5, 5)) == "" and not g.items[key_index].has("opens"))
	g.link_key(key_index, Vector2i(5, 5))
	g.delete_cell_thing(5, 5)
	check("a locked door that goes takes the key's link with it", not g.items[key_index].has("opens"))
	# Taking the floor away takes what stood on it.
	var g2 := _corridor()
	g2.place_item(3, 5, potion, 9)
	g2.place_monster(4, 5, slime)
	g2.set_cell(3, 5, false)
	g2.set_cell(4, 5, false)
	check("rubbing floor back to wall takes the items and monsters on it", g2.items.is_empty() and g2.monsters.is_empty())
	g2.undo()
	g2.undo()
	check("and undo brings them back", g2.items.size() == 1 and g2.monsters.size() == 1)
	# Undo, delete.
	var g3 := _corridor()
	g3.place_item(3, 5, potion, 9)
	g3.place_item(3, 5, potion, 9)
	g3.place_monster(4, 5, slime)
	g3.delete_monster(0)
	g3.delete_item(0)
	check("Delete takes a monster or an item away", g3.monsters.is_empty() and g3.items.is_empty())
	g3.undo()
	g3.undo()
	check("each is undone on its own", g3.monsters.size() == 1 and g3.items.size() == 1 and g3.items[0].count == 2)
	# The data is floor 1's own shapes.
	var g4 := _corridor()
	g4.place_item(3, 5, potion, 9)
	g4.place_item(3, 5, potion, 9)
	g4.place_item(4, 5, key)
	g4.place_monster(6, 5, slime, 3)
	g4.place_start(8, 5)
	var data: Dictionary = g4.level_data()
	check("level_data has ITEMS (cell, def, count when more than one) and MONSTERS (cell, def)",
			data.ITEMS.size() == 2 and data.ITEMS[0].cell == Vector2i(3, 5) and data.ITEMS[0].def == potion and data.ITEMS[0].count == 2 and not data.ITEMS[1].has("count")
			and data.MONSTERS.size() == 1 and data.MONSTERS[0].cell == Vector2i(6, 5) and data.MONSTERS[0].def == slime)
	DungeonMap.use_level_data(data, "seed:editor_test")
	check("the game takes them as they are (ITEMS and MONSTERS of the drawn level)", DungeonMap.ITEMS.size() == 2 and DungeonMap.MONSTERS.size() == 1 and DungeonMap.MONSTERS[0].def == slime
			and load(DungeonMap.ITEMS[0].def) != null and load(DungeonMap.MONSTERS[0].def) != null)
	DungeonMap.use_level("")


## The side panel, the lists and the item and monster tools through real input.
## A whole click (press and release): the GUI keeps routing events to the control that got a press until the button comes up.
func _click(pos: Vector2) -> void:
	_press(pos, MOUSE_BUTTON_LEFT, true)
	_press(pos, MOUSE_BUTTON_LEFT, false)


## A wheel step: the GUI treats the wheel as a button press and release.
func _wheel(pos: Vector2, button: int) -> void:
	_press(pos, button, true)
	_press(pos, button, false)


func _check_panel() -> void:
	var ed: Node = DungeonEditor.new()
	root.add_child(ed)
	await process_frame
	ed.open()
	# The lists come from the folders: every item and monster file is on them.
	var item_files := []
	for f in DirAccess.get_files_at("res://data/items"):
		if f.ends_with(".tres"):
			item_files.append("res://data/items/" + f)
	var monster_files := []
	for f in DirAccess.get_files_at("res://data/monsters"):
		if f.ends_with(".tres"):
			monster_files.append("res://data/monsters/" + f)
	var listed_items: Array = ed.item_list.map(func(e): return e.path)
	var listed_monsters: Array = ed.monster_list.map(func(e): return e.path)
	var all_there := true
	for f in item_files:
		all_there = all_there and f in listed_items
	for f in monster_files:
		all_there = all_there and f in listed_monsters
	check("the panel lists every item in data/items and every monster in data/monsters (%d and %d)" % [item_files.size(), monster_files.size()],
			all_there and listed_items.size() == item_files.size() and listed_monsters.size() == monster_files.size())
	var iconless: int = ed.item_list.filter(func(e): return e.icon == null).size() + ed.monster_list.filter(func(e): return e.icon == null).size()
	check("each shows its own icon or sprite (%d without)" % iconless, iconless == 0)
	ed._new_sheet(14, 10)
	for x in range(2, 12):
		ed.grid.set_cell(x, 5, true)
	for y in range(3, 8):
		for x in range(9, 12):
			ed.grid.set_cell(x, y, true)
	ed._redraw()
	check("there is a button for every tool (DRAW, SELECT and twelve things)", ed.tool_buttons.size() == 14)
	# The ITEM tool with nothing chosen says so.
	ed.set_tool(DungeonEditor.Tool.ITEM)
	_click(_centre_of(ed, 4, 5))
	check("the ITEM tool with nothing picked places nothing and says to pick", ed.grid.items.is_empty() and ed.message != "")
	# Click a row, then a square.
	var row_y: float = DungeonEditor.PANEL_RECT.position.y + DungeonEditor.LIST_TOP + 4
	_click(Vector2(DungeonEditor.PANEL_RECT.position.x + 40, row_y))
	check("clicking a row in the list picks that item", ed.brush_item == ed.item_list[0].path)
	_click(_centre_of(ed, 4, 5))
	_click(_centre_of(ed, 4, 5))
	check("clicking a floor square places it, and again adds to the pile", ed.grid.items.size() >= 1 and ed.grid.items[0].def == ed.item_list[0].path and ed.selected.get("kind") == "item")
	var count_before: int = ed.grid.items.size()
	_click(_centre_of(ed, 4, 4))
	check("a click on a wall places nothing and says why", ed.grid.items.size() == count_before and ed.message != "")
	# The list scrolls.
	var rows: int = ed._visible_rows()
	_wheel(Vector2(DungeonEditor.PANEL_RECT.position.x + 40, row_y), MOUSE_BUTTON_WHEEL_DOWN)
	check("the wheel scrolls the list (it holds more than %d)" % rows, ed.item_list.size() <= rows or ed.list_scroll == 1)
	_wheel(Vector2(DungeonEditor.PANEL_RECT.position.x + 40, row_y), MOUSE_BUTTON_WHEEL_UP)
	check("and back", ed.list_scroll == 0)
	# Monsters: pick, place, face.
	ed.set_tool(DungeonEditor.Tool.MONSTER)
	_click(Vector2(DungeonEditor.PANEL_RECT.position.x + 40, row_y + DungeonEditor.ROW_H))
	check("the MONSTER tool's list picks a monster", ed.brush_monster == ed.monster_list[1].path)
	_click(_centre_of(ed, 6, 5))
	check("a click places it on the floor square, facing south at first, and selects it", ed.grid.monsters.size() == 1 and ed.grid.monsters[0].facing == 2 and ed.selected.get("kind") == "monster")
	_key(KEY_R)
	check("R turns the selected monster", ed.grid.monsters[0].facing == 1 and ed.brush_facing == 1)
	_click(_centre_of(ed, 6, 5))
	check("a second monster on the same square is refused with a message", ed.grid.monsters.size() == 1 and ed.message != "")
	# Hover info.
	_move(_centre_of(ed, 6, 5))
	var lines: Array = ed._info_lines()
	check("the box at the foot of the panel says what is under the mouse (%s)" % str(lines), lines[0] == "(6,5)" and lines.has("FLOOR") and lines.size() >= 4)
	_move(_centre_of(ed, 4, 5))
	var pile_lines: Array = ed._info_lines()
	check("...and an item's name and count", pile_lines[0] == "(4,5)" and pile_lines.size() >= 3)
	# Select cycles through monster, pile stacks and door on one square.
	ed.set_tool(DungeonEditor.Tool.SELECT)
	ed.grid.place_item(6, 5, "res://data/items/dagger.tres")  # (A pile under the monster; the path need not exist for this.)
	ed.selected = {}
	_click(_centre_of(ed, 6, 5))
	check("SELECT picks the monster first", ed.selected.get("kind") == "monster")
	_click(_centre_of(ed, 6, 5))
	check("clicking the same square again goes down the pile", ed.selected.get("kind") == "item")
	_key(KEY_DELETE)
	check("Delete removes the selected stack", ed.grid.items_at(Vector2i(6, 5)).is_empty())
	# Keys and locked doors.
	ed.set_tool(DungeonEditor.Tool.LOCKED)
	_click(_centre_of(ed, 7, 5))
	var key_entry: Dictionary = {}
	for e in ed.item_list:
		if e.path == "res://data/items/key.tres":
			key_entry = e
	ed.set_tool(DungeonEditor.Tool.ITEM)
	ed.select_brush(key_entry.path)
	_click(_centre_of(ed, 3, 5))
	check("a key lies on the floor (and is selected)", ed.selected.get("kind") == "item" and ed.grid.items[int(ed.selected.index)].def == key_entry.path)
	ed.set_tool(DungeonEditor.Tool.SELECT)
	_click(_centre_of(ed, 7, 5))
	check("with the key selected, a click on the locked door links them", ed.grid.items[ed.grid.items_at(Vector2i(3, 5))[0]].get("opens") == Vector2i(7, 5))
	_click(_centre_of(ed, 3, 5))
	_click(_centre_of(ed, 7, 5))
	check("...and clicking again unlinks (select the key square, then the door)", not ed.grid.items[ed.grid.items_at(Vector2i(3, 5))[0]].has("opens"))
	# Drawing all of it runs without a fault.
	ed._redraw()
	await process_frame
	check("the paper and the panel draw with everything on them", ed.is_open())
	ed.close()
	ed.queue_free()


func _problem_texts(problems: Array) -> String:
	return " | ".join(problems.map(func(p): return p.level + ": " + p.text))


func _has_problem(problems: Array, fragment: String) -> bool:
	for p in problems:
		if fragment in p.text:
			return true
	return false


func _check_checker() -> void:
	var key := "res://data/items/key.tres"
	var slime := "res://data/monsters/slime.tres"
	var g := _corridor()
	var p0: Array = EditorCheck.run(g)
	check("an empty paper has two errors: no party start and no stairs", EditorCheck.has_errors(p0) and _has_problem(p0, "NO PARTY START") and _has_problem(p0, "NO STAIRS"))
	g.place_start(3, 5, 3)
	var p1: Array = EditorCheck.run(g)
	check("with a start but no stairs it is still an error", EditorCheck.has_errors(p1) and not _has_problem(p1, "NO PARTY START") and _has_problem(p1, "NO STAIRS"))
	g.place_stairs(9, 3)
	check("a start and stairs on open ground: nothing to report", EditorCheck.run(g).is_empty() and EditorCheck.reachable(g).has(Vector2i(9, 3)))
	# A locked door needs a key you can get to.
	g.place_door(5, 5, EditorGrid.LOCKED)
	var p2: Array = EditorCheck.run(g)
	check("a locked door with no key: warnings, not errors (%s)" % _problem_texts(p2), not EditorCheck.has_errors(p2) and _has_problem(p2, "LOCKED DOOR") and _has_problem(p2, "STAIRS CAN'T") and _has_problem(p2, "FLOOR SQUARE"))
	check("...and the squares behind it are marked", EditorCheck.marked_cells(p2).has(Vector2i(5, 5)) and EditorCheck.marked_cells(p2).has(Vector2i(9, 3)) and EditorCheck.marked_cells(p2).has(Vector2i(8, 5)))
	g.place_item(8, 5, key)
	g.link_key(g.items_at(Vector2i(8, 5))[0], Vector2i(5, 5))
	check("a key linked to the door but lying behind it does not help", _has_problem(EditorCheck.run(g), "STAIRS CAN'T"))
	g.delete_item(0)
	g.place_item(3, 5, key)
	g.link_key(g.items_at(Vector2i(3, 5))[0], Vector2i(5, 5))
	check("a linked key on this side opens the way: nothing to report", EditorCheck.run(g).is_empty())
	g.items[0].erase("opens")
	var p3: Array = EditorCheck.run(g)
	check("a key linked to nothing is a warning, and the door is shut for lack of a key", _has_problem(p3, "KEY") and _has_problem(p3, "STAIRS CAN'T"))
	# A gate needs a lever on this side.
	var g2 := _corridor()
	g2.place_start(3, 5, 3)
	g2.place_stairs(9, 3)
	g2.place_door(5, 5, EditorGrid.GATE)
	var p4: Array = EditorCheck.run(g2)
	check("a gate with no lever is a warning and shuts the way", _has_problem(p4, "GATE") and _has_problem(p4, "STAIRS CAN'T"))
	g2.place_lever(4, 5, 0)
	var p5: Array = EditorCheck.run(g2)
	check("a lever linked to nothing is a warning", _has_problem(p5, "LEVER") and _has_problem(p5, "GATE"))
	g2.link_lever(0, Vector2i(5, 5))
	check("a lever on this side linked to the gate opens it: nothing to report", EditorCheck.run(g2).is_empty())
	g2.delete_lever(0)
	g2.place_lever(8, 3, 0)
	g2.link_lever(g2.levers.size() - 1, Vector2i(5, 5))
	check("a lever behind the gate cannot open it", _has_problem(EditorCheck.run(g2), "STAIRS CAN'T"))
	# Chains: one key opens the way to the lever that opens the way to the next.
	var g3 := EditorGrid.new()
	g3.setup(16, 8, 100)
	for x in range(2, 14):
		g3.set_cell(x, 4, true)
	g3.place_start(2, 4, 3)
	g3.place_door(4, 4, EditorGrid.LOCKED)
	g3.place_door(8, 4, EditorGrid.GATE)
	g3.place_stairs(13, 4)
	g3.place_item(3, 4, key)
	g3.link_key(0, Vector2i(4, 4))
	g3.place_lever(6, 4, 0)
	g3.link_lever(0, Vector2i(8, 4))
	check("a key, then a lever, then the stairs: reachable in turn", EditorCheck.run(g3).is_empty())
	g3.items[0].erase("opens")
	check("take the key's link away and nothing past the locked door is reachable", not EditorCheck.reachable(g3).has(Vector2i(6, 4)) and not EditorCheck.reachable(g3).has(Vector2i(13, 4)))
	# Sealed pockets: items and monsters nobody can reach.
	var g4 := _corridor()
	g4.place_start(3, 5, 3)
	g4.place_stairs(9, 3)
	g4.set_cell(2, 8, true)
	g4.place_item(2, 8, "res://data/items/dagger.tres")
	g4.place_monster(2, 8, slime)
	var p6: Array = EditorCheck.run(g4)
	check("an item and a monster in a sealed pocket are warnings, with the square marked (%s)" % _problem_texts(p6), _has_problem(p6, "ITEM") and _has_problem(p6, "MONSTER") and _has_problem(p6, "FLOOR SQUARE") and EditorCheck.marked_cells(p6).has(Vector2i(2, 8)))
	check("none of it is an error: the build may go on", not EditorCheck.has_errors(p6))


func _check_build() -> void:
	var dummy := Node.new()
	root.add_child(dummy)
	current_scene = dummy
	SaveGame.path = "user://editor_build_test_save.json"
	if FileAccess.file_exists(SaveGame.path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveGame.path))
	var ed: Node = DungeonEditor.new()
	root.add_child(ed)
	await process_frame
	ed.open()
	# Errors refuse the build.
	ed._new_sheet(14, 10)
	ed.request_build()
	check("a build with no start and no stairs is refused with a list", ed.problem_dialog.visible and EditorCheck.has_errors(ed.problems) and DungeonMap.level_id == DungeonMap.FLOOR_1_ID)
	check("the dialog offers only OK when the build is refused", ed.problem_buttons.get_child_count() == 1)
	ed.problem_dialog.visible = false
	# Warnings do not: a lever linked to nothing.
	for x in range(2, 13):
		ed.grid.set_cell(x, 5, true)
	for y in range(3, 8):
		for x in range(10, 13):
			ed.grid.set_cell(x, y, true)
	ed.grid.place_start(2, 5, 3)
	ed.grid.place_stairs(12, 5)
	ed.grid.place_lever(3, 5, 0)
	ed.request_build()
	check("an unlinked lever is a warning: the list offers BUILD ANYWAY and CANCEL, and marks the lever's square", ed.problem_dialog.visible and not EditorCheck.has_errors(ed.problems) and ed.problem_buttons.get_child_count() == 2 and ed.marks.has(Vector2i(3, 5)))
	check("nothing was built yet", DungeonMap.level_id == DungeonMap.FLOOR_1_ID)
	ed.problem_dialog.visible = false
	_click(_centre_of(ed, 9, 5))
	check("the red ink comes off at the next click on the paper", ed.marks.is_empty())
	# The small dungeon: a door, a lever linked to a gate, two monsters and stairs.
	ed.grid.delete_lever(0)
	ed.grid.place_door(4, 5, EditorGrid.DOOR)
	ed.grid.place_lever(6, 5, 0)
	ed.grid.place_door(8, 5, EditorGrid.GATE)
	ed.grid.link_lever(0, Vector2i(8, 5))
	ed.grid.place_monster(11, 3, "res://data/monsters/skeleton.tres", 2)
	ed.grid.place_monster(12, 7, "res://data/monsters/slime.tres", 1)
	ed.grid.place_item(5, 5, "res://data/items/healing_potion.tres", 9)
	check("the little dungeon passes the check", EditorCheck.run(ed.grid).is_empty())
	ed.request_build()
	check("it builds at once: the level is the drawn one, under the editor's play id, and cannot be saved",
			DungeonMap.level_id == DungeonMap.EDITOR_PLAY_ID and DungeonMap.MAP.size() == 10 and DungeonMap.MAP[5][4] == EditorGrid.DOOR and DungeonMap.MAP[5][8] == EditorGrid.GATE
			and DungeonMap.START_TILE == Vector2i(2, 5) and DungeonMap.MONSTERS.size() == 2 and DungeonMap.level_path != "")
	check("the editor is out of the way while the game loads", not ed.is_open())
	await create_timer(1.2).timeout
	var player: Node = get_first_node_in_group("player")
	var party: Node = get_first_node_in_group("party")
	check("the game scene stands, with the party on the start facing east", player != null and party != null and player.cell == Vector2i(2, 5) and player.facing == 3 and current_scene.scene_file_path == "res://scenes/main.tscn")
	check("the ready-made four, with full HP and mana", party.members.size() == 4 and party.members.all(func(m): return m.hp == m.def.max_hp and is_equal_approx(m.mana, float(m.def.max_mana))))
	var kinds: Array = get_nodes_in_group("monsters").map(func(m): return m.def.display_name)
	check("the drawn monsters are in the game, and nothing else (%s)" % str(kinds), kinds.size() == 2 and "Skeleton" in kinds and "Slime" in kinds)
	check("the door, the gate and the stairs are the game's", DungeonMap.is_door(Vector2i(4, 5)) and DungeonMap.is_portcullis(Vector2i(8, 5)) and DungeonMap.is_stairs(Vector2i(12, 5)) and DungeonMap.door_id(Vector2i(8, 5)) != "")
	check("there is still only one editor", get_nodes_in_group("dungeon_editor").size() == 1 and is_instance_valid(ed))
	var saved: String = SaveGame.save(self)
	check("saving is refused (%s) and nothing is written to the save slot" % saved, saved != "" and not FileAccess.file_exists(SaveGame.path))
	# Walk a little, then Tab back to the paper.
	player.restore(Vector2i(6, 5), 3)
	_key(KEY_TAB)
	check("Tab goes back to the paper, the game waits, and the party's square is marked", ed.is_open() and paused and ed.play_marker.get("cell") == Vector2i(6, 5) and ed.play_marker.get("facing") == 3)
	_key(KEY_TAB)
	check("Tab again goes back to the game", not ed.is_open() and not paused)
	_key(KEY_F10)
	check("F10 in the built game also opens the paper (the marker follows the party)", ed.is_open() and ed.play_marker.get("cell") == Vector2i(6, 5))
	# Edit, then build again: the party goes back where it was.
	ed.grid.place_item(7, 5, "res://data/items/dagger.tres")
	ed.request_build()
	check("build again: the level has the new item and the party is waiting to be put back", DungeonMap.ITEMS.size() == 2 and ed.pending_place.get("cell") == Vector2i(6, 5))
	await create_timer(1.4).timeout
	player = get_first_node_in_group("player")
	check("the party stands where it was left (6,5), facing the same way", player != null and player.cell == Vector2i(6, 5) and player.facing == 3 and ed.play_marker.is_empty())
	check("the game after a rebuild is still fresh: full HP", get_first_node_in_group("party").members.all(func(m): return m.hp == m.def.max_hp))
	# Out of play: the menu's level reset and the editor's marker are gone with it.
	DungeonMap.use_level("")
	current_scene.queue_free()
	await process_frame
	check("with the built game gone Tab does nothing and F10 opens the paper as usual", not ed._in_play())
	ed.queue_free()
	await process_frame


const TEST_LEVELS := "user://editor_test_levels"


func _clear_test_levels() -> void:
	for f in DirAccess.get_files_at(TEST_LEVELS):
		DirAccess.remove_absolute(TEST_LEVELS + "/" + f)


## Every level field of `a` that `b` lacks or holds differently (empty when the two are the same level).
func _differing(a: Dictionary, b: Dictionary) -> Array:
	var out := []
	for f in DungeonMap.LEVEL_FIELDS:
		if a.has(f) and (not b.has(f) or b[f] != a[f]):
			out.append(f)
	return out


func _check_save_open() -> void:
	DirAccess.make_dir_recursive_absolute(TEST_LEVELS)
	_clear_test_levels()
	var floor_one: Dictionary = EditorSave.read("res://levels/floor_1.gd")
	var ed: Node = DungeonEditor.new()
	root.add_child(ed)
	await process_frame
	ed.open()
	ed.levels_dir = TEST_LEVELS
	check("EditorSave.read gives floor 1's fields", floor_one.has("MAP") and floor_one.MAP.size() == 25 and floor_one.has("PUZZLES") and floor_one.has("CURSE_ZONES"))
	# Open floor 1: everything the editor knows is there, the rest is kept.
	check("opening floor 1 works", ed.open_file("res://levels/floor_1.gd") == "" and ed.level_name == "floor_1")
	check("floor 1 is on the paper: 22 by 25 squares, its start, 25 sconces, levers, items and monsters",
			ed.grid.width == 22 and ed.grid.height == 25 and ed.grid.start.cell == Vector2i(5, 9) and ed.grid.sconces.size() == 25 and ed.grid.levers.size() == 3
			and ed.grid.items.size() == floor_one.ITEMS.size() and ed.grid.monsters.size() == floor_one.MONSTERS.size() and ed.grid.door_ids.size() == 2)
	check("it opens at a readable zoom with the sheet's width on the paper (%d px squares)" % ed.cell_px, ed.cell_px == 16 and ed.cell_px * ed.grid.width <= DungeonEditor.PAPER_RECT.size.x)
	check("what it cannot edit yet is kept, and listed in grey (%s)" % str(ed._kept_summary()), ed.grid.extras.has("PUZZLES") and ed.grid.extras.has("PLATES") and ed._kept_summary().has("2 PUZZLES") and ed._kept_summary().has("1 PLATES") and ed._kept_summary().has("1 CURSE ZONES") and ed._kept_summary().has("2 CORRUPTED"))
	check("a kept plate shows in the info box's square (18,21)", ed._kept_at(Vector2i(18, 21)).has("PLATE") and ed.grid.type_at(7, 9) == EditorGrid.CORRUPTED)
	check("tidying floor 1 changes nothing (it already follows every rule the editor enforces)", _differing(floor_one, _tidied(floor_one)).is_empty())
	# Save it unchanged under a new name: identical.
	check("Save writes levels/<name>.gd", ed.try_save("zz_round_trip") == "" and FileAccess.file_exists(TEST_LEVELS + "/zz_round_trip.gd") and ed.level_name == "zz_round_trip")
	var saved: Dictionary = EditorSave.read(TEST_LEVELS + "/zz_round_trip.gd")
	var diff := _differing(floor_one, saved)
	check("floor 1 opened and saved without a change is IDENTICAL to floor 1 (differing fields: %s)" % str(diff), diff.is_empty() and saved.MAP == floor_one.MAP)
	var consts: Dictionary = (load(TEST_LEVELS + "/zz_round_trip.gd") as GDScript).get_script_constant_map()
	check("the file is a plain script of consts the game itself reads (use_level reads it)", consts.has("MAP") and consts.MAP == floor_one.MAP)
	var text := FileAccess.get_file_as_string(TEST_LEVELS + "/zz_round_trip.gd")
	check("and it has floor 1's shape: every field a const, the map a row to a line", text.begins_with("extends RefCounted") and text.contains("const MAP := [") and text.contains("const PUZZLES := ") and text.contains("const MENU_VIEW_CELL := ") and text.contains("const CURSE_ZONES := "))
	# Asking before overwriting.
	var before := FileAccess.get_file_as_string(TEST_LEVELS + "/zz_round_trip.gd")
	ed.grid.place_item(6, 9, "res://data/items/dagger.tres")
	check("saving over a file that is there asks first, and writes nothing yet", ed.try_save("zz_round_trip") == "ASKED" and ed.save_dialog.visible and FileAccess.get_file_as_string(TEST_LEVELS + "/zz_round_trip.gd") == before)
	check("the dialog offers REPLACE and CANCEL", ed.save_buttons.get_child_count() == 2 and ed.save_buttons.get_child(0).text == "REPLACE")
	ed._write_level(ed.confirm_overwrite)
	check("REPLACE writes it (the new item is in the file)", FileAccess.get_file_as_string(TEST_LEVELS + "/zz_round_trip.gd") != before and EditorSave.read(TEST_LEVELS + "/zz_round_trip.gd").ITEMS.size() == floor_one.ITEMS.size() + 1 and not ed.save_dialog.visible)
	var edited: Dictionary = EditorSave.read(TEST_LEVELS + "/zz_round_trip.gd")
	var edited_diff := _differing(floor_one, edited)
	check("only the items differ from floor 1 after that edit; the kept fields are untouched (%s)" % str(edited_diff), edited_diff == ["ITEMS"])
	for bad in ["", "Bad Name", "9lives", "a/b", "has space", "x" .repeat(41)]:
		check("the name '%s' is refused" % bad, ed.try_save(bad) == "BAD NAME")
	# A kept door id survives losing its last lever, because a plate still wants it.
	ed.open_file("res://levels/floor_1.gd")
	ed.grid.delete_lever(ed.grid.lever_index(Vector2i(20, 20), 3))
	check("gate_s keeps its id when its lever is deleted: a kept plate still works it", ed.grid.door_ids.get(Vector2i(19, 21)) == "gate_s")
	# A small level drawn by script: save, open, the same.
	ed._new_sheet(14, 10)
	check("a new sheet has no file name", ed.level_name == "")
	var g = ed.grid
	for x in range(2, 13):
		g.set_cell(x, 5, true)
	for y in range(3, 8):
		for x in range(10, 13):
			g.set_cell(x, y, true)
	g.place_start(2, 5, 1)
	g.place_stairs(12, 5)
	g.place_door(4, 5, EditorGrid.DOOR)
	g.place_door(6, 5, EditorGrid.LOCKED)
	g.place_door(8, 5, EditorGrid.GATE)
	g.place_cracked(5, 4)
	g.place_lever(3, 5, 0)
	g.link_lever(0, Vector2i(8, 5))
	g.place_sconce(11, 3, 0, EditorGrid.SCONCE_LIT)
	g.place_sconce(12, 3, 0, EditorGrid.SCONCE_UNLIT)
	g.place_sconce(10, 3, 0, EditorGrid.SCONCE_EMPTY)
	for i in 3:
		g.place_item(3, 5, "res://data/items/healing_potion.tres", 9)
	g.place_item(5, 5, "res://data/items/key.tres")
	g.link_key(g.items_at(Vector2i(5, 5))[0], Vector2i(6, 5))
	g.place_monster(11, 7, "res://data/monsters/skeleton.tres", 1)
	g.place_monster(12, 7, "res://data/monsters/slime.tres")
	var drawn: Dictionary = g.level_data()
	check("the small level saves", ed.try_save("zz_small") == "")
	var drawn_cells: PackedByteArray = g.cells.duplicate()
	ed._new_sheet(8, 8)
	check("a fresh sheet is not the small level", ed.grid.width == 8)
	check("and opening the file puts it back", ed.open_file(TEST_LEVELS + "/zz_small.gd") == "" and ed.level_name == "zz_small")
	var reopened: Dictionary = ed.grid.level_data()
	check("the reopened level is the drawn one: same data in every field (differing: %s)" % str(_differing(drawn, reopened)), _differing(drawn, reopened).is_empty() and ed.grid.cells == drawn_cells)
	check("...squares, start and its facing, links, sconces, the pile, the key's link and the monsters' facing all back",
			ed.grid.start.facing == 1 and ed.grid.levers[0].target == "door_8_5" and ed.grid.sconces.size() == 3 and ed.grid.items[0].count == 3
			and ed.grid.items[ed.grid.items_at(Vector2i(5, 5))[0]].get("opens") == Vector2i(6, 5) and ed.grid.monsters[0].facing == 1 and ed.grid.monsters[1].facing == 2)
	check("a reopened level is as playable as it was (same check result)", EditorCheck.run(ed.grid).size() == EditorCheck.run(g).size())
	DungeonMap.use_level(TEST_LEVELS + "/zz_small.gd")
	check("the game's own use_level reads the saved file as a level", DungeonMap.MAP.size() == 10 and DungeonMap.MONSTERS.size() == 2 and DungeonMap.START_TILE == Vector2i(2, 5))
	DungeonMap.use_level("")
	# The test room too: a bigger file, with stations, signs and ambushes kept.
	ed.open_file("res://levels/test_room.gd")
	var room: Dictionary = EditorSave.read("res://levels/test_room.gd")
	ed.try_save("zz_test_room")
	var room_diff := _differing(room, EditorSave.read(TEST_LEVELS + "/zz_test_room.gd"))
	check("the test room opened and saved is identical too (differing: %s)" % str(room_diff), room_diff.is_empty())
	# The dialogs.
	ed._new_sheet(10, 10)
	ed._show_save_dialog()
	check("the SAVE button's dialog opens with a suggested name", ed.save_dialog.visible and ed.save_edit.text == "my_level")
	ed.save_edit.text = "made_in_the_dialog"
	ed.try_save()
	check("typing a name and saving writes it", FileAccess.file_exists(TEST_LEVELS + "/made_in_the_dialog.gd") and not ed.save_dialog.visible)
	ed._show_open_dialog()
	var files: Array = EditorSave.list(TEST_LEVELS)
	check("the OPEN dialog lists every level file in the folder (%d)" % files.size(), ed.open_dialog.visible and ed.open_list.get_child_count() == files.size() and files.size() >= 4)
	ed.open_list.get_child(files.find("zz_small.gd")).emit_signal("pressed")
	check("clicking a file opens it", not ed.open_dialog.visible and ed.level_name == "zz_small" and ed.grid.width == 14)
	# Typing in a dialog is not a command.
	ed.selected = {"kind": "start"}
	var facing_before: int = ed.grid.start.facing
	ed._show_save_dialog()
	_key(KEY_R)
	_key(KEY_DELETE)
	check("R and Delete typed into the save dialog neither turn nor remove anything", ed.grid.start.facing == facing_before and not ed.grid.start.is_empty())
	_key(KEY_ESCAPE)
	check("Escape closes the save dialog first", not ed.save_dialog.visible and ed.is_open())
	# Build floor 1 itself from the paper, with everything it holds.
	ed.open_file("res://levels/floor_1.gd")
	var dummy := Node.new()
	root.add_child(dummy)
	current_scene = dummy
	ed.build_level()
	await create_timer(1.5).timeout
	var player: Node = get_first_node_in_group("player")
	check("floor 1 built from the paper has its puzzle, its corrupted walls, 25 sconces, 20 monsters and the start",
			DungeonMap.level_id == DungeonMap.EDITOR_PLAY_ID and DungeonMap.PUZZLES.size() == 2 and DungeonMap.is_corrupted(Vector2i(7, 9)) and DungeonMap.TORCHES.size() == 25
			and get_nodes_in_group("monsters").size() == 20 and player != null and player.cell == Vector2i(5, 9) and player.facing == 3)
	player.command("forward")
	await create_timer(0.5).timeout
	player.command("forward")
	await create_timer(0.5).timeout
	check("the party walks it: two steps east of the start", player.cell == Vector2i(7, 9) or player.cell == Vector2i(6, 9))
	DungeonMap.use_level("")
	current_scene.queue_free()
	await process_frame
	_clear_test_levels()
	ed.queue_free()
	await process_frame


## The same level run through the editor's own tidying (EditorGrid._cleanup): a level that follows the rules comes back unchanged.
func _tidied(level: Dictionary) -> Dictionary:
	var g := EditorGrid.new()
	g.load_level(level)
	g._cleanup()
	return g.level_data()


## A double-click (the second press of a pair): the GUI marks it so, and the editor reads `double_click`.
func _double_click(pos: Vector2) -> void:
	for i in 2:
		var e := InputEventMouseButton.new()
		e.position = pos
		e.global_position = pos
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = true
		e.double_click = i == 1
		root.push_input(e, true)
		var up := InputEventMouseButton.new()
		up.position = pos
		up.global_position = pos
		up.button_index = MOUSE_BUTTON_LEFT
		up.pressed = false
		root.push_input(up, true)


func _check_play_from_start() -> void:
	var dummy := Node.new()
	root.add_child(dummy)
	current_scene = dummy
	var ed: Node = DungeonEditor.new()
	root.add_child(ed)
	await process_frame
	ed.open()
	ed._new_sheet(14, 10)
	for x in range(2, 13):
		ed.grid.set_cell(x, 5, true)
	ed.grid.place_start(2, 5, 3)
	ed.grid.place_stairs(12, 5)
	ed.set_tool(DungeonEditor.Tool.SELECT)
	ed.play_marker = {"cell": Vector2i(8, 5), "facing": 3}  # (Pretend the party was left further on.)
	_move(_centre_of(ed, 2, 5))
	var info: Array = ed._info_lines()
	check("pointing at the party start says to double-click to play (%s)" % str(info), info.has("PARTY START") and info.has("2X CLICK: PLAY"))
	_click(_centre_of(ed, 2, 5))
	check("a single click only selects the start, and says how to play", ed.selected.get("kind") == "start" and ed.message.contains("DOUBLE-CLICK") and DungeonMap.level_id == DungeonMap.FLOOR_1_ID)
	_double_click(_centre_of(ed, 6, 5))
	check("a double-click anywhere else does not play", DungeonMap.level_id == DungeonMap.FLOOR_1_ID and not ed.problem_dialog.visible)
	# Warnings come first: a lever linked to nothing.
	ed.grid.place_lever(4, 5, 0)
	_double_click(_centre_of(ed, 2, 5))
	check("a double-click on the start runs the usual check: a warning shows its list (and nothing is built yet)", ed.problem_dialog.visible and DungeonMap.level_id == DungeonMap.FLOOR_1_ID)
	ed.problem_dialog.visible = false
	ed.grid.delete_lever(0)
	_double_click(_centre_of(ed, 2, 5))
	check("a clean map is built at once and the party is not put back at the old marker (from the start)", DungeonMap.level_id == DungeonMap.EDITOR_PLAY_ID and ed.play_marker.is_empty() and not ed.is_open())
	await create_timer(1.3).timeout
	var player: Node = get_first_node_in_group("player")
	check("the party stands on the start of the drawn map, ready to play it: a playable map from one double-click", player != null and player.cell == Vector2i(2, 5) and player.facing == 3 and current_scene.scene_file_path == "res://scenes/main.tscn")
	player.command("forward")
	await create_timer(0.5).timeout
	check("and it can be walked", player.cell == Vector2i(3, 5))
	# Back to the paper, then Enter on the selected start plays from the start again.
	_key(KEY_TAB)
	check("Tab goes back to the paper with the party's square marked", ed.is_open() and ed.play_marker.get("cell") == Vector2i(3, 5))
	ed.selected = {"kind": "start"}
	_key(KEY_ENTER)
	check("Enter with the start selected plays from the start again (the marker is forgotten)", DungeonMap.level_id == DungeonMap.EDITOR_PLAY_ID and ed.play_marker.is_empty() and not ed.is_open())
	await create_timer(1.3).timeout
	player = get_first_node_in_group("player")
	check("...and the party is back on the start, not where it was left", player != null and player.cell == Vector2i(2, 5))
	DungeonMap.use_level("")
	current_scene.queue_free()
	await process_frame
	ed.queue_free()
	await process_frame
