extends Node
## The party: up to four heroes in slots 0-3 (0 and 1 are the front row). Owns their
## HP and attack cooldowns and resolves fights with CombatRules.
## Other scripts talk to it through the "party" group:
##   act(slot, hand)         a hero acts with what's in that hand (party HUD hand buttons):
##                           swing, throw, or "can't reach"; see action_for()
##   cast(slot, hand, spell, target)  cast a spell from the FOCUS in that hand
##   attack(slot)            a hero swings with their first weapon (older API, tests)
##   take_hit_from(monster)  a monster next to the party attacks it
## The party HUD listens to its signals and polls cooldowns, mana and buffs. The
## inventory screen calls use_item() when a consumable is right-clicked.
##
## One action cooldown per hero is shared by swinging, throwing and casting. Mana
## regenerates all the time; Shield/Bless are timed buffs counted in effective_stats(),
## which both sides of a fight read.

const DungeonMap := preload("res://scripts/dungeon_map.gd")
const CombatRules := preload("res://scripts/combat_rules.gd")
const ItemDef := preload("res://scripts/item_def.gd")
const ItemStack := preload("res://scripts/item_stack.gd")
const SpellDef := preload("res://scripts/spell_def.gd")

const MISSILE_RANGE := 4  # How many tiles down the corridor ahead a scroll's missile reaches.
const QUICK_SLOTS := 2        # Quick slots per member (see use_quick), shown under their portrait.
const QUICK_COOLDOWN := 1.0   # Seconds a quick slot is unusable after an item is used from it.
const MANA_REGEN_TIME := 2.5  # Seconds per point of mana regained (always; there's no resting yet).

## What clicking a hand does (see action_for).
enum Act { NOTHING, MELEE, THROW, SPELLS, CANT_REACH }

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

	# Inventory: an ItemStack or null per slot. Hands and armour hold one item, except
	# that a hand may hold a stack of a throwable (darts). A weapon in a hand changes the
	# member's attack and damage (see Party.effective_stats); armour is still data only.
	var hands: Array = [null, null]
	var armour: RefCounted = null
	var backpack: Array = []

	# Quick slots (ItemStack or null): consumables ready to use with one click or a number key. Stored
	# here, on the runtime member, not on the CharacterDef -- that resource is shared
	# and must never be changed while the game runs. Cooldowns count down in
	# Party._process.
	var quick: Array = [null, null]
	var quick_cooldown: Array = [0.0, 0.0]

	# Magic: mana (float, regenerating; spells need whole points) and active buffs,
	# each {"spell": SpellDef, "left": seconds}.
	var mana := 0.0
	var buffs: Array = []

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
		m.mana = m.def.max_mana
		m.backpack.resize(BACKPACK_SIZE)
		# Starting kit: what each hero holds when a run begins.
		for h in mini(HAND_SLOTS, m.def.start_hands.size()):
			var item: Resource = m.def.start_hands[h]
			if item != null:
				var n: int = m.def.start_hand_counts[h] if h < m.def.start_hand_counts.size() else 1
				m.hands[h] = ItemStack.of(item, maxi(1, n))
		members.append(m)


func _process(delta: float) -> void:
	for m in members:
		m.cooldown_left = maxf(0.0, m.cooldown_left - delta)
		for i in QUICK_SLOTS:
			m.quick_cooldown[i] = maxf(0.0, m.quick_cooldown[i] - delta)
		if m.is_alive():
			m.mana = minf(m.def.max_mana, m.mana + delta / MANA_REGEN_TIME)
		for b in m.buffs:
			b.left -= delta
		m.buffs = m.buffs.filter(func(b): return b.left > 0.0)


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
	for stack in m.hands:
		if stack != null and stack.def.type == ItemDef.Type.WEAPON and stack.def.damage_max > 0:
			return stack.def
	return null


