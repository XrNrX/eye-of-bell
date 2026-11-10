extends RefCounted
## Wall signs: a small plaque with a few words, hung on a wall face (DungeonMap.SIGNS, documented there).
## Floor 1 has none; the test room labels its stations with them. Built by dungeon_builder.gd after the walls.
##
## PLACEHOLDER ART: the plaque is a flat dark quad and the text a Label3D in Press Start 2P (palette colours), not a PixelLab
## sprite. Fine for signposting a debug level; listed in docs/asset_log.md. Replace with a drawn sign if a real level needs one.

const DungeonMap := preload("res://scripts/dungeon_map.gd")
const FONT := preload("res://art/fonts/PressStart2P-Regular.ttf")

const SIDE_DIRS: Array[Vector2i] = [Vector2i(0, -1), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(1, 0)]
const HEIGHT := 1.45         # Centre of the sign above the floor.
const FONT_SIZE := 16
const PIXEL_SIZE := 0.0058   # World units per font pixel: 16 characters are about 1.5 wide (a wall is 2).
const LINE_GAP := 4
const BONE_300 := Color("c9c0a4")
const TORCH_300 := Color("f5cf80")
const INK := Color("0b0a10")
const RUST_700 := Color("4e2a1a")
const STONE_800 := Color("1d1c27")


## Hang every sign of the current level on `parent`.
static func build(parent: Node3D) -> void:
	for entry in DungeonMap.SIGNS:
		add_sign(parent, entry.cell, int(entry.side), str(entry.text))


## One sign on the wall at `side` of floor `cell`. A line starting with "!" is drawn gold (e.g. "!NOT BUILT YET").
static func add_sign(parent: Node3D, cell: Vector2i, side: int, text: String) -> Node3D:
	var root := Node3D.new()
	root.name = "Sign_%d_%d_%d" % [cell.x, cell.y, side]
	var lines := text.split("\n")
	var widest := 0
	for l in lines:
		widest = maxi(widest, l.lstrip("!").length())
	var line_h := (FONT_SIZE + LINE_GAP) * PIXEL_SIZE
	var w := widest * FONT_SIZE * PIXEL_SIZE + 0.16
	var h := lines.size() * line_h + 0.1
	var plaque := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(w, h)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = STONE_800
	quad.material = mat
	plaque.mesh = quad
	root.add_child(plaque)
	var i := 0
	for l in lines:
		var gold := l.begins_with("!")
		var label := Label3D.new()
		label.text = l.lstrip("!")
		label.font = FONT
		label.font_size = FONT_SIZE
		label.pixel_size = PIXEL_SIZE
		label.outline_size = 0
		label.shaded = false
		label.modulate = TORCH_300 if gold else BONE_300
		label.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		label.position = Vector3(0, h / 2.0 - 0.05 - line_h * (i + 0.5), 0.004)
		root.add_child(label)
		i += 1
	# Place it on the wall face and turn it to face into the room (a Label3D faces +Z).
	var centre := DungeonMap.cell_to_world(cell)
	var d := SIDE_DIRS[side]
	root.position = centre + Vector3(d.x, 0, d.y) * (DungeonMap.TILE_SIZE / 2.0 - 0.03) + Vector3(0, HEIGHT, 0)
	root.rotation.y = atan2(-d.x, -d.y)  # +Z turned toward the cell centre.
	parent.add_child(root)
	return root
