extends PanelContainer
## The item pop-up: double-click an item in the inventory (a backpack cell, a quick slot, a hand or the armour) for its options. Same iron-bound
## frame and rows as the spell list and the loot pop-up, placed next to the slot by popup_layer.gd (the inventory pauses the game, so this
## runs while paused).
##
## - DROP (key 1): the whole stack onto the floor in front of the party (greyed when there is nowhere to drop it).
## - COMBINE (n) (key 2): merge every stack of the same item in this hero's backpack and quick slots into as few as possible (Party.combine_stacks);
##   greyed when there is no other stack to merge with.
## Esc or a click outside closes it; it closes by itself when the item moves, the inventory closes or another hero is shown.

signal closed

const FRAME := preload("res://art/ui/spell_frame.png")
const FRAME_MARGIN := 10          # Must match FRAME_MARGIN in tools/art/gen_spell_menu.py.
const ICON_SIZE := 16
const ROW_HEIGHT := 20
const WIDTH := 152.0

const TEXT := Color("c9c0a4")      # Palette bone_300.
const TEXT_OFF := Color("504f5e")  # stone_500.
const KEY_COLOUR := Color("d99a36")  # torch_500.
const HEADING := Color("9c9278")   # bone_500.
const LINE := Color("4e2a1a")      # rust_700.
const ROW_HOVER := Color("31303c") # stone_700.
const ROW_EDGE := Color("d99a36")  # torch_500: the hovered row's marker.

var screen: Node          # The InventoryScreen.
var slot_node: Node       # The InventorySlot the item is in.
var stack: RefCounted     # The stack the menu is about.
var member_slot := 0
var combinable := 0       # How many stacks (counting this one) COMBINE would work on; below 2 there is nothing to do.
var drop_button: Button
var combine_button: Button


func setup(a_screen: Node, a_slot: Node) -> void:
	screen = a_screen
	slot_node = a_slot
	stack = a_slot.get_item()
	member_slot = a_slot.member_slot
	var packed: bool = a_slot.kind == a_slot.Kind.BACKPACK or a_slot.kind == a_slot.Kind.QUICK
	combinable = screen.party.matching_stacks(member_slot, stack).size() if packed else 0
	process_mode = Node.PROCESS_MODE_ALWAYS   # The inventory has paused the game.
	add_to_group("item_menu")
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
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 6)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(head)
	var icon := TextureRect.new()
	icon.texture = stack.def.shown_icon()
	icon.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_SCALE
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(icon)
	head.add_child(_label(stack.def.display_name.to_upper(), HEADING, true))
	if stack.count > 1:
		head.add_child(_label("x%d" % stack.count, KEY_COLOUR, false))
	var rule := ColorRect.new()
	rule.color = LINE
	rule.custom_minimum_size = Vector2(0, 1)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(rule)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 3)
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(gap)
	var can_drop: bool = screen.can_drop_on_floor()
	drop_button = _row(col, "1", "DROP", can_drop)
	drop_button.disabled = not can_drop
	drop_button.pressed.connect(drop)
	var combine_text := "COMBINE (%d)" % combinable if combinable >= 2 else "COMBINE"
	combine_button = _row(col, "2", combine_text, combinable >= 2)
	combine_button.disabled = combinable < 2
	combine_button.pressed.connect(combine)


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
	line.add_child(_label(key, KEY_COLOUR, false))
	line.add_child(_label(text, TEXT if on else TEXT_OFF, false))
	return b


func _label(text: String, colour: Color, expand: bool) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 8)
	l.add_theme_color_override("font_color", colour)
	l.add_theme_color_override("font_shadow_color", Color("0b0a10"))  # ink, a 1 px shadow like the party panel's names.
	l.add_theme_constant_override("shadow_offset_x", 1)
	l.add_theme_constant_override("shadow_offset_y", 1)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if expand:
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


func _flat(colour: Color, marker: bool) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = colour
	if marker:  # The hovered row gets a torch-gold bar on its left edge.
		s.border_width_left = 2
		s.border_color = ROW_EDGE
	return s


## Drop the whole stack on the floor in front of the party. Returns whether it was dropped.
func drop() -> bool:
	if not _still_there() or not screen.can_drop_on_floor():
		close()
		return false
	var who: String = screen.party.member(member_slot).name()
	var name_text: String = stack.def.display_name.to_lower()
	var count: int = stack.count
	slot_node.set_item(null)
	slot_node._changed()
	screen.drop_on_floor(stack)
	get_tree().call_group("audio", "play", "drop")
	screen.say("%s drops %d %s." % [who, count, name_text] if count > 1 else "%s drops the %s." % [who, name_text])
	close()
	return true


## Merge every stack of this item in the hero's pack and quick slots. Returns how many stacks that freed.
func combine() -> int:
	if not _still_there() or combinable < 2:
		close()
		return 0
	var who: String = screen.party.member(member_slot).name()
	var name_text: String = stack.def.display_name.to_lower()
	var freed: int = screen.party.combine_stacks(member_slot, stack)
	get_tree().call_group("audio", "play", "drop")
	if freed > 0:
		screen.say("%s combines the %s: %d stack%s freed." % [who, name_text, freed, "" if freed == 1 else "s"])
	else:
		screen.say("The %s stacks are already as full as they go." % name_text)
	close()
	screen.refresh()
	return freed


## The item is still in its slot, the inventory is open on the same hero.
func _still_there() -> bool:
	return is_instance_valid(screen) and screen.visible and screen.focused_slot == member_slot and slot_node.get_item() == stack


func close() -> void:
	if is_queued_for_deletion():
		return
	closed.emit()
	queue_free()


func _process(_delta: float) -> void:
	if not _still_there():
		close()


## Esc or a click outside closes it (and nothing else acts on that press); 1 and 2 choose.
func _input(event: InputEvent) -> void:
	if is_queued_for_deletion():
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_ESCAPE:
			close()
			get_viewport().set_input_as_handled()
		elif event.physical_keycode == KEY_1 and not event.shift_pressed:
			drop()
			get_viewport().set_input_as_handled()
		elif event.physical_keycode == KEY_2 and not event.shift_pressed:
			combine()
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed and not get_global_rect().has_point(event.position):
		close()
		get_viewport().set_input_as_handled()
