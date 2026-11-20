extends RefCounted
## Saving and opening levels for the dungeon editor (roadmap E.5): a level file is a plain script of consts in the exact shape of
## levels/floor_1.gd (the names are DungeonMap.LEVEL_FIELDS), nothing else. `script_text(data)` writes one (every field, empty ones as
## [] or {}; MAP a row to a line; every other entry on a line of its own), `save` puts it on disk and `read` loads one back as a
## dictionary of just those fields; `list` finds the files in a folder. The data goes through Godot's own value text (var_to_str), so a
## saved level reads back as exactly the same values (Vector2i and Vector4i, whole numbers and fractions, strings).
##
## Debug builds only, like the editor: the files are written into the project's levels/ folder (res://), which an exported game cannot do.

const DungeonMap := preload("res://scripts/dungeon_map.gd")

const HEADER := """extends RefCounted
## %s: a level made in the dungeon editor (scripts/debug/dungeon_editor.gd). A level is a plain script of consts, nothing else, in the
## shape of levels/floor_1.gd (which documents every field): edit it by hand or open it in the editor again. Fields the editor does not
## edit yet (puzzles, curse zones, ambushes, plates, signs, traps, structures, corrupted walls) are kept exactly as they were.

"""

## The fields in the order they are written (floor 1's order).
const ORDER := ["MAP", "START_TILE", "START_FACING", "TORCHES", "CORRUPTION", "PUZZLES", "DOOR_IDS", "PLATES", "STRUCTURES", "LEVERS", "ITEMS",
		"MONSTERS", "SIGNS", "ARMED_TRAPS", "AMBUSHES", "STATIONS", "CURSE_ZONES", "MENU_VIEW_CELL"]
const DICTIONARY_FIELDS := ["CORRUPTION", "DOOR_IDS"]


## A value as GDScript text: short things on one line, long arrays and dictionaries one entry to a line.
static func literal(v, indent := "") -> String:
	if v is Array:
		var parts: Array = []
		for e in v:
			parts.append(literal(e, indent + "\t"))
		var inline := "[" + ", ".join(parts) + "]"
		if inline.length() <= 100 and not inline.contains("\n"):
			return inline
		var lines: Array = []
		for p in parts:
			lines.append(indent + "\t" + p + ",")
		return "[\n" + "\n".join(lines) + "\n" + indent + "]"
	if v is Dictionary:
		var entries: Array = []
		for k in v:
			entries.append(literal(k, indent + "\t") + ": " + literal(v[k], indent + "\t"))
		var inline_d := "{" + ", ".join(entries) + "}"
		if inline_d.length() <= 100 and not inline_d.contains("\n"):
			return inline_d
		var rows: Array = []
		for e2 in entries:
			rows.append(indent + "\t" + e2 + ",")
		return "{\n" + "\n".join(rows) + "\n" + indent + "}"
	return var_to_str(v)


static func script_text(data: Dictionary, name := "level") -> String:
	var out: String = HEADER % name
	for field in ORDER:
		if not data.has(field):
			if field == "MENU_VIEW_CELL" or field == "START_TILE" or field == "START_FACING":
				continue  # No honest empty value: a level with none gets its start tile for the menu camera.
			out += "const %s := %s\n\n" % [field, "{}" if field in DICTIONARY_FIELDS else "[]"]
			continue
		var value = data[field]
		if field == "MAP":
			var rows: Array = []
			for y in value.size():
				rows.append("\t[" + ", ".join(value[y].map(func(c): return str(c))) + "],  # " + str(y))
			out += "const MAP := [\n" + "\n".join(rows) + "\n]\n\n"
		else:
			out += "const %s := %s\n\n" % [field, literal(value)]
	return out.rstrip("\n") + "\n"


## Write a level file. "" on success, or why not.
static func save(path: String, data: Dictionary, name := "level") -> String:
	var dir := path.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_recursive_absolute(dir)
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return "COULD NOT WRITE THE FILE"
	f.store_string(script_text(data, name))
	f.close()
	return ""


## Read a level file back as {FIELD: value} (only the level fields). {} if it is not a level. The source is compiled into a script of its
## own (never fetched from the resource cache by path), so a file saved a moment ago is not read as the copy loaded before it.
static func read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var script := GDScript.new()
	script.source_code = FileAccess.get_file_as_string(path)
	if script.reload() != OK:
		return {}
	var consts: Dictionary = script.get_script_constant_map()
	var out := {}
	for field in DungeonMap.LEVEL_FIELDS:
		if consts.has(field):
			var v = consts[field]
			out[field] = v.duplicate(true) if v is Array or v is Dictionary else v
	return out if out.has("MAP") else {}


## The level files in a folder (file names, sorted).
static func list(dir: String) -> Array:
	var out: Array = []
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			out.append(f)
	out.sort()
	return out


## Is this a name a level file may have? Lower case letters, digits and underscores, starting with a letter.
static func valid_name(name: String) -> bool:
	if name == "" or name.length() > 40:
		return false
	var re := RegEx.new()
	re.compile("^[a-z][a-z0-9_]*$")
	return re.search(name) != null
