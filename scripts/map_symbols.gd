extends RefCounted
## What the map draws on a cell, shared by the corner map (minimap.gd) and the full-screen map (automap.gd).
## The symbols are PixelLab art (tools/art/gen_map_icons.py): 16x16 in art/ui/map/icon_<name>.png and 8x8 reductions
## icon_<name>_s.png. Monsters, traps and ambushes are never on the map.

const DungeonMap := preload("res://scripts/dungeon_map.gd")

const INK := Color("0b0a10")
const BONE_300 := Color("c9c0a4")
const BONE_700 := Color("6b6250")
const RUST_500 := Color("7c4426")
const BLOOD_500 := Color("7a2224")
const RUST_700 := Color("4e2a1a")
const CURSE_700 := Color("3a6b4c")

const NAMES := ["door_closed", "door_open", "door_locked", "stairs", "lever", "secret"]


## The symbol for what stands on a cell, or "" for none: doors (closed, open, locked), stairs, and a secret that
## has been found (a cracked wall broken open, or a corrupted one purified).
static func icon_for(c: Vector2i) -> String:
	if DungeonMap.is_door(c):
		if DungeonMap.is_locked(c):
			return "door_locked"
		return "door_open" if DungeonMap.open_doors.has(c) else "door_closed"
	if DungeonMap.is_stairs(c):
		return "stairs"
	if DungeonMap.broken_walls.has(c) or DungeonMap.purified.has(c):
		return "secret"
	return ""


## Load the symbols: small = the 8x8 ones.
static func load_icons(small: bool) -> Dictionary:
	var icons := {}
	for n in NAMES:
		icons[n] = load("res://art/ui/map/icon_%s%s.png" % [n, "_s" if small else ""])
	return icons


## The mark inked inside a wall that is not plain stone (a crack, the curse's rot), or a clear colour for none.
static func wall_mark(c: Vector2i) -> Color:
	if DungeonMap.is_corrupted(c):
		return CURSE_700
	if DungeonMap.is_destructible(c):
		return RUST_700
	return Color(0, 0, 0, 0)


## One cell of floor wash: a checker of dark paper pixels, an ink wash that stays in the palette.
static func make_wash(cell: int) -> Texture2D:
	var img := Image.create(cell, cell, false, Image.FORMAT_RGBA8)
	for y in cell:
		for x in cell:
			if (x + y) % 2 == 0:
				img.set_pixel(x, y, BONE_700)
	return ImageTexture.create_from_image(img)


## A wall that touches floor beside it (used to place the small marks inside special walls).
static func borders_open(c: Vector2i) -> bool:
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var n: Vector2i = c + d
		if n.y >= 0 and n.y < DungeonMap.MAP.size() and n.x >= 0 and n.x < DungeonMap.MAP[n.y].size() 				and not DungeonMap.is_wall(n):
			return true
	return false


## Doors are drawn in code (draw_door), not as icons: "door_closed", "door_open", "door_locked", "portcullis_closed",
## "portcullis_open", or "" if the cell is no door.
static func door_kind(c: Vector2i) -> String:
	if not DungeonMap.is_door(c):
		return ""
	if DungeonMap.is_portcullis(c):
		return "portcullis_open" if DungeonMap.open_doors.has(c) else "portcullis_closed"
	if DungeonMap.is_locked(c):
		return "door_locked"
	return "door_open" if DungeonMap.open_doors.has(c) else "door_closed"


## The points of interest that are PixelLab symbols: stairs and a secret that has been found. (Levers are listed in
## DungeonMap.LEVERS.)
static func poi_for(c: Vector2i) -> String:
	var icon := icon_for(c)
	return icon if icon == "stairs" or icon == "secret" else ""


static func _line(cell: int) -> int:
	return 2 if cell >= 10 else 1  # Thickness of the wall line.


## Draw one cell of the map on `canvas` at `at` (top-left), `cell` px square, as a hand-drawn dungeon: floor is a light ink
## wash, and walls are thin ink lines along the edges where floor meets wall (no filled wall cells, so corridors read as
## pale channels and solid rock stays blank paper). A door is a break in that line with a bar across it (draw_door).
## A wall that is cracked or overgrown with the curse gets a small mark inside it.
static func draw_cell(canvas: CanvasItem, c: Vector2i, at: Vector2, cell: int, wash: Texture2D) -> void:
	if DungeonMap.is_wall(c):
		var mark := wall_mark(c)
		if mark.a > 0.0 and borders_open(c):
			var inset := maxi(2, cell / 4)
			canvas.draw_rect(Rect2(at + Vector2(inset, inset), Vector2(cell - 2 * inset, cell - 2 * inset)), mark)
		return
	canvas.draw_texture(wash, at)  # Floor, doors, stairs.
	var t := _line(cell)
	var n := DungeonMap.is_wall(c + Vector2i(0, -1))
	var s := DungeonMap.is_wall(c + Vector2i(0, 1))
	var w := DungeonMap.is_wall(c + Vector2i(-1, 0))
	var e := DungeonMap.is_wall(c + Vector2i(1, 0))
	if n:
		canvas.draw_rect(Rect2(at, Vector2(cell, t)), INK)
	if s:
		canvas.draw_rect(Rect2(at + Vector2(0, cell - t), Vector2(cell, t)), INK)
	if w:
		canvas.draw_rect(Rect2(at, Vector2(t, cell)), INK)
	if e:
		canvas.draw_rect(Rect2(at + Vector2(cell - t, 0), Vector2(t, cell)), INK)
	# Outer corners: both sides open but the diagonal is wall.
	for corner in [Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1)]:
		if DungeonMap.is_wall(c + corner) and not DungeonMap.is_wall(c + Vector2i(corner.x, 0)) 				and not DungeonMap.is_wall(c + Vector2i(0, corner.y)):
			var cx := 0.0 if corner.x < 0 else float(cell - t)
			var cy := 0.0 if corner.y < 0 else float(cell - t)
			canvas.draw_rect(Rect2(at + Vector2(cx, cy), Vector2(t, t)), INK)
	var kind := door_kind(c)
	if kind != "":
		draw_door(canvas, at, cell, kind, n and s or not (w and e))