## The member's stats with their gear and buffs applied. The weapon adds its attack
## bonus and replaces their bare-handed damage range: by default their first weapon
## (equipped_weapon), or with `hand` the melee weapon in that hand (bare hands if it
## holds none). Worn armour adds its defence_bonus. Buffs (Shield, Bless) add attack
## and defence, unless with_buffs is false (the character sheet shows gear alone).
func effective_stats(m: Member, hand := -1, with_buffs := true) -> Stats:
	var s := Stats.new()
	s.attack = m.def.attack
	s.defence = m.def.defence
	s.damage_min = m.def.damage_min
	s.damage_max = m.def.damage_max
	var weapon: Resource = equipped_weapon(m) if hand < 0 else _melee_weapon_in(m, hand)
	if weapon:
		s.attack += weapon.attack_bonus
		s.damage_min = weapon.damage_min
		s.damage_max = weapon.damage_max
	if m.armour != null:
		s.defence += m.armour.def.defence_bonus
	if with_buffs:
		for b in m.buffs:
			s.attack += b.spell.buff_attack
			s.defence += b.spell.buff_defence
	return s


func _melee_weapon_in(m: Member, hand: int) -> Resource:
	var stack = m.hands[hand]
	if stack != null and stack.def.type == ItemDef.Type.WEAPON and stack.def.melee and stack.def.damage_max > 0:
		return stack.def
	return null


func _start_cooldown(m: Member) -> void:
	var duration := CombatRules.hero_cooldown(m.def.speed)
	m.cooldown_left = duration
	cooldown_started.emit(m.slot, duration)


# --------------------------------------------------------------------------
# Hands: what clicking a hand button does
# --------------------------------------------------------------------------

## What clicking this hand would do right now. A melee weapon or an empty hand
## swings if the hero can melee (front row, or the hero in front is dead) and
## otherwise "can't reach". A throwable is thrown if it can't melee (darts) or the
## hero can't reach (the back row throws a dagger, the front row stabs with it). A
## FOCUS opens its spell list. Anything else (a potion) does nothing.
func action_for(slot: int, hand: int) -> int:
	var m := member(slot)
	if m == null or not m.is_alive() or hand < 0 or hand >= HAND_SLOTS:
		return Act.NOTHING
	var stack = m.hands[hand]
	if stack == null:
		return Act.MELEE if can_melee(slot) else Act.CANT_REACH
	var def: Resource = stack.def
	if def.type == ItemDef.Type.FOCUS:
		return Act.SPELLS
	if def.type != ItemDef.Type.WEAPON:
		return Act.NOTHING
	if def.can_throw() and (not def.melee or not can_melee(slot)):
		return Act.THROW
	if def.melee:
		return Act.MELEE if can_melee(slot) else Act.CANT_REACH
	return Act.NOTHING


## A hero acts with the item in one hand: swing or throw (each starts the shared
## action cooldown), or say they can't reach (no cooldown). SPELLS does nothing
## here: the party HUD opens the spell list and calls cast().
func act(slot: int, hand: int) -> void:
	var m := member(slot)
	if m == null or not m.is_alive() or m.cooldown_left > 0.0:
		return
	match action_for(slot, hand):
		Act.MELEE:
			_melee(m, hand)
		Act.THROW:
			_throw(m, hand)
		Act.CANT_REACH:
			_say("%s can't reach." % m.def.display_name)


## Throw one item from this hand straight ahead (see the blueprint): it hits the first
## monster within MISSILE_RANGE with a normal hit roll and lands on that monster's
## tile, hit or miss; with no monster it lands on the last open tile. A wall or closed
## door right in front means there's nowhere to throw: refused, no cooldown.
func _throw(m: Member, hand: int) -> void:
	var stack = m.hands[hand]
	var def: Resource = stack.def
	var dir: Vector2i = player.DIRS[player.facing]
	if DungeonMap.is_blocked(player.cell + dir):
		_say("There's no room to throw.")
		return
	var land: Vector2i = player.cell
	var target = null
	for i in range(1, MISSILE_RANGE + 1):
		var cell: Vector2i = player.cell + dir * i
		if DungeonMap.is_blocked(cell):
			break
		land = cell
		var monster = DungeonMap.occupied.get(cell)
		if monster != null and is_instance_valid(monster) and not monster.dying:
			target = monster
			break
	_start_cooldown(m)
	var piece: RefCounted = stack.take_one()
	if stack.count <= 0:
		m.hands[hand] = null
	var dungeon = get_tree().get_first_node_in_group("dungeon")
	if dungeon:
		dungeon.place_item(land, piece)
		dungeon.show_throw(player.cell, land, def)
	if target == null:
		_say("%s throws the %s." % [m.def.display_name, def.display_name])
		return
	var s := Stats.new()  # The thrower's attack (with buffs) plus the item's bonus.
	s.attack = m.def.attack + def.attack_bonus
	for buff in m.buffs:
		s.attack += buff.spell.buff_attack
	s.damage_min = def.throw_damage_min
	s.damage_max = def.throw_damage_max
	var result := CombatRules.resolve_attack(s, target.def)
	target.take_hit(result)
	if not result.hit:
		_say("%s throws the %s and misses." % [m.def.display_name, def.display_name])
	elif target.hp <= 0:
		_say("%s kills the %s with the %s!" % [m.def.display_name, target.def.display_name, def.display_name])
	else:
		_say("%s hits the %s with the %s for %d." % [m.def.display_name, target.def.display_name, def.display_name, result.damage])


