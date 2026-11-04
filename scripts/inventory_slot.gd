extends Panel
## One inventory slot: a hand, the armour slot, or a backpack cell belonging to one
## party member -- or a CHARACTER slot, which isn't storage at all but that member's
## portrait in the character strip.
##
## Eye-of-the-Beholder style, one system only: the cursor (cursor_item.gd) is the
## "hand". Click a slot to pick its item up onto the cursor; click a slot while
## holding something to put it there (swapping with whatever was there). There is
## no drag and drop. Right-click uses a consumable in the slot: a potion heals this
## member, a scroll casts at the monster ahead (see Party.use_item).
##
## Acts on the mouse PRESS. Godot routes the release to whichever control got the
## press, wherever the pointer has moved since, so the press is the only event that
## reliably belongs to the slot under the pointer.

const ItemDef := preload("res://scripts/item_def.gd")

enum Kind { HAND, ARMOUR, BACKPACK, CHARACTER }

const ITEM_SLOT := Vector2(24, 24)      # Holds a 24x24 item icon at its native size.
const PORTRAIT_SLOT := Vector2(16, 16)  # A 32x32 portrait scaled to exactly half.
const EMPTY_BG := Color(0.137, 0.118, 0.169, 0.6)  # Palette stone_900, translucent.
const FILLED_BG := Color(0.275, 0.247, 0.31)        # Palette stone_700.
const EDGE := Color(0.588, 0.557, 0.604)            # Palette stone_300.

var screen: Node    # InventoryScreen: party/cursor access, refresh() and say().
var member_slot: int
var kind: Kind
var index: int = 0  # Hand index (0/1) or backpack index; unused for ARMOUR/CHARACTER.

var icon: TextureRect


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	icon = TextureRect.new()
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Without this a TextureRect is never smaller than its texture, so a 32x32
	# portrait overflowed its 16x16 slot and overlapped its neighbours.
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	add_child(icon)
	_apply_kind()


func setup(a_screen: Node, a_member_slot: int, a_kind: Kind, a_index: int = 0) -> void:
	screen = a_screen
	member_slot = a_member_slot
	kind = a_kind
	index = a_index
	_apply_kind()


## Item slots show their icon at native size, centred; a portrait slot scales it.
func _apply_kind() -> void:
	custom_minimum_size = PORTRAIT_SLOT if kind == Kind.CHARACTER else ITEM_SLOT
	if icon:
		icon.stretch_mode = TextureRect.STRETCH_SCALE if kind == Kind.CHARACTER \
				else TextureRect.STRETCH_KEEP_CENTERED


## The ItemDef in this slot, or null. CHARACTER slots never hold anything directly.
func get_item() -> Resource:
	var m = screen.party.member(member_slot)
	match kind:
		Kind.HAND: return m.hands[index]
		Kind.ARMOUR: return m.armour
		Kind.BACKPACK: return m.backpack[index]
	return null


func set_item(def: Resource) -> void:
	var m = screen.party.member(member_slot)
	match kind:
		Kind.HAND: m.hands[index] = def
		Kind.ARMOUR: m.armour = def
		Kind.BACKPACK: m.backpack[index] = def


## Would this slot take that item? Backpack cells take anything.
func accepts(def: Resource) -> bool:
	match kind:
		Kind.HAND: return ItemDef.allowed_in_hand(def.type)
		Kind.ARMOUR: return ItemDef.allowed_in_armour(def.type)
	return true


func refresh() -> void:
	var filled: bool
	if kind == Kind.CHARACTER:
		var m = screen.party.member(member_slot)
		icon.texture = m.def.portrait if m.is_alive() else m.def.portrait_dead
		filled = member_slot == screen.focused_slot  # Highlight whichever member is shown.
		tooltip_text = m.def.display_name
	else:
		var def := get_item()
		icon.texture = def.icon if def else null
		filled = def != null
		tooltip_text = "" if def == null else def.display_name + \
				("\nRight-click to use" if def.type == ItemDef.Type.CONSUMABLE else "")
	var box := StyleBoxFlat.new()
	box.bg_color = FILLED_BG if filled else EMPTY_BG
	box.border_color = EDGE
	box.set_border_width_all(1)
	add_theme_stylebox_override("panel", box)


func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed):
		return
	if event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		if kind == Kind.CHARACTER:
			_click_portrait()
		else:
			_click_slot()
	elif event.button_index == MOUSE_BUTTON_RIGHT:
		accept_event()
		if kind != Kind.CHARACTER:
			_use_item()


## Right-click: use the consumable in this slot. A potion heals whoever's inventory
## this is; a scroll casts at the monster ahead and closes the screen so you can see it.
func _use_item() -> void:
	var def := get_item()
	if def == null or def.type != ItemDef.Type.CONSUMABLE:
		return
	var result: Dictionary = screen.party.use_item(member_slot, def)
	screen.say(result.message)
	if not result.used:
		return
	set_item(null)  # Spent.
	screen.refresh()
	if result.close:
		get_tree().call_group("hud", "show_message", result.message)
		screen.hide_screen()


## Pick up, put down, or swap with the cursor.
func _click_slot() -> void:
	var cursor = screen.cursor
	var here := get_item()
	if not cursor.is_holding():
		if here == null:
			return
		set_item(null)
		cursor.hold(here)
		screen.say("")
	else:
		var held: Resource = cursor.held
		if not accepts(held):
			screen.say("The %s doesn't go there." % held.display_name)
			return
		set_item(cursor.release())
		if here != null:
			cursor.hold(here)  # Swap: what was in the slot is now on the cursor.
		screen.say("")
	screen.refresh()


## Holding something: put it in that member's first empty backpack cell.
## Empty-handed: show that member's inventory instead.
func _click_portrait() -> void:
	var cursor = screen.cursor
	if not cursor.is_holding():
		screen.focus(member_slot)
		return
	var m = screen.party.member(member_slot)
	var i: int = m.backpack.find(null)
	if i < 0:
		screen.say("%s's backpack is full." % m.def.display_name)
		return
	m.backpack[i] = cursor.release()
	screen.say("")
	screen.refresh()
