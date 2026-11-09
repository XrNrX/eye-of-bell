extends Control
## The intro cutscene (scenes/intro.tscn): the party walks up the road and into the dungeon. It plays once on first launch
## (main_menu.gd) and from the menu's INTRO button after that. Any key or click skips to the main menu.
##
## SHOTS is the whole film as data. Each entry is a picture from art/intro/ (docs/intro_prompts.md) and:
##   s            how long it holds, in seconds
##   zoom         [start, end]; 1.0 shows the whole picture. A pan needs a zoom above 1, or there is nothing to pan across.
##   focus        [start, end], the point the camera looks at, 0..1 across the picture
##   fog          "", "thin" or "thick"; the layer drifts sideways along the bottom of the screen
##   rain         true for the falling rain layer; rain_rect limits it to part of the screen (a sky seen through an arch)
##   bolts        lightning: [{"at": seconds into the shot, "bolt": 1..3, "x": left edge of the bolt}]; each flashes and thunders
##   clip         the part of the screen a bolt may show in, so it stays in the sky and behind the figures
##   glow         true to pulse art/intro/fx/<art>_glow.png (gen_intro.py GLOWS: the glowing pixels of that shot)
##
## Any zoom but 1.0 makes the art's pixels slightly uneven, so the zooms are small and slow: raise them with care.

const Settings := preload("res://scripts/settings.gd")

const MENU_SCENE := "res://scenes/main_menu.tscn"
const ART := "res://art/intro/%s.png"
const FX := "res://art/intro/fx/%s.png"

const SCREEN := Vector2(640, 360)
const FADE_TIME := 0.4          # Black between shots, in and out.
const FADE_STEPS := 4.0         # The fade moves in hard steps, not smoothly.
const FOG_SPEED := {"thin": 14.0, "thick": 22.0}  # Screen pixels a second.
const FOG_Y := 180.0
const FOG_WIDTH := 640.0        # The fog art repeats every 640 pixels.
const RAIN_FRAMES := 8
const RAIN_FPS := 16.0
const THUNDER_DELAY := 0.25     # The sound comes just after the flash.
const FLASH_STRENGTH := 0.5     # How strong the flash frame starts. Reduce flashing: FLASH_REDUCED, and no flicker.
const FLASH_REDUCED := 0.12
const FLASH_TIME := 0.3
const BOLT_TIME := 0.22
const GLOW_SPEED := 2.4         # Radians a second.
const GLOW_MAX := 0.55          # The glow layer's strongest alpha. Reduce flashing: half of it, more slowly.
const GLOW_STEPS := 5.0

const SHOTS := [
	{"art": "shot_01_road", "s": 4.0, "zoom": [1.0, 1.05], "focus": [Vector2(0.5, 0.42), Vector2(0.5, 0.42)]},
	{"art": "shot_02_travellers", "s": 3.5, "zoom": [1.05, 1.0], "focus": [Vector2(0.5, 0.75), Vector2(0.5, 0.6)], "fog": "thin"},
	{"art": "shot_03_crow", "s": 3.0, "zoom": [1.04, 1.08], "focus": [Vector2(0.25, 0.3), Vector2(0.25, 0.3)]},
	{"art": "shot_04_trees", "s": 3.5, "zoom": [1.05, 1.05], "focus": [Vector2(0.35, 0.7), Vector2(0.65, 0.7)], "fog": "thick"},
	{"art": "shot_05_boots", "s": 2.5, "zoom": [1.06, 1.06], "focus": [Vector2(0.65, 0.6), Vector2(0.35, 0.6)]},
	{"art": "shot_06_ruins", "s": 3.5, "zoom": [1.0, 1.06], "focus": [Vector2(0.5, 0.45), Vector2(0.5, 0.45)], "fog": "thin"},
	{"art": "shot_07_silhouette", "s": 3.0, "zoom": [1.0, 1.03], "focus": [Vector2(0.5, 0.6), Vector2(0.5, 0.6)],
		"bolts": [{"at": 0.7, "bolt": 1, "x": 515.0}], "clip": Rect2(527, 0, 113, 270)},
	{"art": "shot_08_holy_symbol", "s": 3.0, "zoom": [1.0, 1.06], "focus": [Vector2(0.5, 0.4), Vector2(0.5, 0.4)], "glow": true},
	{"art": "shot_09_sword", "s": 3.0, "zoom": [1.05, 1.05], "focus": [Vector2(0.4, 0.5), Vector2(0.6, 0.5)], "rain": true,
		"bolts": [{"at": 1.9, "bolt": 3, "x": 430.0}], "clip": Rect2(0, 0, 640, 170)},
	{"art": "shot_10_entrance", "s": 4.0, "zoom": [1.0, 1.08], "focus": [Vector2(0.5, 0.6), Vector2(0.5, 0.6)], "fog": "thick", "rain": true, "glow": true},
	{"art": "shot_11_archway", "s": 3.5, "zoom": [1.05, 1.0], "focus": [Vector2(0.5, 0.5), Vector2(0.5, 0.5)], "fog": "thin", "rain": true,
		"bolts": [{"at": 1.2, "bolt": 2, "x": 480.0}], "clip": Rect2(500, 0, 140, 110)},
	{"art": "shot_12_tunnel", "s": 3.5, "zoom": [1.0, 1.08], "focus": [Vector2(0.5, 0.5), Vector2(0.5, 0.5)], "glow": true},
	{"art": "shot_13_inside", "s": 3.0, "zoom": [1.0, 1.05], "focus": [Vector2(0.5, 0.5), Vector2(0.5, 0.5)]},
	{"art": "shot_14_looking_out", "s": 4.0, "zoom": [1.0, 1.0], "focus": [Vector2(0.5, 0.5), Vector2(0.5, 0.5)], "rain": true,
		"rain_rect": Rect2(345, 62, 160, 225),
		"bolts": [{"at": 1.0, "bolt": 1, "x": 320.0}, {"at": 2.6, "bolt": 2, "x": 335.0}], "clip": Rect2(345, 62, 160, 170)},
]

