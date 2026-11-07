extends Resource
## A monster described as data. Make a new monster by saving a new .tres of this
## resource (see data/monsters/skeleton.tres) and listing it in DungeonMap.MONSTERS.

@export var display_name := "Monster"
@export var max_hp := 10
@export var attack := 2          # Accuracy: raises the chance to hit (see combat_rules.gd).
@export var defence := 1         # Lowers the heroes' chance to hit it.
@export var damage_min := 1
@export var damage_max := 4
@export var attack_interval := 2.0  # Seconds between attacks while next to the party.
## AI speed multiplier: the monster acts every (0.8 / speed) seconds.
@export var speed := 1.0
## How many tiles away (steps along the grid) it notices the player.
@export var sight_range := 4

## Percent of its landed hits that are crits (x1.5, and never enough to kill a hero at half HP or more).
@export var crit_chance := 0

@export_group("Drops")
## What it leaves on its tile when it dies, and how often (0..1): a skeleton guard may leave its rations.
@export var drop_item: Resource
@export var drop_chance := 0.0

@export_group("Sprite")
## Sprite sheet: one row of equally sized frames, side by side. Nothing in the code assumes how
## many: the frame count is `hframes`, and each animation is the list of frame numbers below,
## so art with more (or fewer) frames just needs these numbers changed (the importer,
## tools/art/import_pixellab.py, can do it from a layout file).
@export var sheet: Texture2D
@export var hframes := 1
@export var idle_frames := PackedInt32Array([0])    # Looped.
@export var attack_frames := PackedInt32Array()     # Played in order when it attacks.
## Played when it is hit. Exactly two frames means [hurt, hurt flash]: they alternate
## flash, hurt, flash, hurt. Any other count (1, or 3 and more) plays in order, once.
@export var hurt_frames := PackedInt32Array()
## Looped while it is stepping from tile to tile (about 0.3 s a step). Empty: it keeps its idle
## frames while it moves. The frames are extra frames at the end of the sheet (walk_0, walk_1, ...).
@export var walk_frames := PackedInt32Array()
@export var idle_fps := 2.0
@export var walk_fps := 13.0  # Four frames in one 0.3 s step: one stride per step.
@export var attack_fps := 8.0
@export var hurt_fps := 14.0
## World units per sprite pixel (48x64 frame at 0.028 is about 1.3 x 1.8 units).
@export var pixel_size := 0.028
