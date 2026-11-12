extends Node3D
## A monster: occupies one tile, blocks movement, shown as a billboard sprite.
## Its AI acts on a timer. If the player is within sight_range tiles with a clear
## line of sight it steps towards them, otherwise it wanders. Never diagonal.
## Next to the party it stops moving and attacks every attack_interval seconds.
## All stats and art come from a MonsterDef resource, so new monsters are data.

const Events := preload("res://scripts/game_events.gd")
const DungeonMap := preload("res://scripts/dungeon_map.gd")
const FloatingText := preload("res://scripts/floating_text.gd")
const CombatRules := preload("res://scripts/combat_rules.gd")
const ItemStack := preload("res://scripts/item_stack.gd")
const FeelConfigScript := preload("res://scripts/combat_feel_config.gd")

const AI_TICK := 0.8      # Seconds between actions at speed 1.0.
const STEP_TIME := 0.3    # Seconds a step takes to animate.
const WANDER_PAUSE := 0.3 # Chance a wandering monster just stands still this tick.
const WIND_UP := 0.5      # Fraction of attack_interval it waits after reaching the party.
const DAMAGE_COLOUR := Color(0.961, 0.812, 0.502)  # Palette torch_300.
const MISS_COLOUR := Color(0.667, 0.663, 0.706)   # Palette stone_100.

## Per sheet: for each frame, how many transparent rows lie below its lowest opaque pixel. A
## monster stands with that pixel on the floor, so art with empty space under the feet (or a
## puddle that does not reach the frame's bottom) does not float. Computed once per sheet.
static var _foot_gap_cache := {}

const DIRS: Array[Vector2i] = [
	Vector2i(0, -1), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(1, 0),
]

var feel_cfg: Resource = FeelConfigScript.get_config()  # data/combat_feel.tres
var def: Resource  # The MonsterDef.
var cell: Vector2i
var hp: int
var dying := false
var sprite: Sprite3D
var anim_time := 0.0
var attack_cooldown := 0.0
var _walking := false  # True while a step between tiles is animating (plays def.walk_frames).
var _walk_time := 0.0
var _one_shot := PackedInt32Array()  # Frames of an attack/hurt animation playing now.
var _one_shot_time := 0.0
var _one_shot_fps := 10.0
var _telegraphing := false
var _feel_tween: Tween  # The rear-back / lunge on the sprite (see _telegraph).
var _flash_tween: Tween  # The colour flash that goes with it.


## Call before adding to the tree.
func setup(monster_def: Resource, start_cell: Vector2i) -> void:
	def = monster_def
	cell = start_cell
	hp = def.max_hp


func _ready() -> void:
	position = DungeonMap.cell_to_world(cell)
	add_to_group("monsters")
	DungeonMap.occupied[cell] = self
	attack_cooldown = def.attack_interval * WIND_UP

	sprite = Sprite3D.new()
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sprite.texture = def.sheet
	sprite.hframes = def.hframes
	sprite.pixel_size = def.pixel_size
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y  # Always faces the camera, stays upright.
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	# Stand on the floor: lift by half the frame height (the lowest opaque pixel of each frame is then
	# dropped to the floor in _set_frame).
	sprite.position.y = _sprite_height() / 2.0
	add_child(sprite)

	var timer := Timer.new()
	timer.wait_time = AI_TICK / def.speed
	add_child(timer)
	timer.timeout.connect(_on_tick)
	timer.start(randf_range(0.1, timer.wait_time))  # Stagger so monsters don't act in sync.


func _exit_tree() -> void:
	_release_tiles()


func _process(delta: float) -> void:
	_animate(delta)
	if dying:
		return
	if _next_to_player():
		attack_cooldown -= delta
		# Warn the player a moment before the blow lands (it still lands on schedule).
		if not _telegraphing and attack_cooldown > 0.0 and attack_cooldown <= feel_cfg.telegraph_seconds:
			_telegraph()
		if attack_cooldown <= 0.0:
			_attack()
	else:
		if _telegraphing:
			_end_feel()  # The party moved away: stand down.
		# Arriving next to the party: a short wind-up before the first blow.
		attack_cooldown = maxf(attack_cooldown, def.attack_interval * WIND_UP)


