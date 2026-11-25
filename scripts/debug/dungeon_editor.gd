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
## E.3 adds ITEM and MONSTER tools and a SIDE PANEL on the right. With the ITEM or MONSTER tool the panel lists every ItemDef in
## data/items or every MonsterDef in data/monsters (read from the folders when the editor starts, so a new one appears with no change
## here), each with its own small icon or sprite; click one, then a floor square, to place it. Items pile up like the game's floor piles
## (same item onto the top stack until it is full, else a new stack on top); a monster takes the square and faces a way (R turns the
## selected one). The wheel scrolls the list. Whatever the tool, the box at the foot of the panel says what is on the square under the
## mouse. SELECT picks a monster, then each stack of a pile (click the square again to go down the pile), then a door or stairs;
## Delete removes it. A key can be linked to a locked door like a lever (select the key, click the door, or the door then the key;
## clicking again unlinks): floor 1's keys open any locked door, so the link is for the editor (E.4 checks the level can be finished).
##
## E.4 adds BUILD. It first CHECKS the paper (editor_check.gd): no party start or no stairs down refuses the build; an unreachable
## square, item or monster, a lever or key linked to nothing, a locked door with no key and a gate with no lever are warnings, listed
## in a dialog and marked in red ink on the paper (the marks go at the next click). Then it hands the paper to
## DungeonMap.use_level_data (the same code that builds floor 1) under the id "editor:play" and loads the game scene: the ready-made
## four with full HP and mana and their starting gear stand on the start. TAB (or F10) in that game goes back to the paper (the
## game waits) with the party's square marked; Build again puts the party back on that square; Tab or Close goes back to the game.
## A level built here can never be saved to the real save slot (SaveGame.save refuses any level but floor 1). The editor lives at
## the tree root (DungeonMap.add_editor, group "dungeon_editor") so a Build changing the scene does not take it away.
##
## PLAY FROM THE START: double-click the party start (with the SELECT tool), or select it and press Enter, and the paper is built and
## played from there at once (the same check and build as the BUILD button, from the start rather than from where you left the party).
##
## E.5 adds SAVE and OPEN. SAVE asks for a name (lower case letters, digits and underscores) and writes levels/<name>.gd, a plain script
## of consts in the exact shape of levels/floor_1.gd (editor_save.gd); it asks before overwriting a file that is there. OPEN lists the
## .gd files in levels/ and puts one on the paper: opening levels/floor_1.gd shows floor 1 with everything the editor knows about
## (squares, doors, gates, stairs, the start, levers and their links, sconces, items, monsters). What the editor cannot edit yet (puzzles,
## curse zones, ambushes, plates, signs, armed traps, structures, corrupted walls, the menu camera) is KEPT untouched, shown in grey
## ("not editable yet") and written out again exactly as it came, so opening a level and saving it under a new name gives the same
## level back. Build plays an opened level with its puzzles and all.
##
## The paper is data (editor_grid.gd); this script draws it and turns the mouse and keys into strokes. Pixel rules: every line is one
## logical pixel, squares are a whole number of pixels (a multiple of 4, so the hatching of neighbours joins), no smooth gradients,
## palette colours only. The numbers (sheet size, zoom steps, undo depth) are in scripts/debug/editor_config.tres.

const EditorConfig := preload("res://scripts/debug/editor_config.gd")
const EditorGrid := preload("res://scripts/debug/editor_grid.gd")
const EditorCheck := preload("res://scripts/debug/editor_check.gd")
const EditorSave := preload("res://scripts/debug/editor_save.gd")
const DungeonMap := preload("res://scripts/dungeon_map.gd")
const RunState := preload("res://scripts/run_state.gd")
const SaveGame := preload("res://scripts/save_game.gd")
const MAIN_SCENE := "res://scenes/main.tscn"
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
const FRAME_RECT := Rect2(8, 46, 482, 294)   # The iron frame round the paper.
const BORDER := 4                            # Its thickness (map_frame.png).
const PAPER_RECT := Rect2(12, 50, 474, 286)  # The squared paper: the frame's inside.
const PANEL_FRAME := Rect2(494, 46, 138, 294)  # The side panel's frame...
const PANEL_RECT := Rect2(498, 50, 130, 286)   # ...and its inside: the list (items or monsters) above, what is under the mouse below.
const ROW_H := 18
const LIST_TOP := 14                         # Rows start this far down the panel (a heading above).
const INFO_H := 78                           # The "what is here" box at the foot of the panel.

enum Tool { DRAW, SELECT, DOOR, LOCKED, GATE, CRACKED, LEVER, STAIRS, START, SCONCE_LIT, SCONCE_UNLIT, SCONCE_EMPTY, ITEM, MONSTER }
const TOOL_ORDER := [Tool.DRAW, Tool.SELECT, Tool.DOOR, Tool.LOCKED, Tool.GATE, Tool.CRACKED, Tool.LEVER, Tool.STAIRS, Tool.START, Tool.SCONCE_LIT, Tool.SCONCE_UNLIT, Tool.SCONCE_EMPTY, Tool.ITEM, Tool.MONSTER]
const TOOL_NAMES := {Tool.DRAW: "DRAW", Tool.SELECT: "SELECT", Tool.DOOR: "DOOR", Tool.LOCKED: "LOCKED DOOR", Tool.GATE: "GATE", Tool.CRACKED: "CRACKED WALL",
		Tool.LEVER: "LEVER", Tool.STAIRS: "STAIRS DOWN", Tool.START: "PARTY START", Tool.SCONCE_LIT: "SCONCE LIT", Tool.SCONCE_UNLIT: "SCONCE UNLIT", Tool.SCONCE_EMPTY: "SCONCE EMPTY", Tool.ITEM: "ITEM", Tool.MONSTER: "MONSTER"}
