extends Node3D
## The traps set on the floor: armed bear traps (and any later item of type TRAP). A child of the dungeon, made by
## dungeon_builder.gd, group "traps"; others call it through the group or fetch it (get_first_node_in_group("traps")).
## Rules (docs/combat_design.md "Bear trap"); every number is on the trap's ItemDef ("Trap" group) and the tier table's trap row.
##
## - Setting (Party._set_trap): begin_setting() starts a short wait (ItemDef.set_seconds times CharacterDef.trap_set_time); when it
##   is over the trap is armed, if the party still stands there facing the tile and the tile is still free; otherwise the trap is
##   left lying there unset, as an item.
## - An armed trap lies open and flat on the floor (ItemDef.armed_icon). The party steps over it safely.
## - The first monster to finish a step onto it (Monster._step calls monster_entered) gets snapped: trap_damage, then trap_status
##   through Monster.try_status on the tier table's trap row. A monster it can never hold (the slime oozes through) leaves it armed.
##   Once sprung the trap closes: it lies on the tile as an ordinary item to pick up and set again, unless its spring snaps.
## - Clicking an armed trap in front picks it back up, disarmed (Player.world_click).
## - Saved under dungeon.armed_traps (an older save has none).

const DungeonMap := preload("res://scripts/dungeon_map.gd")
const CombatRules := preload("res://scripts/combat_rules.gd")
const ItemStack := preload("res://scripts/item_stack.gd")
const Events := preload("res://scripts/game_events.gd")

const ARMED_HEIGHT := 0.03   # The open trap lies just above the floor...
const ARMED_TILT := -70.0    # ...tipped up a little from flat (-90), so it reads at a glance from eye height.
const ARMED_SCALE := 1.3     # A touch bigger than the floor items, for the same reason (the art's readability rule).

var armed := {}    # cell -> {"def": ItemDef, "setter": hero_index, "sprite": Sprite3D}
var setting := []  # [{"cell", "def", "setter", "left", "from", "facing"}]: traps being set right now


func _ready() -> void:
	add_to_group("traps")


## Arm the traps the level starts with (DungeonMap.ARMED_TRAPS). Called by the dungeon builder.
func place_level_traps() -> void:
	for entry in DungeonMap.ARMED_TRAPS:
		if ResourceLoader.exists(str(entry.def)):
			arm(entry.cell, load(entry.def), -1)


## Why a trap can't be set on this tile, or "" if it can: only an empty floor tile (not a wall or door, the stairs, a pressure
## plate, a monster, a pile of items or another trap).
func can_set(cell: Vector2i) -> String:
	if DungeonMap.is_wall(cell) or DungeonMap.is_door(cell):
		return "There's no room for a trap there."
	if DungeonMap.is_stairs(cell) or DungeonMap.PLATES.any(func(p): return p.cell == cell):
		return "The trap won't sit flat there."
	if DungeonMap.is_occupied(cell):
		return "Something is in the way."
	if armed.has(cell) or setting.any(func(s): return s.cell == cell):
		return "There's already a trap there."
	var dungeon := get_tree().get_first_node_in_group("dungeon")
	if dungeon != null and dungeon.item_at(cell) != null:
		return "Clear the floor first."
	return ""


## Start setting a trap on `cell` (the party stands on `from` facing `facing`). It is armed `seconds` later.
func begin_setting(cell: Vector2i, def: Resource, setter: int, seconds: float, from: Vector2i, facing: int) -> void:
	setting.append({"cell": cell, "def": def, "setter": setter, "left": seconds, "from": from, "facing": facing})


func _process(delta: float) -> void:
	for s in setting.duplicate():
		s.left -= delta
		if s.left > 0.0:
			continue
		setting.erase(s)
		var player := get_tree().get_first_node_in_group("player")
		var still_here: bool = player != null and player.cell == s.from and int(player.facing) == s.facing
		if still_here and can_set(s.cell) == "":
			arm(s.cell, s.def, s.setter)
			_say("The trap is set.")
			_cue("trap_set")
		else:  # Interrupted: it lies there closed, to be picked up.
			var dungeon := get_tree().get_first_node_in_group("dungeon")
			if dungeon != null and not DungeonMap.is_wall(s.cell):
				dungeon.place_item(s.cell, ItemStack.of(s.def, 1))
			_say("The trap is left unset.")


