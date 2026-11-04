extends Resource
## A monster described as data. Make a new monster by saving a new .tres of this
## resource (see data/monsters/skeleton.tres) and listing it in DungeonMap.MONSTERS.

@export var display_name := "Monster"
@export var max_hp := 10
@export var damage := 2  # Not used yet; here for when combat arrives.
## AI speed multiplier: the monster acts every (0.8 / speed) seconds.
@export var speed := 1.0
## How many tiles away (steps along the grid) it notices the player.
@export var sight_range := 4

@export_group("Sprite")
## Sprite sheet: one row of equally sized frames, side by side.
@export var sheet: Texture2D
@export var hframes := 1
@export var idle_frames := PackedInt32Array([0])
@export var attack_frames := PackedInt32Array()  # Not used yet.
@export var hurt_frames := PackedInt32Array()    # Not used yet.
@export var idle_fps := 2.0
## World units per sprite pixel (48x64 frame at 0.028 is about 1.3 x 1.8 units).
@export var pixel_size := 0.028
