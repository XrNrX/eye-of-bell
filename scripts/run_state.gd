extends RefCounted
## RunState: what survives a change of level (docs/code_review.md S6, Foundations Step 12).
##
## The party node is rebuilt from the hero files whenever main.tscn loads, so a new floor would start everyone fresh. RunState carries
## the party across: `carry` takes the party's own save_state (Step 7: the formation and every hero's HP, mana, gear, backpack, quick
## slots, buffs, food and sickness), the item on the cursor and the banter run flags ("banter.*": a once-a-run line must not come back
## on floor 2; every other flag belongs to its level and starts empty), `change_level` carries them, builds the next level and reloads the
## scene, and save_manager.gd calls `apply` once the new scene is built (the same moment a loaded save is applied). The party is
## validated with Party.validate_state first, so a bad carry changes nothing.
##
## Nothing in the game calls change_level yet: the stairs still show "Level complete" (the second floor does not exist). This is the
## mechanism, tested in tests/smoke_test.gd, ready for it.

const DungeonMap := preload("res://scripts/dungeon_map.gd")
const Party := preload("res://scripts/party.gd")
const MAIN_SCENE := "res://scenes/main.tscn"

## What is waiting to be put onto the next level's party: {"party": ..., "cursor": ..., "flags": ...}, or empty.
static var pending := {}


static func has() -> bool:
	return not pending.is_empty()


static func clear() -> void:
	pending = {}


## Take the running party (and the cursor's item and the banter flags) to carry to the next level. False if there is no party.
static func carry(tree: SceneTree) -> bool:
	var party := tree.get_first_node_in_group("party")
	if party == null:
		return false
	var cursor := tree.get_first_node_in_group("cursor")
	var banter_flags := {}
	for name in DungeonMap.flags:
		if str(name).begins_with("banter."):
			banter_flags[name] = DungeonMap.flags[name]
	pending = {
		"party": party.save_state().duplicate(true),
		"cursor": cursor.save_state().duplicate(true) if cursor != null else {"held": null},
		"flags": banter_flags,
	}
	return true


## Put the waiting party onto the freshly built scene. Returns "" (also when nothing waits) or why it couldn't; what is waiting is
## discarded either way.
static func apply(tree: SceneTree) -> String:
	if pending.is_empty():
		return ""
	var data := pending
	pending = {}
	var party := tree.get_first_node_in_group("party")
	if party == null:
		return "The game isn't ready to take the party."
	var problem: String = Party.validate_state(data.get("party", {}), party.members.size())
	if problem != "":
		return problem
	party.load_state(data.party)
	var saved_flags: Dictionary = data.get("flags", {})
	for name in saved_flags:
		DungeonMap.flags[name] = saved_flags[name]
	var cursor := tree.get_first_node_in_group("cursor")
	if cursor != null and data.get("cursor") is Dictionary:
		cursor.load_state(data.cursor)
	party.sync_light_level()  # The light held after a change of level is not news.
	return ""


## Carry the party to the level `id` (DungeonMap.use_level_id: "floor_1" or a level script's path): carry, build the level's data, and
## reload the scene; save_manager.gd applies the party once it is built. Returns "" or why it couldn't (nothing is changed then).
static func change_level(tree: SceneTree, id: String) -> String:
	if tree.get_first_node_in_group("party") == null:
		return "There is no party to carry."
	if not carry(tree):
		return "There is no party to carry."
	if not DungeonMap.use_level_id(id):
		clear()
		return "There is no way to build that level."
	tree.paused = false
	if tree.current_scene != null and tree.current_scene.scene_file_path == MAIN_SCENE:
		tree.reload_current_scene()
	else:
		tree.change_scene_to_file(MAIN_SCENE)
	return ""
