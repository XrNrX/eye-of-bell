extends Node3D
## The main menu and the game's startup scene: a torch-lit corridor rendered with the
## game's own level builder (scripts/dungeon_builder.gd, set to build the architecture
## only), its textures and its torch light, at the game's 320x200 -- with the title and
## the buttons drawn over it.
##
##   NEW GAME   starts a fresh run
##   LOAD GAME  loads the save (greyed out when there isn't one)
##   OPTIONS    master volume (see settings.gd), kept between sessions
##   QUIT       exits
##
## Also reached from Game over's "Quit to Menu" (see end_screen.gd).
##
## The look: Press Start 2P (a free pixel font under the SIL Open Font License, see
## art/fonts/OFL.txt) in sizes that are multiples of 8, so every pixel lands on the grid;
## its import settings turn anti-aliasing and hinting off, so keep them off. The title has
## a palette-coloured drop shadow. All colours are the game's palette.

const MAIN_SCENE := "res://scenes/main.tscn"
const SaveGame := preload("res://scripts/save_game.gd")
const Settings := preload("res://scripts/settings.gd")
const DungeonMap := preload("res://scripts/dungeon_map.gd")
const FONT := preload("res://art/fonts/PressStart2P-Regular.ttf")

# Palette colours (tools/art/palette.json).
const INK := Color("14101a")
const STONE_900 := Color("231e2b")
const STONE_800 := Color("322c3b")
const STONE_700 := Color("463f4f")
const STONE_500 := Color("6a6272")
const STONE_100 := Color("c3bcc0")
const RUST_700 := Color("7a3a1c")
const BONE_300 := Color("e6dcc0")
const TORCH_700 := Color("c78a1e")
const TORCH_500 := Color("f0b83a")
const TORCH_300 := Color("ffe38a")

const TITLE_SIZE := 16        # Two native pixels per font pixel: chunky.
const TEXT_SIZE := 8          # One.
const VIEW_CELL := Vector2i(1, 7)  # Camera starts in this cell of the level, facing east...
const VIEW_FACING_DEG := -90.0     # ...down the long south corridor (torches on the right wall).
const SWAY := 0.035           # How far the camera drifts, in world units, so the view is alive.
const VOLUME_STEP := 0.1

@onready var camera: Camera3D = %Camera3D
@onready var root_ui: Control = %Root
@onready var title: Label = %Title
@onready var menu_box: VBoxContainer = %MenuBox
@onready var options_box: VBoxContainer = %OptionsBox
@onready var new_game_button: Button = %NewGameButton
@onready var load_button: Button = %LoadButton
@onready var options_button: Button = %OptionsButton
@onready var quit_button: Button = %QuitButton
@onready var options_title: Label = %OptionsTitle
@onready var volume_label: Label = %VolumeLabel
@onready var volume_bar: ProgressBar = %VolumeBar
@onready var volume_down: Button = %VolumeDown
@onready var volume_up: Button = %VolumeUp
@onready var back_button: Button = %BackButton
@onready var blip: AudioStreamPlayer = %Blip

var time := 0.0
var base_position: Vector3


func _ready() -> void:
	Settings.apply()
	root_ui.theme = _make_theme()
	options_title.add_theme_color_override("font_color", TORCH_300)
	_style_title()

	# The camera: a hand's breadth inside the corridor's west end, looking east.
	var world := DungeonMap.cell_to_world(VIEW_CELL)
	base_position = Vector3(world.x - 0.6, 1.0, world.z)
	camera.position = base_position
	camera.rotation_degrees.y = VIEW_FACING_DEG

	new_game_button.pressed.connect(_on_new_game_pressed)
	load_button.pressed.connect(_on_load_pressed)
	options_button.pressed.connect(_show_options.bind(true))
	quit_button.pressed.connect(func(): get_tree().quit())
	back_button.pressed.connect(_show_options.bind(false))
	volume_down.pressed.connect(_change_volume.bind(-VOLUME_STEP))
	volume_up.pressed.connect(_change_volume.bind(VOLUME_STEP))

	load_button.disabled = not SaveGame.has_save()  # Nothing to load yet: greyed out.
	blip.stream = _make_blip()
	_refresh_volume()
	new_game_button.grab_focus()  # So Enter / Space and the arrow keys work straight away.


func _process(delta: float) -> void:
	# A slow drift and a hint of roll, as if the torch-bearer were breathing.
	time += delta
	camera.position = base_position + Vector3(sin(time * 0.31) * SWAY, sin(time * 0.53) * SWAY * 0.6, sin(time * 0.23) * SWAY)
	camera.rotation_degrees.z = sin(time * 0.37) * 0.35


