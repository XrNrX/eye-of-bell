extends RefCounted
## The dungeon editor's paper as data (dungeon_editor.gd draws and edits it): a width x height grid of squares holding the SAME tile
## codes as a level's MAP (levels/floor_1.gd): 0 floor (blank paper), 1 wall (the default: solid rock), 2 door, 3 locked door,
## 4 stairs down, 5 portcullis (a gate), 6 cracked wall. On top of the squares sit the things that are not whole squares: the party
## start (one, with the way it faces), wall levers and wall sconces (each on one face of a floor square) and the links from levers to
## doors. E.3 adds the things that lie or stand on a floor square: items (in piles, like the game's) and monsters. They use floor 1's
## own data shapes (LEVERS, DOOR_IDS, TORCHES, START_TILE, START_FACING, ITEMS, MONSTERS), see level_data().
##
## E.5 lets a whole level file be opened (load_level) and written again (level_data): what the editor does not edit yet (puzzles, curse
## zones, ambushes, plates, signs, armed traps, structures, corrupted walls, the menu camera) is held untouched in `extras` and goes out
## again exactly as it came in, so opening floor 1 and saving it gives floor 1 back.
##
## The outer edge always stays wall: nothing is placed on it. Painting (set_cell) only turns plain floor into wall and back; the other
## things are placed by their own calls, which refuse, with a short reason, anything the game would not allow (a door needs a wall on
## each side of it, a sconce or lever needs a wall face, and so on). After any change, things that no longer make sense (a lever
## whose wall was painted away, a door that became floor) are dropped (_cleanup).
##
## A STROKE is one action: begin_stroke, any number of changes, end_stroke; undo and redo take back or put back the whole stroke,
## squares AND things. A change made outside a stroke is a stroke of one. Only the last `undo_limit` strokes are kept; a new stroke
## clears what could have been redone.

const FLOOR := 0
const WALL := 1
const DOOR := 2
const LOCKED := 3
const STAIRS := 4
const GATE := 5
const CRACKED := 6
const CORRUPTED := 7  # Overgrown with the curse: the editor shows it, keeps it and cannot change it yet.
const DIRS := [Vector2i(0, -1), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(1, 0)]  # Sides: 0 north, 1 west, 2 south, 3 east (as the game's).
const SCONCE_LIT := 0
const SCONCE_UNLIT := 1
const SCONCE_EMPTY := 2
## The fields of a level the editor does not edit yet: kept untouched (see load_level).
const KEPT := ["CORRUPTION", "PUZZLES", "PLATES", "STRUCTURES", "SIGNS", "ARMED_TRAPS", "AMBUSHES", "STATIONS", "CURSE_ZONES", "MENU_VIEW_CELL"]

var width := 0
var height := 0
var cells := PackedByteArray()  # y * width + x: a tile code.
var start := {}                 # {"cell": Vector2i, "facing": int} (0 north, 1 west, 2 south, 3 east), or {} for none.
var levers: Array = []          # {"cell": Vector2i, "side": int, "target": String}: the floor square and the wall it hangs on; target "" is unlinked.
var sconces: Array = []         # {"cell": Vector2i, "side": int, "state": int (SCONCE_*)}.
var door_ids := {}              # door or gate cell -> its id, for the doors a lever is linked to (floor 1's DOOR_IDS).
var items: Array = []           # {"cell": Vector2i, "def": String (an ItemDef path), "count": int, optionally "opens": Vector2i (a key linked to a locked door)}. Several on one square are a pile, the last on top.
var monsters: Array = []        # {"cell": Vector2i, "def": String (a MonsterDef path), "facing": int}: one to a square.
var extras := {}                # The kept fields of an opened level (KEPT), untouched.
var undo_limit := 100
var _undo: Array = []           # Strokes: {"cells": PackedInt32Array of (index, old, new) triples, "before": things, "after": things}.
var _redo: Array = []
var _stroke := PackedInt32Array()
var _before := {}
var _in_stroke := false


## A fresh sheet of solid rock (all wall) with nothing on it; the undo history starts empty.
func setup(w: int, h: int, limit := 100) -> void:
	width = maxi(3, w)
	height = maxi(3, h)
	undo_limit = maxi(1, limit)
	cells = PackedByteArray()
	cells.resize(width * height)
	cells.fill(WALL)
	start = {}
	levers = []
	sconces = []
	door_ids = {}
	items = []
	monsters = []
	extras = {}
	_undo.clear()
	_redo.clear()
	_stroke = PackedInt32Array()
	_before = {}
	_in_stroke = false


