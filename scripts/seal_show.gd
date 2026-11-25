extends Node3D
## What a purged room looks like (roadmap 7e.2). The rules are the dungeon's (Dungeon.seal_area / unseal_area / raise_reliquary);
## this only shows them, from the run state, so a loaded save looks right too:
## - a curse seal (an eye in a ring of runes) on both faces of every sealed door and portcullis, which rides with the door, and a faint
##   green light; it crumbles when the seal comes off;
## - a green glow in the mortar of a sealed area's walls, which dissolves away when the area is unsealed;
## - a reliquary chest for every raised one: it grinds up out of the floor (rumble, dust, a small shake), opens by itself, and only then
##   do its items show and can they be picked up (`rising`). It stays open on its tile; it blocks nothing.
## `sync(animate)` makes the scene match DungeonMap: with `animate` false (building, loading) things are simply there or gone.
## A child of the dungeon ("SealShow"), made by dungeon_builder.gd. Art: art/seal/ (tools/art/gen_seal.py, PixelLab). Nothing fades
## smoothly. Reduce flashing holds the seal and the glow still and leaves the screen unshaken.

const DungeonMap := preload("res://scripts/dungeon_map.gd")
const Settings := preload("res://scripts/settings.gd")

const DIR := "res://art/seal/"
const DIRS := [Vector2i(0, -1), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(1, 0)]
const SEAL_PIXEL := 2.0 / 256.0     # The door's own pixel density.
const DOOR_THICKNESS := 0.2        # As dungeon_builder.gd's.
const SEAL_DROP := -0.0625          # The seal's centre below the door's.
const CRUMBLE_DROP := 24            # Pixels the crumble frame's centre lies below the seal's (a taller frame, for the falling pieces).
const MORTAR_PIXEL := 2.0 / 128.0   # One frame covers a wall face.
const FADE_STEP := 0.35             # Seconds on each of the mortar's dissolving frames.
const CHEST_PIXEL := 0.0125         # The 96x80 chest is 1.2 x 1.0 world units.
const CHEST_BACK := 0.06            # The chest is drawn this far behind its tile's middle, so the items on it are in front.
const RISE_SECONDS := 1.8
const OPEN_AFTER := 0.35            # The pause between arriving and opening.
const DUST_AT := [0.0, 0.6, 1.2]    # Seconds into the rise when dust bursts at its foot.
const SHAKE_REACH := 6              # Tiles from which the rising stone is felt.
const LIGHT_COLOUR := Color(0.5, 0.72, 0.54)  # curse_500

var door_seals := {}   # Door cell -> [Sprite3D, Sprite3D, OmniLight3D] (children of the door).
var glows := {}        # Area id -> [Sprite3D] on its walls.
var chests := {}       # Cell -> {"sprite": Sprite3D, "t": float, "rising": bool, "dust": int}
var effects := []      # One-shots and dissolves: {"sprite", "t", "fps", "frames", "free"}
var clock := 0.0
var sheets := {}


func _sheet(name: String) -> Dictionary:
	if not sheets.has(name):
		var info = JSON.parse_string(FileAccess.get_file_as_string(DIR + name + "_sheet.json"))
		sheets[name] = {"texture": load(DIR + name + "_sheet.png"), "frames": int(info.frames), "fps": float(info.fps), "height": int(info.frame_h)}
	return sheets[name]


func _sprite(name: String, pixel: float) -> Sprite3D:
	var sheet := _sheet(name)
	var s := Sprite3D.new()
	s.texture = sheet.texture
	s.hframes = sheet.frames
	s.pixel_size = pixel
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	s.shaded = false
	s.double_sided = false
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return s


