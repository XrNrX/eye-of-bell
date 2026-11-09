extends Node3D
## One corrupted wall (MAP tile 7): a dark, rotted block overgrown with the curse. Everything that moves on it is a PixelLab
## effect (docs/asset_log.md), laid on each face that can be seen:
##   veins   art/corruption/veins_sheet.png   green curse veins that pulse with a heartbeat (looping), plus a faint green light
##                                            that beats with them
##   purge   art/corruption/purge_sheet.png   the gold holy light that a Bless sends into it
##   ash     art/corruption/ash_sheet.png     the wall crumbling to ash and dust
## The veins burn away from the centre outward as the gold light spreads (the `burn` uniform of shaders/corruption_add.gdshader),
## the block blackens, then sinks into a cloud of ash: no stone cubes, so it looks nothing like a cracked wall breaking.
## dungeon_builder.gd owns the state (DungeonMap.corrupted_left / purified); this node is only the show.

const DungeonMap := preload("res://scripts/dungeon_map.gd")
const Settings := preload("res://scripts/settings.gd")

const ADD_SHADER := preload("res://shaders/corruption_add.gdshader")
const MIX_SHADER := preload("res://shaders/corruption_mix.gdshader")
const SHEET := "res://art/corruption/%s_sheet"

const VEIN_GAIN := 1.5             # How bright the veins glow (above 1.4 the brightest pixels bloom with the heartbeat).
const VEIN_OFFSET := 0.012         # How far each overlay stands off the wall, so it does not fight the block for depth.
const PURGE_OFFSET := 0.016
const ASH_OFFSET := 0.02
const PURGE_GAIN := 1.15
const PURGE_REDUCED := 0.6          # Reduce flashing: the gold light is dimmer.
const PARTIAL_FRAMES := 5           # A Bless that does not finish the job plays only this many frames of the burn...
const PARTIAL_BURN := 0.5           # ...and burns the veins away this far out (0..1, the corners being 1).
const FULL_BURN := 1.1
const BURN_SECONDS := 1.0           # Matches the gold ring reaching the edge of the face.
const BLACKEN_TO := Color(0.12, 0.12, 0.13)
const CRUMBLE_AT := 1.0             # Seconds in, the ash starts and the block sinks.
const CRUMBLE_SECONDS := 1.3
const ASH_SECONDS := 1.6
const LIGHT_COLOUR := Color(0.45, 0.95, 0.6)
const LIGHT_ENERGY := 0.55          # The faint glow's strongest beat. Reduce flashing: a third of it.
const LIGHT_RANGE := 3.2
## How strong the heartbeat light is on each of the veins' 12 frames (the lub-dub of the animation).
const HEARTBEAT := [0.3, 1.0, 0.6, 0.9, 0.35, 0.3, 0.3, 0.3, 0.3, 0.3, 0.3, 0.3]

static var _sheets := {}   # name -> {texture, frames, fps}

var cell := Vector2i.ZERO
var strength := 1
var block: MeshInstance3D
var block_material: StandardMaterial3D
var light: OmniLight3D
var vein_material: ShaderMaterial          # Shared by every face, so one burn value burns them all.
var faces: Array = []                       # {"dir": Vector2i, "out": Vector3, "rot": Vector3, "veins": MeshInstance3D}
var overlays: Array = []                    # Running one-shots: {"mesh", "material", "frames", "fps", "t", "last"}
var burn := 0.0
var _burn_tween: Tween
var clock := 0.0
var _gone := false


static func sheet(name: String) -> Dictionary:
	if _sheets.has(name):
		return _sheets[name]
	var base: String = SHEET % name
	var entry := {}
	if ResourceLoader.exists(base + ".png") and FileAccess.file_exists(base + ".json"):
		var info = JSON.parse_string(FileAccess.get_file_as_string(base + ".json"))
		if info is Dictionary:
			entry = {"texture": load(base + ".png"), "frames": int(info.frames), "fps": float(info.fps)}
	_sheets[name] = entry
	return entry


## Build the block and its veins. `box` is the wall mesh (one whole picture per face, see the builder's _wall_box).
func setup(owner_cell: Vector2i, box: Mesh, blessings: int) -> void:
	cell = owner_cell
	strength = maxi(1, blessings)
	var s := DungeonMap.TILE_SIZE
	var h := DungeonMap.WALL_HEIGHT
	position = DungeonMap.cell_to_world(cell)
	block = MeshInstance3D.new()
	block.mesh = box
	block.position = Vector3(0, h / 2.0, 0)
	block_material = box.surface_get_material(0)
	add_child(block)
	var veins := sheet("veins")
	vein_material = null
	if not veins.is_empty():
		vein_material = ShaderMaterial.new()
		vein_material.shader = ADD_SHADER
		vein_material.set_shader_parameter("sheet", veins.texture)
		vein_material.set_shader_parameter("frames", float(veins.frames))
		vein_material.set_shader_parameter("gain", VEIN_GAIN)
	var first_open := Vector2i.ZERO
	for side in 4:
		var dir: Vector2i = _dir(side)
		if DungeonMap.is_wall(cell + dir):
			continue  # Nothing sees this face.
		if first_open == Vector2i.ZERO:
			first_open = dir
		var out := Vector3(dir.x, 0, dir.y)
		var rot := Vector3(0, atan2(dir.x, dir.y), 0)
		var face := {"dir": dir, "out": out, "rot": rot, "veins": null}
		if vein_material != null:
			face.veins = _quad(vein_material, out * (s / 2.0 + VEIN_OFFSET), rot)
		faces.append(face)
	if first_open != Vector2i.ZERO:
		light = OmniLight3D.new()
		light.light_color = LIGHT_COLOUR
		light.omni_range = LIGHT_RANGE
		light.light_energy = 0.0
		light.shadow_enabled = false
		light.position = Vector3(first_open.x, 0, first_open.y) * 0.9 + Vector3(0, 1.0, 0)
		add_child(light)
	set_burn(_partial_burn())


