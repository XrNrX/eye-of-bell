extends Node3D
## A monster: occupies one tile, blocks movement, shown as a billboard sprite.
## Its AI acts on a timer. If the player is within sight_range tiles with a clear
## line of sight it steps towards them, otherwise it wanders. Never diagonal.
## Next to the party it stops moving and attacks every attack_interval seconds.
## All stats and art come from a MonsterDef resource, so new monsters are data.

const DungeonMap := preload("res://scripts/dungeon_map.gd")
const FloatingText := preload("res://scripts/floating_text.gd")
const FeelConfigScript := preload("res://scripts/combat_feel_config.gd")

const AI_TICK := 0.8      # Seconds between actions at speed 1.0.
const STEP_TIME := 0.3    # Seconds a step takes to animate.
const WANDER_PAUSE := 0.3 # Chance a wandering monster just stands still this tick.
const WIND_UP := 0.5      # Fraction of attack_interval it waits after reaching the party.
const DAMAGE_COLOUR := Color(1.0, 0.89, 0.54)  # Palette torch_300.
const MISS_COLOUR := Color(0.76, 0.74, 0.75)   # Palette stone_100.

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
	DungeonMap.occupied[cell] = self
	attack_cooldown = def.attack_interval * WIND_UP

	sprite = Sprite3D.new()
	sprite.texture = def.sheet
	sprite.hframes = def.hframes
	sprite.pixel_size = def.pixel_size
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y  # Always faces the camera, stays upright.
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	# Stand on the floor: lift by half the frame height.
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


## Show the attack/hurt animation if one is playing, otherwise loop the idle frames.
func _animate(delta: float) -> void:
	anim_time += delta
	if not _one_shot.is_empty():
		_one_shot_time += delta
		var i := int(_one_shot_time * _one_shot_fps)
		if i < _one_shot.size():
			sprite.frame = _one_shot[i]
			return
		if dying:
			sprite.frame = _one_shot[_one_shot.size() - 1]  # Hold the last frame while dying.
			return
		_one_shot = PackedInt32Array()
	var frames: PackedInt32Array = def.idle_frames
	sprite.frame = frames[int(anim_time * def.idle_fps) % frames.size()]


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
	var was_telegraphing := _telegraphing
	_end_feel()
	if was_telegraphing and feel_cfg.telegraph_lunge:
		_lunge()
	if not def.attack_frames.is_empty():
		_play(def.attack_frames, 8.0)
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
		_float_text("Miss", MISS_COLOUR)
		return
	hp -= result.damage
	_float_text(str(result.damage), DAMAGE_COLOUR)
	get_tree().call_group("combat_feel", "monster_hit", result.damage, hp <= 0)
	if def.hurt_frames.size() >= 2:  # Flash: alternate the white frame with the hurt frame.
		var hurt: int = def.hurt_frames[0]
		var flash: int = def.hurt_frames[1]
		_play(PackedInt32Array([flash, hurt, flash, hurt]), 14.0)
	if hp <= 0:
		_die()


## Free the tile at once (so the player can walk in), then sink into the floor.
func _die() -> void:
	dying = true
	_end_feel()  # Back to normal first: the sink below tweens the sprite's scale and height.
	_release_tiles()
	get_tree().call_group("dungeon", "refresh")
	var tween := create_tween()
	tween.tween_interval(0.3)  # Let the hurt flash play first.
	tween.tween_property(sprite, "scale:y", 0.0, 0.3).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(sprite, "position:y", 0.0, 0.3).set_ease(Tween.EASE_IN)
	tween.tween_callback(queue_free)


## Remove every tile this monster holds (it can hold two while mid-step).
func _release_tiles() -> void:
	for c in DungeonMap.occupied.keys():
		if DungeonMap.occupied[c] == self:
			DungeonMap.occupied.erase(c)


func _float_text(value: String, colour: Color) -> void:
	var label := FloatingText.new()
	label.setup(value, colour)
	# Parented to the dungeon, not the monster, so it outlives a monster that dies.
	label.position = position + Vector3(randf_range(-0.25, 0.25), _sprite_height() * 0.75, 0.0)
	get_parent().add_child(label)


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
	var tween := create_tween()
	tween.tween_property(self, "position", DungeonMap.cell_to_world(cell), STEP_TIME)
	tween.tween_callback(func():
		if DungeonMap.occupied.get(old) == self:
			DungeonMap.occupied.erase(old)
		get_tree().call_group("dungeon", "refresh"))  # Doors re-check who's standing in them.
