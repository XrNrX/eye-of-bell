extends Node3D
## Holds a status's looping effect and light on a monster (made by spell_effects.status_started, freed by
## Monster.remove_status). Each frame it sits `toward` world units in front of the monster on the camera's side, at
## `height`, so the additive flipbook draws over the monster's sprite instead of fighting it for depth, wherever the party stands.

var height := 0.6
var toward := 0.18


func _process(_delta: float) -> void:
	var parent := get_parent() as Node3D
	var camera := get_viewport().get_camera_3d() if is_inside_tree() else null
	if parent == null or camera == null:
		position = Vector3(0, height, 0)
		return
	var flat := camera.global_position - parent.global_position
	flat.y = 0.0
	var dir := flat.normalized() if flat.length() > 0.01 else Vector3.ZERO
	global_position = parent.global_position + Vector3(0, height, 0) + dir * toward
