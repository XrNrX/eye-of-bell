extends CanvasLayer
## Minimal HUD: a short-lived message at the bottom. Other scripts call
## show_message() through the "hud" group, so this scene can be removed without
## breaking anything.

const MESSAGE_TIME := 2.0  # Seconds a message stays fully visible.
const FADE_TIME := 0.5

@onready var message: Label = %Message

var tween: Tween


func _ready() -> void:
	add_to_group("hud")
	message.modulate.a = 0.0


func show_message(text: String) -> void:
	message.text = text
	message.modulate.a = 1.0
	if tween:
		tween.kill()  # Restart the timer if a message is already showing.
	tween = create_tween()
	tween.tween_interval(MESSAGE_TIME)
	tween.tween_property(message, "modulate:a", 0.0, FADE_TIME)
