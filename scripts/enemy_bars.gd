extends Control
## Enemy health bars, drawn inside the 3D view's SubViewport (a CanvasLayer made by game_view.gd), so
## every bar pixel is a screen pixel: integer positions, rectangles only, no smoothing.
##  - a small bar above a monster that has been hit, or is the one directly in front of the party;
##    after `hold_seconds` it dissolves in palette-pure dither steps (never an alpha fade);
##  - a slim strip at the top of the view with the name and bar of the monster in front;
##  - a wide named bar with curse-green trim for bosses and wall monsters (MonsterDef.boss / wall_monster).
## When damage lands the lost chunk flashes light, then drains (a crit drains with a small shake).
## Options: Settings.enemy_bars 0 On, 1 Boss only, 2 Off. Numbers and colours: data/enemy_bars.tres.

const DungeonMap := preload("res://scripts/dungeon_map.gd")
const Settings := preload("res://scripts/settings.gd")
const ConfigScript := preload("res://scripts/enemy_bars_config.gd")

const BAYER := [[0, 2], [3, 1]]  # 2x2 ordered-dither thresholds for the fade.
const FACING_DIRS: Array[Vector2i] = [Vector2i(0, -1), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(1, 0)]

var cfg: Resource = ConfigScript.get_config()
var now := 0.0
var states := {}  # monster instance id -> {hp_ghost, flash, rate, last_hit, crit}


func _ready() -> void:
	add_to_group("enemy_bars")
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


## Called by Monster.take_hit with the damage it just took (hp is already lowered).
func monster_hit(m: Node, damage: int, crit: bool) -> void:
	var st := _state(m)
	st.hp_ghost = maxf(st.hp_ghost, float(m.hp + damage))  # The chunk still draining joins the new one.
	st.flash = cfg.flash_seconds
	st.rate = 0.0
	st.last_hit = now
	st.crit = crit


func _state(m: Node) -> Dictionary:
	var id := m.get_instance_id()
	if not states.has(id):
		states[id] = {"hp_ghost": float(maxi(m.hp, 0)), "flash": 0.0, "rate": 0.0, "last_hit": -1000.0, "crit": false}
	return states[id]


func _process(delta: float) -> void:
	now += delta
	for id in states.keys():
		var m: Object = instance_from_id(id)
		if m == null or not is_instance_valid(m) or m.is_queued_for_deletion():
			states.erase(id)
			continue
		var st: Dictionary = states[id]
		var hp := float(maxi(m.hp, 0))
		if st.flash > 0.0:
			st.flash -= delta
		elif st.hp_ghost > hp:
			if st.rate == 0.0:
				st.rate = (st.hp_ghost - hp) / maxf(cfg.drain_seconds, 0.01)
			st.hp_ghost = maxf(hp, st.hp_ghost - st.rate * delta)
		else:
			st.hp_ghost = hp
			st.rate = 0.0
	queue_redraw()


# --------------------------------------------------------------------------
# What is shown
# --------------------------------------------------------------------------

func _is_big(m: Node) -> bool:
	return m.def.boss or m.def.wall_monster


## The monster directly in front of the party, or null.
func front_monster() -> Node:
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return null
	var m = DungeonMap.occupied.get(player.cell + FACING_DIRS[player.facing])
	if m != null and is_instance_valid(m) and m.is_in_group("monsters") and m.hp > 0:
		return m
	return null


## Fade level for a small bar: 0 full, 1..fade_steps dissolving, -1 hidden.
func fade_level(m: Node, is_front: bool) -> int:
	if is_front:
		return 0
	var st := _state(m)
	var age: float = now - st.last_hit
	if age < cfg.hold_seconds:
		return 0
	if age >= cfg.hold_seconds + cfg.fade_seconds:
		return -1
	return 1 + int((age - cfg.hold_seconds) / cfg.fade_seconds * cfg.fade_steps)


## Which monsters get a small bar, as [monster, level] farthest first. Public so tests can read it.
func visible_small_bars() -> Array:
	var out := []
	if Settings.enemy_bars != 0:
		return out
	var front := front_monster()
	for m in get_tree().get_nodes_in_group("monsters"):
		if _is_big(m) or not _can_see(m):
			continue
		var level := fade_level(m, m == front)
		if level >= 0:
			out.append([m, level])
	out.sort_custom(func(a, b): return _dist(a[0]) > _dist(b[0]))
	return out


## The boss or wall monster whose wide bar shows (the nearest one that can see the party), or null.
func boss_monster() -> Node:
	if Settings.enemy_bars == 2:
		return null
	var best: Node = null
	for m in get_tree().get_nodes_in_group("monsters"):
		if not _is_big(m) or m.hp <= 0 or not _can_see(m, cfg.boss_range):
			continue
		if best == null or _dist(m) < _dist(best):
			best = m
	return best


func _dist(m: Node) -> int:
	var d: Vector2i = m.cell - DungeonMap.player_cell
	return absi(d.x) + absi(d.y)


func _can_see(m: Node, max_tiles := -1) -> bool:
	return _dist(m) <= (max_tiles if max_tiles >= 0 else cfg.max_distance) \
			and DungeonMap.has_line_of_sight(m.cell, DungeonMap.player_cell)


# --------------------------------------------------------------------------
# Drawing
# --------------------------------------------------------------------------

