extends MeshInstance3D
## A flipbook effect: a row of pixel-art frames played on an unshaded billboard quad. With `additive` it is
## drawn with additive blending, so it glows (black adds nothing, so the sprites' dark outlines vanish and the
## colours brighten whatever is behind them); the tint may go above 1.0 ("HDR") so the glow blooms.
##
## Made by spell_effects.gd from the sheets in art/spells/<spell>/ (see tools/art/gen_spell_fx.py): one row of
## frames, N of them, `fps` of them a second. A one-shot frees itself when its last frame has played and emits
## `finished`; a loop wraps. `t` is the time played, `fps` the speed: the light that goes with an effect
## (fx_light.gd) reads them to stay in step with the animation.

signal frame_changed(index: int)
signal finished

var frames := 1
var fps := 12.0
var loop := false
var t := 0.0
var index := -1
var material: StandardMaterial3D


## `size_px` is one frame's size in art pixels, `pixel_size` the world size of one art pixel (0.014 for the
## monsters), `scale` a multiplier on top.
func setup(sheet: Texture2D, frame_count: int, frames_per_second: float, looping: bool, pixel_size: float,
		tint: Color, additive := true, scale_by := 1.0) -> void:
	frames = maxi(1, frame_count)
	fps = frames_per_second
	loop = looping
	var frame_w := float(sheet.get_width()) / frames
	var frame_h := float(sheet.get_height())
	var quad := QuadMesh.new()
	quad.size = Vector2(frame_w, frame_h) * pixel_size * scale_by
	mesh = quad
	material = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if additive else BaseMaterial3D.BLEND_MODE_MIX
	material.albedo_texture = sheet
	material.albedo_color = tint
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.billboard_keep_scale = true
	material.uv1_scale = Vector3(1.0 / frames, 1.0, 1.0)
	material.no_depth_test = false
	material_override = material
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_show_frame(0)


## Where in the animation we are, in frames (fractional): what the synced light reads.
func position_in_frames() -> float:
	return t * fps


func _process(delta: float) -> void:
	t += delta
	var i := int(t * fps)
	if i >= frames:
		if loop:
			i = i % frames
		else:
			finished.emit()
			queue_free()
			return
	if i != index:
		_show_frame(i)


func _show_frame(i: int) -> void:
	index = i
	material.uv1_offset = Vector3(float(i) / frames, 0.0, 0.0)
	frame_changed.emit(i)
