extends SceneTree
## Checks the test room's level data and debug tools. Run: timeout 120 "$G" --headless --path . -s tests/test_room_test.gd

const DungeonMap := preload("res://scripts/dungeon_map.gd")
const Settings := preload("res://scripts/settings.gd")
const DIRS := [Vector2i(0, -1), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(1, 0)]
var fails := 0


func check(name: String, ok: bool) -> void:
	print(("PASS " if ok else "FAIL ") + name)
	if not ok:
		fails += 1


func _init() -> void:
	DungeonMap.use_level(DungeonMap.TEST_ROOM_PATH)
	_check_data()
	DungeonMap.use_level("")
	check("floor 1 comes back", DungeonMap.MAP.size() == 25 and DungeonMap.START_TILE == Vector2i(5, 9) and DungeonMap.SIGNS.is_empty() and DungeonMap.MONSTERS.size() == 15)
	DungeonMap.use_level(DungeonMap.TEST_ROOM_PATH)
	await _check_game()
	DungeonMap.use_level("")
	print("DONE fails=", fails)
	quit(fails)


func _check_data() -> void:
	var map: Array = DungeonMap.MAP
	check("start is floor", not DungeonMap.is_blocked(DungeonMap.START_TILE))
	# Every station can be walked to from the start (doors count as passable; cracked and corrupted walls stay shut).
	var seen := {DungeonMap.START_TILE: true}
	var todo := [DungeonMap.START_TILE]
	while not todo.is_empty():
		var c: Vector2i = todo.pop_back()
		for d in DIRS:
			var n: Vector2i = c + d
			if not seen.has(n) and not DungeonMap.is_wall(n):
				seen[n] = true
				todo.append(n)
	var stations_ok := DungeonMap.STATIONS.size() >= 9
	for st in DungeonMap.STATIONS:
		stations_ok = stations_ok and seen.has(st.cell)
	check("every station is reachable", stations_ok)
	var items_ok := true
	for e in DungeonMap.ITEMS:
		items_ok = items_ok and load(e.def) != null and seen.has(e.cell)
	check("all items load and can be reached", items_ok)
	var every := true
	var dir := DirAccess.open("res://data/items")
	for f in dir.get_files():
		if f.ends_with(".tres"):
			var found := false
			for e in DungeonMap.ITEMS:
				found = found or e.def.ends_with("/" + f)
			every = every and found
	check("one of every item is on the table", every)
	var mons_ok := true
	for e in DungeonMap.MONSTERS:
		mons_ok = mons_ok and load(e.def) != null and seen.has(e.cell)
	check("monsters load and stand on floor", mons_ok)
	var corr_ok := true
	var types := {}
	for z in map.size():
		for x in map[z].size():
			types[map[z][x]] = true
			if map[z][x] == 7:
				corr_ok = corr_ok and DungeonMap.CORRUPTION.has(Vector2i(x, z))
	check("corrupted walls have entries", corr_ok)
	check("a wall of each type (normal, destructible, corrupted)", types.has(1) and types.has(6) and types.has(7))
	var signs_ok := true
	for s in DungeonMap.SIGNS:
		signs_ok = signs_ok and seen.has(s.cell) and DungeonMap.is_wall(s.cell + DIRS[s.side])
	check("every sign stands on floor with a wall behind", signs_ok)
	var torch_ok := true
	for t in DungeonMap.TORCHES:
		torch_ok = torch_ok and seen.has(Vector2i(t.x, t.y)) and DungeonMap.is_wall(Vector2i(t.x, t.y) + DIRS[t.z])
	check("every torch hangs on a wall", torch_ok)
	var amb_ok := true
	for a in DungeonMap.AMBUSHES:
		amb_ok = amb_ok and seen.has(a.trigger)
		for m in a.monsters:
			amb_ok = amb_ok and seen.has(m.cell) and load(m.def) != null
	check("ambush tile and spawns are floor", amb_ok)
	check("an arch to test shadows against", DungeonMap.STRUCTURES.any(func(e): return e.kind == "arch" and seen.has(e.cell)))
	check("puzzle door has a plate and a lever", DungeonMap.DOOR_IDS.values().has("puzzle_door") and DungeonMap.PLATES.size() == 1 and DungeonMap.LEVERS.size() == 1)


