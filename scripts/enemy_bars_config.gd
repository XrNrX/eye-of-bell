extends Resource
## Every size, colour and timing of the enemy health bars, in one place: data/enemy_bars.tres
## (see enemy_bars.gd). All colours are palette colours (docs/art_style.md). Read it with
## `EnemyBarsConfig.get_config()`: a plain load, never a preloaded const (that would be read-only).

const PATH := "res://data/enemy_bars.tres"


static func get_config() -> Resource:
	return load(PATH)


@export_group("Bar over the monster")
@export var bar_width := 26             # Outer size in view pixels, frame included.
@export var bar_height := 5
@export var max_distance := 6           # Tiles; farther monsters show no bar.
@export var hold_seconds := 3.0         # After the last hit the bar stays this long (unless it is the one in front)...
@export var fade_seconds := 1.0         # ...then dissolves away in `fade_steps` palette-pure steps.
@export var fade_steps := 3

@export_group("Name strip (the monster in front)")
@export var strip_enabled := true
@export var strip_height := 14
@export var strip_bar_width := 56
@export var strip_top := 3              # Gap above the strip, view pixels.

@export_group("Boss and wall-monster bar")
@export var boss_width := 280
@export var boss_height := 9
@export var boss_top := 4
@export var boss_range := 10            # Tiles; the boss bar shows while it can see the party within this many.

@export_group("Damage chunk")
@export var flash_seconds := 0.12       # The lost chunk is light this long...
@export var drain_seconds := 0.5        # ...then drains away over this long.
@export var crit_shake_pixels := 1      # A crit's drain shakes the bar by up to this many pixels.

@export_group("Colours (palette)")
@export var frame := Color("7c4426")        # rust_500: thin rusted iron.
@export var frame_lit := Color("a8673a")    # rust_300: the lit top edge.
@export var background := Color("0b0a10")   # ink.
@export var fill := Color("7a2224")         # blood_500.
@export var fill_shade := Color("4a1418")   # blood_700: the fill's lower row.
@export var chunk_flash := Color("c9c0a4")  # bone_300: the "white" flash.
@export var chunk_drain := Color("a8673a")  # rust_300.
@export var boss_trim := Color("7fb88a")    # curse_500.
@export var boss_trim_dark := Color("3a6b4c")  # curse_700.
@export var text := Color("c9c0a4")         # bone_300.
@export var text_shadow := Color("0b0a10")
