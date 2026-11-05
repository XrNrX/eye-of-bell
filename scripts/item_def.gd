extends Resource
## An item described as data (see data/items/*.tres). It can lie on a floor tile
## (dungeon_builder.gd owns the sprite there) and be picked up onto the cursor
## (see cursor_item.gd). New items are just new .tres files.
##
## What reads the stats below (see party.gd): an equipped weapon changes its holder's
## attack and damage (effective_stats); a consumable with heal_amount heals, and one
## with spell_damage_max casts at the monster ahead (use_item). defence_bonus is
## still data only -- nothing reads it yet.
##
## In a hand (see Party.act): a weapon with throw_damage_max > 0 can be thrown
## (always, if melee is false, as with darts; from the back row only, if it can also
## melee, as with the dagger). A FOCUS (spellbook, holy symbol) opens its spell list
## for a hero whose CharacterDef.magic matches.

# New values go at the end: .tres files store the number.
enum Type { WEAPON, ARMOUR, CONSUMABLE, KEY, FOCUS }
enum Magic { NONE, ARCANE, DIVINE }

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

@export_group("Throwing")
@export var throw_damage_min := 0    # Damage when thrown; 0 max means it can't be thrown.
@export var throw_damage_max := 0
@export var melee := true            # False for thrown-only weapons (darts).

@export_group("Magic")
@export var magic: Magic = Magic.NONE  # A FOCUS: which kind of caster can use it.
@export var spells: Array[Resource] = []  # SpellDef, in the order the pop-up lists them.


## Which item types a hand slot / the armour slot will accept (see inventory_slot.gd).
## A backpack slot takes anything, so it has no such check.
static func allowed_in_hand(item_type: Type) -> bool:
	return item_type in [Type.WEAPON, Type.CONSUMABLE, Type.FOCUS]


func can_throw() -> bool:
	return throw_damage_max > 0


static func allowed_in_armour(item_type: Type) -> bool:
	return item_type == Type.ARMOUR
