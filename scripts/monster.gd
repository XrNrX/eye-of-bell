extends Node3D
## A monster: occupies one tile, blocks movement, shown as a billboard sprite.
## It moves on its own clock (MonsterDef.step_interval; nothing the party does resets it). If the
## player is within sight_range tiles with a clear line of sight it chases them, otherwise it wanders.
## Never diagonal. Next to the party it stops moving and attacks every attack_interval seconds.
## Pacing (all on the MonsterDef): a reaction_delay before it follows a party that stepped out of
## reach, an arrival_recovery after it steps up before its wind-up starts, and flanking only after
## flank_after seconds held back, one monster at a time (data/monster_ai.tres; see "Movement AI").
## All stats and art come from a MonsterDef resource, so new monsters are data.

const Events := preload("res://scripts/game_events.gd")
const DungeonMap := preload("res://scripts/dungeon_map.gd")
const FloatingText := preload("res://scripts/floating_text.gd")
const CombatRules := preload("res://scripts/combat_rules.gd")
const ItemStack := preload("res://scripts/item_stack.gd")
const FeelConfigScript := preload("res://scripts/combat_feel_config.gd")
const AiConfigScript := preload("res://scripts/monster_ai_config.gd")
const MonsterTiers := preload("res://scripts/monster_tiers.gd")

const DAMAGE_COLOUR := Color(0.961, 0.812, 0.502)  # Palette torch_300.
const MISS_COLOUR := Color(0.667, 0.663, 0.706)   # Palette stone_100.

## Per sheet: for each frame, how many transparent rows lie below its lowest opaque pixel. A
## monster stands with that pixel on the floor, so art with empty space under the feet (or a
## puddle that does not reach the frame's bottom) does not float. Computed once per sheet.
static var _foot_gap_cache := {}

const DIRS: Array[Vector2i] = [
	Vector2i(0, -1), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(1, 0),
]

## The monsters allowed to go round to another side of the party right now (at most max_flankers).
static var _passes: Array = []

var feel_cfg: Resource = FeelConfigScript.get_config()  # data/combat_feel.tres
var ai_cfg: Resource = AiConfigScript.get_config()      # data/monster_ai.tres
var def: Resource  # The MonsterDef.
var move_wait := 0.0       # Seconds until its next move, on its own clock.
var recovery_left := 0.0   # Arrival recovery left: its attack can't start until this runs out.
var held_back := 0.0       # Seconds it has been queued behind a monster already at the party (flank_after unlocks a pass).
var blows_struck := 0      # Attacks it has made (read by tests).
var _was_in_reach := false
var _queued := false       # Its last move found it held back (see _chase_dir).
var statuses := {}         # StatusDef.id -> {def, left (seconds), source (hero_index), dot (damage owed), fx (the loop effect node)}
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
var _swinging := false  # The attack animation is playing and the blow lands when attack_cooldown runs out (see _begin_swing).


## Call before adding to the tree.
func setup(monster_def: Resource, start_cell: Vector2i) -> void:
	def = monster_def
	cell = start_cell
	hp = def.max_hp


func _ready() -> void:
	position = DungeonMap.cell_to_world(cell)
	add_to_group("monsters")
	DungeonMap.occupied[cell] = self
	attack_cooldown = def.attack_interval * def.wind_up
	move_wait = randf_range(0.1, def.step_interval)  # Stagger so monsters don't move in step.

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


func _exit_tree() -> void:
	_release_tiles()
	_drop_pass()


func _process(delta: float) -> void:
	if not _status_flag("freezes_animation"):
		_animate(delta)
	if dying:
		return
	_tick_statuses(delta)
	if dying:
		return  # (A damage-over-time tick killed it.)
	# The party slipped out of reach: a beat before it follows. This only ever pushes the next move later.
	var in_reach := _next_to_player()
	if _was_in_reach and not in_reach:
		move_wait = maxf(move_wait, def.reaction_delay)
	held_back = held_back + delta if _queued else 0.0
	if not _status_flag("stops_moving"):  # Held: the move clock pauses.
		move_wait -= delta / _status_scale("move_time_scale")
		if move_wait <= 0.0:
			move_wait = def.step_interval
			_on_tick()
	_was_in_reach = _next_to_player()
	_fight(delta)


