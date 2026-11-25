extends Node3D
## Oil on the floor (roadmap 7l.5; rules in docs/combat_design.md "Oil and fire", numbers in data/light.tres "Oil"): a node in the dungeon
## ("Oil", made by dungeon_builder.gd, group "oil", `Dungeon.oil`).
##
## A SLICK lies on the tile in front of a hero who threw a Flask of oil at the floor (Party._throw_oil). It lasts `slick_seconds` (120) or until
## it is lit. FIRE touching it lights it: a burning torch lying on the tile (a thrown torch landing there, a slipped one), a lit torch's swing at
## that tile (Party._melee), a Fireball's blast within a tile (spell_effects.explosion). It then BURNS for `burn_seconds` (6): flames (PixelLab VFX),
## a flickering light in the sprite_lights group, and every second 2 damage to a monster on the tile and 1 to each hero if the party stands on
## it. Monsters that fear fire will not step onto it (Dungeon.fire_at). A curse zone's air will not let it catch (Dungeon.flame_blocked).
## GameEvents.oil_ignited(cell) is sent when a slick catches. Slicks and burning tiles are saved (save_state / load_state).
## A held monster on a slick is a lit one: the bear trap combo needs nothing special.

const DungeonMap := preload("res://scripts/dungeon_map.gd")
const Events := preload("res://scripts/game_events.gd")
const LightConfig := preload("res://scripts/light_config.gd")
const TorchLight := preload("res://scripts/torch.gd")
const Flipbook := preload("res://scripts/fx_flipbook.gd")
const Settings := preload("res://scripts/settings.gd")

const SLICK_TEXTURE := "res://art/decals/oil_slick.png"
const FLAMES_SHEET := "res://art/spells/oil/flames_sheet"  # .png and .json (tools/art/gen_spell_fx.py)
const FLAME_PIXEL := 0.03  # World size of one flame art pixel: a patch of flames about 1.7 wide, a bit under a tile.

var cfg: Resource = LightConfig.get_config()
var dungeon: Node
var party: Node
var slicks := {}   # Vector2i -> {"left": seconds, "node": MeshInstance3D}
var burning := {}  # Vector2i -> {"left": seconds, "tick": seconds since the last burn, "light": OmniLight3D, "flames": Array of Flipbook}
var ignited := 0   # Slicks that caught so far (tests read this).
var _slick_mesh: Mesh
var _flames: Dictionary = {}


func _ready() -> void:
	add_to_group("oil")
	dungeon = get_parent()
	if ResourceLoader.exists(SLICK_TEXTURE):
		var plane := PlaneMesh.new()
		plane.size = Vector2(1.7, 1.7)
		var mat := StandardMaterial3D.new()
		mat.albedo_texture = load(SLICK_TEXTURE)
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		mat.alpha_scissor_threshold = 0.5
		mat.roughness = 0.35  # Wet: a little shine where a light catches it.
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		plane.material = mat
		_slick_mesh = plane
	if ResourceLoader.exists(FLAMES_SHEET + ".png"):
		var info = JSON.parse_string(FileAccess.get_file_as_string(FLAMES_SHEET + ".json"))
		if info is Dictionary:
			_flames = {"texture": load(FLAMES_SHEET + ".png"), "frames": int(info.frames), "fps": float(info.fps)}


# --- Questions -----------------------------------------------------------------------------------------------------------

func has_slick(cell: Vector2i) -> bool:
	return slicks.has(cell)


func is_burning(cell: Vector2i) -> bool:
	return burning.has(cell)


# --- Commands ------------------------------------------------------------------------------------------------------------

## Oil on this tile (a flask thrown at the floor): a fresh slick that lasts `slick_seconds`. Thrown onto a burning tile or onto fire, it
## catches at once.
func add_slick(cell: Vector2i) -> void:
	if burning.has(cell):
		return
	if slicks.has(cell):  # More oil on an old slick: a fresh 120 s.
		slicks[cell].left = cfg.slick_seconds
		return
	var node: MeshInstance3D = null
	if _slick_mesh != null:
		node = MeshInstance3D.new()
		node.mesh = _slick_mesh
		node.position = DungeonMap.cell_to_world(cell) + Vector3(0, 0.025, 0)
		node.rotation.y = float((cell.x * 7 + cell.y * 13) % 4) * PI / 2.0  # Not every puddle the same way up.
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(node)
	slicks[cell] = {"left": cfg.slick_seconds, "node": node}


## Fire touches this tile. A slick on it catches and burns; nothing happens on a tile with none. Returns whether one caught. (Refused in a
## curse zone: the air will not let oil catch.)
func ignite(cell: Vector2i) -> bool:
	if not slicks.has(cell) or dungeon.flame_blocked(cell):
		return false
	_remove_slick(cell)
	_burn(cell, cfg.burn_seconds, false)
	ignited += 1
	Events.send(get_tree(), "oil_ignited", [cell])
	dungeon.ignite_braziers_beside(cell)
	get_tree().call_group("audio", "play", "fireball", -10.0, 1.3)  # (A placeholder whoosh: no oil sound exists yet.)
	if _sees(cell):
		get_tree().call_group("hud", "show_message", "The oil catches!")
	return true


## Fire touches every slick on a tile within `radius` of `cell` (a Fireball's blast). Returns how many caught.
func ignite_near(cell: Vector2i, radius := 1) -> int:
	var count := 0
	for c in slicks.keys():
		var d: Vector2i = (c - cell).abs()
		if maxi(d.x, d.y) <= radius and ignite(c):
			count += 1
	return count