func _unhandled_input(event: InputEvent) -> void:
	if not options_box.visible:
		return
	if event.is_action_pressed("ui_cancel"):
		_show_options(false)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_left"):
		_change_volume(-VOLUME_STEP)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_right"):
		_change_volume(VOLUME_STEP)
		get_viewport().set_input_as_handled()


func _on_new_game_pressed() -> void:
	get_tree().change_scene_to_file(MAIN_SCENE)


func _on_load_pressed() -> void:
	var error := SaveGame.load_game(get_tree())
	if error != "":
		load_button.text = "NO SAVE"  # (Can only happen if the file vanished since the menu opened.)
		load_button.disabled = true


func _show_options(open: bool) -> void:
	menu_box.visible = not open
	options_box.visible = open
	(back_button if open else options_button).grab_focus()  # (+ and - may be greyed out; the keys work anyway)


func _change_volume(delta: float) -> void:
	Settings.set_volume(Settings.volume + delta)
	_refresh_volume()
	blip.play()  # So the new level can be heard (there is no other sound in the game yet).


func _refresh_volume() -> void:
	var percent := roundi(Settings.volume * 100.0)
	volume_bar.value = percent
	volume_label.text = "VOLUME %d%%" % percent if percent > 0 else "VOLUME OFF"
	volume_down.disabled = percent <= 0
	volume_up.disabled = percent >= 100


# --------------------------------------------------------------------------
# Look
# --------------------------------------------------------------------------

## The title: big, torch-yellow, with a rust-coloured drop shadow and a thin ink edge.
func _style_title() -> void:
	title.add_theme_font_override("font", FONT)
	title.add_theme_font_size_override("font_size", TITLE_SIZE)
	title.add_theme_color_override("font_color", TORCH_300)
	title.add_theme_color_override("font_shadow_color", RUST_700)
	title.add_theme_constant_override("shadow_offset_x", 2)
	title.add_theme_constant_override("shadow_offset_y", 2)
	title.add_theme_color_override("font_outline_color", INK)
	title.add_theme_constant_override("outline_size", 2)


func _make_theme() -> Theme:
	var t := Theme.new()
	t.default_font = FONT
	t.default_font_size = TEXT_SIZE
	t.set_color("font_color", "Label", BONE_300)

	# Buttons: dark stone slabs; the hovered or focused one lights up like torchlight.
	t.set_font("font", "Button", FONT)
	t.set_font_size("font_size", "Button", TEXT_SIZE)
	t.set_color("font_color", "Button", BONE_300)
	t.set_color("font_hover_color", "Button", TORCH_300)
	t.set_color("font_focus_color", "Button", TORCH_300)
	t.set_color("font_pressed_color", "Button", TORCH_500)
	t.set_color("font_disabled_color", "Button", STONE_500)
	t.set_stylebox("normal", "Button", _slab(Color(STONE_900, 0.88), STONE_700))
	t.set_stylebox("hover", "Button", _slab(Color(STONE_800, 0.95), TORCH_500))
	t.set_stylebox("focus", "Button", _slab(Color(STONE_800, 0.95), TORCH_500))
	t.set_stylebox("pressed", "Button", _slab(Color(STONE_700, 0.95), TORCH_300))
	t.set_stylebox("disabled", "Button", _slab(Color(STONE_900, 0.6), STONE_800))
	t.set_constant("h_separation", "Button", 0)

	# The volume bar, drawn like the HUD's bars.
	var back := StyleBoxFlat.new()
	back.bg_color = INK
	var fill := StyleBoxFlat.new()
	fill.bg_color = TORCH_500
	t.set_stylebox("background", "ProgressBar", back)
	t.set_stylebox("fill", "ProgressBar", fill)
	t.set_constant("outline_size", "Label", 0)
	return t


func _slab(fill: Color, edge: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fill
	s.border_color = edge
	s.set_border_width_all(1)
	s.content_margin_left = 6
	s.content_margin_right = 6
	s.content_margin_top = 4
	s.content_margin_bottom = 4
	return s


## A short square-wave beep, generated here (no audio files in the project yet).
func _make_blip() -> AudioStreamWAV:
	var rate := 22050
	var samples := int(rate * 0.07)
	var data := PackedByteArray()
	data.resize(samples)
	for i in samples:
		var wave := 1.0 if int(i * 880.0 / rate) % 2 == 0 else -1.0
		var envelope := 1.0 - float(i) / samples
		data[i] = int(128.0 + wave * envelope * 60.0)
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_8_BITS
	wav.mix_rate = rate
	wav.stereo = false
	# 8-bit WAV data is signed in Godot: convert from the unsigned form above.
	for i in samples:
		data[i] = (data[i] - 128) & 0xFF
	wav.data = data
	return wav
