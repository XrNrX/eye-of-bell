extends SceneTree
## Smoke test of floor 1: the things every refactor must keep working (docs/code_review.md, step 0).
## Run: timeout 120 "$G" --headless --path . -s tests/smoke_test.gd      (exit code = number of failed checks)
##
## Combat, the five spells, food, resurrection, a save and load round trip, and the GameEvents signals (each fires once
## when its thing happens, and not at all while a save is loaded). The combat dice are seeded. It uses its
## own settings and save files, so a real save is never touched. It changes run state directly (hp, mana, cooldowns,
## where monsters stand) to set each check up; it never changes game code or data.

const DungeonMap := preload("res://scripts/dungeon_map.gd")
const SpellEffectsConfig := preload("res://scripts/spell_effects_config.gd")
const CombatRules := preload("res://scripts/combat_rules.gd")
const Settings := preload("res://scripts/settings.gd")
const SaveGame := preload("res://scripts/save_game.gd")
const ItemStack := preload("res://scripts/item_stack.gd")

const SAVE_PATH := "user://smoke_test_save.json"
const SPOT := Vector2i(6, 13)   # West end of the long corridor; facing east (3) there are six open tiles ahead.
const EAST := 3
const AHEAD_1 := Vector2i(7, 13)
const AHEAD_2 := Vector2i(8, 13)
const CLOSETS: Array[Vector2i] = [Vector2i(18, 1), Vector2i(20, 1)]  # One-tile rooms behind shut doors: a monster there cannot move.
const PLAIN_DOOR := Vector2i(16, 6)
const LEVER := Vector3i(19, 7, 0)  # The north lever of gate_n: cell (19,7), side 0.

const EVENTS := ["monster_killed", "monster_held", "monster_released", "trap_triggered", "hero_hurt", "mana_low", "hero_died", "hero_revived", "item_picked_up", "door_unlocked", "lever_pulled", "wall_broken",
		"wall_purified", "puzzle_solved", "level_completed"]
const CRACKED_WALL := Vector2i(2, 6)
const THICK_CORRUPTION := Vector2i(16, 4)  # Purifying it fires the puzzle "nook_blessing".
const SWORD_TILE := Vector2i(6, 10)        # The short sword in front of the start.

var fails := 0
var events := {}  # GameEvents signal name -> the argument lists it was sent with, in order.
var fight_log := []  # "started" / "ended", in order (GameEvents.fight_started and fight_ended).
var party: Node
var player: Node
var dungeon: Node


func check(name: String, ok: bool) -> void:
	print(("PASS " if ok else "FAIL ") + name)
	if not ok:
		fails += 1


func _init() -> void:
	Settings.path = "user://smoke_test_settings.cfg"
	Settings.loaded = true
	SaveGame.path = SAVE_PATH
	DungeonMap.use_level("")
	CombatRules.seed_rng(12345)
	DungeonMap.set_flag("smoke.left_over", true)
	DungeonMap.use_level("")  # Starting a level starts a run: it clears the run flags.
	check("starting a run clears the run flags", DungeonMap.flags.is_empty())
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene  # So loading can reload it, as in the real game.
	await create_timer(0.8).timeout
	_find_nodes()
	if party == null or player == null or dungeon == null:
		check("the game scene has a party, a player and a dungeon", false)
		_finish()
		return
	check("floor 1 is built with its four heroes", party.members.size() == 4 and get_nodes_in_group("monsters").size() == DungeonMap.MONSTERS.size())
	check("the GameEvents autoload is there", _listen())

	dungeon.clear_monsters()
	player.restore(SPOT, EAST)
	_check_kill()
	_check_monster_hit()
	await _check_attack_timing()
	await _check_pacing()
	_check_hero_death()
	_check_spells()
	_check_hold()
	await _check_trap()
	await _check_food()
	_check_resurrection()
	await _check_world_events()
	await _check_save_load()
	_check_stairs()
	await _check_hurt_and_heal()
	await _check_fight()
	_check_names()
	_finish()


func _finish() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	print("DONE fails=", fails)
	quit(fails)


## Record every GameEvents signal. False if the autoload is missing.
func _listen() -> bool:
	var bus := root.get_node_or_null("GameEvents")
	if bus == null:
		return false
	bus.fight_started.connect(func(): fight_log.append("started"))
	bus.fight_ended.connect(func(): fight_log.append("ended"))
	for event in EVENTS:
		events[event] = []
		if not bus.has_signal(event):
			return false
		bus.connect(event, func(a = null, b = null, c = null): events[event].append([a, b, c]))
	return true


## True if the signal has been sent exactly once so far, with these arguments (fewer than three are padded with null).
func _sent_once(event: String, args: Array) -> bool:
	var padded := args.duplicate()
	while padded.size() < 3:
		padded.append(null)
	return events.get(event, []).size() == 1 and events[event][0] == padded


func _event_counts() -> Dictionary:
	var counts := {}
	for event in EVENTS:
		counts[event] = events.get(event, []).size()
	return counts


func _find_nodes() -> void:
	party = get_first_node_in_group("party")
	player = get_first_node_in_group("player")
	dungeon = get_first_node_in_group("dungeon")


func _monster(file: String, cell: Vector2i, hp := -1) -> Node:
	return dungeon.spawn_monster(load("res://data/monsters/%s.tres" % file), cell, hp)


func _rest_everyone() -> void:
	for m in party.members:
		m.hp = m.def.max_hp
		m.mana = float(m.def.max_mana)
		m.cooldown_left = 0.0
		m.buffs.clear()
		m.food_left = 0.0
		m.sick_left = 0.0
		m.shaken_left = 0.0
		party.hp_changed.emit(m.slot)


func _total_hp() -> int:
	var total := 0
	for m in party.members:
		total += m.hp
	return total


# --------------------------------------------------------------------------
# Combat
# --------------------------------------------------------------------------

func _check_kill() -> void:
	_rest_everyone()
	var slime: Node = _monster("slime", AHEAD_1)
	var swings := 0
	while not slime.dying and swings < 200:
		party.members[0].cooldown_left = 0.0
		party.act(0, 0)  # The front-left hero swings with whatever is in their first hand.
		swings += 1
	check("a hero kills the monster in front (%d swings)" % swings, slime.dying and slime.hp <= 0)
	check("the dead monster's tile is free", not DungeonMap.is_occupied(AHEAD_1))
	check("event: monster_killed once, naming the monster, its tile and the hero",
			_sent_once("monster_killed", [load("res://data/monsters/slime.tres"), AHEAD_1, party.members[0].hero_index]))
	dungeon.clear_monsters()


