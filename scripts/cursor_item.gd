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

@onready var icon: TextureRect = %Icon

var held: Resource  # The ItemDef currently on the cursor, or null if empty.


func _ready() -> void:
	add_to_group("cursor")
	process_mode = Node.PROCESS_MODE_ALWAYS  # Keep following the mouse while paused.
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE  # Never steal a click from the world.
	icon.visible = false


func _process(_delta: float) -> void:
	if held:
		_follow_mouse()


func _follow_mouse() -> void:
	icon.global_position = get_viewport().get_mouse_position() - icon.size / 2.0


func is_holding() -> bool:
	return held != null


## True if something is held and it's that ItemDef.Type.
func holding_type(type: int) -> bool:
	return held != null and held.type == type


## Put an item on the cursor, replacing whatever was already there.
func hold(def: Resource) -> void:
	held = def
	icon.texture = def.icon
	icon.size = def.icon.get_size()
	_follow_mouse()  # Appear at the mouse straight away, not at the old spot for a frame.
	icon.visible = true


## Take the held item off the cursor and return it (null if nothing was held).
func release() -> Resource:
	var def := held
	held = null
	icon.visible = false
	return def
