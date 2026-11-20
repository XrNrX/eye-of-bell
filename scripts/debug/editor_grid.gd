extends RefCounted
## The dungeon editor's paper as data (dungeon_editor.gd draws and edits it): a width x height grid of squares, each wall (1, the
## default: solid rock) or floor (0, blank paper), with undo and redo.
##
## The outer edge always stays wall: set_cell refuses it (and anything off the grid). A STROKE is one drag of the mouse: begin_stroke,
## any number of set_cell / line calls, end_stroke; undo and redo take back or put back a whole stroke. A change made outside a stroke
## is a stroke of one. Only the last `undo_limit` strokes are kept; a new stroke clears what could have been redone.

var width := 0
var height := 0
var cells := PackedByteArray()  # y * width + x: 1 wall, 0 floor.
var undo_limit := 100
var _undo: Array = []  # Strokes, each a PackedInt32Array of (index, old, new) triples.
var _redo: Array = []
var _stroke := PackedInt32Array()
var _in_stroke := false


## A fresh sheet of solid rock (all wall); the undo history starts empty.
func setup(w: int, h: int, limit := 100) -> void:
	width = maxi(3, w)
	height = maxi(3, h)
	undo_limit = maxi(1, limit)
	cells = PackedByteArray()
	cells.resize(width * height)
	cells.fill(1)
	_undo.clear()
	_redo.clear()
	_stroke = PackedInt32Array()
	_in_stroke = false


func in_bounds(x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < width and y < height


func is_edge(x: int, y: int) -> bool:
	return x == 0 or y == 0 or x == width - 1 or y == height - 1


func is_floor(x: int, y: int) -> bool:
	return in_bounds(x, y) and cells[y * width + x] == 0


func floor_count() -> int:
	var n := 0
	for c in cells:
		if c == 0:
			n += 1
	return n


func begin_stroke() -> void:
	_stroke = PackedInt32Array()
	_in_stroke = true


## Make the square floor (or wall). False, changing nothing, off the grid, on the outer edge, or if it already is that.
func set_cell(x: int, y: int, make_floor: bool) -> bool:
	if not in_bounds(x, y) or is_edge(x, y):
		return false
	var i := y * width + x
	var now: int = 0 if make_floor else 1
	if cells[i] == now:
		return false
	var single := not _in_stroke
	if single:
		begin_stroke()
	_stroke.append(i)
	_stroke.append(cells[i])
	_stroke.append(now)
	cells[i] = now
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
	if _in_stroke and not _stroke.is_empty():
		_undo.append(_stroke)
		while _undo.size() > undo_limit:
			_undo.pop_front()
		_redo.clear()
	_stroke = PackedInt32Array()
	_in_stroke = false


func can_undo() -> bool:
	return not _undo.is_empty()


func can_redo() -> bool:
	return not _redo.is_empty()


func undo() -> bool:
	if _undo.is_empty():
		return false
	var stroke: PackedInt32Array = _undo.pop_back()
	for k in range(stroke.size() - 3, -1, -3):  # Backwards: a square touched twice in one stroke ends as it began.
		cells[stroke[k]] = stroke[k + 1]
	_redo.append(stroke)
	return true


func redo() -> bool:
	if _redo.is_empty():
		return false
	var stroke: PackedInt32Array = _redo.pop_back()
	for k in range(0, stroke.size(), 3):
		cells[stroke[k]] = stroke[k + 2]
	_undo.append(stroke)
	return true


func undo_depth() -> int:
	return _undo.size()
