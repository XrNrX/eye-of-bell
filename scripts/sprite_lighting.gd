extends Node
## Monsters and floor items are lit by the light that really reaches them (the dark: docs/combat_design.md "Light and darkness").
## They stay unshaded sprites, because Godot lights a billboard sprite from behind (its normal faces away from the camera), so a
## skeleton in front of a torch-bearing party came out a silhouette lit by the wall torch beyond it. Instead this node tints each
## sprite every frame: a cold floor of light (LightConfig.sprite_min_light, the eyes adjusted to the dark, so a silhouette always
## reads), plus each light in range whose tile can see the sprite's tile (walls and closed doors block it, as the real shadows do):
## light_color x light_energy x (1 - distance / range) ^ omni_attenuation, times sprite_light_gain. A light counts if it is in the
## group "sprite_lights": the party's light, the wall torches, lights burning on the floor and the spells' flipbook lights.
## A child of the dungeon, made by dungeon_builder.gd ("SpriteLighting"). Monsters get it through Monster.set_light (their status
## tint, e.g. held blue, is kept on top); floor piles, armed traps and levers directly.

const DungeonMap := preload("res://scripts/dungeon_map.gd")
const LightConfig := preload("res://scripts/light_config.gd")

var cfg: Resource = LightConfig.get_config()


func _process(_delta: float) -> void:
	var dungeon := get_parent()
	var lights := []
	for l in get_tree().get_nodes_in_group("sprite_lights"):
		if l is OmniLight3D and l.is_visible_in_tree() and l.light_energy > 0.0:
			var at: Vector3 = l.global_position
			lights.append({"pos": at, "cell": cell_of(at), "range": l.omni_range, "att": l.omni_attenuation, "colour": l.light_color * l.light_energy})
	for m in get_tree().get_nodes_in_group("monsters"):
		if m.sprite != null:
			m.set_light(light_at(m.sprite.global_position, m.cell, lights))
	for cell in dungeon.items:
		var sprite: Node3D = dungeon.items[cell].sprite
		sprite.modulate = light_at(sprite.global_position, cell, lights)
	if dungeon.get("traps") != null:
		for cell in dungeon.traps.armed:
			var s: Node3D = dungeon.traps.armed[cell].sprite
			s.modulate = light_at(s.global_position, cell, lights)
	for key in dungeon.levers:
		var lever: Node3D = dungeon.levers[key]
		lever.modulate = light_at(lever.global_position, Vector2i(key.x, key.y), lights)


## The tint for a sprite at `pos` standing on `cell`: the cold floor plus every light that reaches it, each channel at most 1.
func light_at(pos: Vector3, cell: Vector2i, lights: Array) -> Color:
	var c: Color = cfg.ambient_color.lerp(Color.WHITE, 0.5) * cfg.sprite_min_light  # Cold, but not as blue as the ambient itself.
	for l in lights:
		var d := pos.distance_to(l.pos)
		if d >= l.range:
			continue
		if l.cell != cell and not DungeonMap.has_line_of_sight(l.cell, cell):
			continue
		c += l.colour * pow(1.0 - d / l.range, l.att) * cfg.sprite_light_gain
	return Color(minf(c.r, 1.0), minf(c.g, 1.0), minf(c.b, 1.0))


## The tile a world position is on.
static func cell_of(pos: Vector3) -> Vector2i:
	return Vector2i(roundi(pos.x / DungeonMap.TILE_SIZE), roundi(pos.z / DungeonMap.TILE_SIZE))
