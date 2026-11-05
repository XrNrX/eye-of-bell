extends Node3D
## Plays the spells' lighting inside the dungeon view (a child of the SubViewport, next to the
## Dungeon). Other scripts never hold a reference; they call it through its group:
##
##     get_tree().call_group("spell_effects", "missile", from_cell, to_cell)   # bolt + impact
##     get_tree().call_group("spell_effects", "party_glow", "heal")           # "heal", "bless", "shield"
##
## Every colour, strength and time is in data/spell_effects.tres (spell_effects_config.gd).
## It also puts the bloom and fog from that file on this viewport's WorldEnvironment at startup.
## Purely visual: Party has already decided what the spell did.

const Config := preload("res://scripts/spell_effects_config.gd")
const DungeonMap := preload("res://scripts/dungeon_map.gd")
const Settings := preload("res://scripts/settings.gd")

const PALETTE_CORE := Color("e6dcc0")   # bone_300
const PALETTE_MID := Color("c3bcc0")    # stone_100
const PALETTE_EDGE := Color("968e9a")   # stone_300

var orb: ImageTexture
var live := 0  # Effects playing right now (tests read this).


func _ready() -> void:
	add_to_group("spell_effects")
	orb = _make_orb()
	var env_node := get_parent().get_node_or_null("WorldEnvironment")
	if env_node:
		Config.apply_environment(env_node.environment, Settings.fog)


## A 7x7 round bolt in three palette greys; the config tints it light blue (and over-brightens it).
func _make_orb() -> ImageTexture:
	var image := Image.create(7, 7, false, Image.FORMAT_RGBA8)
	for y in 7:
		for x in 7:
			var d := Vector2(x - 3, y - 3).length()
			var c := Color(0, 0, 0, 0)
			if d < 1.2:
				c = PALETTE_CORE
			elif d < 2.2:
				c = PALETTE_MID
			elif d < 3.1:
				c = PALETTE_EDGE
			image.set_pixel(x, y, c)
	return ImageTexture.create_from_image(image)


func _cell_pos(cell: Vector2i, height: float) -> Vector3:
	return DungeonMap.cell_to_world(cell) + Vector3(0, height, 0)


## A bolt flies from the party's tile to `to_cell`, lighting the walls as it goes, then bursts.
func missile(from_cell: Vector2i, to_cell: Vector2i) -> void:
	var c := Config.get_config()
	if not c.bolt_enabled:
		return
	live += 1
	var forward := Vector3(to_cell.x - from_cell.x, 0, to_cell.y - from_cell.y).normalized()
	var start := _cell_pos(from_cell, c.bolt_height) + forward * 0.6
	var end := _cell_pos(to_cell, c.bolt_height)
	var bolt := Node3D.new()
	bolt.position = start
	add_child(bolt)
	var sprite := Sprite3D.new()
	sprite.texture = orb
	sprite.pixel_size = c.bolt_size
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.shaded = false
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.modulate = c.bolt_color
	bolt.add_child(sprite)
	var light := OmniLight3D.new()
	light.light_color = c.bolt_light_color
	light.light_energy = c.bolt_light_energy
	light.omni_range = c.bolt_light_range
	bolt.add_child(light)
	if c.bolt_trail_amount > 0:
		var trail := _trail(c)
		bolt.add_child(trail)
		trail.emitting = true
	var tiles := maxf(1.0, (to_cell - from_cell).length())
	var tween := bolt.create_tween()
	tween.tween_property(bolt, "position", end, tiles * c.bolt_seconds_per_tile)
	tween.tween_callback(func():
		impact(to_cell)
		bolt.queue_free()
		live -= 1)


func _trail(c: Resource) -> CPUParticles3D:
	var p := _particles(c.bolt_trail_amount, c.bolt_trail_seconds, 0.03, c.impact_spark_color)
	p.explosiveness = 0.0
	p.one_shot = false
	p.direction = Vector3.ZERO
	p.spread = 180.0
	p.initial_velocity_min = 0.0
	p.initial_velocity_max = 0.25
	p.gravity = Vector3.ZERO
	p.local_coords = false  # The sparks stay where they were dropped.
	return p


