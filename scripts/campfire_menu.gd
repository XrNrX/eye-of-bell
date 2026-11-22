extends PanelContainer
## The campfire pop-up: left-click a campfire on the tile in front (Player.world_click -> Player._click_campfire) to choose what to do
## there. Same iron-bound frame and rows as the spell list and the loot pop-up, placed by popup_layer.gd.
##
## - MAKE CAMP (key 1): rest at the fire, the same camp as a bedroll makes (Party.camp_refusal says why not; no bedroll is used up).
## - COOK (n) (key 2): make camp and cook everything raw the party carries (Camp.cook_all); greyed when nothing is raw.
## - BREAK CAMP (key 3, only in the safe campfire zone a Hearth Coal opens, camp_zone.gd): back to the exact tile the party left.
## Esc or a click outside closes it, and it closes by itself if the party moves or turns.

signal closed

const FRAME := preload("res://art/ui/spell_frame.png")
const FRAME_MARGIN := 10          # Must match FRAME_MARGIN in tools/art/gen_spell_menu.py.
const ROW_HEIGHT := 20
const WIDTH := 152.0

const TEXT := Color("c9c0a4")      # Palette bone_300.
const TEXT_OFF := Color("504f5e")  # stone_500.
const KEY_COLOUR := Color("d99a36")  # torch_500.
const HEADING := Color("9c9278")   # bone_500.
const LINE := Color("4e2a1a")      # rust_700.
const ROW_HOVER := Color("31303c") # stone_700.
const ROW_EDGE := Color("d99a36")  # torch_500: the hovered row's marker.

var party: Node
var player: Node
var from_cell: Vector2i
var from_facing := 0
var raw_count := 0               # Raw items the party carries (what COOK would cook).
var camp_button: Button
var cook_button: Button
var break_button: Button         # null outside the safe campfire zone.


func setup(a_party: Node, a_player: Node) -> void:
	party = a_party
	player = a_player
	from_cell = player.cell
	from_facing = player.facing
	var camp = player.get_tree().get_first_node_in_group("camp")
	if camp != null:
		camp.party = party   # (cookables() reads it; begin() sets it again.)
		raw_count = camp.cookable_count()
	add_to_group("campfire_menu")
	var box := StyleBoxTexture.new()
	box.texture = FRAME
	box.set_texture_margin_all(FRAME_MARGIN)
	box.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	box.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	box.set_content_margin_all(FRAME_MARGIN + 2)
	add_theme_stylebox_override("panel", box)
	custom_minimum_size.x = WIDTH
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(col)
	col.add_child(_label("CAMPFIRE", HEADING))
	var rule := ColorRect.new()
	rule.color = LINE
	rule.custom_minimum_size = Vector2(0, 1)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(rule)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 3)
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(gap)
	camp_button = _row(col, "1", "MAKE CAMP", true)
	camp_button.pressed.connect(make_camp)
	cook_button = _row(col, "2", "COOK (%d)" % raw_count if raw_count > 0 else "COOK", raw_count > 0)
	cook_button.disabled = raw_count <= 0
	cook_button.pressed.connect(cook)
	if _zone().in_zone():
		break_button = _row(col, "3", "BREAK CAMP", true)
		break_button.pressed.connect(break_camp)


func _row(col: VBoxContainer, key: String, text: String, on: bool) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, ROW_HEIGHT)
	b.focus_mode = Control.FOCUS_NONE
	b.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS  # Act on the press, like every other click.
	for state in ["normal", "pressed", "disabled", "focus"]:
		b.add_theme_stylebox_override(state, _flat(Color(0, 0, 0, 0), false))
	b.add_theme_stylebox_override("hover", _flat(ROW_HOVER, true))
	col.add_child(b)
	var line := HBoxContainer.new()
	line.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	line.offset_left = 4
	line.offset_right = -4
	line.add_theme_constant_override("separation", 6)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(line)
	line.add_child(_label(key, KEY_COLOUR))
	line.add_child(_label(text, TEXT if on else TEXT_OFF))
	return b


func _label(text: String, colour: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 8)
	l.add_theme_color_override("font_color", colour)
	l.add_theme_color_override("font_shadow_color", Color("0b0a10"))  # ink, a 1 px shadow like the party panel's names.
	l.add_theme_constant_override("shadow_offset_x", 1)
	l.add_theme_constant_override("shadow_offset_y", 1)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _flat(colour: Color, marker: bool) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = colour
	if marker:  # The hovered row gets a torch-gold bar on its left edge.
		s.border_width_left = 2
		s.border_color = ROW_EDGE
	return s


## Make camp at the fire. Says why not when the party cannot rest here. Returns whether the camp began.
func make_camp() -> bool:
	if not _still_there():
		close()
		return false
	var why: String = party.camp_refusal()
	var camp = get_tree().get_first_node_in_group("camp")
	var began := false
	if why == "":
		if camp == null:
			why = "There is nowhere to rest."
		elif camp.begin():
			began = true
		else:
			why = "Nobody is left to rest."
	if not began:
		get_tree().call_group("hud", "show_message", why)
	close()
	return began


## Make camp and cook everything raw. Returns how many stacks were queued (0 if the camp did not begin).
func cook() -> int:
	if raw_count <= 0 or not make_camp():
		return 0
	var camp = get_tree().get_first_node_in_group("camp")
	return camp.cook_all()


func _zone() -> GDScript:
	return load("res://scripts/camp_zone.gd")   # (Loaded when needed: it reaches RunState and the party script.)


## Leave the safe campfire zone for the tile the party came from. Returns whether they went.
func break_camp() -> bool:
	if break_button == null or not _still_there():
		return false
	var camp = get_tree().get_first_node_in_group("camp")
	if camp != null and camp.active:
		camp.end()
	var tree := get_tree()
	close()
	_zone().go_back(tree)
	return true


## The party has not moved or turned since it opened.
func _still_there() -> bool:
	return player.cell == from_cell and int(player.facing) == from_facing


func close() -> void:
	if is_queued_for_deletion():
		return
	closed.emit()
	queue_free()


func _process(_delta: float) -> void:
	if not _still_there():
		close()


## Esc or a click outside closes it; 1 and 2 choose. Used up here, so the pause menu and the world click do not also act.
func _input(event: InputEvent) -> void:
	if is_queued_for_deletion():
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_ESCAPE:
			close()
			get_viewport().set_input_as_handled()
		elif event.physical_keycode == KEY_1 and not event.shift_pressed:
			make_camp()
			get_viewport().set_input_as_handled()
		elif event.physical_keycode == KEY_2 and not event.shift_pressed:
			cook()
			get_viewport().set_input_as_handled()
		elif event.physical_keycode == KEY_3 and not event.shift_pressed and break_button != null:
			break_camp()
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed and not get_global_rect().has_point(event.position):
		close()
		get_viewport().set_input_as_handled()
