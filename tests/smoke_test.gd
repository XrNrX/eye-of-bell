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
const LightConfig := preload("res://scripts/light_config.gd")
const SaveGame := preload("res://scripts/save_game.gd")
const ItemStack := preload("res://scripts/item_stack.gd")
const ItemDef := preload("res://scripts/item_def.gd")

const SAVE_PATH := "user://smoke_test_save.json"
const SPOT := Vector2i(6, 13)   # West end of the long corridor; facing east (3) there are six open tiles ahead.
const EAST := 3
const AHEAD_1 := Vector2i(7, 13)
const AHEAD_2 := Vector2i(8, 13)
const CLOSETS: Array[Vector2i] = [Vector2i(18, 1), Vector2i(20, 1)]  # One-tile rooms behind shut doors: a monster there cannot move.
const PLAIN_DOOR := Vector2i(16, 6)
const LEVER := Vector3i(19, 7, 0)  # The north lever of gate_n: cell (19,7), side 0.

const EVENTS := ["monster_killed", "monster_held", "monster_released", "trap_triggered", "light_out", "light_changed", "hero_hurt", "mana_low", "hero_died", "hero_revived", "item_picked_up", "door_unlocked", "lever_pulled", "wall_broken",
		"wall_purified", "puzzle_solved", "level_completed", "entered_curse_zone", "left_curse_zone", "oil_ignited", "camp_made", "camp_ended", "food_cooked", "legendary_found"]
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
	_check_level_data()
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
	DungeonMap.puzzles_done["cave_cleansed"] = true  # Set aside: the older checks clear the monsters by hand, which must not lift the cave's zone. _check_floor_light puts it back.

	dungeon.clear_monsters()
	player.restore(SPOT, EAST)
	_check_light()
	_check_focus_hands()
	_check_kill()
	_check_monster_hit()
	await _check_attack_timing()
	await _check_pacing()
	_check_hero_death()
	_check_spells()
	_check_hold()
	await _check_trap()
	await _check_warden()
	await _check_rat()
	await _check_shockwave()
	await _check_sconces()
	await _check_curse_zones()
	await _check_floor_light()
	await _check_camp()
	await _check_cooking()
	await _check_legendary()
	await _check_azure_brand()
	await _check_item_glow()
	await _check_red_shaman()
	await _check_goblin()
	await _check_knight()
	await _check_log_scroll()
	_check_tooltip_theme()
	await _check_music()
	await _check_curse_look()
	_check_death_gas()
	_check_inventory_quick()
	_check_run_state()
	_check_food_to_portrait()
	_check_mana_potion()
	await _check_oil()
	await _check_torch_throw()
	await _check_food()
	_check_resurrection()
	await _check_world_events()
	_check_puzzles()
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
# Light and darkness (torches and candles)
# --------------------------------------------------------------------------

## The party's light is what it holds: the start (a lit torch, two candles), burning only while held, stowing keeps the time, the
## brightest counts with a capped bonus, a quick-slot candle swaps in, burning out (light_out, the stub gone), light_changed only
## when the light really changes, the torch's fire and a slime recoiling, a slipped torch burning on the floor and going home lit,
## and a light's burn time and floor flame surviving a save.
func _check_light() -> void:
	_rest_everyone()
	dungeon.clear_monsters()
	player.restore(SPOT, EAST)
	var torch: Resource = load("res://data/items/torch.tres")
	var candle: Resource = load("res://data/items/candle.tres")
	var holy: Resource = load("res://data/items/holy_symbol.tres")
	var cleric = party.members.filter(func(m): return m.class_id() == "cleric")[0]
	var fighter = party.members.filter(func(m): return m.class_id() == "fighter")[0]
	var hud: Node = get_first_node_in_group("hud")
	var light_node: Node = get_first_node_in_group("party_light")
	check("light: the cleric starts with a lit torch in hand and two candles in a quick slot", cleric.hands[0] != null and cleric.hands[0].def == torch
			and cleric.quick[0] != null and cleric.quick[0].def == candle and cleric.quick[0].count == 2)
	check("light: the party's light is the torch (level %.2f)" % party.light_level(), is_equal_approx(party.light_level(), torch.light_energy)
			and party.brightest_light() == cleric.hands[0])
	light_node._process(0.0)
	check("light: the party light node shines with it", light_node != null and light_node.visible and is_equal_approx(light_node.omni_range, torch.light_range))
	check("light: a torch is a weak swing from the front row", party.action_for(cleric.slot, 0) == (party.Act.MELEE if party.can_melee(cleric.slot) else party.Act.CANT_REACH))
	var lit = cleric.hands[0]
	lit.burn_left = -1.0
	party._process(10.0)
	check("light: it burns while held (%.1f s left)" % lit.seconds_left(), is_equal_approx(lit.seconds_left(), torch.burn_seconds - 10.0))
	# Stowed: out, its time kept; the light goes with it.
	var changed_before: int = events.light_changed.size()
	cleric.hands[0] = null
	cleric.backpack[11] = lit
	party._process(5.0)
	check("light: stowed, it stops burning and keeps its time", is_equal_approx(lit.seconds_left(), torch.burn_seconds - 10.0) and lit.burn_left > 0.0)
	check("light: the party is dark, and light_changed said so once", party.light_level() == 0.0 and events.light_changed.size() == changed_before + 1
			and is_zero_approx(float(events.light_changed[-1][0])))
	light_node._process(0.0)
	check("light: the party light node is off in the dark", not light_node.visible)
	party._process(1.0)
	check("light: no light_changed while nothing changes", events.light_changed.size() == changed_before + 1)
	check("light: a used torch does not stack with a fresh one", not lit.can_stack_with(ItemStack.of(torch, 1)) and ItemStack.of(torch, 1).can_stack_with(ItemStack.of(torch, 1)))
	# A candle from the quick slot: one comes off the stack into the free hand, lit.
	cleric.cooldown_left = 0.0
	var r: Dictionary = party.use_quick(cleric.slot, 0)
	check("light: a quick-slot candle goes lit into the free hand", r.used and cleric.hands[0] != null and cleric.hands[0].def == candle
			and cleric.hands[1].def == holy and cleric.quick[0].count == 1 and is_equal_approx(party.light_level(), candle.light_energy))
	# Two lights: the brightest counts, a little brighter, capped.
	fighter.hands[1] = ItemStack.of(torch, 1)
	var cfg: Resource = load("res://data/light.tres")
	check("light: two lights: the brightest, a little brighter (%.2f)" % party.light_level(),
			is_equal_approx(party.light_level(), snappedf(torch.light_energy * (1.0 + minf(cfg.extra_light_cap, cfg.extra_light_bonus)), 0.01)))
	# Burning out.
	var out_before: int = events.light_out.size()
	fighter.hands[1].burn_left = 0.05
	party._process(0.1)
	check("light: a light that burns out is gone, with a line", fighter.hands[1] == null
			and hud.lines.any(func(l): return str(l.text) == "%s's torch gutters out." % fighter.name()))
	check("light: light_out once, naming the hero", events.light_out.size() == out_before + 1 and events.light_out[-1][0] == fighter.hero_index)
	# A single light in a quick slot swaps with the light in hand, which is put out into the slot.
	cleric.quick[0] = ItemStack.of(torch, 1)
	r = party.use_quick(cleric.slot, 0)
	check("light: a quick-slot torch swaps with the candle in hand, which goes out into the slot", r.used and cleric.hands[0].def == torch
			and cleric.quick[0] != null and cleric.quick[0].def == candle)
	# The torch's fire: a hit on a slime makes it recoil a tile.
	var slime: Node = _monster("slime", AHEAD_1, 50)
	fighter.hands[0] = ItemStack.of(torch, 1)
	var hit := false
	for i in 40:
		fighter.cooldown_left = 0.0
		var hp_before: int = slime.hp
		party._melee(fighter, 0)
		if slime.hp < hp_before:
			hit = true
			check("light: a torch hit adds fire (%d damage, at least %d)" % [hp_before - slime.hp, torch.damage_min + torch.fire_damage_min],
					hp_before - slime.hp >= torch.damage_min + torch.fire_damage_min)
			break
	check("light: the torch hit the slime", hit)
	check("light: the slime fears fire and recoils a tile", hit and slime.cell == AHEAD_2
			and hud.lines.any(func(l): return str(l.text) == "The slime recoils from the flame."))
	dungeon.clear_monsters()
	# A slip: the torch rolls onto the tile in front still burning, and goes home lit.
	var slipped := false
	for i in 60:
		fighter.cooldown_left = 0.0
		if fighter.hands[0] == null:
			break
		party._critical_fail(fighter, 0, torch, false, AHEAD_1)
		slipped = fighter.hands[0] == null
		if slipped:
			break
	var lights: Node = get_first_node_in_group("lights")
	var on_floor = dungeon.item_at(AHEAD_1)
	check("light: a slipped torch lies in front, still burning", slipped and on_floor != null and on_floor.def == torch and on_floor.burning
			and lights != null and lights.burning.size() == 1)
	var floor_left: float = on_floor.seconds_left() if on_floor != null else 0.0
	lights._process(2.0)
	check("light: it burns down on the floor", on_floor != null and is_equal_approx(on_floor.seconds_left(), floor_left - 2.0))
	var data = SaveGame.stack_to_data(on_floor)
	var back: RefCounted = SaveGame.data_to_stack(data)
	check("light: its burn time and floor flame survive a save", back != null and back.burning and is_equal_approx(back.burn_left, on_floor.burn_left))
	lights.restore()
	check("light: after a load the burning lights are lit again", lights.burning.size() == 1)
	var picked: RefCounted = dungeon.take_item(AHEAD_1)
	var home: String = party.return_to_origin(picked)
	lights._process(0.0)
	check("light: picked up, it goes back to the hand it slipped from, lit there", home != "" and fighter.hands[0] == picked
			and not picked.burning and lights.burning.is_empty())
	# Put the party back as it started.
	fighter.hands = [null, null]
	cleric.hands = [ItemStack.of(torch, 1), ItemStack.of(holy, 1)]
	cleric.quick[0] = ItemStack.of(candle, 2)
	cleric.backpack[11] = null
	party._process(0.0)
	_rest_everyone()


## A spellbook or holy symbol only goes in the hand of a hero who casts that magic; anyone may carry one in a backpack.
func _check_focus_hands() -> void:
	var book: Resource = load("res://data/items/spellbook.tres")
	var symbol: Resource = load("res://data/items/holy_symbol.tres")
	var by_class := {}
	for m in party.members:
		by_class[m.class_id()] = m
	check("focus: only the Mage can hold the spellbook, only the Cleric the holy symbol",
			party.can_equip(by_class.mage, book) and not party.can_equip(by_class.fighter, book) and not party.can_equip(by_class.thief, book)
			and not party.can_equip(by_class.cleric, book) and party.can_equip(by_class.cleric, symbol) and not party.can_equip(by_class.mage, symbol))
	var cursor: Node = get_first_node_in_group("cursor")
	var fighter = by_class.fighter
	var before = fighter.hands[1]
	cursor.hold(ItemStack.of(book, 1))
	var why: String = party.place_in_hand(fighter.slot, 1, cursor)
	check("focus: the Fighter's hand refuses the spellbook, and it stays on the cursor (%s)" % why,
			why == "Brannoc can't make use of the spellbook." and fighter.hands[1] == before and cursor.is_holding())
	check("focus: but it fits in his backpack", party.add_to_backpack(fighter.slot, cursor.release()))
	fighter.backpack[fighter.backpack.find(fighter.backpack.filter(func(s): return s != null and s.def == book)[0])] = null


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
	var overlay: Node = get_first_node_in_group("hit_overlay")
	check("a landed blow plays the monster's hit effect across the view (%s)" % skeleton.def.hit_effect,
			overlay != null and overlay.playing.size() >= 1 and overlay.playing[-1].sprite.texture.resource_path.ends_with("skeleton_claws_sheet.png"))
	var every_effect := true
	for file in ["skeleton", "skeleton_guard", "slime", "slime_acid"]:
		var effect: String = load("res://data/monsters/%s.tres" % file).hit_effect
		every_effect = every_effect and effect != "" and overlay.play(effect, "left", true)
	check("every monster's hit effect exists and plays (crits and side hits too)", every_effect)
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
	check("trap: a monster stepping on it is snapped: hurt and held for %.1f s" % skel.status_left("held"),
			skel.hp < 50 and absf(skel.status_left("held") - trap_def.trap_seconds) < 0.3 and traps.armed_at(AHEAD_1) == null)
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
	# Nothing gets past it: a tougher monster (the guard, tier 2) is held every time.
	trap_def.break_chance = 0.0
	var held_every_time := true
	for i in 6:
		traps.arm(AHEAD_1, trap_def, thief.hero_index)
		var guard: Node = _monster("skeleton_guard", AHEAD_2, 99)
		guard.move_wait = 999.0
		guard._step(Vector2i(-1, 0))
		await create_timer(0.45).timeout
		held_every_time = held_every_time and guard.has_status("held")
		dungeon.clear_monsters()
		dungeon.set_pile(AHEAD_1, [])
	trap_def.break_chance = saved_break
	check("trap: nothing gets past it: a skeleton guard is held every time (6 of 6)", held_every_time)
	# Dropped from the cursor onto the tile in front, it is set there, by the Thief (fastest).
	_rest_everyone()
	cursor.hold(ItemStack.of(trap_def, 2))
	player.world_click()
	check("trap: dropped in front, it is being set by the Thief and one stays on the cursor", traps.setting.size() == 1
			and traps.setting[0].setter == thief.hero_index and thief.cooldown_left > 0.0 and cursor.is_holding() and cursor.held.count == 1)
	traps._process(2.0)
	check("trap: ...and then lies armed", traps.armed_at(AHEAD_1) == trap_def)
	player.world_click()  # Onto a tile that has a trap already: refused, kept on the cursor.
	check("trap: dropped where it can't be set, it stays on the cursor", cursor.is_holding() and cursor.held.count == 1 and traps.armed_at(AHEAD_1) == trap_def)
	cursor.release()
	traps.disarm(AHEAD_1)
	# A snap the party can neither see nor hear is not news (a monster wandering onto a trap across the level): the trap still works.
	trap_def.break_chance = 0.0
	check("trap: a snap right in front is seen", traps.witness(AHEAD_2) == "seen")
	player.restore(Vector2i(9, 13), EAST)
	check("trap: three tiles away round a wall it is only heard", traps.witness(Vector2i(9, 10)) == "heard")
	check("trap: across the level, nobody knows", traps.witness(Vector2i(40, 40)) == "")
	player.restore(SPOT, EAST)
	DungeonMap.player_cell = Vector2i(40, 40)  # (The party "is" far away.)
	traps.arm(AHEAD_1, trap_def, thief.hero_index)
	var lines_before: int = hud.lines.size()
	var events_before: int = events.trap_triggered.size()
	skel = _monster("skeleton", AHEAD_2, 50)
	skel.move_wait = 999.0
	skel._step(Vector2i(-1, 0))
	await create_timer(0.45).timeout
	check("trap: out of sight and hearing it still snaps shut on the monster (hurt, held, spent)...", skel.hp < 50 and skel.has_status("held") and traps.armed_at(AHEAD_1) == null)
	check("trap: ...but says nothing: no log line, no news", hud.lines.size() == lines_before and events.trap_triggered.size() == events_before)
	trap_def.break_chance = saved_break
	dungeon.clear_monsters()
	dungeon.set_pile(AHEAD_1, [])
	player.restore(SPOT, EAST)
	_rest_everyone()


## The mini-boss (the Cursed Warden, tier 3) and the mana rate that goes with him: he guards the stairs, a bear trap holds him
## for half the time and only once a fight, and mana comes back at 1 point per 6 s.
func _check_warden() -> void:
	_rest_everyone()
	dungeon.clear_monsters()
	player.restore(SPOT, EAST)
	var warden_def: Resource = load("res://data/monsters/warden.tres")
	var placed: Array = DungeonMap.MONSTERS.filter(func(e): return e.def == "res://data/monsters/warden.tres")
	check("warden: floor 1 has one, in the corridor before the stairs", placed.size() == 1 and placed[0].cell == Vector2i(20, 22))
	check("warden: tier 3, a boss bar, 80 HP", warden_def.tier == 3 and warden_def.boss and warden_def.max_hp == 80)
	var odds: Dictionary = load("res://data/tiers.tres").odds("held", warden_def)
	check("warden: Hold Monster lands 35% of the time, for half as long", odds.chance == 35 and is_equal_approx(odds.duration, 0.5))
	var trap_def: Resource = load("res://data/items/bear_trap.tres")
	var traps: Node = get_first_node_in_group("traps")
	var saved_break: float = trap_def.break_chance
	trap_def.break_chance = 0.0
	traps.caught.clear()
	traps.arm(AHEAD_1, trap_def, -1)
	var warden: Node = _monster("warden", AHEAD_2)
	warden.move_wait = 999.0
	warden.attack_cooldown = 999.0
	warden._step(Vector2i(-1, 0))
	await create_timer(0.45).timeout
	check("warden: a trap holds him for %.1f s (half of %.1f)" % [warden.status_left("held"), trap_def.trap_seconds],
			absf(warden.status_left("held") - trap_def.trap_seconds * 0.5) < 0.3)
	warden.remove_status("held", false)
	dungeon.set_pile(AHEAD_1, [])
	traps.arm(AHEAD_2, trap_def, -1)
	warden._step(Vector2i(1, 0))
	await create_timer(0.45).timeout
	var hud: Node = get_first_node_in_group("hud")
	check("warden: a second trap in the same fight bites but does not hold him", not warden.has_status("held") and traps.armed_at(AHEAD_2) == null
			and hud.lines.any(func(l): return str(l.text).contains("tears free")))
	dungeon.set_pile(AHEAD_2, [])
	root.get_node("GameEvents").fight_ended.emit()
	traps.arm(AHEAD_1, trap_def, -1)
	warden._step(Vector2i(-1, 0))
	await create_timer(0.45).timeout
	check("warden: in a new fight a trap holds him again", warden.has_status("held"))
	trap_def.break_chance = saved_break
	dungeon.clear_monsters()
	dungeon.set_pile(AHEAD_1, [])
	traps.caught.clear()
	# Mana: 1 point per 6 s.
	var mage = party.members.filter(func(m): return m.class_id() == "mage")[0]
	mage.mana = 0.0
	party._process(6.0)
	check("mana: one point comes back in 6 s (%.2f)" % mage.mana, is_equal_approx(mage.mana, 1.0))
	var fight: Node = party.fight
	var waited := 0.0
	while fight.in_fight and waited < 8.0:  # Let the fight the traps started end, so later checks start calm.
		await create_timer(0.25).timeout
		waited += 0.25
	_rest_everyone()


## The plague rat (tier 1, fast, fears fire): its numbers, its nest, a bite that may make a hero sick, and the raw meat it leaves.
## Every torch-second in the game: in hands, backpacks, quick slots, the cursor, on the floor, and in the sconces that hold a torch.
## Torches are never created, so this stays the same through any lighting, taking and hanging (it only falls as a torch burns in a hand).
func _torch_seconds() -> float:
	var total := 0.0
	for stack in _all_torch_stacks():
		total += stack.seconds_left() * stack.count
	for key in dungeon.sconces:
		if dungeon.sconce_at(key) != DungeonMap.SCONCE_EMPTY:
			total += dungeon.sconce_time(key)
	return total


