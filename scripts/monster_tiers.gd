extends Resource
## The monster tier table: data/tiers.tres. How likely each status effect is to land on a monster, and for how much of its
## time, by the monster's tier (MonsterDef.tier: 1 fodder, 2 tough, 3 elite or mini-boss, 4 boss). Every status source reads
## it through Monster.try_status (Hold Monster now; a bear trap, slowed or poisoned later), so a new effect needs only a new row.
## Rule of thumb: tier 1, a spell almost always works; tier 4, it is a gamble. Docs: docs/combat_design.md "Monster tiers".
##
## A row: rows[status id, or a source's own row such as "trap": Monster.try_status's `row`] = {"chance": [tier 1, 2, 3, 4] percent, "duration": [tier 1, 2, 3, 4] multiplier}.
## A monster can override one status for itself (MonsterDef.status_overrides). A status with no row always lands, in full.
## Read it with MonsterTiers.get_config() (a plain load: never preload the .tres into a const, that makes it read-only).

const PATH := "res://data/tiers.tres"
const TIERS := 4


static func get_config() -> Resource:
	return load(PATH)


@export var rows := {
	"held": {"chance": [90, 65, 35, 15], "duration": [1.0, 1.0, 0.5, 0.5]},
	"trap": {"chance": [95, 83, 68, 58], "duration": [1.0, 1.0, 0.5, 0.5]},  # A bear trap's hold: held's chance to resist, halved.
}


## What a status does to a monster of this definition: {"chance": percent, "duration": multiplier, "immune": bool,
## "message": a flavour line or ""}. Tier first, then the monster's own override; a wall monster is always immune.
func odds(status_id: String, def: Resource) -> Dictionary:  # status_id: a row name (a status id, or a source's row like "trap").
	var out := {"chance": 100, "duration": 1.0, "immune": false, "message": ""}
	var tier := clampi(int(def.get("tier")) if def.get("tier") != null else 1, 1, TIERS)
	if rows.has(status_id):
		var row: Dictionary = rows[status_id]
		var chances: Array = row.get("chance", [])
		var durations: Array = row.get("duration", [])
		if tier - 1 < chances.size():
			out.chance = int(chances[tier - 1])
		if tier - 1 < durations.size():
			out.duration = float(durations[tier - 1])
	var overrides = def.get("status_overrides")
	if overrides is Dictionary and overrides.has(status_id):
		var own: Dictionary = overrides[status_id]
		out.chance = int(own.get("chance", out.chance))
		out.duration = float(own.get("duration", out.duration))
		out.message = str(own.get("message", ""))
	if def.get("wall_monster") or out.chance <= 0:
		out.immune = true
	return out
