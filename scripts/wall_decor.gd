extends RefCounted
## The ancient wall look. For each wall cell the builder asks add_faces(): one picture quad on every side that faces open
## floor (a stone texture picked by a seed from the tile and side), a grime overlay, and 0-2 decals placed by the same seeded
## randomness; about 1 face in 10 also gets glowing curse veins, and a few get an alcove. add_structures() then adds
## pillars, arches and alcoves (rule-placed in long corridors, plus whatever DungeonMap.STRUCTURES lists). Everything is read
## from data/wall_decor.tres (WallDecorConfig), so density is tuned there.
##
## Faces are quads, not the old block, so an interior wall nobody can see costs nothing.
##
## Where a decal sits on a face follows its file name (PLACEMENT): roots hang from the top, stains start high, blood is
## low or middle, tally marks are at hand height, cobwebs sit in a top corner (web_l / web_r), cracks go anywhere.

const DungeonMap := preload("res://scripts/dungeon_map.gd")
const Config := preload("res://scripts/wall_decor_config.gd")
const TorchLight := preload("res://scripts/torch.gd")
const NormalMaps := preload("res://scripts/normal_maps.gd")

const PIXEL := 2.0 / 256.0  # World units per wall-texture pixel (a 256 px face is one tile, 2 units, wide; on main it was 128).
const PLACEMENT := {"roots": "top", "stain": "top", "blood": "low", "tally": "mid", "web_l": "corner_l", "web_r": "corner_r"}

var cfg: Resource = Config.get_config()
var _materials := {}   # texture path -> StandardMaterial3D
var _quads := {}       # key -> QuadMesh
var _vein_materials: Array = []


## Does the builder use this look (config.enabled and a texture list that loads)?
func active() -> bool:
	return cfg.enabled and not cfg.wall_textures.is_empty()


## Build every visible face of this wall cell into `builder` (a Node3D with `_add_mesh`).
func add_faces(builder: Node3D, cell: Vector2i) -> void:
	for side in 4:
		if DungeonMap.is_wall(cell + _dir(side)):
			continue  # Nothing can see this face.
		add_face(builder, cell, side)


## One face of a wall cell (side 0 north, 1 west, 2 south, 3 east), whether or not it is seen right now: the builder calls this
## for the walls beside a cell that has just opened (a broken or purified wall), whose faces were never built.
func add_face(builder: Node3D, cell: Vector2i, side: int) -> void:
	var s := DungeonMap.TILE_SIZE
	var h := DungeonMap.WALL_HEIGHT
	var centre := DungeonMap.cell_to_world(cell) + Vector3(0, h / 2.0, 0)
	var dir: Vector2i = _dir(side)
	var rng := RandomNumberGenerator.new()
	rng.seed = face_seed(cell, side)
	var out := Vector3(dir.x, 0, dir.y)
	var rot := Vector3(0, atan2(dir.x, dir.y), 0)  # A QuadMesh faces +Z; turn it to face out of the wall.
	var base := centre + out * (s / 2.0)
	var texture: String = cfg.wall_textures[rng.randi() % cfg.wall_textures.size()]
	builder._add_mesh(_quad(Vector2(s, h), texture, false), base, rot)
	if cfg.grime_enabled:
		_overlay(builder, _quad(Vector2(s, h), cfg.grime_texture, true), base + out * cfg.grime_offset, rot)
	if cfg.alcove_texture != "" and rng.randf() < cfg.alcove_chance:
		add_alcove(builder, cell + dir, (side + 2) % 4)  # From the open tile's side: the wall faces back at it.
		return  # The niche is the feature of this face.
	for decal in decals_for(rng):
		var tex: Texture2D = load(decal)
		var size := Vector2(tex.get_width(), tex.get_height()) * PIXEL
		var at := _spot(decal, size, rng, s, h)
		var pos: Vector3 = base + out * cfg.decal_offset + _along(rot) * at.x + Vector3(0, at.y, 0)
		_overlay(builder, _quad(size, decal, true), pos, rot)
	if cfg.vein_textures.size() > 0 and rng.randf() < cfg.vein_chance:
		var vein: String = cfg.vein_textures[rng.randi() % cfg.vein_textures.size()]
		var vtex: Texture2D = load(vein)
		var vsize := Vector2(vtex.get_width(), vtex.get_height()) * PIXEL
		var vat := _spot("vein", vsize, rng, s, h)
		var vpos: Vector3 = base + out * (cfg.decal_offset + 0.004) + _along(rot) * vat.x + Vector3(0, vat.y, 0)
		_overlay(builder, _quad(vsize, vein, true, true), vpos, rot)


## A picture laid just over a wall face (grime, decal, vein, niche). It casts no shadow: only the wall itself does.
func _overlay(builder: Node3D, mesh: Mesh, pos: Vector3, rot: Vector3) -> void:
	builder._add_mesh(mesh, pos, rot).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## The decal textures this face gets (0, 1 or 2, in the config's chances), drawn from the face's own random stream.
