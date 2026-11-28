extends Node
## PROTOTYPE (branch wip/rewind-test), not a real feature: turning time back, in the test room only. Added by test_room_tools.gd.
## It turns back THE PARTY AND THE ENEMIES NEAR IT, and nothing else:
## - the party: where it stands and faces, and each hero's condition (HP, mana, buffs, food and sickness, shaken, oiled, a web). Not
##   what they carry, so nothing is ever doubled or lost against the floor; cooldowns and recast waits are left as they are.
## - monsters within RADIUS tiles of the party (where they are now, or where they were then): their tile, HP, attack timer and
##   statuses; one killed since comes back. One that did not exist then is left alone, as are those further off.
## - never: doors, levers, plates, traps, puzzles, walls, braziers, sconces, oil, gas, floor items, run flags.
## Every SNAPSHOT_SECONDS of play it keeps that much in memory, the last 30 seconds of it (the systems' own save_state()); nothing
## is written to disk. Going back costs Fennick mana. His mana is NOT rewound: afterwards it is what he had when he asked, less the
## cost. It is refused if a sealed room, a shut door or another body stands between the party and where it was.
## Two ways in:
## - the spell: while this node is there, Rewind (data/debug/rewind.tres) is added to the spellbook. Cast, the world waits and a
##   pop-up lets the player step back and forth in STEP_SECONDS (or BIG_STEP_SECONDS) steps, the party and monsters shown as they
##   were at the moment picked, with its price (cost_of, through PRICES). Nothing is spent until TURN BACK; Cancel, Escape or a
##   right-click puts the present back. A step he can't pay for, or further than is remembered, is refused with the reason.
## - holding Backspace: STEP_SECONDS back for every STEP_SECONDS held, STEP_COST each, up to HOLD_MAX_STEPS, until released.

const DungeonMap := preload("res://scripts/dungeon_map.gd")
const SaveData := preload("res://scripts/save_data.gd")
const FONT := preload("res://art/fonts/PressStart2P-Regular.ttf")

## The spell's price: what going back this many seconds costs. In between, it is worked out along the line (rounded up).
const PRICES := [
	{"seconds": 0.0, "mana": 0.0},
	{"seconds": 5.0, "mana": 4.0},
	{"seconds": 10.0, "mana": 7.0},
	{"seconds": 30.0, "mana": 12.0},
]
const BIG_STEP_SECONDS := 5.0 # The pop-up's long step (and Shift with an arrow key).
const STEP_SECONDS := 0.5     # A held key's step.
const STEP_COST := 2.0
const HOLD_MAX_STEPS := 6     # A hold goes 3 seconds at most.
const SNAPSHOT_SECONDS := 0.5
const MEMORY_SECONDS := 30.0  # The furthest back.
const SHOW_SECONDS := 0.6     # How long the grey view stays after a cast.
const RADIUS := 20.0          # Tiles from the party within which monsters are turned back too.
const ID := "rewind_id"       # Metadata naming a monster, so the same one can be found again.
const REWIND_KEY := KEY_BACKSPACE
const CASTER := "mage"
const SPELL := "res://data/debug/rewind.tres"
const SPELLBOOK := "res://data/items/spellbook.tres"

const INK := Color("0b0a10")
const STONE_900 := Color("14131b")
const STONE_700 := Color("31303c")
const STONE_500 := Color("504f5e")
const RUST_500 := Color("7c4426")
const BONE_300 := Color("c9c0a4")
const TORCH_300 := Color("f5cf80")

## PLACEHOLDER effect, drawn in code (the rule is the VFX tool for anything kept): greyed out, with scanlines.
const SHADER := """
shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform float line_px = 2.0;
void fragment() {
	vec3 c = textureLod(screen_tex, SCREEN_UV, 0.0).rgb;
	float grey = dot(c, vec3(0.299, 0.587, 0.114));
	float line = step(line_px, mod(FRAGCOORD.y, line_px * 2.0));
	COLOR = vec4(mix(c, vec3(grey), 0.92) * mix(1.15, 0.55, line), 1.0);
}
"""

