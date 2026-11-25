extends Node3D
## Curse zones: places where flames die (docs/design/expansion_design.md section 3, roadmap 7l.3). A node in the dungeon ("CurseZones", made
## by dungeon_builder.gd, group "curse_zones"); the zones themselves are data (DungeonMap.CURSE_ZONES), lifted for good by a puzzle effect
## (clear_curse_zone: the run flag "curse_zone.<id>.cleared", saved). Numbers: data/light.tres "Curse zones".
##
## INSIDE A ZONE (and outside a Bless's pocket):
##   * a torch or candle a hero holds sputters for `zone_sputter_seconds` (the party's light flickers hard) and goes out: no light, no
##     burning (Party.flames_out; Party.held_lights skips it). It relights by itself the moment the party leaves, or a pocket opens;
##     put away and taken up again inside it sputters again. A light with ItemDef.curse_proof (the Unquenchable) is never touched;
##     spell light is not a flame and is not touched either.
##   * a sconce will not light (Dungeon.light_sconce refuses; a torch hung in a bare bracket stays unlit), a lit one goes out, and this
##     reaches `sconce_reach` (2) tiles past the zone's tiles, as far as the haze looks (blocks_sconce), and so do the other lights fixed
##     in the world: the candle in a wall niche goes out (its picture swaps to one without a flame) and a burning
##     light lying on the floor (or thrown there: LightField.drop) goes out and can be picked up cold. Braziers (not built yet) ask
##     Dungeon.light_blocked(cell), oil Dungeon.flame_blocked(cell) (the zone's own tiles).
##   * nothing is said until a flame dies: "The air here hates fire." (and a banter remark, event "flames_snuffed").
## A BLESS makes a POCKET: for SpellDef.pocket_seconds (20) the tile the party stood on and the tiles within `zone_pocket_radius` of it are
## free of the zone: flames light and live there. When it ends, whatever still burns inside goes out as above. (Not saved.)
## THE FOG (it eats light; it is not a gas): murky, darker-than-toxic curse green (PixelLab VFX art/spells/curse/fog_sheet.png) laid flat
## over every tile of a zone in force with NORMAL blending (so it darkens the floor as well as tinting it), unshaded so it shows from far
## down the corridor, two patches a tile (`_haze`). It CREEPS IN FROM THE ZONE'S EDGES (`creep`: the tiles beside open floor fill first,
## the middle last), swells round the party while a held flame sputters, and a flame that dies in the world leaves a wisp of fog curling
## up (art/spells/curse/wisp_sheet.png). A BLESS pushes it back: on the pocket's tiles it shrinks and slides away from the centre in
## `fog_recoil_seconds`, and creeps back over the last `pocket_warn_seconds` of the pocket (`fog_pocket`, 0 recoiled .. 1 in force).
## THE EDGE GLOW: `vignette` (0..1) is what the screen-edge vignette (curse_vignette.gd) shows: it creeps in slowly while the party stands
## in the zone, thickens the longer it stays in the dark (`dark_time`), pulls back when a Bless opens a pocket, creeps back in the pocket's
## last seconds as a warning, and fades on leaving. Reduce flashing holds one still fog frame and the glow does not pulse.
## GameEvents.entered_curse_zone / left_curse_zone are sent as the party's tile crosses a zone's edge (never while a save loads).

const DungeonMap := preload("res://scripts/dungeon_map.gd")
const Events := preload("res://scripts/game_events.gd")
const LightConfig := preload("res://scripts/light_config.gd")
const Settings := preload("res://scripts/settings.gd")

const HAZE_SHEET := "res://art/spells/curse/fog_sheet"  # .png and .json
const WISP_SHEET := "res://art/spells/curse/wisp_sheet"

