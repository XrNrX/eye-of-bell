extends Node
## The party: up to four heroes in slots 0-3 (0 and 1 are the front row). Owns their
## HP and attack cooldowns and resolves fights with CombatRules.
## Other scripts talk to it through the "party" group:
##   act(slot, hand)         a hero acts with what's in that hand (party HUD hand buttons):
##                           swing, throw, or "can't reach"; see action_for()
##   cast(slot, hand, spell, target)  cast a spell from the FOCUS in that hand
##   place_in_hand / place_in_quick(slot, i, cursor)  click-with-an-item on the party panel
##   return_to_origin(stack)  a thrown item picked up off the floor goes back to its slot
##   stow(stack)              shift-click on a floor item: first free quick slot, else a backpack
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

const SpellEffectsConfig := preload("res://scripts/spell_effects_config.gd")
const NO_CELL := Vector2i(-1, -1)
const MISSILE_RANGE := 4  # How many tiles down the corridor ahead a scroll's missile reaches.
const QUICK_SLOTS := 2        # Quick slots per member (see use_quick), shown under their portrait.
const QUICK_COOLDOWN := 1.0   # Seconds a quick slot is unusable after an item is used from it.
const MANA_REGEN_TIME := 2.5  # Seconds per point of mana regained (always; there's no resting yet).

## What clicking a hand does (see action_for).
enum Act { NOTHING, MELEE, THROW, SPELLS, CANT_REACH }

signal hp_changed(slot: int)
signal formation_changed  # The party was rearranged (see set_formation); HUDs redraw every panel.
signal quick_changed(slot: int)  # A member's quick slots changed (contents or cooldown started).
signal cooldown_started(slot: int, duration: float)
signal hero_hit(slot: int, damage: int)  # damage 0 means the monster missed.
signal holy_cast(slot: int, hand: int, spell: Resource)  # A Heal or Bless was cast from a holy symbol in this hand.
signal wiped

## Hero definitions (CharacterDef .tres), in slot order.
@export var hero_defs: Array[Resource] = []
@export var player_path: NodePath


## Backpack size and hand-slot count, shared by every member (see inventory_screen.gd).
const BACKPACK_SIZE := 12
const HAND_SLOTS := 2


class Member:
	var def: Resource
	var hero_index: int  # Which hero this is (index into hero_defs). Never changes.
	var slot: int        # Where they stand now: 0-3, front row first. Changes when the formation does.
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


var members: Array = []  # Member per position (slot), front row first. Reordered by set_formation.

## The formation: the hero_index standing in each position, e.g. [0, 1, 2, 3] by default
## or [2, 1, 0, 3] after the fighter and thief swap. This is the party data a save/load
## stores; restore it with set_formation(). Everything keyed by position (front row =
## slots 0-1, who can melee, who a monster can reach, the HUD panels) follows it.
var formation: Array[int] = []
@onready var player: Node3D = get_node_or_null(player_path)


func _enter_tree() -> void:
	add_to_group("party")


func _ready() -> void:
	for i in hero_defs.size():
		var m := Member.new()
		m.def = hero_defs[i]
		m.hero_index = i
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
		formation.append(i)


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


## Swap two positions (e.g. drag one portrait onto another). Whole characters move:
## their stats, hands, backpack, quick slots, mana and buffs are on the Member and go
## with them. Dead characters can be swapped too. Returns false for a bad position.
func swap_positions(a: int, b: int) -> bool:
	if a == b or member(a) == null or member(b) == null:
		return false
	var order := formation.duplicate()
	var t = order[a]
	order[a] = order[b]
	order[b] = t
	var names := "%s and %s" % [member(a).def.display_name, member(b).def.display_name]
	set_formation(order)
	_cue("ui_swap")
	_say("%s swap places." % names)
	return true


