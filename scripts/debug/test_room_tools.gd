extends CanvasLayer
## Debug tools: F12 opens or leaves the test room, and inside it the debug keys and a toggleable help overlay (H).
## Debug builds only: game_view.gd adds this node when DungeonMap.test_room_available() says so, and this file (with the whole
## scripts/debug folder and levels/) is left out of release exports (export_presets.cfg exclude_filter).
##
## Keys (only inside the test room, so they never clash with play): H help, G god mode, R refill HP and mana, X +500 XP,
## U level up the party, Z kill all monsters, V spawn a monster in front (a pop-up list), T teleport to a station (a pop-up
## list), B banter, N fog, J screen shake, P spell and torch shadows. Monster pacing: O picks a value (step interval, reaction
## delay, arrival recovery, flank delay), [ and ] lower or raise it by 0.1 s on every monster kind at once (the loaded
## MonsterDefs, so live monsters feel it on their next move; never saved: copy what feels right into data/monsters/*.tres),
## Y puts the values from the files back, I spawns a pack of three skeletons ahead. Hit effects: - plays the next monster kind's
## hit effect (MonsterDef.hit_effect) across the view, from the front, the left, the right and behind in turn, with no damage. Held monster: 9 holds the monster in front
## (Hold Monster's status and time, with no resistance roll and no mana), 0 frees every held monster. X and U wait for an XP system: they call Party.add_xp / Party.level_up_party when
## those exist and say so in the log until then. A new system gets a station in levels/test_room.gd and, if it needs one, a key here.
##
## On arriving, every item in data/items is put in the heroes' backpacks (one of each, full stacks of stackables, shared round the
## party; their hands are left alone), for quick access. The item table still has one of each on the floor.
##
## The ambush corridor is a stand-in: stepping on a trigger tile in DungeonMap.AMBUSHES spawns its monsters.

const DungeonMap := preload("res://scripts/dungeon_map.gd")
const Settings := preload("res://scripts/settings.gd")
const SpellEffectsConfigScript := preload("res://scripts/spell_effects_config.gd")
const FONT := preload("res://art/fonts/PressStart2P-Regular.ttf")
const WARN_DISTANCE := 6  # Tiles from an ambush's trigger at which the party gets its warning.
const MONSTER_DIR := "res://data/monsters"
const ITEM_DIR := "res://data/items"
const ItemStack := preload("res://scripts/item_stack.gd")
const PACING_FIELDS := [["step_interval", "STEP"], ["reaction_delay", "REACTION"], ["arrival_recovery", "RECOVERY"], ["flank_after", "FLANK DELAY"]]
const PACING_STEP := 0.1
const PACK_MONSTER := "res://data/monsters/skeleton.tres"
const HOLD_SPELL := "res://data/spells/hold_monster.tres"

const INK := Color("0b0a10")
const STONE_900 := Color("14131b")
const STONE_700 := Color("2a2937")
const RUST_500 := Color("7c4426")
const BONE_300 := Color("c9c0a4")
const BONE_500 := Color("9b9278")
const TORCH_300 := Color("f5cf80")

var in_room := false
var help: PanelContainer
var help_label: Label
var menu: Control
var god := false
var help_clock := 0.0
var banter_on := true
var fog_on := true
var shake_on := true
var armed := {}          # ambush index -> true while it can spring
var warned := {}         # ambush index -> true once its warning has been given (until the party walks away)
var ambush_active := false  # An ambush has sprung and its fight is not over: banter is quiet
var ambush_age := 0.0
var last_cell := Vector2i(-99, -99)
var tune_index := 0       # Which of PACING_FIELDS [ and ] change.
var hit_fx_turn := 0      # Which monster kind's hit effect (and which side) - plays next.