func _check_monster_hit() -> void:
	_rest_everyone()
	var skeleton: Node = _monster("skeleton", AHEAD_1)
	var before := _total_hp()
	var blows := 0
	while _total_hp() == before and blows < 60:
		party.take_hit_from(skeleton)
		blows += 1
	check("a monster's hit lowers a hero's HP (%d blows)" % blows, _total_hp() < before)
	var hurt_events: Array = events.hero_hurt
	check("event: hero_hurt once, with the HP lost and the source", hurt_events.size() == 1 and hurt_events[0][1] == before - _total_hp()
			and hurt_events[0][2] == "monster" and party.members.any(func(m): return m.hero_index == hurt_events[0][0] and m.hp < m.def.max_hp))
	var front_only := true  # A monster in front reaches the front row (positions 0 and 1) only.
	for m in party.members:
		if m.slot >= 2 and m.hp < m.def.max_hp:
			front_only = false
	check("a monster in front hurts the front row only", front_only)
	dungeon.clear_monsters()


## A monster's blow lands on the impact frame of its swing: the damage (and with it the red flash, the shake and the sound) arrives
## as that frame appears, and the monster does not rear back or stretch first (MonsterDef.attack_hit_frame, monster._begin_swing).
func _check_attack_timing() -> void:
	for file in ["skeleton", "skeleton_guard", "slime", "slime_acid"]:
		_rest_everyone()
		dungeon.clear_monsters()
		player.restore(SPOT, EAST)
		var monster: Node = _monster(file, AHEAD_1)
		var def: Resource = monster.def
		var impact: int = def.attack_frames[def.attack_hit_frame]
		var seen := {"start": -1.0, "hit": -1.0, "frame": -1, "drift": 0.0}
		var started := Time.get_ticks_msec()
		var on_hit := func(_slot, _damage):
			if seen.hit < 0.0:
				seen.hit = (Time.get_ticks_msec() - started) / 1000.0
				seen.frame = monster.sprite.frame
		party.hero_hit.connect(on_hit)
		while seen.hit < 0.0 and (Time.get_ticks_msec() - started) < 6000:
			await process_frame
			var now := (Time.get_ticks_msec() - started) / 1000.0
			if monster._swinging and seen.start < 0.0:
				seen.start = now
			seen.drift = maxf(seen.drift, maxf((monster.sprite.scale - Vector3.ONE).length(), absf(monster.sprite.position.y - monster._sprite_height() / 2.0)))
		party.hero_hit.disconnect(on_hit)
		var wait: float = seen.hit - seen.start
		var expected: float = def.attack_hit_frame / def.attack_fps
		check("%s: the blow lands (the swing began %.2f s earlier, the impact frame is %.2f s in)" % [file, wait, expected],
				seen.hit >= 0.0 and seen.start >= 0.0 and absf(wait - expected) < 0.12)
		check("%s: the impact frame is on screen as it lands (frame %d, wanted %d)" % [file, seen.frame, impact], absi(seen.frame - impact) <= 1)
		check("%s: no pull-back or stretch before the blow" % file, seen.drift < 0.001)
	dungeon.clear_monsters()
	_rest_everyone()


## Monster pacing (MonsterDef step_interval, reaction_delay, arrival_recovery, wind_up): a monster that steps up to the party
## can't strike in the same moment, waits out its arrival recovery, and a party step away never makes it move sooner.
func _check_pacing() -> void:
	_rest_everyone()
	dungeon.clear_monsters()
	player.restore(SPOT, EAST)
	var monster: Node = _monster("skeleton", AHEAD_2)
	var def: Resource = monster.def
	await process_frame
	monster.move_wait = 0.0
	monster._process(0.0)  # Its move comes up: it steps next to the party...
	monster._process(10.0)  # ...and even a huge frame in the same moment brings no blow.
	check("pacing: a monster steps up to the party on its own clock", monster.cell == AHEAD_1)
	check("pacing: a monster can't step and attack in the same tick", monster.blows_struck == 0 and not monster._swinging
			and monster.attack_cooldown >= def.attack_interval * def.wind_up - 0.001)
	await create_timer(def.arrival_recovery * 0.5 + 0.35).timeout  # (0.35: the step animation is 0.3 s.)
	check("pacing: after the step it waits out its arrival recovery before the wind-up (%.2f s left)" % monster.recovery_left,
			monster.recovery_left > 0.0 and monster.blows_struck == 0 and not monster._swinging
			and monster.attack_cooldown >= def.attack_interval * def.wind_up - 0.001)
	# The party steps back: a short beat before it follows, and never sooner than its own clock.
	monster.move_wait = 0.05
	player.restore(SPOT + Vector2i(0, -1), EAST)  # (6,12): north, out of its reach.
	monster._process(0.0)
	check("pacing: when the party steps out of reach it waits its reaction delay", monster.move_wait >= def.reaction_delay - 0.001)
	player.restore(SPOT, EAST)
	monster._process(0.0)
	monster.move_wait = def.step_interval
	player.restore(SPOT + Vector2i(0, -1), EAST)  # (6,12): north, out of its reach.
	monster._process(0.0)
	check("pacing: a party move never brings its next move forward", monster.move_wait >= def.step_interval - 0.001)
	check("pacing: normal monsters are much slower than the party (step %.1f s)" % def.step_interval, def.step_interval >= 1.0)
	dungeon.clear_monsters()
	player.restore(SPOT, EAST)
	_rest_everyone()


func _check_hero_death() -> void:
	_rest_everyone()
	party.members[0].hp = 1
	party.members[1].hp = 1
	var skeleton: Node = _monster("skeleton", AHEAD_1)
	var blows := 0
	while party.members[0].is_alive() and party.members[1].is_alive() and blows < 80:
		party.take_hit_from(skeleton)
		blows += 1
	var dead: Array = party.members.filter(func(m): return not m.is_alive())
	check("a monster can kill a hero (%d blows)" % blows, dead.size() == 1)
	check("event: hero_died once, naming the hero", dead.size() == 1 and _sent_once("hero_died", [dead[0].hero_index]))
	dungeon.clear_monsters()
	_rest_everyone()


# --------------------------------------------------------------------------
# Spells
# --------------------------------------------------------------------------

## Where a hero holds a focus that lists this spell: [position, hand], or [] if nobody can cast it.
func _caster_of(spell: Resource) -> Array:
	for slot in party.members.size():
		for hand in 2:
			if spell in party.spells_in(slot, hand):
				return [slot, hand]
	return []


