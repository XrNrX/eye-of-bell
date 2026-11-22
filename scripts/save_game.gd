extends RefCounted
## Save and load the run (7.3; per-system states since docs/code_review.md S1). One slot, JSON, at user://savegame.json.
## Use it via preload (like DungeonMap):
##     const SaveGame := preload("res://scripts/save_game.gd")
##     SaveGame.save(tree)        # -> "" or an error message
##     SaveGame.load_game(tree)   # reloads the scene and applies the file -> "" or an error
##
## This file only GATHERS: each system writes and reads its own part, `save_state()` / `load_state(d)` / static
## `validate_state(d)`, and a new system adds its own functions and one line here (and one in `validate`):
##   party      Party:        the formation and, per hero: hp, mana, hands, armour, backpack, quick slots, buffs, food and
##                            sickness, shaken
##   player     Player:       cell and facing
##   dungeon    Dungeon (dungeon_builder.gd): floor piles (where thrown items came from, lights' burn time and whether
##                            they lie lit), open and unlocked doors, levers, live monsters (Monster.save_state: kind, cell,
##                            hp, attack timer, statuses with the time left, boss greeting), broken, purified and corrupted
##                            walls, solved puzzles, armed bear traps
##   cursor     CursorItem:   the item held on the cursor ({"held": stack or null})
##   flags      the run flags (DungeonMap.flags: things that have happened, by name)
##   level      the level's script path ("" = floor 1; the test room cannot be saved)
##   level_id   which level this is (DungeonMap.level_id: "floor_1", a level script's path, or a generated level's id/seed);
##              optional, an older save has only `level`. DungeonMap.use_level_id builds it again on load.
## Not saved: cooldowns (they restart ready), animations in flight, floating text, fights.
##
## VALIDATE FIRST: `validate` checks the whole file (every key and its type) before anything in the game is touched, and a
## bad file is refused with a message and changes nothing. It runs on the file before the scene reloads, and again in
## apply() against the real game (hero count) before the first load_state. Versions: 2 is current (it adds `level` and
## wraps the cursor as {"held"}); version 1 files are accepted (`upgrade` converts them); a newer one is refused.
##
## Loading reloads main.tscn (a clean, fully built dungeon) and then applies the file to it once everything is ready: see
## save_manager.gd, which calls apply() for `pending`. Items and spells are stored by resource path; numbers come back from
## JSON as floats, so every integer is converted on the way in.

const DungeonMap := preload("res://scripts/dungeon_map.gd")
const SaveData := preload("res://scripts/save_data.gd")

## Where the save lives. A var so tests can point it elsewhere and never touch a real save.
static var path := "user://savegame.json"
const VERSION := 2
const OLDEST_VERSION := 1  # Saves back to this version still load.
const MAIN_SCENE := "res://scenes/main.tscn"

## The save waiting to be applied after the scene reloads (set by load_game).
static var pending := {}


static func has_save() -> bool:
	return FileAccess.file_exists(path)


## Write the current run to disk. Returns "" on success or why it failed.
static func save(tree: SceneTree) -> String:
	if not DungeonMap.level_saveable():
		return "This level can't be saved."  # (The test room, or a level built from the editor.)
	var data := serialize(tree)
	if data.is_empty():
		return "Nothing to save."
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return "Couldn't write the save file."
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
	if DirAccess.rename_absolute(tmp, path) != OK:  # Replace the old save only once the new one is complete.
		DirAccess.remove_absolute(path)
		DirAccess.rename_absolute(tmp, path)
	return ""


## Read the file. Returns {} with `error` explaining if it can't be used. A usable file is upgraded to the current layout
## and has passed `validate`.
static func read_file() -> Dictionary:
	if not has_save():
		return {"error": "There is no saved game."}
	var text := FileAccess.get_file_as_string(path)
	var parsed = JSON.parse_string(text)  # (A truncated file does not parse.)
	if not (parsed is Dictionary):
		return {"error": "The save file is damaged."}
	if not SaveData.is_number(parsed.get("version")):
		return {"error": "The save file is damaged (no version)."}
	var version := int(parsed.version)
	if version < OLDEST_VERSION:
		return {"error": "The save file is from another version."}
	if version > VERSION:
		return {"error": "The save file is from a newer version of the game."}
	var data := upgrade(parsed)
	var problem := validate(data)
	if problem != "":
		return {"error": problem}
	return data


## Bring an older save up to the current layout (a copy; idempotent). Version 1 -> 2: no `level` (floor 1) and the cursor's
## stack was stored bare instead of as {"held": stack}.
static func upgrade(data: Dictionary) -> Dictionary:
	var d := data.duplicate(true)
	if SaveData.is_number(d.get("version")) and int(d.version) < 2:
		d["cursor"] = {"held": d.get("cursor")}
		d["level"] = str(d.get("level", ""))
		d["version"] = 2
	return d


