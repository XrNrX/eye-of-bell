extends Node3D
## The burst when a cracked wall breaks: small stone cubes (the wall's own texture) as physics
## bodies that fly out, bounce and settle, plus a puff of dust. Made by dungeon_builder.break_wall;
## it removes itself once the cubes have settled (or after MAX_SECONDS), so nothing lingers and the
## physics load goes back to nothing. The permanent rubble on the floor is a separate, static
## decoration (the builder makes that).
##
## The cubes need something to land on, so for the few seconds it lives this node also carries
## invisible colliders: the floor, the ceiling, and the wall cells around the broken one.

const DungeonMap := preload("res://scripts/dungeon_map.gd")

const CUBES := 16
const CUBE_MIN := 0.09        # Edge length range of a cube, in world units.
const CUBE_MAX := 0.22
const SETTLE_SPEED := 0.12    # Slower than this (and not spinning fast) counts as settled.
const SETTLE_HOLD := 0.5      # Everything must stay settled this long.
const MAX_SECONDS := 4.0      # Remove the cubes after this long however they are moving.
const SHRINK_SECONDS := 0.3   # They shrink away rather than popping out.
const DUST_COLOUR := Color("7b7a88")  # stone_300

var cubes: Array[RigidBody3D] = []
var age := 0.0
var still := 0.0
var finishing := false
var material: Material


## Start the burst in `cell`. `toward` is the direction the debris is pushed (away from the
## wall's far side, toward the party), `material` is the wall's own so the cubes match it.
func start(cell: Vector2i, toward: Vector3, wall_material: Material) -> void:
	material = wall_material
	var centre := DungeonMap.cell_to_world(cell)
	_add_colliders(cell)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(cell) + 17
	for i in CUBES:
		_add_cube(centre, toward, rng)
	_add_dust(centre)


func _add_colliders(cell: Vector2i) -> void:
	var body := StaticBody3D.new()
	add_child(body)
	var floor_shape := CollisionShape3D.new()
	floor_shape.shape = WorldBoundaryShape3D.new()  # Plane through the origin, facing up.
	body.add_child(floor_shape)
	var ceiling_shape := CollisionShape3D.new()
	var ceiling := WorldBoundaryShape3D.new()
	ceiling.plane = Plane(Vector3.DOWN, -DungeonMap.WALL_HEIGHT)
	ceiling_shape.shape = ceiling
	body.add_child(ceiling_shape)
	var s := DungeonMap.TILE_SIZE
	for dz in range(-2, 3):
		for dx in range(-2, 3):
			var c := cell + Vector2i(dx, dz)
			if DungeonMap.is_blocked(c):  # Walls and closed doors hold the debris in.
				var shape := CollisionShape3D.new()
				var box := BoxShape3D.new()
				box.size = Vector3(s, DungeonMap.WALL_HEIGHT, s)
				shape.shape = box
				shape.position = DungeonMap.cell_to_world(c) + Vector3(0, DungeonMap.WALL_HEIGHT / 2.0, 0)
				body.add_child(shape)


func _add_cube(centre: Vector3, toward: Vector3, rng: RandomNumberGenerator) -> void:
	var size := rng.randf_range(CUBE_MIN, CUBE_MAX)
	var cube := RigidBody3D.new()
	cube.mass = size * 4.0
	cube.continuous_cd = true  # Small and fast: do not tunnel through the floor.
	var phys := PhysicsMaterial.new()
	phys.bounce = 0.35
	phys.friction = 0.8
	cube.physics_material_override = phys
	cube.position = centre + Vector3(rng.randf_range(-0.8, 0.8), rng.randf_range(0.25, 1.7), rng.randf_range(-0.8, 0.8))
	cube.rotation = Vector3(rng.randf() * TAU, rng.randf() * TAU, rng.randf() * TAU)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3.ONE * size
	shape.shape = box
	cube.add_child(shape)
	var mesh := MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = Vector3.ONE * size
	box_mesh.material = material
	mesh.mesh = box_mesh
	cube.add_child(mesh)
	add_child(cube)
	cube.linear_velocity = toward * rng.randf_range(0.8, 2.6) + Vector3(rng.randf_range(-1.6, 1.6), rng.randf_range(0.8, 3.0), rng.randf_range(-1.6, 1.6))
	cube.angular_velocity = Vector3(rng.randf_range(-8, 8), rng.randf_range(-8, 8), rng.randf_range(-8, 8))
	cubes.append(cube)


## A soft grey puff that swells, drifts up and fades.
func _add_dust(centre: Vector3) -> void:
	var dust := CPUParticles3D.new()
	dust.position = centre + Vector3(0, 0.9, 0)
	dust.amount = 36
	dust.lifetime = 1.5
	dust.one_shot = true
	dust.explosiveness = 0.9
	dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	dust.emission_box_extents = Vector3(0.8, 0.8, 0.8)
	dust.direction = Vector3.UP
	dust.spread = 90.0
	dust.initial_velocity_min = 0.2
	dust.initial_velocity_max = 1.0
	dust.gravity = Vector3(0, 0.15, 0)
	dust.damping_min = 0.6
	dust.damping_max = 1.2
	dust.scale_amount_min = 0.7
	dust.scale_amount_max = 1.6
	var growth := Curve.new()
	growth.add_point(Vector2(0, 0.5))
	growth.add_point(Vector2(1, 1.6))
	dust.scale_amount_curve = growth
	var quad := QuadMesh.new()
	quad.size = Vector2(0.4, 0.4)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	quad.material = mat
	dust.mesh = quad
	dust.color = Color(DUST_COLOUR, 0.55)
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 1))
	ramp.set_color(1, Color(1, 1, 1, 0))
	dust.color_ramp = ramp
	add_child(dust)
	dust.emitting = true


func _physics_process(delta: float) -> void:
	if finishing:
		return
	age += delta
	var all_settled := true
	for cube in cubes:
		if not is_instance_valid(cube):
			continue
		if not cube.sleeping and cube.linear_velocity.length() > SETTLE_SPEED:
			all_settled = false
			break
	still = still + delta if all_settled else 0.0
	if still >= SETTLE_HOLD or age >= MAX_SECONDS:
		_finish()


## Shrink the cubes away and remove everything (the dust has usually faded by then).
func _finish() -> void:
	finishing = true
	for cube in cubes:
		if is_instance_valid(cube):
			cube.freeze = true  # Stop simulating them; they are only shrinking now.
			create_tween().tween_property(cube.get_child(1), "scale", Vector3.ZERO, SHRINK_SECONDS)  # (The mesh, not the body: bodies cannot be scaled.)
	get_tree().create_timer(maxf(SHRINK_SECONDS, 1.6 - age) + 0.1).timeout.connect(queue_free)
