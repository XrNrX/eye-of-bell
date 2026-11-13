extends Resource
## Movement rules every monster shares: data/monster_ai.tres. Each monster's own pacing (step interval,
## reaction delay, arrival recovery, wind-up, flank delay) is on its MonsterDef; this holds the rest.
## Read it with MonsterAiConfig.get_config() (a plain load, the same shared instance everywhere, so test
## and debug edits take effect at once). Never preload the .tres into a const: that makes it read-only.
##
## The rules (monster.gd, "Movement AI"; reasons in docs/combat_design.md):
## - A monster moves on its own clock only (MonsterDef.step_interval).
## - Only one monster may stand next to the party unless more hold a flank pass. A monster that is
##   held back queues behind the one at the party. After MonsterDef.flank_after seconds held back it
##   may take a pass (at most max_flankers at once) and go to any free side of the party.
## - The party moving next to a monster is the party's doing: any monster next to the party attacks.

const PATH := "res://data/monster_ai.tres"


static func get_config() -> Resource:
	return load(PATH)


## How many monsters may be trying to get round the party at the same time.
@export var max_flankers := 1
## Seconds a step from tile to tile takes to animate (monster walk cycles are drawn for 0.3).
@export var step_seconds := 0.3
## Chance a wandering monster (one that hasn't seen the party) stands still on a move.
@export var wander_pause := 0.3
## How far (in steps) a chasing monster searches for a way to the party or the end of the queue.
@export var path_radius := 12