var snapshots: Array[Dictionary] = []  # Oldest first: {"at": `clock` when taken, "data": what record() keeps}.
var clock := 0.0             # Seconds of play (not counting pauses or camps); going back puts it back too.
var holding := false         # Backspace is being held.
var picker: Control          # The "how far?" pop-up, while it is open.
var picker_buttons := {}     # Its buttons: "back_big", "back", "on", "on_big", "confirm", "cancel".
var offset := 0.0            # Seconds back the pop-up is showing (0: the present).
var _picker_text: Label
var _present := {}           # The moment of the cast, to come back to.
var _cast_cell := Vector2i.ZERO
var _cast_mana := 0.0
var show_left := 0.0         # The grey view after a cast.
var steps := 0               # Steps taken in this hold.
var _record_clock := 0.0
var _next_id := 0
var _held_clock := 0.0
var _was_down := false
var _stopped := false        # This hold can go no further.
var _book_spells: Array[Resource] = []  # The spellbook's own list, put back on the way out.
var _effect: CanvasLayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("rewind")
	var book: Resource = load(SPELLBOOK)
	_book_spells = book.spells
	var with_rewind: Array[Resource] = _book_spells.duplicate()
	with_rewind.append(load(SPELL))
	book.spells = with_rewind  # Every spellbook is this one resource: only for as long as this node lives.


func _exit_tree() -> void:
	load(SPELLBOOK).spells = _book_spells
	if is_instance_valid(picker):
		picker.queue_free()


func _process(delta: float) -> void:
	var down := Input.is_physical_key_pressed(REWIND_KEY)
	if holding:
		if not down:
			end()
		else:
			_held_clock += delta
			if _held_clock >= STEP_SECONDS:
				_held_clock -= STEP_SECONDS
				step_back()
	elif show_left > 0.0:
		show_left -= delta
		if show_left <= 0.0:
			_release()
	elif picker != null:
		pass  # The world waits for an answer.
	elif down and not _was_down and not get_tree().paused:
		begin()
	elif not get_tree().paused:
		var camp := get_tree().get_first_node_in_group("camp")
		if camp != null and camp.active:
			snapshots.clear()  # A camp is not saved: no rewinding across one.
		else:
			clock += delta
			_record_clock += delta
			if _record_clock >= SNAPSHOT_SECONDS:
				_record_clock = fmod(_record_clock, SNAPSHOT_SECONDS)
				record()
	_was_down = down


func _input(event: InputEvent) -> void:
	if picker == null:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		get_viewport().set_input_as_handled()
		cancel()
		return
	if not (event is InputEventKey) or not event.pressed:
		return
	var by: float = BIG_STEP_SECONDS if event.shift_pressed else STEP_SECONDS
	match event.keycode:
		KEY_LEFT:
			step_picker(by)
		KEY_RIGHT:
			step_picker(-by)
		KEY_ENTER, KEY_KP_ENTER:
			if not event.echo:
				confirm()
		KEY_ESCAPE:
			if not event.echo:
				cancel()
		_:
			return
	get_viewport().set_input_as_handled()


## Keep the party and the monsters as they are now.
func record() -> void:
	var party := get_tree().get_first_node_in_group("party")
	var player := get_tree().get_first_node_in_group("player")
	if party == null or player == null or party.is_wiped():
		return
	snapshots.append({"at": clock, "data": _snapshot()})
	while snapshots.size() > 1 and float(snapshots[1].at) <= clock - MEMORY_SECONDS:
		snapshots.pop_front()  # Keep one at least as old as the furthest step.


## The party and the monsters as they are now, in memory.
func _snapshot() -> Dictionary:
	var party := get_tree().get_first_node_in_group("party")
	var player := get_tree().get_first_node_in_group("player")
	var monsters := []
	for m in get_tree().get_nodes_in_group("monsters"):
		if m.dying or m.is_queued_for_deletion():
			continue
		if not m.has_meta(ID):
			_next_id += 1
			m.set_meta(ID, _next_id)
		monsters.append({"id": m.get_meta(ID), "state": m.save_state()})
	var data := {"player": player.save_state(), "party": party.save_state(), "webbed": party.webbed_left, "monsters": monsters}
	# Through JSON, as a real save goes: an independent copy, and load_state sees just what it would from a file.
	return JSON.parse_string(JSON.stringify(data))