func _ready() -> void:
	layer = 14  # Help overlay only (pop-ups go through the pop-up layer, 16, which must stay above every HUD layer).
	process_mode = Node.PROCESS_MODE_ALWAYS
	in_room = DungeonMap.level_path == DungeonMap.TEST_ROOM_PATH
	if not in_room:
		return
	fog_on = Settings.fog
	shake_on = _feel().screen_shake_enabled
	for i in DungeonMap.AMBUSHES.size():
		armed[i] = true
	var bus := get_tree().root.get_node_or_null("GameEvents")
	if bus != null:
		bus.fight_ended.connect(_on_fight_ended)
	_build_help()
	_stock_backpacks.call_deferred()  # (Deferred: the party gives out its starting kit in its own _ready.)
	_say("Test room. H shows the debug keys.")


func _process(delta: float) -> void:
	if ambush_active:  # Safety: if no fight ever starts, banter does not stay quiet for ever.
		ambush_age += delta
		var party := _party()
		if ambush_age > 12.0 and not (party != null and party.fight.in_fight):
			_end_ambush(false)
	if help != null and help.visible:  # The fight line changes by itself: redraw the overlay a few times a second.
		help_clock -= delta
		if help_clock <= 0.0:
			help_clock = 0.2
			_refresh_help()
	if not in_room or DungeonMap.player_cell == last_cell:
		return
	last_cell = DungeonMap.player_cell
	for i in DungeonMap.AMBUSHES.size():
		var a: Dictionary = DungeonMap.AMBUSHES[i]
		var d: Vector2i = last_cell - a.trigger
		var distance := absi(d.x) + absi(d.y)
		if last_cell == a.trigger and armed.get(i, false):
			armed[i] = false
			_spring(a, i)
		elif distance > 8:
			armed[i] = true
			warned[i] = false
		elif armed.get(i, false) and distance <= WARN_DISTANCE and not warned.get(i, false):
			warned[i] = true  # A quick exchange before the burst (the laugh lowers the guard).
			_banter("ambush_warning", {})


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if event.keycode == KEY_F12:
		get_viewport().set_input_as_handled()
		DungeonMap.use_level("" if in_room else DungeonMap.TEST_ROOM_PATH)
		get_tree().paused = false
		get_tree().reload_current_scene()
		return
	if not in_room:
		return
	if event.keycode == KEY_ESCAPE and is_instance_valid(menu):
		_close_menu()
		get_viewport().set_input_as_handled()
		return
	if event.ctrl_pressed or event.alt_pressed or event.meta_pressed or get_tree().paused:
		return
	var handled := true
	match event.keycode:
		KEY_H:
			help.visible = not help.visible
		KEY_G:
			god = not god
			_party().god_mode = god
			_say("God mode %s." % ("on: nothing can hurt the party" if god else "off"))
		KEY_R:
			_refill()
		KEY_X:
			if _party().has_method("add_xp"):
				_party().add_xp(500)
				_say("+500 XP.")
			else:
				_say("No XP system yet: nothing to add.")
		KEY_U:
			if _party().has_method("level_up_party"):
				_party().level_up_party()
				_say("The party levels up.")
			else:
				_say("No levels yet: nothing to raise.")
		KEY_Z:
			_kill_all()
		KEY_V:
			_open_spawn_list()
		KEY_T:
			_open_teleport_list()
		KEY_B:
			banter_on = not banter_on
			var b := get_tree().get_first_node_in_group("banter")
			if b:
				b.enabled = banter_on
			_say("Banter %s." % ("on" if banter_on else "off"))
		KEY_N:
			fog_on = not fog_on
			var env_node := get_parent().get_node_or_null("WorldEnvironment")
			if env_node:
				SpellEffectsConfigScript.apply_environment(env_node.environment, fog_on)  # (Not saved: Settings.fog is untouched.)
			_say("Fog %s." % ("on" if fog_on else "off"))
		KEY_J:
			shake_on = not shake_on
			_feel().screen_shake_enabled = shake_on
			_say("Screen shake %s." % ("on" if shake_on else "off"))
		KEY_P:
			Settings.spell_shadows = not Settings.spell_shadows  # (Not saved.)
			SpellEffectsConfigScript.refresh_shadows(get_tree())
			_say("Shadows %s." % ("on" if Settings.spell_shadows else "off"))
		KEY_O:
			tune_index = (tune_index + 1) % PACING_FIELDS.size()
			_say("Tuning %s." % str(PACING_FIELDS[tune_index][1]).to_lower())
		KEY_BRACKETLEFT:
			_tune(-1.0)
		KEY_BRACKETRIGHT:
			_tune(1.0)
		KEY_Y:
			_reset_pacing()
		KEY_I:
			_spawn_pack()
		KEY_MINUS:
			_next_hit_effect()
		KEY_EQUAL:
			_burn_lights_down()
		KEY_9:
			_hold_ahead()
		KEY_0:
			_free_all()
		_:
			handled = false
	if handled:
		get_viewport().set_input_as_handled()
		_refresh_help()


