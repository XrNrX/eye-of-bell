extends RefCounted
## Combat maths in one place (see the combat design page). Preload it like DungeonMap:
##     const CombatRules := preload("res://scripts/combat_rules.gd")
## Attackers and targets are any objects with attack / defence / damage_min /
## damage_max fields: both CharacterDef and MonsterDef qualify.

const BASE_HIT := 60      # % chance to hit when attack equals defence.
const HIT_PER_POINT := 5  # % per point of attack above (or below) the target's defence.
const MIN_HIT := 10
const MAX_HIT := 95
const CRIT_CAP := 40             # No hero's crit chance goes above this, whatever adds to it.
const CRIT_MULT := 2.0           # Weapons, thrown weapons and fists.
const SPELL_CRIT_MULT := 1.5     # Damage spells.
const MONSTER_CRIT_MULT := 1.5
const CRIT_MULT_CAP := 3.0       # Perks may raise a multiplier, never above this.
const FUMBLE_CHANCE := 8         # % of a party's missed weapon attacks that go badly wrong.
const SLIP_CHANCE := 0.5         # When a weapon could slip: the share of critical fails where it does.

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


## Roll one attack. Returns {hit: bool, damage: int, chance: int, crit: bool}. A crit is rolled only on a
## hit (crit_percent is a share of landed hits), so it never changes the hit chance.
static func resolve_attack(attacker: Object, target: Object, crit_percent := 0, crit_mult := CRIT_MULT) -> Dictionary:
	var chance := hit_chance(attacker.attack, target.defence)
	var hit := rng().randi_range(1, 100) <= chance
	var damage := roll_damage(attacker.damage_min, attacker.damage_max) if hit else 0
	var crit := hit and roll_crit(crit_percent)
	if crit:
		damage = crit_damage(damage, crit_mult)
	return {"hit": hit, "damage": damage, "chance": chance, "crit": crit}


## A hero's crit chance with this weapon (null for fists): class base + (Dexterity - 10) + the weapon's bonus + the
## hero's bonus with finesse weapons + anything a perk adds, in percent, kept within 0..CRIT_CAP.
static func crit_chance(hero: Object, weapon: Object = null, perk_points := 0) -> int:
	var chance: int = hero.crit_base + hero.dexterity - 10 + perk_points
	if weapon != null:
		chance += weapon.crit_bonus
		if weapon.finesse:
			chance += hero.finesse_crit
	return clampi(chance, 0, CRIT_CAP)


static func roll_crit(percent: int) -> bool:
	return percent > 0 and rng().randi_range(1, 100) <= percent


## Crit damage from a damage already rolled: rounded up, the multiplier kept to CRIT_MULT_CAP.
static func crit_damage(damage: int, mult: float) -> int:
	return ceili(damage * minf(mult, CRIT_MULT_CAP))


## A monster's crit can't kill a hero who was at half HP or more: it leaves them on 1.
static func cap_monster_crit(damage: int, hp: int, max_hp: int) -> int:
	return mini(damage, hp - 1) if hp * 2 >= max_hp else damage


## Does this missed attack go badly wrong?
static func roll_fumble() -> bool:
	return rng().randi_range(1, 100) <= FUMBLE_CHANCE


## Seconds between a hero's attacks: faster heroes swing more often.
static func hero_cooldown(speed: int) -> float:
	return maxf(0.8, 2.0 - 0.15 * speed)
