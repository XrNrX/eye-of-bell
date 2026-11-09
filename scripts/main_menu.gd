extends Node3D
## The main menu and the game's startup scene: a torch-lit corridor rendered with the
## game's own level builder (scripts/dungeon_builder.gd, set to build the architecture
## only), its textures and its torch light, rendered in a 320x180 SubViewport shown at 2x
## (the same chunky pixels as the in-game 3D view) -- with the title and the buttons drawn
## over it at the native 640x360.
##
##   NEW GAME   starts a fresh run
##   LOAD GAME  loads the save (greyed out when there isn't one)
##   OPTIONS    master, music and effects volume (see settings.gd), kept between sessions
##   QUIT       exits
##
## Also reached from Game over's "Quit to Menu" (see end_screen.gd).
##
## The look: Press Start 2P (a free pixel font under the SIL Open Font License, see
## art/fonts/OFL.txt) in sizes that are multiples of 8 (title 32, text 16), so every pixel lands on the grid;
## its import settings turn anti-aliasing and hinting off, so keep them off. The title has
## a palette-coloured drop shadow. All colours are the game's palette.

const MAIN_SCENE := "res://scenes/main.tscn"
const INTRO_SCENE := "res://scenes/intro.tscn"
const INTRO_SEEN := "intro_played"  # In Settings' hints_seen: the intro has played once on this machine.
const TITLE_ART := "res://art/ui/title.png"
const SaveGame := preload("res://scripts/save_game.gd")
const Settings := preload("res://scripts/settings.gd")
const SpellEffectsConfig := preload("res://scripts/spell_effects_config.gd")
const DungeonMap := preload("res://scripts/dungeon_map.gd")
const FONT := preload("res://art/fonts/PressStart2P-Regular.ttf")

# Palette colours (tools/art/palette.json).
const INK := Color("0b0a10")
const STONE_900 := Color("14131b")
const STONE_800 := Color("1f1e28")
const STONE_700 := Color("31303c")
const STONE_500 := Color("504f5e")
const STONE_100 := Color("aaa9b4")
const RUST_700 := Color("4e2a1a")
const BONE_300 := Color("c9c0a4")
const TORCH_700 := Color("9a5f1c")
const TORCH_500 := Color("d99a36")
const TORCH_300 := Color("f5cf80")

const TITLE_SIZE := 32        # Four native pixels per font pixel: chunky.
const TEXT_SIZE := 16         # Two (the same pixel size as the 2x dungeon view).
const VIEW_CELL := Vector2i(6, 13)  # Camera starts in this cell of the level, facing east...
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
@onready var volume_label: Label = %VolumeLabel  # The master volume's row; the others are built from it.
@onready var volume_bar: ProgressBar = %VolumeBar
@onready var volume_down: Button = %VolumeDown
@onready var volume_up: Button = %VolumeUp
@onready var back_button: Button = %BackButton

## The three volumes: kind -> {name, label, bar, down, up}. Left and right arrows change the
## row that has the keyboard focus (or the one last used).
var rows := {}
var current_kind := "master"
var fog_button: Button      # "FOG: ON" / "FOG: OFF".
var flash_button: Button    # "FLASHING: REDUCED" / "FLASHING: NORMAL".
var hints_button: Button    # "HINTS: ON" / "HINTS: OFF".
var bars_button: Button     # "ENEMY HEALTH BARS: ON / BOSS ONLY / OFF".
var palette_button: Button  # "PALETTE: ON" / "PALETTE: OFF" (the optional palette filter on the 3D view).
var options_panel: Panel    # The dark panel behind the Options screen.
var display_button: Button  # "SCREEN: FULLSCREEN" / "SCREEN: WINDOWED", built in _build_display_button.

var time := 0.0
var base_position: Vector3


