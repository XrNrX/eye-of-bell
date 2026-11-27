extends SceneTree
## Checks the test room's level data and debug tools. Run: timeout 120 "$G" --headless --path . -s tests/test_room_test.gd

const DungeonMap := preload("res://scripts/dungeon_map.gd")
const Settings := preload("res://scripts/settings.gd")
const ItemDef := preload("res://scripts/item_def.gd")
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
	check("floor 1 comes back", DungeonMap.MAP.size() == 25 and DungeonMap.START_TILE == Vector2i(5, 9) and DungeonMap.SIGNS.is_empty() and DungeonMap.MONSTERS.size() == 23)
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
			if not seen.has(n) and (not DungeonMap.is_wall(n) or DungeonMap.is_rune_wall(n)):  # (A rune wall opens.)
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


## The sealed pen: walking in seals both doors, killing what is inside opens them and raises a reliquary, and H lists the puzzles.
func _check_pen(tools: Node, player: Node) -> void:
	var dungeon: Node = get_first_node_in_group("dungeon")
	var west := Vector2i(29, 26)
	var north := Vector2i(33, 25)
	var exits: Array = DungeonMap.area_exits("pen")
	check("the pen has two doors and no other way out", exits.size() == 2 and exits.has(west) and exits.has(north) and DungeonMap.area_openings("pen").is_empty())
	var station: Dictionary = DungeonMap.STATIONS.filter(func(s): return s.name == "Sealed pen")[0]
	for n in get_nodes_in_group("monsters"):
		n.free()   # (The pacing checks before this one cleared the room: put the pen's skeleton back.)
	dungeon.spawn_monster(load("res://data/monsters/skeleton.tres"), Vector2i(34, 27)).holds_ground = true
	tools._teleport(station)
	tools._refresh_help()
	check("the help lists the puzzles and which conditions hold (%s)" % tools.puzzle_label.text.replace("\n", " / "), tools.puzzle_label.text.contains("PEN_SEAL  OPEN") and tools.puzzle_label.text.contains("- PARTY_IN PEN"))
	player._interact()
	await create_timer(1.0).timeout
	for i in 2:
		player._try_move(Vector2i(1, 0))
		await create_timer(0.5).timeout
	await create_timer(1.0).timeout
	check("stepping into the pen seals both doors", DungeonMap.puzzles_done.has("pen_seal") and DungeonMap.is_sealed(west) and DungeonMap.is_sealed(north) and not DungeonMap.open_doors.has(west))
	check("and not solved while its skeleton lives", not DungeonMap.puzzles_done.has("pen_purged"))
	var show: Node = dungeon.seal_show
	var on_door: Array = show.door_seals.get(west, [])
	check("show: a seal on both faces of each sealed door, riding on the door, and the mortar glows", show.door_seals.size() == 2 and on_door.size() == 3
			and on_door[0].get_parent() == dungeon.doors[west] and show.glows.has("pen") and show.glows.pen.size() > 6)
	var first: int = on_door[0].frame
	await create_timer(0.4).timeout
	check("show: the seal is alive (its frames turn)", on_door[0].frame != first)
	for m in get_nodes_in_group("monsters"):
		if DungeonMap.area_has("pen", m.cell):
			m.take_hit({"hit": true, "damage": 999, "chance": 100, "crit": false, "by": 0})
	await create_timer(0.4).timeout
	var chest_at := Vector2i(31, 27)
	check("show: the seals crumble and the glow dissolves", show.door_seals.is_empty() and show.glows.is_empty() and show.effects.size() >= 4)
	check("show: the chest is still coming up, its items hidden and out of reach", dungeon.reliquary_rising(chest_at) and show.chests[chest_at].sprite.frame == 0
			and not dungeon.items[chest_at].sprite.visible and show.chests[chest_at].sprite.position.y < 0.45)
	player.restore(Vector2i(30, 27), 3)
	player.world_click()
	check("show: a click takes nothing from a rising chest", not get_first_node_in_group("cursor").is_holding() and dungeon.item_at(chest_at) != null)
	await create_timer(2.6).timeout
	check("show: it stands, opens by itself and shows its items; the one-shots are gone", not dungeon.reliquary_rising(chest_at) and show.chests[chest_at].sprite.frame == 1
			and dungeon.items[chest_at].sprite.visible and is_equal_approx(show.chests[chest_at].sprite.position.y, 0.5) and show.effects.is_empty())
	player.world_click()
	check("show: and the items can be taken from it", get_first_node_in_group("cursor").is_holding())
	dungeon.place_item(chest_at, get_first_node_in_group("cursor").release())
	tools._refresh_help()
	check("killing it opens the seals and raises the reliquary", DungeonMap.puzzles_done.has("pen_purged") and not DungeonMap.is_sealed(west) and not DungeonMap.is_sealed(north)
			and DungeonMap.reliquaries.has(Vector2i(31, 27)) and dungeon.item_at(Vector2i(31, 27)) != null and tools.puzzle_label.text.contains("PEN_PURGED  SOLVED"))
	get_first_node_in_group("fight_tracker").in_fight = false   # Leave things quiet for the checks after this one.
	get_first_node_in_group("banter").reset_timers()


