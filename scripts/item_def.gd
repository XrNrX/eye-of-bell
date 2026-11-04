extends Resource
## An item described as data (see data/items/*.tres). It can lie on a floor tile
## (dungeon_builder.gd owns the sprite there) and be picked up onto the cursor
## (see cursor_item.gd). New items are just new .tres files; nothing here reads
## the stats below yet -- they're here for when weapons/armour/potions are wired
## into combat, the same way MonsterDef's fields existed before combat did.

enum Type { WEAPON, ARMOUR, CONSUMABLE, KEY }

@export var display_name := "Item"
@export var type: Type = Type.KEY
@export var icon: Texture2D          # Used both on the floor and on the cursor.
@export var icon_pixel_size := 0.03  # World units per icon pixel, for the floor sprite.

@export_group("Stats")
@export var attack_bonus := 0        # Weapon: added to the wielder's attack.
@export var damage_min := 0          # Weapon: replaces the wielder's bare-handed damage.
@export var damage_max := 0
@export var defence_bonus := 0       # Armour: added to the wearer's defence.
@export var heal_amount := 0         # Consumable: HP restored when used.


## Which item types a hand slot / the armour slot will accept (see inventory_slot.gd).
## A backpack slot takes anything, so it has no such check.
static func allowed_in_hand(item_type: Type) -> bool:
	return item_type == Type.WEAPON or item_type == Type.CONSUMABLE


static func allowed_in_armour(item_type: Type) -> bool:
	return item_type == Type.ARMOUR