## The burst where a bolt lands: a bright flash that dies away fast, and sparks.
func impact(cell: Vector2i) -> void:
	var c := Config.get_config()
	live += 1
	var at := _cell_pos(cell, c.bolt_height)
	var flash := OmniLight3D.new()
	flash.position = at
	flash.light_color = c.impact_flash_color
	flash.light_energy = c.impact_flash_energy
	flash.omni_range = c.impact_flash_range
	add_child(flash)
	var tween := flash.create_tween()
	tween.tween_property(flash, "light_energy", 0.0, c.impact_flash_seconds).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func():
		flash.queue_free())
	if c.impact_sparks > 0:
		var sparks := _particles(c.impact_sparks, c.impact_spark_seconds, c.impact_spark_size, c.impact_spark_color)
		sparks.position = at
		sparks.one_shot = true
		sparks.explosiveness = 1.0
		sparks.direction = Vector3.ZERO
		sparks.spread = 180.0
		sparks.initial_velocity_min = c.impact_spark_speed * 0.4
		sparks.initial_velocity_max = c.impact_spark_speed
		sparks.gravity = Vector3(0, -5.0, 0)
		add_child(sparks)
		sparks.emitting = true
		get_tree().create_timer(c.impact_spark_seconds + 0.2).timeout.connect(func():
			sparks.queue_free())
	get_tree().create_timer(maxf(c.impact_flash_seconds, c.impact_spark_seconds) + 0.25).timeout.connect(func():
		live -= 1)


## A soft glow around the party: a light that swells and fades, and motes drifting up.
func party_glow(kind: String) -> void:
	var c := Config.get_config()
	if not ["heal", "bless", "shield"].has(kind):
		return
	var g: Dictionary = c.glow(kind)
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return
	live += 1
	var forward := Vector3(player.DIRS[player.facing].x, 0, player.DIRS[player.facing].y)
	var centre: Vector3 = DungeonMap.cell_to_world(player.cell) + forward * 0.5
	var light := OmniLight3D.new()
	light.position = centre + Vector3(0, 0.9, 0)
	light.light_color = g.color
	light.light_energy = 0.0
	light.omni_range = g.light_range
	add_child(light)
	var tween := light.create_tween()
	tween.tween_property(light, "light_energy", g.light_energy, g.pulse_seconds * 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(light, "light_energy", 0.0, g.pulse_seconds * 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_callback(func():
		light.queue_free())
	if g.motes > 0:
		var motes := _particles(g.motes, g.mote_seconds, c.mote_size, g.mote_color)
		motes.position = centre + forward * (c.mote_distance - 0.5) + Vector3(0, 0.1, 0)
		motes.one_shot = true
		motes.explosiveness = 0.35
		motes.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		motes.emission_sphere_radius = c.mote_spread
		motes.direction = Vector3.UP
		motes.spread = 12.0
		motes.initial_velocity_min = g.mote_rise * 0.6
		motes.initial_velocity_max = g.mote_rise
		motes.gravity = Vector3.ZERO
		add_child(motes)
		motes.emitting = true
		get_tree().create_timer(g.mote_seconds + 0.3).timeout.connect(func():
			motes.queue_free())
	get_tree().create_timer(g.pulse_seconds + 0.1).timeout.connect(func():
		live -= 1)


## Little unshaded squares that fade out: the common part of sparks, trails and motes.
func _particles(amount: int, seconds: float, size: float, color: Color) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = amount
	p.lifetime = seconds
	p.emitting = false
	var quad := QuadMesh.new()
	quad.size = Vector2(size, size)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.vertex_color_use_as_albedo = true
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	quad.material = material
	p.mesh = quad
	p.color = color  # HDR colour; the ramp below fades its alpha out.
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 1))
	ramp.set_color(1, Color(1, 1, 1, 0))
	p.color_ramp = ramp
	return p
