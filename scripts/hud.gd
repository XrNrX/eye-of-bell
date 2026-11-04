extends CanvasLayer
## Minimal HUD: a short-lived message at the bottom and a key counter top-right.
## Other scripts call show_message() through the "hud" group, so this scene can
## be removed without breaking anything.

const DungeonMap := preload("res://scripts/dungeon_map.gd")

const MESSAGE_TIME := 2.0  # Seconds a message stays fully visible.
const FADE_TIME := 0.5

@onready var message: Label = %Message
@onready var keys: Label = %Keys

var tween: Tween


func _ready() -> void:
	add_to_group("hud")
	message.modulate.a = 0.0


func _process(_delta: float) -> void:
	keys.text = "Keys: %d" % DungeonMap.keys_held


func show_message(text: String) -> void:
	message.text = text
	message.modulate.a = 1.0
	if tween:
		tween.kill()  # Restart the timer if a message is already showing.
	tween = create_tween()
	tween.tween_interval(MESSAGE_TIME)
	tween.tween_property(message, "modulate:a", 0.0, FADE_TIME)
