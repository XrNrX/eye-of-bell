extends Node
## A small puzzle system, all data (DungeonMap.PUZZLES, documented there): when every condition of a puzzle holds, its effects
## run, once. It listens to the event bus (GameEvents): ANY event re-checks every puzzle that has not fired, so a new kind of
## condition needs no call site anywhere, only a branch in met(). Add a condition or effect kind by adding a branch to met() or run().
## (S7 in docs/code_review.md. It used to be called by the dungeon builder after a lever pull and a purified wall.)
##
## Conditions are read from the live world (a lever that is on, a wall that is purified). A condition with MEMORY (levers pulled
## in order) keeps it in the run flags (DungeonMap.flags, saved), named "puzzle.<id>.<what>", and learns what happened from the
## event that woke the puzzle: met() is given the event's name and arguments. Effects can set a flag too, so one puzzle can wait
## on another.
##
## A node in the dungeon ("Puzzles", made by dungeon_builder.gd). Used by corrupted walls: purifying one is a condition, and
## purifying one is an effect, so a lever or another puzzle can burn one away. Run state (puzzles that have fired, doors they
## hold open) is in DungeonMap and is saved.

const Events := preload("res://scripts/game_events.gd")
const DungeonMap := preload("res://scripts/dungeon_map.gd")

var dungeon: Node
var _links := []  # [{signal, callable}] connected to the bus, dropped when this node leaves the tree


func _ready() -> void:
	dungeon = get_parent()
	var bus := get_node_or_null("/root/GameEvents")
	if bus == null:
		return  # A bare test scene: no news, so no puzzles stir.
	for info in bus.get_script().get_script_signal_list():  # GameEvents' own signals, not Node's.
		var event: String = info.name
		var count: int = info.args.size()
		var heard := func(a = null, b = null, c = null, d = null):
			check(dungeon, event, [a, b, c, d].slice(0, count))
		bus.connect(event, heard)
		_links.append({"signal": event, "callable": heard})


func _exit_tree() -> void:
	var bus := get_node_or_null("/root/GameEvents")
	if bus != null:
		for link in _links:
			if bus.is_connected(link.signal, link.callable):
				bus.disconnect(link.signal, link.callable)
	_links.clear()


## Fire every puzzle whose conditions now hold and that has not fired yet, and go round again if one did (its effects may have made
## another true). `event` and `args` are the news that woke it (conditions with memory read them; "" for a plain re-check). Returns
## the ids that fired.
static func check(dungeon: Node, event := "", args := []) -> Array:
	var fired := []
	var again := true
	while again:
		again = false
		for puzzle in DungeonMap.PUZZLES:
			var id: String = puzzle.id
			if DungeonMap.puzzles_done.has(id):
				continue
			# (Every condition is asked, even after one fails: a condition with memory must see every event.)
			var all := true
			for condition in puzzle.when:
				if not met(dungeon, condition, puzzle, event, args):
					all = false
			if not all:
				continue
			DungeonMap.puzzles_done[id] = true  # First, so an effect that triggers another check cannot fire it twice.
			for effect in puzzle.then:
				run(dungeon, effect)
			fired.append(id)
			again = true
			Events.send(dungeon.get_tree(), "puzzle_solved", [id])
	return fired


static func met(dungeon: Node, condition: Dictionary, puzzle := {}, event := "", args := []) -> bool:
	match condition.kind:
		"wall_purified":
			return DungeonMap.purified.has(condition.cell) and not DungeonMap.purify_pending.has(condition.cell)
		"lever_on":
			return dungeon.lever_on.get(Vector3i(condition.cell.x, condition.cell.y, int(condition.side)), false)
		"flag":
			return DungeonMap.flag(condition.name, false) == condition.get("value", true)
		"lever_order":
			return _lever_order(condition, puzzle, event, args)
	push_warning("puzzles: unknown condition kind '%s'" % condition.kind)
	return false


## The levers in `condition.levers` ({"cell", "side"} each) pulled one after another in that order. Progress is the run flag
## "puzzle.<id>.step" (saved): a pull of a listed lever that is the next one moves it on, any other listed lever sends it back to the
## start (counting that pull as a first one if it is), and levers not listed are ignored. Met once the last one has been pulled.
static func _lever_order(condition: Dictionary, puzzle: Dictionary, event: String, args: Array) -> bool:
	var flag_name := "puzzle.%s.step" % puzzle.get("id", "")
	var levers: Array = condition.levers
	var step := int(DungeonMap.flag(flag_name, 0))
	if event == "lever_pulled" and args.size() >= 2:
		var pulled := -1
		for i in levers.size():
			if levers[i].cell == args[0] and int(levers[i].side) == int(args[1]):
				pulled = i
		if pulled >= 0 and step < levers.size():
			if pulled == step:
				step += 1
			else:
				step = 1 if pulled == 0 else 0
			DungeonMap.set_flag(flag_name, step)
	return step >= levers.size()


static func run(dungeon: Node, effect: Dictionary) -> void:
	match effect.kind:
		"message":
			dungeon.get_tree().call_group("hud", "show_message", effect.text)
		"open_door":
			DungeonMap.puzzle_doors[effect.id] = true
			dungeon.refresh()
			dungeon.get_tree().call_group("audio", "play", "portcullis")
		"break_wall":
			dungeon.break_wall(effect.cell)
		"purify_wall":
			dungeon.purify_wall(effect.cell)
		"set_flag":
			DungeonMap.set_flag(effect.name, effect.get("value", true))
		_:
			push_warning("puzzles: unknown effect kind '%s'" % effect.kind)
