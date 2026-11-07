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
## Backpack cells hold stacks of identical stackable items (ItemDef.max_stack) with a
## small count in the corner. Clicking picks up the whole stack; putting a stack on a
## matching one merges them (the overflow stays on the cursor); right-clicking a stack
## of 2+ splits one off onto the cursor (shift+right-click uses one; a single item is used).
## Hands and armour hold a single item, so a stack can't go there -- except a hand
## takes a stack of a throwable (darts).
##
## Acts on the mouse PRESS. Godot routes the release to whichever control got the
## press, wherever the pointer has moved since, so the press is the only event that
## reliably belongs to the slot under the pointer.

const ItemDef := preload("res://scripts/item_def.gd")
const StackCount := preload("res://scripts/stack_count.gd")

enum Kind { HAND, ARMOUR, BACKPACK, CHARACTER }

const ITEM_SLOT := Vector2(48, 48)      # Holds a 48x48 item icon (24x24 logical, drawn at 2x) at its native size.
const PORTRAIT_SLOT := Vector2(32, 32)  # A 64x64 portrait scaled to exactly half.
const EMPTY_BG := Color(0.078, 0.075, 0.106, 0.6)  # Palette stone_900, translucent.
const FILLED_BG := Color(0.122, 0.118, 0.157)        # Palette stone_800.
const EDGE := Color(0.486, 0.267, 0.149)            # Palette rust_500: the same rusted iron as the window's lip.
## What an empty hand or armour slot shows, faintly: a sword and a chestplate (art/ui/slot_*.png, made by
## gen_ui.slot_placeholder), so it is clear what goes where.
const HAND_PLACEHOLDER := preload("res://art/ui/slot_hand.png")
const ARMOUR_PLACEHOLDER := preload("res://art/ui/slot_armour.png")
const PLACEHOLDER_TINT := Color(1, 1, 1, 0.3)

var screen: Node    # InventoryScreen: party/cursor access, refresh() and say().
var member_slot: int
var kind: Kind
var index: int = 0  # Hand index (0/1) or backpack index; unused for ARMOUR/CHARACTER.

var icon: TextureRect
var count_label: Control


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
	count_label = StackCount.new()
	add_child(count_label)
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


## The ItemStack in this slot, or null. CHARACTER slots never hold anything directly.
func get_item() -> RefCounted:
	var m = screen.party.member(member_slot)
	match kind:
		Kind.HAND: return m.hands[index]
		Kind.ARMOUR: return m.armour
		Kind.BACKPACK: return m.backpack[index]
	return null


func set_item(stack: RefCounted) -> void:
	var m = screen.party.member(member_slot)
	match kind:
		Kind.HAND: m.hands[index] = stack
		Kind.ARMOUR: m.armour = stack
		Kind.BACKPACK: m.backpack[index] = stack


## Why this slot won't take that stack, or "" if it will. Backpack cells take anything;
## hands and armour take one item of the right type.
func refusal(stack: RefCounted) -> String:
	var allowed := true
	match kind:
		Kind.HAND: allowed = ItemDef.allowed_in_hand(stack.def.type)
		Kind.ARMOUR: allowed = ItemDef.allowed_in_armour(stack.def.type)
	if not allowed:
		return "The %s doesn't go there." % stack.def.display_name
	if (kind == Kind.HAND or kind == Kind.ARMOUR) and screen != null and screen.party != null:
		var m = screen.party.member(member_slot)
		if m != null and not screen.party.can_equip(m, stack.def):  # The same class rule as clicking a portrait.
			return "The %s can't %s that." % [m.def.display_name.to_lower(), "wear" if stack.def.type == ItemDef.Type.ARMOUR else "use"]
	if stack.count > 1 and not holds_stacks(stack.def):
		return "Only one at a time goes there."
	return ""


## Backpack cells hold stacks; a hand holds a stack only of a throwable (darts), so
## the hero can throw them one after another.
func holds_stacks(def: Resource) -> bool:
	return kind == Kind.BACKPACK or (kind == Kind.HAND and def.can_throw())


