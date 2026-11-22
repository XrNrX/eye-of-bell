extends Node
## Quick save and load for the running game (see save_game.gd for what is saved):
##   F5 or K  save      L  load
## L, not the classic F9: when the game is launched from the Godot editor (F5 there is
## "Run"), the editor owns several F-keys and F9 froze the game after a load until it was
## pressed again. Plain letter keys never collide with editor shortcuts.
## and, when the scene was just reloaded by a load (or the main menu's Continue), applies
## the waiting save once the whole dungeon is built. Self-contained: delete this node
## and the keys do nothing; the menu's Continue then loads an unmodified fresh game.
##
## Runs while the game is paused so L also works from the Game over screen. Saving is
## refused while paused (the inventory, level complete, game over) so a save is always a
## moment of real play.

const SaveGame := preload("res://scripts/save_game.gd")
const RunState := preload("res://scripts/run_state.gd")
const DungeonMap := preload("res://scripts/dungeon_map.gd")


func _ready() -> void:
	add_to_group("save_manager")
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not SaveGame.pending.is_empty():
		call_deferred("_apply_pending")  # After every sibling's _ready (and its own deferred setup).
	elif RunState.has():
		call_deferred("_apply_run_state")  # The party carried from the last level (run_state.gd).
		if DungeonMap.level_id == "res://levels/camp_zone.gd":
			call_deferred("_say", "The party finds a safe fire.")  # (The Hearth Coal's trip: camp_zone.gd.)


func _apply_run_state() -> void:
	var error := RunState.apply(get_tree())
	if error != "":
		_say("Couldn't bring the party along: " + error)


func _apply_pending() -> void:
	var data := SaveGame.pending
	SaveGame.pending = {}
	var error := SaveGame.apply(get_tree(), data)
	if error == "":
		get_tree().call_group("audio", "play", "load")
	if error == "" and data.get("from_camp", false):
		_say("The party breaks camp.")   # Back from the safe campfire zone (camp_zone.gd), not a loaded save.
		return
	_say("Game loaded." if error == "" else "Couldn't load: " + error)


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if event.keycode == KEY_F5 or event.keycode == KEY_K:
		get_viewport().set_input_as_handled()
		save_game()
	elif event.keycode == KEY_L:
		get_viewport().set_input_as_handled()  # First: loading replaces the scene, taking this node with it.
		load_game()


func save_game() -> void:
	if get_tree().paused:
		_say("Can't save right now.")
		return
	var error := SaveGame.save(get_tree())
	if error == "":
		get_tree().call_group("audio", "play", "save")
	_say("Game saved." if error == "" else error)


func load_game() -> void:
	var error := SaveGame.load_game(get_tree())
	if error != "":
		_say(error)


func _say(text: String) -> void:
	get_tree().call_group("hud", "show_message", text)