## Is the whole file usable? "" if so, else a message. Checks every system's part with that system's own validate_state, so
## nothing is read without a default part-way through a load. `hero_count` is how many heroes this game has (-1: skip, for
## a check made before the game is running).
static func validate(data: Dictionary, hero_count := -1) -> String:
	var version = data.get("version")
	if not SaveData.is_number(version) or int(version) < OLDEST_VERSION or int(version) > VERSION:
		return "The save file is from another version."
	for key in ["party", "player", "dungeon", "cursor"]:
		if not data.get(key) is Dictionary:
			return "The save file is damaged (no %s)." % key
	var problem: String = SaveData.maybe(data, "flags", "dict", "save file")
	if problem == "":
		problem = SaveData.maybe(data, "level", "string", "save file")
	if problem == "":
		problem = SaveData.maybe(data, "level_id", "string", "save file")
	if problem == "" and str(data.get("level", "")) != "" and not ResourceLoader.exists(str(data.level)):
		problem = "The saved level is not in this game."
	var saved_id := str(data.get("level_id", data.get("level", "")))  # (An older save has only the level path.)
	if problem == "" and saved_id != "" and saved_id != DungeonMap.FLOOR_1_ID and not (saved_id.begins_with("res://") and ResourceLoader.exists(saved_id)):
		problem = "The saved level is not in this game."
	if problem == "":
		problem = _script("res://scripts/party.gd").validate_state(data.party, hero_count)
	if problem == "":
		problem = _script("res://scripts/player.gd").validate_state(data.player)
	if problem == "":
		problem = _script("res://scripts/dungeon_builder.gd").validate_state(data.dungeon)
	if problem == "":
		problem = _script("res://scripts/cursor_item.gd").validate_state(data.cursor)
	return problem


## A system's script, looked up when needed (not preloaded: those scripts preload most of the game, and the pause menu and
## main menu preload this one).
static func _script(script_path: String) -> GDScript:
	return load(script_path)


## Load the saved game: reload the main scene and apply the file to it. Returns ""
## on success or why it can't (the file is checked first: a bad one changes nothing).
static func load_game(tree: SceneTree) -> String:
	var data := read_file()
	if data.has("error"):
		return data.error
	pending = data
	DungeonMap.use_level_id(str(data.get("level_id", data.get("level", ""))))  # Floor 1, or a level script (the test room cannot be saved).
	tree.paused = false
	if tree.current_scene != null and tree.current_scene.scene_file_path == MAIN_SCENE:
		tree.reload_current_scene()
	else:
		tree.change_scene_to_file(MAIN_SCENE)
	return ""


# --------------------------------------------------------------------------
# Serialising
# --------------------------------------------------------------------------

static func serialize(tree: SceneTree) -> Dictionary:
	var party := tree.get_first_node_in_group("party")
	var player := tree.get_first_node_in_group("player")
	var dungeon := tree.get_first_node_in_group("dungeon")
	if party == null or player == null or dungeon == null:
		return {}
	var cursor := tree.get_first_node_in_group("cursor")
	return {
		"version": VERSION,
		"level": DungeonMap.level_path,
		"level_id": DungeonMap.level_id,
		"party": party.save_state(),
		"player": player.save_state(),
		"dungeon": dungeon.save_state(),
		"flags": DungeonMap.flags.duplicate(),
		"cursor": cursor.save_state() if cursor else {"held": null},
	}


# (Thin wrappers: the helpers live in save_data.gd so the systems can use them without loading this file.)
static func cell_to_data(cell: Vector2i) -> Array:
	return SaveData.cell_to_data(cell)


static func data_to_cell(data) -> Vector2i:
	return SaveData.data_to_cell(data)


static func stack_to_data(stack):
	return SaveData.stack_to_data(stack)


static func data_to_stack(data) -> RefCounted:
	return SaveData.data_to_stack(data)


# --------------------------------------------------------------------------
# Applying
# --------------------------------------------------------------------------

## Put a saved game onto a freshly built main scene. Returns "" or why it couldn't. The whole file is checked against the
## running game first; nothing changes unless it all passes.
static func apply(tree: SceneTree, data: Dictionary) -> String:
	var party := tree.get_first_node_in_group("party")
	var player := tree.get_first_node_in_group("player")
	var dungeon := tree.get_first_node_in_group("dungeon")
	if party == null or player == null or dungeon == null:
		return "The game isn't ready to load."
	data = upgrade(data)
	var problem := validate(data, party.members.size())
	if problem != "":
		return problem

	party.load_state(data.party)
	dungeon.load_state(data.dungeon)
	DungeonMap.flags.clear()  # (An older save has none: the run starts with no flags set.)
	var saved_flags = data.get("flags", {})
	for name in saved_flags:
		var value = saved_flags[name]
		if value is float and value == floorf(value) and absf(value) < 1.0e15:
			value = int(value)  # JSON gives every number back as a float.
		if typeof(value) in [TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING]:
			DungeonMap.flags[str(name)] = value
	player.load_state(data.player)  # After the dungeon: standing on a tile refreshes its doors and plates.
	party.sync_light_level()  # The light held (and lit lights seen) after loading is not news.
	var cursor := tree.get_first_node_in_group("cursor")
	if cursor:
		cursor.load_state(data.cursor)
	tree.call_group("curse_zones", "sync_silently")  # Standing in a curse zone after loading is not news.
	return ""
