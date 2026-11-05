extends CanvasLayer
## Minimal main menu: a title, a Continue button (only if a save exists) and a New Game
## button that (re)starts the dungeon.
## Reached from Game over's "Quit to Menu" button (see end_screen.gd). Placeholder:
## expand with real menu options, a background scene, etc. whenever.

const MAIN_SCENE := "res://scenes/main.tscn"
const SaveGame := preload("res://scripts/save_game.gd")

@onready var new_game_button: Button = %NewGameButton
@onready var continue_button: Button = %ContinueButton


func _ready() -> void:
	new_game_button.pressed.connect(_on_new_game_pressed)
	continue_button.visible = SaveGame.has_save()
	continue_button.pressed.connect(func(): SaveGame.load_game(get_tree()))
	(continue_button if continue_button.visible else new_game_button).grab_focus()  # So Enter / Space also work.


func _on_new_game_pressed() -> void:
	get_tree().change_scene_to_file(MAIN_SCENE)
