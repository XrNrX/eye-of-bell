extends Resource
## The dungeon editor's numbers (scripts/debug/editor_config.tres; the editor is dungeon_editor.gd). Read with
## EditorConfig.get_config() (a plain load, one shared instance). Debug builds only: the whole scripts/debug folder is left out of a
## release export.

## A new dungeon on the squared paper: this many squares across and down (the New button asks, starting from these).
@export var new_width := 32
@export var new_height := 32
@export var min_size := 8      # The smallest and largest a dungeon may be, in squares.
@export var max_size := 128
## How big a square is on screen, in pixels, at each zoom step (the wheel moves between them). Multiples of 4, so the cross-hatching
## of neighbouring walls joins up.
@export var cell_sizes := PackedInt32Array([8, 12, 16, 20, 24, 32])
@export var start_zoom := 2    # Index into cell_sizes the editor opens at (16 px).
@export var undo_steps := 100  # How many strokes Ctrl+Z can take back (the brief asks for at least 50).
@export var pan_speed := 240.0 # WASD panning, in screen pixels a second.


static func get_config() -> Resource:
	return load("res://scripts/debug/editor_config.tres")