func _ready() -> void:
	Settings.apply()
	if not Settings.hint_seen(INTRO_SEEN):  # The very first launch plays the intro, which comes back here.
		Settings.mark_hint(INTRO_SEEN)
		set_process(false)
		get_tree().change_scene_to_file.call_deferred(INTRO_SCENE)
		return
	_show_title_art()
	root_ui.theme = _make_theme()
	options_title.add_theme_color_override("font_color", TORCH_300)
	_style_title()

	# The camera: a hand's breadth inside the corridor's west end, looking east.
	var world := DungeonMap.cell_to_world(VIEW_CELL)
	base_position = Vector3(world.x - 0.6, 1.0, world.z)
	camera.position = base_position
	camera.rotation_degrees.y = VIEW_FACING_DEG

	_build_volume_rows()
	_build_display_button()
	_build_fog_button()
	_build_flash_button()
	_build_hints_button()
	_build_palette_button()
	_build_bars_button()
	_arrange_options()
	new_game_button.pressed.connect(_on_new_game_pressed)
	load_button.pressed.connect(_on_load_pressed)
	options_button.pressed.connect(_show_options.bind(true))
	quit_button.pressed.connect(func(): get_tree().quit())
	back_button.pressed.connect(_show_options.bind(false))
	var intro_button: Button = options_button.duplicate()  # Watch the intro again, between Options and Quit.
	intro_button.unique_name_in_owner = false
	intro_button.name = "IntroButton"
	intro_button.text = "INTRO"
	menu_box.add_child(intro_button)
	menu_box.move_child(intro_button, quit_button.get_index())
	intro_button.pressed.connect(func(): get_tree().change_scene_to_file(INTRO_SCENE))
	intro_button.pressed.connect(_click)

	load_button.disabled = not SaveGame.has_save()  # Nothing to load yet: greyed out.
	_refresh_volume()
	_refresh_display()
	_apply_look()
	for b in [new_game_button, load_button, options_button, quit_button, back_button]:
		b.pressed.connect(_click)  # (Load is also greyed out when there is no save: no click then.)
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
		_change_volume(_focused_kind(), -VOLUME_STEP)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_right"):
		_change_volume(_focused_kind(), VOLUME_STEP)
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
	if options_panel:
		options_panel.visible = open
	title.visible = not open  # The Options panel covers the title.
	(back_button if open else options_button).grab_focus()  # (+ and - may be greyed out; the keys work anyway)


## The Fullscreen / Windowed switch: a copy of the Back button above it. The game's display_manager.gd
## (an autoload) does the work; Alt+Enter changes it too, so the button listens for that.
func _build_display_button() -> void:
	display_button = back_button.duplicate()
	display_button.unique_name_in_owner = false
	options_box.add_child(display_button)
	options_box.move_child(display_button, back_button.get_index())
	display_button.pressed.connect(func():
		var dm := get_node_or_null("/root/DisplayManager")
		if dm:
			dm.toggle()
		_refresh_display())
	display_button.pressed.connect(_click)
	var dm := get_node_or_null("/root/DisplayManager")
	if dm:
		dm.mode_changed.connect(func(_on): _refresh_display())


## The volumetric fog switch (a copy of the Back button). The menu's own backdrop shows it at once.
func _build_fog_button() -> void:
	fog_button = back_button.duplicate()
	fog_button.unique_name_in_owner = false
	options_box.add_child(fog_button)
	options_box.move_child(fog_button, back_button.get_index())
	fog_button.pressed.connect(func():
		Settings.set_fog(not Settings.fog)
		_apply_look()
		_refresh_display())
	fog_button.pressed.connect(_click)


## The "reduce flashing" switch: holy light and spell glows become steady and gentle.
func _build_flash_button() -> void:
	flash_button = back_button.duplicate()
	flash_button.unique_name_in_owner = false
	options_box.add_child(flash_button)
	options_box.move_child(flash_button, back_button.get_index())
	flash_button.tooltip_text = "Reduced: softer flashes and no screen shake"
	flash_button.pressed.connect(func():
		Settings.set_reduce_flashing(not Settings.reduce_flashing)
		_refresh_display())
	flash_button.pressed.connect(_click)


