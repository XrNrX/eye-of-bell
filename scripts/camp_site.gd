extends Node3D
## A camp in the dungeon: a campfire of crossed logs with an animated flame, a cooking spit over it, a light
## that flickers (group "sprite_lights", so monsters and the party's tiles are lit by it), and one bedroll for each of the four heroes.
## A level places one with a STRUCTURES entry {"cell": Vector2i, "kind": "campfire"}; wall_decor.add_structures builds it. Scenery
## for now: nothing blocks movement and nothing can be clicked yet (making camp is roadmap 7h.2, cooking 7h.3).
## Art: tools/art/gen_camp.py -> art/camp/ (PixelLab pieces, see docs/asset_log.md): the pit and spit are billboards at PIXEL world units
## an art pixel, the flame a looping flipbook (fx_flipbook.gd); the bedrolls are small soft-edged 3D models (squashed capsules and spheres: a mat, a quilt, a pillow and a rolled blanket) with a drawn quilt top.

const DungeonMap := preload("res://scripts/dungeon_map.gd")
const FxFlipbook := preload("res://scripts/fx_flipbook.gd")
const TorchLight := preload("res://scripts/torch.gd")

const DIR := "res://art/camp/"
const PIXEL := 0.022          # World size of one art pixel for the pit (a 64 px picture is 1.4 units wide), times FIRE_SCALE.
const FIRE_SCALE := 1.45      # The fire and spit are drawn bigger than life next to the bedrolls: the fire is the centre of the camp.
const FLAME_PIXEL := 0.0174 * FIRE_SCALE * 0.95   # Smaller than the pit's logs, so they show round it. # The flame is 0.79 of the pit's pixel size: it sits inside the logs.
const SPIT_PIXEL := 0.0253 * FIRE_SCALE
const FLAME_TOWARD := 0.3     # The flame and the spit stand this far toward the camera from the logs, so the logs never hide them
const SPIT_TOWARD := 0.12     # from any side (billboards at the same depth fight).
const KINDLING_TOWARD := 0.5  # The kindling and coals lie in front of the flame's base and the front logs just behind them, so it burns from inside the pile.
const KINDLING_SCALE := 0.55  # (Smaller than the pit: a busy bed of coals at full size hid the flame.)
const PIT_FRONT_TOWARD := 0.4
const FLAME_WIDTH := 0.7      # The flame is squeezed to this share of its width: a tall flame, not a wide blob that hides the logs.
const FLAME_BASE := 0.3 * FIRE_SCALE   # How high the flame's base stands: on the kindling, not above it.

## One bedroll for each hero position (0 and 1 the front pair), where it lies in world units from the fire (x east, z south): two behind the
## fire, two in front. Each lies along the line from the fire with its pillow outward and its feet to the flames.
const BEDROLLS := [Vector2(-2.3, -1.5), Vector2(2.3, -1.5), Vector2(-2.2, 1.9), Vector2(2.2, 1.9)]
## Each blanket's tint (a quilt colour multiplied by it), so the four beds can be told apart.
const BLANKETS := [Color(0.84, 0.86, 0.96), Color(1.0, 0.76, 0.66), Color(0.9, 0.88, 0.84), Color(1.0, 0.88, 0.58)]   # Cool grey, rust, bone, ochre: never green (the curse; firelight turns a blue tint olive, so the cool one is faint).
const BED_SIZE := Vector3(1.7, 0.1, 0.85)      # The straw pallet: length, thickness, width.
const BLANKET_SIZE := Vector3(1.45, 0.07, 0.8)
const BED_BRIGHTNESS := 1.05   # The patchwork picture has its own strong colours: close to as drawn (albedo may exceed 1 for a little lift in the dim camp).
const BED_TINT := 0.45        # How much of the hero's blanket colour tints their bed (0 none, 1 full).
const BED_PIXEL := 0.011      # World size of one art pixel of the bedroll picture (175 px long: about 1.9 units, 0.77 wide).
const BED_THICKNESS := 0.24   # How tall the plump middle of each bed is (the edges roll down to the floor).
const ROLL_END := 27.5        # The picture's pixel column where the strapped roll ends and the patchwork begins.
const ROLL_BULGE := 1.3       # The roll stands this much taller than the quilt's middle.
const PATCH_X := [28.5, 71.0, 121.5, 168.0]   # The seams between the patches in the picture, in its pixels (along it)...
const PATCH_Y := [0.0, 35.0, 70.0]            # ...and across it (two rows). Each patch swells on its own; the seams stay low.
const PATCH_PUFF := 0.16      # Each patch swells this share higher at its middle.
const WRINKLE := 0.014        # Height of the soft cloth wrinkles, in world units.
## The smoke is PixelLab's too (art/camp/smoke_sheet.png, a one-shot puff that rises inside its own frames): a new one every SMOKE_EVERY seconds.
const SMOKE_PIXEL := 0.055    # World size of one art pixel of a puff (20x30 px: about 1.1 wide, 1.65 tall).
const SMOKE_EVERY := Vector2(0.9, 1.5)
const SMOKE_BASE := 0.95      # Where a puff's bottom starts above the floor: over the flame's tip.
const SMOKE_TOWARD := 0.2
const EMBER_PIXEL := 0.014    # World size of one art pixel of the embers (52x74 px: about 0.7 wide, 1 tall).
const EMBER_TOWARD := 0.35    # Toward the camera, in front of the flame, so the sparks show over it from every side.
const EMBER_BASE := 0.5       # Where the embers' bottom starts above the floor.
const PALLET_COLOUR := Color("74553a")   # leather_400
const PILLOW_COLOUR := Color("9c9278")   # bone_500