## Apply a formation: the hero_index for each position. It must be a permutation of
## every hero (otherwise nothing changes and false is returned). Used by swap_positions
## and, later, by loading a save.
func set_formation(order: Array) -> bool:
	if order.size() != members.size():
		return false
	var by_hero := {}
	for m in members:
		by_hero[m.hero_index] = m
	var seen := {}
	for h in order:
		if not by_hero.has(h) or seen.has(h):
			return false
		seen[h] = true
	var reordered := []
	for pos in order.size():
		var m = by_hero[order[pos]]
		m.slot = pos
		reordered.append(m)
	members = reordered
	formation.assign(order)
	for pos in members.size():
		quick_changed.emit(pos)  # Quick-slot widgets are keyed by position: redraw them.
	formation_changed.emit()
	return true


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
	_do_throw(m, {"where": "hand", "index": hand})


## The item a throw would take from: {"where": "hand" or "quick", "index": n}.
func _source_stack(m: Member, source: Dictionary):
	return m.hands[source.index] if source.where == "hand" else m.quick[source.index]


## Throw one item from a hand or quick slot. Returns whether it was thrown. The piece
## that lands on the floor remembers where it came from (see return_to_origin).
func _do_throw(m: Member, source: Dictionary) -> bool:
	var stack = _source_stack(m, source)
	var def: Resource = stack.def
	var dir: Vector2i = player.DIRS[player.facing]
	if DungeonMap.is_blocked(player.cell + dir):
		_say("There's no room to throw.")
		return false
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
	piece.origin = {"hero": m.hero_index, "where": source.where, "index": source.index}
	if stack.count <= 0:
		if source.where == "hand":
			m.hands[source.index] = null
		else:
			m.quick[source.index] = null
	if source.where == "quick":
		quick_changed.emit(m.slot)
	var dungeon = get_tree().get_first_node_in_group("dungeon")
	_cue("throw")
	if dungeon:
		dungeon.place_item(land, piece)
		dungeon.show_throw(player.cell, land, def)
	if target == null:
		_say("%s throws the %s." % [m.def.display_name, def.display_name])
		return true
	var s := Stats.new()  # The thrower's attack (with buffs) plus the item's bonus.
	s.attack = m.def.attack + def.attack_bonus
	for buff in m.buffs:
		s.attack += buff.spell.buff_attack
	s.damage_min = def.throw_damage_min
	s.damage_max = def.throw_damage_max
	var result := CombatRules.resolve_attack(s, target.def)
	target.take_hit(result)
	if not result.hit:
		_say("%s's %s misses the %s." % [m.def.display_name, def.display_name, target.def.display_name], "miss")
	elif target.hp <= 0:
		_say("%s kills the %s with the %s!" % [m.def.display_name, target.def.display_name, def.display_name])
	else:
		_say("%s hits the %s with the %s for %d." % [m.def.display_name, target.def.display_name, def.display_name, result.damage])
	return true


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
		if m.def.magic == ItemDef.Magic.DIVINE:
			return "You need your holy symbol."  # The cleric prays through it; it must be in a hand.
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
		if m.def.magic == ItemDef.Magic.DIVINE and cast_refusal(slot, hand) != "":
			_say("You need your holy symbol.")
		return false
	if not can_afford(slot, spell):
		_say("Not enough mana.")
		return false
	var who: String = m.def.display_name
	var text := ""
	match spell.target:
		SpellDef.Target.AHEAD:
			var monster = _first_monster_ahead()
			var wall := NO_CELL
			if monster == null and spell.breaks_walls:
				wall = _cracked_wall_ahead()  # A blast can also be aimed at a cracked wall.
			if monster == null and wall == NO_CELL:
				_say("There is nothing to target.")
				return false
			if monster == null:
				var dir: Vector2i = player.DIRS[player.facing]
				var burst_at: Vector2i = wall - dir if wall - dir != player.cell else wall
				_fx(spell.effect, burst_at)
				_break_wall(wall, player.cell, burst_at)
				text = "%s casts %s: the cracked wall explodes!" % [who, spell.display_name]
			else:
				var damage := CombatRules.roll_damage(spell.damage_min, spell.damage_max)
				monster.take_hit({"hit": true, "damage": damage, "chance": 100})
				var caught := 0
				if spell.splash_radius > 0:
					caught = _splash(monster, spell.splash_radius, maxi(1, ceili(damage * spell.splash_percent / 100.0)))
				var opened := 0
				if spell.breaks_walls:  # The shockwave cracks open any cracked wall beside the target.
					opened = _break_walls_near(monster.cell, maxi(1, spell.splash_radius))
				_fx(spell.effect, monster.cell)
				text = "%s casts %s: it hits the %s for %d!" % [who, spell.display_name, monster.def.display_name, damage]
				if monster.hp <= 0:
					text += " It dies!"
				if caught > 0:
					text += " %d more %s caught in the blast." % [caught, "is" if caught == 1 else "are"]
				if opened > 0:
					text += " The blast breaks open the wall!"
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
	if spell.sound != "":
		_cue(spell.sound)
	if spell.target != SpellDef.Target.AHEAD:
		_fx(spell.effect)
	var focus = m.hands[hand]
	if focus != null and focus.def.magic == ItemDef.Magic.DIVINE and spell.effect in ["heal", "bless"]:
		get_tree().call_group("spell_effects", "holy_pulse")  # The one pure warm light in a cursed land.
		holy_cast.emit(slot, hand, spell)
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


