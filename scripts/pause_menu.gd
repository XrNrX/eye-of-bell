extends CanvasLayer
## The pause menu: Escape in play opens it (and the game freezes), Escape again or Resume closes it.
##   Resume / Save Game / Load Game / Quit to Menu / Quit to Desktop
## Escape belongs first to whatever is already open (the inventory, spell pop-up, a formation drag,
## target mode: they handle it and mark it used), so this only opens when none of those did, and
## never over Level complete / Game over (the game is already paused then). Self-contained: delete
## the PauseMenu node from main.tscn and Escape does nothing. Built in code, like the palette-coloured
## overlays; it runs while the game is paused.

const SaveGame := preload("res://scripts/save_game.gd")
const MAIN_MENU := "res://scenes/main_menu.tscn"

const INK := Color("14101a")
const TORCH_500 := Color("f0b83a")
const STONE_300 := Color("968e9a")
const BUTTON_WIDTH := 224.0

var dim: ColorRect
var title: Label
var status: Label
var buttons := {}  # "resume" | "save" | "load" | "menu" | "desktop" -> Button


func _ready() -> void:
	add_to_group("pause_menu")
	layer = 19  # Above the inventory (11) and the cursor (15), below the end screens (20, 21).
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_build()


func _build() -> void:
	dim = ColorRect.new()
	dim.color = Color(INK, 0.78)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)  # Also swallows clicks meant for the game underneath.
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	center.add_child(box)
	title = Label.new()
	title.text = "PAUSED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", TORCH_500)
	box.add_child(title)
	for entry in [["resume", "RESUME"], ["save", "SAVE GAME"], ["load", "LOAD GAME"], ["menu", "QUIT TO MENU"], ["desktop", "QUIT TO DESKTOP"]]:
		var b := Button.new()
		b.text = entry[1]
		b.custom_minimum_size = Vector2(BUTTON_WIDTH, 0)
		b.add_theme_font_size_override("font_size", 8)
		b.pressed.connect(_pressed.bind(entry[0]))
		box.add_child(b)
		buttons[entry[0]] = b
	status = Label.new()
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.custom_minimum_size = Vector2(BUTTON_WIDTH, 8)
	status.add_theme_font_size_override("font_size", 8)
	status.add_theme_color_override("font_color", STONE_300)
	box.add_child(status)


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE):
		return
	if visible:
		close()
	elif not get_tree().paused:  # Something else open (inventory, end screens) owns Escape.
		open()
	else:
		return
	get_viewport().set_input_as_handled()


func open() -> void:
	status.text = ""
	buttons.load.disabled = not SaveGame.has_save()
	visible = true
	get_tree().paused = true
	get_tree().call_group("audio", "play", "ui_click")
	buttons.resume.grab_focus()  # Enter / Space work straight away.


func close() -> void:
	visible = false
	get_tree().paused = false
	get_tree().call_group("audio", "play", "ui_click")


func _pressed(which: String) -> void:
	match which:
		"resume":
			close()
		"save":
			var error := SaveGame.save(get_tree())
			if error == "":
				get_tree().call_group("audio", "play", "save")
			status.text = "GAME SAVED" if error == "" else error.to_upper()
			buttons.load.disabled = not SaveGame.has_save()
		"load":
			var error := SaveGame.load_game(get_tree())  # Reloads the scene on success.
			if error != "":
				status.text = error.to_upper()
		"menu":
			get_tree().paused = false  # Or the menu's own input would be frozen too.
			get_tree().change_scene_to_file(MAIN_MENU)
		"desktop":
			get_tree().quit()