## How many torches there are: stacks of them anywhere, and the ones hanging in sconces.
func _torches_in_the_game() -> int:
	var n := 0
	for stack in _all_torch_stacks():
		n += stack.count
	for key in dungeon.sconces:
		if dungeon.sconce_at(key) != DungeonMap.SCONCE_EMPTY:
			n += 1
	return n


func _all_torch_stacks() -> Array:
	var cursor: Node = get_first_node_in_group("cursor")
	var stacks: Array = [cursor.held]
	for m in party.members:
		stacks += m.hands + m.backpack + m.quick
	for cell in dungeon.items:
		stacks += dungeon.items[cell].pile
	return stacks.filter(func(s): return s != null and s.def.fits_sconce)


## A lit torch can be thrown (7l.4): shift+click on its hand; it flies up to 4 tiles with its light, does 1-3 fire to a monster it hits (a monster that
## fears fire recoils, a doused one catches), burns where it lands, lights a slick there, keeps the time it had, and goes home to its hand when picked
## up. A candle cannot be thrown.
func _check_torch_throw() -> void:
	var torch: Resource = load("res://data/items/torch.tres")
	var candle: Resource = load("res://data/items/candle.tres")
	var fighter = null
	for m in party.members:
		if m.class_id() == "fighter":
			fighter = m
	var held_before := []
	for m in party.members:
		held_before.append(m.hands.duplicate())
	dungeon.clear_monsters()
	dungeon.oil.load_state({"slicks": [], "burning": []})
	check("torch throw: a torch can be thrown (1-3), a candle cannot", torch.can_throw() and torch.throw_damage_min == 1 and torch.throw_damage_max == 3 and not candle.can_throw())
	player.restore(SPOT, EAST)
	var torch_stack: RefCounted = ItemStack.of(torch, 1)
	torch_stack.burn_left = 90.0
	fighter.hands = [torch_stack, null]
	check("torch throw: a plain click on the hand still swings it (the front row), only shift+click throws", party.action_for(fighter.slot, 0) == party.Act.MELEE)

	# A candle: shift+click swings, nothing is thrown.
	var candle_stack: RefCounted = ItemStack.of(candle, 1)
	fighter.hands = [candle_stack, null]
	fighter.cooldown_left = 0.0
	party.act(fighter.slot, 0, true)
	check("torch throw: shift+click on a candle throws nothing", fighter.hands[0] == candle_stack and dungeon.item_at(Vector2i(10, 13)) == null and dungeon.lights.burning.is_empty())

	# Thrown with no monster: it flies the whole 4 tiles, with its light, and burns where it lands, keeping its time.
	fighter.hands = [torch_stack, null]
	fighter.cooldown_left = 0.0
	var lights_before := _count_omni(dungeon)
	party.act(fighter.slot, 0, true)
	var land := Vector2i(10, 13)  # Four tiles from the party's tile.
	check("torch throw: with the hand shift-clicked it flies 4 tiles (its light flies with it), the hand is empty and it lies burning there",
			fighter.hands[0] == null and _count_omni(dungeon) > lights_before and dungeon.fire_at(land) and dungeon.lights.burning.any(func(e): return e.cell == land))
	var lying: RefCounted = dungeon.item_at(land)
	check("torch throw: it keeps the time it had (90 s, less a moment), and remembers the hand it left", lying != null and lying.def == torch and lying.burning and lying.burn_left > 80.0 and lying.burn_left <= 90.0
			and lying.origin.has("hero") and lying.origin.hero == fighter.hero_index)

	# Picking it up sends it home to the hand.
	var taken: RefCounted = dungeon.take_item(land)
	var home: String = party.return_to_origin(taken)
	check("torch throw: picked up it goes home to the hand it left", home != "" and fighter.hands[0] == taken and fighter.hands[0].def == torch)
	await create_timer(0.2).timeout
	check("torch throw: and the floor flame is out", dungeon.lights.burning.is_empty())

	# At a monster: a landed hit does 1-3 fire (a crit may double it), a monster that fears fire recoils; the torch lies burning on its tile.
	var hit := false
	var tries := 0
	var slime: Node = null
	while not hit and tries < 12:
		tries += 1
		dungeon.clear_monsters()
		slime = _monster("slime", AHEAD_2, 40)
		slime.move_wait = 999.0
		slime.attack_cooldown = 0.0
		fighter.hands = [ItemStack.of(torch, 1), null]
		fighter.cooldown_left = 0.0
		party.act(fighter.slot, 0, true)
		hit = slime.hp < 40
	check("torch throw: a landed hit does 1-3 fire (a crit up to 6), the slime recoils from it, and the torch lies burning on its tile (%d throws)" % tries,
			hit and 40 - slime.hp >= 1 and 40 - slime.hp <= 6 and slime.attack_cooldown >= LightConfig.get_config().recoil_delay and dungeon.fire_at(AHEAD_2))
	while dungeon.take_item(AHEAD_2) != null:
		pass  # (Every throw that missed also left a burning torch on that tile: take them all, however many the dice gave.)
	dungeon.clear_monsters()

	# A doused monster hit by a thrown torch takes +6 and burns.
	hit = false
	tries = 0
	var doused: Node = null
	while not hit and tries < 12:
		tries += 1
		dungeon.clear_monsters()
		doused = _monster("skeleton", AHEAD_2, 99)
		doused.add_status(load("res://data/statuses/held.tres"), 30.0, 1)
		doused.add_status(load("res://data/statuses/doused.tres"), 30.0, 1)
		fighter.hands = [ItemStack.of(torch, 1), null]
		fighter.cooldown_left = 0.0
		party.act(fighter.slot, 0, true)
		hit = doused.hp < 99
	check("torch throw: a doused monster hit by a thrown torch takes the +6 and burns (%d throws)" % tries, hit and doused.has_status("burning") and not doused.has_status("doused") and 99 - doused.hp >= 7)
	while dungeon.take_item(AHEAD_2) != null:
		pass
	dungeon.clear_monsters()
	dungeon.lights.restore()

	# It lights a slick where it lands.
	dungeon.oil.add_slick(land)
	fighter.hands = [ItemStack.of(torch, 1), null]
	fighter.cooldown_left = 0.0
	party.act(fighter.slot, 0, true)
	await create_timer(0.3).timeout
	check("torch throw: landing on a slick lights it", dungeon.oil.is_burning(land))
	dungeon.take_item(land)

	# In a curse zone it fizzles where it lands.
	dungeon.oil.load_state({"slicks": [], "burning": []})
	var real_zones: Array = DungeonMap.CURSE_ZONES
	DungeonMap.CURSE_ZONES = [{"id": "smoke_throw", "tiles": [Vector2i(9, 13), Vector2i(10, 13)]}]
	dungeon.curse.pocket_left = 0.0
	fighter.hands = [ItemStack.of(torch, 1), null]
	fighter.cooldown_left = 0.0
	party.act(fighter.slot, 0, true)
	var cold: RefCounted = dungeon.item_at(land)
	check("torch throw: thrown into a curse zone it fizzles where it lands and can be picked up cold", cold != null and not cold.burning and not dungeon.lights.burning.any(func(e): return e.stack == cold))
	dungeon.take_item(land)
	DungeonMap.CURSE_ZONES = real_zones

	for i in party.members.size():
		party.members[i].hands = held_before[i]
	_rest_everyone()
	dungeon.clear_monsters()
	player.restore(SPOT, EAST)


func _count_omni(node: Node) -> int:
	var n := 0
	for child in node.get_children():
		if child is OmniLight3D:
			n += 1
		n += _count_omni(child)
	return n


## The Flask of oil (7l.5): thrown at the floor it lands on the tile in front and leaves a slick; thrown at a monster it is doused; fire (a
## Fireball, a torch swing, a burning torch lying there) lights a slick, which burns 6 s and hurts what stands on it; a doused monster hit by
## fire takes +6 and burns; oil on a weapon; refused in a curse zone; monsters that fear fire will not cross it; saved (see _check_save_load).
func _check_oil() -> void:
	var flask: Resource = load("res://data/items/oil_flask.tres")
	var doused_def: Resource = load("res://data/statuses/doused.tres")
	var fighter = null
	for m in party.members:
		if m.class_id() == "fighter":
			fighter = m
	var held_before := []
	for m in party.members:
		held_before.append(m.hands.duplicate())
	dungeon.clear_monsters()
	dungeon.oil.load_state({"slicks": [], "burning": []})
	fighter.hands = [ItemStack.of(load("res://data/items/short_sword.tres"), 1), ItemStack.of(flask, 3)]
	check("oil: a flask stacks to 3, can be thrown, and a hand click throws it", flask.max_stack == 3 and flask.is_oil and flask.can_throw() and party.action_for(fighter.slot, 1) == party.Act.THROW
			and party.quick_accepts(ItemStack.of(flask, 1)))
	player.restore(SPOT, EAST)
	var ignited_before: int = events.get("oil_ignited", []).size()

	# Thrown at the floor: it always lands on the tile in front, never under the party.
	fighter.cooldown_left = 0.0
	party.act(fighter.slot, 1)
	check("oil: thrown at the floor it leaves a slick on the tile in front, not under the party, and the flask is spent",
			dungeon.oil.has_slick(AHEAD_1) and not dungeon.oil.has_slick(SPOT) and fighter.hands[1].count == 2 and dungeon.oil.slicks[AHEAD_1].left > 119.0
			and get_first_node_in_group("hud").lines.any(func(l): return str(l.text).contains("Oil spreads")))

	# Thrown at a monster: doused for 30 s (a tier table row of its own; slimes too).
	var skeleton: Node = _monster("skeleton", AHEAD_2, 99)
	skeleton.add_status(load("res://data/statuses/held.tres"), 30.0, 1)  # (Held, so it stays on its tile.)
	fighter.cooldown_left = 0.0
	party.act(fighter.slot, 1)
	check("oil: thrown at a monster it is doused for 30 s, and the flask is spent", skeleton.has_status("doused") and skeleton.status_left("doused") > 29.0 and skeleton.status_left("doused") <= 30.0
			and fighter.hands[1].count == 1 and not dungeon.oil.has_slick(AHEAD_2))
	var odds_slime: Dictionary = load("res://data/tiers.tres").odds("doused", load("res://data/monsters/slime.tres"))
	var odds_warden: Dictionary = load("res://data/tiers.tres").odds("doused", load("res://data/monsters/warden.tres"))
	check("oil: doused has its own row in the tier table: slimes and the Warden can be doused", odds_slime.chance == 100 and not odds_slime.immune and odds_warden.chance == 100 and not odds_warden.immune)

	# Fire: a Fireball at the doused monster does +6 and sets it burning, and its blast lights the slick a tile away.
	var hp_before: int = skeleton.hp
	var r := _cast("fireball")
	await create_timer(1.2).timeout
	var after_blast: int = skeleton.hp
	check("oil: a Fireball on a doused monster does +6 (at least 11 in all) and sets it burning; it is no longer doused",
			r.cast and hp_before - after_blast >= 11 and skeleton.has_status("burning") and not skeleton.has_status("doused"))
	check("oil: the blast lit the slick beside it: it burns now, as a light in sprite_lights, and oil_ignited was sent once for that tile",
			dungeon.oil.is_burning(AHEAD_1) and not dungeon.oil.has_slick(AHEAD_1) and dungeon.oil.burning[AHEAD_1].light.is_in_group("sprite_lights")
			and events.get("oil_ignited", []).size() == ignited_before + 1 and events["oil_ignited"][-1][0] == AHEAD_1)
	await create_timer(3.2).timeout
	check("oil: burning does 2 a second for 3 s (about 6 in all, some of it before the blast was measured) and then stops", skeleton.hp <= after_blast - 3 and skeleton.hp >= after_blast - 8 and not skeleton.has_status("burning"))
	dungeon.clear_monsters()

	# A burning tile hurts a monster on it (a held one on a slick can be lit), lasts 6 s and then it is out.
	dungeon.oil.load_state({"slicks": [], "burning": []})
	var trapped: Node = _monster("skeleton", Vector2i(10, 13), 50)
	trapped.add_status(load("res://data/statuses/held.tres"), 30.0, 1)
	dungeon.oil.add_slick(Vector2i(10, 13))
	check("oil: fire on a tile with no oil does nothing, and a slick catches when fire touches it", not dungeon.oil.ignite(Vector2i(9, 13)) and dungeon.oil.has_slick(Vector2i(10, 13)))
	dungeon.oil.ignite(Vector2i(10, 13))
	await create_timer(2.3).timeout
	check("oil: a monster held on the slick takes 2 a second while it burns (the trap combo)", trapped.hp <= 46 and trapped.hp >= 44 and dungeon.oil.is_burning(Vector2i(10, 13)))
	dungeon.oil.burning[Vector2i(10, 13)].left = 1.4
	await create_timer(1.8).timeout
	check("oil: and then it is out", not dungeon.oil.is_burning(Vector2i(10, 13)) and not dungeon.fire_at(Vector2i(10, 13)))
	dungeon.clear_monsters()

	# Monsters that fear fire will not step onto it: burning oil, or a burning torch lying there.
	var slime: Node = _monster("slime", Vector2i(11, 13), 20)
	var plain: Node = _monster("skeleton", Vector2i(12, 13), 20)
	dungeon.oil.add_slick(Vector2i(10, 13))
	dungeon.oil.ignite(Vector2i(10, 13))
	var torch_def: Resource = load("res://data/items/torch.tres")
	var lying: RefCounted = ItemStack.of(torch_def, 1)
	dungeon.place_item(Vector2i(9, 13), lying)
	dungeon.lights.drop(Vector2i(9, 13), lying)
	check("oil: a slime will not step onto burning oil or onto a burning torch lying there", dungeon.fire_at(Vector2i(10, 13)) and dungeon.fire_at(Vector2i(9, 13))
			and not slime._can_enter(Vector2i(10, 13)) and not slime._can_enter(Vector2i(9, 13)))
	check("oil: a monster that does not fear fire may enter a burning tile", plain._can_enter(Vector2i(10, 13)) and not plain.def.fears_fire)
	dungeon.take_item(Vector2i(9, 13))
	dungeon.clear_monsters()

	# A burning torch lying on a slick lights it (a thrown torch landing there).
	dungeon.oil.load_state({"slicks": [], "burning": []})
	dungeon.oil.add_slick(Vector2i(8, 13))
	var dropped: RefCounted = ItemStack.of(torch_def, 1)
	dungeon.place_item(Vector2i(8, 13), dropped)
	dungeon.lights.drop(Vector2i(8, 13), dropped)
	await create_timer(0.3).timeout
	check("oil: a burning torch lying on a slick lights it", dungeon.oil.is_burning(Vector2i(8, 13)))
	dungeon.take_item(Vector2i(8, 13))
	dungeon.oil.load_state({"slicks": [], "burning": []})

	# The party standing in burning oil: each hero loses 1 a second.
	var hp_total_before := _total_hp()
	dungeon.oil.add_slick(SPOT)
	dungeon.oil.ignite(SPOT)
	await create_timer(1.3).timeout
	var alive: int = party.members.filter(func(m): return m.is_alive()).size()
	check("oil: the party standing on burning oil loses 1 HP a second each (%d lost, %d heroes)" % [hp_total_before - _total_hp(), alive], hp_total_before - _total_hp() == alive)
	dungeon.oil.load_state({"slicks": [], "burning": []})
	_rest_everyone()

	# Oil on a weapon: the next 3 landed hits do +2 fire; fire on a doused monster burns it.
	var blade: Dictionary = party.use_item(fighter.slot, flask)
	check("oil: used on a weapon (the inventory's use) it oils the next 3 hits, and a second flask is refused", blade.used and fighter.oiled_hits == 3 and not party.use_item(fighter.slot, flask).used)
	var target: Node = _monster("skeleton", AHEAD_1, 99)
	target.add_status(load("res://data/statuses/held.tres"), 60.0, 1)
	target.add_status(doused_def, 30.0, 1)
	var swings := 0
	while fighter.oiled_hits == 3 and swings < 60:
		fighter.cooldown_left = 0.0
		party.act(fighter.slot, 0)
		swings += 1
	check("oil: the first landed hit on a doused monster burns it (+6 and burning) and uses one of the three", fighter.oiled_hits == 2 and target.has_status("burning") and not target.has_status("doused"))
	while fighter.oiled_hits > 0 and swings < 200:
		fighter.cooldown_left = 0.0
		party.act(fighter.slot, 0)
		swings += 1
	check("oil: each landed hit used one (never a miss), and then the blade is plain", fighter.oiled_hits == 0)
	dungeon.clear_monsters()

	# Refused in a curse zone, and nothing spent; a slick will not catch there.
	var real_zones: Array = DungeonMap.CURSE_ZONES
	DungeonMap.CURSE_ZONES = [{"id": "smoke_oil", "tiles": [SPOT, AHEAD_1, AHEAD_2]}]
	dungeon.curse.pocket_left = 0.0
	fighter.hands[1] = ItemStack.of(flask, 3)
	fighter.cooldown_left = 0.0
	party.act(fighter.slot, 1)
	check("oil: the throw is refused with a line while the party stands in a curse zone, and nothing is spent",
			fighter.hands[1].count == 3 and not dungeon.oil.has_slick(AHEAD_1) and get_first_node_in_group("hud").lines.any(func(l): return str(l.text).begins_with("The air here hates fire.")))
	dungeon.oil.add_slick(AHEAD_2)
	check("oil: a slick will not catch in a zone", not dungeon.oil.ignite(AHEAD_2) and dungeon.oil.has_slick(AHEAD_2))
	DungeonMap.CURSE_ZONES = real_zones
	dungeon.oil.load_state({"slicks": [], "burning": []})

	for i in party.members.size():
		party.members[i].hands = held_before[i]
	_rest_everyone()
	player.restore(SPOT, EAST)