var cell := Vector2i.ZERO
var _bed_px := Vector2(92, 36)   # The bed picture's size in pixels (set when the beds are built).
var flame: MeshInstance3D
var spit: Sprite3D
var kindling: Sprite3D
var pit_front: Sprite3D
var light: OmniLight3D
var glow: OmniLight3D   # A wider, dimmer warm pool that lights the beds and the stone round the camp.
var embers: MeshInstance3D
var _smoke_wait := 0.5
var _smoke_sheet: Texture2D
var _smoke_info = {}
var bedrolls := []   # [Node3D], one per hero position


## Build a camp on this tile as a child of the dungeon.
static func build(builder: Node3D, at: Vector2i) -> Node3D:
	var camp = load("res://scripts/camp_site.gd").new()
	camp.cell = at
	builder.add_child(camp)
	return camp


func _ready() -> void:
	add_to_group("camp_sites")
	position = DungeonMap.cell_to_world(cell)
	if not ResourceLoader.exists(DIR + "pit.png"):
		return  # The art is generated: without it there is nothing to show.
	for i in BEDROLLS.size():
		bedrolls.append(_bed_sprite(i) if ResourceLoader.exists(DIR + "bed.png") else _bedroll(i))
	_sprite("pit", PIXEL * FIRE_SCALE, Vector2.ZERO)
	kindling = _sprite("kindling", PIXEL * FIRE_SCALE * KINDLING_SCALE, Vector2.ZERO)
	kindling.position.y = kindling.texture.get_height() * PIXEL * FIRE_SCALE * KINDLING_SCALE * 0.5 + 0.02
	pit_front = _sprite("pit_front", PIXEL * FIRE_SCALE, Vector2.ZERO)
	spit = _sprite("spit", SPIT_PIXEL, Vector2.ZERO)
	_add_flame()
	light = OmniLight3D.new()
	light.set_script(TorchLight)
	light.base_energy = 1.5
	light.light_color = Color(1.0, 0.72, 0.42)
	light.omni_range = 9.0
	light.position = Vector3(0, 0.8, 0)
	add_child(light)
	glow = OmniLight3D.new()
	glow.set_script(TorchLight)
	glow.base_energy = 0.55
	glow.light_color = Color(1.0, 0.6, 0.32)
	glow.omni_range = 15.0
	glow.position = Vector3(0, 0.35, 0)
	glow.shadow_enabled = false
	add_child(glow)
	if ResourceLoader.exists(DIR + "embers_sheet.png"):
		var info = JSON.parse_string(FileAccess.get_file_as_string(DIR + "embers_sheet.json"))
		embers = FxFlipbook.new()
		embers.setup(load(DIR + "embers_sheet.png"), int(info.frames), float(info.fps), true, EMBER_PIXEL, Color.WHITE, true)
		embers.position = Vector3(0, EMBER_BASE + float(info.frame_h) * 0.5 * EMBER_PIXEL, 0)
		add_child(embers)
	if ResourceLoader.exists(DIR + "smoke_sheet.png"):
		_smoke_sheet = load(DIR + "smoke_sheet.png")
		_smoke_info = JSON.parse_string(FileAccess.get_file_as_string(DIR + "smoke_sheet.json"))
	_face_camera()