## Lay the Options screen out so it fits 640x360 with all its switches: the four toggles (screen, fog, flashing,
## hints) sit in two columns, and a dark panel behind makes the text readable over the title picture.
func _arrange_options() -> void:
	options_box.offset_left = 48.0
	options_box.offset_top = 24.0
	options_box.offset_right = 592.0
	options_box.offset_bottom = 348.0
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 2)
	options_box.add_child(grid)
	options_box.move_child(grid, back_button.get_index())
	for b in [display_button, fog_button, flash_button, hints_button, palette_button, bars_button]:
		b.reparent(grid)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 26)  # Shorter, so five switches in two columns still fit.
	var panel := Panel.new()
	var box := StyleBoxFlat.new()
	box.bg_color = Color(STONE_900.r, STONE_900.g, STONE_900.b, 0.9)
	box.border_color = Color("7c4426")  # Palette rust_500: rusted iron.
	box.set_border_width_all(2)
	panel.add_theme_stylebox_override("panel", box)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.position = Vector2(32, 8)
	panel.size = Vector2(576, 344)
	panel.visible = false
	root_ui.add_child(panel)
	root_ui.move_child(panel, options_box.get_index())  # Behind the options.
	options_panel = panel


## The palette filter switch: the 3D view snapped to the 32 colours with a light dither, to compare with the
## plain look. Takes effect when a game starts.
func _build_palette_button() -> void:
	palette_button = back_button.duplicate()
	palette_button.unique_name_in_owner = false
	options_box.add_child(palette_button)
	options_box.move_child(palette_button, back_button.get_index())
	palette_button.pressed.connect(func():
		Settings.set_palette_filter(not Settings.palette_filter)
		_refresh_display())
	palette_button.pressed.connect(_click)


## Enemy health bars: On / Boss only / Off (cycles).
func _build_bars_button() -> void:
	bars_button = back_button.duplicate()
	bars_button.unique_name_in_owner = false
	options_box.add_child(bars_button)
	options_box.move_child(bars_button, back_button.get_index())
	bars_button.tooltip_text = "Boss only, or Off, for the old-school feel"
	bars_button.pressed.connect(func():
		Settings.set_enemy_bars((Settings.enemy_bars + 1) % 3)
		_refresh_display())
	bars_button.pressed.connect(_click)


## The "show hints" switch: first-time tips such as how to open the character sheet.
func _build_hints_button() -> void:
	hints_button = back_button.duplicate()
	hints_button.unique_name_in_owner = false
	options_box.add_child(hints_button)
	options_box.move_child(hints_button, back_button.get_index())
	hints_button.pressed.connect(func():
		Settings.set_show_hints(not Settings.show_hints)
		_refresh_display())
	hints_button.pressed.connect(_click)


## The title screen picture (art/ui/title.png, 640x360 at full resolution, shown 1:1: the entrance to a cursed
## dungeon at night) is the menu's backdrop. The 3D corridor (the game's own level builder) is kept in the scene, hidden and not
## rendering, as the fallback if the picture is missing.
func _show_title_art() -> void:
	if not ResourceLoader.exists(TITLE_ART):
		return
	var art := TextureRect.new()
	art.name = "TitleArt"
	art.texture = load(TITLE_ART)
	art.position = Vector2.ZERO
	art.size = Vector2(640, 360)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_SCALE
	art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var backdrop: Node = get_node("View/Backdrop")
	backdrop.get_parent().add_child(art)
	backdrop.get_parent().move_child(art, backdrop.get_index() + 1)
	backdrop.visible = false
	get_node("View/Backdrop/Port").render_target_update_mode = SubViewport.UPDATE_DISABLED


## Glow and fog on the backdrop's environment, from data/spell_effects.tres and the Options switch.
func _apply_look() -> void:
	var world_env := get_node_or_null("View/Backdrop/Port/WorldEnvironment")
	if world_env:
		SpellEffectsConfig.apply_environment(world_env.environment, Settings.fog)