## Lay an armed trap on a tile (no checks: callers use can_set).
func arm(cell: Vector2i, def: Resource, setter := -1) -> void:
	var sprite := Sprite3D.new()
	sprite.texture = def.armed_icon if def.armed_icon else (def.floor_icon if def.floor_icon else def.icon)
	sprite.pixel_size = def.icon_pixel_size * ARMED_SCALE
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.shaded = false  # Tinted by the light that reaches it, like the floor items (sprite_lighting.gd); tipped up and enlarged to read.
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sprite.rotation_degrees.x = ARMED_TILT  # Lying on the floor, drawn from above.
	sprite.position = DungeonMap.cell_to_world(cell) + Vector3(0, ARMED_HEIGHT, 0)
	add_child(sprite)
	armed[cell] = {"def": def, "setter": setter, "sprite": sprite}


## The ItemDef of the armed trap on this tile, or null.
func armed_at(cell: Vector2i) -> Resource:
	return armed[cell].def if armed.has(cell) else null


## Pick up the armed trap on this tile, disarmed: returns its ItemDef (null if there is none).
func disarm(cell: Vector2i) -> Resource:
	if not armed.has(cell):
		return null
	var entry: Dictionary = armed[cell]
	armed.erase(cell)
	entry.sprite.queue_free()
	return entry.def


## The party stepped onto a tile (Player._try_move): they know where their traps are.
func party_entered(cell: Vector2i) -> void:
	if not armed.has(cell):
		return
	var party := get_tree().get_first_node_in_group("party")
	var who := "You"
	if party != null:
		for m in party.members:
			if m.is_alive():
				who = m.name()
				break
	_say("%s steps carefully over the trap." % who)


## A monster finished a step onto a tile (Monster._step): snap it, if this tile has an armed trap.
func monster_entered(monster: Node) -> void:
	var cell: Vector2i = monster.cell
	if not armed.has(cell) or monster.dying or monster.def.wall_monster:
		return
	var entry: Dictionary = armed[cell]
	var def: Resource = entry.def
	var monster_name: String = str(monster.def.display_name).to_lower()
	var tiers := preload("res://scripts/monster_tiers.gd").get_config()
	var odds: Dictionary = tiers.odds(def.trap_row, monster.def)
	if odds.immune:  # The slime oozes through: the trap stays armed.
		var line: String = odds.message if odds.message != "" else "The trap does not close on the {monster}."
		_say(line.replace("{monster}", monster_name))
		return
	armed.erase(cell)
	entry.sprite.queue_free()
	_cue("trap_snap")
	get_tree().call_group("spell_effects", "trap_snap", cell)
	get_tree().call_group("fight_tracker", "blow")
	var damage := CombatRules.roll_damage(def.trap_damage_min, def.trap_damage_max) if def.trap_damage_max > 0 else 0
	if damage > 0:
		monster.take_hit({"hit": true, "damage": damage, "chance": 100, "crit": false, "by": entry.setter})
	var text := "The trap snaps shut on the %s." % monster_name
	if monster.dying:
		text = "The trap snaps shut on the %s. It dies." % monster_name
	elif def.trap_status != null:
		var result: Dictionary = monster.try_status(def.trap_status, def.trap_seconds, entry.setter, def.trap_row)
		if result.outcome == "resisted":
			text = "The trap snaps shut, but the %s tears free." % monster_name
		elif result.message != "":
			text += " " + str(result.message).replace("{monster}", monster_name)
	_say(text)
	Events.send(get_tree(), "trap_triggered", [def, monster])
	if def.break_chance > 0.0 and CombatRules.rng().randf() < def.break_chance:
		_say("The trap's spring snaps.")
		get_tree().call_group("banter", "event", "trap_broke", {})
		return
	var dungeon := get_tree().get_first_node_in_group("dungeon")
	if dungeon != null:
		dungeon.place_item(cell, ItemStack.of(def, 1))  # Closed, it lies there to be picked up and set again.


## For the save: every armed trap (and any being set, as if it were done).
func serialize() -> Array:
	var out := []
	for cell in armed:
		out.append({"cell": [cell.x, cell.y], "def": armed[cell].def.resource_path, "setter": armed[cell].setter})
	for s in setting:
		out.append({"cell": [s.cell.x, s.cell.y], "def": s.def.resource_path, "setter": s.setter})
	return out


## Loading: replace every armed trap with the saved ones.
func restore(list: Array) -> void:
	for cell in armed.keys():
		disarm(cell)
	setting.clear()
	for t in list:
		if ResourceLoader.exists(str(t.def)):
			arm(Vector2i(int(t.cell[0]), int(t.cell[1])), load(t.def), int(t.get("setter", -1)))


func _say(text: String) -> void:
	get_tree().call_group("hud", "show_message", text)


func _cue(sound: String) -> void:
	get_tree().call_group("audio", "play", sound)
