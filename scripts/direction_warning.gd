extends CanvasLayer
## A red glow on the edge of the 3D view where a blow came from: the bottom edge for behind, the left or right edge for
## the sides. A hit from the front shows nothing here (the existing red flash covers that). Pure feedback, heard through
## Party.hit_from; delete this node and the glow just stops. Sits above the view and under the frame, so the frame's lips
## stay on top, and it takes no clicks. Settings: "Hit direction" group of data/spell_effects.tres.
##
## The glow is drawn in hard bands, the innermost one dithered, so it is pixels rather than a soft gradient. With Reduce
## flashing it is one dimmer, steady glow that fades, with no pulsing: the warning stays, the flash goes.

const Config := preload("res://scripts/spell_effects_config.gd")
const Settings := preload("res://scripts/settings.gd")
const UiLayout := preload("res://scripts/ui_layout.gd")

const BANDS: Array[float] = [0.85, 0.55, 0.32, 0.16]  # Strength of each band, from the edge inwards.

var cfg: Resource = Config.get_config()
var live := {}  # side -> seconds shown so far
var canvas: Control


func _ready() -> void:
	layer = 2
	canvas = Control.new()
	canvas.position = UiLayout.VIEW.position
	canvas.size = UiLayout.VIEW.size
	canvas.clip_contents = true
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.draw.connect(_paint)
	add_child(canvas)
	call_deferred("_listen")


func _listen() -> void:
	var party := get_tree().get_first_node_in_group("party")
	if party != null:
		party.hit_from.connect(_on_hit_from)


func _on_hit_from(side: String, _slot: int, _damage: int) -> void:
	if side != "front" and cfg.hit_direction_enabled:
		live[side] = 0.0
		canvas.queue_redraw()


func _process(delta: float) -> void:
	if live.is_empty():
		return
	for side in live.keys():
		live[side] += delta / maxf(Engine.time_scale, 0.001)  # Real time, so a hit pause doesn't stretch it.
		if live[side] >= cfg.edge_glow_seconds:
			live.erase(side)
	canvas.queue_redraw()


## How strong the glow on this side is now, 0..1.
func strength(side: String) -> float:
	if not live.has(side):
		return 0.0
	var t: float = live[side] / maxf(cfg.edge_glow_seconds, 0.001)
	if Settings.reduce_flashing:  # One steady glow that fades away near the end.
		return cfg.edge_glow_reduced_strength * clampf((1.0 - t) / 0.4, 0.0, 1.0)
	return (1.0 - t) * (0.6 + 0.4 * cos(TAU * cfg.edge_glow_pulses * t))


func _paint() -> void:
	for side in live:
		_paint_side(side, strength(side))


func _paint_side(side: String, power: float) -> void:
	var band: int = maxi(2, int(cfg.edge_glow_depth / BANDS.size()) & ~1)  # An even number of pixels.
	var size := canvas.size
	for i in BANDS.size():
		var colour: Color = cfg.edge_glow_colour
		colour.a = BANDS[i] * power
		var r := _band_rect(side, i * band, band, size)
		if i < BANDS.size() - 1:
			canvas.draw_rect(r, colour)
			continue
		var y := int(r.position.y)  # The innermost band is a 2x2 checker, so it breaks up instead of ending in a line.
		while y < int(r.end.y):
			var x := int(r.position.x)
			while x < int(r.end.x):
				if (x / 2 + y / 2) % 2 == 0:
					canvas.draw_rect(Rect2(x, y, 2, 2), colour)
				x += 2
			y += 2


func _band_rect(side: String, inset: int, thick: int, size: Vector2) -> Rect2:
	match side:
		"left":
			return Rect2(inset, 0, thick, size.y)
		"right":
			return Rect2(size.x - inset - thick, 0, thick, size.y)
	return Rect2(0, size.y - inset - thick, size.x, thick)  # Behind: the bottom edge.