func _refresh_display() -> void:
	fog_button.text = "FOG: ON" if Settings.fog else "FOG: OFF"
	flash_button.text = "FLASHING: REDUCED" if Settings.reduce_flashing else "FLASHING: NORMAL"
	hints_button.text = "HINTS: ON" if Settings.show_hints else "HINTS: OFF"
	palette_button.text = "PALETTE: ON" if Settings.palette_filter else "PALETTE: OFF"
	bars_button.text = "ENEMY BARS: " + ["ON", "BOSS ONLY", "OFF"][Settings.enemy_bars]
	display_button.text = "SCREEN: FULLSCREEN" if Settings.fullscreen else "SCREEN: WINDOWED"


## Master comes from the scene; Music and Effects are copies of its label and row.
func _build_volume_rows() -> void:
	var master_row: Control = volume_down.get_parent()
	rows["master"] = {"name": "MASTER", "label": volume_label, "bar": volume_bar, "down": volume_down, "up": volume_up}
	var anchor: Control = master_row
	for kind in ["music", "effects"]:
		var label: Label = volume_label.duplicate()
		var row: Control = master_row.duplicate()
		for n in [label, row] + row.find_children("*", "", true, false):
			n.unique_name_in_owner = false  # The copies share the originals' names.
		options_box.add_child(label)
		options_box.add_child(row)
		options_box.move_child(label, anchor.get_index() + 1)
		options_box.move_child(row, label.get_index() + 1)
		anchor = row
		var buttons := row.get_children()
		rows[kind] = {"name": kind.to_upper(), "label": label, "bar": buttons[1], "down": buttons[0], "up": buttons[2]}
	for kind in rows:
		var r: Dictionary = rows[kind]
		r.down.pressed.connect(_change_volume.bind(kind, -VOLUME_STEP))
		r.up.pressed.connect(_change_volume.bind(kind, VOLUME_STEP))
		for b in [r.down, r.up]:
			b.focus_entered.connect(func(): current_kind = kind)


func _volume_of(kind: String) -> float:
	match kind:
		"music": return Settings.music_volume
		"effects": return Settings.sfx_volume
	return Settings.volume


func _focused_kind() -> String:
	var focus := get_viewport().gui_get_focus_owner()
	for kind in rows:
		if focus != null and (focus == rows[kind].down or focus == rows[kind].up):
			return kind
	return current_kind


func _change_volume(kind: String, delta: float) -> void:
	current_kind = kind
	var value := _volume_of(kind) + delta
	match kind:
		"music": Settings.set_music_volume(value)
		"effects": Settings.set_sfx_volume(value)
		_: Settings.set_volume(value)
	_refresh_volume()
	_click()  # An effect, so a change to the effects or master volume can be heard right away.


func _click() -> void:
	if is_inside_tree():  # (New Game and Load have already replaced the scene by the time this runs.)
		get_tree().call_group("audio", "play", "ui_click")


func _refresh_volume() -> void:
	for kind in rows:
		var r: Dictionary = rows[kind]
		var percent := roundi(_volume_of(kind) * 100.0)
		r.bar.value = percent
		r.label.text = "%s %d%%" % [r.name, percent] if percent > 0 else "%s OFF" % r.name
		r.down.disabled = percent <= 0
		r.up.disabled = percent >= 100


# --------------------------------------------------------------------------
# Look
# --------------------------------------------------------------------------

## The title: big, torch-yellow, with a rust-coloured drop shadow and a thin ink edge.
func _style_title() -> void:
	title.add_theme_font_override("font", FONT)
	title.add_theme_font_size_override("font_size", TITLE_SIZE)
	title.add_theme_color_override("font_color", TORCH_300)
	title.add_theme_color_override("font_shadow_color", RUST_700)
	title.add_theme_constant_override("shadow_offset_x", 4)
	title.add_theme_constant_override("shadow_offset_y", 4)
	title.add_theme_color_override("font_outline_color", INK)
	title.add_theme_constant_override("outline_size", 4)


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
	s.set_border_width_all(2)
	s.content_margin_left = 12
	s.content_margin_right = 12
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	return s