## Cast with full mana and no cooldown. Returns {"cast": bool, "spent": mana spent, "cost": the spell's cost}.
func _cast(file: String, target_slot := -1) -> Dictionary:
	var spell: Resource = load("res://data/spells/%s.tres" % file)
	var who := _caster_of(spell)
	if who.is_empty():
		return {"cast": false, "spent": 0.0, "cost": spell.mana_cost, "spell": spell, "slot": -1}
	var m = party.members[who[0]]
	m.mana = float(m.def.max_mana)
	m.cooldown_left = 0.0
	var before: float = m.mana
	var ok: bool = party.cast(who[0], who[1], spell, target_slot)
	return {"cast": ok, "spent": before - m.mana, "cost": spell.mana_cost, "spell": spell, "slot": who[0]}


func _spent_right(r: Dictionary) -> bool:
	return r.cast and is_equal_approx(r.spent, float(r.cost))


func _check_spells() -> void:
	_rest_everyone()
	# Magic Missile: the first monster in the line ahead, never missing.
	var target: Node = _monster("skeleton", AHEAD_2, 99)
	var r := _cast("magic_missile")
	check("Magic Missile hurts the monster ahead", r.cast and target.hp < 99)
	check("Magic Missile spends its mana", _spent_right(r))
	dungeon.clear_monsters()

	# Fireball: the target, and half the roll to a monster beside it.
	target = _monster("skeleton", AHEAD_2, 99)
	var beside: Node = _monster("skeleton", AHEAD_2 + Vector2i(1, 0), 99)
	r = _cast("fireball")
	check("Fireball hurts the monster ahead", r.cast and target.hp < 99)
	check("Fireball's blast catches the monster beside it", beside.hp < 99)
	check("Fireball spends its mana", _spent_right(r))
	dungeon.clear_monsters()

	# Heal: one hero.
	_rest_everyone()
	var hurt = party.members[0]
	hurt.hp = hurt.def.max_hp - 12
	r = _cast("heal", 0)
	check("Heal restores HP", r.cast and hurt.hp > hurt.def.max_hp - 12 and hurt.hp <= hurt.def.max_hp)
	check("Heal spends its mana", _spent_right(r))
	hurt.hp = hurt.def.max_hp
	var full := _cast("heal", 0)
	check("Heal on a healthy hero costs nothing", not full.cast and is_zero_approx(full.spent))

	# Bless: everyone alive.
	_rest_everyone()
	r = _cast("bless")
	var all_blessed := true
	for m in party.members:
		all_blessed = all_blessed and m.buffs.any(func(b): return b.spell == r.spell)
	check("Bless is on every living hero", r.cast and all_blessed)
	check("Bless spends its mana", _spent_right(r))

	# Shield: one hero's defence.
	_rest_everyone()
	var guarded = party.members[0]
	var plain: int = party.effective_stats(guarded).defence
	r = _cast("shield", 0)
	check("Shield raises the target's defence", r.cast and party.effective_stats(guarded).defence > plain)
	check("Shield spends its mana", _spent_right(r))
	_rest_everyone()

	# A cast the hero cannot afford costs nothing and says mana_low.
	var who := _caster_of(load("res://data/spells/magic_missile.tres"))
	var caster = party.members[who[0]]
	caster.mana = 0.0
	caster.cooldown_left = 0.0
	var low_before: int = events.mana_low.size()
	var cast_ok: bool = party.cast(who[0], who[1], load("res://data/spells/magic_missile.tres"))
	check("a cast with no mana fails and costs nothing", not cast_ok and is_zero_approx(caster.mana) and is_zero_approx(caster.cooldown_left))
	check("event: mana_low once, naming the hero", events.mana_low.size() == low_before + 1 and events.mana_low[-1][0] == caster.hero_index)
	_rest_everyone()


# --------------------------------------------------------------------------
# Food and resurrection
# --------------------------------------------------------------------------

