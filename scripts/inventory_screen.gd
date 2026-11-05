extends CanvasLayer
## The inventory screen: opened by clicking a character portrait (on the main party
## HUD, or the character strip inside here) via the "inventory" group's show_screen.
## Shows one "focused" member's two hand slots, their armour slot and a backpack
## grid, plus a strip of every member's portrait.
##
## Eye-of-the-Beholder click-to-click, one system: the cursor (cursor_item.gd) is the
## hand. Click a slot to pick its item up, click a slot to put it down (swapping if
## occupied), click a portrait to put it in that member's backpack (or, empty-handed,
## to switch to them), click outside the window to drop it on the floor in front.
## The clicks live in inventory_slot.gd and inventory_floor_drop.gd; this script
## builds the slots once and owns "which member is focused" and the status line.
##
## Pure data for now: what's equipped doesn't affect combat yet, the same way
## MonsterDef/ItemDef's stat fields existed before anything read them.

const InventorySlotScript := preload("res://scripts/inventory_slot.gd")
const PartyScript := preload("res://scripts/party.gd")
const DungeonMap := preload("res://scripts/dungeon_map.gd")
const CharacterSheet := preload("res://scripts/character_sheet.gd")

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
var backpack_slots := []  # BACKPACK-kind InventorySlot, likewise re-pointed.
var sheet: PanelContainer  # The character sheet beside the window (character_sheet.gd).
@onready var window: Control = $Center/Window


func _ready() -> void:
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
	for i in PartyScript.BACKPACK_SIZE:
		backpack_slots.append(_add_slot(backpack_grid, focused_slot, Kind.BACKPACK, i))
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
	name_label.text = m.def.display_name
	hp_label.text = "%d/%d HP" % [m.hp, m.def.max_hp]
	for i in hand_slots.size():
		hand_slots[i].setup(self, focused_slot, InventorySlotScript.Kind.HAND, i)
		hand_slots[i].refresh()
	armour_slot.setup(self, focused_slot, InventorySlotScript.Kind.ARMOUR)
	armour_slot.refresh()
	for i in backpack_slots.size():
		backpack_slots[i].setup(self, focused_slot, InventorySlotScript.Kind.BACKPACK, i)
		backpack_slots[i].refresh()
	for s in strip_slots:
		s.refresh()
	if sheet.visible:
		sheet.refresh(party, focused_slot)


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
