extends CanvasLayer
## A full-screen "the run is over" screen with a Restart button, used for both
## Level complete and Game over. Placeholder: replace or delete these scenes whenever.
## Other scripts show it through its group, so nothing else depends on it.
##
## Game over also has a "Quit to Menu" button (see scenes/game_over.tscn); Level
## complete doesn't, so this script looks for it by unique name and only wires it
## up if that scene actually has one -- no exported flag needed.

## The group other scripts call show_screen() on, e.g. "level_complete" or "game_over".
@export var group_name := "level_complete"

const MAIN_MENU := "res://scenes/main_menu.tscn"

@onready var restart_button: Button = %RestartButton
@onready var quit_button: Button = get_node_or_null("%QuitButton")  # Not every scene has one.


func _ready() -> void:
	add_to_group(group_name)
	process_mode = Node.PROCESS_MODE_ALWAYS  # Keep working while the game is paused.
	visible = false
	restart_button.pressed.connect(_on_restart_pressed)
	if quit_button:
		quit_button.pressed.connect(_on_quit_pressed)


## Show the screen and freeze the game underneath it.
func show_screen() -> void:
	get_tree().call_group("audio", "play", group_name)  # "level_complete" or "game_over": the jingle has the same name.
	visible = true
	get_tree().paused = true
	restart_button.grab_focus()  # So Enter / Space also work.


func _on_restart_pressed() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()  # Rebuilds the dungeon and resets everything.


func _on_quit_pressed() -> void:
	get_tree().paused = false  # Unpause first, or the menu's own input would be frozen too.
	get_tree().change_scene_to_file(MAIN_MENU)
