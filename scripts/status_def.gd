extends Resource
## A timed status a monster can carry (data/statuses/*.tres): held now; slowed, poisoned and the like are new .tres files
## with these fields, not new code. Put on with Monster.add_status(def, seconds, source); monster.gd reads every field.
## Rules and reasons: docs/combat_design.md ("Status effects").

@export var id := "status"           # The key: Monster.has_status("held"), saved with the monster, sent with the signals.
@export var display_name := "Status"

@export_group("Resisting it")
## How likely it lands and for how long is NOT here: it is the tier table's row for this id (data/tiers.tres, monster_tiers.gd),
## by the monster's tier, with MonsterDef.status_overrides for special cases. Log lines (narrator voice; {monster}: its name, lower case).
@export var resist_message := "The {monster} shrugs it off."
@export var immune_message := "The {monster} is not affected."

@export_group("News")
## GameEvents signals sent when it starts (arguments: monster, source hero_index) and when it ends by itself (argument: monster).
## "" = none. Not sent when it ends because the monster died, nor while a save loads.
@export var started_event := ""
@export var ended_event := ""

@export_group("What it stops")
@export var stops_moving := false    # No steps at all (and the move clock pauses while it lasts).
@export var stops_attacking := false # No blows, no wind-up, no swing (and the attack clock pauses).
@export var freezes_animation := false  # The sprite holds the frame it was showing.

@export_group("Slower or faster")
## Multiplies the time between its moves and the speed its attack clock runs down: 2.0 is half speed (slowed). Several statuses
## multiply together. Ignored while a status stops that action.
@export var move_time_scale := 1.0
@export var attack_time_scale := 1.0

@export_group("Damage over time")
## HP lost per second while it lasts (poisoned, burning), in whole points as they add up; a killing tick kills. The hero who put
## the status on is named as the killer.
@export var damage_per_second := 0.0

@export_group("Helpless")
## Blows on it get each hero's CharacterDef.helpless_crit added to their crit chance (a stab in the back).
@export var helpless := false

@export_group("Look")
## A faint colour laid over the sprite while it lasts (multiplied in; 1,1,1 = none). With several, the last one put on shows.
@export var tint := Color(1, 1, 1)
## A small icon drawn beside the monster's health bar (enemy_bars.gd), or none.
@export var icon: Texture2D
## Flipbooks (art/spells/<fx_spell>/<name>_sheet.png) played on the monster: once as it starts, looped while it lasts, once as it ends.
## Empty: none. Tinted with fx_tint (HDR: above 1 blooms) and lit by a light of fx_light_colour.
@export var fx_spell := ""
@export var fx_start := ""
@export var fx_loop := ""
@export var fx_end := ""
@export var fx_tint := Color(1, 1, 1)
@export var fx_light_colour := Color(1, 1, 1)
@export var fx_light_energy := 0.0
@export var fx_light_range := 2.5