# --------------------------------------------------------------------------
# Spells
# --------------------------------------------------------------------------

## Why this hero can't cast from the item in this hand, or "" if they can: it must
## be a FOCUS whose magic matches theirs (a Mage reads a spellbook, a Cleric uses a
## holy symbol).
func cast_refusal(slot: int, hand: int) -> String:
	var m := member(slot)
	if m == null or not m.is_alive():
		return ""
	var stack = m.hands[hand]
	if stack == null or stack.def.type != ItemDef.Type.FOCUS:
		return "Nothing to cast from."
	if m.def.max_mana <= 0 or m.def.magic != stack.def.magic:
		return "The %s can't make sense of the %s." % [m.def.display_name, stack.def.display_name]
	return ""


## The spells the FOCUS in this hand offers this hero (empty if they can't use it).
func spells_in(slot: int, hand: int) -> Array:
	if cast_refusal(slot, hand) != "":
		return []
	return member(slot).hands[hand].def.spells


func can_afford(slot: int, spell: Resource) -> bool:
	var m := member(slot)
	return m != null and int(m.mana) >= spell.mana_cost


## Cast a spell from the FOCUS in a hand. target_slot is the hero for HERO spells
## (Shield, Heal). A spell that can't take effect (nothing ahead, Heal at full health,
## a dead target) costs nothing and starts no cooldown, like potions and scrolls.
## Otherwise it spends the mana and starts the caster's action cooldown. Returns
## whether it was cast.
func cast(slot: int, hand: int, spell: Resource, target_slot := -1) -> bool:
	var m := member(slot)
	if m == null or not m.is_alive() or m.cooldown_left > 0.0:
		return false
	if not (spell in spells_in(slot, hand)):
		return false
	if not can_afford(slot, spell):
		_say("Not enough mana.")
		return false
	var who: String = m.def.display_name
	var text := ""
	match spell.target:
		SpellDef.Target.AHEAD:
			var monster = _first_monster_ahead()
			if monster == null:
				_say("There is nothing to target.")
				return false
			var damage := CombatRules.roll_damage(spell.damage_min, spell.damage_max)
			monster.take_hit({"hit": true, "damage": damage, "chance": 100})
			text = "%s casts %s: it hits the %s for %d!" % [who, spell.display_name, monster.def.display_name, damage]
			if monster.hp <= 0:
				text += " It dies!"
		SpellDef.Target.HERO:
			var t := member(target_slot)
			if t == null or not t.is_alive():
				_say("%s is beyond help." % t.def.display_name if t else "No one to target.")
				return false
			if spell.heal_max > 0:
				if t.hp >= t.def.max_hp:
					_say("%s is already healthy." % t.def.display_name)
					return false
				var healed := mini(CombatRules.roll_damage(spell.heal_min, spell.heal_max), t.def.max_hp - t.hp)
				t.hp += healed
				hp_changed.emit(t.slot)
				text = "%s casts %s on %s (+%d HP)." % [who, spell.display_name, t.def.display_name, healed]
			if spell.duration > 0.0:
				_add_buff(t, spell)
				text = "%s casts %s on %s." % [who, spell.display_name, t.def.display_name]
		SpellDef.Target.PARTY:
			for other in members:
				if other.is_alive():
					_add_buff(other, spell)
			text = "%s casts %s." % [who, spell.display_name]
	m.mana -= spell.mana_cost
	_start_cooldown(m)
	_say(text)
	return true