## Curse zones (7l.3): flames die inside one. A made-up zone along the long corridor (x 8-12, row 13) and the sconce at (12,14): held flames
## sputter and go out after a second and light again outside; a Bless's pocket lets them live for 20 s; sconces will not light and a lit one
## goes out; a torch dropped there fizzles; the Unquenchable's kind is untouched; a puzzle effect lifts the zone; entered / left news; nothing
## above tier 1 may be placed in one.
func _check_curse_zones() -> void:
	var torch: Resource = load("res://data/items/torch.tres")
	dungeon.clear_monsters()
	var held_before := []
	for m in party.members:
		held_before.append(m.hands.duplicate())
	var cleric = null
	var fighter = null
	for m in party.members:
		if m.class_id() == "cleric":
			cleric = m
		elif m.class_id() == "fighter":
			fighter = m
	cleric.hands = [null, ItemStack.of(load("res://data/items/holy_symbol.tres"), 1)]
	var flame: RefCounted = ItemStack.of(torch, 1)
	fighter.hands = [null, flame]
	for m in party.members:
		if m != cleric and m != fighter:
			m.hands = [null, null]
	var real_zones: Array = DungeonMap.CURSE_ZONES
	var zone_tiles := [Vector2i(8, 13), Vector2i(9, 13), Vector2i(10, 13), Vector2i(11, 13), Vector2i(12, 13), Vector2i(12, 14)]
	DungeonMap.CURSE_ZONES = [{"id": "smoke_zone", "tiles": zone_tiles}]
	var curse: Node = dungeon.curse
	curse.pocket_left = 0.0  # (An earlier Bless in these tests opened a pocket where the party stood.)
	var was_lit := []  # Sconces the zone puts out (here and within 2 tiles of it): lit again at the end, so floor 1 is as it was.
	for key in dungeon.sconces:
		if dungeon.sconce_at(key) == DungeonMap.SCONCE_LIT:
			was_lit.append(key)
	curse.zones_changed()
	player.restore(Vector2i(6, 13), 3)
	var entered_before: int = events.get("entered_curse_zone", []).size()
	var left_before: int = events.get("left_curse_zone", []).size()
	await create_timer(0.3).timeout
	check("zones: outside it the party's flame burns", not party.flames_out and party.held_lights().size() == 1 and party.light_level() > 0.0)
	check("zones: a zone has haze on every tile (two patches each) and a sconce in it was put out", curse._haze.size() == zone_tiles.size() * 2
			and dungeon.sconce_at(Vector3i(9, 13, 2)) == DungeonMap.SCONCE_UNLIT and dungeon.sconce_at(Vector3i(12, 14, 1)) == DungeonMap.SCONCE_UNLIT
			and is_equal_approx(dungeon.sconce_time(Vector3i(9, 13, 2)), 120.0))

	# The wall torches within 2 tiles of the haze AND in sight of it go out too: (6,12) is 2 tiles from the zone's west end with a clear line,
	# (6,11) is just as near but a wall hides the zone (the haze does not creep round corners, as the cave's corridor sconce needs), (3,7) is far.
	check("zones: a wall torch within 2 tiles and in sight went out too, one behind a wall and a far one did not, and it will not light again there",
			dungeon.sconce_at(Vector3i(6, 12, 3)) == DungeonMap.SCONCE_UNLIT and dungeon.sconce_at(Vector3i(6, 11, 1)) == DungeonMap.SCONCE_LIT
			and dungeon.sconce_at(Vector3i(3, 7, 0)) == DungeonMap.SCONCE_LIT and dungeon.sconces[Vector3i(6, 12, 3)].light == null
			and not dungeon.light_sconce(Vector3i(6, 12, 3)) and dungeon.sconce_blocked(Vector2i(6, 12)) and not dungeon.sconce_blocked(Vector2i(3, 7)))

	# Every light fixed in the world within 2 tiles goes out: the niche's candle at (8,13) (in the zone), and a torch dropped 2 tiles away fizzles.
	var niche = dungeon.alcoves.filter(func(a): return a.cell == Vector2i(8, 13))
	var far_niches: Array = dungeon.alcoves.filter(func(a): return DungeonMap.curse_zone_near(a.cell, 2) == "")
	check("zones: the candle in a wall niche in the zone is out (its flame picture and light gone), the niches far away still burn",
			niche.size() == 1 and not niche[0].lit and not niche[0].light.visible and niche[0].node.mesh == niche[0].out_mesh and niche[0].out_mesh != null
			and far_niches.all(func(a): return a.lit and a.light.visible))
	var near_torch: RefCounted = ItemStack.of(torch, 1)
	dungeon.place_item(Vector2i(6, 13), near_torch)
	dungeon.lights.drop(Vector2i(6, 13), near_torch)
	check("zones: a burning torch dropped 2 tiles from the zone fizzles too", not near_torch.burning and dungeon.light_blocked(Vector2i(6, 13)) and not dungeon.flame_blocked(Vector2i(6, 13)))
	dungeon.take_item(Vector2i(6, 13))

	# Walking in: the flame sputters for a second, then it is out, and not a word until then.
	var lines_before: int = get_first_node_in_group("hud").lines.size()
	player.restore(Vector2i(10, 13), 3)
	await create_timer(0.4).timeout
	var left_s: float = flame.seconds_left()
	check("zones: entering sends the news once, and the flame is still lit but sputtering", events.get("entered_curse_zone", []).size() == entered_before + 1
			and events["entered_curse_zone"][-1][0] == "smoke_zone" and not party.flames_out and party.sputter_left > 0.0 and party.held_lights().size() == 1)
	check("zones: nothing is said until a flame dies", get_first_node_in_group("hud").lines.size() == lines_before)
	await create_timer(1.1).timeout
	check("zones: after a second the held flame is out (no light) and the air says so", party.flames_out and party.held_lights().is_empty() and is_equal_approx(party.light_level(), 0.0)
			and get_first_node_in_group("hud").lines.any(func(l): return str(l.text) == "The air here hates fire."))
	var out_left: float = flame.seconds_left()
	await create_timer(0.3).timeout
	check("zones: a flame that is out burns no time", is_equal_approx(flame.seconds_left(), out_left) and out_left < left_s)

	# The Unquenchable's kind stays lit.
	var proof_def: Resource = torch.duplicate()
	proof_def.curse_proof = true
	fighter.hands = [null, ItemStack.of(proof_def, 1)]
	await create_timer(0.2).timeout
	check("zones: a curse-proof light is never put out", not party.carries_flame() and party.held_lights().size() == 1 and not party.snuffed(fighter.hands[1]))
	fighter.hands = [null, flame]

	# Sconces and the floor: they will not light, and a torch dropped there fizzles.
	check("zones: a sconce in a zone will not light (right click: the air hates fire)", not dungeon.light_sconce(Vector3i(12, 14, 1)) and dungeon.flame_blocked(Vector2i(12, 14))
			and dungeon.sconce_at(Vector3i(12, 14, 1)) == DungeonMap.SCONCE_UNLIT)
	var cold: RefCounted = ItemStack.of(torch, 1)
	cold.burn_left = 90.0
	dungeon.place_item(Vector2i(11, 13), cold)
	dungeon.lights.drop(Vector2i(11, 13), cold)
	check("zones: a burning torch dropped in a zone fizzles where it lands, cold, and keeps its time", not cold.burning and dungeon.lights.burning.is_empty() and is_equal_approx(cold.burn_left, 90.0))
	dungeon.take_item(Vector2i(11, 13))
	var stub: RefCounted = dungeon.take_sconce_torch(Vector3i(12, 14, 1), torch)
	var hung_ok: bool = dungeon.hang_sconce_torch(Vector3i(12, 14, 1), stub)
	check("zones: a torch hung in a bare bracket in a zone stays unlit, keeping its time", hung_ok and dungeon.sconce_at(Vector3i(12, 14, 1)) == DungeonMap.SCONCE_UNLIT
			and is_equal_approx(dungeon.sconce_time(Vector3i(12, 14, 1)), 120.0) and dungeon.sconces[Vector3i(12, 14, 1)].light == null)

	# Leaving: the flame lights again at once.
	player.restore(Vector2i(6, 13), 3)
	await create_timer(0.3).timeout
	check("zones: leaving it the flame burns again, and the left news is sent", not party.flames_out and party.held_lights().size() == 1
			and events.get("left_curse_zone", []).size() == left_before + 1 and events["left_curse_zone"][-1][0] == "smoke_zone")

	# A Bless makes a pocket.
	player.restore(Vector2i(10, 13), 3)
	cleric.shaken_left = 0.0
	cleric.spell_wait.clear()
	var r := _cast("bless")
	await create_timer(0.3).timeout
	check("zones: a Bless opens a pocket of about 20 s here and the air steadies", r.cast and curse.pocket_left > 19.0 and curse.pocketed(Vector2i(10, 13)) and curse.pocketed(Vector2i(11, 14))
			and not curse.pocketed(Vector2i(13, 13)) and not dungeon.flame_blocked(Vector2i(10, 13)))
	await create_timer(1.5).timeout
	check("zones: in the pocket the flame lives (no sputter, no going out)", not party.flames_out and party.held_lights().size() == 1)
	check("zones: a torch dropped in the pocket burns there", (func():
		var t: RefCounted = ItemStack.of(torch, 1)
		dungeon.place_item(Vector2i(11, 13), t)
		dungeon.lights.drop(Vector2i(11, 13), t)
		var burns: bool = t.burning and dungeon.lights.burning.size() == 1
		return burns).call())
	curse.pocket_left = 0.2
	await create_timer(0.6).timeout
	check("zones: when the pocket ends the burning torch on the floor goes out", dungeon.lights.burning.is_empty())
	await create_timer(1.3).timeout
	check("zones: and the held flame sputters and goes out again", party.flames_out and party.held_lights().is_empty())
	dungeon.take_item(Vector2i(11, 13))

	# A puzzle effect lifts the zone for good.
	var Puzzles := preload("res://scripts/puzzles.gd")
	Puzzles.run(dungeon, {"kind": "clear_curse_zone", "id": "smoke_zone"})
	await create_timer(0.3).timeout
	check("zones: a puzzle effect lifts it: the flame burns again, the haze is gone, the run flag is set and a sconce lights",
			DungeonMap.zone_cleared("smoke_zone") and DungeonMap.flag("curse_zone.smoke_zone.cleared", false) == true and curse._haze.is_empty()
			and not party.flames_out and party.held_lights().size() == 1 and dungeon.light_sconce(Vector3i(12, 14, 1)) and DungeonMap.curse_zone_at(Vector2i(10, 13)) == "")

	# Nothing above tier 1 may be placed in a zone.
	DungeonMap.flags.erase("curse_zone.smoke_zone.cleared")
	var real_monsters: Array = DungeonMap.MONSTERS
	DungeonMap.MONSTERS = [{"def": "res://data/monsters/skeleton.tres", "cell": Vector2i(9, 13)}, {"def": "res://data/monsters/warden.tres", "cell": Vector2i(10, 13)},
			{"def": "res://data/monsters/skeleton_guard.tres", "cell": Vector2i(20, 1)}]
	var bad: Array = DungeonMap.zone_tier_violations()
	check("zones: a tier 1 monster may stand in a zone, the Warden (tier 3) is reported, a guard outside it is not", bad.size() == 1 and bad[0].def.ends_with("warden.tres") and bad[0].tier == 3)
	DungeonMap.MONSTERS = real_monsters

	# Back to floor 1.
	DungeonMap.CURSE_ZONES = real_zones
	curse.zones_changed()
	await create_timer(0.1).timeout  # (The niches light again by themselves once the zone is gone.)
	for key in was_lit:
		dungeon.light_sconce(key)
	for i in party.members.size():
		party.members[i].hands = held_before[i]
	party.set_flames_out(false)
	player.restore(Vector2i(6, 13), 3)
	await create_timer(0.2).timeout
	check("zones: floor 1 has only the cave's, and nothing is left over", DungeonMap.CURSE_ZONES.size() == 1 and DungeonMap.CURSE_ZONES[0].id == "cave" and not party.flames_out and dungeon.alcoves.all(func(a): return a.lit))


## How a curse zone looks (the fog and the edge glow): the fog creeps in from the zone's edges, a Bless pushes it back and the edge glow
## with it, both creep back over the pocket's last seconds, the glow thickens the longer the party stays dark, Reduce flashing holds it
## steady, and a flame that dies leaves a wisp. Driven by calling the curse node's own ticks, so it does not depend on real time.
## The inventory screen shows a hero's two quick slots beside the hands and armour, and they work like every other slot there.
func _check_inventory_quick() -> void:
	_rest_everyone()
	var inv: Node = get_first_node_in_group("inventory")
	var cursor: Node = get_first_node_in_group("cursor")
	var hero = party.member(0)
	hero.quick[0] = null
	hero.quick[1] = null
	inv.show_screen(0)
	check("inventory: the quick slots are on the screen, two of them", inv.quick_slots.size() == 2 and inv.quick_slots[0].kind == inv.InventorySlotScript.Kind.QUICK)
	var potion: Resource = load("res://data/items/healing_potion.tres")
	var sword: Resource = load("res://data/items/short_sword.tres")
	cursor.hold(ItemStack.wrap(potion))
	inv.quick_slots[1]._click_slot()
	check("inventory: a potion on the cursor goes into the second quick slot (and the cursor is empty)", hero.quick[1] != null and hero.quick[1].def == potion and not cursor.is_holding())
	var changed := [0]
	var on_changed := func(_slot): changed[0] += 1
	party.quick_changed.connect(on_changed)
	inv.quick_slots[1]._click_slot()
	check("inventory: clicking it empty-handed lifts it back onto the cursor, and the party panel is told", hero.quick[1] == null and cursor.is_holding() and cursor.held.def == potion and changed[0] > 0)
	cursor.release()
	cursor.hold(ItemStack.wrap(sword))
	inv.quick_slots[0]._click_slot()
	check("inventory: a sword does not go in a quick slot", hero.quick[0] == null and cursor.is_holding())
	cursor.release()
	var two: RefCounted = ItemStack.wrap(potion)
	two.count = 2
	cursor.hold(two)
	inv.quick_slots[0]._click_slot()
	var held_two: RefCounted = ItemStack.wrap(potion)
	cursor.hold(held_two)
	inv.quick_slots[0]._click_slot()
	check("inventory: a stack tops up a matching quick stack", hero.quick[0] != null and hero.quick[0].count == 3 and not cursor.is_holding())
	hero.quick[0].count = 1  # Back to a single one, so the right-click below uses it.
	hero.hp = 1
	inv.quick_slots[0]._use_item()
	check("inventory: right-click uses the potion from a quick slot (heals, empties it)", hero.hp > 1 and hero.quick[0] == null)
	party.quick_changed.disconnect(on_changed)
	hero.hp = 0
	cursor.hold(ItemStack.wrap(potion))
	var why: String = inv.quick_slots[0].refusal(cursor.held)
	check("inventory: a dead hero's quick slot refuses a new item (%s)" % why, why != "")
	cursor.release()
	hero.hp = hero.def.max_hp
	inv.hide_screen()
	var press_i := InputEventKey.new()
	press_i.physical_keycode = KEY_I
	press_i.keycode = KEY_I
	press_i.pressed = true
	inv._unhandled_input(press_i)
	check("inventory: pressing I opens it", inv.visible)
	inv._unhandled_input(press_i)
	check("inventory: pressing I again closes it", not inv.visible)
	_rest_everyone()


## Levels are data (docs/code_review.md S6, Foundations Step 12): floor 1 lives in levels/floor_1.gd, use_level_data takes any
## dictionary, use_level is the thin wrapper. Pure DungeonMap checks, run before the scene is built; ends on floor 1.
func _check_level_data() -> void:
	DungeonMap.use_level("")
	check("floor 1 comes from levels/floor_1.gd with all its data (25 rows, 25 sconces, 21 monsters, start (5,9), the menu camera (6,13))",
			DungeonMap.MAP.size() == 25 and DungeonMap.TORCHES.size() == 25 and DungeonMap.MONSTERS.size() == 21 and DungeonMap.START_TILE == Vector2i(5, 9)
			and DungeonMap.MENU_VIEW_CELL == Vector2i(6, 13) and DungeonMap.level_id == DungeonMap.FLOOR_1_ID and DungeonMap.level_path == "")
	var data := {"MAP": [[1, 1, 1], [1, 0, 1], [1, 1, 1]], "START_TILE": Vector2i(1, 1), "START_FACING": 2,
			"MONSTERS": [{"cell": Vector2i(1, 1), "def": "res://data/monsters/slime.tres"}]}
	var copy: Dictionary = data.duplicate(true)
	DungeonMap.use_level_data(data, "seed:42")
	check("use_level_data puts a level given as a dictionary in place (map, start, facing, monsters)",
			DungeonMap.MAP.size() == 3 and DungeonMap.START_TILE == Vector2i(1, 1) and DungeonMap.START_FACING == 2 and DungeonMap.MONSTERS.size() == 1)
	check("fields the data leaves out are empty, and the menu camera falls back to the start tile",
			DungeonMap.TORCHES.is_empty() and DungeonMap.ITEMS.is_empty() and DungeonMap.PUZZLES.is_empty() and DungeonMap.CORRUPTION.is_empty()
			and DungeonMap.MENU_VIEW_CELL == Vector2i(1, 1))
	check("its id is kept (and a level that is not floor 1 refuses a save through level_path)", DungeonMap.level_id == "seed:42" and DungeonMap.level_path == "seed:42")
	DungeonMap.MAP[1][1] = 7
	check("the caller's dictionary is copied, never changed by the run", data == copy)
	check("use_level_id builds floor 1 and a level script, and says no to an id it cannot build",
			DungeonMap.use_level_id("") and DungeonMap.level_id == DungeonMap.FLOOR_1_ID and DungeonMap.use_level_id(DungeonMap.FLOOR_1_ID)
			and not DungeonMap.use_level_id("seed:42") and not DungeonMap.use_level_id("res://levels/nothing_here.gd"))
	if DungeonMap.test_room_available():
		var consts: Dictionary = load(DungeonMap.TEST_ROOM_PATH).get_script_constant_map()
		DungeonMap.use_level(DungeonMap.TEST_ROOM_PATH)
		check("use_level(path) is the wrapper: the test room's own data, its path as the id", DungeonMap.MAP == consts.MAP and DungeonMap.level_id == DungeonMap.TEST_ROOM_PATH
				and DungeonMap.level_path == DungeonMap.TEST_ROOM_PATH)
		check("a level file with no menu camera gets its start tile for it", DungeonMap.MENU_VIEW_CELL == DungeonMap.START_TILE)
	DungeonMap.use_level("")
	check("and floor 1 comes back whole after any of it", DungeonMap.MAP.size() == 25 and DungeonMap.MAP[4][16] == 7 and DungeonMap.MONSTERS.size() == 21
			and DungeonMap.MENU_VIEW_CELL == Vector2i(6, 13))


## RunState carries the party to the next level (run_state.gd): their HP, gear and food, the cursor's item and the banter flags.
func _check_run_state() -> void:
	_rest_everyone()
	var RunState := preload("res://scripts/run_state.gd")
	var cursor: Node = get_first_node_in_group("cursor")
	var hero = party.member(1)
	var bread: Resource = load("res://data/items/stale_bread.tres")
	hero.hp = 7
	hero.mana = 2.0
	hero.backpack[5] = ItemStack.wrap(bread)
	hero.backpack[5].count = 4
	cursor.hold(ItemStack.wrap(load("res://data/items/dried_meat.tres")))
	DungeonMap.set_flag("banter.once.carried", true)
	DungeonMap.set_flag("puzzle.some.step", 2)
	check("RunState.carry takes the party", RunState.carry(self) and RunState.has())
	# The next level's party starts fresh...
	hero.hp = hero.def.max_hp
	hero.mana = float(hero.def.max_mana)
	hero.backpack[5] = null
	cursor.release()
	DungeonMap.flags.clear()
	# ...and apply puts the carried party on it.
	check("RunState.apply brings it back with no problem", RunState.apply(self) == "" and not RunState.has())
	check("the party's HP, mana and backpack stack are as they were",
			hero.hp == 7 and is_equal_approx(hero.mana, 2.0) and hero.backpack[5] != null and hero.backpack[5].def == bread and hero.backpack[5].count == 4)
	check("the item on the cursor comes along", cursor.is_holding() and cursor.held.def.resource_path == "res://data/items/dried_meat.tres")
	check("banter flags come along, a level's own flags do not", DungeonMap.has_flag("banter.once.carried") and not DungeonMap.has_flag("puzzle.some.step"))
	check("with nothing waiting apply does nothing", RunState.apply(self) == "")
	RunState.pending = {"party": {"heroes": "not a list"}, "cursor": {"held": null}, "flags": {}}
	check("a damaged carry is refused with a message and changes nothing", RunState.apply(self) != "" and hero.hp == 7 and not RunState.has())
	cursor.release()
	DungeonMap.flags.clear()
	hero.backpack[5] = null
	_rest_everyone()