const ICON_PATHS := {"item": "res://data/items", "monster": "res://data/monsters"}
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
var panel: Control
var item_list: Array = []         # [{"path": String, "name": String, "icon": Texture2D, "def": Resource}], from data/items.
var monster_list: Array = []      # The same, from data/monsters.
var brush_item := ""              # The item (path) the ITEM tool places, or "".
var brush_monster := ""           # The monster (path) the MONSTER tool places, or "".
var brush_facing := 2             # The way a newly placed monster faces (the last one turned to; south at first).
var list_scroll := 0
var panel_hover := -1             # The list row under the mouse, or -1.
var problems: Array = []          # The last check: [{"level": "error" | "warn", "text": String, "cells": Array}].
var marks: Array = []             # The squares the problems point at, marked in red ink until the next click on the paper.
var play_marker := {}             # Where the party stood when you came back to the paper from a build: {"cell": Vector2i, "facing": int}, or {}.
var pending_place := {}           # A square to put the party on once the built game has loaded.
var levels_dir := "res://levels"   # Where SAVE writes and OPEN looks (a test points it elsewhere).
var level_name := ""              # The file the paper came from or was last saved as (without .gd), or "".
var confirm_overwrite := ""       # The file the save dialog is waiting to be told it may replace, or "".
var save_dialog: PanelContainer
var save_edit: LineEdit
var save_note: Label
var save_buttons: HBoxContainer
var open_dialog: PanelContainer
var open_list: VBoxContainer
var problem_dialog: PanelContainer
var problem_lines: VBoxContainer
var problem_buttons: HBoxContainer

var root: Control
var paper: Control
var new_dialog: PanelContainer
var width_box: SpinBox
var height_box: SpinBox
var _tiles := {}                  # cell size -> the cross-hatched wall square (ImageTexture).
var _frame_box := StyleBoxTexture.new()


func _ready() -> void:
	for other in get_tree().get_nodes_in_group("dungeon_editor"):  # One editor at the tree root: a second one gives way.
		if other != self and not other.is_queued_for_deletion():
			queue_free()
			return
	add_to_group("dungeon_editor")
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
	_load_lists()
	_build_panel()
	_add_button("OPEN", Vector2(292, 3), _show_open_dialog, 56)
	_add_button("SAVE", Vector2(352, 3), _show_save_dialog, 56)
	_add_button("BUILD", Vector2(412, 3), request_build, 56)
	_add_button("NEW", Vector2(472, 3), _show_new_dialog, 56)
	_add_button("CLOSE", Vector2(532, 3), close, 56)
	_build_new_dialog()
	_build_problem_dialog()
	_build_save_dialog()
	_build_open_dialog()
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
	if _in_play():  # Back to the paper from the built game: note where the party stands.
		var party_square := get_tree().get_first_node_in_group("player")
		play_marker = {"cell": party_square.cell, "facing": int(party_square.facing)}
	var scene := get_tree().current_scene
	if scene != null and scene.scene_file_path.ends_with("main.tscn"):
		get_tree().paused = true  # In the game the world waits. (The main menu has nothing to pause.)
		opened_pause = true
	get_tree().call_group("party_hud", "cancel_casting")
	visible = true
	new_dialog.visible = false
	problem_dialog.visible = false
	save_dialog.visible = false
	open_dialog.visible = false
	mode = 0
	_redraw()


func close() -> void:
	if not visible:
		return
	visible = false
	mode = 0
	new_dialog.visible = false
	problem_dialog.visible = false
	save_dialog.visible = false
	open_dialog.visible = false
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
	if event.keycode == KEY_TAB and _in_play():  # Tab: from the built game to the paper and back.
		if visible:
			close()
		else:
			open()
		get_viewport().set_input_as_handled()
		return
	if not visible:
		return
	if event.keycode == KEY_ESCAPE:
		if save_dialog.visible:
			save_dialog.visible = false
		elif open_dialog.visible:
			open_dialog.visible = false
		elif problem_dialog.visible:
			problem_dialog.visible = false
		elif new_dialog.visible:
			new_dialog.visible = false
		elif not selected.is_empty():
			selected = {}
			_redraw()
		else:
			close()
		get_viewport().set_input_as_handled()
	elif (event.keycode == KEY_DELETE or event.keycode == KEY_BACKSPACE) and not _dialog_open():
		delete_selected()
		get_viewport().set_input_as_handled()
	elif (event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER) and selected.get("kind") == "start" and not _dialog_open():
		play_from_start()
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_R and not event.ctrl_pressed and not _dialog_open():
		rotate_selected()
		get_viewport().set_input_as_handled()
	elif event.ctrl_pressed and event.keycode == KEY_Z and not _dialog_open():
		if event.shift_pressed:
			redo()
		else:
			undo()
		get_viewport().set_input_as_handled()
	elif event.ctrl_pressed and event.keycode == KEY_Y and not _dialog_open():
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
	marks = []
	play_marker = {}
	level_name = ""
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
	if panel != null:
		panel.queue_redraw()


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
	if _dialog_open():
		return
	if event is InputEventMouseButton:
		var p: Vector2 = event.position
		if event.pressed and not marks.is_empty() and event.button_index != MOUSE_BUTTON_WHEEL_UP and event.button_index != MOUSE_BUTTON_WHEEL_DOWN:
			marks = []  # The red ink comes off at the next click.
			paper.queue_redraw()
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_zoom(1, p)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_zoom(-1, p)
		elif event.button_index == MOUSE_BUTTON_LEFT and tool != Tool.DRAW:
			if event.pressed:
				_use_tool(p, event.double_click)
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
	if not visible or _dialog_open():
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
	_frame_box.draw(root.get_canvas_item(), PANEL_FRAME)
	var font := root.get_theme_default_font()
	root.draw_string(font, Vector2(14, 15), "DUNGEON EDITOR", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, BONE_300)
	root.draw_string(font, Vector2(148, 15), "%dx%d  %d FLOOR" % [grid.width, grid.height, grid.floor_count()], HORIZONTAL_ALIGNMENT_LEFT, -1, 8, BONE_500)
	root.draw_string(font, Vector2(440, 33), "FILE: " + (level_name if level_name != "" else "(NEW)"), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, BONE_500)
	root.draw_string(font, Vector2(440, 43), "TOOL: " + TOOL_NAMES[tool], HORIZONTAL_ALIGNMENT_LEFT, -1, 8, BONE_300)
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


func _add_button(text: String, at: Vector2, on_press: Callable, width := 64.0) -> Button:
	var b := Button.new()
	b.text = text
	b.clip_text = true
	b.custom_minimum_size = Vector2(width, 16)
	_skin(b)
	b.pressed.connect(on_press)
	root.add_child(b)
	b.position = at
	b.size = Vector2(width, 16)
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
	if _dialog_open():
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
		Tool.ITEM:
			return "item"
		Tool.MONSTER:
			return "monster"
	return "sconce_empty"