## The flask smashes on a tile: the splash plays (PixelLab VFX) wherever it lands, on a monster too.
func burst(cell: Vector2i) -> void:
	get_tree().call_group("spell_effects", "oil_burst", cell)


# --- Each frame ----------------------------------------------------------------------------------------------------------

func _process(delta: float) -> void:
	if party == null or not is_instance_valid(party):
		party = get_tree().get_first_node_in_group("party")
	# A burning torch lying on a slick lights it (thrown there, slipped there, or put down lit).
	var lights: Node = dungeon.get("lights")
	if lights != null and not slicks.is_empty():
		for e in lights.burning:
			if slicks.has(e.cell):
				ignite(e.cell)
	for cell in slicks.keys():
		slicks[cell].left -= delta
		if slicks[cell].left <= 0.0:
			_remove_slick(cell)
	for cell in burning.keys():
		var b: Dictionary = burning[cell]
		b.left -= delta
		b.tick += delta
		while b.tick >= 1.0:
			b.tick -= 1.0
			_hurt_on(cell)
		if b.left <= 0.0:
			_put_out(cell)


## One second of fire on a tile: 2 to a monster standing on it (a doused one catches too: see Monster.take_hit), 1 to each hero if the party is there.
func _hurt_on(cell: Vector2i) -> void:
	var monster = DungeonMap.occupied.get(cell)
	if monster != null and is_instance_valid(monster) and not monster.dying and monster.cell == cell:
		monster.take_hit({"hit": true, "damage": int(cfg.burn_monster_dps), "chance": 100, "crit": false, "by": -1, "fire": true, "status": "oil_fire"})
	if party != null and DungeonMap.player_cell == cell:
		party.burn_party(int(cfg.burn_hero_dps))


func _burn(cell: Vector2i, seconds: float, quiet: bool) -> void:
	var light := OmniLight3D.new()
	light.set_script(TorchLight)  # Flickers and joins the group "sprite_lights": monsters beside it are lit by it (sprite_lighting.gd).
	light.base_energy = cfg.burn_light_energy
	light.light_color = Color(1.0, 0.7, 0.38)
	light.omni_range = cfg.burn_light_range
	light.position = DungeonMap.cell_to_world(cell) + Vector3(0, 0.6, 0)
	add_child(light)
	var flames := []
	if not _flames.is_empty():
		for k in 2:  # Two patches side by side, so the tile is full of flame.
			var flip: MeshInstance3D = Flipbook.new()
			flip.setup(_flames.texture, _flames.frames, _flames.fps, true, FLAME_PIXEL, Color(1.15, 1.0, 0.9), true, 1.0)
			flip.position = DungeonMap.cell_to_world(cell) + Vector3(0.4 if k == 0 else -0.4, 0.5, 0.4 if k == 0 else -0.4)  # Diagonally apart: side by side from any way you look
			flip.t = 0.17 * k + float(cell.x + cell.y) * 0.05  # Out of step with each other and with the next tile.
			add_child(flip)
			flames.append(flip)
	burning[cell] = {"left": seconds, "tick": 0.0, "light": light, "flames": flames}


func _put_out(cell: Vector2i) -> void:
	var b: Dictionary = burning[cell]
	burning.erase(cell)
	b.light.queue_free()
	for f in b.flames:
		if is_instance_valid(f):
			f.queue_free()


func _remove_slick(cell: Vector2i) -> void:
	var s: Dictionary = slicks[cell]
	slicks.erase(cell)
	if s.node != null:
		s.node.queue_free()


## Does the party see this tile (a clear line within a few tiles)? Only then is it told the oil caught.
func _sees(cell: Vector2i) -> bool:
	var from: Vector2i = DungeonMap.player_cell
	var d := (cell - from).abs()
	return maxi(d.x, d.y) <= cfg.haze_see_range and (cell == from or DungeonMap.has_line_of_sight(from, cell))


# --- Saving --------------------------------------------------------------------------------------------------------------

func save_state() -> Dictionary:
	var s := []
	for cell in slicks:
		s.append({"cell": [cell.x, cell.y], "left": slicks[cell].left})
	var b := []
	for cell in burning:
		b.append({"cell": [cell.x, cell.y], "left": burning[cell].left})
	return {"slicks": s, "burning": b}


## Is this saved oil state usable? "" if so, else why not (an older save has none: that is fine).
static func validate_state(d) -> String:
	if not d is Dictionary:
		return "The saved oil is damaged."
	for key in ["slicks", "burning"]:
		if not d.get(key) is Array:
			return "The saved oil is damaged."
		for e in d[key]:
			if not (e is Dictionary and e.get("cell") is Array and e.cell.size() == 2 and typeof(e.cell[0]) in [TYPE_INT, TYPE_FLOAT] and typeof(e.cell[1]) in [TYPE_INT, TYPE_FLOAT]
					and typeof(e.get("left")) in [TYPE_INT, TYPE_FLOAT]):
				return "The saved oil is damaged."
	return ""


func load_state(d: Dictionary) -> void:
	for cell in slicks.keys():
		_remove_slick(cell)
	for cell in burning.keys():
		_put_out(cell)
	for e in d.get("slicks", []):
		var cell := Vector2i(int(e.cell[0]), int(e.cell[1]))
		add_slick(cell)
		if slicks.has(cell):
			slicks[cell].left = maxf(0.1, float(e.left))
	for e in d.get("burning", []):
		var cell := Vector2i(int(e.cell[0]), int(e.cell[1]))
		if not burning.has(cell):
			_burn(cell, maxf(0.1, float(e.left)), true)
