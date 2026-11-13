extends RefCounted
## Save and load the run (7.3). One slot, JSON, at user://savegame.json.
## Use it via preload (like DungeonMap):
##     const SaveGame := preload("res://scripts/save_game.gd")
##     SaveGame.save(tree)        # -> "" or an error message
##     SaveGame.load_game(tree)   # reloads the scene and applies the file -> "" or an error
##
## What is saved (everything that changes during a run; level layout, art and item and
## monster definitions are data and come back from the game files):
##   party      the formation (hero_index per position) and, per hero: hp, mana, hands,
##              armour, backpack, quick slots, active buffs
##   player     cell and facing
##   dungeon    items lying on the floor (piles, with where thrown items came from),
##              which doors are open or unlocked, which levers are on, live monsters
##              (kind, cell, hp, attack timer)
##   cursor     the item held on the cursor
##   flags      the run flags (DungeonMap.flags: things that have happened, by name)
## Not saved: cooldowns (they restart ready), animations in flight, floating text.
##
## Loading reloads main.tscn (a clean, fully built dungeon) and then applies the file to
## it once everything is ready: see save_manager.gd, which calls apply() for `pending`.
## Items and spells are stored by resource path; numbers come back from JSON as floats,
## so every integer is converted on the way in.

const DungeonMap := preload("res://scripts/dungeon_map.gd")
const ItemStack := preload("res://scripts/item_stack.gd")
const MonsterScript := preload("res://scripts/monster.gd")

## Where the save lives. A var so tests can point it elsewhere and never touch a real save.
static var path := "user://savegame.json"
const VERSION := 1
const MAIN_SCENE := "res://scenes/main.tscn"

## The save waiting to be applied after the scene reloads (set by load_game).
static var pending := {}


static func has_save() -> bool:
	return FileAccess.file_exists(path)


## Write the current run to disk. Returns "" on success or why it failed.
static func save(tree: SceneTree) -> String:
	if DungeonMap.level_path != "":
		return "The test room can't be saved."
	var data := serialize(tree)
	if data.is_empty():
		return "Nothing to save."
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return "Couldn't write the save file."
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
	if DirAccess.rename_absolute(tmp, path) != OK:  # Replace the old save only once the new one is complete.
		DirAccess.remove_absolute(path)
		DirAccess.rename_absolute(tmp, path)
	return ""


## Read the file. Returns {} with `error` explaining if it can't be used.
static func read_file() -> Dictionary:
	if not has_save():
		return {"error": "There is no saved game."}
	var text := FileAccess.get_file_as_string(path)
	var parsed = JSON.parse_string(text)
	if not (parsed is Dictionary):
		return {"error": "The save file is damaged."}
	if int(parsed.get("version", 0)) != VERSION:
		return {"error": "The save file is from another version."}
	return parsed


## Load the saved game: reload the main scene and apply the file to it. Returns ""
## on success or why it can't.
static func load_game(tree: SceneTree) -> String:
	var data := read_file()
	if data.has("error"):
		return data.error
	pending = data
	DungeonMap.use_level("")  # Saves are floor 1's (the test room cannot be saved).
	tree.paused = false
	if tree.current_scene != null and tree.current_scene.scene_file_path == MAIN_SCENE:
		tree.reload_current_scene()
	else:
		tree.change_scene_to_file(MAIN_SCENE)
	return ""


# --------------------------------------------------------------------------
# Serialising
# --------------------------------------------------------------------------

