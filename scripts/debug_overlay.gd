extends CanvasLayer
## The minimap and tile coordinates overlay: shown from the start; Tab toggles it.
## Self-contained: to remove it, delete the DebugOverlay node from main.tscn
## (and optionally this script, minimap.gd and debug_overlay.tscn).

## Path to the Player node, set on the instance in main.tscn.
@export var player_path: NodePath

const FACING_NAMES: Array[String] = ["N", "W", "S", "E"]  # Same order as player.gd DIRS.

@onready var minimap: Control = %Minimap
@onready var label: Label = %InfoLabel
@onready var player: Node3D = get_node_or_null(player_path)


func _ready() -> void:
	visible = true  # The map is on by default (Tab hides and shows it).
	label.visible = false  # The coordinates are debug only: Shift+Tab.
	minimap.player = player


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo \
			and event.physical_keycode == KEY_TAB:
		if event.shift_pressed:
			label.visible = not label.visible  # Coordinates and facing, for debugging.
		else:
			visible = not visible


func _process(_delta: float) -> void:
	if not visible or player == null:
		return
	label.text = "%d,%d %s" % [
		player.cell.x, player.cell.y, FACING_NAMES[player.facing]]
	minimap.queue_redraw()
