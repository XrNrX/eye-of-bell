extends Node
## The party: up to four heroes in slots 0-3 (0 and 1 are the front row). Owns their
## HP and attack cooldowns and resolves fights with CombatRules.
## Other scripts talk to it through the "party" group:
##   attack(slot)            a hero swings at the tile in front of the player
##   take_hit_from(monster)  a monster next to the party attacks it
## The party HUD listens to its signals. The inventory screen calls use_item() when a
## consumable is right-clicked.

const DungeonMap := preload("res://scripts/dungeon_map.gd")
const CombatRules := preload("res://scripts/combat_rules.gd")
const ItemDef := preload("res://scripts/item_def.gd")

const MISSILE_RANGE := 4  # How many tiles down the corridor ahead a scroll's missile reaches.
const QUICK_SLOTS := 2        # Quick slots per member (see use_quick), shown under their portrait.
const QUICK_COOLDOWN := 1.0   # Seconds a quick slot is unusable after an item is used from it.

signal hp_changed(slot: int)
signal quick_changed(slot: int)  # A member's quick slots changed (contents or cooldown started).
signal cooldown_started(slot: int, duration: float)
signal hero_hit(slot: int, damage: int)  # damage 0 means the monster missed.
signal wiped

## Hero definitions (CharacterDef .tres), in slot order.
@export var hero_defs: Array[Resource] = []
@export var player_path: NodePath


## Backpack size and hand-slot count, shared by every member (see inventory_screen.gd).
const BACKPACK_SIZE := 12
const HAND_SLOTS := 2


class Member:
	var def: Resource
	var slot: int
	var hp: int
	var cooldown_left := 0.0

	# Inventory: ItemDef or null per slot. A weapon in a hand changes the member's
	# attack and damage (see Party.effective_stats); armour is still data only.
	var hands: Array = [null, null]
	var armour: Resource = null
	var backpack: Array = []

	# Quick slots: consumables ready to use with one click or a number key. Stored
	# here, on the runtime member, not on the CharacterDef -- that resource is shared
	# and must never be changed while the game runs. Cooldowns count down in
	# Party._process.
	var quick: Array = [null, null]
	var quick_cooldown: Array = [0.0, 0.0]

	func is_alive() -> bool:
		return hp > 0


## A member's attack numbers after their equipment is applied, in the same shape
## CombatRules.resolve_attack reads from a CharacterDef or MonsterDef.
class Stats:
	var attack: int
	var defence: int
	var damage_min: int
	var damage_max: int


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
		m.backpack.resize(BACKPACK_SIZE)
		members.append(m)


func _process(delta: float) -> void:
	for m in members:
		m.cooldown_left = maxf(0.0, m.cooldown_left - delta)
		for i in QUICK_SLOTS:
			m.quick_cooldown[i] = maxf(0.0, m.quick_cooldown[i] - delta)


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


## The weapon this member fights with: the first weapon in a hand slot (left hand
## first), or null for bare hands. A weapon in the backpack doesn't count.
func equipped_weapon(m: Member) -> Resource:
	for item in m.hands:
		if item != null and item.type == ItemDef.Type.WEAPON and item.damage_max > 0:
			return item
	return null


## The member's stats with their weapon applied: it adds its attack bonus and
## replaces their bare-handed damage range.
func effective_stats(m: Member) -> Stats:
	var s := Stats.new()
	s.attack = m.def.attack
	s.defence = m.def.defence
	s.damage_min = m.def.damage_min
	s.damage_max = m.def.damage_max
	var weapon := equipped_weapon(m)
	if weapon:
		s.attack += weapon.attack_bonus
		s.damage_min = weapon.damage_min
		s.damage_max = weapon.damage_max
	return s


## Remove and return a key from the first member whose backpack holds one, or null
## if the party has none. Dead members' packs count too, so a key can't end up
## stranded on a corpse with the door still locked. (Keys can only live in a
## backpack: hand and armour slots refuse them.)
func take_key() -> Resource:
	for m in members:
		for i in m.backpack.size():
			var item = m.backpack[i]
			if item != null and item.type == ItemDef.Type.KEY:
				m.backpack[i] = null
				return item
	return null


