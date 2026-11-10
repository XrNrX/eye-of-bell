extends SubViewportContainer
## The 3D dungeon view: a SubViewport (ui_layout.VIEW_SOURCE, 416x260) shown 1:1 in the top-left of
## the screen with nearest-neighbour filtering, so the dungeon stays crisp however the window is
## scaled. (It used to be rendered at 208x130 and enlarged 2x by `stretch_shrink = 2`; with
## `stretch_shrink = 1` its pixels are the screen pixels.)
##
## World clicks (picking up and putting down floor items) arrive here as ordinary GUI events on
## the container, in screen coordinates, and are passed on to the player. Going through the GUI
## (rather than forwarding raw input into the SubViewport) keeps the mouse position in the
## 640x360 space the rest of the HUD uses: the view's own pixel is the screen pixel.
##
## Anything drawn above this (the frame, the log, the arrows, the party) sits on a higher canvas
## layer and takes its own clicks first, so only clicks that land on the picture reach here.

const UiLayout := preload("res://scripts/ui_layout.gd")
const PaletteFilter := preload("res://scripts/palette_filter.gd")
const EnemyBars := preload("res://scripts/enemy_bars.gd")
const DungeonMap := preload("res://scripts/dungeon_map.gd")
const UiScale := preload("res://scripts/ui_scale.gd")

var player: Node


func _ready() -> void:
	# Position and size come from ui_layout.gd (the .tscn has the same numbers as a default).
	stretch = true
	stretch_shrink = UiLayout.VIEW_SCALE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# The viewport renders at the real screen resolution (ui_scale.gd), so the picture is as sharp as the window allows.
	UiScale.keep_fitted(self, UiLayout.VIEW.position, UiLayout.VIEW.size, _view_scale_changed)
	var port := get_node_or_null("Port")
	if port:
		var filter := PaletteFilter.new()  # Hidden unless Options: PALETTE FILTER is on.
		filter.name = "PaletteFilter"
		port.add_child(filter)
		var bars_layer := CanvasLayer.new()  # Inside the view, so bars are clipped to it and drawn at its 1:1 pixels.
		bars_layer.name = "EnemyBarsLayer"
		bars_layer.layer = 1
		bars_layer.add_child(EnemyBars.new())
		port.add_child(bars_layer)
		_view_scale_changed(get_meta("view_scale", 1))
	# Debug builds only: the test room's tools (F12, debug keys). The files are left out of a release export, so look them up
	# by path instead of preloading them.
	if DungeonMap.test_room_available():
		var tools: Script = load(DungeonMap.TOOLS_PATH)
		(owner if owner != null else get_tree().root).add_child.call_deferred(tools.new())


func _view_scale_changed(k: int) -> void:
	var bars := get_node_or_null("Port/EnemyBarsLayer")
	if bars is CanvasLayer:
		bars.scale = Vector2(k, k)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if player == null or not is_instance_valid(player):
			player = get_tree().get_first_node_in_group("player")
		if player:
			player.world_click(event.shift_pressed)
		accept_event()