func _process(delta: float) -> void:
	_face_camera()
	if _smoke_sheet == null:
		return
	_smoke_wait -= delta
	if _smoke_wait <= 0.0:
		_smoke_wait = randf_range(SMOKE_EVERY.x, SMOKE_EVERY.y)
		_puff()


## One puff of smoke over the fire, toward the camera a little like the flame so the logs never hide it; it frees itself when it has played.
func _puff() -> void:
	var puff = FxFlipbook.new()
	puff.setup(_smoke_sheet, int(_smoke_info.frames), float(_smoke_info.fps), false, SMOKE_PIXEL, Color.WHITE, false)
	var toward := Vector3.ZERO
	var cam := get_viewport().get_camera_3d()
	if cam != null:
		toward = Vector3(cam.global_position.x - global_position.x, 0.0, cam.global_position.z - global_position.z).normalized() * SMOKE_TOWARD
	puff.position = toward + Vector3(randf_range(-0.12, 0.12), SMOKE_BASE + float(_smoke_info.frame_h) * 0.5 * SMOKE_PIXEL, randf_range(-0.12, 0.12))
	add_child(puff)


## Keep the flame and the spit a little toward the camera from the logs, whichever side it is on.
func _face_camera() -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null or flame == null:
		return
	var d := Vector3(cam.global_position.x - global_position.x, 0.0, cam.global_position.z - global_position.z)
	if d.length() < 0.01:
		return
	d = d.normalized()
	flame.position = Vector3(d.x * FLAME_TOWARD, flame.position.y, d.z * FLAME_TOWARD)
	if spit != null:
		spit.position = Vector3(d.x * SPIT_TOWARD, spit.position.y, d.z * SPIT_TOWARD)
	if kindling != null:
		kindling.position = Vector3(d.x * KINDLING_TOWARD, kindling.position.y, d.z * KINDLING_TOWARD)
	if pit_front != null:
		pit_front.position = Vector3(d.x * PIT_FRONT_TOWARD, pit_front.position.y, d.z * PIT_FRONT_TOWARD)
	if embers != null:
		embers.position = Vector3(d.x * EMBER_TOWARD, embers.position.y, d.z * EMBER_TOWARD)


## A bedroll as the PixelLab picture (art/camp/bed.png: a top-down bedroll, from the user's bedroll image) wrapped over a plump, rounded mat of real
## 3D (`_bed_mesh`): its top is a pillow-like swell BED_THICKNESS high that rolls down to the floor round every edge and corner, so it stands on
## the stone with a thick rounded body, like a real object, and never hovers. It is fixed in place and turned once about the vertical so the strapped
## roll (the left end of the art) points at the fire: nothing tips or turns it toward the camera (a billboard floated and a camera tilt swung).
## Shaded, so the fire and the torches light it; tinted with the hero's blanket colour. The list of bedrolls holds the mesh.
func _bed_sprite(index: int) -> MeshInstance3D:
	var spot: Vector2 = BEDROLLS[index]
	var tex: Texture2D = load(DIR + "bed.png")
	var bed := MeshInstance3D.new()
	_bed_px = Vector2(tex.get_width(), tex.get_height())
	bed.mesh = _bed_mesh(_bed_px * BED_PIXEL)
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = tex
	mat.albedo_color = Color.WHITE.lerp(BLANKETS[index % BLANKETS.size()], BED_TINT) * BED_BRIGHTNESS   # A gentle tint per hero: the patches carry the colour.
	mat.albedo_color.a = 1.0
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	mat.alpha_scissor_threshold = 0.5
	mat.roughness = 1.0
	bed.material_override = mat
	bed.position = Vector3(spot.x, 0.0, spot.y)
	bed.rotation.y = atan2(-spot.y, spot.x)   # Local +x (the blanket end of the art) points away from the fire, the roll toward it.
	_no_shadow(bed)
	add_child(bed)
	return bed