## Attack while next to the party. Never while a step is animating or during the arrival recovery after one, so it can't step
## up and strike in the same moment; the wind-up (MonsterDef.wind_up) is held until both are over. A status that stops attacks
## (held) pauses the attack clock where it is and cancels a swing in progress.
func _fight(delta: float) -> void:
	if _status_flag("stops_attacking"):
		if _swinging:
			_swinging = false
			_one_shot = PackedInt32Array()
			attack_cooldown = maxf(attack_cooldown, _hit_delay())  # The swing starts again from the top when it is free.
		return
	var in_reach := _next_to_player()
	if in_reach and not _walking and recovery_left <= 0.0:
		attack_cooldown -= delta / _status_scale("attack_time_scale")
		# The swing starts early enough that its impact frame appears just as the blow lands (see _begin_swing).
		if not _swinging and attack_cooldown <= _hit_delay():
			_begin_swing()
		if attack_cooldown <= 0.0:
			_attack()
		return
	if not in_reach:
		_swinging = false  # The party moved away: no blow comes of it.
		recovery_left = 0.0
	elif not _walking:
		recovery_left -= delta
	attack_cooldown = maxf(attack_cooldown, def.attack_interval * def.wind_up)


# --------------------------------------------------------------------------
# Status effects (StatusDef: data/statuses/*.tres). Every rule is a field of the StatusDef, so a new status is data.
# --------------------------------------------------------------------------

## Try to put a status on, the way every status source does it (a spell, a trap): the tier table (data/tiers.tres) for this
## monster's tier, or its own MonsterDef.status_overrides, decides whether it lands and for how much of `seconds`. Returns
## {"outcome": "landed" / "resisted" / "immune", "seconds": the time it got, "chance": percent, "message": a flavour line or ""}.
## A resisted try plays the status's ending effect at once (the runes form and break). Rolled with the combat dice.
func try_status(status: Resource, seconds: float, source := -1) -> Dictionary:
	var odds: Dictionary = MonsterTiers.get_config().odds(status.id, def)
	var out := {"outcome": "immune", "seconds": 0.0, "chance": odds.chance, "message": odds.message}
	if dying or odds.immune:
		return out
	if odds.chance < 100 and CombatRules.rng().randi_range(1, 100) > odds.chance:
		out.outcome = "resisted"
		var fx := get_tree().get_first_node_in_group("spell_effects")
		if fx != null:
			fx.status_ended(self, status)
		return out
	out.outcome = "landed"
	out.seconds = seconds * odds.duration
	add_status(status, out.seconds, source)
	return out


## Put a status on (or refresh it to `seconds` if it is already on: the longer of the two). source: the hero_index who did it
## (-1: nobody). quiet: no signal and no starting effect (loading a save).
func add_status(status: Resource, seconds: float, source := -1, quiet := false) -> void:
	if dying or status == null or seconds <= 0.0:
		return
	if statuses.has(status.id):
		var entry: Dictionary = statuses[status.id]
		entry.left = maxf(entry.left, seconds)
		entry.source = source
		return
	statuses[status.id] = {"def": status, "left": seconds, "source": source, "dot": 0.0, "fx": null}
	_refresh_tint()
	var fx := get_tree().get_first_node_in_group("spell_effects")
	if fx != null:
		statuses[status.id].fx = fx.status_started(self, status, quiet)
	if not quiet and status.started_event != "":
		Events.send(get_tree(), status.started_event, [self, source])


## Take a status off. by_itself: it ran out (its ended_event is sent and its ending effect plays); false when the monster dies.
func remove_status(id: String, by_itself := true) -> void:
	if not statuses.has(id):
		return
	var entry: Dictionary = statuses[id]
	statuses.erase(id)
	_refresh_tint()
	if entry.fx != null and is_instance_valid(entry.fx):
		entry.fx.queue_free()
	var fx := get_tree().get_first_node_in_group("spell_effects") if is_inside_tree() else null
	if fx != null and by_itself:
		fx.status_ended(self, entry.def)
	if by_itself and entry.def.ended_event != "":
		Events.send(get_tree(), entry.def.ended_event, [self])


func has_status(id: String) -> bool:
	return statuses.has(id)


## Seconds left on a status (0 if it is not on).
func status_left(id: String) -> float:
	return float(statuses[id].left) if statuses.has(id) else 0.0


## Can't defend itself (a held monster): heroes' blows get their helpless_crit (CombatRules.crit_chance).
func is_helpless() -> bool:
	return _status_flag("helpless")


