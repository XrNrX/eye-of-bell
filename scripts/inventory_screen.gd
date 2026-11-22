extends CanvasLayer
## The inventory screen: opened by clicking a character portrait (on the main party
## HUD, or the character strip inside here) via the "inventory" group's show_screen.
## Shows one "focused" member's two hand slots, their armour slot, their two quick slots and a backpack
## grid, plus a strip of every member's portrait.
##
## Eye-of-the-Beholder click-to-click, one system: the cursor (cursor_item.gd) is the
## hand. Click a slot to pick its item up, click a slot to put it down (swapping if
## occupied), click a portrait to put it in that member's backpack (or, empty-handed,
## to switch to them), click outside the window to drop it on the floor in front.
## The clicks live in inventory_slot.gd and inventory_floor_drop.gd; this script
## builds the slots once and owns "which member is focused" and the status line.
##
## DISCARD (under the backpack): click it with an item on the cursor to drop that item on the floor in front of the party (the same as clicking
## outside the window), so a full pack is never a trap and nothing is lost: it can be picked up again.
##
## Pure data for now: what's equipped doesn't affect combat yet, the same way
## MonsterDef/ItemDef's stat fields existed before anything read them.

const InventorySlotScript := preload("res://scripts/inventory_slot.gd")
const PartyScript := preload("res://scripts/party.gd")
const DungeonMap := preload("res://scripts/dungeon_map.gd")
const CharacterSheet := preload("res://scripts/character_sheet.gd")
const ItemMenu := preload("res://scripts/item_menu.gd")
const NAME_MAX_WIDTH := 150.0  # The header name wraps beyond this many units (see refresh).

@onready var backdrop: ColorRect = %Backdrop
@onready var name_label: Label = %NameLabel
@onready var hp_label: Label = %HpLabel
@onready var strip_box: HBoxContainer = %Strip
@onready var hands_box: HBoxContainer = %Hands
@onready var backpack_grid: GridContainer = %Backpack
@onready var close_button: Button = %CloseButton
@onready var status_label: Label = %StatusLabel

var party: Node
var cursor: Node
var dungeon: Node
var player: Node3D

var focused_slot := 0
var strip_slots := []     # CHARACTER-kind InventorySlot, one per party member.
var hand_slots := []      # HAND-kind InventorySlot, re-pointed to whoever's focused.
var armour_slot: Panel
var quick_slots := []     # QUICK-kind InventorySlot: the member's two quick slots (the ones under their portrait on the party panel).
var backpack_slots := []  # BACKPACK-kind InventorySlot, likewise re-pointed.
var sheet: PanelContainer  # The character sheet beside the window (character_sheet.gd).
var last_pick_slot: Control    # The slot the cursor last picked an item up from, and what it picked (for a double-click: inventory_slot._open_menu).
var last_pick_stack: RefCounted
var discard_button: Button  # Under the backpack: drops the item on the cursor on the floor in front.
@onready var window: Control = $Center/Window
const StonePanel := preload("res://scripts/stone_panel.gd")


func _ready() -> void:
	window.add_theme_stylebox_override("panel", StonePanel.make())
	add_to_group("inventory")
	process_mode = Node.PROCESS_MODE_ALWAYS  # Clicks keep working while paused.
	visible = false
	backdrop.screen = self
	close_button.pressed.connect(hide_screen)
	# The name in the header opens/closes the character sheet.
	name_label.mouse_filter = Control.MOUSE_FILTER_STOP
	name_label.tooltip_text = "Character sheet"
	name_label.gui_input.connect(_on_name_input)
	sheet = CharacterSheet.new()
	sheet.visible = false
	add_child(sheet)
	# Deferred: siblings declared after us (e.g. Party) haven't necessarily run their
	# own _ready() yet -- call_deferred waits until this frame's ready pass is done,
	# correct regardless of node order (see player.gd for the bug this avoided).
	call_deferred("_find_singletons")