func _say(text: String) -> void:
	message = text
	message_left = MESSAGE_SECONDS
	root.queue_redraw()


## A click on the paper with a thing tool: place, select or link.
func _use_tool(p: Vector2, double := false) -> void:
	var cell := cell_at(p)
	if double and tool == Tool.SELECT and cell.x >= 0 and not grid.start.is_empty() and grid.start.cell == cell:
		play_from_start()  # Double-click the party start: play the map from there.
		return
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
		Tool.ITEM:
			if cell.x >= 0:
				if brush_item == "":
					_say("PICK AN ITEM FROM THE LIST")
				else:
					var max_stack: int = int(load(brush_item).max_stack)
					var why := grid.place_item(cell.x, cell.y, brush_item, max_stack)
					_done(why, {"kind": "item", "index": grid.items_at(cell).back() if not grid.items_at(cell).is_empty() else 0})
		Tool.MONSTER:
			if cell.x >= 0:
				if brush_monster == "":
					_say("PICK A MONSTER FROM THE LIST")
				else:
					_done(grid.place_monster(cell.x, cell.y, brush_monster, brush_facing), {"kind": "monster", "index": grid.monsters.size() - 1})
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
	if selected.get("kind") == "item" and int(selected.index) < grid.items.size() and cell.x >= 0 and grid.type_at(cell.x, cell.y) == EditorGrid.LOCKED:
		var def: Resource = load(grid.items[int(selected.index)].def)
		if def != null and int(def.type) == 3:
			var why3 := grid.link_key(int(selected.index), cell)
			if why3 != "":
				_say(why3)
			_redraw()
			return true
	if selected.get("kind") == "cell" and grid.type_at(selected.cell.x, selected.cell.y) == EditorGrid.LOCKED and cell.x >= 0:
		var key := _key_at(cell)
		if key >= 0:
			var why4 := grid.link_key(key, selected.cell)
			if why4 != "":
				_say(why4)
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


func _key_at(cell: Vector2i) -> int:
	for i in grid.items_at(cell):
		var def: Resource = load(grid.items[i].def)
		if def != null and int(def.type) == 3:  # ItemDef.Type.KEY
			return i
	return -1


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
			var here := _cell_candidates(cell)
			if not here.is_empty():
				best = here[0]
				for i in here.size():  # Clicking the same square again goes on down the list: monster, the pile's stacks top first, door, start.
					if here[i] == selected:
						best = here[(i + 1) % here.size()]
	selected = best
	if best.get("kind") == "start":
		_say("DOUBLE-CLICK THE START TO PLAY")


## What can be selected on a square, in the order a click goes through them.
func _cell_candidates(cell: Vector2i) -> Array:
	var out := []
	var m := grid.monster_index_at(cell)
	if m >= 0:
		out.append({"kind": "monster", "index": m})
	var piles := grid.items_at(cell)
	piles.reverse()
	for i in piles:
		out.append({"kind": "item", "index": i})
	var t := grid.type_at(cell.x, cell.y)
	if grid.is_door_type(t) or t == EditorGrid.STAIRS or t == EditorGrid.CRACKED:
		out.append({"kind": "cell", "cell": cell})
	if not grid.start.is_empty() and grid.start.cell == cell:
		out.append({"kind": "start"})
	return out


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
		"item":
			grid.delete_item(int(selected.index))
		"monster":
			grid.delete_monster(int(selected.index))
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
		"monster":
			grid.rotate_monster(int(selected.index))
			if int(selected.index) < grid.monsters.size():
				brush_facing = int(grid.monsters[int(selected.index)].facing)
		"cell", "item":
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
		"item":
			if int(selected.index) >= grid.items.size():
				selected = {}
		"monster":
			if int(selected.index) >= grid.monsters.size():
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
			var kind: String = {EditorGrid.DOOR: "door", EditorGrid.LOCKED: "locked", EditorGrid.GATE: "gate", EditorGrid.STAIRS: "stairs", EditorGrid.CRACKED: "cracked", EditorGrid.CORRUPTED: "kept_wall"}[t]
			var axis := 0 if grid.is_wall_type(grid.type_at(x - 1, y)) and grid.is_wall_type(grid.type_at(x + 1, y)) else 1
			_icon(paper, kind, r, axis, 3)
	if not grid.start.is_empty():
		_icon(paper, "start", Rect2(origin + Vector2(grid.start.cell) * c, Vector2(c, c)).grow(-2.0), 0, int(grid.start.facing))
	_draw_items_and_monsters()
	for l in grid.levers:
		var lp := _face_pos(l.cell, l.side)
		_icon(paper, "lever", Rect2(lp - Vector2(c, c) * 0.3, Vector2(c, c) * 0.6), 0, 3)
	for sc in grid.sconces:
		var sp := _face_pos(sc.cell, sc.side)
		var skind: String = ["sconce_lit", "sconce_unlit", "sconce_empty"][int(sc.state)]
		_icon(paper, skind, Rect2(sp - Vector2(c, c) * 0.3, Vector2(c, c) * 0.6), 0, 3)
	_draw_kept()
	_draw_links()
	_draw_selection()
	_draw_marks()


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
		for it in grid.items:  # A locked door selected: a line to every key linked to it.
			if it.get("opens", Vector2i(-1, -1)) == selected.cell:
				paper.draw_line(_cell_centre(it.cell), _cell_centre(selected.cell), INK, 1.0)
	elif kind == "item" and int(selected.index) < grid.items.size():
		var key_item: Dictionary = grid.items[int(selected.index)]
		if key_item.has("opens"):
			paper.draw_line(_cell_centre(key_item.cell), _cell_centre(key_item.opens), INK, 1.0)


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
		"item":
			r = Rect2(origin + Vector2(grid.items[int(selected.index)].cell) * c, Vector2(c, c))
		"monster":
			r = Rect2(origin + Vector2(grid.monsters[int(selected.index)].cell) * c, Vector2(c, c))
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
		"start", "now":
			var tri: Array = [[Vector2(8, 1), Vector2(2, 14), Vector2(14, 14)], [Vector2(1, 8), Vector2(14, 2), Vector2(14, 14)],
					[Vector2(8, 15), Vector2(2, 2), Vector2(14, 2)], [Vector2(15, 8), Vector2(2, 2), Vector2(2, 14)]][facing]
			var pts := PackedVector2Array([o + tri[0] * s, o + tri[1] * s, o + tri[2] * s])
			ci.draw_colored_polygon(pts, TORCH_500 if kind == "now" else BLOOD_500)
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
		"kept_wall":
			var kw := Rect2(o + Vector2(1, 1) * s, Vector2(14, 14) * s)
			ci.draw_rect(kw, STONE_500)
			ci.draw_rect(kw, INK, false, w)
			ci.draw_line(o + Vector2(2, 14) * s, o + Vector2(14, 2) * s, STONE_300, w)
			ci.draw_line(o + Vector2(2, 9) * s, o + Vector2(9, 2) * s, STONE_300, w)
			ci.draw_line(o + Vector2(7, 14) * s, o + Vector2(14, 7) * s, STONE_300, w)
		"kept":
			var kd := PackedVector2Array([o + Vector2(8, 2) * s, o + Vector2(14, 8) * s, o + Vector2(8, 14) * s, o + Vector2(2, 8) * s])
			ci.draw_colored_polygon(kd, STONE_500)
			ci.draw_polyline(PackedVector2Array([kd[0], kd[1], kd[2], kd[3], kd[0]]), INK, w)
			ci.draw_rect(Rect2(o + Vector2(7, 7) * s, Vector2(2, 2) * s), STONE_100)
		"item":
			var flask := Rect2(o + Vector2(4, 7) * s, Vector2(8, 8) * s)
			ci.draw_rect(flask, STONE_300)
			ci.draw_rect(flask, INK, false, w)
			ci.draw_rect(Rect2(o + Vector2(6, 3) * s, Vector2(4, 4) * s), STONE_100)
			ci.draw_rect(Rect2(o + Vector2(6, 3) * s, Vector2(4, 4) * s), INK, false, w)
			ci.draw_rect(Rect2(o + Vector2(7, 1) * s, Vector2(2, 2) * s), LEATHER_400)
			ci.draw_rect(Rect2(o + Vector2(5, 10) * s, Vector2(6, 4) * s), BLOOD_500)
		"monster":
			var skull := Rect2(o + Vector2(3, 2) * s, Vector2(10, 9) * s)
			ci.draw_rect(skull, BONE_300)
			ci.draw_rect(skull, INK, false, w)
			ci.draw_rect(Rect2(o + Vector2(4, 11) * s, Vector2(8, 4) * s), BONE_300)
			ci.draw_rect(Rect2(o + Vector2(4, 11) * s, Vector2(8, 4) * s), INK, false, w)
			ci.draw_rect(Rect2(o + Vector2(5, 5) * s, Vector2(2, 3) * s), INK)
			ci.draw_rect(Rect2(o + Vector2(9, 5) * s, Vector2(2, 3) * s), INK)
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