static func serialize(tree: SceneTree) -> Dictionary:
	var party := tree.get_first_node_in_group("party")
	var player := tree.get_first_node_in_group("player")
	var dungeon := tree.get_first_node_in_group("dungeon")
	if party == null or player == null or dungeon == null:
		return {}
	var cursor := tree.get_first_node_in_group("cursor")

	var heroes := []
	for m in party.members:
		var buffs := []
		for b in m.buffs:
			buffs.append({"spell": b.spell.resource_path, "left": b.left})
		heroes.append({
			"hero": m.hero_index, "hp": m.hp, "mana": m.mana, "shaken": m.shaken_left,
			"food": {"left": m.food_left, "rate": m.food_rate, "sick_left": m.sick_left, "sick_rate": m.sick_rate},
			"hands": m.hands.map(stack_to_data), "armour": stack_to_data(m.armour),
			"backpack": m.backpack.map(stack_to_data), "quick": m.quick.map(stack_to_data),
			"buffs": buffs,
		})

	var piles := []
	for cell in dungeon.items:
		piles.append({"cell": cell_to_data(cell), "pile": dungeon.items[cell].pile.map(stack_to_data)})
	var broken := []
	for cell in DungeonMap.broken_walls:
		broken.append(cell_to_data(cell))
	var purified := []  # (A wall whose purifying show is still running counts as burned away.)
	for cell in DungeonMap.purified:
		purified.append(cell_to_data(cell))
	for cell in DungeonMap.purify_pending:
		if not DungeonMap.purified.has(cell):
			purified.append(cell_to_data(cell))
	var corruption := []  # The corrupted walls still standing and the Blesses each still needs.
	for cell in DungeonMap.corrupted_left:
		if int(DungeonMap.corrupted_left[cell]) > 0 and not DungeonMap.purify_pending.has(cell):
			corruption.append({"cell": cell_to_data(cell), "left": int(DungeonMap.corrupted_left[cell])})
	var open_doors := []
	for cell in DungeonMap.open_doors:
		open_doors.append(cell_to_data(cell))
	var unlocked := []
	for cell in DungeonMap.unlocked_doors:
		unlocked.append(cell_to_data(cell))
	var levers := []
	for key in dungeon.lever_on:
		if dungeon.lever_on[key]:
			levers.append([key.x, key.y, key.z])
	var monsters := []
	for n in dungeon.get_children():
		if n.has_method("take_hit") and not n.dying:
			var statuses := []  # Held and any other status, with the time left (an older save has none).
			for entry in n.statuses.values():
				statuses.append({"def": entry.def.resource_path, "left": entry.left, "source": entry.source})
			monsters.append({"def": n.def.resource_path, "cell": cell_to_data(n.cell),
					"hp": n.hp, "attack_cooldown": n.attack_cooldown, "statuses": statuses})

	return {
		"version": VERSION,
		"party": {"formation": party.formation.duplicate(), "heroes": heroes},
		"player": {"cell": cell_to_data(player.cell), "facing": player.facing},
		"dungeon": {"items": piles, "open_doors": open_doors, "unlocked_doors": unlocked,
				"levers": levers, "monsters": monsters, "broken_walls": broken,
				"purified_walls": purified, "corruption": corruption,
				"puzzles_done": DungeonMap.puzzles_done.keys(), "puzzle_doors": DungeonMap.puzzle_doors.keys()},
		"flags": DungeonMap.flags.duplicate(),
		"cursor": stack_to_data(cursor.held) if cursor else null,
	}


static func cell_to_data(cell: Vector2i) -> Array:
	return [cell.x, cell.y]


static func data_to_cell(data) -> Vector2i:
	return Vector2i(int(data[0]), int(data[1]))


static func stack_to_data(stack):
	if stack == null:
		return null
	var d := {"def": stack.def.resource_path, "count": stack.count}
	if not stack.origin.is_empty():
		d["origin"] = stack.origin.duplicate()
	return d


## Rebuild an ItemStack from saved data, or null if it's empty or its item no longer exists.
static func data_to_stack(data) -> RefCounted:
	if not (data is Dictionary) or not ResourceLoader.exists(str(data.get("def", ""))):
		return null
	var stack: RefCounted = ItemStack.of(load(data.def), maxi(1, int(data.get("count", 1))))
	var o = data.get("origin")
	if o is Dictionary and o.has("hero"):
		stack.origin = {"hero": int(o.hero), "where": str(o.where), "index": int(o.index)}
	return stack


# --------------------------------------------------------------------------
# Applying
# --------------------------------------------------------------------------