## Start a buff, or refresh it if it's already running (buffs don't stack).
func _add_buff(m: Member, spell: Resource) -> void:
	for b in m.buffs:
		if b.spell == spell:
			b.left = spell.duration
			return
	m.buffs.append({"spell": spell, "left": spell.duration})


## Remove and return a key from the first member whose backpack holds one, or null
## if the party has none. Dead members' packs count too, so a key can't end up
## stranded on a corpse with the door still locked. (Keys can only live in a
## backpack: hand and armour slots refuse them.)
func take_key() -> Resource:
	for m in members:
		for i in m.backpack.size():
			var stack = m.backpack[i]
			if stack != null and stack.def.type == ItemDef.Type.KEY:
				stack.count -= 1
				if stack.count <= 0:
					m.backpack[i] = null
				return stack.def
	return null


## Put a stack in a member's backpack: top up matching stacks first, then use the
## first empty cell. Returns true if all of it fit; otherwise whatever didn't fit is
## left in `stack` (its count reduced) and the backpack is as full as it can be.
func add_to_backpack(slot: int, stack: RefCounted) -> bool:
	var m := member(slot)
	for s in m.backpack:
		if s != null and s.can_stack_with(stack):
			s.merge_from(stack)
			if stack.count <= 0:
				return true
	var i: int = m.backpack.find(null)
	if i < 0:
		return false
	m.backpack[i] = stack
	return true


## Quick slots take consumables only (potions, scrolls, and later throwables).
func quick_accepts(item) -> bool:
	var stack := ItemStack.wrap(item)
	return stack != null and stack.def.type == ItemDef.Type.CONSUMABLE


## Put an item stack (or an ItemDef, or null to empty it) in a quick slot, replacing
## what's there. Returns false, changing nothing, if the slot doesn't exist or the
## item isn't a consumable.
func set_quick(slot: int, index: int, item) -> bool:
	var m := member(slot)
	if m == null or index < 0 or index >= QUICK_SLOTS:
		return false
	if item != null and not quick_accepts(item):
		return false
	m.quick[index] = ItemStack.wrap(item)
	quick_changed.emit(slot)
	return true


## Top up the stack in a quick slot from `stack` (same stackable item), moving as many
## as fit out of it. Returns how many moved.
func merge_quick(slot: int, index: int, stack: RefCounted) -> int:
	var m := member(slot)
	if m == null or m.quick[index] == null:
		return 0
	var moved: int = m.quick[index].merge_from(stack)
	if moved > 0:
		quick_changed.emit(slot)
	return moved


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
	var stack = m.quick[index]
	if stack == null or not m.is_alive() or m.quick_cooldown[index] > 0.0:
		return nothing
	var result := use_item(slot, stack.def)
	if result.used:
		stack.count -= 1  # Uses one item from the stack.
		if stack.count <= 0:
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


## A hero attacks the tile in front of the player with their first weapon. Swinging
## at an empty tile still uses the cooldown (as in Eye of the Beholder). The HUD's hand
## buttons use act() instead, which swings with that hand's weapon.
func attack(slot: int) -> void:
	var m := member(slot)
	if m == null or not m.is_alive() or m.cooldown_left > 0.0 or not can_melee(slot):
		return
	_melee(m, -1)


## Swing at the tile in front; hand -1 means "first weapon" (see effective_stats).
func _melee(m: Member, hand: int) -> void:
	_start_cooldown(m)
	var front: Vector2i = player.cell + player.DIRS[player.facing]
	var target = DungeonMap.occupied.get(front)
	if target == null or not is_instance_valid(target) or target.dying:
		return
	var result := CombatRules.resolve_attack(effective_stats(m, hand), target.def)
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
	# The hero's effective stats, so Shield (and later armour) counts.
	var result := CombatRules.resolve_attack(monster.def, effective_stats(m))
	if result.hit:
		m.hp = maxi(0, m.hp - result.damage)
		if m.hp == 0:
			m.buffs.clear()
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