# --------------------------------------------------------------------------
# Items and monsters (E.3): the lists, the side panel, the pieces on the paper
# --------------------------------------------------------------------------

## Every ItemDef in data/items and MonsterDef in data/monsters, read from the folders (so a new one appears here by itself).
func _load_lists() -> void:
	item_list = _scan("res://data/items", false)
	monster_list = _scan("res://data/monsters", true)


func _scan(dir: String, monsters: bool) -> Array:
	var out := []
	var d := DirAccess.open(dir)
	if d == null:
		return out
	for f in d.get_files():
		var file := f.trim_suffix(".remap")
		if not file.ends_with(".tres"):
			continue
		var path := dir + "/" + file
		var def: Resource = load(path)
		if def == null:
			continue
		var icon: Texture2D = null
		if monsters:
			icon = _monster_frame(def)
		else:
			icon = def.hud_texture()
		out.append({"path": path, "name": str(def.display_name).to_upper(), "icon": icon, "def": def})
	out.sort_custom(func(a, b): return a.name < b.name)
	return out


## A monster's first idle frame, cut from its sheet.
func _monster_frame(def: Resource) -> Texture2D:
	if def.sheet == null:
		return null
	var frames: int = maxi(1, int(def.hframes))
	var fw: float = float(def.sheet.get_width()) / frames
	var tex := AtlasTexture.new()
	tex.atlas = def.sheet
	tex.region = Rect2(int(def.idle_frames[0]) * fw if def.idle_frames.size() > 0 else 0.0, 0.0, fw, float(def.sheet.get_height()))
	return tex


func _entry(path: String, monsters: bool) -> Dictionary:
	for e in (monster_list if monsters else item_list):
		if e.path == path:
			return e
	return {}


func _build_panel() -> void:
	panel = Control.new()
	panel.position = PANEL_RECT.position
	panel.size = PANEL_RECT.size
	panel.clip_contents = true
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	panel.draw.connect(_draw_panel)
	panel.gui_input.connect(_panel_input)
	panel.mouse_exited.connect(func(): panel_hover = -1; panel.queue_redraw())
	root.add_child(panel)


## The list the panel shows now, or [] (the info box alone) for the other tools.
func _current_list() -> Array:
	if tool == Tool.ITEM:
		return item_list
	if tool == Tool.MONSTER:
		return monster_list
	return []


func _visible_rows() -> int:
	return int((PANEL_RECT.size.y - INFO_H - LIST_TOP) / ROW_H)