var cfg: Resource = LightConfig.get_config()
var dungeon: Node
var party: Node
var current_zone := ""         # The zone the party stands in ("" for none): for the entered / left news.
var pocket_cell := Vector2i(-999, -999)
var pocket_left := 0.0
var sputter_left := -1.0       # Seconds the party's flames have left to sputter (-1: not sputtering).
var flames_died := 0           # Flames put out so far (tests read this).
var _synced := false
var _last_message := -99.0
var _clock := 0.0
var vignette := 0.0            # What the screen-edge glow shows now (0..1, before the pulse): curse_vignette.gd reads it.
var dark_time := 0.0           # Seconds the party has stood in a zone with no pocket (the glow thickens with it).
var fog_pocket := 1.0          # 1: the fog is in force on a pocket's tiles; 0: recoiled from them.
var creep := 1.0               # How far the fog has crept in from the zone's edges (0..1).
var _max_depth := 0
var _depth := {}               # zone tile -> how many tiles in from the zone's edge it is (0 = the edge)
var _wisps: Array = []         # [{"node": Sprite3D, "t": float}]
var _wisp_tex: Texture2D
var _wisp_frames := 1
var _wisp_fps := 10.0
var _haze: Array = []          # [{"mesh": MeshInstance3D, "cell": Vector2i, "base": Vector3}]
var _haze_mats: Array = []     # Two materials, half a loop apart.
var _frames := 1
var _fps := 12.0
var _frame_time := 0.0


func _ready() -> void:
	add_to_group("curse_zones")
	dungeon = get_parent()
	_load_haze()
	_build_haze()


# --- Questions ---------------------------------------------------------------------------------------------------------

## Is this tile inside a Bless's pocket right now?
func pocketed(cell: Vector2i) -> bool:
	if pocket_left <= 0.0:
		return false
	var d := (cell - pocket_cell).abs()
	return maxi(d.x, d.y) <= cfg.zone_pocket_radius


## Does a curse zone put out flames on this tile now? (In force, and no pocket covers it.)
func blocks_flame(cell: Vector2i) -> bool:
	return DungeonMap.curse_zone_at(cell) != "" and not pocketed(cell)


## The same for a wall sconce on this tile: it reaches `sconce_reach` (2) tiles past the zone, as far as the haze looks to, so the wall torches
## along the edge go dark too. (A Bless's pocket still covers it.)
func blocks_sconce(cell: Vector2i) -> bool:
	return DungeonMap.curse_zone_near(cell, cfg.sconce_reach) != "" and not pocketed(cell)


# --- Commands ------------------------------------------------------------------------------------------------------------

## A Bless was cast on this tile: flames live around it for `seconds`.
func open_pocket(cell: Vector2i, seconds: float) -> void:
	pocket_cell = cell
	pocket_left = maxf(pocket_left, seconds)
	_update_fog()


## A zone was lifted (or put back): redraw the haze.
func zones_changed() -> void:
	creep = 0.0
	_build_haze()


## Take the party's tile as it is, with no news (a save was just loaded).
func sync_silently() -> void:
	current_zone = DungeonMap.curse_zone_at(DungeonMap.player_cell)
	sputter_left = -1.0
	creep = 1.0  # (A loaded game finds the fog already in.)
	_synced = true


## A flame went out where it lay (called by LightField.drop for a torch thrown or dropped into a zone): the message if the party sees it.
func flame_died(cell: Vector2i) -> void:
	flames_died += 1
	_wisp(DungeonMap.cell_to_world(cell) + Vector3(0, 0.3, 0))
	if _sees(cell):
		_announce(DungeonMap.curse_zone_at(cell), "")


# --- Each frame ----------------------------------------------------------------------------------------------------------

func _process(delta: float) -> void:
	_clock += delta
	if party == null or not is_instance_valid(party):
		party = get_tree().get_first_node_in_group("party")
	var pocket_was_open := pocket_left > 0.0
	if pocket_left > 0.0:
		pocket_left = maxf(0.0, pocket_left - delta)
	var cell: Vector2i = DungeonMap.player_cell
	var zone := DungeonMap.curse_zone_at(cell)
	if zone != current_zone:
		if _synced:  # (The first frame only takes the tile: starting in a zone is not news.)
			if current_zone != "":
				Events.send(get_tree(), "left_curse_zone", [current_zone])
			if zone != "":
				Events.send(get_tree(), "entered_curse_zone", [zone])
		current_zone = zone
	_synced = true
	_party_flames(zone != "" and not pocketed(cell), delta)
	if dungeon != null and dungeon.get("sconces") != null:
		_floor_flames()
	_tick_glow(delta, zone != "", pocketed(cell))
	_animate_haze(delta)
	if pocket_was_open and pocket_left == 0.0:
		_floor_flames()