## How far back the memory goes, in seconds.
func remembered() -> float:
	return clock - float(snapshots[0].at) if not snapshots.is_empty() else 0.0


## Why going `seconds` back for `cost` mana can't be done now, or "" if it can.
func refusal(seconds := STEP_SECONDS, cost := STEP_COST) -> String:
	var mage = _caster()
	if mage == null or not mage.is_alive():
		return "Fennick is in no state to do that."
	if remembered() < seconds - SNAPSHOT_SECONDS * 0.5:
		return "Time will go no further back."
	if mage.mana < cost - 0.001:
		return "Fennick has no mana left for it."
	return ""


## Go `seconds` back at once (to the nearest moment remembered) and charge `cost`. False (and nothing changes) if it can't be done.
func go_back(seconds: float, cost: float) -> bool:
	var why := refusal(seconds, cost)
	if why != "":
		_say(why)
		return false
	var mana: float = _caster().mana
	var index := _index(seconds)
	var data: Dictionary = snapshots[index].data
	var barred := _barred(data)
	if barred != "":
		_say(barred)
		return false
	_restore(data, get_tree().get_first_node_in_group("player").cell)
	clock = float(snapshots[index].at)  # That moment is now.
	_record_clock = 0.0
	snapshots.resize(index + 1)
	_caster().mana = maxf(0.0, mana - cost)  # After the restore: his mana is not rewound.
	get_tree().call_group("audio", "play", "ui_click")
	return true


## The remembered moment nearest to `seconds` ago.
func _index(seconds: float) -> int:
	var target := clock - seconds
	var index := 0
	for i in snapshots.size():
		if absf(float(snapshots[i].at) - target) < absf(float(snapshots[index].at) - target):
			index = i
	return index


## Why the party can't be put back where this snapshot has it, or "" if it can: rewinding is no way through a seal or a shut door.
func _barred(data: Dictionary) -> String:
	var player := get_tree().get_first_node_in_group("player")
	var then := SaveData.data_to_cell(data.player.cell)
	if then == player.cell:
		return ""
	for id in DungeonMap.seals:
		if DungeonMap.area_has(id, then) != DungeonMap.area_has(id, player.cell):
			return "The seal will not let time through."
	if DungeonMap.is_blocked(then):
		return "Something now stands in the way."
	var holder = DungeonMap.occupied.get(then)
	if holder != null and is_instance_valid(holder) and not _moves_back(holder, data, player.cell):
		return "Something now stands in the way."
	return ""


## Will going back to this snapshot move this monster out of its tile?
func _moves_back(monster: Node, data: Dictionary, centre: Vector2i) -> bool:
	for e in data.monsters:
		if monster.has_meta(ID) and int(e.id) == int(monster.get_meta(ID)):
			return _near(centre, SaveData.data_to_cell(e.state.cell)) or _near(centre, monster.cell)
	return false


func _near(a: Vector2i, b: Vector2i) -> bool:
	return Vector2(a - b).length() <= RADIUS


## Put the party and the monsters near `centre` (where the spell is cast) back. Nothing else is touched, and nothing here counts as news (no plate or puzzle hears
## of it: dungeon.settled is false while it happens).
func _restore(data: Dictionary, centre: Vector2i) -> void:
	var dungeon := get_tree().get_first_node_in_group("dungeon")
	var party := get_tree().get_first_node_in_group("party")
	var player := get_tree().get_first_node_in_group("player")
	var live := {}
	for m in get_tree().get_nodes_in_group("monsters"):
		if m.has_meta(ID) and not m.is_queued_for_deletion():
			live[int(m.get_meta(ID))] = m
	var plan := []  # {"id", "state", "now": the tile it stands on now, or null if it is gone}
	for e in data.monsters:
		var id := int(e.id)
		var m: Node = live.get(id)
		if _near(centre, SaveData.data_to_cell(e.state.cell)) or (m != null and _near(centre, m.cell)):
			plan.append({"id": id, "state": e.state, "now": null if m == null or m.dying else m.cell, "node": m})
	dungeon.settled = false
	for p in plan:
		if p.node != null:
			p.node.free()  # At once, so its tile is free for whoever goes back there.
	player.load_state(data.player)
	for p in plan:
		var tile := SaveData.data_to_cell(p.state.cell)
		if DungeonMap.is_blocked(tile) or DungeonMap.is_occupied(tile) or tile == player.cell:
			tile = p.now if p.now != null else Vector2i(-1, -1)  # No room where it was: where it is now, if it was alive.
		if tile.x < 0 or DungeonMap.is_occupied(tile) or tile == player.cell or not ResourceLoader.exists(str(p.state.def)):
			continue
		var monster: Node = dungeon.spawn_monster(load(p.state.def), tile, int(p.state.hp), float(p.state.attack_cooldown))
		monster.load_state(p.state)
		monster.set_meta(ID, p.id)
	_restore_party(party, data)
	get_tree().call_group("curse_zones", "sync_silently")
	dungeon.settled = true


