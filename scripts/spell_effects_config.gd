extends Resource
## Every tunable for the spell lighting, in one place: data/spell_effects.tres (open it in the
## Godot inspector, or edit the file). Colours, light strengths, speeds and durations of the
## Magic Missile bolt, the Heal / Bless / Shield glows, and the bloom and fog on the
## WorldEnvironment. Nothing here changes a rule: spells hit, heal and buff exactly as before.
##
## Scripts read it with `SpellEffectsConfig.get_config()` (a plain load, the same shared instance
## everywhere, so a change at runtime takes effect at once; do not `preload` the .tres into a
## const: Godot makes preloaded resources read-only). spell_effects.gd plays the effects.
##
## Colours above 1.0 are "HDR": they go brighter than white, which is what makes the glow bloom.
## Light colours are real light colours, not palette colours (the 3D view's lighting is not
## palette-bound); the bolt's own pixels are palette pixels tinted by `bolt_color`.

const PATH := "res://data/spell_effects.tres"


static func get_config() -> Resource:
	return load(PATH)


## Put the glow (bloom) and, if wanted, the volumetric fog on an Environment. Used by the game
## and the main menu. `fog_on` comes from the Options screen (settings.gd).
static func apply_environment(env: Environment, fog_on: bool) -> void:
	var c := get_config()
	if env == null or c == null:
		return
	env.glow_enabled = c.glow_enabled
	env.glow_intensity = c.glow_intensity
	env.glow_strength = c.glow_strength
	env.glow_bloom = c.glow_bloom
	env.glow_hdr_threshold = c.glow_hdr_threshold
	env.glow_hdr_scale = c.glow_hdr_scale
	env.glow_blend_mode = c.glow_blend_mode
	env.volumetric_fog_enabled = fog_on and c.fog_density > 0.0
	if env.volumetric_fog_enabled:
		env.volumetric_fog_density = c.fog_density
		env.volumetric_fog_albedo = c.fog_albedo
		env.volumetric_fog_emission = c.fog_emission
		env.volumetric_fog_emission_energy = c.fog_emission_energy
		env.volumetric_fog_length = c.fog_length
		env.volumetric_fog_anisotropy = c.fog_anisotropy
		env.volumetric_fog_ambient_inject = c.fog_ambient_inject


## The settings of one party glow ("heal", "bless" or "shield") as a Dictionary.
func glow(kind: String) -> Dictionary:
	return {
		"color": get(kind + "_color"),
		"light_energy": get(kind + "_light_energy"),
		"light_range": get(kind + "_light_range"),
		"pulse_seconds": get(kind + "_pulse_seconds"),
		"motes": get(kind + "_motes"),
		"mote_color": get(kind + "_mote_color"),
		"mote_rise": get(kind + "_mote_rise"),
		"mote_seconds": get(kind + "_mote_seconds"),
	}


@export_group("Magic Missile bolt")
@export var bolt_enabled := true
@export var bolt_color := Color(0.55, 0.8, 2.4)         # The sprite's tint (HDR: above 1 blooms).
@export var bolt_light_color := Color(0.45, 0.7, 1.0)   # The light blue the bolt throws on the walls.
@export var bolt_light_energy := 3.0
@export var bolt_light_range := 4.5
@export var bolt_size := 0.032                          # World units per bolt pixel (the bolt is 7x7 pixels).
@export var bolt_height := 0.95                         # How high above the floor it flies.
@export var bolt_seconds_per_tile := 0.045              # Speed: shorter is faster.
@export var bolt_trail_amount := 10                     # Little sparks it leaves behind (0 for none).
@export var bolt_trail_seconds := 0.25

@export_group("Missile impact")
@export var impact_flash_color := Color(0.7, 0.85, 1.0)
@export var impact_flash_energy := 7.0
@export var impact_flash_range := 4.0
@export var impact_flash_seconds := 0.2
@export var impact_sparks := 16                         # How many sparks burst out.
@export var impact_spark_color := Color(0.8, 1.4, 3.0)  # HDR.
@export var impact_spark_size := 0.05
@export var impact_spark_speed := 2.6
@export var impact_spark_seconds := 0.45

@export_group("Party glows (all three)")
@export var mote_size := 0.035       # World units per speck.
@export var mote_distance := 1.3     # How far ahead of the party the specks drift (they fill the view).
@export var mote_spread := 0.7       # Radius of the cloud they start in.

@export_group("Fireball projectile")
@export var fire_color := Color(3.0, 0.75, 0.1)          # The orb's tint: orange, HDR so it blooms.
@export var fire_light_color := Color(1.0, 0.5, 0.12)
@export var fire_light_energy := 4.0
@export var fire_light_range := 6.0
@export var fire_flicker := 0.35                         # How far the light flutters (fraction of its energy).
@export var fire_size := 0.06                            # World units per pixel (7x7): about twice the missile.
@export var fire_seconds_per_tile := 0.075               # Slower and heavier than the missile.
@export var ember_amount := 28                           # Embers it sheds on the way.
@export var ember_color := Color(2.6, 0.7, 0.1)
@export var ember_size := 0.04
@export var ember_seconds := 0.55
@export var ember_rise := 0.5                            # Embers drift upward at this speed.

