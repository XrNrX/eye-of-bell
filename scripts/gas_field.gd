extends Node3D
## Toxic gas on the floor: a node in the dungeon ("Gas", made by dungeon_builder.gd, group "gas", `Dungeon.gas`).
##
## A monster whose MonsterDef has `death_gas_chance` may let a cloud off when it dies (Monster._release_gas rolls it with the combat dice):
## `release(cell, radius)` lays a cloud on every open tile within `radius` tiles of the body (a square, walls skipped), each a one-shot
## flipbook (art/spells/gas/cloud_sheet, a PixelLab VFX) that lasts `gas_seconds`. Every second a hero's party standing in it loses
## `gas_hero_dps` HP each (Party.gas_party, source "gas"). Monsters are not hurt by it. Gas is not saved and does not stop a fire: a first
## version for testing. Numbers are in the "Gas" group of data/light.tres (light_config.gd).

const DungeonMap := preload("res://scripts/dungeon_map.gd")
const LightConfig := preload("res://scripts/light_config.gd")
const Flipbook := preload("res://scripts/fx_flipbook.gd")

const SHEET := "res://art/spells/gas/cloud_sheet"  # .png and .json (tools/art/gen_spell_fx.py)

var cfg: Resource = LightConfig.get_config()
var party: Node
var clouds := {}   # Vector2i -> {"left": seconds, "tick": seconds since the last sting, "flip": Flipbook or null}
var released := 0  # Clouds let off so far (tests read this).
var stung := 0     # Stings the party has taken so far (tests read this).
var _sheet: Dictionary = {}
var _say_wait := 0.0


func _ready() -> void:
	add_to_group("gas")
	if ResourceLoader.exists(SHEET + ".png"):
		var info = JSON.parse_string(FileAccess.get_file_as_string(SHEET + ".json"))
		if info is Dictionary:
			_sheet = {"texture": load(SHEET + ".png"), "frames": int(info.frames)}


func has_gas(cell: Vector2i) -> bool:
	return clouds.has(cell)


## Let a cloud off around `cell`. Returns how many tiles are covered. A tile already gassed has its time topped up.
func release(cell: Vector2i, radius := 1) -> int:
	var count := 0
	var seconds: float = cfg.gas_seconds
	for dx in range(-radius, radius + 1):
		for dz in range(-radius, radius + 1):
			var c := cell + Vector2i(dx, dz)
			if DungeonMap.is_wall(c):
				continue
			count += 1
			if clouds.has(c):
				clouds[c].left = seconds
				continue
			clouds[c] = {"left": seconds, "tick": 0.0, "flip": _make_flip(c, seconds)}
	released += 1
	get_tree().call_group("audio", "play", "monster_die")  #
	return count


func _make_flip(cell: Vector2i, seconds: float) -> MeshInstance3D:
	if _sheet.is_empty():
		return null
	var flip: MeshInstance3D = Flipbook.new()
	var px: float = cfg.gas_pixel
	flip.setup(_sheet.texture, _sheet.frames, float(_sheet.frames) / seconds, false, px, Color(1, 1, 1), false, 1.0)
	flip.position = DungeonMap.cell_to_world(cell) + Vector3(0, 40.0 * px + 0.1, 0)
	flip.t = 0.05 * float((cell.x * 7 + cell.y * 3) % 4)  # Out of step with the next tile.
	add_child(flip)
	return flip


func _process(delta: float) -> void:
	_say_wait -= delta
	if clouds.is_empty():
		return
	if party == null or not is_instance_valid(party):
		party = get_tree().get_first_node_in_group("party")
	for cell in clouds.keys():
		var g: Dictionary = clouds[cell]
		g.left -= delta
		g.tick += delta
		while g.tick >= 1.0:
			g.tick -= 1.0
			if party != null and DungeonMap.player_cell == cell:
				stung += 1
				party.gas_party(int(cfg.gas_hero_dps), _say_wait <= 0.0)
				_say_wait = 4.0  # One line in the log, not one a second.
		if g.left <= 0.0:
			if g.flip != null and is_instance_valid(g.flip):
				g.flip.queue_free()
			clouds.erase(cell)
