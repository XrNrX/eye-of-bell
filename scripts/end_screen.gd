extends CanvasLayer
## A full-screen "the run is over" screen with a restart button, used for both
## Level complete and Game over. Placeholder: replace or delete these scenes whenever.
## Other scripts show it through its group, so nothing else depends on it.

## The group other scripts call show_screen() on, e.g. "level_complete" or "game_over".
@export var group_name := "level_complete"

@onready var restart_button: Button = %RestartButton


func _ready() -> void:
	add_to_group(group_name)
	process_mode = Node.PROCESS_MODE_ALWAYS  # Keep working while the game is paused.
	visible = false
	restart_button.pressed.connect(_on_restart_pressed)


## Show the screen and freeze the game underneath it.
func show_screen() -> void:
	visible = true
	get_tree().paused = true
	restart_button.grab_focus()  # So Enter / Space also work.


func _on_restart_pressed() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()  # Rebuilds the dungeon and resets everything.
