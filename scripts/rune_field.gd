extends Node3D
## Darkness runes (roadmap 7e.4; DungeonMap.RUNES: {"id", "cell": the floor tile in front, "side": which wall of that tile}): a ring
## of circular runes on a wall face that shows only while NO light reaches the floor tile in front of it, beyond the dark's own cold
## floor: no flame in a hero's hand (or anywhere near enough), no lit sconce or brazier in reach, no spell in the air. The question
## is asked of sprite_lighting.gd (the same light that tints monsters and items), never worked out twice.
## It comes in over a second in four hard steps (dim to bright palette greens, never a smooth fade) and goes the same way, quicker.
## Once fully shown the party may touch it (click or F, player.gd): Dungeon.read_runes opens the wall.
## A child of the dungeon ("Runes"), made by dungeon_builder.gd. Art: art/runes/ (tools/art/gen_runes.py, PixelLab's VFX tool).

const DungeonMap := preload("res://scripts/dungeon_map.gd")
const Settings := preload("res://scripts/settings.gd")
const LightConfig := preload("res://scripts/light_config.gd")

const DIR := "res://art/runes/"
const PIXEL := 2.0 / 256.0    # The wall's own pixel density.
const OFF_WALL := 0.035       # How far the runes stand off the face (over its grime).
const FADE_IN := 1.0
const FADE_OUT := 0.4
const STEPS := 4              # Three dim steps, then the living runes.
const PROBE_HEIGHT := 0.5     # Where on the floor tile the light is asked for.

var runes := {}   # Rune id -> {"entry", "sprite", "fade", "level": 0..1}
var clock := 0.0
var _fps := 8.0


func _ready() -> void:
	if DungeonMap.RUNES.is_empty():
		return
	var info = JSON.parse_string(FileAccess.get_file_as_string(DIR + "rune_sheet.json"))
	_fps = float(info.fps)
	for entry in DungeonMap.RUNES:
		var live := _sprite(entry, load(DIR + "rune_sheet.png"), int(info.frames))
		var fade := _sprite(entry, load(DIR + "rune_fade_sheet.png"), STEPS - 1)
		runes[entry.id] = {"entry": entry, "sprite": live, "fade": fade, "level": 0.0}


func _sprite(entry: Dictionary, texture: Texture2D, frames: int) -> Sprite3D:
	var s := Sprite3D.new()
	s.texture = texture
	s.hframes = frames
	s.pixel_size = PIXEL
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	s.shaded = false
	s.double_sided = false
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var d: Vector2i = DungeonMap.rune_wall(entry) - entry.cell
	var out := DungeonMap.TILE_SIZE / 2.0 - OFF_WALL
	s.position = DungeonMap.cell_to_world(entry.cell) + Vector3(d.x * out, DungeonMap.WALL_HEIGHT / 2.0, d.y * out)
	s.rotation.y = atan2(-float(d.x), -float(d.y))
	s.visible = false
	add_child(s)
	return s


## Is the floor tile in front of these runes as dark as the dungeon gets?
func is_dark(entry: Dictionary) -> bool:
	var lighting := get_parent().get_node_or_null("SpriteLighting")
	if lighting == null:
		return false
	var at: Vector3 = DungeonMap.cell_to_world(entry.cell) + Vector3(0, PROBE_HEIGHT, 0)
	var seen: Color = lighting.light_at(at, entry.cell, lighting.gather_lights())
	var floor_light: Color = lighting.light_at(at, entry.cell, [])
	var added := maxf(seen.r - floor_light.r, maxf(seen.g - floor_light.g, seen.b - floor_light.b))
	return added <= LightConfig.get_config().rune_dark_max


## Are the runes on this wall of this tile fully shown (and not yet read)?
func shown(cell: Vector2i, side: int) -> String:
	for id in runes:
		var r: Dictionary = runes[id]
		if r.entry.cell == cell and int(r.entry.side) == side and r.level >= 1.0 and not DungeonMap.runes_read.has(id):
			return id
	return ""


func _process(delta: float) -> void:
	if not Settings.reduce_flashing:
		clock += delta
	for id in runes:
		var r: Dictionary = runes[id]
		if DungeonMap.runes_read.has(id):
			r.level = 0.0
		elif is_dark(r.entry):
			r.level = minf(1.0, r.level + delta / FADE_IN)
		else:
			r.level = maxf(0.0, r.level - delta / FADE_OUT)
		var step := int(r.level * STEPS)   # 0 nothing, 1 to 3 dim, 4 alive.
		r.sprite.visible = step >= STEPS
		r.fade.visible = step > 0 and step < STEPS
		if r.fade.visible:
			r.fade.frame = step - 1
		r.sprite.frame = int(clock * _fps) % r.sprite.hframes
