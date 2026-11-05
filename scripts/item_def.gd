extends Resource
## An item described as data (see data/items/*.tres). It can lie on a floor tile
## (dungeon_builder.gd owns the sprite there) and be picked up onto the cursor
## (see cursor_item.gd). New items are just new .tres files.
##
## What reads the stats below (see party.gd): an equipped weapon changes its holder's
## attack and damage (effective_stats); a consumable with heal_amount heals, and one
## with spell_damage_max casts at the monster ahead (use_item). defence_bonus is
## still data only -- nothing reads it yet.

enum Type { WEAPON, ARMOUR, CONSUMABLE, KEY }

@export var display_name := "Item"
@export var type: Type = Type.KEY
@export var icon: Texture2D          # Inventory slots and the cursor.
@export var floor_icon: Texture2D    # Smaller version drawn on the floor; falls back to icon.
@export var icon_pixel_size := 0.03  # World units per pixel of the floor sprite.
@export var max_stack := 1          # How many identical items share one backpack or quick slot (1 = never stacks).

@export_group("Stats")
@export var attack_bonus := 0        # Weapon: added to the wielder's attack.
@export var damage_min := 0          # Weapon: replaces the wielder's bare-handed damage.
@export var damage_max := 0
@export var defence_bonus := 0       # Armour: added to the wearer's defence (not wired yet).
@export var heal_amount := 0         # Consumable: HP restored when used (right-click).
@export var spell_damage_min := 0    # Consumable: a scroll. Used once, it hits the monster
@export var spell_damage_max := 0    # ahead for this much, never missing (right-click).


## Which item types a hand slot / the armour slot will accept (see inventory_slot.gd).
## A backpack slot takes anything, so it has no such check.
static func allowed_in_hand(item_type: Type) -> bool:
	return item_type == Type.WEAPON or item_type == Type.CONSUMABLE


static func allowed_in_armour(item_type: Type) -> bool:
	return item_type == Type.ARMOUR