@export_group("Fireball explosion")
@export var blast_light_color := Color(1.0, 0.55, 0.15)
@export var blast_light_energy := 14.0                   # A big flash that lights the whole area...
@export var blast_light_range := 18.0
@export var blast_seconds := 0.5                         # ...and fades over about half a second.
@export var blast_orb_color := Color(3.0, 0.8, 0.1)
@export var blast_orb_scale := 5.5                       # The fireball swells to this many times the projectile.
@export var blast_sparks := 40
@export var blast_spark_color := Color(3.0, 0.9, 0.15)
@export var blast_spark_size := 0.06
@export var blast_spark_speed := 4.0
@export var blast_spark_seconds := 0.7
@export var blast_shake_strength := 0.12                 # Screen shake (camera offset, world units; a heavy hit is 0.05).
@export var blast_shake_seconds := 0.45

@export_group("Heal glow")
@export var heal_color := Color(1.0, 0.85, 0.45)        # The light's colour.
@export var heal_light_energy := 2.4
@export var heal_light_range := 5.0
@export var heal_pulse_seconds := 0.7                   # Rise and fall of the light.
@export var heal_motes := 18                            # Soft specks drifting up around the party.
@export var heal_mote_color := Color(2.0, 1.45, 0.5)     # HDR.
@export var heal_mote_rise := 0.8
@export var heal_mote_seconds := 1.1

@export_group("Bless glow")
@export var bless_color := Color(1.0, 0.95, 0.75)
@export var bless_light_energy := 2.6
@export var bless_light_range := 5.5
@export var bless_pulse_seconds := 0.8
@export var bless_motes := 22
@export var bless_mote_color := Color(2.1, 1.6, 0.6)
@export var bless_mote_rise := 0.9
@export var bless_mote_seconds := 1.2

@export_group("Shield glow")
@export var shield_color := Color(0.6, 0.8, 1.0)
@export var shield_light_energy := 2.2
@export var shield_light_range := 5.0
@export var shield_pulse_seconds := 0.6
@export var shield_motes := 14
@export var shield_mote_color := Color(1.0, 1.6, 2.6)
@export var shield_mote_rise := 0.6
@export var shield_mote_seconds := 0.9

@export_group("Holy light (the cleric's symbol)")
## Heal and Bless cast from a holy symbol: a gold light swells outward from the party, lighting the
## corridor walls (the one pure warm light in a cursed land), and nearby green curse glows dim while it lasts.
@export var holy_color := Color(1.0, 0.8, 0.38)
@export var holy_light_energy := 2.0
@export var holy_start_range := 1.5                # The light starts this wide...
@export var holy_light_range := 8.0                # ...and swells to this, so the pulse seems to travel outward.
@export var holy_seconds := 1.0                    # How long the pulse lasts (rises for 40%, fades for 60%).
@export var holy_curse_dim := 0.65                 # How much the green curse glows dim (0 none, 1 out completely).
@export var holy_curse_dim_in := 0.25
@export var holy_curse_dim_hold := 0.6
@export var holy_curse_dim_out := 0.9
@export var holy_reduced_scale := 0.45             # "Reduce flashing": the light's strength is multiplied by this and it never swells.

@export_group("Holy symbol on the party panel")
## The glowing symbol in the cleric's hand slot (art/items/holy_symbol_glow.png, three frames).
@export var holy_hud_seconds := 1.2                # How long it pulses (the length of the cast)...
@export var holy_hud_pulses := 3                   # ...in this many pulses...
@export var holy_hud_fade := 1.0                   # ...then fades out over this.
@export var holy_hud_motes := 7                    # Light motes rising off the symbol (0 for none).
@export var holy_hud_mote_color := Color(0.96, 0.81, 0.5)
@export var holy_hud_mote_rise := 16.0             # Pixels per second.
@export var holy_hud_mote_seconds := 1.0

@export_group("Glow (bloom)")
## Only pixels brighter than glow_hdr_threshold bloom, so the torches' own light stays put while
## the HDR bolt and sparks pop. Lower the threshold (or raise intensity) for more bloom everywhere.
@export var glow_enabled := true
@export var glow_intensity := 0.7
@export var glow_strength := 1.0
@export var glow_bloom := 0.0
@export var glow_hdr_threshold := 1.4
@export var glow_hdr_scale := 2.0
@export_enum("Additive", "Screen", "Softlight", "Replace", "Mix") var glow_blend_mode := 1

@export_group("Volumetric fog")
## Subtle haze that catches the torchlight. Switched on and off in Options. A density of 0 turns it off.
@export var fog_density := 0.018
@export var fog_albedo := Color(0.62, 0.55, 0.5)
@export var fog_emission := Color(0.0, 0.0, 0.0)
@export var fog_emission_energy := 0.0
@export var fog_length := 14.0
@export var fog_anisotropy := 0.35
@export var fog_ambient_inject := 0.0
