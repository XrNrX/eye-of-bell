extends RefCounted
## Combat maths in one place (see the combat design page). Preload it like DungeonMap:
##     const CombatRules := preload("res://scripts/combat_rules.gd")
## Attackers and targets are any objects with attack / defence / damage_min /
## damage_max fields: both CharacterDef and MonsterDef qualify.

const BASE_HIT := 60      # % chance to hit when attack equals defence.
const HIT_PER_POINT := 5  # % per point of attack above (or below) the target's defence.
const MIN_HIT := 10
const MAX_HIT := 95

static var _rng: RandomNumberGenerator


## The shared random generator. Call seed_rng() first for repeatable tests.
static func rng() -> RandomNumberGenerator:
	if _rng == null:
		_rng = RandomNumberGenerator.new()
		_rng.randomize()
	return _rng


static func seed_rng(value: int) -> void:
	rng().seed = value


## Chance to hit, in percent.
static func hit_chance(attack: int, defence: int) -> int:
	return clampi(BASE_HIT + HIT_PER_POINT * (attack - defence), MIN_HIT, MAX_HIT)


static func roll_damage(low: int, high: int) -> int:
	return rng().randi_range(low, maxi(low, high))


## Roll one attack. Returns {hit: bool, damage: int, chance: int}.
static func resolve_attack(attacker: Object, target: Object) -> Dictionary:
	var chance := hit_chance(attacker.attack, target.defence)
	var hit := rng().randi_range(1, 100) <= chance
	var damage := roll_damage(attacker.damage_min, attacker.damage_max) if hit else 0
	return {"hit": hit, "damage": damage, "chance": chance}


## Seconds between a hero's attacks: faster heroes swing more often.
static func hero_cooldown(speed: int) -> float:
	return maxf(0.8, 2.0 - 0.15 * speed)