func _dir(side: int) -> Vector2i:
	return [Vector2i(0, -1), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(1, 0)][side]


func _quad(material: Material, offset: Vector3, rot: Vector3) -> MeshInstance3D:
	var quad := QuadMesh.new()
	quad.size = Vector2(DungeonMap.TILE_SIZE, DungeonMap.WALL_HEIGHT)
	var instance := MeshInstance3D.new()
	instance.mesh = quad
	instance.material_override = material
	instance.position = Vector3(0, DungeonMap.WALL_HEIGHT / 2.0, 0) + offset
	instance.rotation = rot
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)
	return instance


## How far the veins have already burned back, from the Blesses this wall has taken (0 untouched).
func _partial_burn() -> float:
	var left: int = int(DungeonMap.corrupted_left.get(cell, strength))
	return PARTIAL_BURN * (1.0 - float(left) / float(strength)) if left < strength else 0.0


func set_burn(value: float) -> void:
	burn = value
	if vein_material != null:
		vein_material.set_shader_parameter("burn", burn)


func _process(delta: float) -> void:
	clock += delta
	var veins := sheet("veins")
	var beat := 0.0
	if not veins.is_empty():
		var frame: int = int(clock * veins.fps) % int(veins.frames)
		if vein_material != null:
			vein_material.set_shader_parameter("frame", float(frame))
		beat = HEARTBEAT[mini(frame, HEARTBEAT.size() - 1)]
	if light != null and not _gone:
		var strength_scale := (1.0 / 3.0) if Settings.reduce_flashing else 1.0
		# The light weakens as the veins burn back: a wall with no veins left has nothing to glow.
		light.light_energy = LIGHT_ENERGY * beat * strength_scale * clampf(1.0 - burn / FULL_BURN, 0.0, 1.0)
	for o in overlays.duplicate():
		o.t += delta
		var frame := int(o.t * o.fps)
		if frame > o.last:
			o.mesh.queue_free()
			overlays.erase(o)
			continue
		o.material.set_shader_parameter("frame", float(frame))


## Play a one-shot flipbook on every visible face. `last` is the final frame to show (-1 = all of them). Returns its length in s.
func _play(name: String, additive: bool, offset: float, last := -1, gain := 1.0) -> float:
	var info := sheet(name)
	if info.is_empty():
		return 0.0
	var final: int = int(info.frames) - 1 if last < 0 else mini(last, int(info.frames) - 1)
	for face in faces:
		var material := ShaderMaterial.new()
		material.shader = ADD_SHADER if additive else MIX_SHADER
		material.set_shader_parameter("sheet", info.texture)
		material.set_shader_parameter("frames", float(info.frames))
		material.set_shader_parameter("frame", 0.0)
		if additive:
			material.set_shader_parameter("gain", gain)
		var mesh := _quad(material, face.out * (DungeonMap.TILE_SIZE / 2.0 + offset), face.rot)
		overlays.append({"mesh": mesh, "material": material, "fps": float(info.fps), "t": 0.0, "last": final})
	return float(final + 1) / float(info.fps)


## A Bless that does not finish it: the gold light goes in and burns the veins back part of the way.
func bless_partial() -> void:
	_play("purge", true, PURGE_OFFSET, PARTIAL_FRAMES - 1, _purge_gain())
	_burn_to(_partial_burn(), BURN_SECONDS * 0.5)


## The Bless that finishes it. Calls `done` when the wall is gone, so the cell can become floor. `open_cell` makes the floor and
## ceiling as the ash starts (so no void shows through).
func purify(open_cell: Callable, done: Callable) -> void:
	_play("purge", true, PURGE_OFFSET, -1, _purge_gain())
	_burn_to(FULL_BURN, BURN_SECONDS)
	var tween := create_tween()
	tween.tween_property(block_material, "albedo_color", BLACKEN_TO, BURN_SECONDS)  # The stone goes black.
	tween.tween_interval(maxf(0.0, CRUMBLE_AT - BURN_SECONDS))
	tween.tween_callback(func():
		open_cell.call()
		_play("ash", false, ASH_OFFSET)
		get_tree().call_group("audio", "play", "rumble")
		get_tree().call_group("combat_feel", "shake_by", 0.04, 0.5))
	# Sink into the floor while the ash hides it.
	tween.tween_property(block, "scale", Vector3(1.0, 0.02, 1.0), CRUMBLE_SECONDS).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(block, "position:y", 0.0, CRUMBLE_SECONDS).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(func():
		_gone = true
		block.visible = false
		if light != null:
			light.light_energy = 0.0
		for face in faces:
			if face.veins != null:
				face.veins.queue_free()
		done.call())
	tween.tween_interval(maxf(0.0, ASH_SECONDS - CRUMBLE_SECONDS) + 0.1)
	tween.tween_callback(queue_free)


func _purge_gain() -> float:
	return PURGE_GAIN * (PURGE_REDUCED if Settings.reduce_flashing else 1.0)


func _burn_to(target: float, seconds: float) -> void:
	if _burn_tween and _burn_tween.is_valid():
		_burn_tween.kill()
	_burn_tween = create_tween()
	_burn_tween.tween_method(set_burn, burn, target, maxf(0.01, seconds)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