## The party's held flames: sputter and go out in a zone, relight outside it (or in a pocket).
func _party_flames(out_wanted: bool, delta: float) -> void:
	if party == null:
		return
	if not out_wanted or not party.carries_flame():
		sputter_left = -1.0
		party.sputter_left = 0.0
		party.set_flames_out(false)
		return
	if party.flames_out:
		return
	if sputter_left < 0.0:
		sputter_left = cfg.zone_sputter_seconds
	sputter_left -= delta
	party.sputter_left = maxf(sputter_left, 0.0001)
	if sputter_left <= 0.0:
		sputter_left = -1.0
		party.sputter_left = 0.0
		party.set_flames_out(true)
		flames_died += 1
		_announce(DungeonMap.curse_zone_at(DungeonMap.player_cell), "held")


## Lit sconces and burning lights lying on the floor that a zone now covers go out.
func _floor_flames() -> void:
	for key in dungeon.sconces.keys():
		if dungeon.sconce_at(key) == DungeonMap.SCONCE_LIT and blocks_sconce(Vector2i(key.x, key.y)):
			dungeon.snuff_sconce(key)
			flames_died += 1
			_wisp(DungeonMap.cell_to_world(Vector2i(key.x, key.y)) + Vector3(0, 1.1, 0))
			if _sees(Vector2i(key.x, key.y)):
				_announce(DungeonMap.curse_zone_near(Vector2i(key.x, key.y), cfg.sconce_reach), "")
	for a in dungeon.alcoves:  # The candle in a wall niche goes out, and is lit again when the zone is lifted or a pocket covers it.
		var out := blocks_sconce(a.cell)
		if a.lit == out:
			dungeon.set_alcove_lit(a, not out)
			if out:
				flames_died += 1
				_wisp(DungeonMap.cell_to_world(a.cell) + Vector3(0, 0.9, 0))
				if _sees(a.cell):
					_announce(DungeonMap.curse_zone_near(a.cell, cfg.sconce_reach), "")
	for cell in DungeonMap.brazier_lit.keys():  # A burning brazier inside a zone goes out (it needs lighting again afterwards).
		if DungeonMap.brazier_lit[cell] and blocks_flame(cell):
			dungeon.set_brazier(cell, false)
			flames_died += 1
			_wisp(DungeonMap.cell_to_world(cell) + Vector3(0, 0.5, 0))
			if _sees(cell):
				_announce(DungeonMap.curse_zone_at(cell), "")
	var lights: Node = dungeon.get("lights")
	if lights != null:
		for e in lights.burning.duplicate():
			if blocks_sconce(e.cell):
				lights.snuff(e)
				flames_died += 1
				_wisp(DungeonMap.cell_to_world(e.cell) + Vector3(0, 0.3, 0))
				if _sees(e.cell):
					_announce(DungeonMap.curse_zone_at(e.cell), "")


func _sees(cell: Vector2i) -> bool:
	var from: Vector2i = DungeonMap.player_cell
	var d := (cell - from).abs()
	return maxi(d.x, d.y) <= cfg.haze_see_range and (cell == from or DungeonMap.has_line_of_sight(from, cell))


## The one line about it, and a remark: when a flame dies. Not more than once every couple of seconds.
func _announce(zone: String, _what: String) -> void:
	if _clock - _last_message < 2.0:
		return
	_last_message = _clock
	get_tree().call_group("hud", "show_message", "The air here hates fire.")
	get_tree().call_group_flags(SceneTree.GROUP_CALL_DEFERRED, "banter", "event", "flames_snuffed", {"zone": zone})


# --- The glow at the screen's edge -------------------------------------------------------------------------------------

