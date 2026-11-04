extends Node3D
## Builds the 3D dungeon from DungeonMap.MAP using placeholder meshes:
## a cube per wall cell, and a floor + ceiling plane per floor cell.

const DungeonMap := preload("res://scripts/dungeon_map.gd")

const WALL_COLOR := Color(0.45, 0.40, 0.35)
const FLOOR_COLOR := Color(0.28, 0.25, 0.22)
const CEILING_COLOR := Color(0.20, 0.18, 0.17)


func _ready() -> void:
	var s := DungeonMap.TILE_SIZE
	var h := DungeonMap.WALL_HEIGHT

	# Meshes and materials are shared by every tile.
	var wall_mesh := BoxMesh.new()
	wall_mesh.size = Vector3(s, h, s)
	wall_mesh.material = _make_material(WALL_COLOR)

	var floor_mesh := PlaneMesh.new()
	floor_mesh.size = Vector2(s, s)
	floor_mesh.material = _make_material(FLOOR_COLOR)

	var ceiling_mesh := PlaneMesh.new()
	ceiling_mesh.size = Vector2(s, s)
	ceiling_mesh.material = _make_material(CEILING_COLOR)

	for z in DungeonMap.MAP.size():
		for x in DungeonMap.MAP[z].size():
			var cell := Vector2i(x, z)
			var pos := DungeonMap.cell_to_world(cell)
			if DungeonMap.is_wall(cell):
				_add_mesh(wall_mesh, pos + Vector3(0, h / 2.0, 0))
			else:
				_add_mesh(floor_mesh, pos)
				# Flip the plane upside down so its face points down at the player.
				_add_mesh(ceiling_mesh, pos + Vector3(0, h, 0), Vector3(PI, 0, 0))


func _add_mesh(mesh: Mesh, pos: Vector3, rot := Vector3.ZERO) -> void:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = pos
	instance.rotation = rot
	add_child(instance)


## Flat-colour material with nearest filtering (swap in textures later).
func _make_material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	return mat