var index := -1        # The shot on screen.
var time := 0.0        # Seconds into it.
var fired := []        # Which of this shot's bolts have gone off.
var finished := false  # True once it is leaving for the menu.
var bolt_left := 0.0
var flash_left := 0.0
var flash_from := 0.0

var picture: TextureRect
var fog_layer: TextureRect
var rain_layer: TextureRect
var glow: TextureRect
var bolt_clip: Control
var bolt: TextureRect
var flash: TextureRect
var fade: ColorRect
var fog_textures := {}
var rain_textures: Array[Texture2D] = []
var bolt_textures := {}


func _ready() -> void:
	Settings.apply()
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	var back := ColorRect.new()
	back.color = Color("0b0a10")  # Palette ink.
	back.size = SCREEN
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(back)
	picture = _layer(null, SCREEN)
	for name_ in ["thin", "thick"]:
		fog_textures[name_] = load(FX % ("fog_" + name_))
	for i in RAIN_FRAMES:
		rain_textures.append(load(FX % ("rain_%d" % i)))
	for i in [1, 2, 3]:
		bolt_textures[i] = load(FX % ("lightning_%d" % i))
	glow = _layer(null, SCREEN)
	var glow_material := CanvasItemMaterial.new()
	glow_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow.material = glow_material
	bolt_clip = Control.new()
	bolt_clip.clip_contents = true
	bolt_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bolt_clip)
	bolt = _layer(null, Vector2(200, 320))
	bolt.reparent(bolt_clip, false)
	bolt.visible = false
	fog_layer = _layer(null, Vector2(FOG_WIDTH * 2.0, 180.0))
	fog_layer.stretch_mode = TextureRect.STRETCH_TILE
	fog_layer.position.y = FOG_Y
	rain_layer = _layer(rain_textures[0], SCREEN)
	rain_layer.stretch_mode = TextureRect.STRETCH_TILE
	flash = _layer(load(FX % "flash"), SCREEN)
	flash.visible = false
	fade = ColorRect.new()
	fade.color = Color("0b0a10")
	fade.size = SCREEN
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fade)
	_show_shot(0)


func _layer(texture: Texture2D, size_: Vector2) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = texture
	rect.size = size_
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rect)
	return rect


func _process(delta: float) -> void:
	if finished:
		return
	time += delta
	var shot: Dictionary = SHOTS[index]
	if time >= shot.s:
		if index + 1 >= SHOTS.size():
			leave()
		else:
			_show_shot(index + 1)
		return
	_update_camera(shot)
	_update_fade(shot)
	_update_layers(shot, delta)
	_update_lightning(shot, delta)