## Moves `vignette`: in slowly in the dark (thicker the longer the party stays), back fast when a pocket opens, back in over the pocket's
## last seconds, out when the party leaves.
func _tick_glow(delta: float, in_zone: bool, in_pocket: bool) -> void:
	var target := 0.0
	var rate: float = 1.0 / maxf(cfg.vignette_out_seconds, 0.05)
	if in_zone and not in_pocket:
		dark_time += delta
		target = lerpf(cfg.vignette_min, 1.0, clampf(dark_time / maxf(cfg.vignette_full_seconds, 0.1), 0.0, 1.0))
		rate = 1.0 / maxf(cfg.vignette_in_seconds, 0.05)
	else:
		dark_time = maxf(0.0, dark_time - delta * 2.0)
		if in_zone and in_pocket:  # The pocket pushes it back, and it creeps in again as a warning.
			var warn: float = cfg.pocket_warn_seconds
			target = cfg.vignette_warn * (1.0 - clampf(pocket_left / maxf(warn, 0.1), 0.0, 1.0)) if pocket_left <= warn else 0.0
			rate = 1.0 / maxf(cfg.vignette_pull_seconds, 0.05) if target < vignette else 1.0 / maxf(cfg.vignette_in_seconds, 0.05)
	vignette = move_toward(vignette, target, rate * delta)
	if not cfg.vignette_enabled:
		vignette = 0.0


## What the screen shows: `vignette` breathing slowly (it dips by up to `vignette_pulse` and comes back, so full strength is the peak; steady
## at that peak with Reduce flashing).
func glow_level() -> float:
	if vignette <= 0.0:
		return 0.0
	if Settings.reduce_flashing:
		return vignette
	return clampf(vignette * (1.0 - cfg.vignette_pulse * (0.5 + 0.5 * sin(_clock * TAU * cfg.vignette_pulse_hz))), 0.0, 1.0)


# --- The fog ---------------------------------------------------------------------------------------------------------------

func _load_haze() -> void:
	if not ResourceLoader.exists(HAZE_SHEET + ".png"):
		return
	var info = JSON.parse_string(FileAccess.get_file_as_string(HAZE_SHEET + ".json"))
	if info is Dictionary:
		_frames = maxi(1, int(info.get("frames", 1)))
		_fps = float(info.get("fps", 12.0))
	var tex: Texture2D = load(HAZE_SHEET + ".png")
	for i in 2:
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_texture = tex
		mat.albedo_color = Color(1, 1, 1, cfg.fog_alpha)
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		mat.uv1_scale = Vector3(1.0 / _frames, 1, 1)
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		_haze_mats.append(mat)
	_set_frame(0)
	if ResourceLoader.exists(WISP_SHEET + ".png"):
		var winfo = JSON.parse_string(FileAccess.get_file_as_string(WISP_SHEET + ".json"))
		if winfo is Dictionary:
			_wisp_frames = maxi(1, int(winfo.get("frames", 1)))
			_wisp_fps = float(winfo.get("fps", 10.0))
		_wisp_tex = load(WISP_SHEET + ".png")


## One or two flat patches of fog on each tile of every zone in force (a zone that was cleared has none).
func _build_haze() -> void:
	for h in _haze:
		h.mesh.queue_free()
	_haze.clear()
	_depth.clear()
	_max_depth = 0
	if _haze_mats.is_empty():
		return
	var tile := DungeonMap.TILE_SIZE
	var depth: float = cfg.fog_width * 42.0 / 128.0  # The art's own shape (128 x 42).
	for zone in DungeonMap.CURSE_ZONES:
		if DungeonMap.zone_cleared(zone.id):
			continue
		for cell in zone.tiles:
			_depth[cell] = _depth_of(cell, zone.tiles)
			_max_depth = maxi(_max_depth, _depth[cell])
			for k in 2:
				var plane := PlaneMesh.new()
				plane.size = Vector2(cfg.fog_width, depth)
				var node := MeshInstance3D.new()
				node.mesh = plane
				node.material_override = _haze_mats[(cell.x + cell.y + k) % 2]
				node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				var base := DungeonMap.cell_to_world(cell) + Vector3(0, cfg.fog_height + 0.003 * k, 0)
				node.position = base
				node.rotation.y = PI / 2.0 if k == 1 else 0.0  # One patch long in x, one long in z: the fog fills the tile.
				add_child(node)
				_haze.append({"mesh": node, "cell": cell, "base": base})
	_update_fog()


## How many tiles in from the zone's edge a tile is: 0 for one beside open floor that is not in the zone.
func _depth_of(cell: Vector2i, tiles: Array) -> int:
	for k in range(0, 4):
		for dx in range(-(k + 1), k + 2):
			for dy in range(-(k + 1), k + 2):
				if maxi(absi(dx), absi(dy)) != k + 1:
					continue
				var c := cell + Vector2i(dx, dy)
				if not tiles.has(c) and not DungeonMap.is_wall(c):
					return k
	return 4


