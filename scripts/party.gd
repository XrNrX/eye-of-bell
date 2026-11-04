extends Node
## The party: up to four heroes in slots 0-3 (0 and 1 are the front row). Owns their
## HP and attack cooldowns and resolves fights with CombatRules.
## Other scripts talk to it through the "party" group:
##   attack(slot)            a hero swings at the tile in front of the player
##   take_hit_from(monster)  a monster next to the party attacks it
## The party HUD listens to its signals.

const DungeonMap := preload("res://scripts/dungeon_map.gd")
const CombatRules := preload("res://scripts/combat_rules.gd")

signal hp_changed(slot: int)
signal cooldown_started(slot: int, duration: float)
signal hero_hit(slot: int, damage: int)  # damage 0 means the monster missed.
signal wiped

## Hero definitions (CharacterDef .tres), in slot order.
@export var hero_defs: Array[Resource] = []
@export var player_path: NodePath


class Member:
	var def: Resource
	var slot: int
	var hp: int
	var cooldown_left := 0.0

	func is_alive() -> bool:
		return hp > 0


var members: Array = []  # Member per slot.
@onready var player: Node3D = get_node_or_null(player_path)


func _enter_tree() -> void:
	add_to_group("party")


func _ready() -> void:
	for i in hero_defs.size():
		var m := Member.new()
		m.def = hero_defs[i]
		m.slot = i
		m.hp = m.def.max_hp
		members.append(m)


func _process(delta: float) -> void:
	for m in members:
		m.cooldown_left = maxf(0.0, m.cooldown_left - delta)


func member(slot: int) -> Member:
	return members[slot] if slot >= 0 and slot < members.size() else null


## Front row can always melee; a back-row hero can once the hero in front is dead.
func can_melee(slot: int) -> bool:
	if slot < 2:
		return true
	var front := member(slot - 2)
	return front == null or not front.is_alive()


func is_wiped() -> bool:
	return members.all(func(m): return not m.is_alive())


## A hero attacks the tile in front of the player. Swinging at an empty tile still
## uses the cooldown (as in Eye of the Beholder).
func attack(slot: int) -> void:
	var m := member(slot)
	if m == null or not m.is_alive() or m.cooldown_left > 0.0 or not can_melee(slot):
		return
	var duration := CombatRules.hero_cooldown(m.def.speed)
	m.cooldown_left = duration
	cooldown_started.emit(slot, duration)

	var front: Vector2i = player.cell + player.DIRS[player.facing]
	var target = DungeonMap.occupied.get(front)
	if target == null or not is_instance_valid(target) or target.dying:
		return
	var result := CombatRules.resolve_attack(m.def, target.def)
	target.take_hit(result)
	if not result.hit:
		_say("%s misses." % m.def.display_name)
	elif target.hp <= 0:
		_say("%s kills the %s!" % [m.def.display_name, target.def.display_name])
	else:
		_say("%s hits the %s for %d." % [m.def.display_name, target.def.display_name, result.damage])


## A monster next to the party attacks. Who it can reach depends on which side it
## is on: front -> front row, behind -> back row, left/right -> that column.
func take_hit_from(monster: Node) -> void:
	var targets := _reachable_from(monster.cell)
	if targets.is_empty():
		return
	var m: Member = targets[CombatRules.rng().randi_range(0, targets.size() - 1)]
	var result := CombatRules.resolve_attack(monster.def, m.def)
	if result.hit:
		m.hp = maxi(0, m.hp - result.damage)
		hp_changed.emit(m.slot)
		_say("The %s hits %s for %d." % [monster.def.display_name, m.def.display_name, result.damage])
	else:
		_say("The %s misses %s." % [monster.def.display_name, m.def.display_name])
	hero_hit.emit(m.slot, result.damage)
	if is_wiped():
		wiped.emit()
		get_tree().call_group("game_over", "show_screen")


func _reachable_from(monster_cell: Vector2i) -> Array:
	var living := members.filter(func(m): return m.is_alive())
	var side: Vector2i = monster_cell - player.cell
	var f: int = player.facing
	var slots := [1, 3]                       # Right column.
	if side == player.DIRS[f]:
		slots = [0, 1]                        # In front: front row.
	elif side == player.DIRS[(f + 2) % 4]:
		slots = [2, 3]                        # Behind: back row.
	elif side == player.DIRS[(f + 1) % 4]:
		slots = [0, 2]                        # Left column.
	var reachable := living.filter(func(m): return m.slot in slots)
	return reachable if not reachable.is_empty() else living


func _say(text: String) -> void:
	get_tree().call_group("hud", "show_message", text)