func refresh() -> void:
	var filled: bool
	if kind == Kind.CHARACTER:
		var m = screen.party.member(member_slot)
		icon.texture = m.def.portrait if m.is_alive() else m.def.portrait_dead
		filled = member_slot == screen.focused_slot  # Highlight whichever member is shown.
		tooltip_text = m.def.display_name
	else:
		var stack := get_item()
		icon.texture = stack.def.icon if stack else null
		icon.modulate = Color.WHITE
		icon.flip_h = false
		if stack == null and (kind == Kind.HAND or kind == Kind.ARMOUR):
			icon.texture = HAND_PLACEHOLDER if kind == Kind.HAND else ARMOUR_PLACEHOLDER
			icon.modulate = PLACEHOLDER_TINT
			icon.flip_h = kind == Kind.HAND and index == 1  # The two hands face each other.
		count_label.set_count(stack.count if stack else 0)
		filled = stack != null
		tooltip_text = ""
		if stack == null and kind == Kind.HAND:
			tooltip_text = "%s hand: a weapon or a spell focus" % ("Left" if index == 0 else "Right")
		elif stack == null and kind == Kind.ARMOUR:
			tooltip_text = "Armour"
		if stack:
			tooltip_text = stack.label()
			if stack.count > 1:
				tooltip_text += "\nRight-click to take one"
				if stack.def.type == ItemDef.Type.CONSUMABLE:
					tooltip_text += "\nShift+right-click to use one"
			elif stack.def.type == ItemDef.Type.CONSUMABLE:
				tooltip_text += "\nRight-click to use"
	var box := StyleBoxFlat.new()
	box.bg_color = FILLED_BG if filled else EMPTY_BG
	box.border_color = EDGE
	box.set_border_width_all(2)
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
			_right_click(event.shift_pressed)


## Right-click: on a stack of 2+, split one off onto the cursor (or onto the matching
## stack already held). Shift+right-click uses one from the stack instead. A single
## item is just used.
func _right_click(use_one := false) -> void:
	var here := get_item()
	if here == null:
		return
	if here.count > 1 and not use_one:
		if not screen.cursor.accepts_more(here):
			screen.say("Your hand is full.")
			return
		screen.cursor.add(here.take_one())
		screen.say("")
		screen.refresh()
		return
	_use_item()


## Use the consumable in this slot. A potion heals whoever's inventory this is; a
## scroll casts at the monster ahead and closes the screen so you can see it.
func _use_item() -> void:
	var stack := get_item()
	if stack == null or stack.def.type != ItemDef.Type.CONSUMABLE:
		return
	var result: Dictionary = screen.party.use_item(member_slot, stack.def)
	screen.say(result.message)
	if not result.used:
		return
	stack.count -= 1  # Spent: one from the stack.
	if stack.count <= 0:
		set_item(null)
	screen.refresh()
	if result.close:
		get_tree().call_group("hud", "show_message", result.message)
		screen.hide_screen()


## Pick up (the whole stack), put down, merge into a matching stack, or swap.
func _click_slot() -> void:
	var cursor = screen.cursor
	var here := get_item()
	if not cursor.is_holding():
		if here == null:
			return
		set_item(null)
		cursor.hold(here)
		get_tree().call_group("audio", "play", "pickup")
		screen.say("")
	else:
		var held: RefCounted = cursor.held
		var why := refusal(held)
		if why != "":
			screen.say(why)
			return
		if holds_stacks(held.def) and here != null and here.can_stack_with(held) and here.room() > 0:
			here.merge_from(held)  # Whatever doesn't fit stays on the cursor.
			if held.count <= 0:
				cursor.release()
			else:
				cursor.refresh()
		else:
			set_item(cursor.release())
			if here != null:
				cursor.hold(here)  # Swap: what was in the slot is now on the cursor.
		get_tree().call_group("audio", "play", "drop")
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
	if cursor.held.def.revive_percent > 0 and not m.is_alive():  # A Scroll of Resurrection on a fallen hero's portrait.
		if screen.party.revive(member_slot, cursor.held.def).used:
			cursor.held.count -= 1
			if cursor.held.count <= 0:
				cursor.release()
			else:
				cursor.refresh()
			screen.say("")
			screen.refresh()
		return
	if not screen.party.add_to_backpack(member_slot, cursor.held):
		cursor.refresh()  # Part of a stack may have fitted.
		screen.say("%s's backpack is full." % m.def.display_name)
		screen.refresh()
		return
	cursor.release()
	screen.say("")
	screen.refresh()
