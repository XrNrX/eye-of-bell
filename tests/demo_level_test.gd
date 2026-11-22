extends SceneTree
## Demo level 1 (levels/demo_1.gd, made by tools/level/gen_demo_1.py from mapBell.png). Run: timeout 120 "$G" --headless --path . -s tests/demo_level_test.gd
## The data (shape, start, stairs, every file named exists, nothing in a wall), the level finishable through its levers and keys (the editor's own
## checker), the balance table (monsters by distance from the start), then a real game on it: the party stands on the start, can be saved and loaded.

const DungeonMap := preload("res://scripts/dungeon_map.gd")
const Settings := preload("res://scripts/settings.gd")
const SaveGame := preload("res://scripts/save_game.gd")
const EditorGrid := preload("res://scripts/debug/editor_grid.gd")
const EditorCheck := preload("res://scripts/debug/editor_check.gd")
const LevelIntro := preload("res://scripts/level_intro.gd")
const DIRS := [Vector2i(0, -1), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(1, 0)]
const TIER_COST := {1: 3.5, 2: 11.0, 3: 30.0}   # % of the party's HP a fair fight costs (docs/design/expansion_design.md, section 2).
var fails := 0


func check(name: String, ok: bool) -> void:
	print(("PASS " if ok else "FAIL ") + name)
	if not ok:
		fails += 1


func _init() -> void:
	Settings.path = "user://demo_level_test_settings.cfg"
	Settings.loaded = true
	SaveGame.path = "user://demo_level_test_save.json"
	DungeonMap.use_level(DungeonMap.DEMO_1_PATH)
	_check_data()
	_check_finishable()
	_check_balance()
	await _check_game()
	DungeonMap.use_level("")
	DirAccess.remove_absolute(SaveGame.path)
	print("DONE fails=", fails)
	quit(fails)


func _check_data() -> void:
	var map: Array = DungeonMap.MAP
	check("the map is 35 by 35", map.size() == 35 and map.all(func(row): return row.size() == 35))
	check("the outer edge is all wall", map[0].all(func(v): return v == 1) and map[34].all(func(v): return v == 1) and map.all(func(row): return row[0] == 1 and row[34] == 1))
	check("the start is floor and the level is the demo's", not DungeonMap.is_blocked(DungeonMap.START_TILE) and DungeonMap.level_id == DungeonMap.DEMO_1_PATH and DungeonMap.level_saveable())
	var stairs := 0
	var locked := 0
	var gates := 0
	for row in map:
		for v in row:
			stairs += 1 if v == 4 else 0
			locked += 1 if v == 3 else 0
			gates += 1 if v == 5 else 0
	check("two stairs squares, two locked doors, sixteen portcullises", stairs == 2 and locked == 2 and gates == 16)
	check("every portcullis has an id and a lever linked to it", DungeonMap.DOOR_IDS.size() == gates and DungeonMap.LEVERS.size() == gates)
	var levers_ok := true
	for lv in DungeonMap.LEVERS:
		var cell: Vector2i = lv.cell
		var wall: Vector2i = cell + DIRS[int(lv.side)]
		levers_ok = levers_ok and DungeonMap.MAP[cell.y][cell.x] == 0 and DungeonMap.MAP[wall.y][wall.x] == 1 and DungeonMap.DOOR_IDS.values().has(lv.target)
	check("every lever hangs on a wall beside a floor square", levers_ok)
	var sconces_ok := true
	for t in DungeonMap.TORCHES:
		var wall: Vector2i = Vector2i(t.x, t.y) + DIRS[t.z]
		sconces_ok = sconces_ok and DungeonMap.MAP[t.y][t.x] == 0 and DungeonMap.MAP[wall.y][wall.x] == 1
	check("every sconce hangs on a wall beside a floor square", sconces_ok and DungeonMap.TORCHES.size() >= 30)
	var files_ok := true
	var spots_ok := true
	var seen := {}
	for e in DungeonMap.MONSTERS + DungeonMap.ITEMS:
		files_ok = files_ok and ResourceLoader.exists(e.def)
		var c: Vector2i = e.cell
		spots_ok = spots_ok and DungeonMap.MAP[c.y][c.x] == 0
	for m in DungeonMap.MONSTERS:
		spots_ok = spots_ok and not seen.has(m.cell)
		seen[m.cell] = true
	check("every monster and item file exists", files_ok)
	check("everything stands on floor and no two monsters share a square", spots_ok)


