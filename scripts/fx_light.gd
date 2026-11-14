extends OmniLight3D
## A light driven by a flipbook (fx_flipbook.gd): its energy and colour follow the animation, frame by frame
## and blended between frames, so what the walls catch is exactly what the sprite is doing: a flicker in
## flight, a spike on the impact, a fade over about half a second. The curves are lists with one value per
## animation frame, kept in data/spell_effects.tres. It frees itself when its flipbook is gone.

const SpellEffectsConfigScript := preload("res://scripts/spell_effects_config.gd")

var flip: Node
var energies := PackedFloat32Array()
var colours := PackedColorArray()
var loops := false
var flicker := 0.0       # Random flutter, a fraction of the energy (a flame never burns evenly).
var strength := 1.0      # Everything multiplied by this (Reduce flashing, spell scale).
var speed := 1.0         # Plays the curve this much faster than the sprite (an impact flash that is shorter than its picture).


func setup(flipbook: Node, energy_by_frame: PackedFloat32Array, colour_by_frame: PackedColorArray, range_: float,
		looping := false, flutter := 0.0, scale_by := 1.0, play_speed := 1.0) -> void:
	flip = flipbook
	energies = energy_by_frame
	colours = colour_by_frame
	omni_range = range_
	loops = looping
	flicker = flutter
	strength = scale_by
	speed = play_speed
	SpellEffectsConfigScript.apply_shadow(self, "spells")
	_apply()


func _process(_delta: float) -> void:
	if not is_instance_valid(flip):
		queue_free()
		return
	_apply()


func _apply() -> void:
	var pos: float = flip.position_in_frames() * (1.0 if loops else speed)
	light_energy = _sample_f(pos) * strength * (1.0 + flicker * randf_range(-1.0, 1.0))
	if colours.size() > 0:
		light_color = _sample_c(pos)


func _next(i: int, count: int) -> int:
	return (i + 1) % count if loops else mini(i + 1, count - 1)


func _sample_f(pos: float) -> float:
	var n := energies.size()
	if n == 0:
		return 0.0
	var i := int(floor(pos)) % n if loops else mini(int(floor(pos)), n - 1)
	return lerpf(energies[i], energies[_next(i, n)], pos - floor(pos))


func _sample_c(pos: float) -> Color:
	var n := colours.size()
	var i := int(floor(pos)) % n if loops else mini(int(floor(pos)), n - 1)
	return colours[i].lerp(colours[_next(i, n)], pos - floor(pos))


func _enter_tree() -> void:
	add_to_group("sprite_lights")  # A spell's light lights the monsters it passes (sprite_lighting.gd).
