extends Resource
## Every tunable for the combat "feel" effects, in one place: data/combat_feel.tres
## (open it in the Godot inspector, or edit the file). Each effect has an `enabled`
## switch and its own numbers. None of them change a combat rule: damage, hit chances
## and cooldown timings are untouched; these only add feedback around the same events.
##
## Scripts read it with `var feel_cfg: Resource = FeelConfigScript.get_config()` (where
## FeelConfigScript is a preload of this file). It is a plain load(), the same shared
## instance everywhere, so changing a field at runtime (a test, the remote inspector)
## takes effect at once. Don't `preload` the .tres into a const: Godot makes a
## preloaded constant resource read-only, and that would silently block those edits.

const PATH := "res://data/combat_feel.tres"


static func get_config() -> Resource:
	return load(PATH)


@export_group("Hit pause")
## A heavy blow freezes the game for a split second (Engine.time_scale, restored by a
## timer that ignores the slowdown).
@export var hit_pause_enabled := true
@export var hit_pause_monster_damage := 6   # A hero's hit on a monster this big or bigger...
@export var hit_pause_on_kill := true       # ...or any killing blow (this switch controls that part).
@export var hit_pause_party_damage := 5     # A monster's hit on the party this big or bigger.
@export var hit_pause_seconds := 0.07       # Real time the pause lasts.
@export var hit_pause_time_scale := 0.05    # Game speed during it (0 would stop timers dead).

@export_group("Screen shake")
## The 3D view shakes when the party takes a big hit. Strength grows with the damage.
@export var screen_shake_enabled := true
@export var screen_shake_min_damage := 4     # Smaller hits don't shake.
@export var screen_shake_full_damage := 8    # This much damage (or more) shakes at full strength.
@export var screen_shake_strength := 0.05    # Camera offset at full strength (world units).
@export var screen_shake_seconds := 0.3

@export_group("Monster telegraph")
## A monster rears back and flashes just before each attack. The attack still lands at
## exactly the same moment; the warning fills the last stretch of its cooldown.
@export var telegraph_enabled := true
@export var telegraph_seconds := 0.45        # How long before the blow it starts.
@export var telegraph_rear_back := 0.18      # How far it leans away and stretches (fraction of its height).
@export var telegraph_flash_colour := Color(1.0, 0.62, 0.35)  # Close to palette rust_300.
@export var telegraph_flashes := 3
@export var telegraph_lunge := true          # Snap forward as the blow lands.

@export_group("Miss messages")
## Misses (by heroes, monsters and thrown weapons) get their own look on the message line.
@export var miss_message_enabled := true
@export var miss_prefix := "Miss! "
@export var miss_colour := Color(0.588, 0.557, 0.604)  # Palette stone_300: muted, a whiff.

@export_group("Portrait shake")
## The portrait of the hero who was hit shakes sideways.
@export var portrait_shake_enabled := true
@export var portrait_shake_min_damage := 1
@export var portrait_shake_pixels := 2.0     # Amplitude at the smallest hit; grows a little with damage.
@export var portrait_shake_seconds := 0.3
