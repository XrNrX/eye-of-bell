extends RefCounted
## What the map draws on a cell, shared by the corner map (minimap.gd) and the full-screen map (automap.gd).
## The symbols are PixelLab art (tools/art/gen_map_icons.py): 16x16 in art/ui/map/icon_<name>.png and 8x8 reductions
## icon_<name>_s.png. Monsters, traps and ambushes are never on the map.

const DungeonMap := preload("res://scripts/dungeon_map.gd")

const INK := Color("0b0a10")
const BONE_700 := Color("6b6250")
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


## Load the symbols: small = the 8x8 ones. The party arrow is always the full 16x16 one.
static func load_icons(small: bool) -> Dictionary:
	var icons := {}
	for n in NAMES:
		icons[n] = load("res://art/ui/map/icon_%s%s.png" % [n, "_s" if small else ""])
	icons["arrow"] = load("res://art/ui/map/icon_arrow.png")
	return icons


## A wall is inked only if one of the four cells beside it is not a wall (so it borders floor, a door or a gap); solid
## rock stays blank paper, like a hand-drawn dungeon. Both maps draw walls this way.
static func borders_open(c: Vector2i) -> bool:
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var n: Vector2i = c + d
		if n.y >= 0 and n.y < DungeonMap.MAP.size() and n.x >= 0 and n.x < DungeonMap.MAP[n.y].size() 				and not DungeonMap.is_wall(n):
			return true
	return false


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


## Draw one cell of the map on `canvas` at `at` (top-left), `cell` px square: wall, wall mark or floor wash.
static func draw_cell(canvas: CanvasItem, c: Vector2i, at: Vector2, cell: int, wash: Texture2D) -> void:
	if DungeonMap.is_wall(c):
		if borders_open(c):
			canvas.draw_rect(Rect2(at, Vector2(cell, cell)), INK)
			var mark := wall_mark(c)
			if mark.a > 0.0:
				var inset := maxi(2, cell / 4)
				canvas.draw_rect(Rect2(at + Vector2(inset, inset), Vector2(cell - 2 * inset, cell - 2 * inset)), mark)
	else:
		canvas.draw_texture(wash, at)  # Floor, doors, stairs.