func _panel_input(event: InputEvent) -> void:
	if _dialog_open():
		return
	var list := _current_list()
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			list_scroll = maxi(0, list_scroll - 1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			list_scroll = clampi(list_scroll + 1, 0, maxi(0, list.size() - _visible_rows()))
		elif event.button_index == MOUSE_BUTTON_LEFT:
			var row := _row_at(event.position)
			if row >= 0 and row < list.size():
				if tool == Tool.ITEM:
					brush_item = list[row].path
				else:
					brush_monster = list[row].path
		panel.queue_redraw()
	elif event is InputEventMouseMotion:
		var row2 := _row_at(event.position)
		if row2 != panel_hover:
			panel_hover = row2
			panel.queue_redraw()


func _row_at(p: Vector2) -> int:
	if p.y < LIST_TOP or p.y >= PANEL_RECT.size.y - INFO_H:
		return -1
	return list_scroll + int((p.y - LIST_TOP) / ROW_H)


func select_brush(path: String) -> void:
	if tool == Tool.MONSTER:
		brush_monster = path
	else:
		brush_item = path
	_redraw()


func _draw_panel() -> void:
	var font := panel.get_theme_default_font()
	var size := PANEL_RECT.size
	panel.draw_rect(Rect2(Vector2.ZERO, size), STONE_900)
	var list := _current_list()
	if tool == Tool.ITEM or tool == Tool.MONSTER:
		panel.draw_string(font, Vector2(4, 10), "ITEMS" if tool == Tool.ITEM else "MONSTERS", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, BONE_300)
		var count := "%d" % list.size()
		panel.draw_string(font, Vector2(size.x - 4 - count.length() * 8, 10), count, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, BONE_700)
		var brush := brush_item if tool == Tool.ITEM else brush_monster
		var rows := _visible_rows()
		for i in rows:
			var idx := list_scroll + i
			if idx >= list.size():
				break
			var e: Dictionary = list[idx]
			var y := LIST_TOP + i * ROW_H
			var row := Rect2(0, y, size.x, ROW_H - 1)
			if e.path == brush:
				panel.draw_rect(row, RUST_700)
				panel.draw_rect(row, BONE_300, false, 1.0)
			elif idx == panel_hover:
				panel.draw_rect(row, STONE_700)
			if e.icon != null:
				panel.draw_texture_rect(e.icon, Rect2(2, y + 1, 16, 16), false)
			panel.draw_string(font, Vector2(21, y + 12), e.name.substr(0, 13), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, BONE_300 if e.path == brush else BONE_500)
		if list.size() > rows:  # A scroll mark down the right edge.
			var track := size.y - INFO_H - LIST_TOP
			var thumb := maxf(8.0, track * rows / float(list.size()))
			var top := LIST_TOP + (track - thumb) * list_scroll / float(maxi(1, list.size() - rows))
			panel.draw_rect(Rect2(size.x - 3, top, 3, thumb), BONE_700)
	else:
		var kept_lines := _kept_summary()
		if kept_lines.is_empty():
			panel.draw_string(font, Vector2(4, 10), "THE LISTS", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, BONE_300)
			for i in 3:
				panel.draw_string(font, Vector2(4, 28 + i * 10), ["PICK THE ITEM OR", "MONSTER TOOL TO", "PLACE THEM"][i], HORIZONTAL_ALIGNMENT_LEFT, -1, 8, BONE_700)
		else:
			panel.draw_string(font, Vector2(4, 10), "KEPT (GREY):", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, STONE_100)
			panel.draw_string(font, Vector2(4, 20), "NOT EDITABLE YET", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, STONE_300)
			for i in mini(kept_lines.size(), 12):
				panel.draw_string(font, Vector2(4, 36 + i * 10), kept_lines[i].substr(0, 15), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, STONE_300)
	# The foot: what is under the mouse (or, with nothing there, what is selected).
	var box := Rect2(0, size.y - INFO_H, size.x, INFO_H)
	panel.draw_rect(box, STONE_700)
	panel.draw_rect(box, RUST_500, false, 1.0)
	var lines := _info_lines()
	for i in mini(lines.size(), 7):
		panel.draw_string(font, Vector2(4, box.position.y + 11 + i * 10), lines[i].substr(0, 15), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, BONE_300 if i == 0 else BONE_500)


## What is on a square, in short lines (15 characters fit): the square, its tile, a monster, the pile, a start, a link.
func _info_lines() -> Array:
	var cell := hover
	if cell.x < 0:
		var kind: String = selected.get("kind", "")
		if kind == "monster" and int(selected.index) < grid.monsters.size():
			cell = grid.monsters[int(selected.index)].cell
		elif kind == "item" and int(selected.index) < grid.items.size():
			cell = grid.items[int(selected.index)].cell
		elif kind == "cell":
			cell = selected.cell
		else:
			return ["(-,-)", "MOUSE OVER A", "SQUARE"]
	var names := {EditorGrid.FLOOR: "FLOOR", EditorGrid.WALL: "WALL", EditorGrid.DOOR: "DOOR", EditorGrid.LOCKED: "LOCKED DOOR", EditorGrid.STAIRS: "STAIRS DOWN", EditorGrid.GATE: "GATE", EditorGrid.CRACKED: "CRACKED WALL", EditorGrid.CORRUPTED: "CORRUPTED WALL"}
	var lines := ["(%d,%d)" % [cell.x, cell.y], names[grid.type_at(cell.x, cell.y)]]
	if not grid.start.is_empty() and grid.start.cell == cell:
		lines.append("PARTY START")
		lines.append("2X CLICK: PLAY")
	for kept in _kept_at(cell):
		lines.append("KEPT: " + kept)
	var m := grid.monster_index_at(cell)
	if m >= 0:
		var entry := _entry(grid.monsters[m].def, true)
		lines.append(str(entry.get("name", "MONSTER")))
		var tier := ("TIER %d" % int(entry.def.tier)) if entry.has("def") else ""
		lines.append("%s FACES %s" % [tier, ["N", "W", "S", "E"][int(grid.monsters[m].facing)]])
	var piles := grid.items_at(cell)
	piles.reverse()
	for i in piles:
		var it: Dictionary = grid.items[i]
		var e := _entry(it.def, false)
		var label := str(e.get("name", "ITEM"))
		if int(it.count) > 1:
			label = "%s X%d" % [label.substr(0, 11), int(it.count)]
		lines.append(label)
		if it.has("opens"):
			lines.append("OPENS (%d,%d)" % [it.opens.x, it.opens.y])
	return lines


func _draw_items_and_monsters() -> void:
	var c := float(cell_px)
	var font := paper.get_theme_default_font()
	var done := {}
	for it in grid.items:
		if done.has(it.cell):
			continue
		done[it.cell] = true
		var cx: float = origin.x + it.cell.x * c
		var cy: float = origin.y + it.cell.y * c
		if cx + c < 0.0 or cx > PAPER_RECT.size.x or cy + c < 0.0 or cy > PAPER_RECT.size.y:
			continue
		var pile := grid.items_at(it.cell)
		var top: Dictionary = grid.items[pile[pile.size() - 1]]
		for k in mini(pile.size(), 3):  # A pile shows up to three stacks, each a little behind the one above.
			var stack: Dictionary = grid.items[pile[pile.size() - 1 - (mini(pile.size(), 3) - 1 - k)]]
			var e := _entry(stack.def, false)
			if e.is_empty() or e.icon == null:
				continue
			var size := c * 0.62
			var shift := (mini(pile.size(), 3) - 1 - k) * -c * 0.1
			paper.draw_texture_rect(e.icon, Rect2(Vector2(cx, cy) + Vector2(c, c) * 0.5 - Vector2(size, size) * 0.5 + Vector2(shift, shift), Vector2(size, size)), false)
		if int(top.count) > 1 and cell_px >= 20:
			var label := str(int(top.count))
			paper.draw_rect(Rect2(cx + c - label.length() * 8 - 2, cy + c - 10, label.length() * 8 + 2, 10), STONE_900)
			paper.draw_string(font, Vector2(cx + c - label.length() * 8 - 1, cy + c - 2), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, BONE_300)
		if top.has("opens"):  # A key linked to a locked door wears a small red tick.
			paper.draw_rect(Rect2(cx + 2, cy + 2, 4, 4), BLOOD_500)
	for m in grid.monsters:
		var mx: float = origin.x + m.cell.x * c
		var my: float = origin.y + m.cell.y * c
		if mx + c < 0.0 or mx > PAPER_RECT.size.x or my + c < 0.0 or my > PAPER_RECT.size.y:
			continue
		var me := _entry(m.def, true)
		if not me.is_empty() and me.icon != null:
			var ms := c * 1.5
			paper.draw_texture_rect(me.icon, Rect2(Vector2(mx, my) + Vector2(c, c) * 0.5 - Vector2(ms, ms) * 0.5 + Vector2(0, -c * 0.18), Vector2(ms, ms)), false)
		else:
			paper.draw_rect(Rect2(mx + 3, my + 3, c - 6, c - 6), BLOOD_500)
		# Which way it faces: a small ink triangle on that side of the square.
		var d := Vector2(EditorGrid.DIRS[int(m.facing)])
		var side := Vector2(-d.y, d.x)
		var base := Vector2(mx, my) + Vector2(c, c) * 0.5 + d * c * 0.42
		paper.draw_colored_polygon(PackedVector2Array([base + d * c * 0.08, base - d * c * 0.1 + side * c * 0.14, base - d * c * 0.1 - side * c * 0.14]), BLOOD_500)
		paper.draw_polyline(PackedVector2Array([base + d * c * 0.08, base - d * c * 0.1 + side * c * 0.14, base - d * c * 0.1 - side * c * 0.14, base + d * c * 0.08]), INK, 1.0)


# --------------------------------------------------------------------------
# Build and play (E.4)
# --------------------------------------------------------------------------

## Is the built game running (a level built from this paper, in the game scene, with a party)?
func _in_play() -> bool:
	var scene := get_tree().current_scene
	return DungeonMap.level_id == DungeonMap.EDITOR_PLAY_ID and scene != null and scene.scene_file_path == MAIN_SCENE \
			and get_tree().get_first_node_in_group("player") != null


## The BUILD button: check the paper, then build it, or list what is wrong first.
func request_build() -> void:
	if _dialog_open():
		return
	problems = EditorCheck.run(grid)
	marks = EditorCheck.marked_cells(problems)
	if problems.is_empty():
		build_level()
	else:
		_show_problems()
	_redraw()


## Hand the paper to the game: the same level code as floor 1 (DungeonMap.use_level_data), the ready-made four on the start (or where
## they stood when you came back to the paper), and the game scene loaded fresh. Nothing is saved.
func build_level() -> void:
	if grid.start.is_empty():
		_say("A BUILD NEEDS A PARTY START")
		return
	pending_place = {}
	if not play_marker.is_empty() and grid.type_at(play_marker.cell.x, play_marker.cell.y) == EditorGrid.FLOOR:
		pending_place = play_marker.duplicate()  # Build again: the party goes back where it was.
	play_marker = {}
	marks = []
	DungeonMap.use_level_data(grid.level_data(), DungeonMap.EDITOR_PLAY_ID)
	RunState.clear()  # A fresh party: nothing carried over, and no waiting save.
	SaveGame.pending = {}
	problem_dialog.visible = false
	new_dialog.visible = false
	save_dialog.visible = false
	open_dialog.visible = false
	visible = false
	opened_pause = false
	get_tree().paused = false
	get_tree().change_scene_to_file(MAIN_SCENE)
	_place_party_when_loaded()


## Once the new game scene stands, put the party on the square it left.
func _place_party_when_loaded() -> void:
	if pending_place.is_empty():
		return
	for i in 120:
		await get_tree().process_frame
		var scene := get_tree().current_scene
		var player := get_tree().get_first_node_in_group("player")
		if scene != null and scene.scene_file_path == MAIN_SCENE and player != null and scene.is_ancestor_of(player) and player.is_node_ready():
			await get_tree().process_frame
			player.restore(pending_place.cell, int(pending_place.facing))
			pending_place = {}
			return
	pending_place = {}


func _build_problem_dialog() -> void:
	problem_dialog = PanelContainer.new()
	problem_dialog.add_theme_stylebox_override("panel", _style(STONE_900, RUST_500))
	problem_dialog.visible = false
	problem_dialog.mouse_filter = Control.MOUSE_FILTER_STOP
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	problem_dialog.add_child(box)
	var title := Label.new()
	title.text = "BUILD CHECK"
	title.add_theme_font_size_override("font_size", 8)
	title.add_theme_color_override("font_color", BONE_300)
	box.add_child(title)
	problem_lines = VBoxContainer.new()
	problem_lines.add_theme_constant_override("separation", 3)
	box.add_child(problem_lines)
	problem_buttons = HBoxContainer.new()
	problem_buttons.add_theme_constant_override("separation", 6)
	box.add_child(problem_buttons)
	root.add_child(problem_dialog)
	problem_dialog.position = Vector2(120, 80)


## List the problems: errors in red ink (the build is refused), warnings in bone (the build may go on).
func _show_problems() -> void:
	for c in problem_lines.get_children():
		problem_lines.remove_child(c)
		c.queue_free()
	for c in problem_buttons.get_children():
		problem_buttons.remove_child(c)
		c.queue_free()
	var refused := EditorCheck.has_errors(problems)
	var shown := 0
	for pr in problems:
		if shown >= 9:
			break
		var l := Label.new()
		l.text = ("X " if pr.level == "error" else "! ") + pr.text
		l.add_theme_font_size_override("font_size", 8)
		l.add_theme_color_override("font_color", Color("a8673a") if pr.level == "error" else BONE_300)
		problem_lines.add_child(l)
		shown += 1
	if problems.size() > shown:
		var more := Label.new()
		more.text = "... AND %d MORE" % (problems.size() - shown)
		more.add_theme_font_size_override("font_size", 8)
		more.add_theme_color_override("font_color", BONE_700)
		problem_lines.add_child(more)
	var note := Label.new()
	note.text = "THE BUILD IS REFUSED." if refused else "THE LEVEL CAN STILL BE BUILT."
	note.add_theme_font_size_override("font_size", 8)
	note.add_theme_color_override("font_color", BONE_500)
	problem_lines.add_child(note)
	if refused:
		_dialog_button("OK", func(): problem_dialog.visible = false)
	else:
		_dialog_button("BUILD ANYWAY", build_level)
		_dialog_button("CANCEL", func(): problem_dialog.visible = false)
	problem_dialog.visible = true


func _dialog_button(text: String, on_press: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(88 if text == "BUILD ANYWAY" else 64, 16)
	_skin(b)
	b.pressed.connect(on_press)
	problem_buttons.add_child(b)


## The squares the check points at, in red ink (a box and a cross), and the party's square from the game you came back from.
func _draw_marks() -> void:
	var c := float(cell_px)
	for m in marks:
		var r := Rect2(origin + Vector2(m) * c, Vector2(c, c)).grow(-1.0)
		paper.draw_rect(r, BLOOD_500, false, 2.0)
		paper.draw_line(r.position, r.end, BLOOD_500, 1.0)
		paper.draw_line(Vector2(r.end.x, r.position.y), Vector2(r.position.x, r.end.y), BLOOD_500, 1.0)
	if not play_marker.is_empty():
		_icon(paper, "now", Rect2(origin + Vector2(play_marker.cell) * c, Vector2(c, c)).grow(-2.0), 0, int(play_marker.facing))


# --------------------------------------------------------------------------
# Save and open (E.5)
# --------------------------------------------------------------------------

func _dialog_open() -> bool:
	return new_dialog.visible or problem_dialog.visible or save_dialog.visible or open_dialog.visible


func _build_save_dialog() -> void:
	save_dialog = PanelContainer.new()
	save_dialog.add_theme_stylebox_override("panel", _style(STONE_900, RUST_500))
	save_dialog.visible = false
	save_dialog.mouse_filter = Control.MOUSE_FILTER_STOP
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	save_dialog.add_child(box)
	var title := Label.new()
	title.text = "SAVE LEVEL"
	title.add_theme_font_size_override("font_size", 8)
	title.add_theme_color_override("font_color", BONE_300)
	box.add_child(title)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	box.add_child(row)
	var label := Label.new()
	label.text = "NAME"
	label.custom_minimum_size = Vector2(40, 0)
	label.add_theme_font_size_override("font_size", 8)
	label.add_theme_color_override("font_color", BONE_500)
	row.add_child(label)
	save_edit = LineEdit.new()
	save_edit.custom_minimum_size = Vector2(176, 0)
	save_edit.max_length = 40
	save_edit.add_theme_font_size_override("font_size", 8)
	save_edit.text_changed.connect(func(_t): _save_name_changed())
	save_edit.text_submitted.connect(func(_t): try_save())
	row.add_child(save_edit)
	save_note = Label.new()
	save_note.add_theme_font_size_override("font_size", 8)
	save_note.add_theme_color_override("font_color", BONE_700)
	box.add_child(save_note)
	save_buttons = HBoxContainer.new()
	save_buttons.add_theme_constant_override("separation", 6)
	box.add_child(save_buttons)
	root.add_child(save_dialog)
	save_dialog.position = Vector2(150, 100)


func _show_save_dialog() -> void:
	if _dialog_open():
		return
	confirm_overwrite = ""
	save_edit.text = level_name if level_name != "" else "my_level"
	save_note.text = "WRITES levels/NAME.gd"
	_save_buttons(false)
	save_dialog.visible = true
	save_edit.grab_focus()
	save_edit.select_all()


func _save_name_changed() -> void:
	confirm_overwrite = ""
	save_note.text = "WRITES levels/NAME.gd"
	_save_buttons(false)


func _save_buttons(confirm: bool) -> void:
	for c in save_buttons.get_children():
		save_buttons.remove_child(c)
		c.queue_free()
	var go := Button.new()
	go.text = "REPLACE" if confirm else "SAVE"
	go.custom_minimum_size = Vector2(72 if confirm else 64, 16)
	_skin(go)
	go.pressed.connect(func(): _write_level(confirm_overwrite) if confirm else try_save())
	save_buttons.add_child(go)
	var cancel := Button.new()
	cancel.text = "CANCEL"
	cancel.custom_minimum_size = Vector2(64, 16)
	_skin(cancel)
	cancel.pressed.connect(func(): save_dialog.visible = false)
	save_buttons.add_child(cancel)


## Save the paper as levels/<name>.gd. A bad name is refused, and a file that is already there is only replaced once the player says so (the
## dialog turns into REPLACE / CANCEL). Returns "" if it was written, "ASKED" if it is waiting to be told to replace, else the reason.
func try_save(name := "") -> String:
	var n := (name if name != "" else save_edit.text).strip_edges().to_lower()
	if not EditorSave.valid_name(n):
		save_note.text = "LOWER CASE, DIGITS AND _ ONLY"
		return "BAD NAME"
	var path := levels_dir.path_join(n + ".gd")
	if FileAccess.file_exists(path) and confirm_overwrite != path:
		confirm_overwrite = path
		save_note.text = n.to_upper() + " IS THERE. REPLACE IT?"
		_save_buttons(true)
		save_dialog.visible = true
		return "ASKED"
	return _write_level(path)


func _write_level(path: String) -> String:
	var n := path.get_file().get_basename()
	var why := EditorSave.save(path, grid.level_data(), n + ".gd")
	if why != "":
		save_note.text = why
		return why
	level_name = n
	confirm_overwrite = ""
	save_dialog.visible = false
	_say("SAVED " + n.to_upper())
	_redraw()
	return ""


func _build_open_dialog() -> void:
	open_dialog = PanelContainer.new()
	open_dialog.add_theme_stylebox_override("panel", _style(STONE_900, RUST_500))
	open_dialog.visible = false
	open_dialog.mouse_filter = Control.MOUSE_FILTER_STOP
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	open_dialog.add_child(box)
	var title := Label.new()
	title.text = "OPEN LEVEL"
	title.add_theme_font_size_override("font_size", 8)
	title.add_theme_color_override("font_color", BONE_300)
	box.add_child(title)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(240, 140)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	open_list = VBoxContainer.new()
	open_list.add_theme_constant_override("separation", 3)
	scroll.add_child(open_list)
	var cancel := Button.new()
	cancel.text = "CANCEL"
	cancel.custom_minimum_size = Vector2(64, 16)
	_skin(cancel)
	cancel.pressed.connect(func(): open_dialog.visible = false)
	box.add_child(cancel)
	root.add_child(open_dialog)
	open_dialog.position = Vector2(170, 70)


func _show_open_dialog() -> void:
	if _dialog_open():
		return
	for c in open_list.get_children():
		open_list.remove_child(c)
		c.queue_free()
	var files := EditorSave.list(levels_dir)
	if files.is_empty():
		var none := Label.new()
		none.text = "NO LEVEL FILES IN " + levels_dir.get_file()
		none.add_theme_font_size_override("font_size", 8)
		none.add_theme_color_override("font_color", BONE_700)
		open_list.add_child(none)
	for f in files:
		var b := Button.new()
		b.text = f.get_basename().to_upper()
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(228, 16)
		_skin(b)
		var path: String = levels_dir.path_join(f)
		b.pressed.connect(func(): open_file(path))
		open_list.add_child(b)
	open_dialog.visible = true


## Put a level file on the paper. "" if it did, else why not. Everything the editor knows is shown; the rest is kept (see EditorGrid.load_level).
func open_file(path: String) -> String:
	var data := EditorSave.read(path)
	if data.is_empty():
		_say("NOT A LEVEL FILE")
		return "NOT A LEVEL FILE"
	grid.load_level(data, cfg.undo_steps)
	level_name = path.get_file().get_basename()
	open_dialog.visible = false
	selected = {}
	marks = []
	play_marker = {}
	hover = Vector2i(-1, -1)
	mode = 0
	_fit_zoom()
	_centre()
	_say("OPENED " + level_name.to_upper())
	_redraw()
	return ""


## The biggest square size, up to the opening zoom, at which the sheet's WIDTH fits the paper (the smallest if none does): a tall sheet is
## then panned up and down rather than shown too small to read.
func _fit_zoom() -> void:
	zoom_index = 0
	for i in range(clampi(int(cfg.start_zoom), 0, cfg.cell_sizes.size() - 1), -1, -1):
		if cfg.cell_sizes[i] * grid.width <= PAPER_RECT.size.x:
			zoom_index = i
			break
	cell_px = cfg.cell_sizes[zoom_index]


## The kept things on a square (names), for the info box.
func _kept_at(cell: Vector2i) -> Array:
	var out := []
	for p in grid.extras.get("PLATES", []):
		if p.get("cell") == cell:
			out.append("PLATE")
	for a in grid.extras.get("AMBUSHES", []):
		if a.get("trigger") == cell:
			out.append("AMBUSH")
	for t in grid.extras.get("ARMED_TRAPS", []):
		if t.get("cell") == cell:
			out.append("ARMED TRAP")
	for sg in grid.extras.get("SIGNS", []):
		if sg.get("cell") == cell:
			out.append("SIGN")
	for st in grid.extras.get("STRUCTURES", []):
		if st.get("cell") == cell:
			out.append(str(st.get("kind", "STRUCTURE")).to_upper())
	for z in grid.extras.get("CURSE_ZONES", []):
		if z.get("tiles", []).has(cell):
			out.append("CURSE ZONE")
	return out


## What the editor is holding untouched, as short lines (for the panel).
func _kept_summary() -> Array:
	var out := []
	var counts := [["PUZZLES", "PUZZLES"], ["PLATES", "PLATES"], ["CURSE_ZONES", "CURSE ZONES"], ["AREAS", "AREAS"], ["BRAZIERS", "BRAZIERS"], ["AMBUSHES", "AMBUSHES"], ["SIGNS", "SIGNS"],
			["ARMED_TRAPS", "ARMED TRAPS"], ["STRUCTURES", "STRUCTURES"]]
	for c in counts:
		var n: int = grid.extras.get(c[0], []).size()
		if n > 0:
			out.append("%d %s" % [n, c[1]])
	var corrupted := 0
	for code in grid.cells:
		if code == EditorGrid.CORRUPTED:
			corrupted += 1
	if corrupted > 0:
		out.append("%d CORRUPTED" % corrupted)
	for st in grid.extras.get("STATIONS", []):
		out.append("STATIONS")
		break
	return out


## Grey marks for what is kept and not editable yet: plates, ambush triggers, armed traps, signs, structures (a small grey diamond in the
## square's corner) and curse zones (a grey outline on each square). Corrupted walls are drawn as grey hatched squares with the doors.
func _draw_kept() -> void:
	if grid.extras.is_empty():
		return
	var c := float(cell_px)
	var spots := []
	for p in grid.extras.get("PLATES", []):
		spots.append(p.get("cell"))
	for a in grid.extras.get("AMBUSHES", []):
		spots.append(a.get("trigger"))
	for t in grid.extras.get("ARMED_TRAPS", []):
		spots.append(t.get("cell"))
	for sg in grid.extras.get("SIGNS", []):
		spots.append(sg.get("cell"))
	for st in grid.extras.get("STRUCTURES", []):
		spots.append(st.get("cell"))
	for z in grid.extras.get("CURSE_ZONES", []):
		for tile in z.get("tiles", []):
			var zr := Rect2(origin + Vector2(tile) * c, Vector2(c, c)).grow(-3.0)
			paper.draw_rect(zr, STONE_300, false, 1.0)
	for cell in spots:
		if cell is Vector2i:
			paper.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			_icon(paper, "kept", Rect2(origin + Vector2(cell) * c + Vector2(c * 0.52, c * 0.02), Vector2(c * 0.46, c * 0.46)), 0, 3)


## Play the map from the party start: forget where the party was left (this is "from the beginning") and build, with the usual check.
func play_from_start() -> void:
	if grid.start.is_empty():
		_say("PLACE A PARTY START FIRST")
		return
	play_marker = {}
	request_build()
