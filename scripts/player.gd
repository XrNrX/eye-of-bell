extends Node3D
## Grid-based first-person movement.
## W/S = forward/back, A/D = strafe, Q/E = turn 90 degrees, F = open door / pull lever,
## 1-8 = use that quick slot (hero 1 = keys 1-2, hero 2 = 3-4...; see party.gd), left click = pick up/put down the
## item on the tile in front, onto the cursor (see cursor_item.gd).
## Every move/turn is tweened; movement input is ignored while a tween is running.

const Events := preload("res://scripts/game_events.gd")
const DungeonMap := preload("res://scripts/dungeon_map.gd")
const ItemDef := preload("res://scripts/item_def.gd")
const ItemStack := preload("res://scripts/item_stack.gd")

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
## Shift+click (empty-handed) sends the item straight to the party instead: see Party.stow.
## A left click on the 3D view (game_view.gd passes it on; the frame and panels never reach
## it). Shift+click sends a floor item to the party instead of the cursor.
func world_click(shift := false) -> void:
	var front := cell + DIRS[facing]
	if DungeonMap.is_portcullis(front) and not DungeonMap.open_doors.has(front):
		_say("The portcullis won't budge.")  # Clicking the grate: it only answers to its switch.
		return
	if DungeonMap.is_destructible(front):
		_say("The wall is cracked.")  # A hint: something heavy, or a blast, might break it.
		return
	if DungeonMap.is_corrupted(front):
		_say("The stone is alive with pulsing green veins.")
		return
	if _click_trap(front):
		return
	_click_item(shift)


## An armed trap in front, clicked with an empty hand: pick it up, disarmed. Returns whether it did.
func _click_trap(front: Vector2i) -> bool:
	var traps := get_tree().get_first_node_in_group("traps")
	if traps == null or cursor == null or cursor.is_holding() or traps.armed_at(front) == null or DungeonMap.is_occupied(front):
		return false
	var def: Resource = traps.disarm(front)
	cursor.hold(ItemStack.of(def, 1))
	_cue("pickup")
	_say("You disarm the %s and pick it up." % str(def.display_name).to_lower())
	return true


func _click_item(shift := false) -> void:
	if dungeon == null or cursor == null:
		return
	var front := cell + DIRS[facing]
	if DungeonMap.is_blocked(front) or DungeonMap.is_occupied(front):
		return
	if cursor.is_holding():  # Goes on top of anything already there (a tile holds a pile).
		var stack: RefCounted = cursor.release()
		dungeon.place_item(front, stack)
		_cue("drop")
		_say("You put down the %s." % stack.label())
	else:
		var stack: RefCounted = dungeon.item_at(front)
		if stack == null:
			return
		if shift and party:
			_stow(front, stack)
			return
		dungeon.take_item(front)
		Events.send(get_tree(), "item_picked_up", [stack.def, stack.count])
		# A thrown item goes home to the hand or quick slot it was thrown from, if that
		# slot is free (or holds the same stack); otherwise it comes onto the cursor.
		var home: String = party.return_to_origin(stack) if party else ""
		_cue("pickup")
		if home != "":
			_say(home)
			return
		stack.origin = {}  # On the cursor it has no home any more.
		# A key goes straight into a party member's backpack (the first with room), and only stays on the
		# cursor if every pack is full.
		if party and stack.def.type == ItemDef.Type.KEY:
			get_tree().call_group("hud", "show_banner", "Key picked up!")
			var packed: String = party.stow_in_backpack(stack)
			if packed != "" and stack.count <= 0:
				_say("Key picked up! %s" % packed)  # "Fighter stows the key."
				return
		cursor.hold(stack)
		_say("You pick up the %s." % stack.label())


## Shift+click: the party takes the item without it passing through the cursor. What
## doesn't fit anywhere stays on the floor.
func _stow(front: Vector2i, stack: RefCounted) -> void:
	var had: int = stack.count
	var worn: String = party.equip_best(stack)  # Armour goes on whoever gains the most defence...
	if worn != "":
		if stack.count <= 0:
			dungeon.take_item(front)
		Events.send(get_tree(), "item_picked_up", [stack.def, had - stack.count])
		_say(worn)
		return
	var message: String = party.stow(stack)  # ...otherwise into a backpack, as any item.
	if message != "":
		_cue("pickup")
	if stack.count < had:
		Events.send(get_tree(), "item_picked_up", [stack.def, had - stack.count])
	if stack.count <= 0:
		dungeon.take_item(front)  # All of it went; remove the empty stack from the pile.
	if message == "":
		message = "There's no room for the %s." % stack.def.display_name.to_lower()
	elif stack.count > 0:
		message += " (Some won't fit.)"
	_say(message)