## The icons to draw beside its health bar (enemy_bars.gd).
func status_icons() -> Array:
	var out := []
	for entry in statuses.values():
		if entry.def.icon != null:
			out.append(entry.def.icon)
	return out


func _status_flag(field: String) -> bool:
	for entry in statuses.values():
		if entry.def.get(field):
			return true
	return false


func _status_scale(field: String) -> float:
	var s := 1.0
	for entry in statuses.values():
		s *= maxf(0.05, float(entry.def.get(field)))
	return s


func _tick_statuses(delta: float) -> void:
	for id in statuses.keys():
		var entry: Dictionary = statuses[id]
		if entry.def.damage_per_second > 0.0:
			entry.dot += entry.def.damage_per_second * delta
			var whole := int(entry.dot)
			if whole > 0:
				entry.dot -= whole
				take_hit({"hit": true, "damage": whole, "chance": 100, "crit": false, "by": entry.source, "status": id})
				if dying:
					return
		entry.left -= delta
		if entry.left <= 0.0:
			remove_status(id)


func _refresh_tint() -> void:
	if sprite == null:
		return
	var tint := Color(1, 1, 1)
	for entry in statuses.values():
		tint = entry.def.tint
	sprite.modulate = tint


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


## Seconds from the start of the attack animation to the frame where the blow lands (MonsterDef.attack_hit_frame): the
## swing's anticipation. 0 for a monster with no attack animation.
func _hit_delay() -> float:
	if def.attack_frames.is_empty():
		return 0.0
	var hit: int = def.attack_hit_frame if def.attack_hit_frame >= 0 else def.attack_frames.size() / 2
	return float(clampi(hit, 0, def.attack_frames.size() - 1)) / maxf(def.attack_fps, 0.01)


## Start the attack animation, so that its impact frame is on screen the moment the damage, the red flash and the
## screen shake arrive (_attack): the blow comes `_hit_delay()` seconds after this. The rhythm of attacks is unchanged
## (attack_interval), only the animation leads it; a monster that was late to begin waits for the impact frame.
func _begin_swing() -> void:
	_swinging = true
	attack_cooldown = maxf(attack_cooldown, _hit_delay())
	if not def.attack_frames.is_empty():
		_play(def.attack_frames, def.attack_fps)


## The blow lands: sound, damage and everything that follows (flash, shake, jolt) happen here, together, on the impact frame.
func _attack() -> void:
	attack_cooldown = def.attack_interval
	_swinging = false
	blows_struck += 1
	get_tree().call_group("party", "cue_attack_from", self)
	get_tree().call_group("party", "take_hit_from", self)


## Called by the party with a CombatRules result: show the number, flash, maybe die.
func take_hit(result: Dictionary) -> void:
	if dying:
		return
	get_tree().call_group("fight_tracker", "blow")  # A hit or a miss, by a weapon, a missile or a spell: a fight is on.
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
	for id in statuses.keys():
		remove_status(id, false)  # It dies held: no "released" news and no shatter.
	Events.send(get_tree(), "monster_killed", [def, cell, killer])
	_drop_loot()
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

## One move, on the monster's own clock (_process): hold position next to the party, chase if it's close and visible,
## else wander.
func _on_tick() -> void:
	if dying:
		return
	_queued = false
	if _next_to_player():
		get_tree().call_group("fight_tracker", "noticed", self)  # (Keeps the fight on while it stands at the party's side.)
		if _others_at(_around_party()).is_empty():
			_drop_pass()  # It is simply the one at the party now: another may earn a pass.
		return
	var to_player := DungeonMap.player_cell - cell
	var distance := absi(to_player.x) + absi(to_player.y)
	var dir := Vector2i.ZERO
	if distance <= def.sight_range and DungeonMap.has_line_of_sight(cell, DungeonMap.player_cell):
		get_tree().call_group("fight_tracker", "noticed", self)
		dir = _chase_dir()
	else:
		_drop_pass()
		dir = _wander_dir()
	if dir != Vector2i.ZERO:
		_step(dir)