## The mana potion (data/items/mana_potion.tres, ItemDef.mana_amount 5): a caster gets mana back, nobody else wastes one.
func _check_mana_potion() -> void:
	_rest_everyone()
	var potion: Resource = load("res://data/items/mana_potion.tres")
	check("mana potion: restores 5 mana, stacks to 9, is a consumable a quick slot takes", potion.mana_amount == 5 and potion.max_stack == 9 and potion.heal_amount == 0 and party.quick_accepts(potion))
	var mage = party.member(3)
	var fighter = party.member(0)
	mage.mana = 2.0
	var result: Dictionary = party.use_item(3, potion)
	check("mana potion: a mage at 2 mana drinks it and has 7 (%s)" % result.message, result.used and is_equal_approx(mage.mana, 7.0) and "+5 mana" in result.message)
	mage.mana = 10.0
	result = party.use_item(3, potion)
	check("mana potion: near the top it only gives what fits (+%d), never above the maximum" % (mage.def.max_mana - 10), result.used and is_equal_approx(mage.mana, float(mage.def.max_mana)) and ("+%d mana" % (mage.def.max_mana - 10)) in result.message)
	result = party.use_item(3, potion)
	check("mana potion: a full pool keeps the potion (%s)" % result.message, not result.used and is_equal_approx(mage.mana, float(mage.def.max_mana)))
	result = party.use_item(0, potion)
	check("mana potion: a hero with no mana keeps it too (%s)" % result.message, not result.used and fighter.def.max_mana <= 0)
	mage.mana = 0.0
	mage.hp = 0
	result = party.use_item(3, potion)
	check("mana potion: nothing for the dead", not result.used and is_equal_approx(mage.mana, 0.0))
	_rest_everyone()


## Food on the cursor, clicked onto a portrait, goes into that hero's backpack; Shift+click feeds them.
func _check_food_to_portrait() -> void:
	_rest_everyone()
	var hud: Node = get_first_node_in_group("party_hud")
	var cursor: Node = get_first_node_in_group("cursor")
	var hero = party.member(1)
	hero.backpack = hero.backpack.map(func(_x): return null)
	hero.hp = maxi(1, hero.def.max_hp - 5)
	var hp0: int = hero.hp
	var bread: Resource = load("res://data/items/stale_bread.tres")
	cursor.hold(ItemStack.wrap(bread))
	hud._on_portrait(1)
	var in_pack := false
	for st in hero.backpack:
		if st != null and st.def == bread:
			in_pack = true
	check("food: a plain click on a portrait puts it in that hero's backpack (not eaten)", in_pack and not cursor.is_holding() and hero.food_left == 0.0 and hero.hp == hp0)
	cursor.hold(ItemStack.wrap(bread))
	hud.force_feed = true
	hud._on_portrait(1)
	hud.force_feed = false
	check("food: Shift+click feeds them instead", hero.food_left > 0.0 and not cursor.is_holding())
	hero.backpack = hero.backpack.map(func(_x): return null)
	_rest_everyone()


## The zombie's death gas (gas_field.gd): a 1 in 5 chance of a cloud within a tile of the body, which stings a party standing in it.
func _check_death_gas() -> void:
	dungeon.clear_monsters()
	_rest_everyone()
	var zdef: Resource = load("res://data/monsters/zombie.tres")
	check("gas: the zombie lets gas off one time in five, a tile round", is_equal_approx(zdef.death_gas_chance, 0.2) and zdef.death_gas_radius == 1)
	check("gas: the cloud sheet exists", load("res://art/spells/gas/cloud_sheet.png") != null)
	var cloud: Image = load("res://art/spells/gas/cloud_sheet.png").get_image()
	var green := 0
	for y in cloud.get_height():
		for x in cloud.get_width():
			var px: Color = cloud.get_pixel(x, y)
			if px.a > 0.0 and px.g > px.r + 0.03 and px.g >= px.b:
				green += 1
	check("gas: no green anywhere in the cloud (green is the curse's): %d green pixels" % green, green == 0)
	var gt: Color = LightConfig.get_config().gas_tint
	check("gas: its tint is in the config and never leans green", gt.g <= gt.r + 0.001 and gt.g <= 1.0)
	var gas: Node = dungeon.gas
	var spot: Vector2i = AHEAD_1
	var covered: int = gas.release(spot, 1)
	check("gas: a release covers the open tiles within a tile of the body (%d)" % covered, covered >= 3 and covered <= 9 and gas.has_gas(spot))
	var walls_clear := true
	for c in gas.clouds.keys():
		if DungeonMap.is_wall(c) or maxi(absi(c.x - spot.x), absi(c.y - spot.y)) > 1:
			walls_clear = false
	check("gas: never in a wall or further out", walls_clear)
	var before: int = party.members[0].hp
	var was: Vector2i = DungeonMap.player_cell
	DungeonMap.player_cell = spot
	gas._process(1.05)
	check("gas: a party standing in it loses a hit point each (%d to %d)" % [before, party.members[0].hp], party.members[0].hp == before - 1 and gas.stung == 1)
	DungeonMap.player_cell = Vector2i(-5, -5)
	var hp_now: int = party.members[0].hp
	gas._process(1.05)
	check("gas: a party standing out of it loses nothing", party.members[0].hp == hp_now)
	gas._process(LightConfig.get_config().gas_seconds + 1.0)
	check("gas: it thins away, flipbooks and all", gas.clouds.is_empty())
	DungeonMap.player_cell = was
	# The roll: always at a chance of 1, never at 0.
	var def_chance: float = zdef.death_gas_chance
	var released_before: int = gas.released
	zdef.death_gas_chance = 1.0
	var z: Node = _monster("zombie", spot)
	z._die()
	check("gas: a zombie dying with a sure roll lets gas off", gas.released == released_before + 1 and gas.has_gas(spot))
	gas.clouds.clear()
	zdef.death_gas_chance = 0.0
	var z2: Node = _monster("zombie", spot)
	z2._die()
	check("gas: and with no chance, none", gas.released == released_before + 1)
	zdef.death_gas_chance = def_chance
	dungeon.clear_monsters()
	_rest_everyone()

## Roadmap 7l.6: the light placed on floor 1 and the dark's to-hit penalty (weapons only).
func _check_floor_light() -> void:
	var dice_state: int = CombatRules.rng().state  # The dice are put back at the end, so the checks after this one roll what they always did.
	_rest_everyone()
	dungeon.clear_monsters()
	var lit_n := 0
	var unlit_n := 0
	var empty_n := 0
	for e in DungeonMap.TORCHES:
		if e is Vector4i:
			match e.w:
				DungeonMap.SCONCE_LIT: lit_n += 1
				DungeonMap.SCONCE_UNLIT: unlit_n += 1
				DungeonMap.SCONCE_EMPTY: empty_n += 1
	check("floor 1 light: 8 lit sconces, 7 unlit with a torch, 10 empty brackets (%d/%d/%d)" % [lit_n, unlit_n, empty_n], lit_n == 8 and unlit_n == 7 and empty_n == 10)
	var torch_cells := [Vector2i(15, 15), Vector2i(20, 7)]
	var loose_ok := true
	for c in torch_cells:
		var t = dungeon.item_at(c)
		loose_ok = loose_ok and t != null and t.def.resource_path.ends_with("torch.tres")
	var candle_at = dungeon.item_at(Vector2i(16, 8))
	check("floor 1 light: loose torches at (15,15) and in room 2, a candle in room 3", loose_ok and candle_at != null and candle_at.def.resource_path.ends_with("candle.tres"))
	check("floor 1 light: nothing above tier 1 stands in the cave's zone", DungeonMap.zone_tier_violations().is_empty())
	check("floor 1 light: the long corridor's wall torch (9,13) stays lit (a wall stops the haze)", DungeonMap.curse_zone_near(Vector2i(9, 13), 2) == "" and DungeonMap.curse_zone_at(Vector2i(8, 17)) == "cave")
	# The cave's rats: all three dead lifts the zone for good.
	DungeonMap.puzzles_done.erase("cave_cleansed")
	for c in [Vector2i(8, 17), Vector2i(7, 18), Vector2i(8, 18)]:
		_monster("plague_rat", c, 5)
	var Puzzles := preload("res://scripts/puzzles.gd")
	Puzzles.check(dungeon, "")
	check("floor 1 light: three live rats keep the zone", DungeonMap.curse_zone_at(Vector2i(8, 17)) == "cave" and not DungeonMap.puzzles_done.has("cave_cleansed"))
	var live := get_nodes_in_group("monsters").filter(func(m): return m.def.resource_path.ends_with("plague_rat.tres"))
	for i in live.size():
		if i < live.size() - 1:
			live[i].take_hit({"hit": true, "damage": 99, "chance": 100, "crit": false, "by": 0})
	await create_timer(0.1).timeout
	check("floor 1 light: two dead rats of three: still in force", DungeonMap.curse_zone_at(Vector2i(8, 17)) == "cave")
	live[live.size() - 1].take_hit({"hit": true, "damage": 99, "chance": 100, "crit": false, "by": 0})
	await create_timer(0.1).timeout
	check("floor 1 light: the third rat dead lifts the zone for good", DungeonMap.curse_zone_at(Vector2i(8, 17)) == "" and DungeonMap.puzzles_done.has("cave_cleansed"))
	# Put it back for the checks after this one.
	DungeonMap.flags.erase("curse_zone.cave.cleared")
	DungeonMap.puzzles_done["cave_cleansed"] = true
	dungeon.clear_monsters()

	# The dark: -10 to hit with a weapon, never for a spell, never for a monster.
	var cleric = party.members.filter(func(m): return m.class_id() == "cleric")[0]
	var fighter = party.members.filter(func(m): return m.class_id() == "fighter")[0]
	var torch: Resource = load("res://data/items/torch.tres")
	var keep: Array = cleric.hands.duplicate()
	player.restore(Vector2i(6, 13), 3)  # Between two wall torches' reach? (6,12) and (6,11) are lit sconces, so this tile is lit by them.
	await create_timer(0.2).timeout
	check("dark: a tile in a lit corridor is lit (no penalty)", party.tile_is_lit() and party.dark_penalty() == 0)
	player.restore(Vector2i(16, 15), 3)  # East corridor, sconces unlit and the party's own torch put away.
	cleric.hands = [null, null]
	await create_timer(0.3).timeout
	var waited_dark := 0.0
	while party.tile_is_lit() and waited_dark < 6.0:  # (A spell's last glow from an earlier check may still be fading.)
		await create_timer(0.25).timeout
		waited_dark += 0.25
	check("dark: no light on the tile, the penalty is 10 (%d)" % party.dark_penalty(), not party.tile_is_lit() and party.dark_penalty() == 10)
	var target: Node = _monster("skeleton", Vector2i(17, 15), 20)
	var plain_chance: int = CombatRules.hit_chance(fighter.def.attack, target.def.defence)
	CombatRules.seed_rng(777)
	var hits := 0
	var runs := 400
	for i in runs:
		if CombatRules.resolve_attack(party.effective_stats(fighter, -1), target.def, 0, CombatRules.CRIT_MULT, -party.dark_penalty()).hit:
			hits += 1
	var dark_chance: int = plain_chance - 10
	check("dark: a weapon blow's hit chance drops from %d%% to %d%% (%d of %d hit)" % [plain_chance, dark_chance, hits, runs], absf(hits / float(runs) * 100.0 - dark_chance) < 8.0)
	var mon_stats = target.def
	check("dark: a monster's blow does not read the penalty (CombatRules.hit_chance on its own stats)", CombatRules.hit_chance(mon_stats.attack, party.effective_stats(fighter).defence) == CombatRules.hit_chance(mon_stats.attack, fighter.def.defence + (fighter.armour.def.defence_bonus if fighter.armour != null else 0)))
	dungeon.clear_monsters()
	# Light on the tile: the party's own torch, and then the penalty is gone.
	var held = ItemStack.of(torch, 1)
	cleric.hands = [held, null]
	await create_timer(0.3).timeout
	check("dark: with a torch in a hand the tile is lit again", party.tile_is_lit() and party.dark_penalty() == 0)
	cleric.hands = keep
	player.restore(SPOT, EAST)
	await create_timer(0.2).timeout
	events["puzzle_solved"].clear()  # (The cave's puzzle was solved on purpose above.)
	CombatRules.rng().state = dice_state

## Roadmap 7h.2: making camp. A bedroll, the refusals, the rest (even climb, Stop, an interruption, a step), what a camp clears, paused burn
## timers, the bedrolls and the events.
func _check_camp() -> void:
	_rest_everyone()
	dungeon.clear_monsters()
	party.fight.in_fight = false
	player.restore(Vector2i(6, 13), 3)
	await create_timer(0.2).timeout
	var camp: Node = get_first_node_in_group("camp")
	var wood: Resource = load("res://data/items/bedroll.tres")
	var cleric = party.members.filter(func(m): return m.class_id() == "cleric")[0]
	var fighter = party.members.filter(func(m): return m.class_id() == "fighter")[0]
	var mage = party.members.filter(func(m): return m.class_id() == "mage")[0]
	var thief = party.members.filter(func(m): return m.class_id() == "thief")[0]
	check("camp: a bedroll is a consumable that stacks to 3 and makes camp, and the camp node is in the game", wood.type == ItemDef.Type.CONSUMABLE and wood.max_stack == 3 and wood.makes_camp and camp != null)
	if camp == null:
		return
	var ended_before: int = events.camp_ended.size()
	var made_before: int = events.camp_made.size()

	# The refusals. Nothing is spent and nothing starts.
	check("camp: a quiet tile is fine", party.camp_refusal() == "")
	_monster("skeleton", Vector2i(9, 13), 20)
	check("camp: a living monster within 4 tiles refuses it (%s)" % party.camp_refusal(), party.camp_refusal() == "Something is too close to rest.")
	var refused: Dictionary = party.use_item(fighter.slot, wood)
	check("camp: using the bedroll then spends nothing and starts nothing", not refused.used and not party.camping and not camp.active and events.camp_made.size() == made_before and refused.message == "Something is too close to rest.")
	dungeon.clear_monsters()
	_monster("skeleton", Vector2i(12, 13), 20)  # Six tiles down the corridor, in plain sight.
	check("camp: a monster in sight, beyond 4 tiles, refuses it (%s)" % party.camp_refusal(), party.camp_refusal() == "Something is watching.")
	dungeon.clear_monsters()
	_monster("skeleton", Vector2i(14, 9), 20)  # In room 3: eight tiles away and walled off.
	check("camp: a monster beyond 4 tiles and out of sight does not (%s)" % party.camp_refusal(), party.camp_refusal() == "")
	dungeon.clear_monsters()
	party.fight.blow()
	check("camp: not in a fight (%s)" % party.camp_refusal(), party.camp_refusal() == "Not in the middle of a fight.")
	party.fight.in_fight = false
	var real_ambushes: Array = DungeonMap.AMBUSHES
	DungeonMap.AMBUSHES = [{"trigger": Vector2i(8, 13), "text": "x", "monsters": []}]
	check("camp: an ambush trigger within 2 tiles refuses it (%s)" % party.camp_refusal(), party.camp_refusal() == "Something waits close by.")
	DungeonMap.AMBUSHES = [{"trigger": Vector2i(11, 13), "text": "x", "monsters": []}]
	check("camp: one 5 tiles away does not", party.camp_refusal() == "")
	DungeonMap.AMBUSHES = real_ambushes

	# Make camp from a hand, with the party hurt, sick, drained and shaken.
	for m in party.members:
		m.hp = maxi(1, m.def.max_hp / 2)
		m.mana = 0.0
		m.sick_left = 8.0
		m.sick_rate = 0.5
		m.food_left = 10.0
		m.food_rate = 0.4
		m.spell_wait[load("res://data/spells/hold_monster.tres")] = 9.0
	cleric.shaken_left = 20.0
	var torch_stack: RefCounted = cleric.hands[0]
	var burn_before: float = torch_stack.seconds_left() if torch_stack != null and torch_stack.def.is_light() else -1.0
	fighter.hands = [ItemStack.of(wood, 2), null]
	fighter.cooldown_left = 0.0
	var meal_hp: int = fighter.hp
	party.act(fighter.slot, 0)
	check("camp: a bedroll in a hand makes camp: one is spent, the camp is on, the party is camping, camp_made once", fighter.hands[0] != null and fighter.hands[0].count == 1 and camp.active and party.camping
			and events.camp_made.size() == made_before + 1)
	check("camp: it cleared the Cleric's shaken, everyone's sickness and recasts, and gave the rest of a running meal at once",
			cleric.shaken_left == 0.0 and party.members.all(func(m): return m.sick_left == 0.0 and m.food_left == 0.0 and m.spell_wait.is_empty()) and fighter.hp >= meal_hp + 3)
	var hp_start := {}
	var mana_start := {}
	for m in party.members:
		hp_start[m] = m.hp  # (the meal's healing is part of where the rest starts)
		mana_start[m] = m.mana
	check("camp: the camp screen shows with a bedroll for each hero", camp.root != null and camp.root.visible and camp.beds.size() == 4 and camp.beds.all(func(b): return b.root.visible))
	party._process(0.1)
	check("camp: while camping the slow mana regeneration waits", cleric.mana == mana_start[cleric])
	camp._process(15.0)
	var half_ok := true
	for m in party.members:
		var want: int = hp_start[m] + int(round((m.def.max_hp - hp_start[m]) * 0.5))
		half_ok = half_ok and m.hp == want
	check("camp: after 15 s HP is half way from where it began to full, for everyone (%d/%d for the fighter)" % [fighter.hp, fighter.def.max_hp], half_ok)
	check("camp: and the casters' mana is half way too (%.1f of %d)" % [cleric.mana, cleric.def.max_mana], is_equal_approx(cleric.mana, cleric.def.max_mana * 0.5) and is_equal_approx(mage.mana, mage.def.max_mana * 0.5) and fighter.mana == 0.0)
	party._process(5.0)
	check("camp: burn timers did not run (a held torch has the same time left)", burn_before < 0.0 or is_equal_approx(torch_stack.seconds_left(), burn_before))
	camp._process(15.1)
	check("camp: after 30 s everyone is at full HP and mana, the rest has ended by itself, and camp_ended(false) went out once",
			party.members.all(func(m): return m.hp == m.def.max_hp and is_equal_approx(m.mana, float(m.def.max_mana))) and not camp.active and not party.camping
			and events.camp_ended.size() == ended_before + 1 and events.camp_ended[-1][0] == false and not camp.root.visible)

	# Stop early: what was gained is kept.
	for m in party.members:
		m.hp = maxi(1, m.def.max_hp / 2)
		m.mana = 0.0
		hp_start[m] = m.hp
	check("camp: it starts again with the stack's last bedroll", party.use_item(fighter.slot, wood).used and camp.active)
	camp._process(10.0)
	var third := true
	for m in party.members:
		third = third and absf(m.hp - (hp_start[m] + (m.def.max_hp - hp_start[m]) / 3.0)) <= 1.0
	check("camp: after 10 s, a third of the way", third)
	var kept: int = fighter.hp
	camp.stop()
	check("camp: Stop ends it and keeps what was gained, and camp_ended(false) went out", fighter.hp == kept and fighter.hp > hp_start[fighter] and not camp.active and not party.camping and events.camp_ended.size() == ended_before + 2)

	# A step or turn ends a rest, and goes no further.
	check("camp: a third camp (no bedroll)", camp.begin() and camp.active)
	var cell_before: Vector2i = player.cell
	player.command("forward")
	check("camp: a step key ends it and the party does not move; a held key stays spent a moment", not camp.active and player.cell == cell_before and camp.consumes_move())
	await create_timer(0.5).timeout
	check("camp: after that moment the party walks again", not camp.consumes_move())

	# A fight breaks it: what was gained is kept, and the event says interrupted.
	for m in party.members:
		m.hp = maxi(1, m.def.max_hp / 2)
	camp.begin()
	camp._process(10.0)
	var gained: int = fighter.hp
	party.fight.blow()
	camp._process(0.1)
	check("camp: a fight ends it as interrupted, keeping what was gained", not camp.active and not party.camping and fighter.hp >= gained and events.camp_ended[-1][0] == true)
	party.fight.in_fight = false

	# The dead are not raised; a bedroll opens its hero's pack and sheet.
	thief.hp = 0
	camp.begin()
	camp._process(30.5)
	check("camp: a fallen hero stays fallen (a camp does not raise the dead) and the others are whole", thief.hp == 0 and fighter.hp == fighter.def.max_hp)
	camp.begin()
	camp._refresh_beds()
	var shown_note: String = camp.beds[thief.slot].note.text
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	camp._bed_input(click, 1)
	var inventory: Node = get_first_node_in_group("inventory")
	check("camp: the bedroll marks a fallen hero, and clicking a bedroll opens that hero's pack and sheet", shown_note == "FALLEN" and inventory != null and inventory.visible and inventory.focused_slot == 1)
	inventory.visible = false
	paused = false
	camp.stop()
	thief.hp = thief.def.max_hp
	_rest_everyone()
	player.restore(SPOT, EAST)
	await create_timer(0.1).timeout
	for name in ["camp_made", "camp_ended", "hero_hurt", "hero_revived", "hero_died"]:
		events[name].clear()

