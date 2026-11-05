extends RefCounted
## Player settings that outlive a run, saved to user://settings.cfg. Right now just the
## master volume (the Options screen on the main menu). Use via preload:
##     const Settings := preload("res://scripts/settings.gd")
##     Settings.apply()              # at startup: push the saved values into the engine
##     Settings.set_volume(0.7)      # change, apply and save
##
## Volume is a fraction 0..1 of full, applied to the Master audio bus (0 mutes). The game
## has no sound yet, so this is groundwork: anything played later obeys it automatically.

const SECTION := "audio"

## Where the file lives. A var so tests can point it elsewhere and never touch a real one.
static var path := "user://settings.cfg"
static var volume := 1.0
static var loaded := false


## Read the file (once) and apply it. Safe to call repeatedly.
static func apply() -> void:
	if not loaded:
		loaded = true
		var cfg := ConfigFile.new()
		if cfg.load(path) == OK:
			volume = clampf(float(cfg.get_value(SECTION, "volume", 1.0)), 0.0, 1.0)
	_push_to_engine()


static func set_volume(value: float) -> void:
	volume = clampf(snappedf(value, 0.05), 0.0, 1.0)
	loaded = true
	_push_to_engine()
	var cfg := ConfigFile.new()
	cfg.set_value(SECTION, "volume", volume)
	cfg.save(path)


static func _push_to_engine() -> void:
	var bus := AudioServer.get_bus_index("Master")
	AudioServer.set_bus_mute(bus, volume <= 0.0)
	AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(volume, 0.0001)))