## A plump, cloth-detailed mat `size` wide (x) and deep (z), built from a fine grid over the footprint (a, b in -1..1; the picture is mapped
## straight down onto it, its top toward -z, its left end toward -x). The height (`_bed_height`) is a rounded pillow that rolls down to the floor at
## the edges and corners, with the cloth on top of it: a rolled blanket bulging at the left end, a crease where it meets the patchwork, the quilt's
## diamonds each puffed (the same lattice as the stitching in the picture, gen_camp.quilted_bed) and a few soft wrinkles. Normals come from the
## slope, so the light picks out every puff and fold. Built once per bed, from arrays (a few thousand vertices).
func _bed_mesh(size: Vector2) -> ArrayMesh:
	var nx := 112
	var nz := 44
	var half := size * 0.5
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var eps_a := 0.35 / nx
	var eps_b := 0.35 / nz
	for j in nz + 1:
		for i in nx + 1:
			var a := -1.0 + 2.0 * i / nx
			var b := -1.0 + 2.0 * j / nz
			var dhdx := (_bed_height(a + eps_a, b) - _bed_height(a - eps_a, b)) / (2.0 * eps_a * half.x)
			var dhdz := (_bed_height(a, b + eps_b) - _bed_height(a, b - eps_b)) / (2.0 * eps_b * half.y)
			verts.append(Vector3(a * half.x, _bed_height(a, b), b * half.y))
			normals.append(Vector3(-dhdx, 1.0, -dhdz).normalized())
			uvs.append(Vector2(float(i) / nx, float(j) / nz))
	var indices := PackedInt32Array()
	for j in nz:
		for i in nx:
			var v00 := j * (nx + 1) + i
			var v10 := v00 + 1
			var v01 := v00 + nx + 1
			var v11 := v01 + 1
			indices.append_array([v00, v10, v11, v00, v11, v01])   # Clockwise seen from above: Godot's front face.
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


## How much of a patch's swell there is at `v` (a pixel along an axis) given the seams `edges` on that axis: 0 outside the patches and on a seam,
## rising to 1 in the middle of a patch, flat on top and steep at the seams (a plump cushion, not a point).
func _patch_swell(edges: Array, v: float) -> float:
	for k in edges.size() - 1:
		if v >= edges[k] and v < edges[k + 1]:
			var t: float = (v - edges[k]) / (edges[k + 1] - edges[k])
			return pow(sin(PI * t), 0.5)
	return 0.0


## The height of the mat at (a, b) in -1..1 across it (0 at the edges and corners). `px` and `py` are the picture's pixel there, which is how
## the geometry lines up with the drawn stitching.
func _bed_height(a: float, b: float) -> float:
	var px := (a + 1.0) * 0.5 * _bed_px.x
	var py := (b + 1.0) * 0.5 * _bed_px.y
	if px < ROLL_END:   # The rolled blanket at the foot: its own round bulge, taller than the quilt, across the width of the roll.
		var c := (px - ROLL_END * 0.5) / (ROLL_END * 0.5)
		return BED_THICKNESS * ROLL_BULGE * sqrt(maxf(0.0, 1.0 - pow(absf(c), 4.0) - pow(absf(b), 4.0)))
	var base := BED_THICKNESS * sqrt(maxf(0.0, 1.0 - pow(absf(a), 4.0) - pow(absf(b), 4.0)))
	var crease := smoothstep(ROLL_END, ROLL_END + 5.0, px)   # The quilt dips where it meets the roll.
	var puff := _patch_swell(PATCH_X, px) * _patch_swell(PATCH_Y, py)   # 0 on a seam, 1 in the middle of a patch.
	var wrinkle := 0.5 * sin(a * 7.0 + b * 2.0) + 0.25 * sin(a * 13.0 - b * 3.0 + 1.0)
	return base * crease * (1.0 + PATCH_PUFF * puff) + WRINKLE * wrinkle * crease * clampf(base / BED_THICKNESS * 2.0, 0.0, 1.0)


