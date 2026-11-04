extends OmniLight3D
## Warm torch light with a subtle flicker. It follows the player simply by
## being a child of the Player node.

const BASE_ENERGY := 1.6
const FLICKER := 0.15  # Fraction of energy the flicker can add/remove.

var time := randf() * 100.0


func _process(delta: float) -> void:
	time += delta
	# Two out-of-phase sine waves give an irregular flicker without randomness.
	var wobble := sin(time * 11.0) * 0.6 + sin(time * 23.0) * 0.4
	light_energy = BASE_ENERGY * (1.0 + wobble * FLICKER)