func sync(animate: bool) -> void:
	var dungeon := get_parent()
	for cell in DungeonMap.sealed_doors:
		if not door_seals.has(cell) and dungeon.doors.has(cell):
			_seal_door(cell, dungeon.doors[cell])
	for cell in door_seals.keys():
		if not DungeonMap.sealed_doors.has(cell):
			if animate:
				_crumble(dungeon.doors[cell])
			for node in door_seals[cell]:
				node.queue_free()
			door_seals.erase(cell)
	for id in DungeonMap.seals:
		if not glows.has(id):
			_light_mortar(id)
	for id in glows.keys():
		if not DungeonMap.seals.has(id):
			for s in glows[id]:
				if animate:  # Swap each for the dissolving frames, which free themselves.
					var fade := _sprite("mortar_fade", MORTAR_PIXEL)
					fade.transform = s.transform
					fade.flip_h = s.flip_h
					add_child(fade)
					effects.append({"sprite": fade, "t": 0.0, "fps": 1.0 / FADE_STEP, "frames": fade.hframes})
				s.queue_free()
			glows.erase(id)
	for cell in DungeonMap.reliquaries:
		if not chests.has(cell):
			_add_chest(cell, animate)
	for cell in chests.keys():
		if not DungeonMap.reliquaries.has(cell):
			chests[cell].sprite.queue_free()
			chests.erase(cell)


## Is a reliquary still coming up on this tile? Its items cannot be touched yet.
func rising(cell: Vector2i) -> bool:
	return chests.has(cell) and chests[cell].rising


func _seal_door(cell: Vector2i, door: MeshInstance3D) -> void:
	var nodes := []
	var depth: float = 0.02 if DungeonMap.is_portcullis(cell) else DOOR_THICKNESS / 2.0 + 0.012
	for face in [1.0, -1.0]:
		var s := _sprite("seal", SEAL_PIXEL)
		s.position = Vector3(0, SEAL_DROP, depth * face)
		s.rotation.y = 0.0 if face > 0.0 else PI
		door.add_child(s)
		nodes.append(s)
	var light := OmniLight3D.new()  # The curse's own faint light: not in "sprite_lights", it shows nothing to fight by.
	light.light_color = LIGHT_COLOUR
	light.light_energy = 0.25
	light.omni_range = 2.4
	door.add_child(light)
	nodes.append(light)
	door_seals[cell] = nodes


func _crumble(door: MeshInstance3D) -> void:
	for face in [1.0, -1.0]:
		var s := _sprite("crumble", SEAL_PIXEL)
		var out: Vector3 = door.basis.z * face * (DOOR_THICKNESS / 2.0 + 0.03)
		s.position = Vector3(door.position.x, DungeonMap.WALL_HEIGHT / 2.0 + SEAL_DROP - CRUMBLE_DROP * SEAL_PIXEL, door.position.z) + out
		s.rotation.y = door.rotation.y + (0.0 if face > 0.0 else PI)
		add_child(s)
		effects.append({"sprite": s, "t": 0.0, "fps": _sheet("crumble").fps, "frames": s.hframes})


func _light_mortar(id: String) -> void:
	var out := []
	for cell in DungeonMap.area_tiles(id):
		for d in DIRS:
			if not DungeonMap.is_wall(cell + d):
				continue
			var s := _sprite("mortar", MORTAR_PIXEL)
			var half: float = DungeonMap.TILE_SIZE / 2.0 - 0.03
			s.position = DungeonMap.cell_to_world(cell) + Vector3(d.x * half, DungeonMap.WALL_HEIGHT / 2.0, d.y * half)
			s.rotation.y = atan2(-float(d.x), -float(d.y))
			s.flip_h = posmod(cell.x * 3 + cell.y + d.x, 2) == 1
			s.set_meta("phase", posmod(cell.x * 5 + cell.y * 3 + d.x + d.y * 2, s.hframes))
			add_child(s)
			out.append(s)
	glows[id] = out