func _check_finishable() -> void:
	var g := EditorGrid.new()
	g.load_level({"MAP": DungeonMap.MAP, "START_TILE": DungeonMap.START_TILE, "START_FACING": DungeonMap.START_FACING, "DOOR_IDS": DungeonMap.DOOR_IDS,
			"LEVERS": DungeonMap.LEVERS, "ITEMS": DungeonMap.ITEMS, "MONSTERS": DungeonMap.MONSTERS, "TORCHES": DungeonMap.TORCHES})
	var problems: Array = EditorCheck.run(g)
	for p in problems:
		print("  ", p.level, ": ", p.text)
	check("the editor's checker finds nothing wrong: the stairs, every room, item and monster can be reached through the levers and keys", problems.is_empty())
	var keys := 0
	for it in DungeonMap.ITEMS:
		keys += 1 if str(it.def).ends_with("/key.tres") else 0
	check("three keys for two locked doors (one is a spare)", keys == 3)
	var coals := 0
	for it in DungeonMap.ITEMS:
		coals += int(it.get("count", 1)) if str(it.def).ends_with("/hearth_coal.tres") else 0
	check("one Hearth Coal on the level", coals == 1)
	check("the campfire is there", DungeonMap.STRUCTURES.any(func(s): return s.kind == "campfire"))


## Distance from the start by the walk through the doors, with the gates and locked doors shut (what a party can reach before any lever or key).
func _distances() -> Dictionary:
	var dist := {DungeonMap.START_TILE: 0}
	var queue: Array = [DungeonMap.START_TILE]
	while not queue.is_empty():
		var a: Vector2i = queue.pop_front()
		for d in DIRS:
			var n: Vector2i = a + d
			if dist.has(n) or n.y < 0 or n.y >= 35 or n.x < 0 or n.x >= 35:
				continue
			if DungeonMap.MAP[n.y][n.x] in [0, 2, 4]:
				dist[n] = dist[a] + 1
				queue.append(n)
	return dist


func _check_balance() -> void:
	var dist := _distances()
	var near_cost := 0.0   # Monsters within 25 steps of the start on foot.
	var total := 0.0
	var tier3_far := true
	var warden_ok := false
	var near_tier2 := 0
	for m in DungeonMap.MONSTERS:
		var def: Resource = load(m.def)
		var d: int = dist.get(m.cell, 999)
		var cost: float = TIER_COST.get(int(def.tier), 3.5)
		total += cost
		if d <= 25:
			near_cost += cost
			near_tier2 += 1 if int(def.tier) >= 2 else 0
		if int(def.tier) >= 3:
			tier3_far = tier3_far and d == 999
			warden_ok = warden_ok or m.cell == Vector2i(16, 1)
	var heal := 0
	for it in DungeonMap.ITEMS:
		if str(it.def).ends_with("/healing_potion.tres"):
			heal += int(it.get("count", 1))
	print("  monsters ", DungeonMap.MONSTERS.size(), ", fight cost if all fought ", int(total), "%, within 25 steps of the start on foot ", int(near_cost), "%, healing potions ", heal)
	check("40 to 60 monsters", DungeonMap.MONSTERS.size() >= 40 and DungeonMap.MONSTERS.size() <= 60)
	check("the start is gentle: nothing above tier 1 within 25 steps on foot and under 25% of the party's HP of fighting", near_tier2 == 0 and near_cost < 25.0)
	check("the Cursed Warden stands in the corridor before the stairs, behind the locked door", tier3_far and warden_ok)
	check("the total fight cost stays between 200% and 450% of the party's HP", total >= 200.0 and total <= 450.0)
	check("healing keeps up: the potions' worth of HP is at least the whole fight cost", heal * 10.0 >= total * 0.86)


