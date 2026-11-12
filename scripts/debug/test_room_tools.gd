extends CanvasLayer
## Debug tools: F12 opens or leaves the test room, and inside it the debug keys and a toggleable help overlay (H).
## Debug builds only: game_view.gd adds this node when DungeonMap.test_room_available() says so, and this file (with the whole
## scripts/debug folder and levels/) is left out of release exports (export_presets.cfg exclude_filter).
##
## Keys (only inside the test room, so they never clash with play): H help, G god mode, R refill HP and mana, X +500 XP,
## U level up the party, Z kill all monsters, V spawn a monster in front (a pop-up list), T teleport to a station (a pop-up
## list), B banter, N fog, J screen shake, P spell and torch shadows. X and U wait for an XP system: they call Party.add_xp / Party.level_up_party when
## those exist and say so in the log until then. A new system gets a station in levels/test_room.gd and, if it needs one, a key here.
##
## The ambush corridor is a stand-in: stepping on a trigger tile in DungeonMap.AMBUSHES spawns its monsters.

const DungeonMap := preload("res://scripts/dungeon_map.gd")
const Settings := preload("res://scripts/settings.gd")
const SpellEffectsConfigScript := preload("res://scripts/spell_effects_config.gd")
const FONT := preload("res://art/fonts/PressStart2P-Regular.ttf")
const MONSTER_DIR := "res://data/monsters"

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
var last_cell := Vector2i(-99, -99)


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
	_build_help()
	_say("Test room. H shows the debug keys.")


func _process(delta: float) -> void:
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
		if last_cell == a.trigger and armed.get(i, false):
			armed[i] = false
			_spring(a)
		elif absi(d.x) + absi(d.y) > 8:
			armed[i] = true


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
		_:
			handled = false
	if handled:
		get_viewport().set_input_as_handled()
		_refresh_help()


# --- Actions -------------------------------------------------------------------------------------

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


func _spring(a: Dictionary) -> void:
	var dungeon := get_tree().get_first_node_in_group("dungeon")
	for m in a.monsters:
		if not DungeonMap.is_blocked(m.cell) and not DungeonMap.is_occupied(m.cell):
			dungeon.spawn_monster(load(m.def), m.cell)
	_say(a.text)


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
		rows.append([str(def.display_name).to_upper() if def != null else f, _spawn.bind(path)])
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
		"FIGHT  %s" % _fight_status(),
		"F12 LEAVE (FLOOR 1)",
	])
	help.reset_size()


# --- Helpers -------------------------------------------------------------------------------------

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