## Roadmap 7h.3: cooking at the camp fire. The cooked foods, the COOK button (every raw stack, one by one), food held on the cursor, the
## sizzle, the news, and that a camp is needed.
func _check_cooking() -> void:
	var dice_state: int = CombatRules.rng().state  # (A cook may burn the food: that rolls the dice, which are put back at the end so later checks roll what they always did.)
	_rest_everyone()
	dungeon.clear_monsters()
	party.fight.in_fight = false
	player.restore(SPOT, EAST)
	await create_timer(0.2).timeout
	var camp: Node = get_first_node_in_group("camp")
	var raw_meat: Resource = load("res://data/items/raw_rat_meat.tres")
	var cooked_meat: Resource = load("res://data/items/cooked_rat_meat.tres")
	var mouldy: Resource = load("res://data/items/mouldy_bread.tres")
	var toast: Resource = load("res://data/items/toasted_bread.tres")
	var dried: Resource = load("res://data/items/dried_meat.tres")
	check("cooking: raw rat meat becomes cooked rat meat (12 HP over 6 s, no sickness), mouldy bread becomes toast with no sickness chance, dried meat is not cookable",
			raw_meat.cooks_into == cooked_meat and cooked_meat.food_heal == 12 and is_equal_approx(cooked_meat.food_seconds, 6.0) and cooked_meat.food_sick_chance == 0.0
			and raw_meat.food_sick_chance > 0.0 and mouldy.cooks_into == toast and toast.food_sick_chance == 0.0 and toast.food_heal > mouldy.food_heal
			and toast.food_seconds < mouldy.food_seconds and not dried.can_cook() and raw_meat.can_cook())
	var fighter = party.members.filter(func(m): return m.class_id() == "fighter")[0]
	var mage = party.members.filter(func(m): return m.class_id() == "mage")[0]
	var thief = party.members.filter(func(m): return m.class_id() == "thief")[0]
	check("cooking: outside a camp nothing can be cooked", camp.cook_all() == 0 and not camp.active)

	# What the party carries: raw meat in a pack, mouldy bread in a hand and in a quick slot.
	for m in party.members:
		for i in m.backpack.size():
			if m.backpack[i] != null and m.backpack[i].def.can_cook():
				m.backpack[i] = null
		for i in m.hands.size():
			if m.hands[i] != null and m.hands[i].def.can_cook():
				m.hands[i] = null
		for i in m.quick.size():
			if m.quick[i] != null and m.quick[i].def.can_cook():
				m.quick[i] = null
	fighter.backpack[3] = ItemStack.of(raw_meat, 4)
	mage.hands[1] = ItemStack.of(mouldy, 2)
	thief.quick[0] = ItemStack.of(mouldy, 3)
	var cooked_before: int = events.food_cooked.size()
	check("cooking: a camp starts, the party is ready, and the COOK button counts the raw food (9 items)", camp.begin() and camp.cookable_count() == 9)
	camp._process(0.0)
	check("cooking: the button says how many (%s)" % camp.cook_button.text, camp.cook_button.text == "COOK (9)" and not camp.cook_button.disabled)
	check("cooking: the COOK button queues every raw stack (3)", camp.cook_all() == 3)
	camp._process(0.01)
	check("cooking: one stack is cooked at once, with a sizzle on the fire", events.food_cooked.size() == cooked_before + 1 and camp.sizzles.size() == 1 and camp.cook_button.disabled)
	camp._process(0.8)
	camp._process(0.8)
	check("cooking: all three are cooked one by one, keeping their counts, and nothing raw is left",
			events.food_cooked.size() == cooked_before + 3 and camp.cookable_count() == 0
			and fighter.hands.all(func(h): return h == null or not h.def.can_cook()) and camp.cookables().is_empty())
	var cooked_in_packs := 0
	for m in party.members:
		for stack in m.backpack + m.hands + m.quick:
			if stack != null and stack.def in [cooked_meat, toast]:
				cooked_in_packs += stack.count
	check("cooking: 4 cooked rat meat, 5 slices of toast (%d in all) and the same slots" % cooked_in_packs,
			cooked_in_packs == 9 and fighter.backpack[3].def == cooked_meat and fighter.backpack[3].count == 4 and mage.hands[1].def == toast and mage.hands[1].count == 2 and thief.quick[0].def == toast and thief.quick[0].count == 3)
	check("cooking: the news names the raw food and who carried it", events.food_cooked[cooked_before][0] == raw_meat or events.food_cooked[cooked_before][0] == mouldy)
	var cooks_line := false
	for line in get_first_node_in_group("hud").lines:
		cooks_line = cooks_line or str(line.text if line is Dictionary else line).contains("cooks the") or str(line.text if line is Dictionary else line).contains("burns the")
	check("cooking: the log says it was cooked (or burnt)", cooks_line)
	check("cooking: the button now says there is nothing to cook, and the sizzle plays out", camp.cook_button.text == "NOTHING TO COOK" and camp.cook_button.disabled)
	camp._process(2.0)
	check("cooking: the sizzle ends by itself", camp.sizzles.is_empty())

	# Cooked food heals more and faster and never makes anyone sick.
	fighter.hp = 5
	var healed_ok := true
	for i in 30:
		fighter.sick_left = 0.0
		var result: Dictionary = party.eat(fighter.slot, cooked_meat)
		healed_ok = healed_ok and result.used and fighter.sick_left == 0.0 and is_equal_approx(fighter.food_left, 6.0) and is_equal_approx(fighter.food_rate, 2.0)
	check("cooking: eating cooked rat meat (30 times) heals 12 over 6 s and never makes anyone sick", healed_ok)

	# Food held on the cursor goes on the fire.
	var cursor: Node = get_first_node_in_group("cursor")
	cursor.release()
	check("cooking: an empty cursor on the fire cooks nothing", not camp.cook_held(cursor))
	cursor.hold(ItemStack.of(load("res://data/items/dagger.tres"), 1))
	check("cooking: a dagger on the fire will not cook and stays held", not camp.cook_held(cursor) and cursor.held.def.display_name == "Dagger")
	cursor.hold(ItemStack.of(raw_meat, 3))
	var before: int = events.food_cooked.size()
	check("cooking: raw meat held on the cursor is cooked on the fire, count kept, news sent once", camp.cook_held(cursor) and cursor.held.def == cooked_meat and cursor.held.count == 3
			and events.food_cooked.size() == before + 1 and events.food_cooked[-1][1] == -1 and camp.sizzles.size() == 1)
	cursor.release()

	# A camp that ends drops what was still queued.
	fighter.backpack[4] = ItemStack.of(raw_meat, 2)
	check("cooking: raw food again, queued", camp.cook_all() == 1)
	camp.end(true)
	check("cooking: ending the camp drops the queue, and nothing cooks outside a camp", camp._cook_queue.is_empty() and camp.cook_all() == 0 and fighter.backpack[4].def == raw_meat)
	fighter.backpack[3] = null
	fighter.backpack[4] = null
	mage.hands[1] = null
	thief.quick[0] = null
	party.fight.in_fight = false
	_rest_everyone()
	for name in ["camp_made", "camp_ended", "food_cooked", "hero_hurt"]:
		events[name].clear()
	CombatRules.rng().state = dice_state

## Foundations step 11 (item behaviour hooks) and roadmap 7g.1 (the legendary framework), with the Test Blade in data/debug.
func _check_legendary() -> void:
	var dice_state: int = CombatRules.rng().state  # (Swings below roll the dice: put back at the end, so later checks roll what they always did.)
	_rest_everyone()
	dungeon.clear_monsters()
	party.fight.in_fight = false
	player.restore(SPOT, EAST)
	await create_timer(0.2).timeout
	var def: Resource = load("res://data/debug/test_legendary.tres")
	var fighter = party.members.filter(func(m): return m.class_id() == "fighter")[0]
	var cleric = party.members.filter(func(m): return m.class_id() == "cleric")[0]
	var mage = party.members.filter(func(m): return m.class_id() == "mage")[0]
	var war_hammer: Resource = load("res://data/items/war_hammer.tres")
	check("legendary: ordinary items have no behaviour and are not legendary; the Test Blade is, with its text and class limits",
			war_hammer.behaviour == null and not war_hammer.legendary and war_hammer.legend_text() == "" and def.legendary and def.behaviour != null
			and def.legend_text().begins_with("LEGENDARY") and def.legend_text().contains("Power:") and def.legend_text().contains("Price:")
			and party.can_equip(fighter, def) and not party.can_equip(cleric, def) and not party.can_equip(mage, def) and party.class_refusal(cleric, def) != "")
	var behaviour = party.behaviour_of(def)
	check("legendary: Party makes one behaviour per item kind, and none for an ordinary item", behaviour != null and party.behaviour_of(def) == behaviour and party.behaviour_of(war_hammer) == null)
	var found_before: int = events.legendary_found.size()
	DungeonMap.flags.erase("legendary.found.%s" % def.resource_path)

	# The hooks: equip, tick, unequip, stowed.
	var stack: RefCounted = ItemStack.of(def, 1)
	fighter.hands = [stack, null]
	var equips: int = behaviour.counts.equip
	var ticks: int = behaviour.counts.tick
	party._tick_items(0.1)
	check("hook: on_equip fired when the blade came into the hand, and on_tick runs while it is held", behaviour.counts.equip == equips + 1 and behaviour.counts.tick == ticks + 1)
	party._tick_items(0.1)
	check("hook: ...and on_equip does not fire again for a blade that stays", behaviour.counts.equip == equips + 1 and behaviour.counts.tick == ticks + 2)
	check("legendary: finding it sent GameEvents.legendary_found once, naming the item and the hero holding it, and set the run flag",
			events.legendary_found.size() == found_before + 1 and events.legendary_found[-1][0] == def and events.legendary_found[-1][1] == fighter.hero_index
			and DungeonMap.has_flag("legendary.found.%s" % def.resource_path))
	var unequips: int = behaviour.counts.unequip
	var stowed: int = behaviour.counts.stowed
	fighter.hands = [null, null]
	fighter.backpack[5] = stack
	party._tick_items(0.1)
	check("hook: on_unequip fired when it left the hand, and on_stowed runs while it sits in a pack", behaviour.counts.unequip == unequips + 1 and behaviour.counts.stowed == stowed + 1)
	party._tick_items(25.0)
	check("hook: on_stowed carries the time: 25 s in the pack and the blade sulks", behaviour.sulking)
	check("legendary: it is found once a run: putting it away and taking it out again sends nothing more", events.legendary_found.size() == found_before + 1)
	fighter.backpack[5] = null
	fighter.hands = [stack, null]
	party._tick_items(0.0)
	check("hook: it was equipped again from the pack (on_equip, and the pack time starts over)", behaviour.counts.equip == equips + 2 and behaviour.stowed_for == 0.0)
	var told: float = behaviour.tick_seconds
	party.camping = true
	party._process(5.0)
	party.camping = false
	check("hook: the clocks wait while camped (on_tick is told no time)", is_equal_approx(behaviour.tick_seconds, told))
	party._process(2.0)
	check("hook: ...and are told the time again afterwards", is_equal_approx(behaviour.tick_seconds, told + 2.0))

	# on_hit and on_kill through the real swing.
	var plain := {"hit": true, "damage": 5}
	var kept_sulk: bool = behaviour.sulking
	behaviour.sulking = true
	party._item_hit(fighter, def, 0, null, plain)
	check("hook: on_hit may change the damage (a sulking blade does 2 less, once)", plain.damage == 3 and not behaviour.sulking)
	var better := {"hit": true, "damage": 5}
	var hits_before: int = behaviour.counts.hit
	party._item_hit(fighter, def, 0, null, better)
	var missed := {"hit": false, "damage": 0}
	party._item_hit(fighter, def, 0, null, missed)
	check("hook: ...and does 1 more when it is not sulking; a miss is no hit", better.damage == 6 and behaviour.counts.hit == hits_before + 1 and missed.damage == 0)
	behaviour.sulking = kept_sulk
	_monster("skeleton", AHEAD_1, 80)
	CombatRules.seed_rng(31)
	var swing_hits: int = behaviour.counts.hit
	for i in 40:
		fighter.cooldown_left = 0.0
		party.act(fighter.slot, 0)
		if behaviour.counts.hit > swing_hits:
			break
	check("hook: a real swing with the blade lands and on_hit hears it", behaviour.counts.hit > swing_hits)
	dungeon.clear_monsters()
	var kills: int = behaviour.counts.kill
	_monster("slime", AHEAD_1, 1)
	for i in 60:
		fighter.cooldown_left = 0.0
		party.act(fighter.slot, 0)
		if behaviour.counts.kill > kills:
			break
	check("hook: a swing that kills sends on_kill", behaviour.counts.kill == kills + 1)
	dungeon.clear_monsters()
	fighter.cooldown_left = 0.0

	# A holder who dies lets go of it.
	var before_death: int = behaviour.counts.unequip
	fighter.hp = 0
	party._tick_items(0.0)
	check("hook: a hero who dies holding it counts as letting go (on_unequip)", behaviour.counts.unequip == before_death + 1)
	fighter.hp = fighter.def.max_hp
	party._tick_items(0.0)

	# The framework's look: the gold mark on slots, text on tooltips and the sheet.
	var Mark: GDScript = load("res://scripts/legendary_mark.gd")
	var probe := Control.new()
	root.add_child(probe)
	Mark.sync(probe, stack)
	var mark = probe.get_node_or_null("LegendMark")
	await process_frame
	check("look: a legendary stack gets the gold mark (the frame and the shimmer), an ordinary one none, and it goes when the item does",
			mark != null and mark.get_child_count() == 2 and probe.get_node_or_null("LegendMark") == mark)
	Mark.sync(probe, ItemStack.of(war_hammer, 1))
	check("look: ...the mark is taken away for an ordinary item", probe.get_node_or_null("LegendMark") == null)
	Mark.sync(probe, stack)
	Settings.reduce_flashing = true
	var shown = probe.get_node("LegendMark")
	await process_frame
	await process_frame
	check("look: Reduce flashing keeps the frame and drops the twinkle", shown._shimmer != null and not shown._shimmer.visible and shown._frame.visible)
	Settings.reduce_flashing = false
	probe.queue_free()
	var colours_ok := true
	for file in ["res://art/ui/legend_frame.png", "res://art/ui/legend_shimmer_sheet.png"]:
		var img: Image = (load(file) as Texture2D).get_image()
		for y in img.get_height():
			for x in img.get_width():
				var c := img.get_pixel(x, y)
				if c.a > 0.0 and c.g > c.r + 0.06 and c.g > c.b + 0.06:
					colours_ok = false  # Anything greener than it is red and blue: never the curse green.
	check("look: the gold frame and shimmer have no curse green in them", colours_ok)

	fighter.hands = [stack, null]
	var inventory: Node = get_first_node_in_group("inventory")
	inventory.show_screen(fighter.slot, true)
	await process_frame
	await process_frame
	var found_slot: Control = null
	var stack_stack := [inventory]
	while not stack_stack.is_empty():
		var n: Node = stack_stack.pop_back()
		if n is Control and n.has_method("get_item") and n.get_item() == stack and n.get_node_or_null("LegendMark") != null:
			found_slot = n
		for c in n.get_children():
			stack_stack.append(c)
	check("look: the inventory slot holding it has the gold mark and a tooltip with its description, power and price (never on right-click)",
			found_slot != null and found_slot.tooltip_text.contains("Test Blade") and found_slot.tooltip_text.contains("Power:") and found_slot.tooltip_text.contains("Price:"))
	check("look: the character sheet lists it with its power and price", inventory.sheet.legend_label.visible and inventory.sheet.legend_label.text.contains("TEST BLADE") and inventory.sheet.legend_label.text.contains("Price:"))
	inventory.visible = false
	paused = false
	var hud: Node = get_first_node_in_group("party_hud")
	await process_frame
	await process_frame
	var hand: TextureButton = hud.panels[fighter.slot].hands[0]
	check("look: the party panel's hand button has the mark and the item's text in its tooltip", hand.get_node_or_null("LegendMark") != null and hand.tooltip_text.contains("Power:") and hand.tooltip_text.begins_with("Test Blade"))
	fighter.hands = [null, null]
	await process_frame
	await process_frame
	check("look: ...and drops the mark when the hand is empty", hand.get_node_or_null("LegendMark") == null)

	# The banter line from the finder.
	var banter: Node = get_first_node_in_group("banter")
	banter.reset_timers()
	var said := ""
	for i in 12:
		var lines: Array = banter.event("legendary_found", {"actor": "fighter", "item": "Test Blade"})
		if not lines.is_empty():
			said = str(lines[0])
			break
		banter.reset_timers()
	check("banter: the finder says a line when they find a legendary (%s)" % said, said != "" and said.begins_with(fighter.name()))
	party._tick_items(0.0)
	fighter.hands = [null, null]
	_rest_everyone()
	DungeonMap.occupied.clear()
	events["legendary_found"].clear()
	events["hero_hurt"].clear()
	events["hero_died"].clear()
	CombatRules.rng().state = dice_state

