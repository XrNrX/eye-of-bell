extends Node
## Combat feel: the effects that need a global hand -- hit-pause and screen shake.
## (The monster telegraph lives in monster.gd, the portrait shake in party_hud.gd, the
## miss message in party.gd/hud.gd; they all read the same config.) Self-contained:
## delete this node and those two effects just stop.
##
## Heard through the group "combat_feel":
##   monster_hit(damage, killed)   a hero (or spell) damaged a monster
## and through Party.hero_hit, for blows the party takes.

const FeelConfigScript := preload("res://scripts/combat_feel_config.gd")
const Settings := preload("res://scripts/settings.gd")

var feel_cfg: Resource = FeelConfigScript.get_config()  # data/combat_feel.tres
var camera: Camera3D
var shake_left := 0.0
var shake_total := 0.0
var shake_strength := 0.0
var pause_id := 0


func _ready() -> void:
	add_to_group("combat_feel")
	call_deferred("_find_singletons")  # Siblings may not have run _ready yet.


func _find_singletons() -> void:
	var party := get_tree().get_first_node_in_group("party")
	if party and not party.hero_hit.is_connected(_on_hero_hit):
		party.hero_hit.connect(_on_hero_hit)
	var player := get_tree().get_first_node_in_group("player")
	if player:
		camera = player.get_node_or_null("Camera3D")


func _exit_tree() -> void:
	Engine.time_scale = 1.0  # Never leave the game slowed (e.g. a scene reload mid-pause).


func monster_hit(damage: int, killed: bool) -> void:
	if damage >= feel_cfg.hit_pause_monster_damage or (killed and feel_cfg.hit_pause_on_kill):
		hit_pause()


func _on_hero_hit(_slot: int, damage: int) -> void:
	if damage <= 0:
		return
	if damage >= feel_cfg.hit_pause_party_damage:
		hit_pause()
	shake(damage)


## A hero's crit landed: a short pause and a small shake, more if it killed.
func monster_crit(killed: bool) -> void:
	if feel_cfg.crit_pause_enabled:
		hit_pause(feel_cfg.crit_kill_pause_seconds if killed else feel_cfg.crit_pause_seconds)
	if feel_cfg.crit_shake_enabled:
		if killed:
			shake_by(feel_cfg.crit_kill_shake_strength, feel_cfg.crit_kill_shake_seconds)
		else:
			shake_by(feel_cfg.crit_shake_strength, feel_cfg.crit_shake_seconds)


## Freeze the game for a moment. A timer that ignores time scale brings it back; a
## newer pause supersedes an older one instead of stacking. seconds < 0: the usual length.
func hit_pause(seconds := -1.0) -> void:
	if not feel_cfg.hit_pause_enabled or get_tree().paused:
		return
	pause_id += 1
	var id := pause_id
	Engine.time_scale = feel_cfg.hit_pause_time_scale
	# process_always, not in physics, ignore_time_scale.
	var length: float = seconds if seconds >= 0.0 else feel_cfg.hit_pause_seconds
	await get_tree().create_timer(length, true, false, true).timeout
	if id == pause_id:
		Engine.time_scale = 1.0


## Shake the 3D view for a hit of this size.
func shake(damage: int) -> void:
	if not feel_cfg.screen_shake_enabled or Settings.reduce_flashing or damage < feel_cfg.screen_shake_min_damage:
		return
	var full := maxf(1.0, float(feel_cfg.screen_shake_full_damage))
	var fresh: float = feel_cfg.screen_shake_strength * clampf(damage / full, 0.3, 1.0)
	var running := shake_strength * (shake_left / maxf(shake_total, 0.001))  # What's left of a shake in progress.
	shake_strength = maxf(running, fresh)
	shake_total = feel_cfg.screen_shake_seconds
	shake_left = shake_total


## Shake the 3D view by a given strength (camera offset in world units) for `seconds`; used by
## spells (the Fireball blast). Respects the same on/off switch as the hit shake, and Reduce flashing stops all of it.
func shake_by(strength: float, seconds: float) -> void:
	if not feel_cfg.screen_shake_enabled or Settings.reduce_flashing or strength <= 0.0:
		return
	var running := shake_strength * (shake_left / maxf(shake_total, 0.001))
	shake_strength = maxf(running, strength)
	shake_total = seconds
	shake_left = seconds


func _process(delta: float) -> void:
	if camera == null:
		return
	if shake_left <= 0.0:
		if camera.h_offset != 0.0 or camera.v_offset != 0.0:
			camera.h_offset = 0.0
			camera.v_offset = 0.0
		return
	# Real time, so a hit-pause doesn't stretch the shake out.
	shake_left = maxf(0.0, shake_left - delta / maxf(Engine.time_scale, 0.001))
	var falloff := shake_left / maxf(shake_total, 0.001)  # Strong at first, then settling.
	var s := shake_strength * falloff
	camera.h_offset = randf_range(-1.0, 1.0) * s
	camera.v_offset = randf_range(-1.0, 1.0) * s * 0.7