## Hold Monster and the "held" status: who can be held (the tier table, a slime's shorter hold, wall monsters, tier 4 for half the time),
## what holding does (no moving or attacking, paused clocks, a frozen frame, still hittable, crit bonus), the recast wait, the
## signals, and running out by itself.
func _check_hold() -> void:
	_rest_everyone()
	dungeon.clear_monsters()
	player.restore(SPOT, EAST)
	var spell: Resource = load("res://data/spells/hold_monster.tres")
	var who := _caster_of(spell)
	check("hold: Hold Monster is in the mage's spellbook", not who.is_empty())
	if who.is_empty():
		return
	var mage = party.members[who[0]]
	var r := _cast("hold_monster")
	check("hold: with nothing in front it costs nothing", not r.cast and is_zero_approx(r.spent))
	var tiers: Resource = load("res://data/tiers.tres")
	check("hold: the tier table's held row (90/65/35/15%, full, full, half, half)", tiers.rows.held.chance == [90, 65, 35, 15]
			and tiers.rows.held.duration == [1.0, 1.0, 0.5, 0.5])
	var tier_ok := true
	for file in ["skeleton", "slime", "slime_acid"]:
		tier_ok = tier_ok and load("res://data/monsters/%s.tres" % file).tier == 1
	check("hold: skeletons and slimes are tier 1, the guard tier 2", tier_ok and load("res://data/monsters/skeleton_guard.tres").tier == 2)
	var slime: Node = _monster("slime", AHEAD_1)
	var slime_casts := 0
	while not slime.has_status("held") and slime_casts < 20:
		mage.spell_wait.clear()
		r = _cast("hold_monster")
		slime_casts += 1
	var hud: Node = get_first_node_in_group("hud")
	check("hold: a slime can be held, for less time, and quivers (%.2f s)" % slime.status_left("held"), slime.has_status("held")
			and absf(slime.status_left("held") - spell.status_seconds * 0.75) < 0.01
			and hud.lines.any(func(l): return str(l.text).contains("The slime quivers against the runes.")))
	dungeon.clear_monsters()
	var skel: Node = _monster("skeleton", AHEAD_1)
	var held_before: int = events.monster_held.size()
	var released_before: int = events.monster_released.size()
	var casts := 0
	var resisted := 0
	while not skel.has_status("held") and casts < 40:
		mage.spell_wait.clear()
		r = _cast("hold_monster")
		casts += 1
		if r.cast and not skel.has_status("held"):
			resisted += 1
	check("hold: it holds a skeleton (%d casts, %d resisted; every cast spent its mana)" % [casts, resisted], skel.has_status("held") and _spent_right(r)
			and absf(skel.status_left("held") - spell.status_seconds) < 0.01)
	var guard_odds: Dictionary = tiers.odds("held", load("res://data/monsters/skeleton_guard.tres"))
	var skel_odds: Dictionary = tiers.odds("held", skel.def)
	var slime_odds: Dictionary = tiers.odds("held", load("res://data/monsters/slime.tres"))
	check("hold: the odds come from the tier, with the slime's own override on top", skel_odds.chance == 90 and is_equal_approx(skel_odds.duration, 1.0)
			and guard_odds.chance == 65 and slime_odds.chance == 90 and is_equal_approx(slime_odds.duration, 0.75) and not slime_odds.immune
			and tiers.odds("no such status", skel.def).chance == 100)
	check("hold: its recast wait has started", party.spell_wait_left(who[0], spell) > 0.0)
	mage.cooldown_left = 0.0
	mage.mana = float(mage.def.max_mana)
	check("hold: it can't be cast again until the wait is over", not party.cast(who[0], who[1], spell) and is_equal_approx(mage.mana, float(mage.def.max_mana)))
	check("hold: event monster_held once, naming the monster and the mage", events.monster_held.size() == held_before + 1
			and events.monster_held[-1][0] == skel and events.monster_held[-1][1] == mage.hero_index)
	var cooldown: float = skel.attack_cooldown
	var wait: float = skel.move_wait
	var blows: int = skel.blows_struck
	var frame: int = skel.sprite.frame
	skel._process(1.0)
	skel._process(1.0)
	check("hold: a held monster doesn't move or attack, its clocks pause and its frame freezes", skel.blows_struck == blows and skel.cell == AHEAD_1
			and is_equal_approx(skel.attack_cooldown, cooldown) and is_equal_approx(skel.move_wait, wait) and skel.sprite.frame == frame)
	var thief: Resource = load("res://data/party/thief.tres")
	var fighter: Resource = load("res://data/party/fighter.tres")
	var dagger: Resource = load("res://data/items/dagger.tres")
	var thief_gain: int = CombatRules.crit_chance(thief, dagger, 0, true) - CombatRules.crit_chance(thief, dagger)
	var fighter_gain: int = CombatRules.crit_chance(fighter, null, 0, true) - CombatRules.crit_chance(fighter)
	check("hold: blows on a held monster crit more often, the thief's most (+%d, fighter +%d)" % [thief_gain, fighter_gain],
			skel.is_helpless() and thief_gain > fighter_gain and fighter_gain > 0)
	var hp_before: int = skel.hp
	for i in 30:
		party.members[0].cooldown_left = 0.0
		party.act(0, 0)
		if skel.hp < hp_before or skel.dying:
			break
	check("hold: a held monster can still be hit", skel.hp < hp_before or skel.dying)
	if not skel.dying:
		skel._process(10.0)
		check("hold: it runs out by itself", not skel.has_status("held") and not skel.is_helpless())
		check("hold: event monster_released once", events.monster_released.size() == released_before + 1 and events.monster_released[-1][0] == skel)
	dungeon.clear_monsters()
	var boss_def: Resource = load("res://data/monsters/skeleton.tres").duplicate()
	boss_def.tier = 4
	var boss: Node = dungeon.spawn_monster(boss_def, AHEAD_1)
	var boss_casts := 0
	while not boss.has_status("held") and boss_casts < 60:
		mage.spell_wait.clear()
		r = _cast("hold_monster")
		boss_casts += 1
	check("hold: a tier 4 monster is held for half the time (%.1f s after %d casts)" % [boss.status_left("held"), boss_casts],
			boss.has_status("held") and absf(boss.status_left("held") - spell.status_seconds * 0.5) < 0.01)
	dungeon.clear_monsters()
	var stubborn_def: Resource = load("res://data/monsters/skeleton.tres").duplicate()
	stubborn_def.status_overrides = {"held": {"chance": 1}}  # A per-monster override beats the tier table.
	var stubborn: Node = dungeon.spawn_monster(stubborn_def, AHEAD_1)
	var shrugs := 0
	for i in 5:
		mage.spell_wait.clear()
		r = _cast("hold_monster")
		if r.cast and not stubborn.has_status("held") and _spent_right(r) and str(get_first_node_in_group("hud").last_message).ends_with("The skeleton shrugs off the spell."):
			shrugs += 1
	check("hold: a resisted cast still costs its mana and says so (%d of 5)" % shrugs, shrugs >= 4)
	dungeon.clear_monsters()
	var wall_def: Resource = boss_def.duplicate()
	wall_def.tier = 1
	wall_def.wall_monster = true
	var wall: Node = dungeon.spawn_monster(wall_def, AHEAD_1)
	mage.spell_wait.clear()
	r = _cast("hold_monster")
	check("hold: a wall monster can't be held", not r.cast and not wall.has_status("held"))
	dungeon.clear_monsters()
	mage.spell_wait.clear()
	_rest_everyone()


