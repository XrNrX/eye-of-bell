extends Node3D
## A monster's bolt in flight (MonsterDef.bolt_effect): a looping flipbook orb with a red glow that flies from the caster to the party's
## tile in `seconds`, then is gone. Purely visual: the damage is dealt by the monster when the bolt arrives (Monster._bolt_lands). Made by
## Monster._cast and added next to the monster, so it goes with the dungeon. Art: art/spells/<bolt_effect>/bolt_sheet.png + .json (the VFX tool,
## sliced by tools/art/gen_spell_fx.py), drawn unshaded and additive like every spell effect; the light is in group "sprite_lights" so the
## walls and monsters it passes catch it.

const FxFlipbook := preload("res://scripts/fx_flipbook.gd")
const TorchLight := preload("res://scripts/torch.gd")

const PIXEL := 0.014                     # World size of one art pixel, like the monsters'.
const LIGHT_COLOUR := Color(1.0, 0.42, 0.28)

var from_pos := Vector3.ZERO
var to_pos := Vector3.ZERO
var seconds := 0.3
var effect := ""


## Add to the tree first, then call: flies from `start` to `end` in `time` seconds using art/spells/<effect_name>/bolt_sheet.
func launch(effect_name: String, start: Vector3, end: Vector3, time: float, tint := Color(1.3, 1.0, 0.9), light_colour := LIGHT_COLOUR, light_energy := 1.2) -> void:
	effect = effect_name
	from_pos = start
	to_pos = end
	seconds = maxf(0.05, time)
	global_position = start
	add_to_group("monster_bolts")
	var base := "res://art/spells/%s/bolt_sheet" % effect
	if ResourceLoader.exists(base + ".png") and FileAccess.file_exists(base + ".json"):
		var info = JSON.parse_string(FileAccess.get_file_as_string(base + ".json"))
		var flame := FxFlipbook.new()
		flame.setup(load(base + ".png"), int(info.frames), float(info.fps), true, PIXEL, tint, true)
		add_child(flame)
	var light := OmniLight3D.new()
	light.set_script(TorchLight)
	light.base_energy = light_energy
	light.light_color = light_colour
	light.omni_range = 5.0
	add_child(light)
	var tween := create_tween()
	tween.tween_property(self, "global_position", end, seconds)
	tween.tween_callback(queue_free)
