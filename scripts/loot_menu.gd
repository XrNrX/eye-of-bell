extends PanelContainer
## The loot pop-up: right-click an item on the floor tile in front (Player.world_right_click) and choose who carries it. Same
## iron-bound frame and rows as the spell list (spell_menu.gd), placed next to the mouse by popup_layer.gd.
##
## - The top of the pile's name and icon at the top, then one row per hero (Party.carry_order: the living in party order, the dead
##   last: their bodies are being dragged anyway): hotkey, portrait, name, "can't use" (greyed, ItemDef.cant_use) and the room in
##   their backpack ("3 FREE", "STACKS" if only a matching stack has room, "FULL", which disables the row).
## - Clicking a row (or its key, 1-4) sends the item straight into that hero's backpack, matching stacks first
##   (Party.pack_into): "Wren stows the dagger."
## - With several items on the tile a "Take all" row shares the whole pile out (Party.share_out) and reports where it went.
## - Esc or a click anywhere outside closes it. It closes by itself if the party moves or turns, or the pile changes.
## Left click (onto the cursor) and shift-click (quick slot or backpack) on a floor item are unchanged (player.gd).

signal closed

const Events := preload("res://scripts/game_events.gd")
const ItemDef := preload("res://scripts/item_def.gd")
const FRAME := preload("res://art/ui/spell_frame.png")
const FRAME_MARGIN := 10          # Must match FRAME_MARGIN in tools/art/gen_spell_menu.py.
const ICON_SIZE := 16
const ROW_HEIGHT := 20
const WIDTH := 264.0

const TEXT := Color("c9c0a4")      # Palette bone_300.
const TEXT_OFF := Color("504f5e")  # stone_500.
const KEY_COLOUR := Color("d99a36")  # torch_500, like the spell costs.
const HEADING := Color("9c9278")   # bone_500.
const LINE := Color("4e2a1a")      # rust_700.
const ROW_HOVER := Color("31303c") # stone_700.
const ROW_EDGE := Color("d99a36")  # torch_500: the hovered row's marker.
const ICON_OFF := Color(0.5, 0.5, 0.55)

var party: Node
var dungeon: Node
var player: Node
var cell: Vector2i
var stack: RefCounted        # The item offered (the top of the pile when it opened).
var pile_size := 0
var from_cell: Vector2i      # Where the party stood, and which way it faced, when it opened.
var from_facing := 0
var rows := []               # [{button, member, room, usable}], in the order shown (hotkeys 1-4).
var take_all_button: Button  # null with a single item on the tile.


func setup(a_party: Node, a_dungeon: Node, a_player: Node, a_cell: Vector2i) -> void:
	party = a_party
	dungeon = a_dungeon
	player = a_player
	cell = a_cell
	stack = dungeon.item_at(cell)
	pile_size = dungeon.pile_at(cell).size()
	from_cell = player.cell
	from_facing = player.facing
	add_to_group("loot_menu")
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
	head.add_child(_icon(stack.def.icon, true))
	head.add_child(_label(stack.def.display_name.to_upper(), HEADING, true))
	if stack.count > 1:
		head.add_child(_label("x%d" % stack.count, KEY_COLOUR, false))
	var rule := ColorRect.new()  # A thin rusted rule under the heading, as on the spell list.
	rule.color = LINE
	rule.custom_minimum_size = Vector2(0, 1)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(rule)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 3)
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(gap)

	for m in party.carry_order():
		var room: String = party.pack_room_text(m, stack)
		var usable: bool = party.can_equip(m, stack.def)
		var b := _row(col)
		var line: HBoxContainer = b.get_child(0)
		line.add_child(_label(str(rows.size() + 1) if rows.size() < 4 else " ", KEY_COLOUR, false))
		line.add_child(_icon(m.def.portrait if m.is_alive() else m.def.portrait_dead, m.is_alive()))
		var name_label := _label(m.short_name(), TEXT if usable else TEXT_OFF, true)
		line.add_child(name_label)
		line.add_child(_label("" if usable else "CAN'T USE", TEXT_OFF, false))
		var room_label := _label(room, TEXT if room != "FULL" else TEXT_OFF, false)
		room_label.custom_minimum_size.x = 56
		room_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		line.add_child(room_label)
		b.disabled = room == "FULL"
		var index := rows.size()
		b.pressed.connect(func(): choose(index))
		rows.append({"button": b, "member": m, "room": room, "usable": usable})
	if pile_size > 1:
		var rule2 := ColorRect.new()
		rule2.color = LINE
		rule2.custom_minimum_size = Vector2(0, 1)
		rule2.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(rule2)
		take_all_button = _row(col)
		take_all_button.get_child(0).add_child(_label("TAKE ALL (%d)" % pile_size, TEXT, true))
		take_all_button.pressed.connect(take_all)