func _add_chest(cell: Vector2i, animate: bool) -> void:
	var s := _sprite("chest", CHEST_PIXEL)
	s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(s)
	chests[cell] = {"sprite": s, "t": 0.0, "rising": animate, "dust": 0}
	s.frame = 0 if animate else 1
	_place_chest(cell, 0.0 if animate else 1.0)
	if animate:
		_show_items(cell, false)
		get_tree().call_group("audio", "play", "rumble")
		var from: Vector2i = (DungeonMap.player_cell - cell).abs()
		if not Settings.reduce_flashing and maxi(from.x, from.y) <= SHAKE_REACH:
			get_tree().call_group("combat_feel", "shake_by", 0.02, RISE_SECONDS)


## Where the chest is drawn: `up` 0 (under the floor) to 1 (standing), in whole art pixels, a little behind the tile's middle.
func _place_chest(cell: Vector2i, up: float) -> void:
	var s: Sprite3D = chests[cell].sprite
	var height: float = _sheet("chest").height * CHEST_PIXEL
	var y := snappedf(height * (up - 0.5), CHEST_PIXEL)
	var at := DungeonMap.cell_to_world(cell)
	var camera := get_viewport().get_camera_3d()
	if camera != null:
		var away := at - camera.global_position
		away.y = 0.0
		if away.length() > 0.1:
			at += away.normalized() * CHEST_BACK
	s.position = at + Vector3(0, y, 0)
	s.visible = DungeonMap.player_cell != cell  # Standing on it, the party looks past it (it would fill the view).


func _show_items(cell: Vector2i, shown: bool) -> void:
	var dungeon := get_parent()
	if dungeon.items.has(cell):
		dungeon.items[cell].sprite.visible = shown


func _dust(cell: Vector2i) -> void:
	var s := _sprite("dust", CHEST_PIXEL * 1.2)
	s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	s.position = DungeonMap.cell_to_world(cell) + Vector3(0, _sheet("dust").height * CHEST_PIXEL * 0.45, 0)
	var lighting := get_parent().get_node_or_null("SpriteLighting")
	if lighting != null:
		var lights := []
		for l in get_tree().get_nodes_in_group("sprite_lights"):
			if l is OmniLight3D and l.is_visible_in_tree():
				lights.append({"pos": l.global_position, "cell": lighting.cell_of(l.global_position), "range": l.omni_range, "att": l.omni_attenuation, "colour": l.light_color * l.light_energy})
		s.modulate = lighting.light_at(s.position, cell, lights)
	add_child(s)
	effects.append({"sprite": s, "t": 0.0, "fps": _sheet("dust").fps, "frames": s.hframes})


func _process(delta: float) -> void:
	if not Settings.reduce_flashing:
		clock += delta
	var seal_frame := int(clock * _sheet("seal").fps) % int(_sheet("seal").frames)
	for cell in door_seals:
		for node in door_seals[cell]:
			if node is Sprite3D:
				node.frame = seal_frame
	for id in glows:
		for s in glows[id]:
			s.frame = (int(clock * _sheet("mortar").fps) + int(s.get_meta("phase"))) % s.hframes
	for cell in chests:
		var c: Dictionary = chests[cell]
		if c.rising:
			c.t += delta
			if c.dust < DUST_AT.size() and c.t >= DUST_AT[c.dust]:
				c.dust += 1
				_dust(cell)
			if c.t >= RISE_SECONDS + OPEN_AFTER:
				c.rising = false
				c.sprite.frame = 1
				_show_items(cell, true)
				get_tree().call_group("audio", "play", "door_open")
			else:
				_show_items(cell, false)  # (Anything dropped there meanwhile waits too.)
		_place_chest(cell, minf(1.0, c.t / RISE_SECONDS) if c.rising else 1.0)
	for i in range(effects.size() - 1, -1, -1):
		var e: Dictionary = effects[i]
		e.t += delta
		var f := int(e.t * e.fps)
		if f >= e.frames:
			e.sprite.queue_free()
			effects.remove_at(i)
		else:
			e.sprite.frame = f
