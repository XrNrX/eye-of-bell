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
const BLANKETS := [Color(0.85, 0.9, 1.0), Color(1.0, 0.8, 0.72), Color(0.82, 1.0, 0.82), Color(1.0, 0.95, 0.7)]
const BED_SIZE := Vector3(1.7, 0.1, 0.85)      # The straw pallet: length, thickness, width.
const BLANKET_SIZE := Vector3(1.45, 0.07, 0.8)
const PALLET_COLOUR := Color("74553a")   # leather_400
const PILLOW_COLOUR := Color("9c9278")   # bone_500

var cell := Vector2i.ZERO
var flame: MeshInstance3D
var spit: Sprite3D
var kindling: Sprite3D
var pit_front: Sprite3D
var light: OmniLight3D
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
		bedrolls.append(_bedroll(i))
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
	_face_camera()


func _process(_delta: float) -> void:
	_face_camera()


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
