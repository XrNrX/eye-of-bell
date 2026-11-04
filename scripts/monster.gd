extends Node3D
## A monster: occupies one tile, blocks movement, shown as a billboard sprite.
## Its AI acts on a timer. If the player is within sight_range tiles with a clear
## line of sight it steps towards them, otherwise it wanders. Never diagonal.
## All stats and art come from a MonsterDef resource, so new monsters are data.

const DungeonMap := preload("res://scripts/dungeon_map.gd")

const AI_TICK := 0.8      # Seconds between actions at speed 1.0.
const STEP_TIME := 0.3    # Seconds a step takes to animate.
const WANDER_PAUSE := 0.3 # Chance a wandering monster just stands still this tick.

const DIRS: Array[Vector2i] = [
	Vector2i(0, -1), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(1, 0),
]

var def: Resource  # The MonsterDef.
var cell: Vector2i
var hp: int
var sprite: Sprite3D
var anim_time := 0.0


## Call before adding to the tree.
func setup(monster_def: Resource, start_cell: Vector2i) -> void:
	def = monster_def
	cell = start_cell
	hp = def.max_hp


func _ready() -> void:
	position = DungeonMap.cell_to_world(cell)
	DungeonMap.occupied[cell] = self

	sprite = Sprite3D.new()
	sprite.texture = def.sheet
	sprite.hframes = def.hframes
	sprite.pixel_size = def.pixel_size
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y  # Always faces the camera, stays upright.
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	# Stand on the floor: lift by half the frame height.
	sprite.position.y = (def.sheet.get_height() * def.pixel_size) / 2.0
	add_child(sprite)

	var timer := Timer.new()
	timer.wait_time = AI_TICK / def.speed
	add_child(timer)
	timer.timeout.connect(_on_tick)
	timer.start(randf_range(0.1, timer.wait_time))  # Stagger so monsters don't act in sync.


func _exit_tree() -> void:
	if DungeonMap.occupied.get(cell) == self:
		DungeonMap.occupied.erase(cell)


func _process(delta: float) -> void:
	anim_time += delta
	var frames: PackedInt32Array = def.idle_frames
	sprite.frame = frames[int(anim_time * def.idle_fps) % frames.size()]


## One AI step: chase if the player is close and visible, else wander.
func _on_tick() -> void:
	var to_player := DungeonMap.player_cell - cell
	var distance := absi(to_player.x) + absi(to_player.y)
	var dir := Vector2i.ZERO
	if distance <= def.sight_range and DungeonMap.has_line_of_sight(cell, DungeonMap.player_cell):
		dir = _chase_dir(to_player)
	else:
		dir = _wander_dir()
	if dir != Vector2i.ZERO:
		_step(dir)


## Step along the axis with the longer gap first; if that's blocked try the other.
func _chase_dir(to_player: Vector2i) -> Vector2i:
	var along_x := Vector2i(signi(to_player.x), 0)
	var along_y := Vector2i(0, signi(to_player.y))
	var options := [along_x, along_y] if absi(to_player.x) >= absi(to_player.y) else [along_y, along_x]
	for option in options:
		if option != Vector2i.ZERO and _can_enter(cell + option):
			return option
	return Vector2i.ZERO


## A random open neighbouring direction, or stand still sometimes.
func _wander_dir() -> Vector2i:
	if randf() < WANDER_PAUSE:
		return Vector2i.ZERO
	var dirs := DIRS.duplicate()
	dirs.shuffle()
	for dir in dirs:
		if _can_enter(cell + dir):
			return dir
	return Vector2i.ZERO


## Monsters stop at walls and closed doors, and at other monsters and the player.
func _can_enter(target: Vector2i) -> bool:
	return not DungeonMap.is_blocked(target) and not DungeonMap.is_occupied(target) \
			and target != DungeonMap.player_cell


## Claim the new tile at once (so nobody else can step in) and free the old
## tile when the move animation ends.
func _step(dir: Vector2i) -> void:
	var old := cell
	cell += dir
	DungeonMap.occupied[cell] = self
	var tween := create_tween()
	tween.tween_property(self, "position", DungeonMap.cell_to_world(cell), STEP_TIME)
	tween.tween_callback(func():
		if DungeonMap.occupied.get(old) == self:
			DungeonMap.occupied.erase(old)
		get_tree().call_group("dungeon", "refresh"))  # Doors re-check who's standing in them.