func _row(col: VBoxContainer) -> Button:
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
	line.add_theme_constant_override("separation", 5)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(line)
	return b


func _icon(tex: Texture2D, bright: bool) -> TextureRect:
	var icon := TextureRect.new()
	icon.texture = tex
	icon.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_SCALE
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.modulate = Color.WHITE if bright else ICON_OFF
	return icon


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


## Send the item to the hero on row `index` (0-based, as shown). Ignored for a full backpack.
func choose(index: int) -> void:
	if index < 0 or index >= rows.size() or rows[index].button.disabled or not _still_there():
		return
	var m = rows[index].member
	var had: int = stack.count
	var moved: int = party.pack_into(m, stack)
	if moved > 0:
		_picked_up(stack.def, moved)
		if stack.count <= 0:
			dungeon.take_item(cell)
		var item: String = stack.def.display_name.to_lower()
		var text := "%s stows the %s." % [m.name(), item] if had == 1 else "%s stows %d %s." % [m.name(), moved, item]
		if stack.count > 0:
			text += " (Some won't fit.)"
		_say(text)
	close()


## Share the whole pile out (Party.share_out) and say who took what.
func take_all() -> void:
	if not _still_there():
		close()
		return
	var pile: Array = dungeon.pile_at(cell)
	pile.reverse()  # Top first: the item the menu shows goes first.
	var counts := {}
	for s in pile:
		counts[s] = s.count
	var report: String = party.share_out(pile)
	for s in pile:
		if s.count < counts[s]:
			_picked_up(s.def, counts[s] - s.count)
	var left: Array = dungeon.pile_at(cell).filter(func(s): return s.count > 0)
	dungeon.set_pile(cell, left)
	_say(report)
	close()


func _picked_up(def: Resource, count: int) -> void:
	Events.send(get_tree(), "item_picked_up", [def, count])
	get_tree().call_group("audio", "play", "pickup")
	if def.type == ItemDef.Type.KEY:
		get_tree().call_group("hud", "show_banner", "Key picked up!")


func _say(text: String) -> void:
	get_tree().call_group("hud", "show_message", text)


## The party hasn't moved and the item it offered is still the top of the pile.
func _still_there() -> bool:
	return player.cell == from_cell and int(player.facing) == from_facing and dungeon.item_at(cell) == stack \
			and dungeon.pile_at(cell).size() == pile_size


func close() -> void:
	if is_queued_for_deletion():
		return
	closed.emit()
	queue_free()


func _process(_delta: float) -> void:
	if not _still_there():
		close()


## Esc or a click outside closes it; 1-4 pick heroes. All of them are used up here, so the pause menu, the quick-slot keys and the
## world click under the mouse don't also act on them (player.gd skips its 1-8 keys while this is open).
func _input(event: InputEvent) -> void:
	if is_queued_for_deletion():
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_ESCAPE:
			close()
			get_viewport().set_input_as_handled()
		elif event.physical_keycode >= KEY_1 and event.physical_keycode <= KEY_4 and not event.shift_pressed:
			choose(event.physical_keycode - KEY_1)
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed and not get_global_rect().has_point(event.position):
		close()
		get_viewport().set_input_as_handled()
