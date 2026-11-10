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
	var signs := 0
	for n in dungeon.get_children():
		if n.name.begins_with("Sign_"):
			signs += 1
	check("signs are built", signs == DungeonMap.SIGNS.size())
	check("player starts at the hall", player.cell == Vector2i(20, 14))
	check("monsters are in the arena", get_nodes_in_group("monsters").size() == 4)

	var press := func(code: Key):
		var e := InputEventKey.new()
		e.pressed = true
		e.keycode = code
		tools._unhandled_input(e)
	press.call(KEY_H)
	check("H shows the help", tools.help.visible)
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
	press.call(KEY_B)
	press.call(KEY_J)
	check("J switches screen shake off", not load("res://data/combat_feel.tres").screen_shake_enabled)
	press.call(KEY_J)
	var fog_before: bool = Settings.fog
	press.call(KEY_N)
	check("N toggles fog without touching the saved setting", tools.fog_on != fog_before and Settings.fog == fog_before)
	press.call(KEY_X)
	press.call(KEY_U)
	# The ambush: walk onto the trigger.
	for n in get_nodes_in_group("monsters"):
		n.free()
	player.restore(Vector2i(3, 21), 2)
	await create_timer(0.1).timeout
	player.restore(Vector2i(3, 22), 2)
	await create_timer(0.2).timeout
	check("the ambush tile spawns its monsters", get_nodes_in_group("monsters").size() == 2)
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
	for i in 12:
		hero.cooldown_left = 0.0
		if hero.backpack[0] == null:
			break
		party.act(0, 0)
	check("shots hurt the monster ahead", not is_instance_valid(target) or target.hp < hp_before or target.dying)
	check("the stones run out", hero.backpack[0] == null)
	hero.cooldown_left = 0.0
	party.act(0, 0)
	check("no stones, no shot, no cooldown", hero.cooldown_left == 0.0)
	hero.hands[0] = null
	var shadows_before: bool = Settings.spell_shadows
	press.call(KEY_P)
	check("P toggles every shadow light", Settings.spell_shadows != shadows_before and get_nodes_in_group("shadow_lights").size() > 0 and get_nodes_in_group("shadow_lights").all(func(l): return l.shadow_enabled == Settings.spell_shadows))
	press.call(KEY_P)
	check("a test-room save is refused", preload("res://scripts/save_game.gd").save(self) != "")
