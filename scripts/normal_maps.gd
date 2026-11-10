extends RefCounted
## Normal maps for the 3D surfaces (walls, floor, ceiling, doors, decals): art/normals/<folder>/<name>_n.png, made from each
## texture's brightness by tools/art/gen_normal_maps.py. `apply(material, albedo_path)` hangs the matching one on a material when
## it exists, so torch and spell light rake across the stone instead of only tinting it. The strengths are in
## data/wall_decor.tres, group "Normal maps" (normal_enabled, normal_strength, normal_decal_strength): change them and re-run.
##
## Surfaces made from a hand-built mesh need tangents (dungeon_builder._wall_box writes them); QuadMesh, PlaneMesh and BoxMesh have
## their own.

const WallDecorConfig := preload("res://scripts/wall_decor_config.gd")


## Add the normal map for `albedo_path` to `mat` if there is one. `decal` uses the gentler decal strength.
static func apply(mat: BaseMaterial3D, albedo_path: String, decal := false) -> void:
	var cfg: Resource = WallDecorConfig.get_config()
	if cfg == null or not cfg.normal_enabled:
		return
	var path := "res://art/normals/%s/%s_n.png" % [albedo_path.get_base_dir().get_file(), albedo_path.get_file().get_basename()]
	if not ResourceLoader.exists(path):
		return
	mat.normal_enabled = true
	mat.normal_texture = load(path)
	mat.normal_scale = cfg.normal_decal_strength if decal else cfg.normal_strength