## The Azure Brand (data/items/azure_brand.tres): a legendary long sword with flame damage, built on the step 11 hooks.
func _check_azure_brand() -> void:
	var dice_state: int = CombatRules.rng().state  # (The swings below roll the dice: put back at the end, so later checks roll what they always did.)
	_rest_everyone()
	dungeon.clear_monsters()
	party.fight.in_fight = false
	player.restore(SPOT, EAST)
	await create_timer(0.2).timeout
	var def: Resource = load("res://data/items/azure_brand.tres")
	var fighter = party.members.filter(func(m): return m.class_id() == "fighter")[0]
	var thief = party.members.filter(func(m): return m.class_id() == "thief")[0]
	var cleric = party.members.filter(func(m): return m.class_id() == "cleric")[0]
	var mage = party.members.filter(func(m): return m.class_id() == "mage")[0]
	var behaviour = party.behaviour_of(def)
	check("azure brand: a legendary long sword (+2 attack, 5-11, never slips) with its text, for a fighter or a thief only",
			def.legendary and behaviour != null and def.type == ItemDef.Type.WEAPON and def.attack_bonus == 2 and def.damage_min == 5 and def.damage_max == 11 and def.never_slips
			and def.legend_text().contains("Power:") and def.legend_text().contains("Price:") and party.can_equip(fighter, def) and party.can_equip(thief, def)
			and not party.can_equip(cleric, def) and not party.can_equip(mage, def))
	check("azure brand: its art is there, in steel greys only: no blue (that glow is a run-time tint) and never curse green",
			def.icon != null and def.hud_icon != null and def.floor_icon != null and _azure_colours_ok(def.icon) and _azure_colours_ok(def.hud_icon))

	# The flame on a landed blow: 2-5 more, fire, a recoil for fire-fearers; a miss is untouched.
	var lo := 99
	var hi := 0
	var fire_flag := true
	var recoil_flag := true
	fighter.hands = [ItemStack.of(def, 1), null]
	var tgt: Node = _monster("slime", AHEAD_1, 40)
	for i in 200:
		var r := {"hit": true, "damage": 5}
		party._item_hit(fighter, def, 0, tgt, r)
		lo = mini(lo, r.damage)
		hi = maxi(hi, r.damage)
		fire_flag = fire_flag and r.get("fire", false)
		recoil_flag = recoil_flag and r.get("recoil", false)
	dungeon.clear_monsters()
	check("azure brand: a landed blow burns for 2 to 5 more (damage 7 to 10 from a 5), counts as fire and asks for the recoil (%d to %d)" % [lo, hi], lo == 7 and hi == 10 and fire_flag and recoil_flag)
	var miss := {"hit": false, "damage": 0}
	var slime0: Node = _monster("slime", AHEAD_1, 40)
	party._item_hit(fighter, def, 0, slime0, miss)
	check("azure brand: a miss burns nothing", miss.damage == 0 and not miss.has("fire"))
	# Oil under its target catches light.
	dungeon.oil.load_state({"slicks": [], "burning": []})
	dungeon.oil.add_slick(AHEAD_1)
	party._item_hit(fighter, def, 0, slime0, {"hit": true, "damage": 5})
	check("azure brand: a blow sets oil under its target alight", dungeon.oil.is_burning(AHEAD_1))
	dungeon.oil.load_state({"slicks": [], "burning": []})
	dungeon.clear_monsters()

	# A real swing: the slime fears fire and flinches, and the damage is the sword's plus the flame.
	CombatRules.seed_rng(41)
	var hit := false
	var tries := 0
	var slime: Node = null
	while not hit and tries < 30:
		tries += 1
		dungeon.clear_monsters()
		slime = _monster("slime", AHEAD_1, 40)
		slime.move_wait = 999.0
		slime.attack_cooldown = 0.0
		fighter.hands = [ItemStack.of(def, 1), null]
		fighter.cooldown_left = 0.0
		party.act(fighter.slot, 0)
		hit = slime.hp < 40
	check("azure brand: a real swing does at least 7 (5 plus the flame) and the slime recoils from the flame (%d swings)" % tries,
			hit and 40 - slime.hp >= 7 and slime.attack_cooldown >= LightConfig.get_config().recoil_delay)
	# A doused monster hit by the blade takes the fire bonus and burns.
	hit = false
	tries = 0
	var doused: Node = null
	while not hit and tries < 30:
		tries += 1
		dungeon.clear_monsters()
		doused = _monster("skeleton", AHEAD_1, 99)
		doused.add_status(load("res://data/statuses/held.tres"), 30.0, 1)
		doused.add_status(load("res://data/statuses/doused.tres"), 30.0, 1)
		fighter.hands = [ItemStack.of(def, 1), null]
		fighter.cooldown_left = 0.0
		party.act(fighter.slot, 0)
		hit = doused.hp < 99
	check("azure brand: a doused monster struck by it takes the +6 and catches light (%d swings)" % tries, hit and doused.has_status("burning") and not doused.has_status("doused") and 99 - doused.hp >= 13)
	dungeon.clear_monsters()

	# The price: a kill singes the wielder for 1, and never takes them to 0.
	fighter.hp = fighter.def.max_hp
	var before_hp: int = fighter.hp
	var killed := false
	tries = 0
	while not killed and tries < 40:
		tries += 1
		dungeon.clear_monsters()
		_monster("slime", AHEAD_1, 1)
		fighter.cooldown_left = 0.0
		fighter.hands = [ItemStack.of(def, 1), null]
		before_hp = fighter.hp
		party.act(fighter.slot, 0)
		killed = get_nodes_in_group("monsters").is_empty() or get_nodes_in_group("monsters").all(func(m): return m.dying or m.hp <= 0)
	check("azure brand: a kill singes the wielder for 1 HP (%d to %d)" % [before_hp, fighter.hp], killed and fighter.hp == before_hp - 1)
	fighter.hp = 1
	var corpse: Node = _monster("slime", AHEAD_1, 1)
	corpse.hp = 0
	party._item_kill(fighter, fighter.hands[0], corpse)
	check("azure brand: ...and the singe never kills (a hero at 1 HP stays at 1)", fighter.hp == 1 and fighter.is_alive())
	dungeon.clear_monsters()

	# Found: the first time a hero holds it.
	var found_before: int = events.legendary_found.size()
	DungeonMap.flags.erase("legendary.found.%s" % def.resource_path)
	fighter.hands = [ItemStack.of(def, 1), null]
	party._tick_items(0.0)
	check("azure brand: holding it for the first time sends legendary_found once, naming the sword and the fighter",
			events.legendary_found.size() == found_before + 1 and events.legendary_found[-1][0] == def and events.legendary_found[-1][1] == fighter.hero_index)
	party._tick_items(0.0)
	check("azure brand: ...and only once", events.legendary_found.size() == found_before + 1)
	fighter.hands = [null, null]
	_rest_everyone()
	DungeonMap.occupied.clear()
	for name in ["legendary_found", "hero_hurt", "hero_died"]:
		events[name].clear()
	CombatRules.rng().state = dice_state


## True if no pixel of this icon is curse green or bruise purple (a legendary blade is blue and steel only).
func _azure_colours_ok(tex: Texture2D) -> bool:
	var img: Image = tex.get_image()
	var blue := 0
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a > 0.0:
				if c.g > c.r + 0.06 and c.g > c.b + 0.06:
					return false
				if c.b > c.r + 0.2 and c.b > c.g:
					blue += 1
	return blue == 0  # (The blue is the run-time tint and light, ItemDef.glow_tint: legendaries never add colours.)

## The Red Shaman (data/monsters/red_shaman.tres): a goblin caster with a ranged bolt (MonsterDef.ranged_range), built into the monster code.
func _check_red_shaman() -> void:
	var dice_state: int = CombatRules.rng().state  # (The casts below roll the dice: put back at the end, so later checks roll what they always did.)
	_rest_everyone()
	dungeon.clear_monsters()
	party.fight.in_fight = false
	party.god_mode = false
	player.restore(SPOT, EAST)
	await create_timer(0.2).timeout
	var def: Resource = load("res://data/monsters/red_shaman.tres")
	check("shaman: a tier 2 caster with 9 HP that casts from 4 tiles, with a cast animation, a bolt, a sound and a hit effect all present",
			def.tier == 2 and def.max_hp == 9 and def.ranged_range == 4 and def.attack_frames.size() == 7 and def.attack_hit_frame == 3 and def.hframes == 22
			and ResourceLoader.exists("res://art/spells/%s/bolt_sheet.png" % def.bolt_effect) and FileAccess.file_exists("res://art/spells/%s/bolt_sheet.json" % def.bolt_effect)
			and ResourceLoader.exists("res://art/spells/hit_fx/%s_sheet.png" % def.hit_effect) and FileAccess.file_exists("res://audio/sfx/%s.wav" % def.cast_sound))

	# Who can strike from where.
	var shaman: Node = _monster("red_shaman", Vector2i(10, 13))
	var skeleton: Node = _monster("skeleton", Vector2i(9, 13))
	check("shaman: four tiles down the corridor, in line and in sight, it can strike; a skeleton at three tiles cannot", shaman._can_strike() and not skeleton._can_strike())
	dungeon.clear_monsters()
	var far: Node = _monster("red_shaman", Vector2i(11, 13))
	var off: Node = _monster("red_shaman", Vector2i(8, 11))
	check("shaman: five tiles away is out of range, and off the line (two across, two up) is no firing line", not far._can_strike() and not off._can_strike())
	dungeon.clear_monsters()
	player.restore(Vector2i(9, 13), EAST)
	var walled: Node = _monster("red_shaman", Vector2i(9, 10))
	check("shaman: in line and in range, but with a wall between, it cannot strike", not walled._can_strike())
	dungeon.clear_monsters()
	player.restore(SPOT, EAST)
	var goal_ok := true
	var near_shaman: Node = _monster("red_shaman", Vector2i(8, 11))
	var goals: Dictionary = near_shaman._ranged_goals()
	for c in goals:
		var d: Vector2i = c - SPOT
		goal_ok = goal_ok and (d.x == 0 or d.y == 0) and absi(d.x) + absi(d.y) >= 2 and absi(d.x) + absi(d.y) <= 4 and DungeonMap.has_line_of_sight(c, SPOT)
	check("shaman: the tiles it heads for are all in line with the party, two to four away, in sight (%d of them)" % goals.size(), goals.size() >= 3 and goal_ok and goals.has(Vector2i(10, 13)))
	check("shaman: from off the line it walks toward a firing line (west, toward the corridor's end), not at the party", near_shaman._chase_dir() == Vector2i(-1, 0))
	dungeon.clear_monsters()

	# Standing in range it stays put and casts: the bolt flies, then the hit lands.
	shaman = _monster("red_shaman", Vector2i(10, 13))
	shaman.move_wait = 0.0
	shaman._on_tick()
	check("shaman: in range it does not close in", shaman.cell == Vector2i(10, 13))
	CombatRules.seed_rng(97)
	var struck := []
	var on_struck := func(monster: Node, side: String, damage: int, crit: bool): struck.append([monster, side, damage])
	party.monster_struck.connect(on_struck)
	var hurt_before: int = events.hero_hurt.size()
	var bolts_seen := 0
	var blows_before: int = shaman.blows_struck
	for i in 25:
		shaman.attack_cooldown = 0.0
		shaman._attack()
		bolts_seen = maxi(bolts_seen, get_nodes_in_group("monster_bolts").size())
		await create_timer(0.45).timeout
		if not struck.is_empty():
			break
	party.monster_struck.disconnect(on_struck)
	check("shaman: a cast sends a bolt flying (%d in flight), and when it arrives the party is struck from the front (%d casts)" % [bolts_seen, shaman.blows_struck - blows_before],
			bolts_seen >= 1 and not struck.is_empty() and struck[0][0] == shaman and struck[0][1] == "front" and events.hero_hurt.size() > hurt_before)
	await create_timer(0.5).timeout
	check("shaman: the bolt is gone once it has arrived", get_nodes_in_group("monster_bolts").is_empty())

	# A caster killed while its bolt is in the air takes the bolt with it.
	_rest_everyone()
	var hp_total := 0
	for m in party.members:
		hp_total += m.hp
	shaman.attack_cooldown = 0.0
	shaman._attack()
	shaman.dying = true
	await create_timer(0.5).timeout
	var hp_after := 0
	for m in party.members:
		hp_after += m.hp
	check("shaman: if he dies before it arrives, his bolt does no damage", hp_after == hp_total)
	dungeon.clear_monsters()
	DungeonMap.occupied.clear()
	_rest_everyone()
	for name in ["hero_hurt", "hero_died"]:
		events[name].clear()
	CombatRules.rng().state = dice_state

## The Goblin (data/monsters/goblin.tres): tier 1 fodder, a spear jab from the next tile only.
func _check_goblin() -> void:
	_rest_everyone()
	dungeon.clear_monsters()
	player.restore(SPOT, EAST)
	await create_timer(0.2).timeout
	var def: Resource = load("res://data/monsters/goblin.tres")
	check("goblin: tier 1, 6 HP, a melee spear (no ranged attack), with idle, attack, walk and hurt frames and a hit frame inside the attack",
			def.tier == 1 and def.max_hp == 6 and def.ranged_range == 0 and def.hframes == 23 and def.idle_frames.size() > 0 and def.walk_frames.size() == 8
			and def.hurt_frames.size() == 3 and def.attack_frames.size() == 7 and def.attack_hit_frame >= 0 and def.attack_hit_frame < def.attack_frames.size())
	var goblin: Node = _monster("goblin", Vector2i(8, 13))
	check("goblin: two tiles away it cannot strike; next to the party it can", not goblin._can_strike())
	goblin.cell = AHEAD_1
	check("goblin: ...next to the party it can", goblin._can_strike())
	dungeon.clear_monsters()
	DungeonMap.occupied.clear()


## The message log can be scrolled back through: it takes the mouse, shows a bar once it overflows, keeps 200 lines, and a new line does not
## pull a reader who has scrolled up back down.
func _check_log_scroll() -> void:
	var hud: Node = get_first_node_in_group("hud")
	for i in 230:
		hud.show_message("Scroll test line %d." % i)
	await create_timer(0.3).timeout
	var bar: VScrollBar = hud.log_text.get_v_scroll_bar()
	check("log: it keeps the last 200 lines and takes the mouse so it can be scrolled", hud.lines.size() == 200 and hud.log_text.mouse_filter == Control.MOUSE_FILTER_STOP)
	check("log: its scroll bar shows (not hidden) once the text overflows", bar.visible and bar.modulate.a > 0.9 and bar.max_value > bar.page)
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	var before: float = bar.value
	hud.log_text.gui_input.emit(wheel)
	check("log: a wheel tick up scrolls two lines back", is_equal_approx(before - bar.value, hud.WHEEL_STEP))
	var kept: float = bar.value
	hud.show_message("A new line while reading old ones.")
	await create_timer(0.3).timeout
	check("log: a new line does not pull a scrolled-back reader down", is_equal_approx(bar.value, kept))
	bar.value = bar.max_value
	hud.show_message("And one at the bottom.")
	await create_timer(0.3).timeout
	check("log: at the bottom the newest line is followed", bar.value >= bar.max_value - bar.page - 2.0)


## Legendaries never add colours (docs/art_style.md): the Azure Brand's art is plain palette greys, and its blue is a run-time tint on its icons
## and a soft pale light from the item on the floor (ItemDef.glow_tint, glow_light_*).
func _check_item_glow() -> void:
	dungeon.clear_monsters()
	player.restore(SPOT, EAST)
	var palette = JSON.parse_string(FileAccess.get_file_as_string("res://tools/art/palette.json"))
	var names := []
	var allowed := {}
	for c in palette.colors:
		names.append(str(c.name))
		allowed[Color(str(c.hex)).to_html(false)] = true
	check("glow: the palette has no arcane_* (blue) colours, and mustard stays (%d colours)" % names.size(), not names.any(func(n): return n.begins_with("arcane")) and names.has("mustard_500") and names.size() == 33)
	var def: Resource = load("res://data/items/azure_brand.tres")
	var clean := true
	var bluish := 0
	for tex in [def.icon, def.floor_icon, def.hud_icon]:
		var img: Image = tex.get_image()
		for y in img.get_height():
			for x in img.get_width():
				var c: Color = img.get_pixel(x, y)
				if c.a > 0.5:
					clean = clean and allowed.has(c.to_html(false))
					if c.b8 >= c.r8 + 25 and c.b8 >= c.g8 - 20:
						bluish += 1
	check("glow: the Azure Brand's three pictures use only palette colours and have no blue pixel in them (%d)" % bluish, clean and bluish == 0)
	var tinted: Texture2D = def.hud_texture()
	var timg: Image = tinted.get_image()
	var blue_sum := 0.0
	var red_sum := 0.0
	for y in timg.get_height():
		for x in timg.get_width():
			var c: Color = timg.get_pixel(x, y)
			if c.a > 0.5:
				blue_sum += c.b
				red_sum += c.r
	check("glow: its hand and inventory icons are tinted pale blue at run time (a copy, the file untouched), a plain item's are the art itself",
			tinted != def.hud_icon and blue_sum > red_sum * 1.2 and def.shown_icon() != def.icon and def.shown_icon() == def.shown_icon()
			and load("res://data/items/torch.tres").shown_icon() == load("res://data/items/torch.tres").icon)
	dungeon.set_pile(AHEAD_1, [])
	dungeon.place_item(AHEAD_1, ItemStack.of(def, 1))
	var sprite: Node3D = dungeon.items[AHEAD_1].sprite
	var light: Node = sprite.get_node_or_null("GlowLight")
	check("glow: lying on the floor it carries a soft pale blue light in sprite_lights", light is OmniLight3D and light.is_in_group("sprite_lights") and light.light_energy > 0.0
			and light.light_color.b > light.light_color.r)
	await create_timer(0.3).timeout
	check("glow: its floor sprite is tinted blue (the lighting times its tint)", sprite.modulate.b > sprite.modulate.r)
	dungeon.place_item(AHEAD_1, ItemStack.of(load("res://data/items/bread.tres") if ResourceLoader.exists("res://data/items/bread.tres") else load("res://data/items/stale_bread.tres"), 1))
	check("glow: a plain item on top of it hides the glow", dungeon.items[AHEAD_1].sprite.get_node_or_null("GlowLight") == null)
	dungeon.set_pile(AHEAD_1, [])