# --- Actions -------------------------------------------------------------------------------------

## Every item in data/items into the backpacks: one of each (a full stack of a stackable), handed round the party so each pack gets a
## share; one that doesn't fit its hero's pack tries the next. Returns how many items found a place.
func _stock_backpacks() -> int:
	var party := _party()
	var dir := DirAccess.open(ITEM_DIR)
	if party == null or dir == null:
		return 0
	var names := Array(dir.get_files()).filter(func(f): return f.ends_with(".tres") or f.ends_with(".tres.remap"))
	names.sort()
	var placed := 0
	var turn := 0
	for f in names:
		var def: Resource = load("%s/%s" % [ITEM_DIR, f.trim_suffix(".remap")])
		if def == null:
			continue
		var stack: RefCounted = ItemStack.of(def, maxi(1, def.max_stack))
		for k in party.members.size():
			if party.add_to_backpack((turn + k) % party.members.size(), stack):
				placed += 1
				break
		turn += 1
	party.formation_changed.emit()  # (The party panels and an open inventory redraw.)
	return placed


func _refill() -> void:
	var party := _party()
	for m in party.members:
		var was_dead: bool = m.hp <= 0
		m.hp = m.def.max_hp
		m.mana = float(m.def.max_mana)
		m.shaken_left = 0.0
		party.hp_changed.emit(m.slot)
		if was_dead:
			party.revived.emit(m.slot, false)
	_say("HP and mana refilled.")


func _kill_all() -> void:
	var n := get_tree().get_nodes_in_group("monsters").size()
	var dungeon := get_tree().get_first_node_in_group("dungeon")
	if dungeon:
		dungeon.clear_monsters()
	_say("%d monster%s removed." % [n, "" if n == 1 else "s"])


func _spawn(path: String) -> void:
	var player := get_tree().get_first_node_in_group("player")
	var dungeon := get_tree().get_first_node_in_group("dungeon")
	var cell: Vector2i = player.cell + player.DIRS[player.facing]
	if DungeonMap.is_blocked(cell) or DungeonMap.is_occupied(cell) or DungeonMap.is_stairs(cell):
		_say("No room in front of the party.")
		return
	var def: Resource = load(path)
	dungeon.spawn_monster(def, cell)
	_say("A %s appears." % def.display_name)


## Every MonsterDef in data/monsters as [path, the loaded (shared) resource], sorted by file name.
func _monster_defs() -> Array:
	var out := []
	var dir := DirAccess.open(MONSTER_DIR)
	if dir == null:
		return out
	var names := Array(dir.get_files()).filter(func(f): return f.ends_with(".tres") or f.ends_with(".tres.remap"))
	names.sort()
	for f in names:
		var path := "%s/%s" % [MONSTER_DIR, f.trim_suffix(".remap")]
		var def: Resource = load(path)
		if def != null and def.get("step_interval") != null:
			out.append([path, def])
	return out