func _draw() -> void:
	var camera := get_viewport().get_camera_3d()
	var k := float(get_viewport().get_meta("view_scale", 1))  # The view renders k times larger; the layer is scaled by k, so draw in logical units.
	var view := get_viewport_rect().size / k
	var boss := boss_monster()
	var top := 0
	if boss != null:
		top = _draw_boss(boss, view)
	elif Settings.enemy_bars == 0 and cfg.strip_enabled:
		var front := front_monster()
		if front != null:
			top = _draw_strip(front, view)
	if camera == null:
		return
	for entry in visible_small_bars():
		var m: Node = entry[0]
		var anchor: Vector3 = m.bar_anchor()
		if camera.is_position_behind(anchor):
			continue
		var p := camera.unproject_position(anchor) / k
		var size := Vector2i(cfg.bar_width, cfg.bar_height)
		var origin := Vector2i(floori(p.x) - size.x / 2, floori(p.y) - size.y - 1)
		origin.x = clampi(origin.x, 2, int(view.x) - size.x - 2)
		origin.y = clampi(origin.y, top + 2, int(view.y) - size.y - 2)
		_bar(origin, size, m, entry[1], cfg.frame, cfg.frame_lit)


func _draw_strip(m: Node, view: Vector2) -> int:
	var font := get_theme_default_font()
	var name_w := int(font.get_string_size(m.def.display_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x)
	var w: int = name_w + 6 + cfg.strip_bar_width + 8
	var h: int = cfg.strip_height
	var x := (int(view.x) - w) / 2
	var y: int = cfg.strip_top
	_px(Rect2i(x, y, w, h), cfg.frame, 0)
	_px(Rect2i(x + 1, y + 1, w - 2, h - 2), cfg.background, 0)
	_text(m.def.display_name, Vector2i(x + 4, y + 3 + 7))
	var bar := Vector2i(cfg.strip_bar_width, 6)
	_bar(Vector2i(x + w - bar.x - 4, y + (h - bar.y) / 2), bar, m, 0, cfg.frame, cfg.frame_lit)
	return y + h


func _draw_boss(m: Node, view: Vector2) -> int:
	var font := get_theme_default_font()
	var w: int = cfg.boss_width
	var x := (int(view.x) - w) / 2
	var y: int = cfg.boss_top
	var title: String = m.def.display_name
	var tw := int(font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x)
	_text(title, Vector2i((int(view.x) - tw) / 2, y + 7))
	var size := Vector2i(w, cfg.boss_height)
	var origin := Vector2i(x, y + 11)
	_bar(origin, size, m, 0, cfg.boss_trim, cfg.boss_trim_dark)
	return origin.y + size.y


## One bar: frame, dark background, fill, and the lost chunk. A tall bar gets a second trim line inside.
func _bar(origin: Vector2i, size: Vector2i, m: Node, level: int, outer: Color, inner: Color) -> void:
	var st := _state(m)
	var shake := Vector2i.ZERO
	if st.crit and (st.flash > 0.0 or st.hp_ghost > float(maxi(m.hp, 0))) and cfg.crit_shake_pixels > 0 \
			and not Settings.reduce_flashing:
		var k: int = cfg.crit_shake_pixels
		shake = Vector2i(randi_range(-k, k), randi_range(-k, k))
	origin += shake
	_px(Rect2i(origin, size), outer, level)
	var inside := Rect2i(origin + Vector2i(1, 1), size - Vector2i(2, 2))
	_px(inside, cfg.background, level)
	if size.y >= 7:
		_px(Rect2i(inside.position, Vector2i(inside.size.x, 1)), inner, level)
		_px(Rect2i(inside.position.x, inside.end.y - 1, inside.size.x, 1), inner, level)
		inside = inside.grow(-1)
		_px(inside, cfg.background, level)
	else:  # A thin bar: its top edge is lit.
		_px(Rect2i(origin.x + 1, origin.y, size.x - 2, 1), inner, level)
	var max_hp := float(maxi(m.def.max_hp, 1))
	var hp_w := roundi(inside.size.x * clampf(float(maxi(m.hp, 0)) / max_hp, 0.0, 1.0))
	var ghost_w := roundi(inside.size.x * clampf(st.hp_ghost / max_hp, 0.0, 1.0))
	if ghost_w > hp_w:
		var colour: Color = cfg.chunk_flash if st.flash > 0.0 else cfg.chunk_drain
		_px(Rect2i(inside.position.x + hp_w, inside.position.y, ghost_w - hp_w, inside.size.y), colour, level)
	if hp_w > 0:
		_px(Rect2i(inside.position, Vector2i(hp_w, inside.size.y)), cfg.fill, level)
		if inside.size.y >= 2:
			_px(Rect2i(inside.position.x, inside.end.y - 1, hp_w, 1), cfg.fill_shade, level)


## Draw a rectangle of one colour. At fade `level` > 0 some of its pixels are left out in an ordered
## dither, so the bar dissolves in steps that never leave the palette.
func _px(r: Rect2i, colour: Color, level: int) -> void:
	if level <= 0:
		draw_rect(Rect2(r), colour)
		return
	var keep := 4 - clampi(level, 0, 3)  # Of every 2x2 block keep 3, 2, then 1 pixels.
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			if BAYER[y & 1][x & 1] < keep:
				draw_rect(Rect2(x, y, 1, 1), colour)


func _text(s: String, baseline: Vector2i) -> void:
	var font := get_theme_default_font()
	draw_string(font, Vector2(baseline) + Vector2(1, 1), s, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, cfg.text_shadow)
	draw_string(font, Vector2(baseline), s, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, cfg.text)