## The rusty bear trap: setting it (only on a free tile; the Thief in half the time), stepping over it, disarming it by a click, a
## monster snapped (damage, held through the tier table's trap row, the trap closed on the tile, trap_triggered), the spring snapping,
## and the slime oozing through.
func _check_trap() -> void:
	_rest_everyone()
	dungeon.clear_monsters()
	player.restore(SPOT, EAST)
	var trap_def: Resource = load("res://data/items/bear_trap.tres")
	var traps: Node = get_first_node_in_group("traps")
	var hud: Node = get_first_node_in_group("hud")
	var cursor: Node = get_first_node_in_group("cursor")
	check("trap: the dungeon has a trap field", traps != null)
	if traps == null:
		return
	var thief = party.members.filter(func(m): return m.class_id() == "thief")[0]
	thief.quick[0] = ItemStack.of(trap_def, 2)
	var blocker: Node = _monster("skeleton", AHEAD_1)
	thief.cooldown_left = 0.0
	var r: Dictionary = party.use_quick(thief.slot, 0)
	check("trap: it can't be set on a monster, and nothing is spent", not r.used and thief.quick[0].count == 2)
	dungeon.clear_monsters()
	thief.cooldown_left = 0.0
	r = party.use_quick(thief.slot, 0)
	check("trap: setting it takes one from the stack and the thief half the time (%.2f s)" % thief.cooldown_left,
			r.used and thief.quick[0].count == 1 and is_equal_approx(thief.cooldown_left, trap_def.set_seconds * 0.5)
			and traps.armed_at(AHEAD_1) == null)
	traps._process(1.0)
	check("trap: once the time is up it lies armed in front", traps.armed_at(AHEAD_1) == trap_def)
	thief.cooldown_left = 0.0
	r = party.use_quick(thief.slot, 0)
	check("trap: not on a tile that already has one", not r.used and thief.quick[0].count == 1)
	thief.quick[0] = null
	player._try_move(Vector2i(1, 0))
	check("trap: the party steps over its own trap safely", traps.armed_at(AHEAD_1) == trap_def and str(hud.last_message).ends_with("steps carefully over the trap."))
	await create_timer(0.3).timeout
	player.restore(SPOT, EAST)
	player.world_click()
	check("trap: clicking it picks it back up, disarmed", traps.armed_at(AHEAD_1) == null and cursor.is_holding() and cursor.held.def == trap_def)
	cursor.release()
	var saved_break: float = trap_def.break_chance
	trap_def.break_chance = 0.0
	traps.arm(AHEAD_1, trap_def, thief.hero_index)
	var triggered_before: int = events.trap_triggered.size()
	var skel: Node = _monster("skeleton", AHEAD_2, 50)
	skel.move_wait = 999.0
	skel._step(Vector2i(-1, 0))
	await create_timer(0.45).timeout
	var resisted: bool = hud.lines.any(func(l): return str(l.text).contains("tears free"))
	check("trap: a monster stepping on it is snapped: hurt and held for %.1f s (or tears free)" % skel.status_left("held"),
			skel.hp < 50 and (resisted or absf(skel.status_left("held") - trap_def.trap_seconds) < 0.3) and traps.armed_at(AHEAD_1) == null)
	check("trap: it lies closed on the tile, to be picked up again", dungeon.item_at(AHEAD_1) != null and dungeon.item_at(AHEAD_1).def == trap_def)
	check("trap: event trap_triggered once, naming the trap and the monster", events.trap_triggered.size() == triggered_before + 1
			and events.trap_triggered[-1][0] == trap_def and events.trap_triggered[-1][1] == skel)
	dungeon.clear_monsters()
	dungeon.set_pile(AHEAD_1, [])
	trap_def.break_chance = 1.0
	traps.arm(AHEAD_1, trap_def, thief.hero_index)
	skel = _monster("skeleton", AHEAD_2, 50)
	skel.move_wait = 999.0
	skel._step(Vector2i(-1, 0))
	await create_timer(0.45).timeout
	check("trap: sometimes its spring snaps and nothing is left", dungeon.item_at(AHEAD_1) == null and hud.lines.any(func(l): return str(l.text).contains("The trap's spring snaps.")))
	trap_def.break_chance = saved_break
	dungeon.clear_monsters()
	traps.arm(AHEAD_1, trap_def, thief.hero_index)
	var slime: Node = _monster("slime", AHEAD_2)
	slime.move_wait = 999.0
	var slime_hp: int = slime.hp
	slime._step(Vector2i(-1, 0))
	await create_timer(0.45).timeout
	check("trap: the slime oozes through it and it stays armed", traps.armed_at(AHEAD_1) == trap_def and slime.hp == slime_hp
			and not slime.has_status("held") and hud.lines.any(func(l): return str(l.text).contains("The slime oozes through the trap.")))
	traps.disarm(AHEAD_1)
	dungeon.clear_monsters()
	dungeon.set_pile(AHEAD_1, [])
	_rest_everyone()


func _check_food() -> void:
	_rest_everyone()
	var bread: Resource = load("res://data/items/stale_bread.tres")
	var eater = party.members[0]
	eater.hp = eater.def.max_hp - 10
	var before: int = eater.hp
	var result: Dictionary = party.eat(0, bread)
	check("eating is accepted and does not heal at once", result.used and eater.hp == before)
	await create_timer(3.0).timeout
	check("food heals over time (+%d HP in 3 s)" % (eater.hp - before), eater.hp > before and eater.hp < before + bread.food_heal)
	check("the meal is still working", eater.food_left > 0.0)
	eater.hp = eater.def.max_hp
	check("a healthy hero is not hungry", not party.eat(0, bread).used)


func _check_resurrection() -> void:
	_rest_everyone()
	var scroll: Resource = load("res://data/items/scroll_resurrection.tres")
	check("the scroll does nothing for the living", not party.revive(2, scroll).used)
	var fallen = party.members[2]
	fallen.hp = 0
	party.hp_changed.emit(2)
	var result: Dictionary = party.revive(2, scroll)
	var expected: int = fallen.def.max_hp if fallen.def.magic == 2 else maxi(1, ceili(fallen.def.max_hp * scroll.revive_percent / 100.0))
	check("a Scroll of Resurrection raises a dead hero", result.used and fallen.is_alive() and fallen.hp == expected)
	check("the raised hero returns with no mana", is_zero_approx(fallen.mana))
	check("event: hero_revived once, naming the hero", _sent_once("hero_revived", [fallen.hero_index, true]))


# --------------------------------------------------------------------------
# The world: items, levers, doors, walls, puzzles (and their GameEvents signals)
# --------------------------------------------------------------------------

## A locked door other than the closet used by the save test, and an open tile to stand on facing it: [door, stand, facing].
func _a_locked_door() -> Array:
	var dirs: Array = player.DIRS
	for y in DungeonMap.MAP.size():
		for x in DungeonMap.MAP[y].size():
			var door := Vector2i(x, y)
			if DungeonMap.MAP[y][x] != 3 or door == CLOSETS[1] + Vector2i(0, 1):
				continue
			for facing in 4:
				var stand: Vector2i = door - dirs[facing]
				if not DungeonMap.is_blocked(stand):
					return [door, stand, facing]
	return []


func _check_world_events() -> void:
	_rest_everyone()
	dungeon.clear_monsters()
	var cursor: Node = get_first_node_in_group("cursor")

	# Picking an item up off the floor, then putting it back.
	player.restore(SWORD_TILE - Vector2i(0, 1), 2)  # North of it, facing south.
	var sword = dungeon.item_at(SWORD_TILE)
	player._click_item()
	check("a click picks the item in front up onto the cursor", sword != null and cursor.is_holding() and dungeon.item_at(SWORD_TILE) == null)
	check("event: item_picked_up once, naming the item and how many", sword != null and _sent_once("item_picked_up", [sword.def, 1]))
	player._click_item()
	check("a second click puts it back, with no event", not cursor.is_holding() and dungeon.item_at(SWORD_TILE) != null and events.item_picked_up.size() == 1)

	# A lever.
	dungeon.pull_lever(Vector2i(LEVER.x, LEVER.y), LEVER.z)
	check("event: lever_pulled once, naming the lever and that it is on", dungeon.lever_on.get(LEVER, false)
			and _sent_once("lever_pulled", [Vector2i(LEVER.x, LEVER.y), LEVER.z, true]))

	# A key on a locked door.
	var spot := _a_locked_door()
	check("setup: floor 1 has a second locked door", not spot.is_empty())
	if not spot.is_empty():
		party.add_to_backpack(0, ItemStack.of(load("res://data/items/key.tres"), 1))
		player.restore(spot[1], spot[2])
		player._interact()
		check("a key unlocks the door", DungeonMap.unlocked_doors.has(spot[0]) and party.take_key() == null)
		check("event: door_unlocked once, naming the door", _sent_once("door_unlocked", [spot[0]]))
		player._interact()
		check("the unlocked door sends no second event", events.door_unlocked.size() == 1)

	# A cracked wall.
	check("the cracked wall breaks", dungeon.break_wall(CRACKED_WALL, false) and not DungeonMap.is_wall(CRACKED_WALL))
	check("event: wall_broken once, naming the wall", _sent_once("wall_broken", [CRACKED_WALL]))
	check("a broken wall cannot break again", not dungeon.break_wall(CRACKED_WALL, false) and events.wall_broken.size() == 1)

	# A corrupted wall, and the puzzle that hangs on it.
	check("the corrupted wall starts to burn away", dungeon.purify_wall(THICK_CORRUPTION))
	var waited := 0.0
	while not DungeonMap.purified.has(THICK_CORRUPTION) and waited < 15.0:
		await create_timer(0.25).timeout
		waited += 0.25
	check("the corrupted wall is gone (%.1f s)" % waited, not DungeonMap.is_wall(THICK_CORRUPTION))
	check("event: wall_purified once, naming the wall", _sent_once("wall_purified", [THICK_CORRUPTION]))
	check("event: puzzle_solved once, naming the puzzle", DungeonMap.puzzles_done.has("nook_blessing") and _sent_once("puzzle_solved", ["nook_blessing"]))
	player.restore(SPOT, EAST)