# --- Questions ---------------------------------------------------------------------------------------------------------

func in_bounds(x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < width and y < height


func is_edge(x: int, y: int) -> bool:
	return x == 0 or y == 0 or x == width - 1 or y == height - 1


## The tile code of a square, or -1 off the grid.
func type_at(x: int, y: int) -> int:
	return cells[y * width + x] if in_bounds(x, y) else -1


func is_floor(x: int, y: int) -> bool:
	return type_at(x, y) == FLOOR


func is_wall_type(t: int) -> bool:
	return t == WALL or t == CRACKED or t == CORRUPTED


func is_door_type(t: int) -> bool:
	return t == DOOR or t == LOCKED or t == GATE


## Can the party walk through it (everything that is not wall or off the grid)?
func is_open(x: int, y: int) -> bool:
	var t := type_at(x, y)
	return t >= 0 and not is_wall_type(t)


func floor_count() -> int:
	var n := 0
	for c in cells:
		if c == FLOOR:
			n += 1
	return n


func door_id_of(cell: Vector2i) -> String:
	return door_ids.get(cell, "")


# --- Strokes, painting -------------------------------------------------------------------------------------------------

func begin_stroke() -> void:
	_stroke = PackedInt32Array()
	_before = _things()
	_in_stroke = true


## Paint a plain square: floor or wall. False, changing nothing, off the grid, on the outer edge, if it already is that, or if the
## square holds a door, stairs or a cracked wall (those are removed with Delete, never painted over by accident).
func set_cell(x: int, y: int, make_floor: bool) -> bool:
	if not in_bounds(x, y) or is_edge(x, y):
		return false
	var now: int = FLOOR if make_floor else WALL
	var here := type_at(x, y)
	if here == now or (here != FLOOR and here != WALL):
		return false
	var single := not _in_stroke
	if single:
		begin_stroke()
	_put(x, y, now)
	_cleanup()
	if single:
		end_stroke()
	return true


## A straight run of squares from a to b (Bresenham), so a fast drag leaves no gaps. Returns how many squares changed.
func line(a: Vector2i, b: Vector2i, make_floor: bool) -> int:
	var changed := 0
	var dx := absi(b.x - a.x)
	var dy := -absi(b.y - a.y)
	var sx := 1 if a.x < b.x else -1
	var sy := 1 if a.y < b.y else -1
	var err := dx + dy
	var x := a.x
	var y := a.y
	while true:
		if set_cell(x, y, make_floor):
			changed += 1
		if x == b.x and y == b.y:
			break
		var e2 := 2 * err
		if e2 >= dy:
			err += dy
			x += sx
		if e2 <= dx:
			err += dx
			y += sy
	return changed


func end_stroke() -> void:
	if _in_stroke:
		var after := _things()
		if not _stroke.is_empty() or after != _before:
			_undo.append({"cells": _stroke, "before": _before, "after": after})
			while _undo.size() > undo_limit:
				_undo.pop_front()
			_redo.clear()
	_stroke = PackedInt32Array()
	_before = {}
	_in_stroke = false


func can_undo() -> bool:
	return not _undo.is_empty()


func can_redo() -> bool:
	return not _redo.is_empty()


func undo() -> bool:
	if _undo.is_empty():
		return false
	var entry: Dictionary = _undo.pop_back()
	var stroke: PackedInt32Array = entry.cells
	for k in range(stroke.size() - 3, -1, -3):  # Backwards: a square touched twice in one stroke ends as it began.
		cells[stroke[k]] = stroke[k + 1]
	_set_things(entry.before)
	_redo.append(entry)
	return true


func redo() -> bool:
	if _redo.is_empty():
		return false
	var entry: Dictionary = _redo.pop_back()
	var stroke: PackedInt32Array = entry.cells
	for k in range(0, stroke.size(), 3):
		cells[stroke[k]] = stroke[k + 2]
	_set_things(entry.after)
	_undo.append(entry)
	return true


func undo_depth() -> int:
	return _undo.size()


# --- Placing things (each returns "" when done, or why it was refused) -----------------------------------------------

## A door, locked door or gate (portcullis) on a floor square, or in place of another door: it needs a wall on both sides and open
## ground ahead and behind, like a doorway in a corridor wall.
func place_door(x: int, y: int, kind: int) -> String:
	if not in_bounds(x, y) or is_edge(x, y):
		return "NOT ON THE EDGE OF THE SHEET"
	var here := type_at(x, y)
	if here != FLOOR and not is_door_type(here):
		return "A DOOR GOES ON FLOOR"
	var across_x := is_wall_type(type_at(x - 1, y)) and is_wall_type(type_at(x + 1, y)) and is_open(x, y - 1) and is_open(x, y + 1)
	var across_y := is_wall_type(type_at(x, y - 1)) and is_wall_type(type_at(x, y + 1)) and is_open(x - 1, y) and is_open(x + 1, y)
	if not (across_x or across_y):
		return "A DOOR NEEDS WALL ON BOTH SIDES"
	return _set_thing_cell(x, y, kind)


## A cracked wall replaces a wall that has floor beside it.
func place_cracked(x: int, y: int) -> String:
	if not in_bounds(x, y) or is_edge(x, y):
		return "NOT ON THE EDGE OF THE SHEET"
	if type_at(x, y) != WALL:
		return "A CRACK GOES IN A WALL"
	var beside := false
	for d in DIRS:
		if is_open(x + d.x, y + d.y):
			beside = true
	if not beside:
		return "A CRACKED WALL NEEDS FLOOR BESIDE IT"
	return _set_thing_cell(x, y, CRACKED)


func place_stairs(x: int, y: int) -> String:
	if not in_bounds(x, y) or is_edge(x, y):
		return "NOT ON THE EDGE OF THE SHEET"
	if type_at(x, y) != FLOOR:
		return "STAIRS GO ON FLOOR"
	return _set_thing_cell(x, y, STAIRS)


## The party start: one only (placing it again moves it). Keeps the way it faced if it is already placed.
func place_start(x: int, y: int, facing := 3) -> String:
	if not in_bounds(x, y) or is_edge(x, y):
		return "NOT ON THE EDGE OF THE SHEET"
	if type_at(x, y) != FLOOR:
		return "THE PARTY STARTS ON FLOOR"
	if monster_index_at(Vector2i(x, y)) >= 0:
		return "A MONSTER STANDS THERE"
	var single := not _in_stroke
	if single:
		begin_stroke()
	start = {"cell": Vector2i(x, y), "facing": int(start.get("facing", facing)) if not start.is_empty() else facing}
	if single:
		end_stroke()
	return ""


## Why a wall face cannot take a lever or sconce, or "": the square must be plain floor, the way `side` must be wall, and nothing
## else hangs there.
func face_reason(x: int, y: int, side: int) -> String:
	if not in_bounds(x, y) or type_at(x, y) != FLOOR:
		return "A WALL FACE NEEDS FLOOR IN FRONT"
	if side < 0 or side > 3 or not is_wall_type(type_at(x + DIRS[side].x, y + DIRS[side].y)):
		return "THAT SIDE IS NOT A WALL"
	if lever_index(Vector2i(x, y), side) >= 0 or sconce_index(Vector2i(x, y), side) >= 0:
		return "THERE IS ALREADY SOMETHING ON THAT WALL"
	return ""


func place_lever(x: int, y: int, side: int) -> String:
	var why := face_reason(x, y, side)
	if why != "":
		return why
	var single := not _in_stroke
	if single:
		begin_stroke()
	levers.append({"cell": Vector2i(x, y), "side": side, "target": ""})
	if single:
		end_stroke()
	return ""


func place_sconce(x: int, y: int, side: int, state: int) -> String:
	var why := face_reason(x, y, side)
	if why != "":
		return why
	var single := not _in_stroke
	if single:
		begin_stroke()
	sconces.append({"cell": Vector2i(x, y), "side": side, "state": state})
	if single:
		end_stroke()
	return ""


func lever_index(cell: Vector2i, side: int) -> int:
	for i in levers.size():
		if levers[i].cell == cell and levers[i].side == side:
			return i
	return -1


func sconce_index(cell: Vector2i, side: int) -> int:
	for i in sconces.size():
		if sconces[i].cell == cell and sconces[i].side == side:
			return i
	return -1


## Link lever number `index` to the door or gate at `cell`; linking it again unlinks it. The door gets an id (floor 1's DOOR_IDS) that
## the lever names as its "target".
func link_lever(index: int, cell: Vector2i) -> String:
	if index < 0 or index >= levers.size():
		return "NO LEVER"
	if not is_door_type(type_at(cell.x, cell.y)) or type_at(cell.x, cell.y) == LOCKED:
		return "A LEVER OPENS A DOOR OR A GATE"
	var id := "door_%d_%d" % [cell.x, cell.y]
	var single := not _in_stroke
	if single:
		begin_stroke()
	if levers[index].target == id:
		levers[index].target = ""  # Linked already: unlink.
	else:
		levers[index].target = id
		door_ids[cell] = id
	_cleanup()
	if single:
		end_stroke()
	return ""


## Take away a door, gate, locked door or stairs (the square becomes floor) or a cracked wall (it becomes wall again). "" if it did.
func delete_cell_thing(x: int, y: int) -> String:
	var t := type_at(x, y)
	if t == CRACKED:
		return _set_thing_cell(x, y, WALL)
	if is_door_type(t) or t == STAIRS:
		return _set_thing_cell(x, y, FLOOR)
	return "NOTHING THERE TO DELETE"


func delete_lever(index: int) -> void:
	if index >= 0 and index < levers.size():
		var single := not _in_stroke
		if single:
			begin_stroke()
		levers.remove_at(index)
		_cleanup()
		if single:
			end_stroke()


func delete_sconce(index: int) -> void:
	if index >= 0 and index < sconces.size():
		var single := not _in_stroke
		if single:
			begin_stroke()
		sconces.remove_at(index)
		if single:
			end_stroke()


func clear_start() -> void:
	if not start.is_empty():
		var single := not _in_stroke
		if single:
			begin_stroke()
		start = {}
		if single:
			end_stroke()


## Turn the party start a quarter turn clockwise (north, east, south, west).
func rotate_start() -> void:
	if start.is_empty():
		return
	var single := not _in_stroke
	if single:
		begin_stroke()
	start.facing = (int(start.facing) + 3) % 4  # (The game's facing numbers go round anticlockwise: 0 N, 1 W, 2 S, 3 E.)
	if single:
		end_stroke()


## Move a lever or sconce to the next wall face of its square that can take it (a quarter turn at a time). "" if it moved.
func rotate_face(is_lever: bool, index: int) -> String:
	var list: Array = levers if is_lever else sconces
	if index < 0 or index >= list.size():
		return "NOTHING TO TURN"
	var item: Dictionary = list[index]
	for step in range(1, 4):
		var side := (int(item.side) + step) % 4
		if face_reason(item.cell.x, item.cell.y, side) == "":
			var single := not _in_stroke
			if single:
				begin_stroke()
			item.side = side
			if single:
				end_stroke()
			return ""
	return "NO OTHER WALL TO TURN TO"


# --- Items and monsters (E.3) -------------------------------------------------------------------------------------------

func items_at(cell: Vector2i) -> Array:
	var out := []
	for i in items.size():
		if items[i].cell == cell:
			out.append(i)
	return out


func monster_index_at(cell: Vector2i) -> int:
	for i in monsters.size():
		if monsters[i].cell == cell:
			return i
	return -1


## Put an item on a floor square. It joins the pile like the game's floor piles: onto the top stack if that is the same item and has
## room (`max_stack`), else on top as a new stack. "" or the reason it was refused.
func place_item(x: int, y: int, def_path: String, max_stack := 1) -> String:
	if not in_bounds(x, y) or is_edge(x, y):
		return "NOT ON THE EDGE OF THE SHEET"
	if type_at(x, y) != FLOOR:
		return "ITEMS LIE ON FLOOR"
	var single := not _in_stroke
	if single:
		begin_stroke()
	var here := items_at(Vector2i(x, y))
	if not here.is_empty() and items[here[here.size() - 1]].def == def_path and int(items[here[here.size() - 1]].count) < max_stack:
		items[here[here.size() - 1]].count = int(items[here[here.size() - 1]].count) + 1
	else:
		items.append({"cell": Vector2i(x, y), "def": def_path, "count": 1})
	if single:
		end_stroke()
	return ""


## Stand a monster on a floor square, facing a way (0 north, 1 west, 2 south, 3 east). One to a square, and never on the party start.
func place_monster(x: int, y: int, def_path: String, facing := 2) -> String:
	if not in_bounds(x, y) or is_edge(x, y):
		return "NOT ON THE EDGE OF THE SHEET"
	if type_at(x, y) != FLOOR:
		return "MONSTERS STAND ON FLOOR"
	if monster_index_at(Vector2i(x, y)) >= 0:
		return "A MONSTER STANDS THERE ALREADY"
	if not start.is_empty() and start.cell == Vector2i(x, y):
		return "THE PARTY STARTS THERE"
	var single := not _in_stroke
	if single:
		begin_stroke()
	monsters.append({"cell": Vector2i(x, y), "def": def_path, "facing": facing})
	if single:
		end_stroke()
	return ""


func delete_item(index: int) -> void:
	if index >= 0 and index < items.size():
		var single := not _in_stroke
		if single:
			begin_stroke()
		items.remove_at(index)
		if single:
			end_stroke()


func delete_monster(index: int) -> void:
	if index >= 0 and index < monsters.size():
		var single := not _in_stroke
		if single:
			begin_stroke()
		monsters.remove_at(index)
		if single:
			end_stroke()


## Turn a monster a quarter turn clockwise.
func rotate_monster(index: int) -> void:
	if index >= 0 and index < monsters.size():
		var single := not _in_stroke
		if single:
			begin_stroke()
		monsters[index].facing = (int(monsters[index].facing) + 3) % 4
		if single:
			end_stroke()


## Link a key (item number `index`; the caller says it is a key) to the locked door at `cell`; linking it again unlinks it. Floor 1's
## keys open any locked door, so the link is for the editor (E.4's check that the level can be finished) and rides along in the item's
## data as "opens".
func link_key(index: int, cell: Vector2i) -> String:
	if index < 0 or index >= items.size():
		return "NO KEY"
	if type_at(cell.x, cell.y) != LOCKED:
		return "A KEY OPENS A LOCKED DOOR"
	var single := not _in_stroke
	if single:
		begin_stroke()
	if items[index].get("opens", Vector2i(-1, -1)) == cell:
		items[index].erase("opens")
	else:
		items[index]["opens"] = cell
	if single:
		end_stroke()
	return ""


## Put a whole level on the paper (E.5): `data` is {FIELD: value} as a level file's consts (floor 1's shapes). The squares, start, sconces,
## levers, door ids, items and monsters become the editor's own; the KEPT fields are held untouched in `extras`. Nothing is tidied up on
## the way in (no _cleanup), so what is saved again is what was opened.
func load_level(data: Dictionary, limit := 100) -> void:
	var map: Array = data.get("MAP", [])
	var w := 0
	for row in map:
		w = maxi(w, row.size())
	setup(w, map.size(), limit)
	for y in map.size():
		for x in map[y].size():
			cells[y * width + x] = int(map[y][x])
	if data.has("START_TILE"):
		start = {"cell": data.START_TILE, "facing": int(data.get("START_FACING", 3))}
	for t in data.get("TORCHES", []):
		if t is Vector4i:
			sconces.append({"cell": Vector2i(t.x, t.y), "side": t.z, "state": t.w})
		elif t is Vector3i:
			sconces.append({"cell": Vector2i(t.x, t.y), "side": t.z, "state": SCONCE_LIT})
	for l in data.get("LEVERS", []):
		var lever: Dictionary = l.duplicate(true)
		lever["target"] = String(lever.get("target", ""))
		levers.append(lever)
	door_ids = data.get("DOOR_IDS", {}).duplicate(true)
	for it in data.get("ITEMS", []):
		var item: Dictionary = it.duplicate(true)
		item["count"] = int(item.get("count", 1))
		items.append(item)
	for m in data.get("MONSTERS", []):
		var monster: Dictionary = m.duplicate(true)
		if not monster.has("facing"):
			monster["facing"] = 2
		monsters.append(monster)
	for f in KEPT:
		if data.has(f):
			var v = data[f]
			extras[f] = v.duplicate(true) if v is Array or v is Dictionary else v


## The level as floor 1's own data: only the fields the editor makes (MAP, START_TILE and START_FACING when a start is placed,
## DOOR_IDS, LEVERS, TORCHES). DungeonMap.use_level_data takes it as it is.
func level_data() -> Dictionary:
	var map: Array = []
	for y in height:
		var row: Array = []
		for x in width:
			row.append(cells[y * width + x])
		map.append(row)
	var torches: Array = []
	for s in sconces:
		torches.append(Vector4i(s.cell.x, s.cell.y, s.side, s.state))
	var lever_list: Array = []
	for l in levers:
		lever_list.append(l.duplicate(true))
	var item_list: Array = []
	for it in items:
		var entry: Dictionary = it.duplicate(true)
		if int(entry.get("count", 1)) <= 1:
			entry.erase("count")  # (Floor 1 writes "count" only for a stack of more than one.)
		item_list.append(entry)
	var monster_list: Array = []
	for m in monsters:
		var mon: Dictionary = m.duplicate(true)
		if int(mon.get("facing", 2)) == 2:
			mon.erase("facing")  # (South is the default and what floor 1's monsters have: not written.)
		monster_list.append(mon)
	var data := {"MAP": map, "DOOR_IDS": door_ids.duplicate(), "LEVERS": lever_list, "TORCHES": torches, "ITEMS": item_list, "MONSTERS": monster_list}
	if not start.is_empty():
		data["START_TILE"] = start.cell
		data["START_FACING"] = start.facing
	for f in extras:  # What the editor does not edit yet goes back out as it came in.
		var kept = extras[f]
		data[f] = kept.duplicate(true) if kept is Array or kept is Dictionary else kept
	return data


# --- Inside ------------------------------------------------------------------------------------------------------------

func _put(x: int, y: int, code: int) -> void:
	var i := y * width + x
	_stroke.append(i)
	_stroke.append(cells[i])
	_stroke.append(code)
	cells[i] = code


func _set_thing_cell(x: int, y: int, code: int) -> String:
	if type_at(x, y) == code:
		return ""
	var single := not _in_stroke
	if single:
		begin_stroke()
	_put(x, y, code)
	_cleanup()
	if single:
		end_stroke()
	return ""


## Drop what no longer makes sense after a change: levers and sconces whose square is no longer floor or whose wall is gone, a start
## that is no longer on floor, door ids of squares that are no longer doors, and links to a door that is gone.
func _cleanup() -> void:
	levers = levers.filter(func(l): return face_ok(l.cell, l.side))
	sconces = sconces.filter(func(s): return face_ok(s.cell, s.side))
	if not start.is_empty() and type_at(start.cell.x, start.cell.y) != FLOOR:
		start = {}
	items = items.filter(func(it): return type_at(it.cell.x, it.cell.y) == FLOOR)
	monsters = monsters.filter(func(m): return type_at(m.cell.x, m.cell.y) == FLOOR)
	for it in items:
		if it.has("opens") and type_at(it.opens.x, it.opens.y) != LOCKED:
			it.erase("opens")
	for cell in door_ids.keys():
		if not is_door_type(type_at(cell.x, cell.y)):
			door_ids.erase(cell)
	for l in levers:
		if l.target != "" and not door_ids.values().has(l.target):
			l.target = ""
	for cell in door_ids.keys():  # An id nobody is linked to is dropped (a lever, a plate or a puzzle all count).
		var used := _id_kept(door_ids[cell])
		for l in levers:
			used = used or l.target == door_ids[cell]
		if not used:
			door_ids.erase(cell)


## Is this door id named by a kept plate or a kept puzzle's open_door effect (so it must not be dropped)?
func _id_kept(id: String) -> bool:
	for p in extras.get("PLATES", []):
		if p.get("target", "") == id:
			return true
	for puzzle in extras.get("PUZZLES", []):
		for e in puzzle.get("then", []):
			if e.get("kind", "") == "open_door" and e.get("id", "") == id:
				return true
	return false


func face_ok(cell: Vector2i, side: int) -> bool:
	return type_at(cell.x, cell.y) == FLOOR and is_wall_type(type_at(cell.x + DIRS[side].x, cell.y + DIRS[side].y))


func _things() -> Dictionary:
	return {"start": start.duplicate(true), "levers": levers.duplicate(true), "sconces": sconces.duplicate(true), "door_ids": door_ids.duplicate(true),
			"items": items.duplicate(true), "monsters": monsters.duplicate(true)}


func _set_things(d: Dictionary) -> void:
	start = d.start.duplicate(true)
	levers = d.levers.duplicate(true)
	sconces = d.sconces.duplicate(true)
	door_ids = d.door_ids.duplicate(true)
	items = d.items.duplicate(true)
	monsters = d.monsters.duplicate(true)
