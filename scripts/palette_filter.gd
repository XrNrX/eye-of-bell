extends CanvasLayer
## The optional palette filter on the dungeon's SubViewport: a full-screen ColorRect running
## shaders/palette_snap.gdshader, which snaps every pixel of the 3D render to the 32 palette colours with a light
## ordered dither. Added by game_view.gd to the viewport; shown when Settings.palette_filter is on (Options:
## PALETTE FILTER). How strong the dither is lives in data/spell_effects.tres (palette_dither).

const Settings := preload("res://scripts/settings.gd")
const SpellEffectsConfig := preload("res://scripts/spell_effects_config.gd")
const SHADER := preload("res://shaders/palette_snap.gdshader")

## The game's palette (tools/art/palette.json), as it has to be in the exported game: tools/ is not shipped.
## Keep this in step with palette.json.
const PALETTE := ["0b0a10", "14131b", "1f1e28", "31303c", "504f5e", "7b7a88", "aaa9b4", "1c1511", "33261c", "4f3a28",
		"74553a", "4e2a1a", "7c4426", "a8673a", "161e1a", "26382c", "44624a", "86a672", "6b6250", "9c9278", "c9c0a4",
		"9a5f1c", "d99a36", "f5cf80", "3a6b4c", "7fb88a", "cdeec0", "1e1428", "3b2850", "6a4a86", "4a1418", "7a2224"]

var rect: ColorRect


func _ready() -> void:
	layer = 100
	rect = ColorRect.new()
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var image := Image.create(PALETTE.size(), 1, false, Image.FORMAT_RGBA8)
	for i in PALETTE.size():
		image.set_pixel(i, 0, Color(PALETTE[i]))
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	mat.set_shader_parameter("palette_tex", ImageTexture.create_from_image(image))
	mat.set_shader_parameter("palette_size", PALETTE.size())
	mat.set_shader_parameter("dither", SpellEffectsConfig.get_config().palette_dither)
	rect.material = mat
	add_child(rect)
	visible = Settings.palette_filter
