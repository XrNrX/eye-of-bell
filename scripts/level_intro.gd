extends CanvasLayer
## A short intro card when a level is started fresh from the main menu (the DEMO LEVEL button sets `pending_for`; game_view.gd starts the card
## when the scene it loads is that level, and a loaded save or a change of level never sets it): the last picture of the intro film (the party
## inside the ruin, looking out at the rain) fades in, then a title and a few narrator lines appear one after another, then it fades away into
## the level. Any key or click skips it (Alt+Enter, a modifier alone and a key repeat do not). The game is held still while it shows.
##
## INTROS is the whole text as data, keyed by level id. The voice is the narrator's (docs/tone.md section 8): plain, present tense, second person,
## nothing funny, nothing about the story's secrets, 70 characters a line at most. Everything fades in hard steps (never a smooth fade).

const DungeonMap := preload("res://scripts/dungeon_map.gd")

const INTROS := {
	"res://levels/demo_1.gd": {
		"art": "res://art/intro/shot_14_looking_out.png",
		"title": "DEMO LEVEL 1",
		"lines": [
			"Four of you came in out of the rain.",
			"The rain stays at the archway. The dark does not.",
			"Something below is dripping, slow and patient.",
		],
		"goal": "Find the stairs down.",
	},
}

const FADE_IN := 0.8          # Seconds for the picture to come up from black.
const TITLE_AT := 1.0
const FIRST_LINE_AT := 2.4
const LINE_GAP := 2.0         # Seconds between one line appearing and the next.
const GOAL_GAP := 2.4         # Then the last line, in gold.
const HOLD := 2.4             # Everything shown, before the fade out.
const FADE_OUT := 0.8
const STEPS := 4.0            # Hard steps in every fade.
const PICTURE_DIM := 0.62     # The picture is dimmed so the text reads.
const TEXT := Color("c9c0a4")      # bone_300
const GOLD := Color("d99a36")      # torch_500
const INK := Color("0b0a10")

## The level id whose intro is waiting to be shown (set by the menu's DEMO LEVEL button), or "".
static var pending_for := ""
## Tests: skip the show.
static var disabled := false

var data: Dictionary
var t := 0.0
var leaving := false
var leave_t := 0.0
var finished := false
var paused_by_us := false
var cover: ColorRect      # Black behind the picture, so the card starts from black and not from the level.
var picture: TextureRect
var band: ColorRect
var title: Label
var lines: Array = []   # Labels: the narrator lines, then the goal.
var times: Array = []   # When each of them appears.


## Is there an intro for this level, waiting to be shown? (Consumes the waiting flag.)
static func take(level_id: String) -> bool:
	var due := pending_for != "" and pending_for == level_id and INTROS.has(level_id) and not disabled
	pending_for = ""
	return due


func _ready() -> void:
	layer = 25   # Over everything the game draws, under nothing.
	add_to_group("level_intro")
	process_mode = Node.PROCESS_MODE_ALWAYS
	data = INTROS[DungeonMap.level_id]
	cover = ColorRect.new()
	cover.color = INK
	cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cover.mouse_filter = Control.MOUSE_FILTER_STOP   # Nothing under the card takes a click meanwhile.
	add_child(cover)
	picture = TextureRect.new()
	picture.texture = load(data.art)
	picture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_SCALE
	picture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(picture)
	band = ColorRect.new()   # A dark band behind the text.
	band.color = Color(INK, 0.6)
	band.position = Vector2(0, 76)
	band.size = Vector2(640, 168)
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(band)
	title = _label(data.title, 16, TEXT, 90)
	var y := 140.0
	var at := FIRST_LINE_AT
	for text in data.lines:
		lines.append(_label(text, 8, TEXT, y))
		times.append(at)
		y += 22.0
		at += LINE_GAP
	lines.append(_label(data.goal, 8, GOLD, y + 6.0))
	times.append(at - LINE_GAP + GOAL_GAP)
	get_tree().paused = true
	paused_by_us = true
	_draw()


func _label(text: String, size: int, colour: Color, y: float) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", colour)
	l.add_theme_color_override("font_shadow_color", INK)
	l.add_theme_constant_override("shadow_offset_x", 1)
	l.add_theme_constant_override("shadow_offset_y", 1)
	l.position = Vector2(0, y)
	l.size = Vector2(640, size + 4)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l


func _exit_tree() -> void:
	if paused_by_us and get_tree() != null:
		get_tree().paused = false


## When the last line has appeared and been held: the card starts to leave.
func end_time() -> float:
	return times.back() + HOLD


func _process(delta: float) -> void:
	if finished:
		return
	if leaving:
		leave_t += delta
		if leave_t >= FADE_OUT:
			_finish()
			return
	else:
		t += delta
		if t >= end_time():
			leave()
	_draw()


## Start fading out (a key, a click, or the end of the text).
func leave() -> void:
	if leaving:
		return
	leaving = true
	leave_t = 0.0


func _finish() -> void:
	finished = true
	if paused_by_us:
		get_tree().paused = false
		paused_by_us = false
	queue_free()


## A fade value 0..1 in hard steps.
static func stepped(progress: float) -> float:
	return floorf(clampf(progress, 0.0, 1.0) * STEPS) / STEPS


func _draw() -> void:
	var out := 1.0 - stepped(leave_t / FADE_OUT) if leaving else 1.0
	var come := stepped(t / FADE_IN)
	cover.modulate.a = out
	picture.modulate = Color(PICTURE_DIM, PICTURE_DIM, PICTURE_DIM, come * out)
	band.modulate.a = minf(come, out) if t > TITLE_AT - 0.2 else 0.0
	title.modulate.a = stepped((t - TITLE_AT) / 0.6) * out
	for i in lines.size():
		lines[i].modulate.a = stepped((t - times[i]) / 0.6) * out


func _input(event: InputEvent) -> void:
	if finished or not _is_skip(event):
		return
	get_viewport().set_input_as_handled()
	if leaving:
		_finish()   # A second press while it is leaving ends it at once.
	else:
		leave()


## Any key or click, but not Alt+Enter (the fullscreen switch), a held key repeating, a modifier alone or the mouse moving.
func _is_skip(event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		return event.pressed
	if event is InputEventKey:
		if not event.pressed or event.echo or event.alt_pressed:
			return false
		return event.keycode not in [KEY_ALT, KEY_CTRL, KEY_SHIFT, KEY_META]
	return false