func _find_singletons() -> void:
	party = get_tree().get_first_node_in_group("party")
	cursor = get_tree().get_first_node_in_group("cursor")
	dungeon = get_tree().get_first_node_in_group("dungeon")
	player = get_tree().get_first_node_in_group("player")
	_build_slots()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		hide_screen()
		get_viewport().set_input_as_handled()  # So the pause menu doesn't also open.
		return
	# I opens the inventory (for the hero whose panel the mouse is over, else the one you last looked at, with the sheet beside
	# it like a portrait click; closes it when it is showing). C opens the character sheet (for the hero whose panel the mouse is over, else the one you last
	# looked at; closes it when it is showing). Shift+1 to Shift+4 open each hero's sheet directly, by
	# position on the party panel. Not while another screen (pause menu, Level complete, Game over)
	# owns the paused game.
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if get_tree().paused and not visible:
		return
	var slot := -1
	if event.physical_keycode == KEY_I and not event.shift_pressed and not event.ctrl_pressed and not event.alt_pressed:
		if visible:
			hide_screen()
			get_viewport().set_input_as_handled()
			return
		slot = focused_slot
		var ihud := get_tree().get_first_node_in_group("party_hud")
		if ihud != null:
			var over_i: int = ihud.slot_under_mouse()
			if over_i >= 0:
				slot = over_i
	elif event.physical_keycode == KEY_C and not event.shift_pressed and not event.ctrl_pressed and not event.alt_pressed:
		if visible and sheet.visible:
			sheet.visible = false
			refresh()
			get_viewport().set_input_as_handled()
			return
		slot = focused_slot
		var hud := get_tree().get_first_node_in_group("party_hud")
		if hud != null and not visible:
			var over: int = hud.slot_under_mouse()
			if over >= 0:
				slot = over
	elif event.shift_pressed and event.physical_keycode >= KEY_1 and event.physical_keycode <= KEY_4:
		slot = event.physical_keycode - KEY_1
	if slot >= 0 and slot < party.members.size():
		show_screen(slot, true)
		get_viewport().set_input_as_handled()


## Open the screen focused on this party member. Called by party_hud.gd's portrait
## buttons (group "inventory"), and by this screen's own strip when switching.
func show_screen(member_slot: int, with_sheet := false) -> void:
	focused_slot = member_slot
	sheet.visible = with_sheet
	if not visible:
		get_tree().call_group("audio", "play", "ui_click")
	visible = true
	get_tree().paused = true
	say("")
	refresh()


## One line of feedback inside the window ("" clears it). The HUD's message line
## can't be used here: it sits under the dimmed backdrop and its fade is paused.
func say(text: String) -> void:
	status_label.text = text


func hide_screen() -> void:
	if visible:
		get_tree().call_group("audio", "play", "ui_click")
	visible = false
	sheet.visible = false
	get_tree().paused = false


func _on_name_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		name_label.accept_event()
		sheet.visible = not sheet.visible
		refresh()


## Keep the sheet just left of the inventory window (it follows the window's real
## rect, so it stays put whatever the window's size).
func _process(_delta: float) -> void:
	if sheet.visible:
		var r := window.get_global_rect()
		sheet.position = Vector2(maxf(2.0, r.position.x - sheet.size.x - 2.0), r.position.y)


func focus(member_slot: int) -> void:
	focused_slot = member_slot
	refresh()


## Create every slot once. Each is told what it is before it enters the tree, so it
## starts at the right size; refresh() later re-points hands/armour/backpack at
## whichever member is focused.
func _build_slots() -> void:
	var Kind = InventorySlotScript.Kind
	for i in party.members.size():
		strip_slots.append(_add_slot(strip_box, i, Kind.CHARACTER))
	for i in PartyScript.HAND_SLOTS:
		hand_slots.append(_add_slot(hands_box, focused_slot, Kind.HAND, i))
	armour_slot = _add_slot(hands_box, focused_slot, Kind.ARMOUR)  # Beside the hands.
	var gap := Control.new()  # Set the quick slots apart from the equipment.
	gap.custom_minimum_size = Vector2(16, 0)
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hands_box.add_child(gap)
	for i in PartyScript.QUICK_SLOTS:
		quick_slots.append(_add_slot(hands_box, focused_slot, Kind.QUICK, i))
	for i in PartyScript.BACKPACK_SIZE:
		backpack_slots.append(_add_slot(backpack_grid, focused_slot, Kind.BACKPACK, i))
	discard_button = Button.new()
	discard_button.text = "DISCARD"
	discard_button.focus_mode = Control.FOCUS_NONE
	discard_button.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS  # Acts on the press, like every other click here.
	discard_button.add_theme_font_size_override("font_size", 8)
	discard_button.custom_minimum_size = Vector2(0, 20)
	discard_button.tooltip_text = "Click with an item on the cursor to drop it on the floor in front"
	discard_button.pressed.connect(discard_held)
	var box := backpack_grid.get_parent()
	box.add_child(discard_button)
	box.move_child(discard_button, backpack_grid.get_index() + 1)
	refresh()


