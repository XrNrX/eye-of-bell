extends CanvasLayer
## Shockwave on spell impacts (the Fireball so far): a ring that ripples outward from the impact point across the
## dungeon view for about 0.3 s (the Fireball's, and a smaller one for the Magic Missile and its scroll). A full-screen ColorRect running shaders/shockwave.gdshader inside the dungeon's
## SubViewport, added by game_view.gd; it is hidden (and costs nothing) while no wave is running.
## Strength, radius, ring width and duration are in the "Shockwave" group of data/spell_effects.tres. Reduce flashing
## scales the strength by shock_reduced_scale (0: no wave at all).
## Call it through the group: get_tree().call_group("shockwave", "burst", world_position).

const Settings := preload("res://scripts/settings.gd")
const Config := preload("res://scripts/spell_effects_config.gd")
const SHADER := preload("res://shaders/shockwave.gdshader")
const MAX_WAVES := 4
const VIEW_WIDTH := 416.0  # The view's logical width (ui_layout.gd VIEW); the render is a whole multiple of it.

var rect: ColorRect
var waves := []  # [{at: Vector2 (logical view px), t: float, strength: float, size: float}]
var started := 0  # Waves started (tests read this).


func _ready() -> void:
	layer = 0  # Over the 3D render, under the enemy bars (layer 1), so the bars never wobble.
	add_to_group("shockwave")
	rect = ColorRect.new()
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	rect.material = mat
	rect.visible = false
	add_child(rect)


## Starts a wave centred on where `world_pos` shows in the view; `power` scales its strength and `size` its radius
## (the Magic Missile's is smaller than the Fireball's). Does nothing behind the camera, with the wave switched off,
## or with Reduce flashing on and shock_reduced_scale 0.
func burst(world_pos: Vector3, power := 1.0, size := 1.0) -> bool:
	var c := Config.get_config()
	var strength: float = c.shock_strength * power * (c.shock_reduced_scale if Settings.reduce_flashing else 1.0)
	if not c.shock_enabled or strength <= 0.0 or c.shock_seconds <= 0.0:
		return false
	var cam := get_viewport().get_camera_3d()
	if cam == null or cam.is_position_behind(world_pos):
		return false
	var at := cam.unproject_position(world_pos) / _step()
	if waves.size() >= MAX_WAVES:
		waves.pop_front()
	waves.append({"at": at, "t": 0.0, "strength": strength, "size": size})
	started += 1
	rect.visible = true
	_push()
	return true


func _process(delta: float) -> void:
	if waves.is_empty():
		return
	var seconds: float = Config.get_config().shock_seconds
	for w in waves:
		w.t += delta
	waves = waves.filter(func(w): return w.t < seconds)
	if waves.is_empty():
		rect.visible = false
	_push()


## Render pixels per logical view pixel: the whole-number scale the SubViewport renders at (ui_scale.gd).
func _step() -> float:
	return maxf(1.0, roundf(get_viewport().get_visible_rect().size.x / VIEW_WIDTH))


## Hands the running waves to the shader, in render pixels. The ring eases out from shock_start_radius to
## shock_radius and its strength falls steadily to nothing as it goes.
func _push() -> void:
	var c := Config.get_config()
	var k := _step()
	var data := []
	for i in MAX_WAVES:
		data.append(Vector4.ZERO)
	for i in waves.size():
		var w: Dictionary = waves[i]
		var p := clampf(w.t / c.shock_seconds, 0.0, 1.0)
		var ease_out := 1.0 - pow(1.0 - p, 2.0)
		var radius: float = lerpf(c.shock_start_radius, c.shock_radius, ease_out) * w.size
		var amp: float = w.strength * (1.0 - p)
		data[i] = Vector4(w.at.x * k, w.at.y * k, radius * k, amp * k)
	var mat := rect.material as ShaderMaterial
	mat.set_shader_parameter("waves", data)
	mat.set_shader_parameter("ring_width", c.shock_width * k)
	mat.set_shader_parameter("pixel_step", k)