## Party.hurt and Party.heal directly: the one path every HP change takes. Last, because it ends in a wipe.
func _check_hurt_and_heal() -> void:
	_rest_everyone()
	dungeon.clear_monsters()
	var m = party.members[0]
	var died_before: int = events.hero_died.size()
	var hurt_before: int = events.hero_hurt.size()
	check("hurt takes the HP and reports what was lost", party.hurt(m, 5, "test") == 5 and m.hp == m.def.max_hp - 5)
	check("heal never goes above the maximum", party.heal(m, 99, "test") == 5 and m.hp == m.def.max_hp)
	check("heal at full health does nothing", party.heal(m, 3, "test") == 0)
	check("hurt that cannot kill leaves the last HP", party.hurt(m, 999, "test", false) == m.def.max_hp - 1 and m.hp == 1 and m.is_alive())
	check("no death so far", events.hero_died.size() == died_before and events.hero_hurt.size() == hurt_before + 2)

	# Sickness goes through the same path and never kills.
	m.hp = 3
	m.sick_left = 2.0
	m.sick_rate = 6.0
	m.sick_acc = 0.0
	await create_timer(1.5).timeout
	check("sickness hurts but stops at 1 HP", m.hp == 1 and m.is_alive() and events.hero_died.size() == died_before)
	check("event: hero_hurt names sickness as the source", events.hero_hurt.any(func(e): return e[2] == "sickness" and e[0] == m.hero_index))
	m.sick_left = 0.0

	# A killing blow: buffs end, the dead are not healed, a resurrection is.
	_rest_everyone()
	_cast("shield", 0)
	check("setup: the hero has a buff", not m.buffs.is_empty())
	check("hurt can kill", party.hurt(m, 999, "test") == m.def.max_hp and not m.is_alive())
	check("death ends the hero's buffs", m.buffs.is_empty())
	check("event: hero_died for that death", events.hero_died.size() == died_before + 1 and events.hero_died[-1][0] == m.hero_index)
	check("hurting or healing the dead does nothing", party.hurt(m, 5, "test") == 0 and party.heal(m, 5, "test") == 0 and m.hp == 0)
	check("heal can raise the dead only when told to", party.heal(m, 4, "test", true) == 4 and m.hp == 4)

	# Everyone dead: Game over, once.
	var wipes := [0]
	party.wiped.connect(func(): wipes[0] += 1)
	for other in party.members:
		party.hurt(other, 999, "test")
	check("the party is wiped", party.is_wiped())
	await process_frame
	await process_frame
	var game_over: Node = get_first_node_in_group("game_over")
	check("a wipe shows Game over, once", wipes[0] == 1 and game_over != null and game_over.visible and paused)
	paused = false


## Hero names and class ids (docs/code_review.md step 3): the player reads the hero's own name; banter and item rules use the class id.
func _check_names() -> void:
	_rest_everyone()
	var by_class := {}
	for m in party.members:
		by_class[m.class_id()] = m
	check("the four heroes have their class ids", by_class.keys().size() == 4 and by_class.has("cleric") and by_class.has("fighter")
			and by_class.has("thief") and by_class.has("mage"))
	check("the heroes have their own names", by_class.cleric.name() == "Brother Felix" and by_class.fighter.name() == "Brannoc"
			and by_class.thief.name() == "Wren" and by_class.mage.name() == "Fennick")
	check("the class is still the class label", by_class.cleric.def.display_name == "Cleric" and by_class.mage.def.display_name == "Mage")
	check("a long name gets a short form for a narrow label", by_class.cleric.short_name() == "Felix" and by_class.fighter.short_name() == "Brannoc")

	# Messages use the name.
	var cleric = by_class.cleric
	cleric.hp = 1
	var line_count: int = get_first_node_in_group("hud").lines.size()
	cleric.hp = cleric.def.max_hp - 5
	party.eat(cleric.slot, load("res://data/items/stale_bread.tres"))
	_cast("heal", cleric.slot)
	var said: String = " ".join(get_first_node_in_group("hud").lines.slice(line_count).map(func(l): return str(l.text)))
	check("a casting message names the hero, not the class", "Brother Felix" in said and not ("Cleric" in said))

	# Item rules match the class id.
	var armour: Resource = load("res://data/items/leather_armour.tres")
	check("the Mage cannot wear leather armour (cant_use is a class id)", not party.can_equip(by_class.mage, armour) and party.can_equip(by_class.fighter, armour))
	check("the refusal names the hero", "Fennick" in party.equip_refusal(by_class.mage, armour))

	# Banter: speakers are class ids; the log shows the hero's name, and renaming changes only that.
	var banter: Node = get_first_node_in_group("banter")
	banter.reset_timers()
	var lines: Array = banter.event("hit_behind", {"actor": "fighter"})
	check("banter speaks as the hero's name, not the class", lines.size() == 1 and str(lines[0]).begins_with("Fennick: "))
	var mage_def: Resource = by_class.mage.def
	mage_def.hero_name = "Fenwick the Test"  # (Restored below: this resource is shared.)
	banter.reset_timers()
	lines = banter.event("hit_behind", {"actor": "fighter"})
	check("renaming a hero changes the banter prefix and nothing else", lines.size() == 1 and str(lines[0]).begins_with("Fenwick the Test: "))
	check("a renamed Mage still cannot wear leather armour", not party.can_equip(by_class.mage, armour))
	mage_def.hero_name = "Fennick"
	banter.reset_timers()
	_rest_everyone()