## A bedroll lying on the floor, all soft curves (no straight box edges): a straw mat with rounded ends, a puffy quilted blanket on it, a round
## pillow at the head and a rolled blanket at the foot. Real 3D so it sits on the stone and looks right from every side. Shaded, so the fire
## lights it. The head points away from the fire. (Every body is a capsule or sphere squashed flat: a capsule's axis is mesh Y, so a flat bed
## is turned a quarter about z and squashed along mesh X, which then is up.)
func _bedroll(index: int) -> Node3D:
	var spot: Vector2 = BEDROLLS[index]
	var bed := Node3D.new()
	bed.position = Vector3(spot.x, 0.0, spot.y)
	bed.rotation.y = atan2(-spot.y, spot.x)   # Local +x (the head end) points away from the fire.
	add_child(bed)
	var tint: Color = BLANKETS[index % BLANKETS.size()]
	var mat := _soft(_capsule(BED_SIZE.x, BED_SIZE.z * 0.5), Vector3(BED_SIZE.y / BED_SIZE.z, 1.0, 1.0), _material(PALLET_COLOUR))
	mat.position = Vector3(0, BED_SIZE.y * 0.5, 0)
	bed.add_child(mat)
	var quilt := _material(tint)
	if ResourceLoader.exists(DIR + "quilt.png"):
		quilt.albedo_texture = load(DIR + "quilt.png")
		quilt.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	var blanket := _soft(_capsule(BLANKET_SIZE.x, BLANKET_SIZE.z * 0.5), Vector3(BLANKET_SIZE.y * 1.9 / BLANKET_SIZE.z, 1.0, 1.0), quilt)
	blanket.position = Vector3(-0.1, BED_SIZE.y + BLANKET_SIZE.y * 0.55, 0)
	bed.add_child(blanket)
	var pillow := MeshInstance3D.new()
	var ball := SphereMesh.new()
	ball.radius = 0.3
	ball.height = 0.6
	ball.radial_segments = 16
	ball.rings = 8
	pillow.mesh = ball
	pillow.scale = Vector3(0.95, 0.45, 1.25)
	pillow.material_override = _material(PILLOW_COLOUR)
	pillow.position = Vector3(BED_SIZE.x * 0.5 - 0.34, BED_SIZE.y + BLANKET_SIZE.y + 0.07, 0)
	_no_shadow(pillow)
	bed.add_child(pillow)
	var roll := MeshInstance3D.new()   # The blanket rolled up and tied at the foot, lying across the bed.
	var tube := CapsuleMesh.new()
	tube.radius = 0.13
	tube.height = BLANKET_SIZE.z * 1.05
	tube.radial_segments = 12
	tube.rings = 4
	roll.mesh = tube
	roll.rotation.x = PI * 0.5   # Its length across the bed (along z).
	roll.material_override = _material(tint * 0.8)
	roll.position = Vector3(-BED_SIZE.x * 0.5 + 0.24, BED_SIZE.y + BLANKET_SIZE.y + 0.1, 0)
	_no_shadow(roll)
	bed.add_child(roll)
	return bed


## A capsule `length` long in all and `radius` round, smooth, lying along the bed (x).
func _capsule(length: float, radius: float) -> CapsuleMesh:
	var m := CapsuleMesh.new()
	m.radius = radius
	m.height = length
	m.radial_segments = 20
	m.rings = 6
	return m


## A capsule laid along x and squashed (`squash.x` is the height as a share of the width), with a material and no shadow.
func _soft(mesh: Mesh, squash: Vector3, material: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.rotation.z = PI * 0.5
	node.scale = squash
	node.material_override = material
	_no_shadow(node)
	return node


func _material(colour: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = colour
	m.roughness = 1.0
	return m


func _no_shadow(node: GeometryInstance3D) -> void:
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _sprite(file: String, pixel: float, offset: Vector2, tint := Color.WHITE, mirror := false) -> Sprite3D:
	var sprite := Sprite3D.new()
	var tex: Texture2D = load(DIR + file + ".png")
	sprite.texture = tex
	sprite.pixel_size = pixel
	sprite.flip_h = mirror
	sprite.modulate = tint
	sprite.shaded = false
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sprite.position = Vector3(offset.x, tex.get_height() * pixel * 0.5, offset.y)
	add_child(sprite)
	return sprite


func _add_flame() -> void:
	var info = JSON.parse_string(FileAccess.get_file_as_string(DIR + "flame_sheet.json"))
	var frames := int(info.frames)
	flame = FxFlipbook.new()
	flame.setup(load(DIR + "flame_sheet.png"), frames, float(info.fps), true, FLAME_PIXEL, Color.WHITE, false)
	# The frame's anchor (24, 58 of 76) is 18 px above its bottom edge: stand it on the top of the logs.
	var h := float(info.frame_h)
	flame.position = Vector3(0, FLAME_BASE + (h * 0.5 - 18.0) * FLAME_PIXEL, -0.2)  # (A little toward the party: billboards of the same depth fight, and the flame must win over the logs.)
	flame.scale = Vector3(FLAME_WIDTH, 1.0, 1.0)
	add_child(flame)
