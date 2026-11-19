extends CanvasLayer
## The curse zone's edge glow: a slow, murky yellow-green vignette that creeps in from the edges of the 3D view while the party stands in a
## curse zone, thickens the longer it stays in the dark, pulls back when a Bless opens a pocket and creeps back in over the pocket's last
## few seconds. It is NOT the damage flash: it is stepped bands (shaders/curse_vignette.gdshader, dithered, in logical view pixels) that move
## slowly and gently and are never red or sharp. Reduce flashing: no pulse, just the steady vignette (curse_zones.gd glow_level()).
##
## Added by game_view.gd above the 3D view and under the frame (layer 2, like direction_warning.gd). It reads `CurseZones.glow_level()` each
## frame (the node in group "curse_zones"), shows nothing and costs nothing while that is 0. Strengths, colours and timings are in the
## "Curse zones" group of data/light.tres (light_config.gd).

const LightConfig := preload("res://scripts/light_config.gd")
const UiLayout := preload("res://scripts/ui_layout.gd")
const SHADER := preload("res://shaders/curse_vignette.gdshader")

var rect: ColorRect
var material: ShaderMaterial
var level := 0.0  # What it shows now (tests read this).
var _zones: Node


func _ready() -> void:
	layer = 2
	add_to_group("curse_vignette")
	rect = ColorRect.new()
	rect.position = UiLayout.VIEW.position
	rect.size = UiLayout.VIEW.size
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.visible = false
	material = ShaderMaterial.new()
	material.shader = SHADER
	rect.material = material
	add_child(rect)
	_apply_config()


func _apply_config() -> void:
	var c: Resource = LightConfig.get_config()
	material.set_shader_parameter("view_size", UiLayout.VIEW.size)
	material.set_shader_parameter("reach", c.vignette_reach)
	material.set_shader_parameter("bands", float(c.vignette_bands))
	material.set_shader_parameter("alpha", c.vignette_alpha)
	material.set_shader_parameter("col_edge", c.vignette_color)
	material.set_shader_parameter("col_dark", c.vignette_dark)


func _process(_delta: float) -> void:
	if _zones == null or not is_instance_valid(_zones):
		_zones = get_tree().get_first_node_in_group("curse_zones")
	level = _zones.glow_level() if _zones != null else 0.0
	rect.visible = level > 0.005
	if rect.visible:
		material.set_shader_parameter("strength", level)