## Show the attack/hurt animation if one is playing, else the walk cycle while stepping (if the
## monster has one), else loop the idle frames.
func _animate(delta: float) -> void:
	anim_time += delta
	if not _one_shot.is_empty():
		_one_shot_time += delta
		var i := int(_one_shot_time * _one_shot_fps)
		if i < _one_shot.size():
			_set_frame(_frame(_one_shot[i]))
			return
		if dying:
			_set_frame(_frame(_one_shot[_one_shot.size() - 1]))  # Hold the last frame while dying.
			return
		_one_shot = PackedInt32Array()
	if _walking and not def.walk_frames.is_empty():
		_walk_time += delta
		_set_frame(_frame(def.walk_frames[int(_walk_time * def.walk_fps) % def.walk_frames.size()]))
		return
	var frames: PackedInt32Array = def.idle_frames
	_set_frame(_frame(frames[int(anim_time * def.idle_fps) % frames.size()]))


## Show a frame, with its lowest opaque pixel on the floor.
func _set_frame(i: int) -> void:
	sprite.frame = i
	var gaps := _foot_gaps()
	sprite.offset.y = -float(gaps[i]) if i < gaps.size() else 0.0


func _foot_gaps() -> PackedInt32Array:
	var key: String = def.sheet.resource_path if def.sheet.resource_path != "" else str(def.sheet.get_instance_id())
	if _foot_gap_cache.has(key):
		return _foot_gap_cache[key]
	var gaps := PackedInt32Array()
	var image: Image = def.sheet.get_image()
	if image != null:
		var fw: int = image.get_width() / maxi(1, def.hframes)
		for f in def.hframes:
			var gap := image.get_height()
			for row in range(image.get_height() - 1, -1, -1):
				var seen := false
				for x in fw:
					if image.get_pixel(f * fw + x, row).a > 0.5:
						seen = true
						break
				if seen:
					gap = image.get_height() - 1 - row
					break
			gaps.append(gap if gap < image.get_height() else 0)
	_foot_gap_cache[key] = gaps
	return gaps


## A frame number from the definition, kept inside the sheet (a definition listing a frame the
## sheet doesn't have shows the nearest one instead of erroring).
func _frame(i: int) -> int:
	return clampi(i, 0, maxi(0, def.hframes - 1))


func _play(frames: PackedInt32Array, fps: float) -> void:
	_one_shot = frames
	_one_shot_time = 0.0
	_one_shot_fps = fps


# --------------------------------------------------------------------------
# Combat
# --------------------------------------------------------------------------

func _next_to_player() -> bool:
	var d := DungeonMap.player_cell - cell
	return absi(d.x) + absi(d.y) == 1


func _attack() -> void:
	attack_cooldown = def.attack_interval
	get_tree().call_group("party", "cue_attack_from", self)
	var was_telegraphing := _telegraphing
	_end_feel()
	if was_telegraphing and feel_cfg.telegraph_lunge:
		_lunge()
	if not def.attack_frames.is_empty():
		_play(def.attack_frames, def.attack_fps)
	get_tree().call_group("party", "take_hit_from", self)


## Where the sprite sits at rest (local to the monster) and the way it faces away from
## the party, for rearing back.
func _rest_position() -> Vector3:
	return Vector3(0.0, _sprite_height() / 2.0, 0.0)


func _away_from_party() -> Vector3:
	var d := cell - DungeonMap.player_cell
	return Vector3(d.x, 0.0, d.y)


## The wind-up: lean away from the party, stretch taller and flash, for the last
## telegraph_seconds before the blow. Purely visual.
func _telegraph() -> void:
	if not feel_cfg.telegraph_enabled:
		return
	_telegraphing = true
	_kill_feel_tween()
	var rear: float = feel_cfg.telegraph_rear_back
	var h := _sprite_height()
	var time := maxf(attack_cooldown, 0.05)
	_feel_tween = create_tween().set_parallel()
	_feel_tween.tween_property(sprite, "scale", Vector3(1.0 - rear * 0.4, 1.0 + rear, 1.0), time * 0.6).set_ease(Tween.EASE_OUT)
	_feel_tween.tween_property(sprite, "position",
			_rest_position() + _away_from_party() * rear * 0.5 + Vector3(0.0, h * rear * 0.5, 0.0), time * 0.6).set_ease(Tween.EASE_OUT)
	# Flash: pulses between the tint and normal.
	var flashes := maxi(1, feel_cfg.telegraph_flashes)
	var flash := create_tween()
	for i in flashes:
		flash.tween_property(sprite, "modulate", feel_cfg.telegraph_flash_colour, time / (flashes * 2.0))
		flash.tween_property(sprite, "modulate", Color.WHITE, time / (flashes * 2.0))
	flash.tween_callback(func(): sprite.modulate = Color.WHITE)
	_flash_tween = flash