## Each hero's condition (not their gear) as the snapshot has it. (Like Party.load_state, but only the body.)
func _restore_party(party: Node, data: Dictionary) -> void:
	for h in data.party.heroes:
		for m in party.members:
			if m.hero_index != int(h.hero):
				continue
			m.hp = clampi(int(h.hp), 0, m.def.max_hp)
			m.mana = clampf(float(h.mana), 0.0, float(m.def.max_mana))
			var alive: bool = m.hp > 0
			m.shaken_left = float(h.get("shaken", 0.0)) if alive else 0.0
			m.oiled_hits = int(h.get("oiled", 0)) if alive else 0
			var food: Dictionary = h.get("food", {})
			m.food_left = float(food.get("left", 0.0)) if alive else 0.0
			m.food_rate = float(food.get("rate", 0.0))
			m.sick_left = float(food.get("sick_left", 0.0)) if alive else 0.0
			m.sick_rate = float(food.get("sick_rate", 0.0))
			m.buffs.clear()
			for b in h.buffs:
				if ResourceLoader.exists(str(b.spell)):
					m.buffs.append({"spell": load(b.spell), "left": float(b.left)})
			party.hp_changed.emit(m.slot)
	party.webbed_left = float(data.webbed)
	party.sync_light_level()


# --- Holding Backspace ----------------------------------------------------------------------------

func begin() -> void:
	holding = true
	steps = 0
	_stopped = false
	_held_clock = 0.0
	get_tree().paused = true  # The world waits while time runs backward.
	_show_effect()


func end() -> void:
	holding = false
	_release()
	if steps > 0:
		_say("Time runs on. %.1f s turned back, %d mana." % [steps * STEP_SECONDS, int(steps * STEP_COST)])


## One more step of a hold. False at the end of the memory or out of mana (said once).
func step_back() -> bool:
	if _stopped or steps >= HOLD_MAX_STEPS:
		return false
	if not go_back(STEP_SECONDS, STEP_COST):
		_stopped = true
		return false
	steps += 1
	_say("Rewind %.1f s." % (steps * STEP_SECONDS))
	return true


# --- The spell ------------------------------------------------------------------------------------

## What going back this many seconds costs.
func cost_of(seconds: float) -> float:
	if seconds <= 0.0:
		return 0.0
	for i in range(1, PRICES.size()):
		var a: Dictionary = PRICES[i - 1]
		var b: Dictionary = PRICES[i]
		if seconds <= b.seconds or i == PRICES.size() - 1:
			return ceilf(lerpf(a.mana, b.mana, (seconds - a.seconds) / (b.seconds - a.seconds)) - 0.001)
	return 0.0


## Cast: open the pop-up on the present. False (nothing spent) if not even one step can be taken.
func cast() -> bool:
	if holding or picker != null or get_tree().paused:
		return false
	var why := refusal(STEP_SECONDS, cost_of(STEP_SECONDS))  # Not even one step: no pop-up.
	if why != "":
		_say(why)
		return false
	var popups := get_tree().get_first_node_in_group("popups")
	if popups == null:
		return false
	get_tree().paused = true
	offset = 0.0
	_present = _snapshot()
	_cast_cell = get_tree().get_first_node_in_group("player").cell
	_cast_mana = _caster().mana
	picker = _build_picker()
	_refresh_picker()
	# Low in the view, so the moment being picked can be seen above it.
	popups.open_popup(picker, func(size: Vector2): return Vector2(320.0 - size.x / 2.0, 266.0 - size.y))
	return true


