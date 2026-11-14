extends Control
## One quick slot under a character's portrait in the party panel: a 14x14 frame
## holding a consumable (potion, scroll, later throwables) that can be used with one
## click or a number key (1-8, in party order: hero 1 = keys 1 and 2, hero 2 = 3 and 4...).
##
## Same click system as the inventory, no drag and drop -- the cursor
## (cursor_item.gd) is the hand:
##   left click, hand full   put the held item in (merging into a matching stack, or
##                           swapping with what's there)
##   left click, hand empty  use one item on this character now (see Party.use_quick)
##   right click             pick the item back up onto the cursor (one, from a stack)
## Identical consumables stack (ItemDef.max_stack); the count shows in the corner.
## Using an item starts a short cooldown, drawn as a grey clock-wipe over the slot.
## It takes consumables and throwables (daggers, darts); a thrown one is thrown by a click or its key.
## A dead character's slot is disabled: it can't be used or filled. Right-click still
## lifts its item out, so a consumable can't be stranded on a corpse.
##
## The contents live on the Party.Member (member.quick), not here; this is just the
## view and the click handling. Acts on the mouse PRESS (see inventory_slot.gd for why).

const PartyScript := preload("res://scripts/party.gd")
const StackCount := preload("res://scripts/stack_count.gd")
const FRAME_FILLED := preload("res://art/ui/quickslot.png")
const FRAME_EMPTY := preload("res://art/ui/quickslot_empty.png")
const SWEEP_TEXTURE := preload("res://art/ui/quickslot_sweep.png")

const UiLayout := preload("res://scripts/ui_layout.gd")

const SLOT_SIZE := Vector2(26, 26)   # The frame art scaled to the slot; its 24x24 inside holds an item's hud icon. (36x36 before the six-hero layout.)
const BORDER := 1.0                  # The frame's border, in pixels.
const SWEEP_TINT := Color(1, 1, 1, 0.65)

var party: Node
var member_slot: int
var index: int

var frame: TextureRect
var icon: TextureRect
var count_label: Control
var sweep: TextureProgressBar
var hovering := false
var hover_text := ""  # What this slot currently has showing in the message line.


## Call before adding to the tree.
func setup(a_party: Node, a_member_slot: int, a_index: int) -> void:
	party = a_party
	member_slot = a_member_slot
	index = a_index


func _ready() -> void:
	custom_minimum_size = SLOT_SIZE
	mouse_filter = Control.MOUSE_FILTER_STOP

	frame = _make_rect(Vector2.ZERO, SLOT_SIZE)
	add_child(frame)
	icon = _make_rect(Vector2(BORDER, BORDER), SLOT_SIZE - Vector2(BORDER, BORDER) * 2.0)
	add_child(icon)
	count_label = StackCount.new()
	add_child(count_label)

	sweep = TextureProgressBar.new()
	sweep.texture_progress = SWEEP_TEXTURE
	sweep.tint_progress = SWEEP_TINT
	sweep.fill_mode = TextureProgressBar.FILL_CLOCKWISE
	sweep.min_value = 0.0
	sweep.max_value = 100.0
	sweep.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sweep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sweep.visible = false
	add_child(sweep)

	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	party.quick_changed.connect(_on_quick_changed)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	refresh()


func _make_rect(pos: Vector2, rect_size: Vector2) -> TextureRect:
	var r := TextureRect.new()
	r.position = pos
	r.size = rect_size
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE  # Otherwise never smaller than the texture.
	r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


func _item() -> RefCounted:
	return party.member(member_slot).quick[index]


func _process(_delta: float) -> void:
	var left: float = party.member(member_slot).quick_cooldown[index]
	sweep.visible = left > 0.0
	sweep.value = left / PartyScript.QUICK_COOLDOWN * 100.0


func _on_quick_changed(changed_member: int) -> void:
	if changed_member == member_slot:
		refresh()


## Redraw from the member's data: frame, icon, and the hover text if the pointer is on us.
func refresh() -> void:
	var item := _item()
	frame.texture = FRAME_FILLED if item else FRAME_EMPTY
	icon.texture = null
	count_label.set_count(item.count if item else 0)
	tooltip_text = "Quick slot (key %d)" % (member_slot * 2 + index + 1)
	if item:
		var def: Resource = item.def
		icon.texture = def.hud_texture()  # 32x32 fills the frame's inside; a smaller (24x24) icon sits centred. Never scaled.
		icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	_update_hint()


# --------------------------------------------------------------------------
# Hover text in the message line
# --------------------------------------------------------------------------

func _on_mouse_entered() -> void:
	hovering = true
	frame.self_modulate = Color(1.22, 1.2, 1.15)  # Brightens, like every other clickable part of the panel.
	_update_hint()


func _on_mouse_exited() -> void:
	hovering = false
	frame.self_modulate = Color.WHITE
	_update_hint()


## Keep the message line showing this slot's item name while hovered, and take it
## down again afterwards (only if it's still our text).
func _update_hint() -> void:
	var item := _item()
	var wanted: String = item.label() if (hovering and item) else ""
	if wanted == hover_text:
		return
	if hover_text != "":
		get_tree().call_group("hud", "clear_message", hover_text)
	hover_text = wanted
	if wanted != "":
		get_tree().call_group("hud", "show_message", wanted, true)


# --------------------------------------------------------------------------
# Clicks
# --------------------------------------------------------------------------

func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed):
		return
	if event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		_left_click()
	elif event.button_index == MOUSE_BUTTON_RIGHT:
		accept_event()
		_right_click()


func _left_click() -> void:
	var m = party.member(member_slot)
	if not m.is_alive():
		return  # Disabled.
	var cursor = get_tree().get_first_node_in_group("cursor")
	if cursor and cursor.is_holding():
		var why: String = party.place_in_quick(member_slot, index, cursor)
		if why != "":
			_say(why)
		else:
			get_tree().call_group("audio", "play", "drop")
	elif _item() != null:
		party.use_quick(member_slot, index)


func _right_click() -> void:
	var here := _item()
	var cursor = get_tree().get_first_node_in_group("cursor")
	if here == null or cursor == null:
		return
	if not cursor.accepts_more(here):
		_say("Your hand is full.")
		return
	get_tree().call_group("audio", "play", "pickup")
	if here.count > 1:
		cursor.add(here.take_one())  # Split one off the stack.
		party.quick_changed.emit(member_slot)
	else:
		party.set_quick(member_slot, index, null)
		cursor.add(here)


func _say(text: String) -> void:
	get_tree().call_group("hud", "show_message", text)