## Quick slots take consumables only (potions, scrolls, and later throwables).
func quick_accepts(def: Resource) -> bool:
	return def != null and def.type == ItemDef.Type.CONSUMABLE


## Put an item (or null, to empty it) in a quick slot. Returns false, changing
## nothing, if the slot doesn't exist or the item isn't a consumable.
func set_quick(slot: int, index: int, def: Resource) -> bool:
	var m := member(slot)
	if m == null or index < 0 or index >= QUICK_SLOTS:
		return false
	if def != null and not quick_accepts(def):
		return false
	m.quick[index] = def
	quick_changed.emit(slot)
	return true


## Use the item in a member's quick slot on that member, right now. A potion heals
## them; a scroll casts at the monster ahead (both via use_item). If it was used it
## is spent and the slot starts a cooldown; if it couldn't be (full health, nothing
## to target) nothing is spent and there is no cooldown. Nothing happens for an empty
## slot, a dead member, or a slot that is still cooling down. Returns use_item's
## {used, message, close} dictionary (used is false when nothing happened).
func use_quick(slot: int, index: int) -> Dictionary:
	var nothing := {"used": false, "message": "", "close": false}
	var m := member(slot)
	if m == null or index < 0 or index >= QUICK_SLOTS:
		return nothing
	var def = m.quick[index]
	if def == null or not m.is_alive() or m.quick_cooldown[index] > 0.0:
		return nothing
	var result := use_item(slot, def)
	if result.used:
		m.quick[index] = null
		m.quick_cooldown[index] = QUICK_COOLDOWN
		quick_changed.emit(slot)
	if result.message != "":
		_say(result.message)
	return result


## Use a consumable on behalf of a member. Returns {used: bool, message: String,
## close: bool}: `used` means it was spent (the caller removes it from the slot),
## `close` means the inventory screen should close so the result can be seen.
## A potion heals the member holding it; a scroll casts at the monster ahead.
func use_item(slot: int, def: Resource) -> Dictionary:
	var m := member(slot)
	if m == null or def == null or def.type != ItemDef.Type.CONSUMABLE:
		return {"used": false, "message": "", "close": false}
	if not m.is_alive():
		return {"used": false, "message": "%s is dead." % m.def.display_name, "close": false}
	if def.heal_amount > 0:
		return _drink(m, def)
	if def.spell_damage_max > 0:
		return _read_scroll(m, def)
	return {"used": false, "message": "Nothing happens.", "close": false}


func _drink(m: Member, def: Resource) -> Dictionary:
	if m.hp >= m.def.max_hp:
		return {"used": false, "message": "%s is already healthy." % m.def.display_name, "close": false}
	var healed := mini(def.heal_amount, m.def.max_hp - m.hp)
	m.hp += healed
	hp_changed.emit(m.slot)
	return {"used": true, "close": false,
		"message": "%s drinks the %s (+%d HP)." % [m.def.display_name, def.display_name, healed]}


## A scroll's missile: it flies straight ahead, stopping at walls and closed doors,
## and hits the first monster in range. It never misses.
func _read_scroll(m: Member, def: Resource) -> Dictionary:
	var target = _first_monster_ahead()
	if target == null:
		return {"used": false, "message": "There is nothing to target.", "close": false}
	var damage := CombatRules.roll_damage(def.spell_damage_min, def.spell_damage_max)
	target.take_hit({"hit": true, "damage": damage, "chance": 100})
	var text := "%s reads the scroll: it hits the %s for %d!" % [m.def.display_name, target.def.display_name, damage]
	if target.hp <= 0:
		text += " It dies!"
	return {"used": true, "message": text, "close": true}


func _first_monster_ahead() -> Node:
	var dir: Vector2i = player.DIRS[player.facing]
	for i in range(1, MISSILE_RANGE + 1):
		var cell: Vector2i = player.cell + dir * i
		if DungeonMap.is_blocked(cell):
			return null
		var monster = DungeonMap.occupied.get(cell)
		if monster != null and is_instance_valid(monster) and not monster.dying:
			return monster
	return null


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
	var result := CombatRules.resolve_attack(effective_stats(m), target.def)
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