## Hover text (Godot's own tooltip) uses the project theme data/ui_theme.tres: 8 px text in the game's font, in a dark box with a rust edge.
func _check_tooltip_theme() -> void:
	var theme: Theme = ThemeDB.get_project_theme()
	var box = theme.get_stylebox("panel", "TooltipPanel") if theme != null else null
	check("tooltip: hover text is 8 px in the game's own palette-coloured box (theme data/ui_theme.tres)",
			theme != null and theme.get_font_size("font_size", "TooltipLabel") == 8 and box is StyleBoxFlat and box.border_width_left == 2
			and box.bg_color.is_equal_approx(Color("14131b")) and box.border_color.is_equal_approx(Color("7c4426"))
			and theme.get_color("font_color", "TooltipLabel").is_equal_approx(Color("c9c0a4")))


## The Horned Knight (data/monsters/knight.tres): a slow, heavily armoured tier 2 melee monster with a greatsword chop.
func _check_knight() -> void:
	_rest_everyone()
	dungeon.clear_monsters()
	player.restore(SPOT, EAST)
	await create_timer(0.2).timeout
	var def: Resource = load("res://data/monsters/knight.tres")
	var guard: Resource = load("res://data/monsters/skeleton_guard.tres")
	check("knight: tier 2, 26 HP, defence 5, slower than the skeleton guard, melee only, with idle, attack, walk and hurt frames and a hit frame inside the attack",
			def.tier == 2 and def.max_hp == 26 and def.defence == 5 and def.step_interval > guard.step_interval and def.attack_interval > guard.attack_interval and def.ranged_range == 0
			and def.hframes == 24 and def.idle_frames.size() > 0 and def.walk_frames.size() == 8 and def.hurt_frames.size() == 4 and def.attack_frames.size() == 7
			and def.attack_hit_frame >= 0 and def.attack_hit_frame < def.attack_frames.size())
	var knight: Node = _monster("knight", AHEAD_1)
	check("knight: next to the party it can strike", knight._can_strike())
	dungeon.clear_monsters()
	DungeonMap.occupied.clear()


## The background music: Walen's "Dark Heart", one looping player under the tree root so it survives scene changes.
func _check_music() -> void:
	var audio: Node = get_first_node_in_group("audio")
	await create_timer(0.3).timeout
	var music = audio.music if audio != null else null
	check("music: the background track plays on the Music bus from one player under the tree root, looping, and keeps playing while paused",
			music != null and music.playing and music.get_parent() == root and music.name == "BackgroundMusic" and music.bus == "Music"
			and music.stream is AudioStreamMP3 and music.stream.loop and music.process_mode == Node.PROCESS_MODE_ALWAYS)
	var again: Node = load("res://scripts/audio.gd").new()
	root.add_child(again)  # A second Audio node (the next scene's) must adopt the player, not start another.
	await create_timer(0.1).timeout
	check("music: a second scene's Audio node adopts the same player and does not restart it", again.music == music and music.playing and root.get_children().filter(func(n): return n.name == "BackgroundMusic").size() == 1)
	again.free()



func _check_curse_look() -> void:
	dungeon.clear_monsters()
	var real_zones: Array = DungeonMap.CURSE_ZONES
	var tiles := [Vector2i(8, 13), Vector2i(9, 13), Vector2i(10, 13), Vector2i(11, 13), Vector2i(12, 13)]
	DungeonMap.CURSE_ZONES = [{"id": "look_zone", "tiles": tiles}]
	var curse: Node = dungeon.curse
	var c: Resource = LightConfig.get_config()
	curse.pocket_left = 0.0
	curse.zones_changed()
	check("look: a fresh zone's fog has not crept in yet, and the edge tiles are the first to fill",
			curse.creep == 0.0 and curse._haze.all(func(h): return not h.mesh.visible))
	curse._animate_haze(c.fog_creep_seconds * 0.3)
	var edge_size: float = 0.0
	var middle_size: float = 0.0
	for h in curse._haze:
		if h.cell == Vector2i(8, 13):
			edge_size = h.mesh.scale.x if h.mesh.visible else 0.0
		elif h.cell == Vector2i(10, 13):
			middle_size = h.mesh.scale.x if h.mesh.visible else 0.0
	check("look: a third of the way in, the zone's edge is fogged and its middle is not (%.2f, %.2f)" % [edge_size, middle_size], edge_size > 0.5 and middle_size < edge_size)
	curse._animate_haze(c.fog_creep_seconds)
	check("look: given its time every tile is fogged", curse.creep == 1.0 and curse._haze.all(func(h): return h.mesh.visible and h.mesh.scale.x > 0.99))

	# The edge glow: slow and thickening in the dark.
	curse.vignette = 0.0
	curse.dark_time = 0.0
	curse._tick_glow(1.0, true, false)
	var first: float = curse.vignette
	for i in 5:
		curse._tick_glow(1.0, true, false)
	var later: float = curse.vignette
	check("look: the glow creeps in slowly (%.2f after 1 s, %.2f after 6)" % [first, later], first > 0.0 and first < 0.4 and later > first)
	curse._tick_glow(40.0, true, false)
	curse._tick_glow(10.0, true, false)
	check("look: and the longer the party stays dark the thicker it gets (%.2f)" % curse.vignette, curse.vignette > later and curse.vignette > 0.95)
	var steady: float = curse.vignette
	var was_reduced: bool = Settings.reduce_flashing
	Settings.reduce_flashing = false
	curse._clock = 1.0 / (4.0 * c.vignette_pulse_hz)  # The deepest dip of the slow breath.
	var pulsed: float = curse.glow_level()
	Settings.reduce_flashing = true
	var calm: float = curse.glow_level()
	Settings.reduce_flashing = was_reduced
	check("look: it breathes gently, and with Reduce flashing it is a steady vignette (%.2f vs %.2f)" % [pulsed, calm], is_equal_approx(calm, steady) and pulsed < calm and calm - pulsed <= c.vignette_pulse + 0.001)

	# A Bless: the fog recoils from the pocket, the glow pulls back, and both creep back over the last seconds.
	var spot := Vector2i(10, 13)
	curse.open_pocket(spot, 20.0)
	curse._tick_glow(1.0, true, true)
	curse._animate_haze(c.fog_recoil_seconds + 0.1)
	var pocket_fog_gone := true
	var outside_fog := false
	for h in curse._haze:
		if absi(h.cell.x - spot.x) <= c.zone_pocket_radius:
			pocket_fog_gone = pocket_fog_gone and not h.mesh.visible
		else:
			outside_fog = outside_fog or h.mesh.visible
	check("look: a Bless pushes the fog off the pocket's tiles and pulls the glow back", pocket_fog_gone and outside_fog and curse.vignette == 0.0 and curse.fog_pocket == 0.0)
	curse.pocket_left = c.pocket_warn_seconds * 0.5
	curse._animate_haze(3.0)
	curse._tick_glow(6.0, true, true)
	check("look: over the pocket's last seconds the fog and the glow creep back as a warning (%.2f, %.2f)" % [curse.fog_pocket, curse.vignette],
			curse.fog_pocket > 0.3 and curse.fog_pocket < 1.0 and curse.vignette > 0.1 and curse.vignette <= c.vignette_warn + 0.001)
	curse.pocket_left = 0.0
	curse._animate_haze(c.fog_return_seconds + 0.1)
	check("look: when the pocket ends the fog is all back", curse.fog_pocket == 1.0 and curse._haze.all(func(h): return h.mesh.visible))
	curse._tick_glow(20.0, false, false)
	check("look: leaving the zone clears the glow", curse.vignette == 0.0)

	# A flame that dies leaves a wisp that goes after a while.
	var wisps_before: int = curse._wisps.size()
	curse.flame_died(Vector2i(9, 13))
	check("look: a flame dying in the zone leaves a wisp of fog, and it is gone after its time", curse._wisps.size() == wisps_before + 1)
	curse._tick_wisps(c.wisp_seconds + 0.1)
	check("look: ...gone", curse._wisps.size() == wisps_before)
	var vignette_node: Node = get_first_node_in_group("curse_vignette")
	check("look: the screen-edge glow node is in the game", vignette_node != null and vignette_node.layer == 2)

	DungeonMap.CURSE_ZONES = real_zones
	curse.zones_changed()
	curse.creep = 1.0
	curse.dark_time = 0.0
	curse.vignette = 0.0
	curse.fog_pocket = 1.0
	curse.pocket_left = 0.0
	player.restore(SPOT, EAST)


## Wall sconces (7l.2): three kinds on floor 1, lit by a flame in a hero's hand (right click) or a Fireball, the torch taken with an
## empty hand and hung back in a bracket with its time kept, and that torches are never made: lighting a sconce and taking its torch
## back cannot be repeated for free.
func _check_sconces() -> void:
	var torch: Resource = load("res://data/items/torch.tres")
	var candle: Resource = load("res://data/items/candle.tres")
	var cursor: Node = get_first_node_in_group("cursor")
	cursor.release()
	dungeon.clear_monsters()
	var kinds := {0: 0, 1: 0, 2: 0}
	for key in dungeon.sconces:
		kinds[dungeon.sconce_at(key)] += 1
	check("sconces: floor 1 has 8 lit, 7 unlit with a torch and 10 empty brackets (%s)" % str(kinds), kinds == {0: 8, 1: 7, 2: 10})
	var unlit := Vector3i(12, 14, 1)
	var empty := Vector3i(12, 9, 1)
	var lit := Vector3i(3, 7, 0)
	check("sconces: a torch the level starts in a sconce has 120 s on it, a bare bracket none", is_equal_approx(dungeon.sconce_time(unlit), 120.0)
			and is_equal_approx(dungeon.sconce_time(lit), 120.0) and dungeon.sconce_time(empty) == 0.0)
	check("sconces: a lit one has a light and the animated flame, an unlit one and an empty one have a still picture and no light",
			dungeon.sconces[lit].light != null and dungeon.sconces[lit].sprite is AnimatedSprite3D
			and dungeon.sconces[unlit].light == null and dungeon.sconces[unlit].sprite is Sprite3D
			and dungeon.sconces[empty].light == null and dungeon.sconces[empty].sprite is Sprite3D)

	# No hero holds anything for now. (Put back at the end.)
	var held_before := []
	for m in party.members:
		held_before.append(m.hands.duplicate())
		m.hands = [null, null]
	var fighter = party.members[party.formation.find(1)]
	var n0 := _torches_in_the_game()
	var t0 := _torch_seconds()

	# Lighting needs a flame, and makes no torch.
	DungeonMap.sconce_seen.clear()
	player.restore(Vector2i(12, 14), 1)  # Facing the unlit sconce's wall.
	check("sconces: the party has seen it from where it stands (the map shows it), and not the far ones",
			DungeonMap.sconce_seen.has(unlit) and not DungeonMap.sconce_seen.has(Vector3i(20, 22, 3)))
	player.world_right_click()
	check("sconces: with nothing lit in a hand it stays dark", dungeon.sconce_at(unlit) == DungeonMap.SCONCE_UNLIT)
	var flame: RefCounted = ItemStack.of(torch, 1)
	fighter.hands[1] = flame
	player.world_right_click()
	check("sconces: a lit torch in a hand lights it, and the torch stays in the hand",
			dungeon.sconce_at(unlit) == DungeonMap.SCONCE_LIT and fighter.hands[1] == flame and flame.count == 1 and dungeon.sconces[unlit].light != null)
	check("sconces: lighting one made no torch and used no time (%d torches, %.0f s in the game)" % [_torches_in_the_game(), _torch_seconds()],
			_torches_in_the_game() == n0 + 1 and is_equal_approx(_torch_seconds(), t0 + flame.seconds_left()))
	player.world_right_click()
	check("sconces: a burning one is already burning", dungeon.sconce_at(unlit) == DungeonMap.SCONCE_LIT)
	fighter.hands[1] = null

	# Taking the torch: an empty hand gets it with 120 s, the bracket is bare and the stretch goes dark.
	player.world_click()
	var taken: RefCounted = cursor.held
	check("sconces: an empty hand takes the torch out of a lit one: 120 s on it, the bracket bare, its light gone",
			taken != null and taken.def == torch and is_equal_approx(taken.seconds_left(), 120.0) and dungeon.sconce_at(unlit) == DungeonMap.SCONCE_EMPTY
			and dungeon.sconces[unlit].light == null)
	check("sconces: light it and take its torch back and the game holds exactly what it did (%d torches, %.0f s)" % [_torches_in_the_game(), _torch_seconds()],
			_torches_in_the_game() == n0 and is_equal_approx(_torch_seconds(), t0))
	cursor.release()
	player.world_click()
	fighter.hands[1] = ItemStack.of(torch, 1)
	player.world_right_click()
	fighter.hands[1] = null
	check("sconces: a bare bracket gives nothing when clicked and a flame does not relight it: the trick cannot be repeated for free (%d torches, the taken one in hand)" % _torches_in_the_game(),
			cursor.held == null and dungeon.sconce_at(unlit) == DungeonMap.SCONCE_EMPTY and _torches_in_the_game() == n0 - 1
			and is_equal_approx(_torch_seconds(), t0 - taken.seconds_left()))
	cursor.hold(taken)

	# Hanging a torch back: it lights the stretch for good, keeping its time, and loses none while it hangs.
	player.world_click()
	check("sconces: a torch from the cursor goes into the empty bracket and lights it, keeping its 120 s",
			cursor.held == null and dungeon.sconce_at(unlit) == DungeonMap.SCONCE_LIT and is_equal_approx(dungeon.sconce_time(unlit), 120.0)
			and dungeon.sconces[unlit].light != null and _torches_in_the_game() == n0 and is_equal_approx(_torch_seconds(), t0))
	await create_timer(0.6).timeout
	check("sconces: it loses no time while it hangs there", is_equal_approx(dungeon.sconce_time(unlit), 120.0) and is_equal_approx(_torch_seconds(), t0))
	player.world_click()
	check("sconces: taken out again it has that same time", cursor.held != null and is_equal_approx(cursor.held.seconds_left(), 120.0))
	for round_ in 5:  # Round and round: nothing is gained or lost.
		player.world_click()  # Hang it.
		player.world_click()  # Take it.
	check("sconces: five more rounds of hanging and taking change nothing (%d torches, %.0f s)" % [_torches_in_the_game(), _torch_seconds()],
			_torches_in_the_game() == n0 and is_equal_approx(_torch_seconds(), t0) and cursor.held != null and is_equal_approx(cursor.held.seconds_left(), 120.0))
	player.world_click()  # Hang it again: it lights the stretch.
	check("sconces: and it ends lit", dungeon.sconce_at(unlit) == DungeonMap.SCONCE_LIT and cursor.held == null)

	# A torch with a different time keeps it; a candle does not fit; a taken bracket is taken.
	var used: RefCounted = ItemStack.of(torch, 1)
	used.burn_left = 77.0
	cursor.hold(used)
	player.restore(Vector2i(12, 9), 1)
	player.world_click()
	check("sconces: a torch with 77 s left hung in a bare bracket keeps its 77 s", dungeon.sconce_at(empty) == DungeonMap.SCONCE_LIT and is_equal_approx(dungeon.sconce_time(empty), 77.0) and cursor.held == null)
	player.world_click()
	check("sconces: and comes out with 77 s", cursor.held != null and is_equal_approx(cursor.held.seconds_left(), 77.0))
	cursor.release()
	cursor.hold(ItemStack.of(candle, 1))
	player.restore(Vector2i(14, 11), 2)
	player.world_click()
	check("sconces: a candle does not fit a bracket, and is not lost", dungeon.sconce_at(Vector3i(14, 11, 2)) == DungeonMap.SCONCE_EMPTY and cursor.held != null and cursor.held.def == candle)
	cursor.release()
	cursor.hold(ItemStack.of(torch, 1))
	player.restore(Vector2i(3, 7), 0)
	player.world_click()
	check("sconces: a bracket that already holds a torch takes no second one", dungeon.sconce_at(lit) == DungeonMap.SCONCE_LIT and cursor.held != null and cursor.held.count == 1)
	cursor.release()

	for i in party.members.size():
		party.members[i].hands = held_before[i]

	# A Fireball cast at an unlit sconce at the end of the corridor lights it.
	var fire_at := Vector3i(14, 15, 0)  # Unlit, on the north wall of (14,15).
	player.restore(Vector2i(14, 15), 0)
	var count_before := _torches_in_the_game()
	check("sconces: setup: that one is unlit", dungeon.sconce_at(fire_at) == DungeonMap.SCONCE_UNLIT)
	var r := _cast("fireball")
	await create_timer(1.2).timeout
	check("sconces: a Fireball cast at an unlit sconce lights it, costs its mana and makes no torch",
			r.cast and _spent_right(r) and dungeon.sconce_at(fire_at) == DungeonMap.SCONCE_LIT and dungeon.sconces[fire_at].light != null and _torches_in_the_game() == count_before)
	player.restore(Vector2i(3, 7), 0)
	r = _cast("fireball")
	check("sconces: a Fireball at a wall with a lit sconce has nothing to target and costs nothing", not r.cast)


