extends SceneTree
## Smoke test of floor 1: the things every refactor must keep working (docs/code_review.md, step 0).
## Run: timeout 120 "$G" --headless --path . -s tests/smoke_test.gd      (exit code = number of failed checks)
##
## Combat, the five spells, food, resurrection, and a save and load round trip. The combat dice are seeded. It uses its
## own settings and save files, so a real save is never touched. It changes run state directly (hp, mana, cooldowns,
## where monsters stand) to set each check up; it never changes game code or data.

const DungeonMap := preload("res://scripts/dungeon_map.gd")
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

var fails := 0
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

	dungeon.clear_monsters()
	player.restore(SPOT, EAST)
	_check_kill()
	_check_monster_hit()
	_check_spells()
	await _check_food()
	_check_resurrection()
	await _check_save_load()
	_finish()


func _finish() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	print("DONE fails=", fails)
	quit(fails)


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
	var front_only := true  # A monster in front reaches the front row (positions 0 and 1) only.
	for m in party.members:
		if m.slot >= 2 and m.hp < m.def.max_hp:
			front_only = false
	check("a monster in front hurts the front row only", front_only)
	dungeon.clear_monsters()


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


# --------------------------------------------------------------------------
# Food and resurrection
# --------------------------------------------------------------------------

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
	dungeon.open_door(PLAIN_DOOR)
	dungeon.pull_lever(Vector2i(LEVER.x, LEVER.y), LEVER.z)
	await create_timer(2.0).timeout  # The door slides for 0.6 s, the portcullis for 1.5 s.
	check("setup: a door is open and a lever is on", DungeonMap.open_doors.has(PLAIN_DOOR) and dungeon.lever_on.get(LEVER, false))
	party.swap_positions(0, 2)
	var potion: Resource = load("res://data/items/healing_potion.tres")
	var stone: Resource = load("res://data/items/stone.tres")
	party.add_to_backpack(1, ItemStack.of(potion, 3))
	party.add_to_backpack(3, ItemStack.of(stone, 7))
	dungeon.place_item(Vector2i(10, 13), ItemStack.of(stone, 4))
	dungeon.take_item(Vector2i(6, 10))  # The short sword in front of the start is gone.
	var n := 0
	for m in party.members:
		m.hp = maxi(1, m.def.max_hp - 3 - 2 * n)
		m.mana = minf(float(m.def.max_mana), 2.0 + n)
		n += 1
	player.restore(Vector2i(9, 13), 1)
	_monster("slime", CLOSETS[0], 3)
	_monster("skeleton_guard", CLOSETS[1], 5)

	var saved := _snapshot()
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
	for key in ["formation", "hp", "items", "doors", "levers", "piles", "monsters"]:
		if loaded[key] != saved[key]:
			print("  ", key, " saved:  ", saved[key])
			print("  ", key, " loaded: ", loaded[key])
