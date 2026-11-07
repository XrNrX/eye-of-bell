extends Label3D
## A damage number (or "Miss") that floats up out of a monster and fades away.
## Usage: var t := FloatingText.new(); t.setup("5", colour); parent.add_child(t)

const RISE := 0.6      # World units it floats upwards.
const LIFETIME := 0.8  # Seconds before it is gone.
const LINGER := 1.3    # ... for a crit.
const SIZE := 64

var text_size := SIZE
var lifetime := LIFETIME


## size 0 is the normal size; linger keeps it up longer (crits).
func setup(value: String, colour: Color, size := 0, linger := false) -> void:
	text = value
	modulate = colour
	if size > 0:
		text_size = size
	if linger:
		lifetime = LINGER


func _ready() -> void:
	billboard = BaseMaterial3D.BILLBOARD_ENABLED
	no_depth_test = true  # Always visible, even if the monster's sprite is in front.
	render_priority = 10
	font_size = text_size
	pixel_size = 0.004
	outline_size = 16
	outline_modulate = Color(0.08, 0.06, 0.1)
	texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	var tween := create_tween().set_parallel()
	tween.tween_property(self, "position:y", position.y + RISE, lifetime).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 0.0, lifetime).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(queue_free)
