extends Resource
## Light and darkness: data/light.tres. Every number for the dark and for the party's light that is not on a light's own ItemDef
## (the "Light" group: energy, range, colour, burn time, fire damage). Rules: docs/combat_design.md "Light and darkness".
## Read it with LightConfig.get_config() (a plain load, the same shared instance everywhere, so test and debug edits take effect at
## once). Never preload the .tres into a const: that makes it read-only.
##
## - The dark: the dungeon has a faint cold ambient ("eyes adjusted"), enough to make out the nearest walls and a silhouette.
##   Everything else is the wall torches and whatever light the party holds. Monsters and floor items are tinted by the light that
##   reaches them (sprite_lighting.gd), never below sprite_min_light.
## - The party's light (party_light.gd, the Player's "Torch" node) is the brightest light held in a living hero's hand, made a
##   little brighter for each extra one, never by more than extra_light_cap.
## - A light near its end flickers hard for its last gutter_seconds, then goes out.

const PATH := "res://data/light.tres"

@export_group("The dark")
@export var ambient_color := Color(0.17, 0.18, 0.25)  # Cold and faint: "b_dim", agreed 14 Nov 2026 from before-and-after shots.
@export var ambient_energy := 1.0

@export_group("The party's light")
@export var extra_light_bonus := 0.1   # Each extra light held adds this share of the brightest one's energy...
@export var extra_light_cap := 0.2     # ...up to this much in all: two torches are not twice as bright.
@export var light_height := 1.4        # Above the floor, at the party (as the old always-on light).
@export var flicker := 0.15            # Share of the energy a burning light's flicker adds or takes away.
@export var gutter_seconds := 15.0     # A light with this little time left flickers hard...
@export var gutter_flicker := 0.5      # ...by this share, and its hand bar blinks.

@export_group("Sprites in the dark")
## Monsters and floor items are tinted by the light that reaches them (sprite_lighting.gd), never darker than this cold floor.
@export var sprite_min_light := 0.35   # In the dark: a dim silhouette that still reads (the art style's readability rule).
@export var sprite_light_gain := 1.0   # How strongly the lights brighten them (1: a torch two tiles away lights them fully).

@export_group("Fire")
@export var recoil_delay := 1.0        # A monster that fears fire, struck by a torch: its next blow comes this much later...
@export var recoil_steps_back := true  # ...and it backs off a tile, if the tile behind it is free.

@export_group("On the floor")
@export var floor_light_height := 0.35 # A burning light lying on a tile shines from just above it.
@export var floor_light_scale := 0.7   # ...at this share of its energy (it lies on its side).


static func get_config() -> Resource:
	return load(PATH)


## Put the dark on the game's Environment: the faint ambient. Called with the glow and fog (spell_effects.gd).
static func apply_ambient(env: Environment) -> void:
	var c := get_config()
	if env == null or c == null:
		return
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = c.ambient_color
	env.ambient_light_energy = c.ambient_energy
