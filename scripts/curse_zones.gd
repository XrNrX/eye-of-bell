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
## THE HAZE: a thin green PixelLab VFX flipbook (art/spells/curse/haze_sheet.png) laid flat, additive, over every tile of a zone in force,
## unshaded so it shows from far down the corridor, and a little wider than the tile so it reaches the one before. It is hidden in a pocket.
## Reduce flashing holds one still frame.
## GameEvents.entered_curse_zone / left_curse_zone are sent as the party's tile crosses a zone's edge (never while a save loads).

const DungeonMap := preload("res://scripts/dungeon_map.gd")
const Events := preload("res://scripts/game_events.gd")
const LightConfig := preload("res://scripts/light_config.gd")
const Settings := preload("res://scripts/settings.gd")

const HAZE_SHEET := "res://art/spells/curse/haze_sheet"  # .png and .json

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
var _haze: Array = []          # [{"mesh": MeshInstance3D, "cell": Vector2i}]
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
	_show_haze()


## A zone was lifted (or put back): redraw the haze.
func zones_changed() -> void:
	_build_haze()


## Take the party's tile as it is, with no news (a save was just loaded).
func sync_silently() -> void:
	current_zone = DungeonMap.curse_zone_at(DungeonMap.player_cell)
	sputter_left = -1.0
	_synced = true


## A flame went out where it lay (called by LightField.drop for a torch thrown or dropped into a zone): the message if the party sees it.
func flame_died(cell: Vector2i) -> void:
	flames_died += 1
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
		if pocket_left == 0.0:
			_show_haze()
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
			if _sees(Vector2i(key.x, key.y)):
				_announce(DungeonMap.curse_zone_near(Vector2i(key.x, key.y), cfg.sconce_reach), "")
	for a in dungeon.alcoves:  # The candle in a wall niche goes out, and is lit again when the zone is lifted or a pocket covers it.
		var out := blocks_sconce(a.cell)
		if a.lit == out:
			dungeon.set_alcove_lit(a, not out)
			if out:
				flames_died += 1
				if _sees(a.cell):
					_announce(DungeonMap.curse_zone_near(a.cell, cfg.sconce_reach), "")
	var lights: Node = dungeon.get("lights")
	if lights != null:
		for e in lights.burning.duplicate():
			if blocks_sconce(e.cell):
				lights.snuff(e)
				flames_died += 1
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


# --- The haze ------------------------------------------------------------------------------------------------------------

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
		mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		mat.albedo_texture = tex
		mat.albedo_color = Color(1, 1, 1, cfg.haze_alpha)
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		mat.uv1_scale = Vector3(1.0 / _frames, 1, 1)
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		_haze_mats.append(mat)
	_set_frame(0)


## One or two flat patches of haze on each tile of every zone in force (a zone that was cleared has none).
func _build_haze() -> void:
	for h in _haze:
		h.mesh.queue_free()
	_haze.clear()
	if _haze_mats.is_empty():
		return
	var tile := DungeonMap.TILE_SIZE
	var depth: float = cfg.haze_width * 75.0 / 162.0  # The art's own shape (162 x 75).
	for zone in DungeonMap.CURSE_ZONES:
		if DungeonMap.zone_cleared(zone.id):
			continue
		for cell in zone.tiles:
			for k in 2:
				var plane := PlaneMesh.new()
				plane.size = Vector2(cfg.haze_width, depth)
				var node := MeshInstance3D.new()
				node.mesh = plane
				node.material_override = _haze_mats[(cell.x + cell.y + k) % 2]
				node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				node.position = DungeonMap.cell_to_world(cell) + Vector3(0, cfg.haze_height + 0.003 * k, 0)
				node.rotation.y = PI / 2.0 if k == 1 else 0.0  # One patch long in x, one long in z: the haze fills the tile.
				add_child(node)
				_haze.append({"mesh": node, "cell": cell})
	_show_haze()


## Hide the haze over a pocket (flames live there), show it everywhere else.
func _show_haze() -> void:
	for h in _haze:
		h.mesh.visible = not pocketed(h.cell)


func _animate_haze(delta: float) -> void:
	if _haze_mats.is_empty() or _haze.is_empty():
		return
	if Settings.reduce_flashing:
		_set_frame(0)
		return
	_frame_time += delta
	_set_frame(int(_frame_time * _fps))


func _set_frame(i: int) -> void:
	for k in _haze_mats.size():
		var f := (i + k * (_frames / 2)) % _frames
		_haze_mats[k].uv1_offset = Vector3(float(f) / _frames, 0, 0)
