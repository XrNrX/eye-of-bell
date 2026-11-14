extends Node3D
## Lights burning on the floor: a torch or candle that slipped from a hero's hand (a critical fail) lands on the tile in front still
## lit, and lights the dungeon there instead of the party. A child of the dungeon, made by dungeon_builder.gd ("Lights", group
## "lights"). The light is an ordinary item in the tile's pile (ItemStack.burning true); this node keeps it burning down
## (ItemStack.burn_left) with a light and a small flame over it. Picking it up puts it out (its time is kept), unless it goes back
## into a hand, where it is lit again. Burned out on the floor, it is gone. Saved with the piles: restore() lights them again.
## Settings: data/light.tres ("On the floor"); the light's own numbers are on its ItemDef.

const DungeonMap := preload("res://scripts/dungeon_map.gd")
const LightConfig := preload("res://scripts/light_config.gd")
const PartyLight := preload("res://scripts/party_light.gd")
const FxFlipbook := preload("res://scripts/fx_flipbook.gd")
const FLAME_SHEET := "res://art/spells/light/flame_sheet"  # A PixelLab VFX flame (png + json), shared with the hand slots.
const FLAME_PIXEL := 0.006      # World size of one flame art pixel: a small flame on a stick lying on the floor.

var cfg: Resource = LightConfig.get_config()
var burning := []   # [{"cell", "stack", "light": OmniLight3D, "flame": Node or null}]
var time := 0.0


func _ready() -> void:
	add_to_group("lights")


## A lit light was just put on this tile (dungeon.place_item has already put it in the pile): keep it burning there.
func drop(cell: Vector2i, stack: RefCounted) -> void:
	stack.burning = true
	_add(cell, stack)


## Light again every burning light in the piles (after a save has put the piles back).
func restore() -> void:
	for e in burning:
		_free(e)
	burning.clear()
	var dungeon := get_parent()
	for cell in dungeon.items:
		for stack in dungeon.items[cell].pile:
			if stack.burning:
				_add(cell, stack)


func _add(cell: Vector2i, stack: RefCounted) -> void:
	var light := OmniLight3D.new()
	light.light_color = stack.def.light_color
	light.omni_range = stack.def.light_range
	light.omni_attenuation = stack.def.light_attenuation
	light.position = DungeonMap.cell_to_world(cell) + Vector3(0, cfg.floor_light_height, 0)
	light.add_to_group("sprite_lights")
	add_child(light)
	var flame: Node = null
	if ResourceLoader.exists(FLAME_SHEET + ".png") and FileAccess.file_exists(FLAME_SHEET + ".json"):
		var info = JSON.parse_string(FileAccess.get_file_as_string(FLAME_SHEET + ".json"))
		flame = FxFlipbook.new()
		flame.setup(load(FLAME_SHEET + ".png"), int(info.frames), float(info.fps), true, FLAME_PIXEL, Color(1.4, 1.2, 1.0), true)
		flame.position = light.position
		add_child(flame)
	burning.append({"cell": cell, "stack": stack, "light": light, "flame": flame})


func _free(e: Dictionary) -> void:
	e.light.queue_free()
	if e.flame != null:
		e.flame.queue_free()


func _process(delta: float) -> void:
	time += delta
	var dungeon := get_parent()
	for e in burning.duplicate():
		var pile: Array = dungeon.pile_at(e.cell)
		if not pile.has(e.stack):  # Picked up: put out (a hand lights it again).
			e.stack.burning = false
			_free(e)
			burning.erase(e)
			continue
		e.stack.burn_left = e.stack.seconds_left() - delta
		if e.stack.burn_left <= 0.0:
			pile.erase(e.stack)
			dungeon.set_pile(e.cell, pile)
			_free(e)
			burning.erase(e)
			get_tree().call_group("hud", "show_message", "The %s on the floor gutters out." % e.stack.def.display_name.to_lower())
			continue
		e.light.light_energy = e.stack.def.light_energy * cfg.floor_light_scale * PartyLight.flicker_factor(time, e.stack.burn_left, cfg)