## Where the fog is thick, thin, shrunk or pushed back, now: the creep from the edges, a pocket's recoil, the swell round a sputtering flame.
func _update_fog() -> void:
	var swell := 0.0
	if party != null and sputter_left > 0.0:
		swell = cfg.fog_thicken * (1.0 - clampf(sputter_left / maxf(cfg.zone_sputter_seconds, 0.1), 0.0, 1.0))
	var me: Vector2i = DungeonMap.player_cell
	for h in _haze:
		var cell: Vector2i = h.cell
		var amount := clampf(creep * (_max_depth + 1.0) - float(_depth.get(cell, 0)), 0.0, 1.0)
		var push := Vector3.ZERO
		if _in_pocket_region(cell):
			amount = minf(amount, fog_pocket)
			var away := Vector3(cell.x - pocket_cell.x, 0, cell.y - pocket_cell.y)
			if away.length() > 0.0:
				push = away.normalized() * cfg.fog_push * (1.0 - fog_pocket)
		var d := (cell - me).abs()
		var size := amount * (1.0 + (swell if maxi(d.x, d.y) <= 1 else 0.0))
		h.mesh.visible = size > 0.04
		h.mesh.scale = Vector3(maxf(size, 0.01), 1, maxf(size, 0.01))
		h.mesh.position = h.base + push


## Is this tile in the area a Bless's pocket covers (while it lasts, and while the fog is still on its way back)?
func _in_pocket_region(cell: Vector2i) -> bool:
	if pocket_left <= 0.0 and fog_pocket >= 1.0:
		return false
	var d := (cell - pocket_cell).abs()
	return maxi(d.x, d.y) <= cfg.zone_pocket_radius


func _animate_haze(delta: float) -> void:
	if _haze_mats.is_empty() or _haze.is_empty():
		_tick_wisps(delta)
		return
	var warn: float = cfg.pocket_warn_seconds
	var want := 1.0
	if pocket_left > warn:
		want = 0.0
	elif pocket_left > 0.0:
		want = 1.0 - pocket_left / maxf(warn, 0.1)
	if want < fog_pocket:
		fog_pocket = move_toward(fog_pocket, want, delta / maxf(cfg.fog_recoil_seconds, 0.05))
	else:
		fog_pocket = move_toward(fog_pocket, want, delta / maxf(cfg.fog_return_seconds, 0.05))
	if creep < 1.0:
		creep = minf(1.0, creep + delta / maxf(cfg.fog_creep_seconds, 0.1))
	_update_fog()
	_tick_wisps(delta)
	if Settings.reduce_flashing:
		_set_frame(0)
		return
	_frame_time += delta
	_set_frame(int(_frame_time * _fps))


func _set_frame(i: int) -> void:
	for k in _haze_mats.size():
		var f := (i + k * (_frames / 2)) % _frames
		_haze_mats[k].uv1_offset = Vector3(float(f) / _frames, 0, 0)


## Kept for the older name: redraw the fog.
func _show_haze() -> void:
	_update_fog()


# --- Wisps: a flame that dies here leaves fog curling up -----------------------------------------------------------------

func _wisp(world: Vector3) -> void:
	if _wisp_tex == null or cfg.wisp_seconds <= 0.0:
		return
	var s := Sprite3D.new()
	s.texture = _wisp_tex
	s.hframes = _wisp_frames
	s.pixel_size = cfg.wisp_size / 44.0
	s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	s.shaded = false
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	s.transparent = true
	s.position = world + Vector3(0, cfg.wisp_size * 0.5, 0)
	add_child(s)
	_wisps.append({"node": s, "t": 0.0})


func _tick_wisps(delta: float) -> void:
	for w in _wisps.duplicate():
		w.t += delta
		if w.t >= cfg.wisp_seconds:
			w.node.queue_free()
			_wisps.erase(w)
		else:
			w.node.frame = 0 if Settings.reduce_flashing else int(w.t * _wisp_fps) % _wisp_frames
			w.node.position.y += delta * 0.12
