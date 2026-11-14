extends OmniLight3D
## The party's light: the Player's "Torch" node. It is no longer always on. It shines only while a living hero holds a lit light
## (a torch or a candle) in a hand, as the brightest one held (Party.brightest_light), a little brighter for each extra one
## (Party.light_level), with that light's range, falloff and colour. It flickers, and flickers hard in a light's last
## gutter_seconds. Settings: data/light.tres (light_config.gd); each light's own numbers are on its ItemDef ("Light" group).
## Reduce flashing keeps the gentle flicker but drops the hard one.

const LightConfig := preload("res://scripts/light_config.gd")
const SpellEffectsConfigScript := preload("res://scripts/spell_effects_config.gd")
const Settings := preload("res://scripts/settings.gd")

@export var shadow_kind := "party_torch"  # Casts shadows when spell_effects_config says so.

var cfg: Resource = LightConfig.get_config()
var time := randf() * 100.0
var party: Node


func _ready() -> void:
	add_to_group("party_light")
	add_to_group("sprite_lights")  # Monsters and items it reaches are lit by it (sprite_lighting.gd).
	if shadow_kind != "":
		SpellEffectsConfigScript.apply_shadow(self, shadow_kind)
	position.y = cfg.light_height
	visible = false


func _process(delta: float) -> void:
	time += delta
	if party == null or not is_instance_valid(party):
		party = get_tree().get_first_node_in_group("party")
	var stack = party.brightest_light() if party != null else null
	visible = stack != null
	if stack == null:
		return
	var def: Resource = stack.def
	light_color = def.light_color
	omni_range = def.light_range
	omni_attenuation = def.light_attenuation
	light_energy = party.light_level() * flicker_factor(time, stack.seconds_left(), cfg)


## How much a burning light's energy is scaled right now: a gentle flicker from two out-of-phase waves (no randomness), and in its
## last gutter_seconds a hard, stuttering one (not with Reduce flashing). Shared with the lights lying on the floor (light_field.gd).
static func flicker_factor(t: float, seconds_left: float, c: Resource) -> float:
	var wobble := sin(t * 11.0) * 0.6 + sin(t * 23.0) * 0.4
	var amount: float = c.flicker
	if seconds_left < c.gutter_seconds and not Settings.reduce_flashing:
		amount = c.gutter_flicker
		wobble = wobble * 0.5 + (0.5 if sin(t * 7.3) > 0.2 else -0.5)  # Dips that catch and hold for a moment, as a dying flame does.
	return maxf(0.05, 1.0 + wobble * amount)
