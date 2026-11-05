extends CanvasLayer
## The Eye-of-the-Beholder-style "item on the cursor": an icon that follows the
## mouse while something is held. It's the party's one "hand": the world click in
## player.gd and every inventory slot pick items up onto it and put them down from it.
## Runs while the game is paused (the inventory pauses it), and sits on a canvas
## layer above the inventory screen, so the held item is always visible at the mouse.
## Other scripts fetch it directly (get_tree().get_first_node_in_group("cursor"))
## when they need to read or change what's held, the same way party_hud.gd fetches
## the Party node. Self-contained: delete this scene and items just can't be picked
## up any more; nothing else breaks.

const ItemStack := preload("res://scripts/item_stack.gd")
const StackCount := preload("res://scripts/stack_count.gd")

@onready var icon: TextureRect = %Icon

var held: RefCounted  # The ItemStack on the cursor (the whole stack), or null if empty.
var count_label: Control  # The pixel number in the icon's corner.


func _ready() -> void:
	add_to_group("cursor")
	process_mode = Node.PROCESS_MODE_ALWAYS  # Keep following the mouse while paused.
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE  # Never steal a click from the world.
	icon.visible = false
	count_label = StackCount.new()
	icon.add_child(count_label)


func _process(_delta: float) -> void:
	if held:
		_follow_mouse()


func _follow_mouse() -> void:
	icon.global_position = get_viewport().get_mouse_position() - icon.size / 2.0


func is_holding() -> bool:
	return held != null


## True if something is held and it's that ItemDef.Type.
func holding_type(type: int) -> bool:
	return held != null and held.def.type == type


## Could one more of this stack's item be added to the cursor (empty hand, or the same
## stackable item with room)? Used by right-click "split one off".
func accepts_more(stack: RefCounted) -> bool:
	return held == null or (held.can_stack_with(stack) and held.room() > 0)


## Add a piece (e.g. one split off a stack) to the cursor: starts holding it, or joins
## the stack already held.
func add(piece: RefCounted) -> void:
	if held == null:
		hold(piece)
	else:
		held.count += piece.count
		refresh()


## Redraw after the held stack's count changed.
func refresh() -> void:
	count_label.set_count(held.count if held else 0)


## Put an item on the cursor, replacing whatever was already there. Takes an ItemStack
## (the whole stack) or a plain ItemDef (a stack of one).
func hold(item) -> void:
	held = ItemStack.wrap(item)
	icon.texture = held.def.icon
	icon.size = held.def.icon.get_size()
	refresh()
	_follow_mouse()  # Appear at the mouse straight away, not at the old spot for a frame.
	icon.visible = true


## Take the held stack off the cursor and return it (null if nothing was held).
func release() -> RefCounted:
	var stack := held
	held = null
	icon.visible = false
	count_label.set_count(0)
	return stack