## Why the pop-up can't show `seconds` back, or "" if it can (judged on Fennick as he cast).
func _limit(seconds: float) -> String:
	if seconds > MEMORY_SECONDS + 0.001 or remembered() < seconds - SNAPSHOT_SECONDS * 0.5:
		return "Time will go no further back."
	if _cast_mana < cost_of(seconds) - 0.001:
		return "Fennick has no mana left for it."
	return ""


## Step the pop-up `by` seconds further back (negative: towards the present). A long step goes as far as it may. Moments the
## party can't be put back into are passed over. False if it can't move at all.
func step_picker(by: float) -> bool:
	if picker == null:
		return false
	var way := signf(by)
	var target := maxf(0.0, offset + by)
	var why := ""
	while target > offset and _limit(target) != "":
		why = _limit(target)
		target -= STEP_SECONDS
	while not is_equal_approx(target, offset) and target > -0.001 and (way < 0.0 or _limit(target) == ""):
		var barred := _show_moment(target)
		if barred == "":
			offset = maxf(0.0, target)
			_refresh_picker()
			get_tree().call_group("audio", "play", "ui_click")
			return true
		why = barred
		target += way * STEP_SECONDS
	_show_moment(offset)  # Stay where it was.
	_refresh_picker()
	if why != "":
		_say(why)
	return false


## Show the party and the monsters as they were `seconds` ago (0: the present). "" if shown, else why not (the present is shown).
func _show_moment(seconds: float) -> String:
	_show_present()
	if seconds < STEP_SECONDS * 0.5:
		_hide_effect()
		return ""
	var data: Dictionary = snapshots[_index(seconds)].data
	var barred := _barred(data)
	if barred != "":
		_hide_effect()
		return barred
	_restore(data, _cast_cell)
	_caster().mana = maxf(0.0, _cast_mana - cost_of(seconds))  # What he would be left with.
	_show_effect()
	return ""


## Put the moment of the cast back, taking away anything a look into the past brought back.
func _show_present() -> void:
	var then := {}
	for e in _present.monsters:
		then[int(e.id)] = true
	for m in get_tree().get_nodes_in_group("monsters"):
		if m.has_meta(ID) and not then.has(int(m.get_meta(ID))) and not m.is_queued_for_deletion():
			m.free()
	_restore(_present, _cast_cell)
	_caster().mana = _cast_mana


## TURN BACK: keep the moment shown, pay for it and let time run.
func confirm() -> void:
	if picker == null:
		return
	if offset <= 0.0:
		_say("Step back first.")
		get_tree().call_group("audio", "play", "ui_click")
		return
	var index := _index(offset)
	var seconds := offset
	clock = float(snapshots[index].at)  # That moment is now.
	_record_clock = 0.0
	snapshots.resize(index + 1)
	_close_picker()
	_say("Time turns back %.1f s." % seconds)
	get_tree().call_group("audio", "play", "ui_click")
	_show_effect()
	show_left = SHOW_SECONDS
	var mage = _caster()
	if mage != null and mage.is_alive():
		get_tree().get_first_node_in_group("party")._start_cooldown(mage)


## Close the pop-up without rewinding: the present is put back and nothing is spent.
func cancel() -> void:
	if picker == null:
		return
	if offset > 0.0:
		_show_present()
		offset = 0.0
	_close_picker()
	_release()


func _close_picker() -> void:
	if is_instance_valid(picker):
		picker.queue_free()
	picker = null
	picker_buttons.clear()
	_present = {}


func _release() -> void:
	show_left = 0.0
	_record_clock = 0.0
	get_tree().paused = false
	_hide_effect()


func _hide_effect() -> void:
	if _effect != null:
		_effect.queue_free()
		_effect = null


