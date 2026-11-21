extends "res://scripts/item_behaviour.gd"
## The behaviour of the Test Blade (data/debug/test_legendary.tres): a legendary made only to exercise the framework in the test room and
## the smoke test. It counts every hook, says so in the log for the rare ones, adds 1 to every landed blow, and sulks after SULK_AFTER seconds
## in a pack (its next landed blow does 2 less, once). Debug builds only: scripts/debug is left out of a release export.

const SULK_AFTER := 20.0

var counts := {"equip": 0, "unequip": 0, "hit": 0, "kill": 0, "tick": 0, "stowed": 0}
var tick_seconds := 0.0   # The time on_tick has been told about (a camped party tells it none).
var stowed_for := 0.0
var sulking := false


func on_equip(party: Node, m, _stack) -> void:
	counts.equip += 1
	stowed_for = 0.0
	party.get_tree().call_group("hud", "show_message", "The Test Blade wakes in %s's hand." % m.short_name())


func on_unequip(party: Node, m, _stack) -> void:
	counts.unequip += 1
	party.get_tree().call_group("hud", "show_message", "The Test Blade leaves %s's hand." % m.short_name())


func on_hit(_party: Node, _m, _stack, _target: Node, result: Dictionary) -> void:
	counts.hit += 1
	if sulking:
		sulking = false
		result.damage = maxi(0, result.damage - 2)
	else:
		result.damage += 1


func on_kill(party: Node, _m, _stack, _target: Node) -> void:
	counts.kill += 1
	party.get_tree().call_group("hud", "show_message", "The Test Blade is pleased.")


func on_tick(_party: Node, _m, _stack, delta: float) -> void:
	counts.tick += 1
	tick_seconds += delta


func on_stowed(party: Node, _m, _stack, delta: float) -> void:
	counts.stowed += 1
	stowed_for += delta
	if stowed_for >= SULK_AFTER and not sulking:
		sulking = true
		party.get_tree().call_group("hud", "show_message", "The Test Blade sulks in the pack.")
