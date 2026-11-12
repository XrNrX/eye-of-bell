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

@export_group("Miss messages")
## Misses (by heroes, monsters and thrown weapons) get their own look on the message line.
@export var miss_message_enabled := true
@export var miss_prefix := "Miss! "
@export var miss_colour := Color(0.482, 0.478, 0.533)  # Palette stone_300: muted, a whiff.

@export_group("Critical hits")
## What a party crit adds. Reduce flashing (Settings) removes the shake and softens the portrait flash.
@export var crit_text_enabled := true
@export var crit_number_size := 128          # Font size of the number (a normal one is 64).
@export var crit_text_size := 48             # "CRITICAL!" above it.
@export var crit_colour := Color(1.7, 1.4, 0.85)  # Palette torch_300 pushed above 1, so it blooms: brighter than a normal number.
@export var crit_pause_enabled := true
@export var crit_pause_seconds := 0.1
@export var crit_kill_pause_seconds := 0.16
@export var crit_shake_enabled := true
@export var crit_shake_strength := 0.04
@export var crit_shake_seconds := 0.25
@export var crit_kill_shake_strength := 0.07
@export var crit_kill_shake_seconds := 0.35
@export var crit_hold_enabled := true
@export var crit_hurt_hold_frames := 3       # Extra frames the hurt frame is held (at the monster's hurt_fps).
@export var crit_death_enabled := true       # A crit that kills: the monster swells, hangs, then goes down.
@export var crit_death_swell := 1.12
@export var crit_death_hold := 0.4
@export var crit_log_colour := Color(0.961, 0.812, 0.502)  # Palette torch_300.

@export_group("Monster crits")
## A monster's crit: a red flash on the portrait of the hero it hit.
@export var portrait_crit_flash_enabled := true
@export var portrait_crit_flash_colour := Color(1.9, 0.4, 0.38)     # Above 1: it glows, not only tints.
@export var portrait_crit_flash_reduced := Color(0.95, 0.5, 0.48)   # With Reduce flashing: one steady, dimmer tint.
@export var portrait_crit_flash_seconds := 0.5
@export var portrait_crit_flash_pulses := 2
@export var crit_taken_log_colour := Color(0.659, 0.404, 0.227)     # Palette rust_300 (blood_500 is too dark to read on the log).

@export_group("Critical fails")
@export var fail_text_enabled := true
@export var fail_text_size := 40
@export var fail_colour := Color(0.498, 0.722, 0.541)  # Palette curse_500: sickly.

@export_group("Banter")
@export var banter_log_colour := Color(0.788, 0.753, 0.643)  # Palette bone_300.

@export_group("Portrait shake")
## The portrait of the hero who was hit shakes sideways.
@export var portrait_shake_enabled := true
@export var portrait_shake_min_damage := 1
@export var portrait_shake_pixels := 2.0     # Amplitude at the smallest hit; grows a little with damage.
@export var portrait_shake_seconds := 0.3
