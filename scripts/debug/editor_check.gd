extends RefCounted
## The dungeon editor's check before a Build (roadmap E.4): can this paper be built and played, and is anything in it unreachable or
## unfinished? `run(grid)` returns a list of problems, each {"level": "error" | "warn", "text": String, "cells": Array of Vector2i}.
## An ERROR refuses the build (no party start, no stairs down); a WARNING lets it go on if the player says so. The cells are what the
## editor marks in red ink on the paper.
##
## Reachable means: a player starting on the party start could walk (or be let) onto that square. They walk floor, stairs and plain
## doors; a locked door opens once a key LINKED to it (the item's "opens") lies on a square they can reach; a gate opens once a lever
## linked to it (its "target" is the gate's id in door_ids) hangs on a wall of a square they can reach. Opening one door can open the
## way to the next key or lever, so this runs until nothing changes. (Floor 1's keys open any locked door in the game; the editor's
## links say which door each is meant for, and an unlinked key opens nothing here, which is why it is a warning.)

const EditorGrid := preload("res://scripts/debug/editor_grid.gd")


## Every square a player could get to, as {cell: true}. Empty with no party start.
static func reachable(g: RefCounted) -> Dictionary:
	var seen := {}
	if g.start.is_empty():
		return seen
	var open_locked := {}  # Locked doors a reachable key is linked to.
	var open_gate := {}    # Gates a reachable lever is linked to.
	seen[g.start.cell] = true
	var changed := true
	while changed:
		changed = false
		var queue: Array = seen.keys()
		var i := 0
		while i < queue.size():
			var cell: Vector2i = queue[i]
			i += 1
			for d in EditorGrid.DIRS:
				var n: Vector2i = cell + d
				if seen.has(n) or not g.in_bounds(n.x, n.y):
					continue
				var t: int = g.type_at(n.x, n.y)
				var ok: bool = t == EditorGrid.FLOOR or t == EditorGrid.STAIRS or t == EditorGrid.DOOR
				if t == EditorGrid.LOCKED and open_locked.has(n):
					ok = true
				if t == EditorGrid.GATE and open_gate.has(n):
					ok = true
				if ok:
					seen[n] = true
					queue.append(n)
					changed = true
		for it in g.items:
			if seen.has(it.cell) and it.has("opens") and not open_locked.has(it.opens):
				open_locked[it.opens] = true
				changed = true
		for l in g.levers:
			if seen.has(l.cell) and l.target != "":
				for door in g.door_ids:
					if g.door_ids[door] == l.target and not open_gate.has(door):
						open_gate[door] = true
						changed = true
	return seen


## Is this item a key? (Its ItemDef's type is KEY.)
static func is_key(def_path: String) -> bool:
	var def: Resource = load(def_path)
	return def != null and int(def.type) == 3  # ItemDef.Type.KEY


static func _problem(level: String, text: String, cells: Array) -> Dictionary:
	return {"level": level, "text": text, "cells": cells}


static func run(g: RefCounted) -> Array:
	var out: Array = []
	var stairs: Array = []
	for y in g.height:
		for x in g.width:
			if g.type_at(x, y) == EditorGrid.STAIRS:
				stairs.append(Vector2i(x, y))
	if g.start.is_empty():
		out.append(_problem("error", "NO PARTY START", []))
	if stairs.is_empty():
		out.append(_problem("error", "NO STAIRS DOWN", []))
	# The things that are not linked to anything.
	var loose_levers: Array = []
	for l in g.levers:
		if l.target == "":
			loose_levers.append(l.cell)
	if not loose_levers.is_empty():
		out.append(_problem("warn", "%d LEVER%s WORK NOTHING" % [loose_levers.size(), "" if loose_levers.size() == 1 else "S"], loose_levers))
	var loose_keys: Array = []
	for it in g.items:
		if is_key(it.def) and not it.has("opens"):
			loose_keys.append(it.cell)
	if not loose_keys.is_empty():
		out.append(_problem("warn", "%d KEY%s OPEN NOTHING" % [loose_keys.size(), "" if loose_keys.size() == 1 else "S"], loose_keys))
	var keyless: Array = []
	var leverless: Array = []
	for y in g.height:
		for x in g.width:
			var cell := Vector2i(x, y)
			var t: int = g.type_at(x, y)
			if t == EditorGrid.LOCKED:
				var has_key := false
				for it in g.items:
					has_key = has_key or it.get("opens", Vector2i(-1, -1)) == cell
				if not has_key:
					keyless.append(cell)
			elif t == EditorGrid.GATE:
				var id: String = g.door_id_of(cell)
				var has_lever := false
				for l in g.levers:
					has_lever = has_lever or (id != "" and l.target == id)
				if not has_lever:
					leverless.append(cell)
	if not keyless.is_empty():
		out.append(_problem("warn", "%d LOCKED DOOR%s HAVE NO KEY" % [keyless.size(), "" if keyless.size() == 1 else "S"], keyless))
	if not leverless.is_empty():
		out.append(_problem("warn", "%d GATE%s HAVE NO LEVER" % [leverless.size(), "" if leverless.size() == 1 else "S"], leverless))
	# What the player cannot get to.
	if not g.start.is_empty():
		var seen := reachable(g)
		var lost_stairs: Array = stairs.filter(func(c): return not seen.has(c))
		if not lost_stairs.is_empty() and lost_stairs.size() == stairs.size():
			out.append(_problem("warn", "THE STAIRS CAN'T BE REACHED", lost_stairs))
		var lost_floor: Array = []
		for y in g.height:
			for x in g.width:
				if g.type_at(x, y) == EditorGrid.FLOOR and not seen.has(Vector2i(x, y)):
					lost_floor.append(Vector2i(x, y))
		if not lost_floor.is_empty():
			out.append(_problem("warn", "%d FLOOR SQUARE%s CAN'T BE REACHED" % [lost_floor.size(), "" if lost_floor.size() == 1 else "S"], lost_floor))
		var lost_items: Array = []
		for it in g.items:
			if not seen.has(it.cell) and not lost_items.has(it.cell):
				lost_items.append(it.cell)
		if not lost_items.is_empty():
			out.append(_problem("warn", "%d ITEM SQUARE%s CAN'T BE REACHED" % [lost_items.size(), "" if lost_items.size() == 1 else "S"], lost_items))
		var lost_monsters: Array = []
		for m in g.monsters:
			if not seen.has(m.cell):
				lost_monsters.append(m.cell)
		if not lost_monsters.is_empty():
			out.append(_problem("warn", "%d MONSTER%s CAN'T BE REACHED" % [lost_monsters.size(), "" if lost_monsters.size() == 1 else "S"], lost_monsters))
	return out


static func has_errors(problems: Array) -> bool:
	for p in problems:
		if p.level == "error":
			return true
	return false


## Every square the problems point at (what the editor marks in red).
static func marked_cells(problems: Array) -> Array:
	var cells: Array = []
	for p in problems:
		for c in p.cells:
			if not cells.has(c):
				cells.append(c)
	return cells
