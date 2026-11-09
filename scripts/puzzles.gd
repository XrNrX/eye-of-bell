extends RefCounted
## A small puzzle system, all data (DungeonMap.PUZZLES, documented there): when every condition of a puzzle holds, its effects
## run, once. The dungeon builder calls check() whenever something a condition watches may have changed (a corrupted wall
## purified, a lever pulled). Add a condition or effect kind by adding a branch to met() or run().
##
## Used by corrupted walls: purifying one is a condition, and purifying one is an effect, so a lever or another puzzle can
## burn one away. Run state (puzzles that have fired, doors they hold open) is in DungeonMap and is saved.

const DungeonMap := preload("res://scripts/dungeon_map.gd")


## Fire every puzzle whose conditions now hold and that has not fired yet. Returns the ids that fired.
static func check(dungeon: Node) -> Array:
	var fired := []
	for puzzle in DungeonMap.PUZZLES:
		var id: String = puzzle.id
		if DungeonMap.puzzles_done.has(id):
			continue
		var all := true
		for condition in puzzle.when:
			if not met(dungeon, condition):
				all = false
				break
		if not all:
			continue
		DungeonMap.puzzles_done[id] = true  # First, so an effect that triggers another check cannot fire it twice.
		for effect in puzzle.then:
			run(dungeon, effect)
		fired.append(id)
	return fired


static func met(dungeon: Node, condition: Dictionary) -> bool:
	match condition.kind:
		"wall_purified":
			return DungeonMap.purified.has(condition.cell) and not DungeonMap.purify_pending.has(condition.cell)
		"lever_on":
			return dungeon.lever_on.get(Vector3i(condition.cell.x, condition.cell.y, int(condition.side)), false)
	push_warning("puzzles: unknown condition kind '%s'" % condition.kind)
	return false


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
		_:
			push_warning("puzzles: unknown effect kind '%s'" % effect.kind)
