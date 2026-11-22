extends CanvasLayer
## The webbing over the 3D view while the party is stuck in a spider's web (Party.web_party calls show_web through the group "web_overlay"). It is
## the PixelLab picture art/ui/web_net.png (tools/art/gen_web_net.py), 208x128 art pixels shown at 2x, centred in the view, over the dungeon and
## under the frame. It does not fade (no smooth alpha in effects): it is on for the whole time, then blinks off in steps as the web is about to
## tear (nothing blinks with Settings.reduce_flashing: it just goes).

const UiLayout := preload("res://scripts/ui_layout.gd")
const Settings := preload("res://scripts/settings.gd")

const PATH := "res://art/ui/web_net.png"
const BLINKS := 3          # How many times it blinks off and on before it goes.
const BLINK_TIME := 0.09   # Seconds for each half of a blink.

var rect: TextureRect
var _tween: Tween


func _ready() -> void:
	layer = 2
	add_to_group("web_overlay")
	if not ResourceLoader.exists(PATH):
		return
	rect = TextureRect.new()
	rect.texture = load(PATH)
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var view := UiLayout.VIEW
	rect.size = Vector2(rect.texture.get_width(), rect.texture.get_height()) * 2.0
	rect.position = view.position + ((view.size - rect.size) * 0.5).floor()
	rect.visible = false
	add_child(rect)


## Show the web for `seconds` (the whole time the party is stuck), blinking off at the end.
func show_web(seconds: float) -> void:
	if rect == null:
		return
	if _tween != null:
		_tween.kill()
	rect.visible = true
	_tween = create_tween()
	var blinks := 0 if Settings.reduce_flashing else BLINKS
	_tween.tween_interval(maxf(0.0, seconds - blinks * BLINK_TIME * 2.0))
	for i in blinks:
		_tween.tween_callback(func(): rect.visible = false)
		_tween.tween_interval(BLINK_TIME)
		_tween.tween_callback(func(): rect.visible = true)
		_tween.tween_interval(BLINK_TIME)
	_tween.tween_callback(func(): rect.visible = false)


## Take it away at once (the web is gone: a new run, a load).
func clear() -> void:
	if _tween != null:
		_tween.kill()
	if rect != null:
		rect.visible = false