func _check_game() -> void:
	LevelIntro.pending_for = DungeonMap.DEMO_1_PATH   # As the menu's DEMO LEVEL button leaves it: the level opens with its intro card.
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	await create_timer(1.0).timeout
	var card := get_first_node_in_group("level_intro")
	check("the demo opens with its intro card, and the game is held still behind it", card != null and paused and LevelIntro.pending_for == "")
	if card != null:
		check("the card has a title, three narrator lines and a goal, each short", card.lines.size() == 4 and card.data.title == "DEMO LEVEL 1" and card.data.lines.all(func(l): return l.length() <= 70))
		await create_timer(card.times[0] + 1.0).timeout
		check("the first line has appeared by then and the last has not", card.lines[0].modulate.a > 0.0 and card.lines[3].modulate.a == 0.0)
		var key := InputEventKey.new()
		key.keycode = KEY_SPACE
		key.physical_keycode = KEY_SPACE
		key.pressed = true
		root.push_input(key, true)
		check("a key press starts it fading out", card.leaving)
		await create_timer(LevelIntro.FADE_OUT + 0.4).timeout
		check("the card is gone and the game runs again", not is_instance_valid(card) and not paused)
	check("a loaded game or a new floor shows no intro", not LevelIntro.take(DungeonMap.DEMO_1_PATH))
	var party := get_first_node_in_group("party")
	var player := get_first_node_in_group("player")
	check("the demo builds: four heroes, the party on the start, every monster in", party != null and party.members.size() == 4 and player.cell == DungeonMap.START_TILE and get_nodes_in_group("monsters").size() == DungeonMap.MONSTERS.size())
	check("the camp site is built", get_nodes_in_group("camp_sites").size() == 1)
	check("the demo level can be saved", SaveGame.save(self) == "" and SaveGame.has_save())
	var data := SaveGame.read_file()
	check("and the save names the demo level", not data.has("error") and str(data.get("level_id", "")) == DungeonMap.DEMO_1_PATH)
	check("a door lies in front of the start", player.cell + DIRS[player.facing] == Vector2i(2, 25) and DungeonMap.is_door(Vector2i(2, 25)))
	var dungeon := get_first_node_in_group("dungeon")
	check("every lever is built on the wall", dungeon.levers.size() == DungeonMap.LEVERS.size())
	var closed_before := 0
	for gate in DungeonMap.DOOR_IDS:
		closed_before += 0 if DungeonMap.open_doors.has(gate) else 1
	for lv in DungeonMap.LEVERS:
		dungeon.pull_lever(lv.cell, int(lv.side))
	await create_timer(2.2).timeout
	var open_after := 0
	for gate in DungeonMap.DOOR_IDS:
		open_after += 1 if DungeonMap.open_doors.has(gate) else 0
	check("the portcullises start shut and the sixteen levers raise them all", closed_before == 16 and open_after == 16)
	check("the walk from the start to the stairs exists with the levers pulled and the locked doors open", _walk_to_stairs())


## Is there a walk from the start to a stairs square through open ground, doors, raised gates and locked doors (keys assumed found)?
func _walk_to_stairs() -> bool:
	var seen := {DungeonMap.START_TILE: true}
	var queue: Array = [DungeonMap.START_TILE]
	while not queue.is_empty():
		var a: Vector2i = queue.pop_front()
		if DungeonMap.is_stairs(a):
			return true
		for d in DIRS:
			var n: Vector2i = a + d
			if seen.has(n) or n.y < 0 or n.y >= 35 or n.x < 0 or n.x >= 35:
				continue
			if DungeonMap.MAP[n.y][n.x] != 1:
				seen[n] = true
				queue.append(n)
	return false
