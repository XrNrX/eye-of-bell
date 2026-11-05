extends Node
## Fullscreen / windowed, for the whole game. An autoload (project.godot [autoload]), so it is
## there in every scene: it applies the saved choice at startup and handles Alt+Enter anywhere.
##
##   DisplayManager.toggle()             # what Alt+Enter and the Options button call
##   DisplayManager.set_fullscreen(true) # change, apply and save (settings.gd)
##   DisplayManager.mode_changed         # emitted with the new state (the Options button listens)
##
## The game's base size is always 640x360 (project.godot: stretch mode viewport, scale mode
## integer), so the picture is scaled by a whole number and any leftover screen is black bars,
## in both modes. Fullscreen is borderless (Window.MODE_FULLSCREEN, not exclusive). A window opens
## at the largest whole multiple of 640x360 that fits the screen, centred. Mouse positions need
## no work: the engine maps window pixels back to 640x360 through the same transform, bars included.

const Settings := preload("res://scripts/settings.gd")

signal mode_changed(fullscreen: bool)

const BASE := Vector2i(640, 360)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # Alt+Enter works in the inventory and end screens too.
	Settings.apply()
	apply_mode(Settings.fullscreen)


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.alt_pressed \
			and (event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER):
		toggle()
		get_viewport().set_input_as_handled()


func is_fullscreen() -> bool:
	return Settings.fullscreen


func toggle() -> void:
	set_fullscreen(not Settings.fullscreen)


## Change the mode, apply it and remember it.
func set_fullscreen(on: bool) -> void:
	Settings.set_fullscreen(on)
	apply_mode(on)
	mode_changed.emit(on)


## Put the window into the mode without saving.
func apply_mode(on: bool) -> void:
	if DisplayServer.get_name() == "headless":
		return  # Nothing to resize (and tests run this way).
	var window := get_window()
	if on:
		window.mode = Window.MODE_FULLSCREEN
	else:
		_open_window(window)


## The biggest whole number k so that a 640x360 * k window plus its title bar and borders ("extra")
## fits in the usable part of the screen (at least 1).
static func best_scale(usable: Vector2i, extra: Vector2i) -> int:
	return maxi(1, mini((usable.x - extra.x) / BASE.x, (usable.y - extra.y) / BASE.y))


func _open_window(window: Window) -> void:
	window.mode = Window.MODE_WINDOWED
	window.borderless = false
	window.size = BASE
	await get_tree().process_frame  # Let the window manager give it its title bar before measuring.
	var screen := DisplayServer.window_get_current_screen()
	var usable := DisplayServer.screen_get_usable_rect(screen)
	var extra := window.get_size_with_decorations() - window.size
	window.size = BASE * best_scale(usable.size, extra)
	window.position = usable.position + (usable.size - window.get_size_with_decorations()) / 2  # Centred.
