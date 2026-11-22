extends RefCounted
## The safe campfire zone (a Hearth Coal's trip): the party is taken to a small separate level (levels/camp_zone.gd: a room with a
## campfire and four bedrolls, no monsters), where they can rest, cook and use their packs, and BREAK CAMP in the campfire's pop-up
## (campfire_menu.gd) brings them back to the exact tile they left, facing the same way, with the level as they left it.
##
## How: `enter` snapshots the running game (SaveGame.serialize: doors, levers, floor piles, monsters, the party, the player's tile) in
## memory (`snapshot`, never written to the save slot), then RunState.change_level carries the party and cursor into the zone level.
## `leave` puts the party's CURRENT state (what was rested, cooked or moved about in packs) over that snapshot and loads it as
## SaveGame.pending, so the level comes back exactly as it was and the party comes back as it is now. The zone cannot be saved
## (DungeonMap.level_path is not ""), and a snapshot lost with the program means a game quit at camp is a game back at the last save.

const DungeonMap := preload("res://scripts/dungeon_map.gd")
const SaveGame := preload("res://scripts/save_game.gd")
const RunState := preload("res://scripts/run_state.gd")
const Events := preload("res://scripts/game_events.gd")

const ZONE_PATH := "res://levels/camp_zone.gd"
const MAIN_SCENE := "res://scenes/main.tscn"

## The game as it was when the party left for camp (SaveGame.serialize's layout), or empty when they are not at camp.
static var snapshot := {}


## Are the party in the safe zone now?
static func in_zone() -> bool:
	return DungeonMap.level_id == ZONE_PATH


## Why the party cannot go to camp (a short narrator line), or "" if they can. Not in the zone already, and Party.camp_refusal's rules
## (no fight, no monster close).
static func refusal(tree: SceneTree) -> String:
	if in_zone():
		return "The party is already at camp."
	var party := tree.get_first_node_in_group("party")
	if party == null:
		return "There is nowhere to rest."
	return party.camp_refusal()


## Take the party to the zone. False (with nothing changed) if they cannot go. Call it AFTER the coal has left its slot: the party is
## carried as it stands.
static func enter(tree: SceneTree) -> bool:
	if refusal(tree) != "":
		return false
	var data := SaveGame.serialize(tree)
	if data.is_empty():
		return false
	var saved := snapshot
	snapshot = data
	if RunState.change_level(tree, ZONE_PATH) != "":
		snapshot = saved
		return false
	Events.send(tree, "camp_zone_entered", [])
	return true


## The Hearth Coal's trip with its show: slow dust builds over the view (camp_transition.gd), then `enter`. Deferred by the caller, so the coal
## has left its slot first.
static func go(tree: SceneTree) -> void:
	var Transition = load("res://scripts/camp_transition.gd")
	Transition.play(tree, func(): return enter(tree))


## BREAK CAMP with the same show: dust builds, then `leave`.
static func go_back(tree: SceneTree) -> void:
	var Transition = load("res://scripts/camp_transition.gd")
	Transition.play(tree, func(): return leave(tree))


## Bring the party back to where they left. False if there is nothing to go back to.
static func leave(tree: SceneTree) -> bool:
	if not in_zone() or snapshot.is_empty():
		return false
	var party := tree.get_first_node_in_group("party")
	if party == null:
		return false
	var data := snapshot.duplicate(true)
	data["party"] = party.save_state().duplicate(true)
	var cursor := tree.get_first_node_in_group("cursor")
	if cursor != null:
		data["cursor"] = cursor.save_state().duplicate(true)
	data["from_camp"] = true
	snapshot = {}
	SaveGame.pending = data
	if not DungeonMap.use_level_id(str(data.get("level_id", ""))):
		SaveGame.pending = {}
		return false
	tree.paused = false
	Events.send(tree, "camp_zone_left", [])
	if tree.current_scene != null and tree.current_scene.scene_file_path == MAIN_SCENE:
		tree.reload_current_scene()
	else:
		tree.change_scene_to_file(MAIN_SCENE)
	return true
