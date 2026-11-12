extends Node
## Knows whether the party is in a fight (docs/code_review.md, M4). Banter, resting, ambush locks and anything else that must
## behave differently "in a fight" ask this node or listen to GameEvents.fight_started / fight_ended. Party builds one in
## _ready (group "fight_tracker"); scripts never hold it, they call through the group or read `Party.fight`:
##
##     get_tree().call_group("fight_tracker", "blow")             # something struck something (Monster.take_hit, Party.take_hit_from)
##     get_tree().call_group("fight_tracker", "noticed", monster)  # a monster saw the party or stands next to it (Monster._on_tick)
##
## A FIGHT STARTS with the first blow, struck or taken, a hit or a miss (a thrown dagger, a Fireball, a monster's swing), or
## when a monster newly notices the party. It is OVER once nothing has been struck for `fight_clear_seconds` and no living
## monster is aware of the party, or for `fight_gap_seconds` if some still are (a monster watching through a portcullis does
## not keep the fight on for ever). A monster stays "aware" for AWARE_SECONDS after its last notice (its AI ticks about every
## 0.8 s). Both times are in data/spell_effects.tres ("Hit direction" group). The clock stops while the game is paused.
## `behind_warned` is the "Something's behind you!" flag: it is said once a fight and cleared when the fight ends.

const Events := preload("res://scripts/game_events.gd")
const SpellEffectsConfig := preload("res://scripts/spell_effects_config.gd")

const AWARE_SECONDS := 2.0

var in_fight := false
var behind_warned := false
var since_blow := 0.0         # Seconds since something was last struck, while a fight is on.
var _aware := {}              # Monster node -> seconds left as aware of the party.


func _enter_tree() -> void:
	add_to_group("fight_tracker")


## Something was struck, by the party or by a monster.
func blow() -> void:
	since_blow = 0.0
	_begin()


## A monster can see the party, or is next to it. Only a monster that was not already aware starts a fight by itself.
func noticed(monster: Node) -> void:
	var fresh := not _aware.has(monster)
	_aware[monster] = AWARE_SECONDS
	if fresh:
		_begin()


func aware_count() -> int:
	return _aware.size()


## For the test room's help overlay: "OFF" or "ON, quiet 2.1 s, 1 aware".
func status() -> String:
	if not in_fight:
		return "OFF"
	return "ON  QUIET %.1fS  AWARE %d" % [since_blow, _aware.size()]


func _begin() -> void:
	if in_fight:
		return
	in_fight = true
	since_blow = 0.0
	Events.send(get_tree(), "fight_started")


func _end() -> void:
	in_fight = false
	behind_warned = false
	since_blow = 0.0
	Events.send(get_tree(), "fight_ended")


func _process(delta: float) -> void:
	for monster in _aware.keys():  # The dead and the gone no longer count.
		if not is_instance_valid(monster) or monster.dying:
			_aware.erase(monster)
		else:
			_aware[monster] -= delta
			if _aware[monster] <= 0.0:
				_aware.erase(monster)
	if not in_fight:
		return
	since_blow += delta
	var config: Resource = SpellEffectsConfig.get_config()
	var limit: float = config.fight_gap_seconds if not _aware.is_empty() else config.fight_clear_seconds
	if since_blow >= limit:
		_end()