## The monster pacing station: its tuning keys, the pack, and flanking (one monster at a time, only after being held back).
func _check_pacing(tools: Node, press: Callable, player: Node) -> void:
	for n in get_nodes_in_group("monsters"):
		n.free()
	var skel: Resource = load("res://data/monsters/skeleton.tres")
	var step0: float = skel.step_interval
	var react0: float = skel.reaction_delay
	tools.tune_index = 0
	press.call(KEY_BRACKETRIGHT)
	check("] raises every monster's step interval", is_equal_approx(skel.step_interval, step0 + 0.1))
	press.call(KEY_O)
	press.call(KEY_BRACKETLEFT)
	check("O then [ lowers the reaction delay", is_equal_approx(skel.reaction_delay, maxf(0.0, react0 - 0.1)))
	tools._refresh_help()
	check("the help shows the pacing table", tools.help_label.text.contains("MONSTER PACING") and tools.help_label.text.contains("SKELETON"))
	press.call(KEY_Y)
	check("Y puts the pacing back from the files", is_equal_approx(skel.step_interval, step0) and is_equal_approx(skel.reaction_delay, react0))
	var station: Dictionary = DungeonMap.STATIONS.filter(func(s): return s.name == "Monster pacing")[0]
	tools._teleport(station)
	press.call(KEY_I)
	check("I spawns a pack of three ahead", get_nodes_in_group("monsters").size() == 3)
	for n in get_nodes_in_group("monsters"):
		n.free()
	# Flanking, in the open arena: the party faces north with a skeleton in front and two more coming from the sides.
	var dungeon: Node = get_first_node_in_group("dungeon")
	player.restore(Vector2i(6, 6), 0)
	var lead: Node = dungeon.spawn_monster(skel, Vector2i(6, 5))
	var second: Node = dungeon.spawn_monster(skel, Vector2i(8, 6))
	var third: Node = dungeon.spawn_monster(skel, Vector2i(4, 6))
	for m in [lead, second, third]:
		m.move_wait = 999.0  # Their own clocks are stopped: the test moves them.
	var beside := func(m: Node) -> bool:
		var d: Vector2i = m.cell - player.cell
		return absi(d.x) + absi(d.y) == 1
	for i in 4:
		second.held_back = 0.0
		second._on_tick()
		third.held_back = 0.0
		third._on_tick()
	check("monsters queue behind the one at the party instead of going round (%s, %s)" % [second.cell, third.cell],
			not beside.call(second) and not beside.call(third))
	for i in 3:
		second.held_back = skel.flank_after + 0.1
		second._on_tick()
	check("after being held back a while one may go round to the party's side (%s)" % second.cell, beside.call(second) and second._has_pass())
	for i in 3:
		third.held_back = 99.0
		third._on_tick()
	check("only one monster at a time goes round (%s)" % third.cell, not beside.call(third))
	for n in get_nodes_in_group("monsters"):
		n.free()
	# The traps station: a bear trap already armed, and one to pick up.
	var traps_room: Dictionary = DungeonMap.STATIONS.filter(func(s): return s.name == "Traps")[0]
	tools._teleport(traps_room)
	var trap_field: Node = get_first_node_in_group("traps")
	check("the traps station has an armed bear trap", trap_field != null and trap_field.armed_at(Vector2i(34, 20)) != null)
	# The held-monster room: 9 holds the monster in front, 0 frees it.
	var held_room: Dictionary = DungeonMap.STATIONS.filter(func(s): return s.name == "Held monster")[0]
	tools._teleport(held_room)
	tools._spawn("res://data/monsters/skeleton.tres")
	var target: Node = get_nodes_in_group("monsters")[0]
	press.call(KEY_9)
	check("9 holds the monster in front", target.has_status("held"))
	press.call(KEY_0)
	check("0 frees every held monster", not target.has_status("held"))
	for n in get_nodes_in_group("monsters"):
		n.free()
	var fight: Node = get_first_node_in_group("party").fight
	var waited := 0.0
	while fight.in_fight and waited < 8.0:  # Let the fight these monsters started end, so later checks start calm.
		await create_timer(0.25).timeout
		waited += 0.25


