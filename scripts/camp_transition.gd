extends CanvasLayer
## The Hearth Coal's trip to camp, seen (and the way back): slow dust motes and a few embers build up over the 3D view while it darkens in
## steps, then the scene changes, and on the other side the same dust is played backward, thinning away as the view brightens.
## Art: art/camp/dust_sheet.png (the VFX tool's 'Camp dust', tools/art/gen_camp.py: 208x130 frames shown at 2x over the 416x260 view). The
## darkening steps through a few flat black levels (never a smooth fade). A node of the tree ROOT, so it outlives the scene change.
##
## `CampTransition.play(tree, on_done)`: dust builds (about 2.3 s, the game paused), then `on_done` runs (the scene change: it returns false
## if the trip fell through, and the dust then clears at once); the layer waits for the new scene's player, then plays the dust back and
## frees itself. `CampTransition.skip` (tests) does the change at once, with no show. Reduce flashing changes nothing: it is slow steps.

const UiLayout := preload("res://scripts/ui_layout.gd")
const DIR := "res://art/camp/"
## How dark the view is at each step of the fade, lightest first (the last is fully black behind the thickest dust).
const DARK_STEPS := [0.0, 0.25, 0.5, 0.75, 0.92]
const DARK_FROM := 0.35   # The share of the dust's time after which the view starts to darken.
const MAX_WAIT := 6.0     # Give up waiting for the new scene after this long (seconds).

enum Phase { BUILD, WAIT, CLEAR }

static var skip := false   # Tests: no show, the change happens at once.

var phase := Phase.BUILD
var t := 0.0               # Seconds into the current phase.
var frames := 1
var frame_w := 208
var frame_h := 130
var fps := 10.0
var on_done := Callable()
var old_player: Node
var sheet: Texture2D
var picture: TextureRect
var atlas: AtlasTexture
var dim: ColorRect
var paused_by_us := false
var shown := -1


## Start the show over the running game. Returns the node (null when `skip` ran `on_done` at once or the art is missing).
static func play(tree: SceneTree, done: Callable) -> Node:
	var art := DIR + "dust_sheet.png"
	if skip or not ResourceLoader.exists(art):
		done.call()
		return null
	var layer = load("res://scripts/camp_transition.gd").new()
	layer.on_done = done
	layer.old_player = tree.get_first_node_in_group("player")
	tree.root.add_child(layer)
	return layer


func _ready() -> void:
	layer = 17   # Over the party panels, the frame and the pop-ups (16), under the full-screen map.
	process_mode = Node.PROCESS_MODE_ALWAYS
	sheet = load(DIR + "dust_sheet.png")
	var info = JSON.parse_string(FileAccess.get_file_as_string(DIR + "dust_sheet.json"))
	frames = int(info.frames)
	fps = float(info.fps)
	frame_w = int(info.frame_w)
	frame_h = int(info.frame_h)
	dim = ColorRect.new()
	dim.color = Color(0.043, 0.039, 0.063)   # ink, 0b0a10
	dim.position = UiLayout.VIEW.position
	dim.size = UiLayout.VIEW.size
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	atlas = AtlasTexture.new()
	atlas.atlas = sheet
	picture = TextureRect.new()
	picture.texture = atlas
	picture.position = UiLayout.VIEW.position
	picture.size = UiLayout.VIEW.size
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_SCALE
	picture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(picture)
	get_tree().paused = true   # The world holds still while the party goes (the end of the show gives it back).
	paused_by_us = true
	_show(0.0)


func _exit_tree() -> void:
	if paused_by_us and get_tree() != null:
		get_tree().paused = false


## Seconds the dust takes to build (or to clear): all its frames.
func duration() -> float:
	return frames / fps


func _process(delta: float) -> void:
	t += delta
	match phase:
		Phase.BUILD:
			_show(minf(1.0, t / duration()))
			if t >= duration():
				_arrive()
		Phase.WAIT:
			var player := get_tree().get_first_node_in_group("player")
			if (player != null and player != old_player and is_instance_valid(player) and t > 0.3) or t > MAX_WAIT:
				phase = Phase.CLEAR
				t = 0.0
				get_tree().paused = true   # (The change of level gave the pause back: hold the new scene still while the dust clears.)
				paused_by_us = true
		Phase.CLEAR:
			_show(maxf(0.0, 1.0 - t / duration()))
			if t >= duration():
				_finish()


## The dust is thick: do the trip. If it fell through the dust clears where it is.
func _arrive() -> void:
	phase = Phase.WAIT
	t = 0.0
	var went = on_done.call() if on_done.is_valid() else false
	if went == false:
		phase = Phase.CLEAR


func _finish() -> void:
	if paused_by_us:
		get_tree().paused = false
		paused_by_us = false
	queue_free()


## Draw the show at `progress` 0 (clear) to 1 (thickest): the dust frame and the stepped darkness.
func _show(progress: float) -> void:
	var f := clampi(int(progress * frames), 0, frames - 1)
	if f != shown:
		shown = f
		atlas.region = Rect2(f * frame_w, 0, frame_w, frame_h)
	var level := 0
	if progress >= 1.0:
		level = DARK_STEPS.size() - 1
	elif progress > DARK_FROM:
		level = int((progress - DARK_FROM) / (1.0 - DARK_FROM) * (DARK_STEPS.size() - 1))
	dim.color.a = DARK_STEPS[level]
