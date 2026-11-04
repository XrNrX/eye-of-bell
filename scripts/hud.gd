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


## Show a message, which fades out after a couple of seconds. With hold = true it
## stays until clear_message() instead (used for hover text, see quick_slot.gd).
func show_message(text: String, hold := false) -> void:
	message.text = text
	message.modulate.a = 1.0
	if tween:
		tween.kill()  # Restart the timer if a message is already showing.
		tween = null
	if hold:
		return
	tween = create_tween()
	tween.tween_interval(MESSAGE_TIME)
	tween.tween_property(message, "modulate:a", 0.0, FADE_TIME)


## Hide the message now. With only_if, only if that exact text is the one showing,
## so a hover ending can't wipe a different message that arrived in the meantime.
func clear_message(only_if := "") -> void:
	if only_if != "" and message.text != only_if:
		return
	if tween:
		tween.kill()
		tween = null
	message.modulate.a = 0.0