## The fight tracker (docs/code_review.md step 4): a fight starts with a blow or a monster noticing the party, and ends after quiet.
func _check_fight() -> void:
	_rest_everyone()
	dungeon.clear_monsters()
	player.restore(SPOT, EAST)  # (The stairs check left the party on the stairs.)
	var fight: Node = party.fight
	check("the party has a fight tracker", fight != null)
	if fight == null:
		return
	var config: Resource = SpellEffectsConfig.get_config()
	var clear_was: float = config.fight_clear_seconds
	var gap_was: float = config.fight_gap_seconds
	config.fight_clear_seconds = 0.6  # Short, so the test need not wait long.
	config.fight_gap_seconds = 1.5
	var banter: Node = get_first_node_in_group("banter")
	var gap_was_banter: float = banter.min_gap
	banter.min_gap = 0.0  # (The global gap would hide the second warning: it is tested in banter_test.gd.)
	var warnings := func() -> int:
		return banter.said.filter(func(l): return "BEHIND US" in str(l)).size()

	var waited := 0.0
	while fight.in_fight and waited < 4.0:
		await create_timer(0.2).timeout
		waited += 0.2
	check("no fight while nothing is going on", not fight.in_fight and fight.aware_count() == 0)
	fight_log.clear()

	# A hero's spell, even before the monster has noticed anything.
	var target: Node = _monster("skeleton", AHEAD_2, 99)
	_cast("magic_missile")
	check("a blow starts a fight, and says so once", fight.in_fight and fight_log == ["started"])
	_cast("magic_missile")
	check("a second blow does not start another", fight_log == ["started"])
	dungeon.clear_monsters()
	await create_timer(1.2).timeout
	check("the fight ends when it goes quiet (and says so once)", not fight.in_fight and fight_log == ["started", "ended"])

	# A monster that sees the party starts one with no blow at all; one shut in a closet does not.
	var seen: Node = _monster("skeleton", AHEAD_2 + Vector2i(2, 0))
	var hidden: Node = _monster("slime", CLOSETS[0])
	hidden._on_tick()
	check("a monster behind a shut door starts no fight", not fight.in_fight and fight_log.size() == 2)
	seen._on_tick()
	check("a monster that notices the party starts a fight", fight.in_fight and fight.aware_count() == 1 and fight_log.size() == 3)
	dungeon.clear_monsters()
	await create_timer(1.2).timeout
	check("with it gone the fight ends", not fight.in_fight and fight_log == ["started", "ended", "started", "ended"])

	# A monster's blow, and "Something's behind you!" once a fight.
	player.restore(Vector2i(9, 13), 1)  # Facing west: east, where the skeleton stands, is behind.
	var rear: Node = _monster("skeleton", Vector2i(10, 13))
	var blows := 0
	while warnings.call() == 0 and blows < 80:
		_rest_everyone()
		party.take_hit_from(rear)
		blows += 1
	check("a monster's blow from behind starts a fight and warns (%d blows)" % blows, fight.in_fight and warnings.call() == 1 and fight_log.size() == 5)
	for i in 12:
		_rest_everyone()
		party.take_hit_from(rear)
	check("the warning is said once in a fight", warnings.call() == 1 and fight.behind_warned)
	dungeon.clear_monsters()
	await create_timer(1.2).timeout
	check("the fight ends and the warning is ready again", not fight.in_fight and not fight.behind_warned)
	rear = _monster("skeleton", Vector2i(10, 13))
	blows = 0
	while warnings.call() < 2 and blows < 80:
		_rest_everyone()
		party.take_hit_from(rear)
		blows += 1
	check("in the next fight it warns again", warnings.call() == 2)
	dungeon.clear_monsters()
	await create_timer(1.2).timeout
	var four := ["started", "ended", "started", "ended", "started", "ended", "started", "ended"]  # A spell, a monster noticing, two blows from behind.
	check("four fights: each started once and ended once", fight_log == four)

	config.fight_clear_seconds = clear_was
	config.fight_gap_seconds = gap_was
	banter.min_gap = gap_was_banter
	player.restore(SPOT, EAST)
	_rest_everyone()


func _check_stairs() -> void:
	var stairs := Vector2i(-1, -1)
	for y in DungeonMap.MAP.size():
		for x in DungeonMap.MAP[y].size():
			if DungeonMap.MAP[y][x] == 4:
				stairs = Vector2i(x, y)
	player.restore(stairs, 0)
	player._arrive()
	check("event: level_completed once, on the stairs", stairs.x >= 0 and _sent_once("level_completed", []))
	paused = false  # (The Level complete screen pauses the game.)


# --------------------------------------------------------------------------
# Save and load
# --------------------------------------------------------------------------

func _stack_text(stack) -> String:
	return "-" if stack == null else "%s x%d" % [stack.def.resource_path, stack.count]


## Everything the round trip must give back, as plain values that can be compared.
func _snapshot() -> Dictionary:
	var hp := [0, 0, 0, 0]
	var mana := [0.0, 0.0, 0.0, 0.0]
	var items := ["", "", "", ""]
	for m in party.members:  # By hero, not by position: the formation is compared on its own.
		hp[m.hero_index] = m.hp
		mana[m.hero_index] = m.mana
		var parts := []
		for stack in m.hands:
			parts.append(_stack_text(stack))
		parts.append(_stack_text(m.armour))
		for stack in m.backpack:
			parts.append(_stack_text(stack))
		for stack in m.quick:
			parts.append(_stack_text(stack))
		items[m.hero_index] = " | ".join(parts)
	var doors := []
	for cell in DungeonMap.open_doors:
		doors.append(str(cell))
	doors.sort()
	var levers := []
	for key in dungeon.lever_on:
		if dungeon.lever_on[key]:
			levers.append(str(key))
	levers.sort()
	var piles := []
	for cell in dungeon.items:
		var parts := []
		for stack in dungeon.items[cell].pile:
			parts.append(_stack_text(stack))
		piles.append("%s: %s" % [cell, " | ".join(parts)])
	piles.sort()
	var monsters := []
	for n in get_nodes_in_group("monsters"):
		if is_instance_valid(n) and n.is_inside_tree() and not n.dying:
			monsters.append("%s at %s hp %d" % [n.def.resource_path, n.cell, n.hp])
	monsters.sort()
	var formation := []  # A copy: party.formation itself changes when heroes swap.
	for h in party.formation:
		formation.append(int(h))
	return {"formation": formation, "hp": hp, "mana": mana, "items": items, "cell": player.cell,
			"facing": player.facing, "doors": doors, "levers": levers, "piles": piles, "monsters": monsters}


