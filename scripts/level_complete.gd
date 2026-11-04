extends CanvasLayer
## "Level complete" screen with a restart button. Placeholder: replace or delete
## this scene whenever. The player triggers it through the "level_complete" group
## (see player.gd _arrive), so nothing else depends on it.

@onready var restart_button: Button = %RestartButton


func _ready() -> void:
	add_to_group("level_complete")
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
	get_tree().reload_current_scene()  # Rebuilds the dungeon and resets keys, doors, etc.