func decals_for(rng: RandomNumberGenerator) -> Array:
	var picks := []
	if cfg.decal_textures.is_empty():
		return picks
	var roll := rng.randf()
	var count := 2 if roll < cfg.decal_chance_two else (1 if roll < cfg.decal_chance_one else 0)
	for i in count:
		picks.append(cfg.decal_textures[rng.randi() % cfg.decal_textures.size()])
	return picks


## Where on a face a decal of this kind sits: an offset from the face's centre (x along the wall, y up), by its placement band.
func _spot(path: String, size: Vector2, rng: RandomNumberGenerator, s: float, h: float) -> Vector2:
	var m: float = cfg.decal_margin
	var room_x := maxf(0.0, s - size.x - m * 2.0)
	var room_y := maxf(0.0, h - size.y - m * 2.0)
	var x := rng.randf_range(-0.5, 0.5) * room_x
	var top := h / 2.0 - m - size.y / 2.0
	var bottom := -h / 2.0 + m + size.y / 2.0
	match PLACEMENT.get(path.get_file().get_basename(), "any"):
		"top":
			return Vector2(x, top - rng.randf() * 0.15)
		"low":
			return Vector2(x, bottom + 0.1 + rng.randf() * 0.35)
		"mid":
			return Vector2(x, rng.randf_range(-0.15, 0.35))
		"corner_l":
			return Vector2(-s / 2.0 + size.x / 2.0 + 0.02, h / 2.0 - size.y / 2.0 - 0.02)
		"corner_r":
			return Vector2(s / 2.0 - size.x / 2.0 - 0.02, h / 2.0 - size.y / 2.0 - 0.02)
	return Vector2(x, rng.randf_range(-0.5, 0.5) * room_y)


## A niche in the wall on `side` of this open tile, with a skull and a candle stub, and a dim flickering candle light in front.
func add_alcove(builder: Node3D, cell: Vector2i, side: int) -> void:
	var s := DungeonMap.TILE_SIZE
	var dir := _dir(side)
	var out := -Vector3(dir.x, 0, dir.y)  # From the wall back towards the tile.
	var rot := Vector3(0, atan2(-dir.x, -dir.y), 0)
	var tex: Texture2D = load(cfg.alcove_texture)
	var size := Vector2(tex.get_width(), tex.get_height()) * PIXEL * 1.5
	var wall_point := DungeonMap.cell_to_world(cell) + Vector3(dir.x, 0, dir.y) * (s / 2.0) + Vector3(0, 0.95, 0)
	_overlay(builder, _quad(size, cfg.alcove_texture, true), wall_point + out * (cfg.decal_offset + 0.008), rot)
	var light := OmniLight3D.new()
	light.set_script(TorchLight)
	light.base_energy = cfg.alcove_light_energy
	light.light_color = Color(1.0, 0.72, 0.42)
	light.omni_range = cfg.alcove_light_range
	light.position = wall_point + out * 0.25 + Vector3(0, -0.1, 0)
	builder.add_child(light)


## Pillars, arches and alcoves: those the level lists (DungeonMap.STRUCTURES, hand-placed) and, in long straight
## corridors, an arch every few tiles. Nothing here blocks movement: they are scenery on the walls and ceiling.
func add_structures(builder: Node3D) -> void:
	if not cfg.structures_enabled:
		return
	var placed := {}  # cell -> true, so a hand-placed one isn't doubled by the rule
	for entry in DungeonMap.STRUCTURES:
		var cell: Vector2i = entry.cell
		match entry.kind:
			"arch":
				_arch(builder, cell, entry.get("axis", _corridor_axis(cell)))
			"pillar":
				_pillar(builder, cell, int(entry.get("side", 1)))
			"alcove":
				add_alcove(builder, cell, int(entry.get("side", 1)))
		placed[cell] = true
	var reserved := {}
	for t in DungeonMap.TORCHES:
		reserved[Vector2i(t.x, t.y)] = true
	for l in DungeonMap.LEVERS:
		reserved[l.cell] = true
	for z in DungeonMap.MAP.size():
		for x in DungeonMap.MAP[z].size():
			var cell := Vector2i(x, z)
			if placed.has(cell) or reserved.has(cell) or DungeonMap.is_blocked(cell) or DungeonMap.is_door(cell) or DungeonMap.is_stairs(cell):
				continue
			var axis := _corridor_axis(cell)
			if axis == "":
				continue
			var step := Vector2i(1, 0) if axis == "x" else Vector2i(0, 1)
			var before := 0
			while before < 40 and _corridor_axis(cell - step * (before + 1)) == axis:
				before += 1
			var after := 0
			while after < 40 and _corridor_axis(cell + step * (after + 1)) == axis:
				after += 1
			if before + after + 1 < cfg.arch_min_run:
				continue
			if before > 0 and after > 0 and (before + cfg.arch_offset) % cfg.arch_spacing == 0:
				_arch(builder, cell, axis)


