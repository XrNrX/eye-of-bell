extends CanvasLayer
## The message log, in the log window of the stone frame (see ui_layout.gd): a scrolling
## history of what happened ("The Slime hits Cleric for 2."), newest at the bottom and
## brightest, older lines dimmer. Below it a one-line status row shows transient text: the
## name of the item under the mouse, or a prompt like "Heal whom?".
##
## Other scripts call show_message() through the "hud" group, so this scene can be removed
## without breaking anything:
##   show_message(text)             a line in the log
##   show_message(text, true)       the status row; stays until clear_message()
##   show_message(text, false, "miss")   a log line in the miss style (prefix and colour
##                                  from data/combat_feel.tres)
##   clear_message(only_if)         clear the status row (only if it shows that text)
##   show_banner(text)              big text over the top of the 3D view for a moment ("Key picked up!")
##
## last_message / last_tone are the newest log line, for anything that wants to read it.

const UiLayout := preload("res://scripts/ui_layout.gd")
const FeelConfigScript := preload("res://scripts/combat_feel_config.gd")

const MAX_LINES := 40
const NEWEST := Color("c9c0a4")    # Palette bone_300.
const RECENT := Color("aaa9b4")    # Palette stone_100.
const OLD := Color("7b7a88")       # Palette stone_300.
const STATUS := Color("f5cf80")    # Palette torch_300.
const PADDING := Vector2(8, 6)
const STATUS_HEIGHT := 12.0

var feel_cfg: Resource = FeelConfigScript.get_config()  # data/combat_feel.tres
@onready var log_text: RichTextLabel = %Log
@onready var message: Label = %Message  # The status row.

var lines := []  # [{text, colour: Color or null (use the age colour)}], oldest first.
var last_message := ""
var last_tone := ""
var banner: Label
var banners: Array = []  # Every banner shown, for tests.


func _ready() -> void:
	add_to_group("hud")
	var well := UiLayout.LOG
	log_text.position = well.position + PADDING
	log_text.size = well.size - PADDING * 2.0 - Vector2(0, STATUS_HEIGHT)
	message.position = Vector2(well.position.x + PADDING.x, well.end.y - PADDING.y - STATUS_HEIGHT)
	message.size = Vector2(well.size.x - PADDING.x * 2.0, STATUS_HEIGHT)
	message.add_theme_color_override("font_color", STATUS)
	message.text = ""
	log_text.get_v_scroll_bar().modulate.a = 0.0  # It scrolls itself; no scrollbar needed.


## A line in the log, or (hold) the status row. tone "miss" gives it the miss style.
func show_message(text: String, hold := false, tone := "") -> void:
	if hold:
		message.text = text
		return
	var colour = null
	if tone == "miss" and feel_cfg.miss_message_enabled:
		text = feel_cfg.miss_prefix + text
		colour = feel_cfg.miss_colour
	elif tone == "crit":
		colour = feel_cfg.crit_log_colour
	elif tone == "hurt":
		colour = feel_cfg.crit_taken_log_colour
	elif tone == "fail":
		colour = feel_cfg.fail_colour
	elif tone == "banter":
		colour = feel_cfg.banter_log_colour
	last_message = text
	last_tone = tone
	lines.append({"text": text, "colour": colour})
	if lines.size() > MAX_LINES:
		lines.pop_front()
	_redraw()


## Big text in the upper part of the 3D view that holds a moment and fades: for things the player must not miss.
## A newer banner replaces the one showing.
func show_banner(text: String) -> void:
	if banner != null and is_instance_valid(banner):
		banner.queue_free()
	banner = Label.new()
	banner.text = text
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.add_theme_font_size_override("font_size", 16)
	banner.add_theme_color_override("font_color", STATUS)
	banner.add_theme_color_override("font_outline_color", Color("0b0a10"))  # Palette ink.
	banner.add_theme_constant_override("outline_size", 4)
	var view := UiLayout.VIEW
	banner.size = Vector2(view.size.x, 20)
	banner.position = Vector2(view.position.x, view.position.y + 38)
	add_child(banner)
	banners.append(text)
	var tween := banner.create_tween()
	tween.tween_interval(1.6)
	tween.tween_property(banner, "modulate:a", 0.0, 0.5)
	tween.tween_callback(banner.queue_free)


## Clear the status row now. With only_if, only if that exact text is showing, so a hover
## ending can't wipe a different prompt that arrived in the meantime.
func clear_message(only_if := "") -> void:
	if only_if == "" or message.text == only_if:
		message.text = ""


## Rebuild the log: the newest line brightest, the two before it a little dimmer, the rest dim.
func _redraw() -> void:
	log_text.clear()
	for i in lines.size():
		var age: int = lines.size() - 1 - i
		var line: Dictionary = lines[i]
		var colour: Color = line.colour if line.colour != null else \
				(NEWEST if age == 0 else (RECENT if age <= 2 else OLD))
		log_text.push_color(colour)
		log_text.add_text(line.text)
		log_text.pop()
		if i < lines.size() - 1:
			log_text.newline()
