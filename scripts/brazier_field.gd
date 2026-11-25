extends Node3D
## The braziers on the level (roadmap 7e.3; DungeonMap.BRAZIERS, burning or not in DungeonMap.brazier_lit): an iron bowl on a floor
## tile, and while it burns a PixelLab flame and a real light (energy 1.4, range 7, in "sprite_lights", so monsters and items beside
## it are lit and the party is not fighting in the dark). It is solid: nobody walks onto its tile (DungeonMap.is_brazier), though
## sight and missiles pass over it.
## This node only SHOWS them. Lighting and snuffing are the dungeon's (Dungeon.ignite_brazier / set_brazier), so the click, a
## Fireball, a thrown torch, burning oil, a puzzle and a loaded save all end up in the same place, and this follows each frame.
## A child of the dungeon ("Braziers"), made by dungeon_builder.gd. Art: art/brazier/ (tools/art/gen_brazier.py).

const DungeonMap := preload("res://scripts/dungeon_map.gd")
const Settings := preload("res://scripts/settings.gd")
const Torch := preload("res://scripts/torch.gd")

const DIR := "res://art/brazier/"
const PIXEL := 0.016          # World units per art pixel (bowl and flame).
const BOWL_TOP := 0.34        # Height of the coals: the flame stands there.
const PROP_BACK := 0.07       # Drawn this far behind the tile's middle (items on the tile stay in front)...
const FLAME_BACK := 0.05      # ...and the flame a little in front of the bowl.
const LIGHT_ENERGY := 1.4     # docs/design/expansion_design.md section 2.
const LIGHT_RANGE := 7.0
const LIGHT_HEIGHT := 0.9
const LIGHT_COLOUR := Color(1.0, 0.68, 0.36)

var braziers := {}  # Cell -> {"prop": Sprite3D, "flame": Sprite3D, "light": OmniLight3D}
var clock := 0.0
var _flame_frames := 1
var _flame_fps := 10.0


func _ready() -> void:
	if DungeonMap.BRAZIERS.is_empty():
		return
	var info = JSON.parse_string(FileAccess.get_file_as_string(DIR + "flame_sheet.json"))
	_flame_frames = int(info.frames)
	_flame_fps = float(info.fps)
	var flame_height: float = float(info.frame_h) * PIXEL
	var bowl: Texture2D = load(DIR + "brazier.png")
	for entry in DungeonMap.BRAZIERS:
		var cell: Vector2i = entry.cell
		var prop := _sprite(bowl)
		prop.set_meta("y", bowl.get_height() * PIXEL / 2.0)
		var flame := _sprite(load(DIR + "flame_sheet.png"))
		flame.hframes = _flame_frames
		flame.set_meta("y", BOWL_TOP + flame_height / 2.0 - 0.06)
		var light: OmniLight3D = Torch.new()
		light.base_energy = LIGHT_ENERGY
		light.shadow_kind = "torches"
		light.light_color = LIGHT_COLOUR
		light.omni_range = LIGHT_RANGE
		light.position = DungeonMap.cell_to_world(cell) + Vector3(0, LIGHT_HEIGHT, 0)
		add_child(light)
		braziers[cell] = {"prop": prop, "flame": flame, "light": light}
	_follow()


func _sprite(texture: Texture2D) -> Sprite3D:
	var s := Sprite3D.new()
	s.texture = texture
	s.pixel_size = PIXEL
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	s.shaded = false  # The bowl is tinted by the light that reaches it (sprite_lighting.gd); the flame is its own light.
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(s)
	return s


func _process(delta: float) -> void:
	if not Settings.reduce_flashing:
		clock += delta
	_follow()


## Match what is drawn to the run state, and keep the two sprites layered toward the camera.
func _follow() -> void:
	var camera := get_viewport().get_camera_3d()
	for cell in braziers:
		var b: Dictionary = braziers[cell]
		var lit: bool = DungeonMap.brazier_lit.get(cell, false)
		var at := DungeonMap.cell_to_world(cell)
		var away := Vector3.ZERO
		if camera != null:
			away = at - camera.global_position
			away.y = 0.0
			away = away.normalized() if away.length() > 0.1 else Vector3.ZERO
		b.prop.position = at + away * PROP_BACK + Vector3(0, b.prop.get_meta("y"), 0)
		b.flame.position = at + away * FLAME_BACK + Vector3(0, b.flame.get_meta("y"), 0)
		b.flame.visible = lit
		b.flame.frame = (int(clock * _flame_fps) + cell.x * 3 + cell.y) % _flame_frames
		b.light.visible = lit