## [ and ]: move the chosen pacing value by 0.1 s on every monster kind (each keeps its own value, all move together).
func _tune(direction: float) -> void:
	var field: String = PACING_FIELDS[tune_index][0]
	var lowest := 0.1 if field == "step_interval" else 0.0  # A zero step interval would move every frame.
	for e in _monster_defs():
		e[1].set(field, maxf(lowest, snappedf(float(e[1].get(field)) + direction * PACING_STEP, 0.01)))
	_say("%s %s. Not saved." % [str(PACING_FIELDS[tune_index][1]).capitalize(), "down" if direction < 0.0 else "up"])


## Y: the pacing values from the files on disk again.
func _reset_pacing() -> void:
	for e in _monster_defs():
		var fresh: Resource = ResourceLoader.load(e[0], "", ResourceLoader.CACHE_MODE_IGNORE)
		for f in PACING_FIELDS:
			e[1].set(f[0], fresh.get(f[0]))
	_say("Monster pacing back to the files.")


## I: three skeletons in a line, 3 to 5 tiles ahead (where there is floor), to back away from or be flanked by.
func _spawn_pack() -> void:
	var player := get_tree().get_first_node_in_group("player")
	var dungeon := get_tree().get_first_node_in_group("dungeon")
	var forward: Vector2i = player.DIRS[player.facing]
	var made := 0
	for i in range(3, 6):
		var cell: Vector2i = player.cell + forward * i
		if DungeonMap.is_blocked(cell):
			break
		if not DungeonMap.is_occupied(cell) and not DungeonMap.is_stairs(cell):
			dungeon.spawn_monster(load(PACK_MONSTER), cell)
			made += 1
	_say("A pack of %d appears." % made if made > 0 else "No room ahead for a pack.")


## =: every lit light (in a hand or on the floor) burns down to its last few seconds.
func _burn_lights_down() -> void:
	var party := _party()
	var left := 10.0  # Inside the gutter time: the flame stutters and the hand bar blinks, then it goes out.
	var stacks: Array = party.held_lights() if party != null else []
	var lights := get_tree().get_first_node_in_group("lights")
	if lights != null:
		for e in lights.burning:
			stacks.append(e.stack)
	for stack in stacks:
		stack.burn_left = minf(stack.seconds_left(), left)
	_say("%d lights burn low." % stacks.size() if not stacks.is_empty() else "No light is burning.")


## -: play the next monster kind's hit effect across the view, cycling through the sides, without hurting anyone.
func _next_hit_effect() -> void:
	var defs := _monster_defs().filter(func(e): return str(e[1].get("hit_effect")) != "")
	var overlay := get_tree().get_first_node_in_group("hit_overlay")
	if defs.is_empty() or overlay == null:
		_say("No hit effects to show.")
		return
	var sides := ["front", "left", "right", "behind"]
	var def: Resource = defs[hit_fx_turn % defs.size()][1]
	var side: String = sides[(hit_fx_turn / defs.size()) % sides.size()]
	hit_fx_turn += 1
	overlay.play(def.hit_effect, side)
	_say("%s hit effect, from the %s." % [def.display_name, side])


## 9: put Hold Monster's status on the monster in front, for the spell's time, with no roll (to look at the effect and tune it).
func _hold_ahead() -> void:
	var player := get_tree().get_first_node_in_group("player")
	var m = DungeonMap.occupied.get(player.cell + player.DIRS[player.facing])
	if m == null or not is_instance_valid(m) or m.dying:
		_say("Nothing in front to hold.")
		return
	var spell: Resource = load(HOLD_SPELL)
	m.add_status(spell.applies_status, spell.status_seconds, -1)
	_say("The %s is held for %.1f s." % [str(m.def.display_name).to_lower(), spell.status_seconds])


## 0: every held monster is free again (the shatter plays).
func _free_all() -> void:
	var n := 0
	for m in get_tree().get_nodes_in_group("monsters"):
		if m.has_status("held"):
			m.remove_status("held")
			n += 1
	_say("%d monster%s freed." % [n, "" if n == 1 else "s"])