## Quick slots take consumables (potions, scrolls) and throwables (daggers, darts).
func quick_accepts(item) -> bool:
	var stack := ItemStack.wrap(item)
	return stack != null and (stack.def.type == ItemDef.Type.CONSUMABLE or stack.def.can_throw())


## Put an item stack (or an ItemDef, or null to empty it) in a quick slot, replacing
## what's there. Returns false, changing nothing, if the slot doesn't exist or the
## item isn't something a quick slot takes (see quick_accepts).
func set_quick(slot: int, index: int, item) -> bool:
	var m := member(slot)
	if m == null or index < 0 or index >= QUICK_SLOTS:
		return false
	if item != null and not quick_accepts(item):
		return false
	m.quick[index] = ItemStack.wrap(item)
	quick_changed.emit(slot)
	return true


## Click a quick slot while holding an item on the cursor: put it in (it must be
## something quick slots take), top up a matching stack, or swap with what's there (the old
## item goes onto the cursor). Returns "" on success, or why it wasn't done.
func place_in_quick(slot: int, index: int, cursor: Node) -> String:
	var m := member(slot)
	if m == null or index < 0 or index >= QUICK_SLOTS:
		return ""
	if not m.is_alive():
		return "%s is dead." % m.def.display_name
	var held: RefCounted = cursor.held
	if not quick_accepts(held):
		return "The %s can't go in a quick slot." % held.def.display_name
	var here = m.quick[index]
	if here != null and here.can_stack_with(held) and here.room() > 0:
		merge_quick(slot, index, held)  # The overflow stays on the cursor.
		if held.count <= 0:
			cursor.release()
		else:
			cursor.refresh()
		return ""
	set_quick(slot, index, cursor.release())
	if here != null:
		cursor.hold(here)
	return ""


## Why a hand can't take this stack, or "": the right kind of item, and one at a time
## except a stack of a throwable (darts), so they can be thrown one after another.
func hand_refusal(stack: RefCounted) -> String:
	if not ItemDef.allowed_in_hand(stack.def.type):
		return "The %s doesn't go there." % stack.def.display_name
	if stack.count > 1 and not stack.def.can_throw():
		return "Only one at a time goes there."
	return ""


## Click a hand while holding an item on the cursor: same rules as a quick slot
## (place, top up a matching stack, or swap), for a hand. Returns "" or the reason.
func place_in_hand(slot: int, hand: int, cursor: Node) -> String:
	var m := member(slot)
	if m == null or hand < 0 or hand >= HAND_SLOTS:
		return ""
	if not m.is_alive():
		return "%s is dead." % m.def.display_name
	var held: RefCounted = cursor.held
	var why := hand_refusal(held)
	if why != "":
		return why
	var here = m.hands[hand]
	if here != null and here.can_stack_with(held) and here.room() > 0 and held.def.can_throw():
		here.merge_from(held)
		if held.count <= 0:
			cursor.release()
		else:
			cursor.refresh()
		return ""
	m.hands[hand] = cursor.release()
	if here != null:
		cursor.hold(here)
	return ""


