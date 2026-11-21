extends "res://scripts/item_behaviour.gd"
## The Azure Brand (data/items/azure_brand.tres), a legendary long sword burning with a cold blue flame (7g framework, step 11 hooks).
##
## Power: every landed blow burns for FIRE_MIN to FIRE_MAX more, counts as fire (a doused monster takes the +6 and catches light, a monster that
## fears fire recoils, exactly as from a torch) and sets any oil under its target alight.
## Price: a kill singes the wielder for SINGE HP (Party.hurt with can_kill false: it can take a hero to 1 HP and never to 0).

const CombatRules := preload("res://scripts/combat_rules.gd")

const FIRE_MIN := 2
const FIRE_MAX := 5
const SINGE := 1


func on_hit(party: Node, _m, _stack, target: Node, result: Dictionary) -> void:
	result.damage += CombatRules.rng().randi_range(FIRE_MIN, FIRE_MAX)
	result.fire = true     # Monster.take_hit: fire on a doused monster does +6 and sets it burning.
	result.recoil = true   # Party._melee: a monster that fears fire flinches from the flame, as from a torch.
	party.get_tree().call_group("oil", "ignite", target.cell)


func on_kill(party: Node, m, _stack, _target: Node) -> void:
	if party.hurt(m, SINGE, "fire", false) > 0:
		party.get_tree().call_group("hud", "show_message", "The blue flame singes %s." % m.short_name())