## A door in code. `horizontal`: the passage runs east-west (walls above and below), so the door bar stands north-south.
## Closed: a rust bar with an ink edge across the gap; locked: the same with a blood-red dot; open: the leaf swung
## back along the wall; a portcullis is a dashed bar (closed) or two raised stubs (open).
static func draw_door(canvas: CanvasItem, at: Vector2, cell: int, kind: String, horizontal: bool) -> void:
	var bt := maxi(2, roundi(cell / 3.5))   # Bar thickness.
	var t := _line(cell)
	var c := float(cell)
	# Work in a frame where the passage runs left to right, then flip axes for a north-south passage.
	var flip := not horizontal
	var rect := func(x: float, y: float, w: float, h: float, colour: Color) -> void:
		var r := Rect2(at + (Vector2(y, x) if flip else Vector2(x, y)), Vector2(h, w) if flip else Vector2(w, h))
		canvas.draw_rect(r, colour)
	var mid := (c - bt) / 2.0
	match kind:
		"door_closed", "door_locked":
			rect.call(mid - 1, 0, bt + 2, c, INK)
			rect.call(mid, t, bt, c - 2 * t, RUST_500)
			if kind == "door_locked":
				var d := float(bt)
				rect.call((c - d) / 2.0 - 1, (c - d) / 2.0 - 1, d + 2, d + 2, INK)
				rect.call((c - d) / 2.0, (c - d) / 2.0, d, d, BLOOD_500)
		"door_open":
			var leaf := c * 0.7
			rect.call(t + 1, t, leaf, bt - 1 if bt > 2 else 1, INK)  # The leaf, lying along the north wall.
			rect.call(t, t, 2, 2, RUST_500)                           # Its hinge.
		"portcullis_closed":
			var step := c / 4.0
			for i in 3:
				rect.call(mid, step * (i + 0.5) - 0.5, bt, maxf(1.0, step - 1.0), INK)
		"portcullis_open":
			rect.call(mid, t, bt, 1, INK)
			rect.call(mid, c - t - 1, bt, 1, INK)


## A point of interest: a PixelLab symbol, on a small pale plaque with an ink edge when `plaque` is true (the corner map's
## 8x8 symbols would otherwise melt into the floor wash).
static func draw_poi(canvas: CanvasItem, icon: Texture2D, at: Vector2, cell: int, plaque: bool) -> void:
	var size := icon.get_size()
	var pos := at + (Vector2(cell, cell) - size) / 2.0
	if plaque:
		canvas.draw_rect(Rect2(pos - Vector2(1, 1), size + Vector2(2, 2)), INK)
		canvas.draw_rect(Rect2(pos, size), BONE_300)
	canvas.draw_texture(icon, pos)


# The party marker: a small arrowhead drawn in code so that it fits inside one cell and never spills over the wall lines
# (the 16x16 PixelLab arrow was bigger than a corner-map cell). K = ink outline, R = blood. Drawn pointing north.
const ARROW_SMALL := [
	"..KK..",
	".KRRK.",
	".KRRK.",
	"KRRRRK",
	"KRKKRK",
	"KK..KK",
]
const ARROW_LARGE := [
	"...K...",
	"..KRK..",
	"..KRK..",
	".KRRRK.",
	"KRRRRRK",
	"KRKKKRK",
	"KK...KK",
]
static var _arrows := {}  # "<size>_<facing>" -> Texture2D.


## The arrow texture for a cell size (the small one fits a corner-map cell, the large one a cell of 10+ px) and a facing
## (0 north, 1 west, 2 south, 3 east): the north-pointing pattern turned in whole quarter turns, so pixels stay square.
static func arrow(cell: int, facing: int) -> Texture2D:
	var large := cell >= 10
	var key := "%s_%d" % ["L" if large else "S", facing]
	if _arrows.has(key):
		return _arrows[key]
	var rows: Array = ARROW_LARGE if large else ARROW_SMALL
	var n: int = rows.size()
	var grid := []
	for y in n:
		grid.append(rows[y])
	for _turn in facing:  # Each step is a quarter turn counter-clockwise: (x, y) moves to (y, n - 1 - x).
		var next := []
		for y in n:
			var row := ""
			for x in n:
				row += grid[x][n - 1 - y]
			next.append(row)
		grid = next
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var ch: String = grid[y][x]
			if ch == "K":
				img.set_pixel(x, y, INK)
			elif ch == "R":
				img.set_pixel(x, y, BLOOD_500)
	var tex := ImageTexture.create_from_image(img)
	_arrows[key] = tex
	return tex


## Draw the party marker centred in the cell whose top-left is `at`.
static func draw_arrow(canvas: CanvasItem, at: Vector2, cell: int, facing: int) -> void:
	var tex := arrow(cell, facing)
	canvas.draw_texture(tex, at + ((Vector2(cell, cell) - tex.get_size()) / 2.0).floor())