## A thrown item was picked up off the floor: send it home if it can go. It returns to
## the slot (hand or quick) it was thrown from if that slot is empty, or holds the same
## stack with room for all of it, and the hero is alive. Returns the message to show, or ""
## if it can't go home (the caller puts it on the cursor instead).
func return_to_origin(stack: RefCounted) -> String:
	var o: Dictionary = stack.origin
	if o.is_empty():
		return ""
	var m: Member = null
	for candidate in members:
		if candidate.hero_index == o.hero:
			m = candidate
	if m == null or not m.is_alive():
		return ""
	var slots: Array = m.hands if o.where == "hand" else m.quick
	var here = slots[o.index]
	if here == null:
		slots[o.index] = stack
	elif here.can_stack_with(stack) and here.room() >= stack.count:
		here.merge_from(stack)
	else:
		return ""
	stack.origin = {}
	if o.where == "quick":
		quick_changed.emit(m.slot)
	return "%s takes back the %s." % [m.def.display_name, stack.def.display_name.to_lower()]


## Shift-click on a floor item: send as much of the stack as fits to the first free
## matching quick slot in party order (an empty one, or one holding the same item with
## room), then to the first living hero's backpack with room. Moves items out of `stack`
## (its count drops) and returns the message, or "" if nothing fit.
func stow(stack: RefCounted) -> String:
	var message := ""
	var item_name: String = stack.def.display_name.to_lower()
	if quick_accepts(stack):
		for m in members:
			if not m.is_alive():
				continue
			for i in QUICK_SLOTS:
				if stack.count <= 0:
					break
				var here = m.quick[i]
				var moved := 0
				if here == null:
					m.quick[i] = ItemStack.of(stack.def, stack.count)
					moved = stack.count
					stack.count = 0
				elif here.can_stack_with(stack) and here.room() > 0:
					moved = here.merge_from(stack)
				if moved > 0:
					quick_changed.emit(m.slot)
					if message == "":
						message = "%s readies the %s." % [m.def.display_name, item_name]
	if stack.count > 0:
		for m in members:
			if not m.is_alive():
				continue
			var before: int = stack.count
			var copy := ItemStack.of(stack.def, stack.count)
			if add_to_backpack(m.slot, copy):
				stack.count = 0
			else:
				stack.count = copy.count  # Whatever didn't fit (it may have topped up stacks).
			if stack.count < before and message == "":
				message = "%s stows the %s." % [m.def.display_name, item_name]
			if stack.count <= 0:
				break
	return message


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


## Use the item in a member's quick slot, right now. A throwable is thrown at the monster
## ahead (one from the stack; it uses the hero's action cooldown, not the slot's). A potion heals
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
	if stack.def.can_throw():
		if m.cooldown_left > 0.0:
			return nothing
		return {"used": _do_throw(m, {"where": "quick", "index": index}), "message": "", "close": false}
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
	_cue("potion")
	return {"used": true, "close": false,
		"message": "%s drinks the %s (+%d HP)." % [m.def.display_name, def.display_name, healed]}


## A scroll's missile: it flies straight ahead, stopping at walls and closed doors,
## and hits the first monster in range. It never misses.
func _read_scroll(m: Member, def: Resource) -> Dictionary:
	var target = _first_monster_ahead()
	if target == null:
		return {"used": false, "message": "There is nothing to target.", "close": false}
	var damage := CombatRules.roll_damage(def.spell_damage_min, def.spell_damage_max)
	_cue("zap")
	_fx("missile", target.cell)
	target.take_hit({"hit": true, "damage": damage, "chance": 100})
	var text := "%s reads the scroll: it hits the %s for %d!" % [m.def.display_name, target.def.display_name, damage]
	if target.hp <= 0:
		text += " It dies!"
	return {"used": true, "message": text, "close": true}


## A blast's splash: every other living monster within `radius` tiles (the 8 around, for 1) of
## the target takes `damage` (already worked out: no roll, no hit chance). Returns how many were hit.
## Walls and closed doors hold no monsters, so nothing passes through them; the party is never hurt.
func _splash(target: Node, radius: int, damage: int) -> int:
	var count := 0
	for other in DungeonMap.occupied.values().duplicate():
		if other == target or not is_instance_valid(other) or other.dying:
			continue
		var d: Vector2i = (other.cell - target.cell).abs()
		if maxi(d.x, d.y) <= radius:
			other.take_hit({"hit": true, "damage": damage, "chance": 100})
			count += 1
	return count


