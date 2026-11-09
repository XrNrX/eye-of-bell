extends RefCounted
## What the map draws on a cell, shared by the corner map (minimap.gd) and the full-screen map (automap.gd).
## The symbols are PixelLab art (tools/art/gen_map_icons.py): 16x16 in art/ui/map/icon_<name>.png and 8x8 reductions
## icon_<name>_s.png. Monsters, traps and ambushes are never on the map.

const DungeonMap := preload("res://scripts/dungeon_map.gd")

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