func _spring(a: Dictionary, index := 0) -> void:
	var dungeon := get_tree().get_first_node_in_group("dungeon")
	for m in a.monsters:
		if not DungeonMap.is_blocked(m.cell) and not DungeonMap.is_occupied(m.cell):
			dungeon.spawn_monster(load(m.def), m.cell)
	_say(a.text)
	# Banter: quiet for the whole fight, except the battle cry that starts it.
	ambush_active = true
	ambush_age = 0.0
	get_tree().call_group("banter", "set_quiet", "ambush", true)
	_banter("ambush_started", {"warned": warned.get(index, false)})


## The ambush's fight is over (GameEvents.fight_ended): banter may speak again, and the party reacts.
func _on_fight_ended() -> void:
	if ambush_active:
		_end_ambush(true)


func _end_ambush(react: bool) -> void:
	ambush_active = false
	get_tree().call_group("banter", "set_quiet", "ambush", false)
	if react:
		_banter("ambush_over", {})


func _banter(event_name: String, context: Dictionary) -> void:
	get_tree().call_group("banter", "event", event_name, context)


func _teleport(entry: Dictionary) -> void:
	var player := get_tree().get_first_node_in_group("player")
	if DungeonMap.is_occupied(entry.cell):
		_say("Something is standing there.")
		return
	get_tree().call_group("party_hud", "cancel_casting")
	player.restore(entry.cell, int(entry.facing))
	_say("Teleported to %s." % entry.name)


# --- Pop-up lists --------------------------------------------------------------------------------

func _open_spawn_list() -> void:
	var rows := []
	var dir := DirAccess.open(MONSTER_DIR)
	if dir == null:
		return
	var names := Array(dir.get_files()).filter(func(f): return f.ends_with(".tres") or f.ends_with(".tres.remap"))
	names.sort()
	for f in names:
		var path := "%s/%s" % [MONSTER_DIR, f.trim_suffix(".remap")]
		var def: Resource = load(path)
		var label: String = ("%s  T%d" % [str(def.display_name).to_upper(), int(def.get("tier")) if def.get("tier") != null else 1]) if def != null else f
		rows.append([label, _spawn.bind(path)])  # The tier: how likely a status effect lands (data/tiers.tres).
	_open_menu("SPAWN AHEAD", rows)


func _open_teleport_list() -> void:
	var rows := []
	for entry in DungeonMap.STATIONS:
		rows.append([str(entry.name).to_upper(), _teleport.bind(entry)])
	_open_menu("TELEPORT", rows)


func _open_menu(title: String, rows: Array) -> void:
	_close_menu()
	var popups := get_tree().get_first_node_in_group("popups")
	if popups == null:
		return
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _box(STONE_900, RUST_500))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	panel.add_child(box)
	var head := Label.new()
	head.text = title
	head.add_theme_font_override("font", FONT)
	head.add_theme_font_size_override("font_size", 8)
	head.add_theme_color_override("font_color", TORCH_300)
	box.add_child(head)
	rows.append(["CANCEL", Callable()])
	for row in rows:
		var b := Button.new()
		b.text = row[0]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_override("font", FONT)
		b.add_theme_font_size_override("font_size", 8)
		b.add_theme_color_override("font_color", BONE_300)
		b.add_theme_color_override("font_hover_color", TORCH_300)
		b.add_theme_stylebox_override("normal", _box(STONE_700, STONE_700))
		b.add_theme_stylebox_override("hover", _box(STONE_900, TORCH_300))
		b.add_theme_stylebox_override("pressed", _box(STONE_900, TORCH_300))
		var action: Callable = row[1]
		b.pressed.connect(func():
			_close_menu()
			if action.is_valid():
				action.call())
		box.add_child(b)
	menu = panel
	popups.open_popup(panel, func(size: Vector2): return Vector2((640.0 - size.x) / 2.0, (360.0 - size.y) / 2.0))