## The cracked wall straight ahead if nothing else (a wall, a door, a portcullis) is in the way
## within missile range, else NO_CELL.
func _cracked_wall_ahead() -> Vector2i:
	var dir: Vector2i = player.DIRS[player.facing]
	for i in range(1, MISSILE_RANGE + 1):
		var c: Vector2i = player.cell + dir * i
		if DungeonMap.is_blocked(c):
			return c if DungeonMap.is_destructible(c) else NO_CELL
	return NO_CELL


## Break a cracked wall, timed to land with a projectile that flies from `from` to `at`.
func _break_wall(wall: Vector2i, from: Vector2i, at: Vector2i) -> void:
	var dungeon := get_tree().get_first_node_in_group("dungeon")
	if dungeon == null:
		return
	var tiles := maxf(1.0, (at - from).length())
	dungeon.break_wall(wall, true, tiles * SpellEffectsConfig.get_config().fire_seconds_per_tile)


## Break every cracked wall within `radius` tiles of a blast. Returns how many.
func _break_walls_near(centre: Vector2i, radius: int) -> int:
	var count := 0
	for dz in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			var c := centre + Vector2i(dx, dz)
			if DungeonMap.is_destructible(c):
				_break_wall(c, player.cell, centre)
				count += 1
	return count


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


## A swing that hit no monster: if the tile in front is a cracked wall, a heavy weapon (the war
## hammer) breaks it; anything else just rings off it.
func _swing_at_wall(m: Member, hand: int, front: Vector2i) -> void:
	if not DungeonMap.is_destructible(front):
		return
	var weapon: Resource = equipped_weapon(m) if hand < 0 else _melee_weapon_in(m, hand)
	if weapon != null and weapon.breaks_walls:
		var dungeon := get_tree().get_first_node_in_group("dungeon")
		if dungeon != null and dungeon.break_wall(front):
			_say("%s smashes the cracked wall with the %s: it crumbles!" % [m.def.display_name, weapon.display_name])
			_cue("hit")
	else:
		_say("%s strikes the cracked wall. It shudders but holds: it needs something heavier." % m.def.display_name)


## Swing at the tile in front; hand -1 means "first weapon" (see effective_stats).
func _melee(m: Member, hand: int) -> void:
	_start_cooldown(m)
	_cue("swing")
	var front: Vector2i = player.cell + player.DIRS[player.facing]
	var target = DungeonMap.occupied.get(front)
	if target == null or not is_instance_valid(target) or target.dying:
		_swing_at_wall(m, hand, front)
		return
	var result := CombatRules.resolve_attack(effective_stats(m, hand), target.def)
	target.take_hit(result)
	if result.hit:
		_cue("hit")
	if not result.hit:
		_say("%s swings at the %s and misses." % [m.def.display_name, target.def.display_name], "miss")
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
			_cue("hero_die")
		else:
			_cue("hero_hurt")
		hp_changed.emit(m.slot)
		_say("The %s hits %s for %d." % [monster.def.display_name, m.def.display_name, result.damage])
	else:
		_cue("whiff")
		_say("The %s misses %s." % [monster.def.display_name, m.def.display_name], "miss")
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


## Play a spell's lighting through the spell_effects node (group "spell_effects"), if the scene
## has one: a bolt from the party to `at` for "missile", a glow around the party for the others.
func _fx(effect: String, at := Vector2i(-1, -1)) -> void:
	if effect == "":
		return
	if effect == "missile":
		get_tree().call_group("spell_effects", "missile", player.cell, at)
	elif effect == "fireball":
		get_tree().call_group("spell_effects", "fireball", player.cell, at)
	else:
		get_tree().call_group("spell_effects", "party_glow", effect)


## Play a sound through the audio node (group "audio"), if the scene has one.
func _cue(sound: String) -> void:
	get_tree().call_group("audio", "play", sound)


## Show a message on the HUD. tone "miss" styles it as a miss (see hud.gd).
func _say(text: String, tone := "") -> void:
	get_tree().call_group("hud", "show_message", text, false, tone)