## The blow lands: snap towards the party, then settle.
func _lunge() -> void:
	_kill_feel_tween()
	var toward := -_away_from_party() * 0.12
	sprite.scale = Vector3(1.1, 0.92, 1.0)
	sprite.position = _rest_position() + toward
	_feel_tween = create_tween().set_parallel()
	_feel_tween.tween_property(sprite, "scale", Vector3.ONE, 0.18).set_ease(Tween.EASE_OUT)
	_feel_tween.tween_property(sprite, "position", _rest_position(), 0.18).set_ease(Tween.EASE_OUT)


## Stop the telegraph and put the sprite back to normal.
func _end_feel() -> void:
	_telegraphing = false
	_kill_feel_tween()
	sprite.scale = Vector3.ONE
	sprite.position = _rest_position()
	sprite.modulate = Color.WHITE


func _kill_feel_tween() -> void:
	if _feel_tween:
		_feel_tween.kill()
		_feel_tween = null
	if _flash_tween:
		_flash_tween.kill()
		_flash_tween = null


## Called by the party with a CombatRules result: show the number, flash, maybe die.
func take_hit(result: Dictionary) -> void:
	if dying:
		return
	if not result.hit:
		if result.get("fail", false) and feel_cfg.fail_text_enabled:
			_float_text("CRITICAL FAIL!", feel_cfg.fail_colour, 0.4, feel_cfg.fail_text_size)
		else:
			_float_text("Miss", MISS_COLOUR)
		return
	var crit: bool = result.get("crit", false)
	hp -= result.damage
	get_tree().call_group("enemy_bars", "monster_hit", self, result.damage, crit)
	if crit and feel_cfg.crit_text_enabled:
		_float_text(str(result.damage), feel_cfg.crit_colour, 0.0, feel_cfg.crit_number_size, true)
		_float_text("CRITICAL!", feel_cfg.crit_colour, 0.5, feel_cfg.crit_text_size, true)
	else:
		_float_text(str(result.damage), DAMAGE_COLOUR)
	if crit:
		get_tree().call_group("combat_feel", "monster_crit", hp <= 0)
		get_tree().call_group("audio", "play", "crit_hit")
	else:
		get_tree().call_group("combat_feel", "monster_hit", result.damage, hp <= 0)
	get_tree().call_group("audio", "play", "monster_die" if hp <= 0 else "monster_hurt")
	var hold: int = feel_cfg.crit_hurt_hold_frames if crit and feel_cfg.crit_hold_enabled else 0
	if def.hurt_frames.size() == 2:  # [hurt, flash]: alternate the white frame with the hurt frame.
		var hurt: int = def.hurt_frames[0]
		var flash: int = def.hurt_frames[1]
		_play(_held(PackedInt32Array([flash, hurt, flash, hurt]), hold), def.hurt_fps)
	elif not def.hurt_frames.is_empty():  # Any other number of frames: play them as drawn.
		_play(_held(def.hurt_frames, hold), def.hurt_fps)
	if hp <= 0:
		_die(crit and feel_cfg.crit_death_enabled, int(result.get("by", -1)))


## These frames with the last one repeated `extra` more times: a crit holds the hurt frame a moment longer.
func _held(frames: PackedInt32Array, extra: int) -> PackedInt32Array:
	var out := frames.duplicate()
	for i in extra:
		out.append(frames[frames.size() - 1])
	return out


## Free the tile at once (so the player can walk in), then sink into the floor. killer: the hero_index that struck the
## last blow (`by` in the result given to take_hit), or -1.
func _die(big := false, killer := -1) -> void:
	dying = true
	Events.send(get_tree(), "monster_killed", [def, cell, killer])
	_drop_loot()
	_end_feel()  # Back to normal first: the sink below tweens the sprite's scale and height.
	_release_tiles()
	get_tree().call_group("dungeon", "refresh")
	var tween := create_tween()
	if big:  # A crit that kills: it swells a little and hangs there before it goes down.
		tween.tween_property(sprite, "scale", sprite.scale * feel_cfg.crit_death_swell, 0.08).set_ease(Tween.EASE_OUT)
		tween.tween_interval(feel_cfg.crit_death_hold)
	else:
		tween.tween_interval(0.3)  # Let the hurt flash play first.
	tween.tween_property(sprite, "scale:y", 0.0, 0.3).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(sprite, "position:y", 0.0, 0.3).set_ease(Tween.EASE_IN)
	tween.tween_callback(queue_free)