func _check_game() -> void:
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await create_timer(0.8).timeout
	var tools: Node = null
	for c in scene.get_children():
		if c.get_script() != null and str(c.get_script().resource_path).ends_with("test_room_tools.gd"):
			tools = c
	check("tools are added in a debug build", tools != null)
	if tools == null:
		return
	var party: Node = get_first_node_in_group("party")
	var player: Node = get_first_node_in_group("player")
	var dungeon: Node = get_first_node_in_group("dungeon")
	var in_packs := {}
	for m in party.members:
		for st in m.backpack:
			if st != null:
				in_packs[st.def.resource_path.get_file()] = true
	var all_items := Array(DirAccess.open("res://data/items").get_files()).filter(func(f): return f.ends_with(".tres"))
	var missing := all_items.filter(func(f): return not in_packs.has(f))
	check("every item is in the backpacks on arrival (%d items, missing: %s)" % [all_items.size(), missing], missing.is_empty())
	var signs := 0
	for n in dungeon.get_children():
		if n.name.begins_with("Sign_"):
			signs += 1
	check("signs are built", signs == DungeonMap.SIGNS.size())
	check("player starts at the hall", player.cell == Vector2i(20, 14))
	check("monsters are in the arena and the held-monster room", get_nodes_in_group("monsters").size() == DungeonMap.MONSTERS.size())

	var press := func(code: Key):
		var e := InputEventKey.new()
		e.pressed = true
		e.keycode = code
		tools._unhandled_input(e)
	press.call(KEY_H)
	check("H shows the help", tools.help.visible)
	check("the help shows the fight state", tools.help_label.text.contains("FIGHT  OFF"))
	press.call(KEY_H)
	check("H hides it again", not tools.help.visible)
	press.call(KEY_G)
	check("G god mode", party.god_mode)
	var m0 = get_nodes_in_group("monsters")[0]
	var hp0 := 0
	for m in party.members:
		hp0 += m.hp
	for i in 30:
		party.take_hit_from(m0)
	var hp1 := 0
	for m in party.members:
		hp1 += m.hp
	check("god mode: hits land on nobody", hp1 == hp0)
	press.call(KEY_G)
	party.members[0].hp = 1
	party.members[0].mana = 0.0
	press.call(KEY_R)
	check("R refills HP and mana", party.members[0].hp == party.members[0].def.max_hp and party.members[0].mana == float(party.members[0].def.max_mana))
	press.call(KEY_Z)
	check("Z kills all monsters", get_nodes_in_group("monsters").size() == 0)
	tools._spawn("res://data/monsters/slime.tres")
	check("V spawns a monster in front", get_nodes_in_group("monsters").size() == 1)
	tools._open_spawn_list()
	var popups: Node = get_first_node_in_group("popups")
	check("the spawn list opens on the pop-up layer", popups.open_count == 1 and is_instance_valid(tools.menu) and tools.menu.get_parent() == popups)
	var labels := []
	for b in tools.menu.find_children("*", "Button", true, false):
		labels.append(b.text)
	check("the spawn list shows each monster's tier (%s)" % ", ".join(labels), labels.has("SKELETON  T1") and labels.has("SKELETON GUARD  T2"))
	press.call(KEY_ESCAPE)
	await process_frame
	await process_frame
	check("Escape closes it", popups.open_count == 0)
	tools._open_teleport_list()
	check("the teleport list opens", popups.open_count == 1)
	tools._close_menu()
	await process_frame
	await process_frame
	var st: Dictionary = DungeonMap.STATIONS[5]
	tools._teleport(st)
	check("T teleports to a station", player.cell == st.cell and player.facing == st.facing)
	press.call(KEY_B)
	check("B switches banter off", not get_first_node_in_group("banter").enabled)
	tools._refresh_help()
	check("the help shows banter off", tools.help_label.text.contains("BANTER        OFF"))
	press.call(KEY_B)
	get_first_node_in_group("banter").set_quiet("test room check")
	tools._refresh_help()
	check("the help shows banter quiet and why", tools.help_label.text.contains("QUIET (test room check)"))
	get_first_node_in_group("banter").set_quiet("test room check", false)
	press.call(KEY_J)
	check("J switches screen shake off", not load("res://data/combat_feel.tres").screen_shake_enabled)
	press.call(KEY_J)
	var fog_before: bool = Settings.fog
	press.call(KEY_N)
	check("N toggles fog without touching the saved setting", tools.fog_on != fog_before and Settings.fog == fog_before)
	await _check_pacing(tools, press, player)
	press.call(KEY_X)
	press.call(KEY_U)
	# The ambush: walk onto the trigger.
	for n in get_nodes_in_group("monsters"):
		n.free()
	var banter: Node = get_first_node_in_group("banter")
	banter.reset_timers()
	banter.said.clear()
	player.restore(Vector2i(3, 17), 2)  # Within 6 tiles of the trigger: the warning.
	await create_timer(0.2).timeout
	check("the ambush gives its warning on the way in", banter.said == ["Brother Felix: I smell evil."])
	player.restore(Vector2i(3, 21), 2)
	await create_timer(0.1).timeout
	player.restore(Vector2i(3, 22), 2)
	await create_timer(0.2).timeout
	check("the ambush tile spawns its monsters", get_nodes_in_group("monsters").size() == 2)
	check("the ambush keeps banter quiet", banter.is_quiet() and tools.ambush_active)
	check("...but the battle cry gets through", banter.said.size() >= 2 and banter.said[1] == "Brother Felix: I did say!")
	await create_timer(1.0).timeout
	check("...and its answer", banter.said.has("Brannoc: Shut up, cleric!") and not banter.said.has("Brannoc: Shut up."))
	for n in get_nodes_in_group("monsters"):
		n.free()  # The fight is over once it has been quiet for a moment: banter may speak, and the Cleric remarks on the Fighter.
	var said_before: int = banter.said.size()
	var waited := 0.0
	while tools.ambush_active and waited < 8.0:
		await create_timer(0.25).timeout
		waited += 0.25
	check("when the ambush's fight is over banter is let speak again", not tools.ambush_active and not banter.is_quiet())
	check("...with the Cleric's grudging remark", banter.said.size() > said_before and (str(banter.said[-1]).contains("not so bad with a sword") or str(banter.said[-1]).contains("adequate")))
	for m in party.members:  # (Empty the stocked packs: the checks below count the stones and arrows in them.)
		for i in m.backpack.size():
			m.backpack[i] = null
	# The slingshot: fires a stone from the backpack at the first monster in line, spends it, needs ammo.
	for n in get_nodes_in_group("monsters"):
		n.free()
	player.restore(Vector2i(20, 14), 3)
	var sling: Resource = load("res://data/items/slingshot.tres")
	var stone: Resource = load("res://data/items/stone.tres")
	var hero = party.members[0]
	hero.hands[0] = preload("res://scripts/item_stack.gd").of(sling, 1)
	hero.backpack[0] = preload("res://scripts/item_stack.gd").of(stone, 3)
	hero.cooldown_left = 0.0
	check("a slingshot is fired, not swung", party.action_for(0, 0) == party.Act.FIRE)
	var target = get_first_node_in_group("dungeon").spawn_monster(load("res://data/monsters/skeleton.tres"), Vector2i(22, 14))
	var hp_before: int = target.hp
	party.act(0, 0)
	check("a shot spends one stone", hero.backpack[0].count == 2)
	check("a shot starts the cooldown", hero.cooldown_left > 0.0)
	hero.backpack[0].count = 40  # Enough that misses cannot decide the test.
	for i in 40:
		hero.cooldown_left = 0.0
		if not is_instance_valid(target) or target.dying or target.hp < hp_before:
			break
		party.act(0, 0)
	check("shots hurt the monster ahead", not is_instance_valid(target) or target.hp < hp_before or target.dying)
	hero.backpack[0].count = 1
	hero.cooldown_left = 0.0
	party.act(0, 0)
	check("the stones run out", hero.backpack[0] == null)
	hero.cooldown_left = 0.0
	party.act(0, 0)
	check("no stones, no shot, no cooldown", hero.cooldown_left == 0.0)
	# The bow shoots arrows, not stones: stones in the pack are no use to it.
	hero.hands[0] = preload("res://scripts/item_stack.gd").of(load("res://data/items/bow.tres"), 1)
	hero.backpack[0] = preload("res://scripts/item_stack.gd").of(stone, 2)
	hero.cooldown_left = 0.0
	party.act(0, 0)
	check("a bow does not shoot stones", hero.backpack[0].count == 2 and hero.cooldown_left == 0.0)
	hero.backpack[0] = preload("res://scripts/item_stack.gd").of(load("res://data/items/arrow.tres"), 2)
	party.act(0, 0)
	check("a bow shoots an arrow", hero.backpack[0].count == 1 and hero.cooldown_left > 0.0)
	hero.hands[0] = null
	hero.backpack[0] = null
	var shadows_before: bool = Settings.spell_shadows
	press.call(KEY_P)
	check("P toggles every shadow light", Settings.spell_shadows != shadows_before and get_nodes_in_group("shadow_lights").size() > 0 and get_nodes_in_group("shadow_lights").all(func(l): return l.shadow_enabled == Settings.spell_shadows))
	press.call(KEY_P)
	check("a test-room save is refused", preload("res://scripts/save_game.gd").save(self) != "")
