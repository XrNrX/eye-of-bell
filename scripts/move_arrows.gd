extends CanvasLayer
## The on-screen movement arrows, in the arrows window of the stone frame:
##
##     [turn left]  [forward]  [turn right]
##     [strafe L ]  [back   ]  [strafe R  ]
##
## They do exactly what W/A/S/D/Q/E do (Player.command), including holding the mouse button
## down to keep walking; the player ignores them while a step is animating, as for keys.
## Talks to the player through its group, so deleting this node just removes the arrows.

const UiLayout := preload("res://scripts/ui_layout.gd")

const BUTTON := 36.0  # The art is a native 36x36 (PixelLab), three across fill the 112 px well.
const GAP := 2.0
# [command, art name] in reading order.
const LAYOUT := [
	["turn_left", "turn_left"], ["forward", "up"], ["turn_right", "turn_right"],
	["strafe_left", "left"], ["back", "down"], ["strafe_right", "right"],
]

var buttons := {}  # command -> TextureButton
var player: Node


func _ready() -> void:
	layer = 6
	var well := UiLayout.ARROWS
	var block := Vector2(3 * BUTTON + 2 * GAP, 2 * BUTTON + GAP)
	var origin := well.position + ((well.size - block) / 2.0).floor()
	for i in LAYOUT.size():
		var command: String = LAYOUT[i][0]
		var art: String = LAYOUT[i][1]
		var b := TextureButton.new()
		b.texture_normal = load("res://art/ui/arrow_%s.png" % art)
		b.texture_pressed = load("res://art/ui/arrow_%s_pressed.png" % art)
		b.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		b.focus_mode = Control.FOCUS_NONE  # Space/Enter/F shouldn't press them.
		b.position = origin + Vector2((i % 3) * (BUTTON + GAP), (i / 3) * (BUTTON + GAP))
		b.tooltip_text = command.replace("_", " ").capitalize()
		# Act on the press itself, so even a very quick tap (down and up between two frames)
		# is never missed; _process then repeats it while the button stays held.
		b.button_down.connect(_press.bind(command))
		add_child(b)
		buttons[command] = b


func _press(command: String) -> void:
	_find_player()
	if player:
		player.command(command)


func _find_player() -> void:
	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")


func _process(_delta: float) -> void:
	# Held buttons repeat every frame; the player ignores the calls while it is mid-step.
	_find_player()
	if player == null:
		return
	for command in buttons:
		if buttons[command].button_pressed:
			player.command(command)
