extends OmniLight3D
## Warm torch light with a subtle flicker. Used both for the player's torch
## (a child of the Player node, so it follows them) and for wall torches.

@export var base_energy := 1.6
@export var shadow_kind := ""  # "torches" or "party_torch": casts shadows when spell_effects_config says so. Empty: never (candles).
const SpellEffectsConfigScript := preload("res://scripts/spell_effects_config.gd")
const FLICKER := 0.15  # Fraction of energy the flicker can add/remove.

var time := randf() * 100.0


func _ready() -> void:
	if shadow_kind != "":
		SpellEffectsConfigScript.apply_shadow(self, shadow_kind)


func _process(delta: float) -> void:
	time += delta
	# Two out-of-phase sine waves give an irregular flicker without randomness.
	var wobble := sin(time * 11.0) * 0.6 + sin(time * 23.0) * 0.4
	light_energy = base_energy * (1.0 + wobble * FLICKER)
