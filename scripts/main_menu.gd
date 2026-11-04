extends CanvasLayer
## Minimal main menu: a title and a New Game button that (re)starts the dungeon.
## Reached from Game over's "Quit to Menu" button (see end_screen.gd). Placeholder:
## expand with real menu options, a background scene, etc. whenever.

const MAIN_SCENE := "res://scenes/main.tscn"

@onready var new_game_button: Button = %NewGameButton


func _ready() -> void:
	new_game_button.pressed.connect(_on_new_game_pressed)
	new_game_button.grab_focus()  # So Enter / Space also work.


func _on_new_game_pressed() -> void:
	get_tree().change_scene_to_file(MAIN_SCENE)