func _check_save_load() -> void:
	_rest_everyone()
	dungeon.clear_monsters()
	# A state unlike a fresh game in every part that is saved.
	dungeon.open_door(PLAIN_DOOR)  # (The lever was pulled, a wall broken and another purified in _check_world_events.)
	await create_timer(2.0).timeout  # The door slides for 0.6 s, the portcullis for 1.5 s.
	check("setup: a door is open and a lever is on", DungeonMap.open_doors.has(PLAIN_DOOR) and dungeon.lever_on.get(LEVER, false))
	party.swap_positions(0, 2)
	var potion: Resource = load("res://data/items/healing_potion.tres")
	var stone: Resource = load("res://data/items/stone.tres")
	party.add_to_backpack(1, ItemStack.of(potion, 3))
	party.add_to_backpack(3, ItemStack.of(stone, 7))
	dungeon.place_item(Vector2i(10, 13), ItemStack.of(stone, 4))
	dungeon.take_item(SWORD_TILE)  # The short sword in front of the start is gone.
	DungeonMap.set_flag("smoke.seen", true)
	DungeonMap.set_flag("smoke.count", 3)
	DungeonMap.set_flag("smoke.ratio", 0.5)
	DungeonMap.set_flag("smoke.name", "Fennick")
	DungeonMap.set_flag("smoke.bad", [1, 2])  # (Refused with a warning: only simple values are saved.)
	check("a run flag holds a bool, a number or a string and nothing else", DungeonMap.has_flag("smoke.seen") and DungeonMap.flag("smoke.count") == 3
			and not DungeonMap.has_flag("smoke.bad") and DungeonMap.flag("smoke.missing", 7) == 7)
	var n := 0
	for m in party.members:
		m.hp = maxi(1, m.def.max_hp - 3 - 2 * n)
		m.mana = minf(float(m.def.max_mana), 2.0 + n)
		n += 1
	player.restore(Vector2i(9, 13), 1)
	_monster("slime", CLOSETS[0], 3)
	_monster("skeleton_guard", CLOSETS[1], 5).add_status(load("res://data/statuses/held.tres"), 4.0, 3)
	get_first_node_in_group("traps").arm(Vector2i(11, 13), load("res://data/items/bear_trap.tres"), 2)

	var saved := _snapshot()
	var sent_before := _event_counts()
	var error: String = SaveGame.save(self)
	check("the game saves", error == "" and SaveGame.has_save())

	# Wreck the state, so a load that did nothing cannot pass.
	party.swap_positions(1, 3)
	for m in party.members:
		m.hp = 1
		m.mana = 0.0
		m.backpack[0] = null
	dungeon.clear_monsters()
	dungeon.set_pile(Vector2i(10, 13), [])
	player.restore(DungeonMap.START_TILE, 0)
	DungeonMap.flags.clear()
	DungeonMap.set_flag("smoke.wrecked", true)

	error = SaveGame.load_game(self)
	check("the game loads", error == "")
	var frames := 0
	await process_frame
	while (not SaveGame.pending.is_empty() or get_first_node_in_group("party") == party) and frames < 120:
		await process_frame  # The scene reloads, then the save is applied once it is built.
		frames += 1
	await process_frame
	_find_nodes()
	if party == null or player == null or dungeon == null or not SaveGame.pending.is_empty():
		check("the loaded game is ready", false)
		return
	var loaded := _snapshot()

	check("load: sends no GameEvents (a broken wall, a purified wall and a solved puzzle are put back silently)",
			_event_counts() == sent_before and DungeonMap.broken_walls.has(CRACKED_WALL) and DungeonMap.purified.has(THICK_CORRUPTION)
			and DungeonMap.puzzles_done.has("nook_blessing"))
	var smoke_flags := {}  # (Banter has set flags of its own during the run: look at the test's.)
	for flag_name in DungeonMap.flags:
		if str(flag_name).begins_with("smoke."):
			smoke_flags[flag_name] = DungeonMap.flags[flag_name]
	check("load: run flags come back, with their types, and nothing else", smoke_flags == {"smoke.seen": true, "smoke.count": 3, "smoke.ratio": 0.5, "smoke.name": "Fennick"}
			and typeof(DungeonMap.flags["smoke.count"]) == TYPE_INT and typeof(DungeonMap.flags["smoke.ratio"]) == TYPE_FLOAT
			and not DungeonMap.has_flag("smoke.wrecked"))
	check("load: formation", loaded.formation == saved.formation)
	check("load: every hero's HP", loaded.hp == saved.hp)
	var mana_ok := true
	for i in 4:
		mana_ok = mana_ok and absf(loaded.mana[i] - saved.mana[i]) < 0.25  # (Mana regenerates a little in the frames between.)
	check("load: every hero's mana", mana_ok)
	check("load: hands, armour, backpacks and quick slots", loaded.items == saved.items)
	check("load: player cell and facing", loaded.cell == saved.cell and loaded.facing == saved.facing)
	check("load: open doors", loaded.doors == saved.doors and saved.doors.size() >= 2)
	check("load: levers", loaded.levers == saved.levers and saved.levers.size() == 1)
	check("load: floor piles", loaded.piles == saved.piles)
	check("load: monsters (kind, cell, hp)", loaded.monsters == saved.monsters and saved.monsters.size() == 2)
	var loaded_traps: Node = get_first_node_in_group("traps")
	check("load: an armed trap is still armed where it was set", loaded_traps != null and loaded_traps.armed_at(Vector2i(11, 13)) != null
			and loaded_traps.armed[Vector2i(11, 13)].setter == 2)
	var guard = DungeonMap.occupied.get(CLOSETS[1])
	check("load: a held monster is still held, with its time left (%.2f s)" % (guard.status_left("held") if guard else -1.0),
			guard != null and guard.has_status("held") and guard.status_left("held") > 2.5 and guard.status_left("held") <= 4.0
			and guard.statuses.held.source == 3)
	for key in ["formation", "hp", "items", "doors", "levers", "piles", "monsters"]:
		if loaded[key] != saved[key]:
			print("  ", key, " saved:  ", saved[key])
			print("  ", key, " loaded: ", loaded[key])

	# A save from before run flags existed has no "flags": it loads, with none set.
	var old_save: Dictionary = SaveGame.read_file()
	old_save.erase("flags")
	DungeonMap.set_flag("smoke.stale", true)
	error = SaveGame.apply(self, old_save)
	check("an older save without flags loads, with no flags set", error == "" and DungeonMap.flags.is_empty())