## Puzzles listen to the event bus (S7): any event re-checks them. The real puzzle is covered with the world events; here a made-up
## table checks conditions with memory (levers pulled in order, kept in the run flags), a flag condition, a chain (one puzzle's effect
## makes another true in the same check) and that a puzzle fires once. Levers are not really pulled (the state the later checks
## expect stays), only the news that they were is sent.
func _check_puzzles() -> void:
	var real_puzzles: Array = DungeonMap.PUZZLES
	var a := {"cell": Vector2i(19, 7), "side": 0}
	var b := {"cell": Vector2i(20, 5), "side": 3}
	DungeonMap.PUZZLES = [
		{"id": "smoke_order", "when": [{"kind": "lever_order", "levers": [a, b]}], "then": [{"kind": "set_flag", "name": "smoke.order", "value": true}]},
		{"id": "smoke_chain", "when": [{"kind": "flag", "name": "smoke.order"}], "then": [{"kind": "set_flag", "name": "smoke.chain", "value": 7}]},
	]
	var pulled := func(lever: Dictionary):
		root.get_node("GameEvents").lever_pulled.emit(lever.cell, lever.side, true)
	var solved_before: int = events.get("puzzle_solved", []).size()
	pulled.call(b)
	pulled.call(a)
	pulled.call(a)  # (Starting over: a pulled twice is a first pull again.)
	check("puzzles: levers pulled in the wrong order do not solve it", not DungeonMap.puzzles_done.has("smoke_order") and DungeonMap.flag("puzzle.smoke_order.step") == 1)
	pulled.call(b)
	check("puzzles: pulled in order they do, from the event alone, and the progress is a run flag", DungeonMap.puzzles_done.has("smoke_order") and DungeonMap.flag("smoke.order", false) == true
			and DungeonMap.flag("puzzle.smoke_order.step") == 2)
	check("puzzles: one puzzle's effect makes another true in the same check (a chain)", DungeonMap.puzzles_done.has("smoke_chain") and DungeonMap.flag("smoke.chain") == 7)
	check("puzzles: each fired once, and puzzle_solved was sent for each", events.get("puzzle_solved", []).size() == solved_before + 2)
	pulled.call(a)
	pulled.call(b)
	check("puzzles: a solved puzzle does not fire again", events.get("puzzle_solved", []).size() == solved_before + 2)
	# Any event re-checks: a flag set by hand and then any news at all.
	DungeonMap.PUZZLES = [{"id": "smoke_any", "when": [{"kind": "flag", "name": "smoke.go"}], "then": [{"kind": "set_flag", "name": "smoke.went"}]}]
	DungeonMap.set_flag("smoke.go", true)
	check("puzzles: a flag alone does nothing until some news arrives", not DungeonMap.puzzles_done.has("smoke_any"))
	root.get_node("GameEvents").fight_ended.emit()
	check("puzzles: any event at all re-checks them", DungeonMap.puzzles_done.has("smoke_any") and DungeonMap.flag("smoke.went", false) == true)
	DungeonMap.PUZZLES = real_puzzles
	for id in ["smoke_order", "smoke_chain", "smoke_any"]:
		DungeonMap.puzzles_done.erase(id)
	for flag_name in ["puzzle.smoke_order.step", "smoke.order", "smoke.chain", "smoke.go", "smoke.went"]:
		DungeonMap.flags.erase(flag_name)
	check("puzzles: the real puzzle is back in place and still done", DungeonMap.PUZZLES.size() == 2 and DungeonMap.puzzles_done.has("nook_blessing"))


## The shockwave: a Fireball explosion starts a ring (a Magic Missile impact a smaller one) that is gone after shock_seconds; Reduce flashing (with
## shock_reduced_scale 0) starts none.
func _check_shockwave() -> void:
	dungeon.clear_monsters()
	player.restore(SPOT, EAST)
	var wave: Node = root.find_child("Shockwave", true, false)
	var fx: Node = get_first_node_in_group("spell_effects")
	check("shockwave: the layer is in the dungeon view", wave != null and wave.get_viewport() is SubViewport)
	if wave == null or fx == null:
		return
	var before: int = wave.started
	fx.explosion(SPOT + Vector2i(2, 0))
	check("shockwave: a Fireball explosion starts one", wave.started == before + 1 and wave.rect.visible)
	await create_timer(SpellEffectsConfig.get_config().shock_seconds + 0.15).timeout
	check("shockwave: it is over after shock_seconds", wave.waves.is_empty() and not wave.rect.visible)
	before = wave.started
	fx._missile_impact(SPOT + Vector2i(2, 0))
	var c: Resource = SpellEffectsConfig.get_config()
	check("shockwave: a Magic Missile impact starts a smaller one", wave.started == before + 1 and wave.waves.size() > 0 			and wave.waves[-1].strength < c.shock_strength and wave.waves[-1].size < 1.0)
	await create_timer(c.shock_seconds + 0.15).timeout
	Settings.reduce_flashing = true
	before = wave.started
	fx.explosion(SPOT + Vector2i(2, 0))
	check("shockwave: none with Reduce flashing", wave.started == before)
	Settings.reduce_flashing = false


func _check_rat() -> void:
	_rest_everyone()
	dungeon.clear_monsters()
	player.restore(SPOT, EAST)
	var def: Resource = load("res://data/monsters/plague_rat.tres")
	check("rat: tier 1, 5 HP, attack 2, defence 1, bites for 1-3", def.tier == 1 and def.max_hp == 5 and def.attack == 2 and def.defence == 1 			and def.damage_min == 1 and def.damage_max == 3)
	check("rat: a blow every 1.4 s, a step every 0.7 s, fears fire", is_equal_approx(def.attack_interval, 1.4) and is_equal_approx(def.step_interval, 0.7) and def.fears_fire)
	var nest: Array = DungeonMap.MONSTERS.filter(func(e): return e.def == "res://data/monsters/plague_rat.tres").map(func(e): return e.cell)
	check("rat: three nest in the cave, and no skeleton stands at (9,18)", nest.size() == 3 and Vector2i(8, 17) in nest 			and DungeonMap.MONSTERS.filter(func(e): return e.cell == Vector2i(9, 18)).is_empty())
	check("rat: its bite effect sheet exists", load("res://art/spells/hit_fx/rat_bite_sheet.png") != null and def.hit_effect == "rat_bite")
	# A bite: 20% of landed blows leave the food sickness (6 HP over 6 s).
	var rat: Node = _monster("plague_rat", AHEAD_1)
	rat.move_wait = 999.0
	rat.attack_cooldown = 999.0
	var landed := 0
	var sick := 0
	var sick_ok := true
	var shown := false
	for i in 400:
		_rest_everyone()
		var before: int = _total_hp()
		party.take_hit_from(rat)
		if _total_hp() < before:
			landed += 1
			for m in party.members:
				if m.sick_left > 0.0:
					sick += 1
					sick_ok = sick_ok and is_equal_approx(m.sick_left, 6.0) and is_equal_approx(m.sick_rate, 1.0)
			shown = shown or get_first_node_in_group("hud").lines.any(func(l): return str(l.text).contains("The bite festers"))
	check("rat: about one landed bite in five makes a hero sick (%d of %d)" % [sick, landed], landed > 100 and float(sick) / landed > 0.12 and float(sick) / landed < 0.28)
	check("rat: a sick bite gives 6 HP over 6 s, and the log says so", sick_ok and shown)
	_rest_everyone()
	var tough: Node = _monster("skeleton", AHEAD_2)
	var plain := 0
	for i in 100:
		_rest_everyone()
		tough.move_wait = 999.0
		party.take_hit_from(tough)
		for m in party.members:
			plain += 1 if m.sick_left > 0.0 else 0
	check("rat: no other monster's bite makes anyone sick", plain == 0)
	dungeon.clear_monsters()
	# What it leaves: raw rat meat, 40% of the time.
	var meat: Resource = load("res://data/items/raw_rat_meat.tres")
	check("rat: it drops raw rat meat 40% of the time", def.drop_item == meat and is_equal_approx(def.drop_chance, 0.4))
	var drops := 0
	for i in 150:
		var r: Node = _monster("plague_rat", AHEAD_1)
		r.move_wait = 999.0
		r._drop_loot()
		if dungeon.item_at(AHEAD_1) != null:
			drops += 1
		dungeon.set_pile(AHEAD_1, [])
		dungeon.clear_monsters()
	check("rat: the drops come about 40%% of the time (%d of 150)" % drops, drops > 40 and drops < 80)
	# The meat: 6 HP over 6 s, and half the time the food sickness.
	check("meat: 6 HP over 6 s, 50% sickness of 6 HP over 6 s", meat.food_heal == 6 and is_equal_approx(meat.food_seconds, 6.0) and is_equal_approx(meat.food_sick_chance, 0.5) 			and meat.food_sick_damage == 6 and is_equal_approx(meat.food_sick_seconds, 6.0))
	var sick_eats := 0
	for i in 200:
		_rest_everyone()
		var eater = party.members[0]
		eater.hp = eater.def.max_hp - 10
		party.eat(0, meat)
		sick_eats += 1 if eater.sick_left > 0.0 else 0
	check("meat: eaten raw it makes half the eaters sick (%d of 200)" % sick_eats, sick_eats > 70 and sick_eats < 130)
	_rest_everyone()
	await create_timer(0.1).timeout


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

## Replace the save file's contents (a test of damaged files).
func _write_save(text: String) -> void:
	var f := FileAccess.open(SaveGame.path, FileAccess.WRITE)
	f.store_string(text)
	f.close()


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
	# Added since the code review: the Warden (greeted already, held), a plague rat (held), a hero's food and sickness running,
	# torch and candle burn times, and a torch lying lit on the floor.
	var warden: Node = _monster("warden", Vector2i(8, 13), 41)
	warden._boss_seen = true
	warden.add_status(load("res://data/statuses/held.tres"), 4.0, 1)
	var rat: Node = _monster("plague_rat", Vector2i(12, 13), 2)
	rat.add_status(load("res://data/statuses/held.tres"), 4.0, 0)
	var sick = party.members[party.formation.find(1)]
	sick.food_left = 5.0
	sick.food_rate = 2.0
	sick.sick_left = 4.0
	sick.sick_rate = 1.5
	var torch: Resource = load("res://data/items/torch.tres")
	var candle: Resource = load("res://data/items/candle.tres")
	var torch_holder = null
	for m in party.members:
		for stack in m.hands:
			if stack != null and stack.def == torch:
				stack.burn_left = 123.0
				torch_holder = m
	var candle_stack: RefCounted = ItemStack.of(candle, 1)
	candle_stack.burn_left = 40.0
	var candle_holder = party.members[party.formation.find(2)]
	candle_holder.backpack[5] = candle_stack
	var floor_torch: RefCounted = ItemStack.of(torch, 1)
	floor_torch.burn_left = 77.0
	dungeon.place_item(Vector2i(12, 13), floor_torch)
	dungeon.lights.drop(Vector2i(12, 13), floor_torch)

	# Sconces: one emptied, a torch with 77 s hung in another bracket, one seen and one not.
	var torch_def: Resource = load("res://data/items/torch.tres")
	dungeon.take_sconce_torch(Vector3i(6, 11, 1), torch_def)
	var used_torch: RefCounted = ItemStack.of(torch_def, 1)
	used_torch.burn_left = 77.0
	dungeon.hang_sconce_torch(Vector3i(19, 3, 0), used_torch)
	DungeonMap.sconce_seen.clear()
	DungeonMap.sconce_seen[Vector3i(19, 3, 0)] = true

	# Oil: a slick, a tile burning (4 s left), a doused monster and a hero's oiled weapon.
	dungeon.oil.load_state({"slicks": [], "burning": []})
	dungeon.oil.add_slick(Vector2i(7, 13))
	dungeon.oil.add_slick(Vector2i(10, 13))
	dungeon.oil.ignite(Vector2i(10, 13))
	dungeon.oil.burning[Vector2i(10, 13)].left = 4.0
	DungeonMap.occupied.get(CLOSETS[0]).add_status(load("res://data/statuses/doused.tres"), 20.0, 2)
	for m in party.members:
		if m.class_id() == "fighter":
			m.oiled_hits = 2

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
	check("load: monsters (kind, cell, hp)", loaded.monsters == saved.monsters and saved.monsters.size() == 4)
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

	# What was added after the code review survives too.
	var warden_back = DungeonMap.occupied.get(Vector2i(8, 13))
	check("load: the Warden is back with his hit points, held, and does not greet the party again",
			warden_back != null and warden_back.def.boss and warden_back.hp == 41 and warden_back.has_status("held") and warden_back._boss_seen)
	var rat_back = DungeonMap.occupied.get(Vector2i(12, 13))
	check("load: a plague rat is back with its hit points, held", rat_back != null and rat_back.def.resource_path == "res://data/monsters/plague_rat.tres"
			and rat_back.hp == 2 and rat_back.has_status("held") and rat_back.statuses.held.source == 0)
	var sick_back = party.members[party.formation.find(1)]
	check("load: a hero's food and sickness are still running",
			sick_back.food_left > 3.0 and is_equal_approx(sick_back.food_rate, 2.0) and sick_back.sick_left > 2.0 and is_equal_approx(sick_back.sick_rate, 1.5))
	var held_torch: RefCounted = null
	for m in party.members:
		for stack in m.hands:
			if stack != null and stack.def == torch:
				held_torch = stack
	check("load: a held torch keeps its burn time (%.1f s left)" % (held_torch.burn_left if held_torch else -1.0),
			held_torch != null and held_torch.burn_left > 115.0 and held_torch.burn_left <= 123.0)
	var candle_back: RefCounted = party.members[party.formation.find(2)].backpack[5]
	check("load: a candle in a backpack keeps its burn time, unlit", candle_back != null and candle_back.def == candle and is_equal_approx(candle_back.burn_left, 40.0) and not candle_back.burning)
	var lying: RefCounted = null
	for stack in dungeon.items[Vector2i(12, 13)].pile:
		if stack.def == torch:
			lying = stack
	check("load: a torch lying lit on the floor still burns there, with its time left (%.1f s)" % (lying.burn_left if lying else -1.0),
			lying != null and lying.burning and lying.burn_left > 60.0 and lying.burn_left <= 77.0 and dungeon.lights.burning.size() == 1)
	check("load: a taken sconce is still bare, a hung torch still lights its stretch with its 77 s, the lights are rebuilt, and what was seen stays seen",
			dungeon.sconce_at(Vector3i(6, 11, 1)) == DungeonMap.SCONCE_EMPTY and dungeon.sconces[Vector3i(6, 11, 1)].light == null
			and dungeon.sconce_at(Vector3i(19, 3, 0)) == DungeonMap.SCONCE_LIT and is_equal_approx(dungeon.sconce_time(Vector3i(19, 3, 0)), 77.0)
			and dungeon.sconces[Vector3i(19, 3, 0)].light != null and dungeon.sconce_at(Vector3i(12, 9, 1)) == DungeonMap.SCONCE_EMPTY
			and DungeonMap.sconce_seen.has(Vector3i(19, 3, 0)) and not DungeonMap.sconce_seen.has(Vector3i(20, 22, 3)))
	var doused_back = DungeonMap.occupied.get(CLOSETS[0])
	var oiled_back := 0
	for m in party.members:
		if m.class_id() == "fighter":
			oiled_back = m.oiled_hits
	check("load: a slick (still about 2 minutes), a burning tile (a few seconds left, lit, flames), a doused monster and an oiled weapon all come back",
			dungeon.oil.has_slick(Vector2i(7, 13)) and dungeon.oil.slicks[Vector2i(7, 13)].left > 50.0 and dungeon.oil.is_burning(Vector2i(10, 13))
			and dungeon.oil.burning[Vector2i(10, 13)].left > 0.0 and dungeon.oil.burning[Vector2i(10, 13)].left <= 4.0 and dungeon.oil.burning[Vector2i(10, 13)].light.is_in_group("sprite_lights")
			and doused_back != null and doused_back.has_status("doused") and doused_back.status_left("doused") > 10.0 and oiled_back == 2)
	var level_text := FileAccess.get_file_as_string(SaveGame.path)
	var written = JSON.parse_string(level_text)
	check("the save stores the level id too (floor_1)", written is Dictionary and written.get("level_id") == DungeonMap.FLOOR_1_ID)
	var no_id: Dictionary = written.duplicate(true)
	no_id.erase("level_id")
	var other_id: Dictionary = written.duplicate(true)
	other_id["level_id"] = "seed:9"
	check("a save without a level id (an older one) is accepted, and one naming a level this game cannot build is refused",
			SaveGame.validate(no_id, party.members.size()) == "" and SaveGame.validate(other_id, party.members.size()) != "")
	check("the save stores its version and level path", written is Dictionary and int(written.version) == SaveGame.VERSION and written.level == DungeonMap.level_path
			and written.cursor is Dictionary and written.cursor.has("held"))

	# A bad file is refused cleanly and changes nothing.
	var good_text := level_text
	party.members[0].hp = 3
	var monsters_before: int = get_nodes_in_group("monsters").size()
	_write_save(good_text.substr(0, good_text.length() / 2))  # Cut off half way, as a crash while writing would leave it.
	var read: Dictionary = SaveGame.read_file()
	check("a truncated save file is refused with a message", read.has("error") and str(read.error) != "")
	error = SaveGame.load_game(self)
	await process_frame
	check("loading a truncated file refuses, leaves nothing pending and does not reload the game",
			error != "" and SaveGame.pending.is_empty() and get_first_node_in_group("party") == party and party.members[0].hp == 3)
	var missing_parts := []
	for part in [["party"], ["player"], ["dungeon"], ["cursor"], ["party", "heroes"], ["party", "formation"], ["dungeon", "monsters"], ["dungeon", "items"], ["dungeon", "levers"]]:
		var broken: Dictionary = JSON.parse_string(good_text)
		var holder: Dictionary = broken
		for i in part.size() - 1:
			holder = holder[part[i]]
		holder.erase(part[part.size() - 1])
		_write_save(JSON.stringify(broken))
		var refused: bool = SaveGame.read_file().has("error") and SaveGame.apply(self, broken) != ""
		if not refused:
			missing_parts.append("/".join(part))
	check("a file missing a key is refused by read_file and apply (not refused: %s)" % str(missing_parts), missing_parts.is_empty())
	var wrong: Dictionary = JSON.parse_string(good_text)
	wrong.party.heroes[2].hp = "lots"
	error = SaveGame.apply(self, wrong)
	check("a file with a wrong kind of value is refused", error != "")
	var half_bad: Dictionary = JSON.parse_string(good_text)  # The party part is fine, the dungeon part is not: nothing loads at all.
	half_bad.party.heroes[0].hp = 9
	half_bad.dungeon.monsters[0].erase("cell")
	error = SaveGame.apply(self, half_bad)
	check("a bad dungeon part stops the good party part loading too (nothing changed)", error != "" and party.members[0].hp == 3
			and get_nodes_in_group("monsters").size() == monsters_before)
	var newer: Dictionary = JSON.parse_string(good_text)
	newer.version = 99
	_write_save(JSON.stringify(newer))
	check("a save from a newer version is refused", SaveGame.read_file().has("error"))
	# A version 1 save (no level, the cursor's stack bare) still loads.
	var old: Dictionary = JSON.parse_string(good_text)
	old.version = 1
	old.erase("level")
	old.cursor = old.cursor.held
	_write_save(JSON.stringify(old))
	var old_read: Dictionary = SaveGame.read_file()
	check("a version 1 save is accepted and brought up to date", not old_read.has("error") and int(old_read.version) == SaveGame.VERSION
			and old_read.level == "" and old_read.cursor is Dictionary and old_read.cursor.has("held"))
	party.members[0].hp = 3
	error = SaveGame.apply(self, old_read)
	check("a version 1 save applies", error == "" and party.members[0].hp != 3 and DungeonMap.occupied.get(Vector2i(8, 13)) != null)
	_write_save(good_text)

	# A save from before run flags existed has no "flags": it loads, with none set.
	var old_save: Dictionary = SaveGame.read_file()
	old_save.erase("flags")
	DungeonMap.set_flag("smoke.stale", true)
	error = SaveGame.apply(self, old_save)
	check("an older save without flags loads, with no flags set", error == "" and DungeonMap.flags.is_empty())
	old_save.dungeon.erase("sconces")  # A save from before sconces: every wall torch was burning then.
	error = SaveGame.apply(self, old_save)
	var all_lit := true
	for key in dungeon.sconces:
		all_lit = all_lit and dungeon.sconce_at(key) == DungeonMap.SCONCE_LIT and dungeon.sconces[key].light != null
	check("an older save without sconces loads with every wall torch lit", error == "" and all_lit)
