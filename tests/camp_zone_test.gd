extends SceneTree
## The safe campfire zone (a Hearth Coal's trip, scripts/camp_zone.gd). Run: timeout 120 "$G" --headless --path . -s tests/camp_zone_test.gd
## A real scene change both ways: floor 1 -> the zone -> the exact tile, facing and monsters left behind.

const DungeonMap := preload("res://scripts/dungeon_map.gd")
const Settings := preload("res://scripts/settings.gd")
const SaveGame := preload("res://scripts/save_game.gd")
const RunState := preload("res://scripts/run_state.gd")
const CampZone := preload("res://scripts/camp_zone.gd")
const COAL := "res://data/items/hearth_coal.tres"
var fails := 0


func check(name: String, ok: bool) -> void:
	print(("PASS " if ok else "FAIL ") + name)
	if not ok:
		fails += 1


func _init() -> void:
	Settings.path = "user://camp_zone_test_settings.cfg"
	Settings.loaded = true
	SaveGame.path = "user://camp_zone_test_save.json"
	DungeonMap.use_level("")
	RunState.clear()
	CampZone.snapshot = {}
	var coal: Resource = load(COAL)
	check("the Hearth Coal is a consumable that opens the camp zone", coal != null and coal.opens_camp_zone and coal.type == 2)
	check("floor 1 holds exactly one Hearth Coal", _coals_on_floor_1() == 1)
	var zone: Dictionary = load(CampZone.ZONE_PATH).get_script_constant_map()
	check("the zone level has a fire, no monsters and a start on floor", zone.MONSTERS.is_empty() and zone.STRUCTURES.size() == 1 and zone.STRUCTURES[0].kind == "campfire" and zone.MAP[zone.START_TILE.y][zone.START_TILE.x] == 0)

	var scene: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	await create_timer(0.8).timeout
	var party := get_first_node_in_group("party")
	var player := get_first_node_in_group("player")
	var dungeon := get_first_node_in_group("dungeon")
	# Floor 1 has 23 monsters and no tile is out of sight of all of them: keep one (a skeleton at the far dead end) and rest at the other end.
	dungeon.clear_monsters()
	var kept: Node = dungeon.spawn_monster(load("res://data/monsters/skeleton.tres"), Vector2i(20, 22), 2)
	var spot := Vector2i(6, 7)
	player.restore(spot, 3)
	check("the party may rest here", party.camp_refusal() == "")
	var monsters_before := get_nodes_in_group("monsters").size()
	party.members[1].hp = 3

	var result: Dictionary = party.use_item(0, coal)
	check("using the coal is accepted and closes the inventory", result.used and result.close)
	await create_timer(1.2).timeout
	check("the party is in the safe zone", CampZone.in_zone() and DungeonMap.level_id == CampZone.ZONE_PATH)
	player = get_first_node_in_group("player")
	party = get_first_node_in_group("party")
	check("they stand at the zone's start facing the fire, with no monsters", player.cell == zone.START_TILE and player.facing == zone.START_FACING and get_nodes_in_group("monsters").is_empty() and get_nodes_in_group("camp_sites").size() == 1)
	check("the zone cannot be saved", SaveGame.save(self) == "This level can't be saved.")
	check("the coal will not work inside the zone", party.use_item(0, coal).used == false)
	party.members[1].hp = 7   # Rested (or fed) at camp: what they leave with.
	var fire_menu: Node = null
	player.world_click()
	await process_frame
	fire_menu = player.last_campfire_menu
	check("the fire's pop-up has BREAK CAMP here", fire_menu != null and fire_menu.break_button != null)
	check("BREAK CAMP takes the party back", fire_menu.break_camp())
	await create_timer(1.2).timeout
	check("floor 1 is back, not the zone", not CampZone.in_zone() and DungeonMap.level_id == DungeonMap.FLOOR_1_ID)
	player = get_first_node_in_group("player")
	party = get_first_node_in_group("party")
	check("the party is on the exact tile, facing as before", player.cell == spot and player.facing == 3)
	check("the monsters are as they were", get_nodes_in_group("monsters").size() == monsters_before and get_nodes_in_group("monsters")[0].hp == 2)
	check("the party comes back as it is now (a hero rested at camp)", party.members[1].hp == 7)
	check("nothing waits to be applied", SaveGame.pending.is_empty() and CampZone.snapshot.is_empty() and not RunState.has())
	DungeonMap.use_level("")
	print("DONE fails=", fails)
	quit(fails)


func _coals_on_floor_1() -> int:
	var n := 0
	for e in DungeonMap.ITEMS:
		if str(e.def) == COAL:
			n += int(e.get("count", 1))
	return n