func _close_menu() -> void:
	if is_instance_valid(menu):
		menu.queue_free()
	menu = null


# --- Help overlay --------------------------------------------------------------------------------

func _build_help() -> void:
	help = PanelContainer.new()
	help.add_theme_stylebox_override("panel", _box(Color(STONE_900, 0.94), RUST_500))
	help.position = Vector2(16, 16)
	help.visible = false
	help.mouse_filter = Control.MOUSE_FILTER_IGNORE
	help_label = Label.new()
	help_label.add_theme_font_override("font", FONT)
	help_label.add_theme_font_size_override("font_size", 8)
	help_label.add_theme_color_override("font_color", BONE_300)
	help_label.add_theme_constant_override("line_spacing", 3)
	help.add_child(help_label)
	add_child(help)
	_refresh_help()


func _refresh_help() -> void:
	if help_label == null:
		return
	var party_has_xp := _party().has_method("add_xp")
	help_label.text = "\n".join([
		"TEST ROOM KEYS",
		"",
		"H   THIS HELP",
		"G   GOD MODE      %s" % _on(god),
		"R   REFILL HP AND MANA",
		"X   +500 XP       %s" % ("" if party_has_xp else "(NO XP YET)"),
		"U   LEVEL UP      %s" % ("" if party_has_xp else "(NO LEVELS YET)"),
		"Z   KILL ALL MONSTERS",
		"V   SPAWN MONSTER AHEAD",
		"T   TELEPORT TO STATION",
		"B   BANTER        %s" % _banter_status(),
		"N   FOG           %s" % _on(fog_on),
		"J   SCREEN SHAKE  %s" % _on(shake_on),
		"P   SHADOWS       %s" % _on(Settings.spell_shadows),
		"",
		"MONSTER PACING (NOT SAVED)",
		"I   PACK AHEAD    9 HOLD  0 FREE",
		"-   SHOW NEXT MONSTER HIT EFFECT",
		"=   BURN LIGHTS DOWN",
		"O   TUNE          %s" % PACING_FIELDS[tune_index][1],
		"[ ] -/+ 0.1S      Y FROM FILES",
		_pacing_table(),
		"",
		"FIGHT  %s" % _fight_status(),
		"F12 LEAVE (FLOOR 1)",
	])
	help.reset_size()


# --- Helpers -------------------------------------------------------------------------------------

## One row per monster kind: step interval, reaction delay, arrival recovery and flank delay, in seconds.
func _pacing_table() -> String:
	var rows := ["            STEP REACT RECOV FLANK"]
	for e in _monster_defs():
		var d: Resource = e[1]
		rows.append("%-11s %4.1f %5.1f %5.1f %5.1f" % [str(d.display_name).to_upper().left(11), d.step_interval, d.reaction_delay, d.arrival_recovery, d.flank_after])
	return "
".join(rows)


## What the banter node says: "ON", "OFF" or "ON  QUIET (ambush)" (some system has switched banter quiet).
func _banter_status() -> String:
	var b := get_tree().get_first_node_in_group("banter")
	return b.status() if b != null else _on(banter_on)


## What the fight tracker says: "OFF", or "ON  QUIET 2.1S  AWARE 1".
func _fight_status() -> String:
	var party := _party()
	if party == null or party.get("fight") == null:
		return "NO TRACKER"
	return party.fight.status()


func _on(v: bool) -> String:
	return "ON" if v else "OFF"


func _box(fill: Color, edge: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fill
	s.border_color = edge
	s.set_border_width_all(2)
	s.content_margin_left = 6
	s.content_margin_right = 6
	s.content_margin_top = 4
	s.content_margin_bottom = 4
	return s


func _party() -> Node:
	return get_tree().get_first_node_in_group("party")


func _feel() -> Resource:
	return load("res://data/combat_feel.tres")


func _say(text: String) -> void:
	get_tree().call_group("hud", "show_message", text)