## The chase. With nobody at the party yet (or holding a flank pass) it heads for the nearest free tile next to the party, the
## one in front of the party when two are as near. Otherwise it queues: as close as it can get behind the monsters already at
## the party, never onto another tile beside the party. After flank_after seconds queued it may take a pass (at most
## max_flankers at once) and go round. Paths are found by a short breadth-first search (path_radius steps).
func _chase_dir() -> Vector2i:
	var around := _around_party()
	var at_party := _others_at(around)
	var may_close: bool = at_party.is_empty() or _has_pass()
	if not may_close and held_back >= def.flank_after:
		may_close = _take_pass()
	if may_close:
		var free := {}
		for c in around:
			if not DungeonMap.is_occupied(c):
				free[c] = true
		var dir := _path_dir(free, {})
		if dir != Vector2i.ZERO:
			return dir
		_drop_pass()  # No way round from here: let another monster try.
		if at_party.is_empty():
			return Vector2i.ZERO  # Nobody is holding it back; the way is simply shut.
	# Queue behind the monsters at the party.
	_queued = true
	var keep_off := {}
	for c in around:
		keep_off[c] = true
	var line := {}
	for m in at_party:
		for d in DIRS:
			var c: Vector2i = m.cell + d
			if not keep_off.has(c) and not DungeonMap.is_blocked(c):
				line[c] = true
	if line.has(cell):
		return Vector2i.ZERO  # In line already.
	return _path_dir(line, keep_off)


## The open tiles next to the party.
func _around_party() -> Array:
	var out := []
	for d in DIRS:
		var c: Vector2i = DungeonMap.player_cell + d
		if not DungeonMap.is_blocked(c):
			out.append(c)
	return out


## The other living monsters standing on (or stepping into) these tiles.
func _others_at(tiles: Array) -> Array:
	var out := []
	for c in tiles:
		var m = DungeonMap.occupied.get(c)
		if m != null and m != self and is_instance_valid(m) and not m.dying and not out.has(m):
			out.append(m)
	return out


## The first step of a shortest path to the nearest tile in `goals` (a set), through tiles it could enter and not through
## `keep_off` (a set). Of goals equally near, the tile in front of the party wins. ZERO if none is within path_radius.
func _path_dir(goals: Dictionary, keep_off: Dictionary) -> Vector2i:
	if goals.is_empty():
		return Vector2i.ZERO
	var front := DungeonMap.player_cell + _party_forward()
	var radius: int = ai_cfg.path_radius
	var dist := {cell: 0}
	var first := {cell: Vector2i.ZERO}
	var frontier: Array[Vector2i] = [cell]
	var best := cell
	var best_d := -1
	var head := 0
	while head < frontier.size():
		var c: Vector2i = frontier[head]
		head += 1
		var dc: int = dist[c]
		if best_d >= 0 and dc > best_d:
			break
		if c != cell and goals.has(c):
			if best_d < 0 or (c == front and best != front):
				best = c
				best_d = dc
			continue
		if dc >= radius:
			continue
		for d in DIRS:
			var n: Vector2i = c + d
			if dist.has(n) or not _can_enter(n) or (keep_off.has(n) and not goals.has(n)):
				continue
			dist[n] = dc + 1
			first[n] = d if c == cell else first[c]
			frontier.append(n)
	return first[best] if best_d >= 0 else Vector2i.ZERO


## The grid direction the party faces (DIRS order, the same as the player's).
func _party_forward() -> Vector2i:
	var player := get_tree().get_first_node_in_group("player") if is_inside_tree() else null
	return DIRS[int(player.facing) % 4] if player != null else Vector2i.ZERO


func _has_pass() -> bool:
	return _passes.has(self)


## Take a flank pass if fewer than max_flankers are out.
func _take_pass() -> bool:
	if _has_pass():
		return true
	_passes = _passes.filter(func(m): return is_instance_valid(m) and not m.dying and m.is_inside_tree())
	if _passes.size() >= int(ai_cfg.max_flankers):
		return false
	_passes.append(self)
	return true


func _drop_pass() -> void:
	_passes.erase(self)


## A random open neighbouring direction, or stand still sometimes.
func _wander_dir() -> Vector2i:
	if randf() < ai_cfg.wander_pause:
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
	tween.tween_property(self, "position", DungeonMap.cell_to_world(cell), ai_cfg.step_seconds)
	tween.tween_callback(func():
		_walking = false
		if _next_to_player():
			recovery_left = def.arrival_recovery  # Just stepped up: a moment before its wind-up can start.
		if DungeonMap.occupied.get(old) == self:
			DungeonMap.occupied.erase(old)
		get_tree().call_group("dungeon", "refresh"))  # Doors re-check who's standing in them.
