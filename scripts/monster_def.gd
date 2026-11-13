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
## How many tiles away (steps along the grid) it notices the player.
@export var sight_range := 4

@export_group("Movement and pacing")
## Seconds between its moves, on its own clock: a party move never resets or speeds it up. The party
## walks a tile in about 0.2 s, so a monster at 1.2 s falls behind a party that keeps moving.
## (The step itself animates in monster_ai.tres step_seconds.)
@export var step_interval := 1.2
## When the party steps out of its reach, it waits at least this long before following (only ever
## pushes its next move later, never earlier).
@export var reaction_delay := 0.5
## After it steps next to the party, it can't start its attack until this many seconds after the step
## animation ends; the wind-up below then runs on top of it.
@export var arrival_recovery := 0.5
## Fraction of attack_interval it waits before its first blow after coming within reach (the wind-up).
@export var wind_up := 0.5
## Seconds it must be held back (another monster already at the party, no way to the party) before it
## may try to get round to another side of the party. Only monster_ai.tres max_flankers do so at once.
@export var flank_after := 3.0

@export_group("Combat extras")
## 1 fodder, 2 tough, 3 elite or mini-boss, 4 boss. Decides how likely a status effect (Hold Monster, a trap...) is to land and for
## how much of its time: the tier table, data/tiers.tres (monster_tiers.gd). A wall monster is immune to them all.
@export_range(1, 4) var tier := 1
## Special cases, per status id, over the tier table: {"held": {"chance": 90, "duration": 0.75, "message": "The {monster} ..."}}.
## Any key may be left out. chance 0 = immune. message is added to the log line when the status lands ({monster}: its name).
@export var status_overrides := {}

## Percent of its landed hits that are crits (x1.5, and never enough to kill a hero at half HP or more).
@export var crit_chance := 0

## A boss, or a monster that is part of a wall (giant hand, tentacles): it gets the wide named bar
## across the top of the view, not a small bar over its sprite (enemy_bars.gd). Needs no other change.
@export var boss := false
@export var wall_monster := false

## What its landed blow leaves across the 3D view with the red flash (hit_overlay.gd): a sheet in art/spells/hit_fx/, e.g.
## "skeleton_claws". "" for none (the red flash alone).
@export var hit_effect := ""

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
## Which frame of attack_frames is the moment the blow lands (0 = the first): the fist at full reach, the axe coming down, the slam.
## The attack animation starts early enough that this frame appears just as the damage is dealt, so the swing, the red flash and
## the screen shake are one beat (monster.gd: _begin_swing). -1: the middle frame. Set it for every new or redone attack animation.
@export var attack_hit_frame := -1
@export var hurt_fps := 14.0
## World units per sprite pixel (48x64 frame at 0.028 is about 1.3 x 1.8 units).
@export var pixel_size := 0.028
