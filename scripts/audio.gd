extends Node
## The game's sound: effects and an ambient loop. One of these sits in each scene that makes
## noise (main.tscn, main_menu.tscn); other scripts never hold a reference to it, they call it
## through the group, like the HUD:
##
##     get_tree().call_group("audio", "play", "door_open")
##     get_tree().call_group("audio", "play", "hit", -3.0)          # a little quieter
##
## Sounds are WAV files in res://audio/sfx/ named for what they are (door_open.wav). Variants
## are name_2.wav, name_3.wav...: play("step") picks one of step, step_2, step_3 at random, and
## every play also shifts the pitch a little (CUES below), so repeats don't sound identical.
## The effects come from tools/audio/gen_sounds.py; replace any with a real recording of the same
## name. If a file is missing, play() just does nothing.
##
## Effects play on the SFX bus, the ambient loop on the Music bus; both volumes are in the Options
## screen (settings.gd). The node runs while the game is paused, so the end-screen jingles and
## the inventory's clicks sound.

const Settings := preload("res://scripts/settings.gd")

const SFX_DIR := "res://audio/sfx/"
const MUSIC_PATH := "res://audio/music/dungeon_drone.wav"
const VOICES := 12  # How many effects can sound at once; a new one takes over the oldest.

## How each sound behaves, when it differs from the default (0 dB, 4% pitch wobble, no gap):
##   db     volume offset      pitch  random pitch wobble (+/-, as a fraction)
##   gap    the shortest time before the same sound may play again (stops a held key machine-gunning it)
const CUES := {
	"step": {"db": -7.0, "pitch": 0.08, "gap": 0.12},
	"turn": {"db": -10.0, "gap": 0.1},
	"bump": {"db": -4.0, "gap": 0.45},
	"fireball": {"db": -3.0},
	"explosion": {"db": -1.0, "pitch": 0.05},
	"portcullis": {"db": -2.0, "pitch": 0.05},
	"rumble": {"db": -1.0, "pitch": 0.05},
	"door_open": {"db": -3.0},
	"door_close": {"db": -4.0},
	"hit": {"db": -2.0, "pitch": 0.1},
	"whiff": {"db": -6.0, "pitch": 0.1},
	"swing": {"db": -5.0, "pitch": 0.1},
	"monster_attack": {"db": -4.0},
	"hero_hurt": {"db": -3.0, "pitch": 0.1},
	"pickup": {"db": -6.0},
	"drop": {"db": -6.0},
	"ui_click": {"db": -8.0, "pitch": 0.0, "gap": 0.03},
	"ui_swap": {"db": -6.0, "pitch": 0.0},
	"level_complete": {"pitch": 0.0},
	"game_over": {"pitch": 0.0},
}
const DEFAULT_PITCH_WOBBLE := 0.04

## Start the ambient loop on _ready. A scene can turn it off (or change its level) in the editor.
@export var music_on := true
@export var music_db := -4.0

var library := {}      # name -> Array of AudioStream (the variants)
var voices: Array[AudioStreamPlayer] = []
var next_voice := 0
var last_played := {}  # name -> time (msec) it last sounded, for the gaps
var played: Array = [] # the last 64 names played, newest last (tests and debugging read this)
var music: AudioStreamPlayer


func _ready() -> void:
	add_to_group("audio")
	process_mode = Node.PROCESS_MODE_ALWAYS
	Settings.apply()  # Creates the Music and SFX buses and applies the saved volumes.
	_load_library()
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		p.bus = Settings.SFX_BUS
		add_child(p)
		voices.append(p)
	if music_on:
		start_music()


## Find every WAV in the sound folder and group the variants under their base name.
func _load_library() -> void:
	var dir := DirAccess.open(SFX_DIR)
	if dir == null:
		return
	var seen := {}
	for f in dir.get_files():
		# An exported game lists "name.wav.import" or "name.wav.remap" instead of the plain name.
		f = f.trim_suffix(".remap").trim_suffix(".import")
		if not f.ends_with(".wav") or seen.has(f):
			continue  # (The editor lists both name.wav and name.wav.import: load it once.)
		seen[f] = true
		var stream: AudioStream = load(SFX_DIR + f)
		if stream == null:
			continue
		var base := f.get_basename()
		var variant := RegEx.create_from_string("^(.*)_\\d+$").search(base)
		if variant:
			base = variant.get_string(1)
		library.get_or_add(base, []).append(stream)


func has_sound(sound: String) -> bool:
	return library.has(sound)


func variants(sound: String) -> int:
	return library[sound].size() if library.has(sound) else 0


## Play a sound effect by name. volume_db adds to the sound's own level, pitch multiplies its speed.
func play(sound: String, volume_db := 0.0, pitch := 1.0) -> void:
	if not library.has(sound):
		return
	var cue: Dictionary = CUES.get(sound, {})
	var now := Time.get_ticks_msec()
	if now - last_played.get(sound, -100000) < int(cue.get("gap", 0.0) * 1000.0):
		return
	last_played[sound] = now
	var options: Array = library[sound]
	var voice := _free_voice()
	voice.stream = options[randi() % options.size()]
	voice.volume_db = volume_db + float(cue.get("db", 0.0))
	voice.pitch_scale = pitch * (1.0 + randf_range(-1.0, 1.0) * float(cue.get("pitch", DEFAULT_PITCH_WOBBLE)))
	voice.play()
	played.append(sound)
	if played.size() > 64:
		played.pop_front()


## An idle voice, or the one that has been sounding longest.
func _free_voice() -> AudioStreamPlayer:
	for v in voices:
		if not v.playing:
			return v
	next_voice = (next_voice + 1) % voices.size()
	return voices[next_voice]


func start_music() -> void:
	if music != null and music.playing:
		return
	if not ResourceLoader.exists(MUSIC_PATH):
		return
	var stream: AudioStreamWAV = (load(MUSIC_PATH) as AudioStreamWAV).duplicate()
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD  # Whatever the import settings say.
	stream.loop_begin = 0
	stream.loop_end = roundi(stream.get_length() * stream.mix_rate)  # In samples. (Not data.size(): the import may compress the data.)
	if music == null:
		music = AudioStreamPlayer.new()
		music.bus = Settings.MUSIC_BUS
		add_child(music)
	music.stream = stream
	music.volume_db = -40.0
	music.play()
	create_tween().tween_property(music, "volume_db", music_db, 2.0)  # Fade in, so the loop never starts with a bang.


func stop_music() -> void:
	if music != null:
		music.stop()