func _process(_delta: float) -> void:
	# F is edge-triggered: track it even while busy so a held key doesn't repeat.
	var interact_down := Input.is_physical_key_pressed(KEY_F)
	var interact_pressed := interact_down and not interact_was_down
	interact_was_down = interact_down

	# 1-8: use that quick slot (two per hero, in party order). Real time, so this works mid-move too.
	for i in 8:
		var down := Input.is_physical_key_pressed(KEY_1 + i) and not Input.is_physical_key_pressed(KEY_SHIFT)  # (Shift+1..4 open the character sheets.)
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
		command("forward")
	elif Input.is_physical_key_pressed(KEY_S):
		command("back")
	elif Input.is_physical_key_pressed(KEY_A):
		command("strafe_left")
	elif Input.is_physical_key_pressed(KEY_D):
		command("strafe_right")
	elif Input.is_physical_key_pressed(KEY_Q):
		command("turn_left")
	elif Input.is_physical_key_pressed(KEY_E):
		command("turn_right")


## One step or turn, ignored while another is still animating. The keys above and the
## on-screen arrows (move_arrows.gd) both come through here.
## kind: forward, back, strafe_left, strafe_right, turn_left, turn_right.
func command(kind: String) -> void:
	if tween and tween.is_running():
		return
	match kind:
		"forward": _try_move(DIRS[facing])
		"back": _try_move(DIRS[(facing + 2) % 4])
		"strafe_left": _try_move(DIRS[(facing + 1) % 4])  # Left of facing.
		"strafe_right": _try_move(DIRS[(facing + 3) % 4])
		"turn_left": _turn(1)
		"turn_right": _turn(-1)


## Step one tile in grid direction `dir`, unless a wall is in the way.
func _try_move(dir: Vector2i) -> void:
	var target := cell + dir
	if DungeonMap.is_blocked(target) or DungeonMap.is_occupied(target):  # Walls, closed doors, monsters.
		_cue("bump")  # (audio.gd limits how often, so holding W against a wall isn't a drum roll.)
		return
	cell = target
	_cue("step")
	_report_position()
	get_tree().call_group("traps", "party_entered", cell)  # The party steps over its own armed traps (trap_field.gd).
	tween = create_tween()
	tween.tween_property(self, "position", DungeonMap.cell_to_world(cell), MOVE_TIME)
	tween.tween_callback(_arrive)


## Put the party at a cell and facing at once (loading a save).
func restore(new_cell: Vector2i, new_facing: int) -> void:
	if tween and tween.is_running():
		tween.kill()
	cell = new_cell
	facing = new_facing
	yaw_degrees = facing * 90.0
	rotation_degrees.y = yaw_degrees
	position = DungeonMap.cell_to_world(cell)
	_report_position()


## Tell the world which tile we're on, so pressure plates and switch doors react.
## Done when a step STARTS: we already count as standing on the new tile.
func _report_position() -> void:
	DungeonMap.player_cell = cell
	get_tree().call_group("dungeon", "refresh")


## Called when a step finishes: take the stairs if we're on them.
func _arrive() -> void:
	if DungeonMap.is_stairs(cell):
		Events.send(get_tree(), "level_completed")
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
	if DungeonMap.is_destructible(front):
		_say("The wall is cracked.")
		return
	if DungeonMap.is_corrupted(front):
		_say("The stone is alive with pulsing green veins.")
		return
	if not DungeonMap.is_door(front) or DungeonMap.open_doors.has(front):
		return
	if DungeonMap.is_portcullis(front):
		_say("The portcullis won't budge.")  # Never by hand: only its linked lever or plate.
		return
	if DungeonMap.door_id(front) != "":
		_say("It won't budge.")  # Only its switches can open it.
		return
	if DungeonMap.is_locked(front):
		if _take_key() == null:
			_cue("door_locked")
			_say("The door is locked.")
			return
		DungeonMap.unlocked_doors[front] = true
		Events.send(get_tree(), "door_unlocked", [front])
		_cue("unlock")
		_say("You unlock the door.")
	get_tree().call_group("dungeon", "open_door", front)


## Use up a key to unlock a door: the one on the cursor if there is one, otherwise
## one from any party member's backpack. Returns it, or null if there is no key.
func _take_key() -> Resource:
	if cursor and cursor.holding_type(ItemDef.Type.KEY):
		return cursor.release().def
	if party:
		return party.take_key()
	return null


## Play a sound through the audio node (group "audio"), if the scene has one.
func _cue(sound: String) -> void:
	get_tree().call_group("audio", "play", sound)


## Show a message on the HUD (group "hud"), if there is one.
func _say(text: String) -> void:
	get_tree().call_group("hud", "show_message", text)


## Turn 90 degrees: +1 = left (counter-clockwise), -1 = right.
func _turn(direction: int) -> void:
	_cue("turn")
	facing = posmod(facing + direction, 4)
	yaw_degrees += 90.0 * direction
	tween = create_tween()
	tween.tween_property(self, "rotation_degrees:y", yaw_degrees, MOVE_TIME)