func _show_shot(i: int) -> void:
	index = i
	time = 0.0
	var shot: Dictionary = SHOTS[i]
	fired = []
	bolt_left = 0.0
	flash_left = 0.0
	bolt.visible = false
	flash.visible = false
	var path: String = ART % shot.art
	picture.texture = load(path) if ResourceLoader.exists(path) else null
	var fog_name: String = shot.get("fog", "")
	fog_layer.visible = fog_name != ""
	if fog_name != "":
		fog_layer.texture = fog_textures[fog_name]
	rain_layer.visible = shot.get("rain", false)
	var rain_rect: Rect2 = shot.get("rain_rect", Rect2(Vector2.ZERO, SCREEN))
	rain_layer.position = rain_rect.position
	rain_layer.size = rain_rect.size
	var clip: Rect2 = shot.get("clip", Rect2(Vector2.ZERO, SCREEN))
	bolt_clip.position = clip.position
	bolt_clip.size = clip.size
	var glow_path: String = FX % (shot.art + "_glow")
	glow.visible = shot.get("glow", false) and ResourceLoader.exists(glow_path)
	if glow.visible:
		glow.texture = load(glow_path)
	_update_camera(shot)
	_update_fade(shot)
	_update_layers(shot, 0.0)


## Scale the picture round its focus point, always keeping the screen covered. Positions are whole pixels, so a slow pan
## moves in single-pixel steps instead of smearing.
func _update_camera(shot: Dictionary) -> void:
	var t := clampf(time / shot.s, 0.0, 1.0)
	var zoom := lerpf(shot.zoom[0], shot.zoom[1], t)
	var focus: Vector2 = shot.focus[0].lerp(shot.focus[1], t)
	picture.scale = Vector2(zoom, zoom)
	var spare := SCREEN * (zoom - 1.0)
	picture.position = (-spare * focus).round()
	glow.scale = picture.scale
	glow.position = picture.position


func _update_fade(shot: Dictionary) -> void:
	var edge := minf(time, shot.s - time) / FADE_TIME
	var dark := 1.0 - clampf(edge, 0.0, 1.0)
	fade.color.a = ceilf(dark * FADE_STEPS) / FADE_STEPS


func _update_layers(shot: Dictionary, _delta: float) -> void:
	if glow.visible:
		var speed := GLOW_SPEED * (0.5 if Settings.reduce_flashing else 1.0)
		var strength := GLOW_MAX * (0.5 if Settings.reduce_flashing else 1.0)
		var wave := 0.5 + 0.5 * sin(time * speed)
		glow.modulate.a = round(wave * GLOW_STEPS) / GLOW_STEPS * strength
	if fog_layer.visible:
		var speed: float = FOG_SPEED[shot.fog]
		var total_time := float(Time.get_ticks_msec()) / 1000.0  # It keeps drifting across cuts.
		fog_layer.position.x = -round(fposmod(total_time * speed, FOG_WIDTH))
	if rain_layer.visible:
		var frame := int(float(Time.get_ticks_msec()) / 1000.0 * RAIN_FPS) % RAIN_FRAMES
		rain_layer.texture = rain_textures[frame]


func _update_lightning(shot: Dictionary, delta: float) -> void:
	var bolts: Array = shot.get("bolts", [])
	for i in bolts.size():
		if i not in fired and time >= bolts[i].at:
			fired.append(i)
			strike(bolts[i])
	if bolt_left > 0.0:
		bolt_left -= delta
		# A flicker: dark for a moment in the middle. Reduce flashing holds it steady.
		bolt.visible = bolt_left > 0.0 and (Settings.reduce_flashing or absf(bolt_left - BOLT_TIME * 0.5) > 0.03)
	if flash_left > 0.0:
		flash_left -= delta
		var left := maxf(flash_left, 0.0) / FLASH_TIME
		flash.visible = flash_left > 0.0
		flash.modulate.a = ceilf(left * 3.0) / 3.0 * flash_from


## One lightning strike: the bolt, the flash over the whole screen, and thunder just after.
func strike(event: Dictionary) -> void:
	bolt.texture = bolt_textures[int(event.bolt)]
	bolt.position = Vector2(event.x, 0.0) - bolt_clip.position
	bolt.visible = true
	bolt_left = BOLT_TIME
	flash_from = FLASH_REDUCED if Settings.reduce_flashing else FLASH_STRENGTH
	flash_left = FLASH_TIME
	flash.modulate.a = flash_from
	flash.visible = true
	get_tree().create_timer(THUNDER_DELAY).timeout.connect(_thunder)


func _thunder() -> void:
	if is_inside_tree():
		get_tree().call_group("audio", "play", "thunder")


func _input(event: InputEvent) -> void:
	if finished or not _is_skip(event):
		return
	get_viewport().set_input_as_handled()
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


## Off to the main menu, skipped or finished.
func leave() -> void:
	if finished:
		return
	finished = true
	get_tree().change_scene_to_file.call_deferred(MENU_SCENE)