## "x" if this open tile is part of a corridor running east-west (walls north and south), "z" if north-south, else "".
func _corridor_axis(cell: Vector2i) -> String:
	if DungeonMap.is_blocked(cell) or DungeonMap.is_door(cell):
		return ""
	var n := DungeonMap.is_wall(cell + Vector2i(0, -1))
	var sd := DungeonMap.is_wall(cell + Vector2i(0, 1))
	var w := DungeonMap.is_wall(cell + Vector2i(-1, 0))
	var e := DungeonMap.is_wall(cell + Vector2i(1, 0))
	if n and sd and not w and not e:
		return "x"
	if w and e and not n and not sd:
		return "z"
	return ""


## A stone arch across a corridor tile: a pillar against each wall and a lintel over the top, tall enough to walk under.
func _arch(builder: Node3D, cell: Vector2i, axis: String) -> void:
	var s := DungeonMap.TILE_SIZE
	var h := DungeonMap.WALL_HEIGHT
	var centre := DungeonMap.cell_to_world(cell)
	var mat := _material(cfg.wall_textures[0], false)
	var thick: float = cfg.arch_depth
	var lintel_h: float = cfg.lintel_height
	for side in ([0, 2] if axis == "x" else [1, 3]):
		_pillar(builder, cell, side)
	# Long across the corridor, thin along it.
	var size := Vector3(thick, lintel_h, s) if axis == "x" else Vector3(s, lintel_h, thick)
	builder._add_mesh(builder._wall_box(size, mat), centre + Vector3(0, h - lintel_h / 2.0, 0))
	var under := PlaneMesh.new()
	under.size = Vector2(size.x, size.z)
	under.material = mat
	builder._add_mesh(under, centre + Vector3(0, h - lintel_h, 0), Vector3(PI, 0, 0))


## A pillar standing against the wall on `side` of this tile.
func _pillar(builder: Node3D, cell: Vector2i, side: int) -> void:
	var s := DungeonMap.TILE_SIZE
	var h := DungeonMap.WALL_HEIGHT
	var dir := _dir(side)
	var depth: float = cfg.pillar_depth
	var width: float = cfg.pillar_width
	var size := Vector3(depth, h, width) if dir.x != 0 else Vector3(width, h, depth)
	var pos := DungeonMap.cell_to_world(cell) + Vector3(dir.x, 0, dir.y) * (s / 2.0 - depth / 2.0) + Vector3(0, h / 2.0, 0)
	builder._add_mesh(builder._wall_box(size, _material(cfg.wall_textures[0], false)), pos)


## Start the slow pulse of every vein material (one tween drives them all). Call once, after the walls are built.
func start_pulse(builder: Node3D) -> void:
	if _vein_materials.is_empty():
		return
	var tween := builder.create_tween().set_loops()
	var half: float = cfg.vein_pulse_seconds / 2.0
	tween.tween_method(_set_vein_energy, cfg.vein_energy_low, cfg.vein_energy_high, half).set_trans(Tween.TRANS_SINE)
	tween.tween_method(_set_vein_energy, cfg.vein_energy_high, cfg.vein_energy_low, half).set_trans(Tween.TRANS_SINE)


func _set_vein_energy(value: float) -> void:
	for m in _vein_materials:
		m.emission_energy_multiplier = value


## A fixed scatter: the same for a given tile and side every run.
func face_seed(cell: Vector2i, side: int) -> int:
	return absi((cell.x * 73856093) ^ (cell.y * 19349663) ^ (side * 83492791) ^ (cfg.seed * 2654435761))


## Sides run 0 north, 1 west, 2 south, 3 east, as DungeonMap.LEVERS and TORCHES do.
func _dir(side: int) -> Vector2i:
	return [Vector2i(0, -1), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(1, 0)][side]


## Left to right as seen from outside the face, for a quad turned by `rot`.
func _along(rot: Vector3) -> Vector3:
	return Vector3(cos(rot.y), 0, -sin(rot.y))


func _quad(size: Vector2, texture: String, cutout: bool, glow := false) -> QuadMesh:
	var key := "%s|%s|%s|%s" % [size, texture, cutout, glow]
	if not _quads.has(key):
		var q := QuadMesh.new()
		q.size = size
		q.material = _material(texture, cutout, glow)
		_quads[key] = q
	return _quads[key]


func _material(texture: String, cutout: bool, glow := false) -> StandardMaterial3D:
	var key := texture + ("|glow" if glow else "")
	if not _materials.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_texture = load(texture)
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		NormalMaps.apply(m, texture, cutout)  # (A cut-out is a decal; a stone face is not.)
		if cutout:  # Hard pixel edges, no sorting trouble.
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
			m.alpha_scissor_threshold = 0.5
		if glow:  # In Godot 4 the emission texture is ADDED to the emission colour, so the colour is black: only the vein pixels glow.
			m.emission_enabled = true
			m.emission = Color.BLACK
			m.emission_texture = m.albedo_texture
			m.emission_energy_multiplier = cfg.vein_energy_low
			_vein_materials.append(m)
		_materials[key] = m
	return _materials[key]