func _build_picker() -> Control:
	var panel := PanelContainer.new()
	panel.process_mode = Node.PROCESS_MODE_ALWAYS  # Its buttons work while the world waits.
	panel.add_theme_stylebox_override("panel", _box(STONE_900, RUST_500))
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 2)
	panel.add_child(column)
	_picker_text = Label.new()
	_picker_text.add_theme_font_override("font", FONT)
	_picker_text.add_theme_font_size_override("font_size", 8)
	_picker_text.add_theme_color_override("font_color", TORCH_300)
	column.add_child(_picker_text)
	picker_buttons.clear()
	var steps_row := HBoxContainer.new()
	steps_row.add_theme_constant_override("separation", 2)
	column.add_child(steps_row)
	for s in [["back_big", "<<5", BIG_STEP_SECONDS], ["back", "<.5", STEP_SECONDS], ["on", ".5>", -STEP_SECONDS],
			["on_big", "5>>", -BIG_STEP_SECONDS]]:
		var b := _button(s[1])
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.pressed.connect(step_picker.bind(s[2]))
		steps_row.add_child(b)
		picker_buttons[s[0]] = b
	for s in [["confirm", "TURN BACK", confirm], ["cancel", "CANCEL", cancel]]:
		var b := _button(s[1])
		b.alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.pressed.connect(s[2])
		column.add_child(b)
		picker_buttons[s[0]] = b
	return panel


func _refresh_picker() -> void:
	_picker_text.text = "BACK %4.1f S\nCOST %2d OF %2d MANA\nKEPT %4.1f S" % [
			offset, int(cost_of(offset)), floori(_cast_mana), minf(remembered(), MEMORY_SECONDS)]
	# Greyed, but still buttons: clicking one says why not.
	for id in ["back", "back_big"]:
		_grey(picker_buttons[id], _limit(offset + STEP_SECONDS) != "")
	for id in ["on", "on_big", "confirm"]:
		_grey(picker_buttons[id], offset <= 0.0)


func _grey(b: Button, grey: bool) -> void:
	b.add_theme_color_override("font_color", STONE_500 if grey else BONE_300)
	b.add_theme_color_override("font_hover_color", STONE_500 if grey else TORCH_300)
	b.add_theme_stylebox_override("normal", _box(STONE_900, STONE_900) if grey else _box(STONE_700, STONE_700))


func _button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", FONT)
	b.add_theme_font_size_override("font_size", 8)
	b.add_theme_color_override("font_color", BONE_300)
	b.add_theme_color_override("font_hover_color", TORCH_300)
	b.add_theme_stylebox_override("normal", _box(STONE_700, STONE_700))
	b.add_theme_stylebox_override("hover", _box(STONE_900, TORCH_300))
	b.add_theme_stylebox_override("pressed", _box(STONE_900, TORCH_300))
	return b


func _box(fill: Color, edge: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fill
	s.border_color = edge
	s.set_border_width_all(2)
	s.content_margin_left = 6
	s.content_margin_right = 6
	s.content_margin_top = 3
	s.content_margin_bottom = 3
	return s


# --------------------------------------------------------------------------------------------------

func _caster() -> Variant:
	var party := get_tree().get_first_node_in_group("party")
	if party != null:
		for m in party.members:
			if m.class_id() == CASTER:
				return m
	return null


func _show_effect() -> void:
	var dungeon := get_tree().get_first_node_in_group("dungeon")
	if dungeon == null or _effect != null:
		return
	var port: Viewport = dungeon.get_viewport()
	_effect = CanvasLayer.new()
	_effect.layer = 101  # Over everything in the 3D view, the palette filter (100) too.
	_effect.process_mode = Node.PROCESS_MODE_ALWAYS
	var copy := BackBufferCopy.new()
	copy.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	_effect.add_child(copy)
	var rect := ColorRect.new()
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = SHADER
	var material := ShaderMaterial.new()
	material.shader = shader
	var view: Node = port.get_parent()
	material.set_shader_parameter("line_px", float(view.get_meta("view_scale", 1)) if view != null else 1.0)
	rect.material = material
	_effect.add_child(rect)
	port.add_child(_effect)


func _say(text: String) -> void:
	get_tree().call_group("hud", "show_message", text)
