extends Node
## Quick save and load for the running game (see save_game.gd for what is saved):
##   F5  save   F9  load
## and, when the scene was just reloaded by a load (or the main menu's Continue), applies
## the waiting save once the whole dungeon is built. Self-contained: delete this node
## and the keys do nothing; the menu's Continue then loads an unmodified fresh game.
##
## Runs while the game is paused so F9 also works from the Game over screen. Saving is
## refused while paused (the inventory, level complete, game over) so a save is always a
## moment of real play.

const SaveGame := preload("res://scripts/save_game.gd")


func _ready() -> void:
	add_to_group("save_manager")
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not SaveGame.pending.is_empty():
		call_deferred("_apply_pending")  # After every sibling's _ready (and its own deferred setup).


func _apply_pending() -> void:
	var data := SaveGame.pending
	SaveGame.pending = {}
	var error := SaveGame.apply(get_tree(), data)
	_say("Game loaded." if error == "" else "Couldn't load: " + error)


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if event.keycode == KEY_F5:
		get_viewport().set_input_as_handled()
		save_game()
	elif event.keycode == KEY_F9:
		get_viewport().set_input_as_handled()  # First: loading replaces the scene, taking this node with it.
		load_game()


func save_game() -> void:
	if get_tree().paused:
		_say("Can't save right now.")
		return
	var error := SaveGame.save(get_tree())
	_say("Game saved." if error == "" else error)


func load_game() -> void:
	var error := SaveGame.load_game(get_tree())
	if error != "":
		_say(error)


func _say(text: String) -> void:
	get_tree().call_group("hud", "show_message", text)
