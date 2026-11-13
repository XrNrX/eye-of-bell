extends CanvasLayer
## What a monster's landed blow leaves across the 3D view, with the red flash: claw rakes, an axe slash, a slime splat. Each
## monster names its own (MonsterDef.hit_effect, a sheet in art/spells/hit_fx/, made with PixelLab's VFX tool); one with none
## gets only the red flash. Heard through Party.monster_struck; delete this node and the effects just stop. Sits above the view
## and under the frame (layer 2, like the direction glow) and takes no clicks. Settings: "Hit effects" group of
## data/combat_feel.tres.
##
## Placement follows the side the blow came from: centred for the front, towards that edge for the left or right, low for behind
## (matching the direction glow). A crit plays bigger and holds its strongest frame a moment longer. Reduce flashing plays it
## smaller and quicker. Frames step (no alpha fades), like every effect in the game.

const FeelConfig := preload("res://scripts/combat_feel_config.gd")
const Settings := preload("res://scripts/settings.gd")
const UiLayout := preload("res://scripts/ui_layout.gd")
const SHEET_DIR := "res://art/spells/hit_fx/%s_sheet"

var cfg: Resource = FeelConfig.get_config()
var canvas: Control
var playing := []   # [{sprite, frames, fps, t, hold_at, hold}]: effects on screen (tests read it)
var _sheets := {}   # name -> {texture, frames, fps} or {} when missing


func _ready() -> void:
	layer = 2
	add_to_group("hit_overlay")
	canvas = Control.new()
	canvas.position = UiLayout.VIEW.position
	canvas.size = UiLayout.VIEW.size
	canvas.clip_contents = true
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(canvas)
	call_deferred("_listen")


func _listen() -> void:
	var party := get_tree().get_first_node_in_group("party")
	if party != null and party.has_signal("monster_struck"):
		party.monster_struck.connect(_on_struck)


func _on_struck(monster: Node, side: String, _damage: int, crit: bool) -> void:
	if monster != null and is_instance_valid(monster) and monster.def.hit_effect != "":
		play(monster.def.hit_effect, side, crit)


## Play a hit effect by sheet name ("skeleton_claws") from a side ("front", "left", "right", "behind"). Returns whether it played.
func play(effect: String, side := "front", crit := false) -> bool:
	if not cfg.hit_fx_enabled:
		return false
	var sheet := _sheet(effect)
	if sheet.is_empty():
		return false
	var calm: bool = Settings.reduce_flashing
	var scale_by: float = cfg.hit_fx_scale * (cfg.hit_fx_crit_scale if crit else 1.0) * (cfg.hit_fx_reduced_scale if calm else 1.0)
	var sprite := Sprite2D.new()
	sprite.texture = sheet.texture
	sprite.hframes = sheet.frames
	sprite.frame = 0
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.scale = Vector2(scale_by, scale_by)
	sprite.position = canvas.size / 2.0 + _offset(side)
	if side == "right":
		sprite.flip_h = true  # Raked from the other side.
	canvas.add_child(sprite)
	var peak := int(sheet.frames * 0.4)  # Roughly the fullest frame: where a crit lingers.
	playing.append({"sprite": sprite, "frames": sheet.frames, "fps": sheet.fps * (cfg.hit_fx_reduced_speed if calm else 1.0),
			"t": 0.0, "hold_at": peak, "hold": cfg.hit_fx_crit_hold if crit and not calm else 0.0})
	return true


func _offset(side: String) -> Vector2:
	match side:
		"left":
			return Vector2(-cfg.hit_fx_side_offset, 0)
		"right":
			return Vector2(cfg.hit_fx_side_offset, 0)
		"behind":
			return Vector2(0, cfg.hit_fx_behind_offset)
	return Vector2.ZERO


func _process(delta: float) -> void:
	var real: float = delta / maxf(Engine.time_scale, 0.001)  # Real time, so the hit pause doesn't freeze it.
	for p in playing.duplicate():
		p.t += real
		var i := int(p.t * p.fps)
		if p.hold > 0.0 and i >= p.hold_at:  # A crit holds its strongest frame for a moment.
			p.hold -= real
			p.t = float(p.hold_at) / p.fps
			i = p.hold_at
		if i >= p.frames:
			p.sprite.queue_free()
			playing.erase(p)
			continue
		p.sprite.frame = i


func _sheet(effect: String) -> Dictionary:
	if _sheets.has(effect):
		return _sheets[effect]
	var png := (SHEET_DIR % effect) + ".png"
	var json_path := (SHEET_DIR % effect) + ".json"
	var entry := {}
	if ResourceLoader.exists(png) and FileAccess.file_exists(json_path):
		var info = JSON.parse_string(FileAccess.get_file_as_string(json_path))
		if info is Dictionary:
			entry = {"texture": load(png), "frames": int(info.frames), "fps": float(info.fps)}
	_sheets[effect] = entry
	return entry
