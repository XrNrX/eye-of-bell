extends Resource
## Every tunable for the ancient wall look, in one place: data/wall_decor.tres (open it in the Godot inspector, or edit the
## file). Read it with `WallDecorConfig.get_config()` (a plain load; never `preload` the .tres into a const: Godot makes a
## preloaded resource read-only, so edits at runtime would silently do nothing).
##
## `enabled` off draws the old plain brick walls, which is how the before-and-after screenshots are taken.

const PATH := "res://data/wall_decor.tres"


static func get_config() -> Resource:
	return load(PATH)


@export_group("Normal maps")
## art/normals/ (tools/art/gen_normal_maps.py) makes light rake across the stone. normal_scale multiplies the slopes baked into the
## pictures: 0 flat, 1 as made, above 1 craggier. Re-run the generator (--blur, --strength) to change how they are derived.
@export var normal_enabled := true
@export var normal_strength := 1.5          # Walls, floor, ceiling, doors.
@export var normal_decal_strength := 0.9    # Cracks, stains, blood, roots and the rest laid on the walls.

@export_group("Wall stone")
@export var enabled := true
## One of these is picked for each wall face, from a seed made of the tile position and which side it is: random but the
## same every run.
@export var wall_textures: PackedStringArray = [
	"res://art/tiles/wall_stone_1.png", "res://art/tiles/wall_stone_2.png",
	"res://art/tiles/wall_stone_3.png", "res://art/tiles/wall_stone_4.png",
]
@export var seed := 7

@export_group("Decals")
## Small transparent pictures stuck on wall faces (one art pixel is one wall-texture pixel). Most faces get none.
## A kind listed twice is twice as likely. Where each sits on the face follows its file name (wall_decor.gd, PLACEMENT).
@export var decal_textures: PackedStringArray = [
	"res://art/decals/crack.png", "res://art/decals/crack.png", "res://art/decals/stain.png", "res://art/decals/stain.png",
	"res://art/decals/roots.png", "res://art/decals/blood.png", "res://art/decals/tally.png",
	"res://art/decals/web_l.png", "res://art/decals/web_r.png",
]
@export var decal_chance_one := 0.42     # Chance a face gets at least one decal...
@export var decal_chance_two := 0.12     # ...and chance it gets two (this share of all faces; the rest get one).
@export var decal_margin := 0.12         # Keep decals this far (world units) from the edge of a face.
@export var decal_offset := 0.012        # How far in front of the wall they sit.

@export_group("Curse veins")
## Faint sickly green veins that glow and pulse slowly on roughly this share of wall faces.
@export var vein_chance := 0.1
@export var vein_textures: PackedStringArray = [
	"res://art/decals/vein_1.png", "res://art/decals/vein_2.png", "res://art/decals/vein_3.png",
]
@export var vein_energy_low := 0.15
@export var vein_energy_high := 0.55
@export var vein_pulse_seconds := 5.0

@export_group("Structures")
## Stone pillars and arches in long straight corridors, and alcoves. DungeonMap.STRUCTURES adds hand-placed ones.
@export var structures_enabled := true
@export var arch_min_run := 6            # A corridor must be at least this many tiles long to get arches...
@export var arch_spacing := 4            # ...one every this many tiles...
@export var arch_offset := 2             # ...starting this many tiles in from the end of the run.
@export var pillar_width := 0.55
@export var pillar_depth := 0.35
@export var arch_depth := 0.45
@export var lintel_height := 0.4
@export var alcove_chance := 0.025       # Share of wall faces that are an alcove with a skull and a candle stub.
@export var alcove_texture := "res://art/decals/niche.png"
@export var alcove_light_energy := 0.5
@export var alcove_light_range := 3.0

@export_group("Grime")
## A dithered dark gradient: heavy towards the floor, light towards the ceiling.
@export var grime_enabled := true
@export var grime_texture := "res://art/decals/grime.png"
@export var grime_offset := 0.006