## The braziers: lit only by a Fireball or a torch taken from a wall, snuffed bare-handed; both
## burning break the ward on the closet door; a curse zone refuses them.
func _check_braziers(tools: Node, player: Node) -> void:
	var dungeon: Node = get_first_node_in_group("dungeon")
	var party: Node = get_first_node_in_group("party")
	var cursor: Node = get_first_node_in_group("cursor")
	var hud: Node = get_first_node_in_group("hud")
	var north := Vector2i(15, 25)
	var south := Vector2i(15, 27)
	var door := Vector2i(17, 26)
	for n in get_nodes_in_group("monsters"):
		n.free()
	if cursor.is_holding():
		cursor.release()
	var field: Node = dungeon.braziers
	check("two braziers stand dark, each with a bowl, no flame and no light", field.braziers.size() == 4 and field.braziers[north].prop.visible
			and not field.braziers[north].flame.visible and not field.braziers[north].light.visible and not DungeonMap.brazier_lit[north])
	var station: Dictionary = DungeonMap.STATIONS.filter(func(s): return s.name == "Braziers")[0]
	tools._teleport(station)
	var keep := []
	for m in party.members:
		keep.append(m.hands.duplicate())
		m.hands = [null, null]
	await create_timer(0.3).timeout
	player.restore(north - Vector2i(1, 0), 3)
	player._try_move(Vector2i(1, 0))
	await create_timer(0.4).timeout
	var walker: Node = dungeon.spawn_monster(load("res://data/monsters/skeleton.tres"), north + Vector2i(1, 0))
	check("a brazier is solid: neither the party nor a monster steps onto it, but sight passes (%s)" % hud.last_message, player.cell == north - Vector2i(1, 0)
			and hud.last_message == "The brazier is in the way." and not walker._can_enter(north) and not DungeonMap.is_blocked(north)
			and not get_first_node_in_group("traps").can_set(north).is_empty())
	walker.free()
	player.world_click()
	var needs := "It needs a torch from the wall."
	check("with no flame the coals stay cold (%s)" % hud.last_message, not DungeonMap.brazier_lit[north] and hud.last_message == needs)
	var torch: Resource = load("res://data/items/torch.tres")
	for own in [torch, load("res://data/items/candle.tres")]:
		party.members[0].hands = [load("res://scripts/item_stack.gd").of(own, 1), null]
		await create_timer(0.3).timeout
		player.world_click()
		check("the party's own %s does not light it" % own.display_name.to_lower(), not DungeonMap.brazier_lit[north] and hud.last_message == needs)
	var sconce := Vector3i(16, 25, 3)
	var taken: RefCounted = dungeon.take_sconce_torch(sconce, torch)
	check("a torch taken from a wall sconce carries the mark", taken != null and taken.from_wall and taken.take_one().from_wall)
	taken.count = 1
	var SaveData := preload("res://scripts/save_data.gd")
	check("and keeps it, with its time, through a save and a stow into a backpack", SaveData.data_to_stack(SaveData.stack_to_data(taken)).from_wall
			and taken.copy(1).from_wall and is_equal_approx(taken.copy(1).burn_left, taken.burn_left))
	party.members[0].hands = [taken, null]
	await create_timer(0.3).timeout
	player.world_click()
	await create_timer(0.2).timeout
	var light: OmniLight3D = field.braziers[north].light
	check("a wall torch in a hand lights it: the flame shows and its light is a sprite light", DungeonMap.brazier_lit[north] and field.braziers[north].flame.visible
			and light.visible and light.is_in_group("sprite_lights") and absf(light.base_energy - 1.4) < 0.01 and light.omni_range == 7.0)
	party.members[0].hands = [null, null]
	await create_timer(0.3).timeout
	check("and it lights the party's way with nothing in their hands", party.tile_is_lit())
	player.world_click()
	check("an empty-handed click snuffs it", not DungeonMap.brazier_lit[north] and hud.last_message == "You snuff the brazier.")
	cursor.hold(torch)
	dungeon.set_brazier(north, true)
	player.world_click()
	check("with something on the cursor the click puts it down and leaves the fire alone", DungeonMap.brazier_lit[north] and not cursor.is_holding() and dungeon.item_at(north) != null)
	player.world_click()
	check("an item lying there is picked up before the brazier is touched", DungeonMap.brazier_lit[north] and cursor.is_holding())
	cursor.release()
	dungeon.set_brazier(north, false)
	# A Fireball: down the row the north brazier stands in.
	player.restore(Vector2i(12, 25), 3)
	var mage: Variant = party.members.filter(func(m): return m.class_id() == "mage")[0]
	mage.mana = float(mage.def.max_mana)
	mage.cooldown_left = 0.0
	var fireball: Resource = load("res://data/spells/fireball.tres")
	mage.hands = [load("res://scripts/item_stack.gd").of(load("res://data/items/spellbook.tres"), 1), null]
	var cast: bool = party.cast(mage.slot, 0, fireball)
	await create_timer(2.0).timeout
	check("a Fireball can be aimed at a dark brazier and lights it", cast and DungeonMap.brazier_lit[north])
	check("one brazier does not break the ward", not DungeonMap.puzzles_done.has("brazier_ward") and not DungeonMap.open_doors.has(door))
	dungeon.set_brazier(north, false)
	dungeon.ignite_braziers_along(Vector2i(10, 26), Vector2i(16, 26))
	check("a Fireball passing within a tile lights both", DungeonMap.brazier_lit[north] and DungeonMap.brazier_lit[south])
	await create_timer(1.0).timeout
	check("both burning break the ward and the door opens", DungeonMap.puzzles_done.has("brazier_ward") and DungeonMap.open_doors.has(door))
	dungeon.set_brazier(north, false)
	check("and it stays open when one is snuffed", DungeonMap.puzzle_doors.has("brazier_door"))
	var thrown: RefCounted = taken.copy(1)
	dungeon.set_pile(north, [])
	dungeon.place_item(north, thrown)
	dungeon.lights.drop(north, thrown)
	check("a torch thrown onto its tile does not light it", not DungeonMap.brazier_lit[north])
	dungeon.set_pile(north, [])
	dungeon.oil.add_slick(north + Vector2i(-1, 0))
	dungeon.oil.ignite(north + Vector2i(-1, 0))
	check("nor does burning oil beside it", not DungeonMap.brazier_lit[north])
	dungeon.set_brazier(north, true)
	# A curse zone: it will not light, and one burning goes out.
	var real_zones: Array = DungeonMap.CURSE_ZONES
	DungeonMap.CURSE_ZONES = [{"id": "test_brazier", "tiles": [south]}]
	await create_timer(0.3).timeout
	check("a brazier a curse zone covers goes out", not DungeonMap.brazier_lit[south])
	check("and will not light there", not dungeon.ignite_brazier(south) and not DungeonMap.brazier_lit[south])
	DungeonMap.CURSE_ZONES = real_zones
	for i in party.members.size():
		party.members[i].hands = keep[i]
	get_first_node_in_group("fight_tracker").in_fight = false
	get_first_node_in_group("banter").reset_timers()


