extends Node3D
## Grid-based first-person movement.
## W/S = forward/back, A/D = strafe, Q/E = turn 90 degrees, F = open door / pull lever,
## 1-8 = use that quick slot (hero 1 = keys 1-2, hero 2 = 3-4...; see party.gd), left click = pick up/put down the
## item on the tile in front, onto the cursor (see cursor_item.gd).
## Every move/turn is tweened; movement input is ignored while a tween is running.

const DungeonMap := preload("res://scripts/dungeon_map.gd")
const ItemDef := preload("res://scripts/item_def.gd")

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
var interact_was_down := false  # So holding F triggers once, not every frame.
var quick_was_down := [false, false, false, false, false, false, false, false]  # Same for the 1-8 quick-slot keys.

# The dungeon (for item_at/take_item/place_item, which need return values, so we
# call them directly) and the cursor overlay (what's currently "held"). Both are
# optional: if either scene is removed, items just stop being interactive.
var dungeon: Node
var cursor: Node
var party: Node  # Where keys in backpacks are looked for (see _take_key).


func _ready() -> void:
	add_to_group("player")  # Lets other singletons (e.g. inventory_screen.gd) find us.
	yaw_degrees = facing * 90.0
	rotation_degrees.y = yaw_degrees
	position = DungeonMap.cell_to_world(cell)
	# Deferred: CursorItem is declared after us in main.tscn, so its _ready() (which
	# adds it to the group) hasn't run yet at this point -- call_deferred waits until
	# every sibling's _ready() this frame has finished, regardless of node order.
	call_deferred("_find_singletons")
	_report_position()


func _find_singletons() -> void:
	dungeon = get_tree().get_first_node_in_group("dungeon")
	cursor = get_tree().get_first_node_in_group("cursor")
	party = get_tree().get_first_node_in_group("party")


## Left click: pick up the item on the tile in front of us onto the cursor, or (if
## already holding one) put it down there -- Eye-of-the-Beholder style. Whether the
## click actually landed on the item's sprite doesn't matter, only that it's there;
## see the summary for why (headless-testable determinism over pixel-precise picking).
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_click_item()


func _click_item() -> void:
	if dungeon == null or cursor == null:
		return
	var front := cell + DIRS[facing]
	if DungeonMap.is_blocked(front) or DungeonMap.is_occupied(front):
		return
	if cursor.is_holding():
		if dungeon.item_at(front) != null:
			return  # Something's already there; no stacking two items on one tile.
		var def: Resource = cursor.release()
		dungeon.place_item(front, def)
		_say("You put down the %s." % def.display_name)
	else:
		var def: Resource = dungeon.item_at(front)
		if def == null:
			return
		dungeon.take_item(front)
		cursor.hold(def)
		_say("You pick up the %s." % def.display_name)


func _process(_delta: float) -> void:
	# F is edge-triggered: track it even while busy so a held key doesn't repeat.
	var interact_down := Input.is_physical_key_pressed(KEY_F)
	var interact_pressed := interact_down and not interact_was_down
	interact_was_down = interact_down

	# 1-8: use that quick slot (two per hero, in party order). Real time, so this works mid-move too.
	for i in 8:
		var down := Input.is_physical_key_pressed(KEY_1 + i)
		if down and not quick_was_down[i]:
			get_tree().call_group("party", "use_quick", i >> 1, i & 1)
		quick_was_down[i] = down

	# Busy animating: ignore input.
	if tween and tween.is_running():
		return

	if interact_pressed:
		_interact()
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
	if DungeonMap.is_blocked(target) or DungeonMap.is_occupied(target):  # Walls, closed doors, monsters.
		return
	cell = target
	_report_position()
	tween = create_tween()
	tween.tween_property(self, "position", DungeonMap.cell_to_world(cell), MOVE_TIME)
	tween.tween_callback(_arrive)


## Tell the world which tile we're on, so pressure plates and switch doors react.
## Done when a step STARTS: we already count as standing on the new tile.
func _report_position() -> void:
	DungeonMap.player_cell = cell
	get_tree().call_group("dungeon", "refresh")


## Called when a step finishes: take the stairs if we're on them.
func _arrive() -> void:
	if DungeonMap.is_stairs(cell):
		get_tree().call_group("level_complete", "show_screen")


## F: pull a lever on the wall in front of us, or open the door in front of us.
## Locked doors need (and use up) a key. The dungeon (group "dungeon") owns the
## door and lever nodes, so we just ask it.
func _interact() -> void:
	if not DungeonMap.lever_at(cell, facing).is_empty():
		get_tree().call_group("dungeon", "pull_lever", cell, facing)
		_say("You pull the lever.")
		return

	var front := cell + DIRS[facing]
	if not DungeonMap.is_door(front) or DungeonMap.open_doors.has(front):
		return
	if DungeonMap.door_id(front) != "":
		_say("It won't budge.")  # Only its switches can open it.
		return
	if DungeonMap.is_locked(front):
		if _take_key() == null:
			_say("The door is locked.")
			return
		DungeonMap.unlocked_doors[front] = true
		_say("You unlock the door.")
	get_tree().call_group("dungeon", "open_door", front)


## Use up a key to unlock a door: the one on the cursor if there is one, otherwise
## one from any party member's backpack. Returns it, or null if there is no key.
func _take_key() -> Resource:
	if cursor and cursor.holding_type(ItemDef.Type.KEY):
		return cursor.release()
	if party:
		return party.take_key()
	return null


## Show a message on the HUD (group "hud"), if there is one.
func _say(text: String) -> void:
	get_tree().call_group("hud", "show_message", text)


## Turn 90 degrees: +1 = left (counter-clockwise), -1 = right.
func _turn(direction: int) -> void:
	facing = posmod(facing + direction, 4)
	yaw_degrees += 90.0 * direction
	tween = create_tween()
	tween.tween_property(self, "rotation_degrees:y", yaw_degrees, MOVE_TIME)
