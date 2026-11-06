extends RefCounted
## Player settings that outlive a run, saved to user://settings.cfg: the three volumes and the
## fullscreen / windowed choice of the Options screen on the main menu. Use via preload:
##     const Settings := preload("res://scripts/settings.gd")
##     Settings.apply()                # at startup: push the saved values into the engine
##     Settings.set_volume(0.7)        # master volume: change, apply and save
##     Settings.set_music_volume(0.5)  # the ambient loop
##     Settings.set_sfx_volume(0.8)    # sound effects
##     Settings.set_fullscreen(false)  # remember the display mode (display_manager.gd applies it)
##     Settings.set_fog(false)         # volumetric fog on or off (spell_effects_config.apply_environment)
##     Settings.set_reduce_flashing(true)  # softer holy light and glows (spell_effects.gd, party_hud.gd)
##
## Each is a fraction 0..1 of full (0 mutes). They are applied to the audio buses: Master, and
## Music and SFX, which are created here if the project doesn't define them (both send to
## Master, so the master volume scales everything). audio.gd plays on those buses.

const SECTION := "audio"
const DISPLAY_SECTION := "display"
const MUSIC_BUS := "Music"
const SFX_BUS := "SFX"

## Where the file lives. A var so tests can point it elsewhere and never touch a real one.
static var path := "user://settings.cfg"
static var volume := 1.0        # Master.
static var music_volume := 0.7  # The ambient loop starts a little below full: it is a bed, not a feature.
static var sfx_volume := 1.0
static var fullscreen := true   # Borderless fullscreen by default; false = a window.
static var fog := true          # The subtle volumetric fog; off on weak machines.
static var reduce_flashing := false  # Softer spell and holy-light pulses: steady glows, no flicker, no shake.
static var loaded := false


## Read the file (once) and apply it. Safe to call repeatedly.
static func apply() -> void:
	if not loaded:
		loaded = true
		var cfg := ConfigFile.new()
		if cfg.load(path) == OK:
			volume = clampf(float(cfg.get_value(SECTION, "volume", volume)), 0.0, 1.0)
			music_volume = clampf(float(cfg.get_value(SECTION, "music_volume", music_volume)), 0.0, 1.0)
			sfx_volume = clampf(float(cfg.get_value(SECTION, "sfx_volume", sfx_volume)), 0.0, 1.0)
			fullscreen = bool(cfg.get_value(DISPLAY_SECTION, "fullscreen", fullscreen))
			fog = bool(cfg.get_value(DISPLAY_SECTION, "fog", fog))
			reduce_flashing = bool(cfg.get_value(DISPLAY_SECTION, "reduce_flashing", reduce_flashing))
	_push_to_engine()


static func set_volume(value: float) -> void:
	volume = _clean(value)
	_changed()


static func set_music_volume(value: float) -> void:
	music_volume = _clean(value)
	_changed()


static func set_sfx_volume(value: float) -> void:
	sfx_volume = _clean(value)
	_changed()


static func set_fullscreen(value: bool) -> void:
	fullscreen = value
	_changed()


static func set_fog(value: bool) -> void:
	fog = value
	_changed()


static func set_reduce_flashing(value: bool) -> void:
	reduce_flashing = value
	_changed()


static func _clean(value: float) -> float:
	return clampf(snappedf(value, 0.05), 0.0, 1.0)


static func _changed() -> void:
	loaded = true
	_push_to_engine()
	var cfg := ConfigFile.new()
	cfg.set_value(SECTION, "volume", volume)
	cfg.set_value(SECTION, "music_volume", music_volume)
	cfg.set_value(SECTION, "sfx_volume", sfx_volume)
	cfg.set_value(DISPLAY_SECTION, "fullscreen", fullscreen)
	cfg.set_value(DISPLAY_SECTION, "fog", fog)
	cfg.set_value(DISPLAY_SECTION, "reduce_flashing", reduce_flashing)
	cfg.save(path)


## Make sure the Music and SFX buses exist (each sends to Master). Returns nothing; safe to repeat.
static func ensure_buses() -> void:
	for bus_name in [MUSIC_BUS, SFX_BUS]:
		if AudioServer.get_bus_index(bus_name) == -1:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, bus_name)
			AudioServer.set_bus_send(i, "Master")


static func _push_to_engine() -> void:
	ensure_buses()
	for pair in [["Master", volume], [MUSIC_BUS, music_volume], [SFX_BUS, sfx_volume]]:
		var bus := AudioServer.get_bus_index(pair[0])
		AudioServer.set_bus_mute(bus, pair[1] <= 0.0)
		AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(pair[1], 0.0001)))