## The rune room: the runes show only in the dark (braziers snuffed, no flame in a hand), come in by steps, go when light returns, and
## touching them opens the wall.
func _check_runes(tools: Node, player: Node) -> void:
	var dungeon: Node = get_first_node_in_group("dungeon")
	var party: Node = get_first_node_in_group("party")
	var hud: Node = get_first_node_in_group("hud")
	for n in get_nodes_in_group("monsters"):
		n.free()
	if get_first_node_in_group("cursor").is_holding():
		get_first_node_in_group("cursor").release()
	var wall := Vector2i(3, 36)
	var front := Vector2i(3, 35)
	var near := Vector2i(2, 33)
	var far := Vector2i(4, 35)
	var r: Dictionary = dungeon.rune_field.runes.test_runes
	var station: Dictionary = DungeonMap.STATIONS.filter(func(s): return s.name == "Runes")[0]
	var keep := []
	for m in party.members:
		keep.append(m.hands.duplicate())
		m.hands = [null, null]
	tools._teleport(station)
	await create_timer(1.5).timeout
	check("the rune room starts lit by its two braziers, and no rune shows", DungeonMap.brazier_lit[near] and DungeonMap.brazier_lit[far]
			and not dungeon.rune_field.is_dark(r.entry) and r.level == 0.0 and not r.sprite.visible and not r.fade.visible and DungeonMap.is_wall(wall))
	dungeon.set_brazier(far, false)
	await create_timer(1.3).timeout
	check("one brazier still burning is enough to hide them", r.level == 0.0)
	dungeon.set_brazier(near, false)
	await create_timer(0.5).timeout
	check("both snuffed and no flame held: they come in by dim steps (%.2f)" % r.level, dungeon.rune_field.is_dark(r.entry) and r.fade.visible and not r.sprite.visible
			and r.level > 0.2 and r.level < 1.0)
	check("and cannot be touched yet", dungeon.runes_shown(front, 2) == "" and not dungeon.read_runes(front, 2))
	await create_timer(1.0).timeout
	check("after a second they are alive on the wall", r.sprite.visible and not r.fade.visible and dungeon.runes_shown(front, 2) == "test_runes")
	var torch: Resource = load("res://data/items/torch.tres")
	party.members[0].hands = [load("res://scripts/item_stack.gd").of(torch, 1), null]
	await create_timer(0.8).timeout
	check("a torch in a hand hides them again", r.level == 0.0 and not r.sprite.visible and dungeon.runes_shown(front, 2) == "")
	party.members[0].hands = [load("res://scripts/item_stack.gd").of(load("res://data/items/candle.tres"), 1), null]
	await create_timer(1.3).timeout
	check("so does a candle", r.level == 0.0)
	party.members[0].hands = [null, null]
	await create_timer(1.3).timeout
	player.restore(front, 1)
	player.world_click()
	check("facing another wall, a click reads nothing", not DungeonMap.runes_read.has("test_runes"))
	player.restore(front, 2)
	await create_timer(0.2).timeout
	player._interact()
	check("F at the shown runes reads them (%s)" % hud.last_message, DungeonMap.runes_read.has("test_runes") and hud.last_message == "The stone gives way.")
	check("the puzzle condition is met at once, and the wall is still solid while it opens", DungeonMap.puzzles_done.has("rune_reading") and DungeonMap.is_wall(wall))
	await create_timer(3.5).timeout
	check("then it is floor, the runes are gone and the closet is open", not DungeonMap.is_wall(wall) and not DungeonMap.is_blocked(wall) and not r.sprite.visible and not r.fade.visible)
	for i in 2:
		player._try_move(Vector2i(0, 1))
		await create_timer(0.5).timeout
	check("and the party can walk through", player.cell == Vector2i(3, 37))
	var saved: Dictionary = dungeon.save_state()
	check("the read runes are in the save, and a damaged list is refused", saved.runes_read == ["test_runes"] and dungeon.validate_state(saved) == "")
	var bad: Dictionary = saved.duplicate(true)
	bad.runes_read = [3]
	check("...refused", dungeon.validate_state(bad) != "")
	for i in party.members.size():
		party.members[i].hands = keep[i]
	await create_timer(0.5).timeout   # (Hands full again: let any remark about a light be said before the quiet is reset.)
	get_first_node_in_group("fight_tracker").in_fight = false
	get_first_node_in_group("banter").reset_timers()


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
	press.call(KEY_SEMICOLON)
	check("; spawns a pack of three ahead", get_nodes_in_group("monsters").size() == 3)
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
	# The item table: right-click the pile in front for the loot pop-up.
	var table: Dictionary = DungeonMap.STATIONS.filter(func(s): return s.name == "Item table")[0]
	tools._teleport(table)
	await process_frame
	var the_party: Node = get_first_node_in_group("party")
	var the_dungeon: Node = get_first_node_in_group("dungeon")
	var front: Vector2i = player.cell + player.DIRS[player.facing]
	var pile_before: int = the_dungeon.pile_at(front).size()
	var loot: Node = player.world_right_click(Vector2(200, 120))
	await process_frame
	check("right-click on a pile opens the loot pop-up on the pop-up layer, a row per hero and Take all", loot != null and pile_before >= 2
			and loot.get_parent() == get_first_node_in_group("popups") and loot.rows.size() == 4 and loot.take_all_button != null)
	var first = loot.rows[0].member
	var top = the_dungeon.item_at(front)
	var pack_count := func(m, def): return m.backpack.filter(func(s): return s != null and s.def == def).reduce(func(a, s): return a + s.count, 0)
	var had: int = pack_count.call(first, top.def)
	var top_count: int = top.count
	loot.choose(0)
	await process_frame
	check("choosing a hero puts the item in their backpack and takes it off the floor", pack_count.call(first, top.def) == had + top_count
			and the_dungeon.pile_at(front).size() == pile_before - 1 and (not is_instance_valid(loot) or loot.is_queued_for_deletion()))
	check("...with a line saying who stowed it", str(get_first_node_in_group("hud").last_message).begins_with("%s stows" % first.name()))
	# A dead hero is listed last, and can still carry.
	var thief = the_party.members.filter(func(m): return m.class_id() == "thief")[0]
	thief.hp = 0
	loot = player.world_right_click()
	check("a dead hero is listed last", loot != null and loot.rows[-1].member == thief)
	loot.take_all()
	await process_frame
	check("Take all shares the pile out and empties the tile", the_dungeon.item_at(front) == null
			and str(get_first_node_in_group("hud").last_message).contains(" takes "))
	thief.hp = thief.def.max_hp
	# Can't use and full: the leather armour (the Mage can't wear it) and a full pack.
	var armour: Resource = load("res://data/items/leather_armour.tres")
	the_dungeon.place_item(front, armour)
	var mage = the_party.members.filter(func(m): return m.class_id() == "mage")[0]
	var saved_pack: Array = mage.backpack.duplicate()
	for i in mage.backpack.size():
		if mage.backpack[i] == null:
			mage.backpack[i] = load("res://scripts/item_stack.gd").of(load("res://data/items/key.tres"), 1)
	loot = player.world_right_click()
	var mage_row: Dictionary = loot.rows.filter(func(r): return r.member == mage)[0]
	check("the Mage's row says can't use and full, and is disabled", not mage_row.usable and mage_row.room == "FULL" and mage_row.button.disabled)
	var esc := InputEventKey.new()
	esc.physical_keycode = KEY_ESCAPE
	esc.pressed = true
	root.push_input(esc)
	await process_frame
	check("Esc closes it", not is_instance_valid(loot) or loot.is_queued_for_deletion())
	var first_hero = the_party.carry_order()[0]
	first_hero.backpack[first_hero.backpack.size() - 1] = null  # (The test room stocks every item in the packs: leave this one room.)
	loot = player.world_right_click()
	var key2 := InputEventKey.new()
	key2.physical_keycode = KEY_1
	key2.pressed = true
	var first_now = loot.rows[0].member
	root.push_input(key2)
	await process_frame
	key2.pressed = false
	root.push_input(key2)
	check("1 gives it to the first hero listed", first_now.backpack.any(func(s): return s != null and s.def == armour) and the_dungeon.item_at(front) == null)
	mage.backpack = saved_pack
	# The light room: dark (sconces: one lit, two unlit, two empty), a torch and candles to try, and = burns the lit lights down.
	var light_room: Dictionary = DungeonMap.STATIONS.filter(func(s): return s.name == "Light and dark")[0]
	tools._teleport(light_room)
	var room_torches: Array = DungeonMap.TORCHES.filter(func(t): return t.y >= 33 and t.y <= 38 and t.x >= 6 and t.x <= 19)
	var dungeon_node: Node = get_first_node_in_group("dungeon")
	var on_table = dungeon_node.item_at(Vector2i(10, 34))
	check("the light room is dark and has torches to pick up", room_torches.all(func(t): return t.w != DungeonMap.SCONCE_LIT or t.x == 9) and on_table != null and on_table.def.is_light())
	var kinds := {}
	for t in room_torches:
		kinds[t.w] = int(kinds.get(t.w, 0)) + 1
	check("the light room has sconces of all three kinds (lit, unlit with a torch, empty)", kinds.size() == 3 and dungeon_node.sconce_at(Vector3i(9, 33, 0)) == DungeonMap.SCONCE_UNLIT
			and dungeon_node.sconce_at(Vector3i(15, 33, 0)) == DungeonMap.SCONCE_EMPTY and dungeon_node.sconce_at(Vector3i(9, 38, 2)) == DungeonMap.SCONCE_LIT)
	var lit: Array = get_first_node_in_group("party").held_lights()
	press.call(KEY_EQUAL)
	check("= burns every lit light down to its last seconds", not lit.is_empty() and lit.all(func(s): return s.seconds_left() <= 10.0))
	check("the light room has a curse zone over its east end, with haze", DungeonMap.curse_zone_at(Vector2i(16, 36)) == "light_room" and DungeonMap.curse_zone_at(Vector2i(12, 36)) == ""
			and dungeon_node.curse._haze.size() == 48 and DungeonMap.zone_tier_violations().is_empty())
	press.call(KEY_BACKSLASH)
	check("the backslash key lifts the zone (no haze, flames live) and puts it back", DungeonMap.zone_cleared("light_room") and dungeon_node.curse._haze.is_empty() and not dungeon_node.flame_blocked(Vector2i(16, 36)))
	press.call(KEY_BACKSLASH)
	check("and again: it is back", not DungeonMap.zone_cleared("light_room") and dungeon_node.curse._haze.size() == 48 and dungeon_node.flame_blocked(Vector2i(16, 36)))
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
	# The test room stocks every hero's pack with things to try: each hero gets a near-equal share of data/items, and what they hold is theirs to use.
	var packs: Array = []
	var every_usable := true
	for m in get_first_node_in_group("party").members:
		var held: Array = m.backpack.filter(func(st): return st != null)
		packs.append(held.size())
		for st in held:
			if st.def.type == ItemDef.Type.FOCUS and st.def.magic != m.def.magic:
				every_usable = false
			elif m.class_id() in st.def.cant_use:
				every_usable = false
	check("every hero has a stocked pack (%s stacks) of items they can use" % str(packs), packs.min() >= 6 and packs.max() - packs.min() <= 3 and every_usable)
	# DISCARD in the inventory: a full pack is never a trap. The item is dropped on the floor in front, and can be picked up again.
	var inv := get_first_node_in_group("inventory")
	var hand_cursor := get_first_node_in_group("cursor")
	var the_dungeon := get_first_node_in_group("dungeon")
	var front: Vector2i = player.cell + player.DIRS[player.facing]
	while the_dungeon.item_at(front) != null:   # (An empty tile: a drop onto a matching stack would merge into it.)
		the_dungeon.take_item(front)
	var ItemStackS := load("res://scripts/item_stack.gd")
	check("the inventory has a DISCARD button and the window stays on screen", inv.discard_button != null and Rect2(0, 0, 640, 360).encloses(inv.window.get_global_rect()))
	check("DISCARD with an empty hand does nothing", not inv.discard_held())
	var darts: RefCounted = ItemStackS.of(load("res://data/items/darts.tres"), 3)
	hand_cursor.hold(darts)
	check("DISCARD drops the stack on the floor in front", inv.discard_held() and not hand_cursor.is_holding() and the_dungeon.item_at(front) == darts and "drops 3 darts" in inv.status_label.text)
	the_dungeon.take_item(front)
	var key: RefCounted = ItemStackS.of(load("res://data/items/key.tres"), 1)
	hand_cursor.hold(key)
	check("a key (or any item) is dropped at once, never lost", inv.discard_held() and the_dungeon.item_at(front) == key)
	the_dungeon.take_item(front)
	hand_cursor.hold(ItemStackS.of(load("res://data/items/key.tres"), 1))
	var here: Vector2i = player.cell
	player.cell = Vector2i(0, 0)   # A wall in front: nowhere to drop it.
	check("with nowhere to drop it the item stays on the cursor", not inv.discard_held() and hand_cursor.is_holding() and "nowhere" in inv.status_label.text)
	player.cell = here
	hand_cursor.release()
	# Double-clicking an item in the inventory opens its pop-up (DROP, COMBINE), through real input routing: the first click picks the item up, the
	# second puts it back and opens the menu.
	var dm := get_first_node_in_group("party")
	var bread: Resource = load("res://data/items/stale_bread.tres")
	var hero0 = dm.members[0]
	for i in hero0.backpack.size():
		hero0.backpack[i] = null
	hero0.backpack[0] = ItemStackS.of(bread, 3)
	hero0.backpack[2] = ItemStackS.of(bread, 4)
	hero0.backpack[5] = ItemStackS.of(bread, 2)
	inv.show_screen(0)
	await process_frame
	await process_frame
	var cell_a: Control = inv.backpack_slots[0]
	var at: Vector2 = cell_a.get_global_rect().get_center()
	var click_at := func(double: bool):
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = true
		ev.position = at
		ev.global_position = at
		ev.double_click = double
		root.push_input(ev, true)
	click_at.call(false)
	check("one click picks the stack up", hand_cursor.is_holding() and hand_cursor.held.count == 3)
	click_at.call(true)
	await process_frame
	var item_menu := get_first_node_in_group("item_menu")
	check("the second click puts it back and opens the item pop-up", not hand_cursor.is_holding() and hero0.backpack[0] != null and item_menu != null)
	check("the pop-up offers DROP and COMBINE (3 stacks of bread)", item_menu != null and not item_menu.drop_button.disabled and item_menu.combinable == 3 and not item_menu.combine_button.disabled)
	if item_menu != null:
		check("COMBINE merges the pack's bread into full stacks", item_menu.combine() >= 1)
		var total := 0
		var stacks := 0
		for st in hero0.backpack:
			if st != null and st.def == bread:
				total += st.count
				stacks += 1
		check("nine bread now lie in two stacks (5 and 4), none lost", total == 9 and stacks == 2)
		inv.refresh()
		at = inv.backpack_slots[0].get_global_rect().get_center()
		click_at.call(false)
		click_at.call(true)
		await process_frame
		item_menu = get_first_node_in_group("item_menu")
		check("combining again changes nothing (5 and 4 cannot merge)", item_menu != null and item_menu.combine() == 0 and "already" in inv.status_label.text)
		inv.refresh()
		click_at.call(false)
		click_at.call(true)
		await process_frame
		item_menu = get_first_node_in_group("item_menu")
		var front_cell: Vector2i = player.cell + player.DIRS[player.facing]
		while the_dungeon.item_at(front_cell) != null:
			the_dungeon.take_item(front_cell)
		if item_menu != null:
			var dropped_count: int = hero0.backpack[0].count
			check("DROP puts the whole stack on the floor in front", item_menu.drop() and hero0.backpack[0] == null and the_dungeon.item_at(front_cell) != null and the_dungeon.item_at(front_cell).count == dropped_count)
	inv.hide_screen()
	# The campfire station: a camp at (21,21) with four bedrolls, an animated flame and a flickering light the dark rules count.
	var camps := get_nodes_in_group("camp_sites")
	var camp_ok: bool = camps.size() == 1 and camps[0].cell == Vector2i(21, 21) and camps[0].bedrolls.size() == 4 and camps[0].flame != null and camps[0].light != null
	check("the campfire station has a camp with four bedrolls, a flame and a light", camp_ok)
	check("a campfire tile is not walkable but does not block sight", DungeonMap.is_campfire(Vector2i(21, 21)) and not DungeonMap.is_campfire(Vector2i(20, 21)) and not DungeonMap.is_blocked(Vector2i(21, 21)))
	if camp_ok:
		# Walking into the fire: the party stays where it is.
		player.cell = Vector2i(21, 20)
		player.position = DungeonMap.cell_to_world(player.cell)
		player._try_move(Vector2i(0, 1))
		check("the party cannot step into the campfire", player.cell == Vector2i(21, 20))
		# Clicking the fire in front opens its pop-up: make camp and cook (greyed with nothing raw).
		player.facing = 2
		player.world_click()
		await process_frame
		var fire_menu: Node = player.last_campfire_menu
		check("clicking the campfire opens its pop-up", fire_menu != null and is_instance_valid(fire_menu) and fire_menu.is_in_group("campfire_menu"))
		if fire_menu != null and is_instance_valid(fire_menu):
			check("COOK is greyed with nothing raw to cook", fire_menu.cook_button.disabled == (fire_menu.raw_count <= 0))
			check("MAKE CAMP makes camp at the fire", fire_menu.make_camp() and get_first_node_in_group("camp").active)
			get_first_node_in_group("camp").end()
			check("the pop-up closes after a choice", fire_menu.is_queued_for_deletion())
		player.cell = Vector2i(20, 14)
		player.position = DungeonMap.cell_to_world(player.cell)
		var flame: Node = camps[0].flame
		var t0: float = flame.t
		await create_timer(0.3).timeout
		check("its flame is playing and its light is a sprite light", flame.t > t0 and camps[0].light.is_in_group("sprite_lights") and camps[0].light.light_energy > 0.0)
		var ahead: Vector2 = Vector2(camps[0].global_position.x, camps[0].global_position.z)
		var lit := false
		for l in get_nodes_in_group("sprite_lights"):
			lit = lit or (l == camps[0].light and Vector2(l.global_position.x, l.global_position.z).distance_to(ahead) < l.omni_range)
		check("the fire's light reaches the camp (so the dark penalty does not apply beside it)", lit)
		# The bedrolls are plump rounded 3D mats (the PixelLab bed picture wrapped over them), thick, resting on the floor, fixed in place: nothing tips or
		# turns them toward the camera.
		var bed_ok := true
		var before := []
		var thick := 0.0
		for bed in camps[0].bedrolls:
			var is_mesh: bool = bed is MeshInstance3D and bed.mesh is ArrayMesh
			bed_ok = bed_ok and is_mesh
			if not is_mesh:
				continue
			var box: AABB = bed.mesh.get_aabb()
			thick = box.size.y
			var mat: StandardMaterial3D = bed.material_override
			bed_ok = bed_ok and box.size.y > 0.2 and box.size.y < 0.4 and bed.mesh.surface_get_array_len(0) > 4000 and absf(box.position.y) < 0.001 and box.size.x > 1.7 and box.size.z > 0.6 					and absf(bed.position.y) < 0.001 and absf(bed.rotation.x) < 0.0001 and absf(bed.rotation.z) < 0.0001 					and mat != null and mat.albedo_texture != null and mat.albedo_texture.resource_path.ends_with("art/camp/bed.png")
			before.append(bed.global_transform)
		# The cloth detail: the picture is the patchwork sleeping bag (175 x 70 px) and each patch of it swells on its own in the geometry, with a crease along
		# the seams and the strapped roll standing taller than the patches.
		var site = camps[0]
		var tex_w: int = site.bedrolls[0].material_override.albedo_texture.get_width()
		var a_of := func(px: float) -> float: return px / float(tex_w) * 2.0 - 1.0
		var b_row: float = -0.5   # The middle of the top row of patches (pixel row 17 of 70).
		var centre: float = site._bed_height(a_of.call(96.0), b_row)    # The middle of the middle patch.
		var seam: float = site._bed_height(a_of.call(71.0), b_row)      # The seam between it and the first patch.
		var other: float = site._bed_height(a_of.call(50.0), b_row)     # The middle of the first patch.
		var roll: float = site._bed_height(a_of.call(14.0), 0.0)
		check("the bed is the patchwork bag (%d px wide): each patch swells (%.3f) over its seam (%.3f), and the roll stands taller (%.3f)" % [tex_w, centre, seam, roll],
				tex_w == 175 and centre - seam > 0.03 and other - seam > 0.03 and roll > centre)
		get_first_node_in_group("player").restore(Vector2i(21, 17), 2)
		await create_timer(0.3).timeout
		get_first_node_in_group("player").restore(Vector2i(17, 21), 3)
		await create_timer(0.3).timeout
		var still := true
		for k in before.size():
			still = still and camps[0].bedrolls[k].global_transform.is_equal_approx(before[k])
		check("the four bedrolls are thick rounded mats (%.2f tall) standing on the floor, and do not move or turn when the camera does" % thick, bed_ok and still and before.size() == 4)
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
	# Camp survival: a bedroll in front of the station, ash where the party rests, the wound key, the free camp key and the status line.
	var wood_pile = dungeon.item_at(Vector2i(21, 19))
	check("the camp survival station has a bedroll in front of it and ash on the camp spot", wood_pile != null and wood_pile.def.makes_camp and wood_pile.count == 3
			and DungeonMap.camp_spot_at(Vector2i(21, 20)) and get_nodes_in_group("camp_spot_marks").size() == 1)
	# The legendary station: the Test Blade (a framework item in data/debug) lies in front of it, fighter only.
	var blade = dungeon.item_at(Vector2i(36, 9))
	var fighter_m = party.members.filter(func(m): return m.class_id() == "fighter")[0]
	var cleric_m = party.members.filter(func(m): return m.class_id() == "cleric")[0]
	check("the legendary station has the Test Blade in front of it: legendary, with its text, fighter only", blade != null and blade.def.legendary and blade.def.legend_text().contains("Price:")
			and party.can_equip(fighter_m, blade.def) and not party.can_equip(cleric_m, blade.def))
	var azure = dungeon.item_at(Vector2i(35, 9))
	check("the legendary station also has the Azure Brand on the floor: a real legendary, for the fighter and the thief but not the cleric",
			azure != null and azure.def.resource_path.ends_with("azure_brand.tres") and azure.def.legendary and party.can_equip(fighter_m, azure.def) and not party.can_equip(cleric_m, azure.def))
	var station_sign := ""
	for s_entry in DungeonMap.SIGNS:
		if s_entry.cell == Vector2i(35, 12):
			station_sign = s_entry.text
	check("the legendary station's sign no longer says it is not built", station_sign.contains("AZURE BRAND") and station_sign.contains("TEST BLADE") and not station_sign.contains("NOT BUILT"))
	check("the help shows whether the party may camp", tools.help_label.text.contains("CAMP   "))
	press.call(KEY_COMMA)
	var wounded := true
	for m in party.members:
		wounded = wounded and m.hp < m.def.max_hp and m.mana == 0.0 and m.sick_left > 0.0
	check(", wounds, drains and sickens the party for the camp test", wounded)
	var camp_node: Node = get_first_node_in_group("camp")
	press.call(KEY_PERIOD)
	check(". makes camp without a bedroll when the party may, and the help says it is resting", camp_node != null and camp_node.active and party.camping)
	camp_node._process(31.0)
	var healed := true
	for m in party.members:
		healed = healed and m.hp == m.def.max_hp
	check("and the rest heals everyone and ends", healed and not camp_node.active and not party.camping)
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
	var hit_overlay: Node = get_first_node_in_group("hit_overlay")
	var before_fx: int = hit_overlay.playing.size() if hit_overlay else 0
	press.call(KEY_MINUS)
	check("- plays a monster's hit effect", hit_overlay != null and hit_overlay.playing.size() == before_fx + 1)
	press.call(KEY_J)
	check("J switches screen shake off", not load("res://data/combat_feel.tres").screen_shake_enabled)
	press.call(KEY_J)
	var fog_before: bool = Settings.fog
	press.call(KEY_N)
	check("N toggles fog without touching the saved setting", tools.fog_on != fog_before and Settings.fog == fog_before)
	await _check_pacing(tools, press, player)
	await _check_pen(tools, player)
	await _check_braziers(tools, player)
	await _check_runes(tools, player)
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
