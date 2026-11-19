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

@export_group("Sconces")
@export var sconce_torch_seconds := 120.0  # A torch the level starts in a sconce burns this long once taken out (a stub; a held one has 240).
@export var sconce_see_range := 6          # A sconce counts as seen from a tile this near with a clear line (it shows on the map).

@export_group("Gas")
@export var gas_seconds := 5.5          # A cloud of toxic gas (a monster's death, gas_field.gd) lingers this long.
@export var gas_hero_dps := 1.0         # Each second the party stands in it, every living hero loses this much (never saved, no fire).
@export var gas_pixel := 0.016          # World size of one cloud art pixel: a cloud about 2 units wide, one tile.

@export_group("Oil")
@export var slick_seconds := 120.0      # An oil slick lasts this long or until fire touches it.
@export var burn_seconds := 6.0         # Burning oil: how long a tile burns...
@export var burn_monster_dps := 2.0     # ...what it does a second to a monster on it...
@export var burn_hero_dps := 1.0        # ...and to each hero when the party stands on it (half: the party is never hurt by its own fire at full rate).
@export var burn_light_energy := 1.2    # Burning oil is a light (sprite_lights): this bright...
@export var burn_light_range := 6.0     # ...and this far (units; 3 tiles).
@export var doused_seconds := 30.0      # A monster a flask was thrown at stays doused this long (tier table row "doused")...
@export var doused_fire_bonus := 6      # ...and the next fire that touches it does this much more...
@export var burning_dps := 2.0          # ...and sets it burning (status "burning", tier row)...
@export var burning_seconds := 3.0      # ...for this long.
@export var oiled_hits := 3             # Oil on a weapon: the next this many landed hits...
@export var oiled_bonus := 2            # ...do this much more, as fire.

@export_group("Curse zones")
@export var zone_sputter_seconds := 1.0  # A held flame sputters this long in a zone, then goes out.
@export var sconce_reach := 2           # A wall sconce this many tiles from a zone (a square round its tiles) is put out and will not light either.
@export var zone_pocket_radius := 1      # A Bless's pocket: the party's tile and the tiles within this many of it (Chebyshev).
@export var fog_alpha := 0.85            # The murky fog on the floor of a zone (art/spells/curse/fog_sheet): laid with normal blending, so it darkens as well as tints...
@export var fog_width := 3.6             # ...each patch this wide (world units; a tile is 2) and as deep as the art's shape says...
@export var fog_height := 0.06           # ...this far above the floor.
@export var fog_creep_seconds := 6.0     # A zone's fog creeps in from its edges over this long when it appears (and again when a Bless pocket ends).
@export var fog_recoil_seconds := 0.7    # A Bless's pocket pushes the fog back this fast...
@export var fog_return_seconds := 2.0    # ...and it comes back this slowly once the pocket is over.
@export var fog_push := 0.9              # Fog on the pocket's tiles also slides this far (world units) away from its centre as it recoils.
@export var fog_thicken := 0.35          # Fog round the party swells by this much while a held flame sputters.
@export var wisp_seconds := 2.4          # A flame that dies in the world leaves a wisp of fog curling up for this long.
@export var wisp_size := 1.6             # ...this big (world units tall).
@export var pocket_warn_seconds := 4.0   # In the last this many seconds of a Bless pocket the fog and the edge glow creep back as a warning.
@export_subgroup("Edge glow (the screen vignette)")
@export var vignette_enabled := true
@export var vignette_color := Color(0.525, 0.651, 0.447)  # Palette slime_300: the lit edge (a yellowish curse green)...
@export var vignette_dark := Color(0.149, 0.220, 0.173)   # ...palette moss_700: the murky outer edge.
@export var vignette_alpha := 0.7        # Strongest band's opacity (0..1).
@export var vignette_reach := 72.0       # How far in from the edge it creeps at full strength (view pixels).
@export var vignette_bands := 5          # Stepped bands, dithered, never a smooth ramp.
@export var vignette_min := 0.35         # Strength on first stepping into a zone (0..1)...
@export var vignette_full_seconds := 40.0  # ...growing to full over this long in the dark.
@export var vignette_in_seconds := 3.5   # It creeps in this slowly (strength 0 to 1)...
@export var vignette_pull_seconds := 0.9 # ...pulls back this fast when a Bless opens a pocket...
@export var vignette_out_seconds := 2.0  # ...and fades this fast on leaving the zone.
@export var vignette_warn := 0.5         # Strength it has crept back to by the end of a pocket.
@export var vignette_pulse := 0.1        # A slow, gentle swell of this much (none with Reduce flashing)...
@export var vignette_pulse_hz := 0.25    # ...this many times a second.
@export var haze_see_range := 7          # A message about a flame dying on the floor or in a sconce is only given within this many tiles, in sight.

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