## Put a saved game onto a freshly built main scene. Returns "" or why it couldn't.
static func apply(tree: SceneTree, data: Dictionary) -> String:
	var party := tree.get_first_node_in_group("party")
	var player := tree.get_first_node_in_group("player")
	var dungeon := tree.get_first_node_in_group("dungeon")
	if party == null or player == null or dungeon == null:
		return "The game isn't ready to load."
	var hero_data: Array = data.party.heroes
	if hero_data.size() != party.members.size():
		return "The saved party doesn't match this game."
	# Check the formation before changing anything: a bad file must not half-load.
	var order := []
	var seen := {}
	for h in data.party.formation:
		order.append(int(h))
		seen[int(h)] = true
	if order.size() != party.members.size() or seen.size() != order.size() 			or not order.all(func(h): return h >= 0 and h < party.members.size()):
		return "The saved formation is invalid."

	# --- party (by hero, whatever position they were standing in) ---
	var by_hero := {}
	for m in party.members:
		by_hero[m.hero_index] = m
	for h in hero_data:
		var m = by_hero.get(int(h.hero))
		if m == null:
			return "The saved party doesn't match this game."
		m.hp = clampi(int(h.hp), 0, m.def.max_hp)
		m.mana = clampf(float(h.mana), 0.0, float(m.def.max_mana))
		m.shaken_left = maxf(0.0, float(h.get("shaken", 0.0))) if m.hp > 0 else 0.0  # (An older save has none.)
		var food: Dictionary = h.get("food", {})  # (So does an older save: no food or sickness running.)
		var alive: bool = m.hp > 0
		m.food_left = maxf(0.0, float(food.get("left", 0.0))) if alive else 0.0
		m.food_rate = maxf(0.0, float(food.get("rate", 0.0)))
		m.sick_left = maxf(0.0, float(food.get("sick_left", 0.0))) if alive else 0.0
		m.sick_rate = maxf(0.0, float(food.get("sick_rate", 0.0)))
		m.food_acc = 0.0
		m.sick_acc = 0.0
		m.cooldown_left = 0.0
		for i in m.hands.size():
			m.hands[i] = data_to_stack(h.hands[i]) if i < h.hands.size() else null
		m.armour = data_to_stack(h.armour)
		for i in m.backpack.size():
			m.backpack[i] = data_to_stack(h.backpack[i]) if i < h.backpack.size() else null
		for i in m.quick.size():
			m.quick[i] = data_to_stack(h.quick[i]) if i < h.quick.size() else null
			m.quick_cooldown[i] = 0.0
		m.buffs.clear()
		for b in h.buffs:
			if ResourceLoader.exists(str(b.spell)):
				m.buffs.append({"spell": load(b.spell), "left": float(b.left)})
	party.set_formation(order)  # Also redraws the HUD. (Validated above.)
	for m in party.members:
		party.hp_changed.emit(m.slot)

	# --- dungeon ---
	var d: Dictionary = data.dungeon
	DungeonMap.unlocked_doors.clear()
	for c in d.unlocked_doors:
		DungeonMap.unlocked_doors[data_to_cell(c)] = true
	var open := {}
	for c in d.open_doors:
		open[data_to_cell(c)] = true
	var broken_cells := []
	for c in d.get("broken_walls", []):  # (An older save has none.)
		broken_cells.append(data_to_cell(c))
	dungeon.restore_broken_walls(broken_cells)
	var left := {}
	for entry in d.get("corruption", []):  # (An older save has none: every corrupted wall starts fresh.)
		left[data_to_cell(entry.cell)] = int(entry.left)
	var purified_cells := []
	for c in d.get("purified_walls", []):
		purified_cells.append(data_to_cell(c))
	DungeonMap.puzzles_done.clear()
	for id in d.get("puzzles_done", []):
		DungeonMap.puzzles_done[str(id)] = true
	DungeonMap.puzzle_doors.clear()
	for id in d.get("puzzle_doors", []):
		DungeonMap.puzzle_doors[str(id)] = true
	DungeonMap.flags.clear()  # (An older save has none: the run starts with no flags set.)
	var saved_flags = data.get("flags", {})
	if saved_flags is Dictionary:
		for name in saved_flags:
			var value = saved_flags[name]
			if value is float and value == floorf(value) and absf(value) < 1.0e15:
				value = int(value)  # JSON gives every number back as a float.
			if typeof(value) in [TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING]:
				DungeonMap.flags[str(name)] = value
	dungeon.restore_corruption(left, purified_cells)
	dungeon.restore_doors(open)
	var on := {}
	for l in d.levers:
		on[Vector3i(int(l[0]), int(l[1]), int(l[2]))] = true
	dungeon.restore_levers(on)

	for cell in dungeon.items.keys():
		dungeon.set_pile(cell, [])
	for entry in d.items:
		var stacks := []
		for s in entry.pile:
			var stack := data_to_stack(s)
			if stack != null:
				stacks.append(stack)
		dungeon.set_pile(data_to_cell(entry.cell), stacks)

	dungeon.clear_monsters()
	for mo in d.monsters:
		if ResourceLoader.exists(str(mo.def)):
			var monster: Node = dungeon.spawn_monster(load(mo.def), data_to_cell(mo.cell), int(mo.hp), float(mo.attack_cooldown))
			for st in mo.get("statuses", []):
				if ResourceLoader.exists(str(st.def)):
					monster.add_status(load(st.def), float(st.left), int(st.source), true)  # Quiet: no news, no binding again.

	# --- player and cursor ---
	player.restore(data_to_cell(data.player.cell), int(data.player.facing))
	var cursor := tree.get_first_node_in_group("cursor")
	if cursor:
		cursor.release()
		var held := data_to_stack(data.cursor)
		if held != null:
			cursor.hold(held)
	return ""