## Maybe leave something on this tile (MonsterDef.drop_item, drop_chance), rolled with the combat dice so tests
## can seed it. The dungeon puts it on the floor (a pile if something is already there).
func _drop_loot() -> void:
	if def.drop_item == null or def.drop_chance <= 0.0 or CombatRules.rng().randf() >= def.drop_chance:
		return
	var dungeon := get_tree().get_first_node_in_group("dungeon")
	if dungeon == null:
		return
	dungeon.place_item(cell, ItemStack.wrap(def.drop_item))
	get_tree().call_group("hud", "show_message", "The %s leaves %s." % [def.display_name.to_lower(), def.drop_item.display_name.to_lower()])


## Remove every tile this monster holds (it can hold two while mid-step).
func _release_tiles() -> void:
	for c in DungeonMap.occupied.keys():
		if DungeonMap.occupied[c] == self:
			DungeonMap.occupied.erase(c)


func _float_text(value: String, colour: Color, above := 0.0, size := 0, linger := false) -> void:
	var label := FloatingText.new()
	label.setup(value, colour, size, linger)
	# Parented to the dungeon, not the monster, so it outlives a monster that dies.
	var sideways := 0.0 if size > 0 else randf_range(-0.25, 0.25)  # Big text stays centred, where it fits the view.
	label.position = position + Vector3(sideways, _sprite_height() * 0.75 + above, 0.0)
	get_parent().add_child(label)


## A point just above the sprite's head, in world space: where its health bar hangs.
func bar_anchor() -> Vector3:
	return global_position + Vector3(0.0, _sprite_height() + 0.08, 0.0)


func _sprite_height() -> float:
	return def.sheet.get_height() * def.pixel_size


# --------------------------------------------------------------------------
# Movement AI
# --------------------------------------------------------------------------

## One AI step: hold position next to the party, chase if it's close and visible,
## else wander.
func _on_tick() -> void:
	if dying or _next_to_player():
		return
	var to_player := DungeonMap.player_cell - cell
	var distance := absi(to_player.x) + absi(to_player.y)
	var dir := Vector2i.ZERO
	if distance <= def.sight_range and DungeonMap.has_line_of_sight(cell, DungeonMap.player_cell):
		dir = _chase_dir(to_player)
	else:
		dir = _wander_dir()
	if dir != Vector2i.ZERO:
		_step(dir)


## Step along the axis with the longer gap first; if that's blocked try the other.
func _chase_dir(to_player: Vector2i) -> Vector2i:
	var along_x := Vector2i(signi(to_player.x), 0)
	var along_y := Vector2i(0, signi(to_player.y))
	var options := [along_x, along_y] if absi(to_player.x) >= absi(to_player.y) else [along_y, along_x]
	for option in options:
		if option != Vector2i.ZERO and _can_enter(cell + option):
			return option
	return Vector2i.ZERO


## A random open neighbouring direction, or stand still sometimes.
func _wander_dir() -> Vector2i:
	if randf() < WANDER_PAUSE:
		return Vector2i.ZERO
	var dirs := DIRS.duplicate()
	dirs.shuffle()
	for dir in dirs:
		if _can_enter(cell + dir):
			return dir
	return Vector2i.ZERO


## Monsters stop at walls and closed doors, and at other monsters and the player.
func _can_enter(target: Vector2i) -> bool:
	return not DungeonMap.is_blocked(target) and not DungeonMap.is_occupied(target) \
			and target != DungeonMap.player_cell


## Claim the new tile at once (so nobody else can step in) and free the old
## tile when the move animation ends.
func _step(dir: Vector2i) -> void:
	var old := cell
	cell += dir
	DungeonMap.occupied[cell] = self
	_walking = true
	_walk_time = 0.0
	var tween := create_tween()
	tween.tween_property(self, "position", DungeonMap.cell_to_world(cell), STEP_TIME)
	tween.tween_callback(func():
		_walking = false
		if DungeonMap.occupied.get(old) == self:
			DungeonMap.occupied.erase(old)
		get_tree().call_group("dungeon", "refresh"))  # Doors re-check who's standing in them.