func _add_slot(parent: Container, member_slot: int, slot_kind: int, slot_index: int = 0) -> Panel:
	var s: Panel = InventorySlotScript.new()
	s.setup(self, member_slot, slot_kind, slot_index)
	parent.add_child(s)
	return s


## Redraw everything for whichever member is focused. Called after any move (by the
## slots themselves) and whenever focus changes.
func refresh() -> void:
	if party == null:
		return  # Not built yet.
	var m = party.member(focused_slot)
	name_label.text = m.name()
	# A long name ("Brother Felix" at 16 px) would make the window wider than its pack grid and push it under the sheet: it wraps instead.
	var wide: bool = name_label.get_theme_font("font").get_string_size(name_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x > NAME_MAX_WIDTH
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if wide else TextServer.AUTOWRAP_OFF
	name_label.custom_minimum_size.x = NAME_MAX_WIDTH if wide else 0.0
	hp_label.text = "%d/%d HP" % [m.hp, m.def.max_hp]
	for i in hand_slots.size():
		hand_slots[i].setup(self, focused_slot, InventorySlotScript.Kind.HAND, i)
		hand_slots[i].refresh()
	armour_slot.setup(self, focused_slot, InventorySlotScript.Kind.ARMOUR)
	armour_slot.refresh()
	for i in quick_slots.size():
		quick_slots[i].setup(self, focused_slot, InventorySlotScript.Kind.QUICK, i)
		quick_slots[i].refresh()
	for i in backpack_slots.size():
		backpack_slots[i].setup(self, focused_slot, InventorySlotScript.Kind.BACKPACK, i)
		backpack_slots[i].refresh()
	for s in strip_slots:
		s.refresh()
	if sheet.visible:
		sheet.refresh(party, focused_slot)


## The item pop-up (item_menu.gd: DROP, COMBINE) for the item in `slot`, beside it. Returns the menu (null if the slot is empty).
func open_item_menu(slot: Control) -> Node:
	if slot.get_item() == null:
		return null
	for old in get_tree().get_nodes_in_group("item_menu"):
		old.close()
	var menu := ItemMenu.new()
	menu.setup(self, slot)
	var popups := get_tree().get_first_node_in_group("popups")
	var rect := slot.get_global_rect()
	var preferred := func(size: Vector2) -> Vector2:
		return Vector2(rect.end.x + 4.0, rect.position.y)
	if popups:
		popups.open_popup(menu, preferred)
	else:  # No pop-up layer (a bare test scene).
		var layer := CanvasLayer.new()
		layer.layer = 16
		add_child(layer)
		layer.add_child(menu)
		menu.position = preferred.call(menu.get_combined_minimum_size())
	return menu


## The DISCARD button: drop the item on the cursor (the whole stack) on the tile in front of the party, where it can be picked up again. Says so
## and keeps it on the cursor if there is nowhere to drop it (a wall, a closed door or a monster in front). Returns whether it was dropped.
func discard_held() -> bool:
	if cursor == null or not cursor.is_holding():
		say("Pick something up to discard it.")
		return false
	if not can_drop_on_floor():
		say("There is nowhere to drop it here.")
		return false
	var held: RefCounted = cursor.held
	var name_text: String = held.def.display_name.to_lower()
	var what: String = name_text if held.count <= 1 else "%d %s" % [held.count, name_text]
	var who: String = party.member(focused_slot).name()
	drop_on_floor(cursor.release())
	get_tree().call_group("audio", "play", "drop")
	say("%s drops the %s." % [who, what] if held.count <= 1 else "%s drops %s." % [who, what])
	return true


func _front_cell() -> Vector2i:
	return player.cell + player.DIRS[player.facing]


## True if the tile in front of the party could currently take a dropped item (an
## item already there is fine: the tile holds a pile).
func can_drop_on_floor() -> bool:
	var front := _front_cell()
	return not (DungeonMap.is_blocked(front) or DungeonMap.is_occupied(front))


func drop_on_floor(item) -> void:
	dungeon.place_item(_front_cell(), item)
	refresh()
