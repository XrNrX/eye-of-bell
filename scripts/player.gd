extends Node3D
## Grid-based first-person movement.
## W/S = forward/back, A/D = strafe, Q/E = turn 90 degrees.
## Every action is tweened; input is ignored while a tween is running.

const DungeonMap := preload("res://scripts/dungeon_map.gd")

const MOVE_TIME := 0.2  # Seconds per step or turn.

# Grid directions (x, z) indexed by facing. Facing increases when turning left,
# which matches positive rotation around Y.
const DIRS: Array[Vector2i] = [
	Vector2i(0, -1),  # 0: north (-Z)
	Vector2i(-1, 0),  # 1: west
	Vector2i(0, 1),   # 2: south
	Vector2i(1, 0),   # 3: east
]

var cell: Vector2i = DungeonMap.START_TILE
var facing: int = DungeonMap.START_FACING
var yaw_degrees: float  # Accumulated (unwrapped) yaw so turn tweens take the short way.
var tween: Tween


func _ready() -> void:
	yaw_degrees = facing * 90.0
	rotation_degrees.y = yaw_degrees
	position = DungeonMap.cell_to_world(cell)


func _process(_delta: float) -> void:
	# Busy animating: ignore input.
	if tween and tween.is_running():
		return

	# Polling (instead of key events) lets you hold a key to keep walking.
	if Input.is_physical_key_pressed(KEY_W):
		_try_move(DIRS[facing])
	elif Input.is_physical_key_pressed(KEY_S):
		_try_move(DIRS[(facing + 2) % 4])
	elif Input.is_physical_key_pressed(KEY_A):
		_try_move(DIRS[(facing + 1) % 4])  # Left of facing.
	elif Input.is_physical_key_pressed(KEY_D):
		_try_move(DIRS[(facing + 3) % 4])  # Right of facing.
	elif Input.is_physical_key_pressed(KEY_Q):
		_turn(1)
	elif Input.is_physical_key_pressed(KEY_E):
		_turn(-1)


## Step one tile in grid direction `dir`, unless a wall is in the way.
func _try_move(dir: Vector2i) -> void:
	var target := cell + dir
	if DungeonMap.is_wall(target):
		return
	cell = target
	tween = create_tween()
	tween.tween_property(self, "position", DungeonMap.cell_to_world(cell), MOVE_TIME)


## Turn 90 degrees: +1 = left (counter-clockwise), -1 = right.
func _turn(direction: int) -> void:
	facing = posmod(facing + direction, 4)
	yaw_degrees += 90.0 * direction
	tween = create_tween()
	tween.tween_property(self, "rotation_degrees:y", yaw_degrees, MOVE_TIME)
