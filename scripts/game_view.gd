extends SubViewportContainer
## The 3D dungeon view: a small SubViewport (ui_layout.VIEW_SOURCE, 208x130) shown at 2x in the
## top-left of the screen with nearest-neighbour filtering, so the dungeon keeps a chunky pixel
## look however the window is scaled. The container's own `stretch_shrink = 2` does the
## enlarging: it renders the SubViewport at half the container's size.
##
## World clicks (picking up and putting down floor items) arrive here as ordinary GUI events on
## the container, in screen coordinates, and are passed on to the player. Going through the GUI
## (rather than forwarding raw input into the SubViewport) keeps the mouse position in the
## 640x360 space the rest of the HUD uses: the view's own pixel is the screen pixel / 2.
##
## Anything drawn above this (the frame, the log, the arrows, the party) sits on a higher canvas
## layer and takes its own clicks first, so only clicks that land on the picture reach here.

const UiLayout := preload("res://scripts/ui_layout.gd")

var player: Node


func _ready() -> void:
	# Position and size come from ui_layout.gd (the .tscn has the same numbers as a default).
	position = UiLayout.VIEW.position
	size = UiLayout.VIEW.size
	stretch = true
	stretch_shrink = UiLayout.VIEW_SCALE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if player == null or not is_instance_valid(player):
			player = get_tree().get_first_node_in_group("player")
		if player:
			player.world_click(event.shift_pressed)
		accept_event()
