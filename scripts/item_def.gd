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
@export var icon: Texture2D          # Inventory slots and the cursor (UI pixel size: art drawn at 2x).
@export var hud_icon: Texture2D      # Small version for the party panel's hand and quick slots (also 2x); falls back to icon.
@export var floor_icon: Texture2D    # Sprite in the 3D world (NOT enlarged: that view is shown at 2x); falls back to icon.
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

@export_group("Food")
## Food heals slowly: `food_heal` HP in total, spread evenly over `food_seconds` (potions heal at once, so they stay the
## emergency option). Eating again while a food heal is running replaces it, never stacks. Bad food has a
## `food_sick_chance` (0..1) of making the eater sick: `food_sick_damage` HP in total over `food_sick_seconds`
## (a short damage over time that never kills: it stops at 1 HP). See Party.eat.
@export var food_heal := 0
@export var food_seconds := 0.0
@export var food_sick_chance := 0.0
@export var food_sick_damage := 0
@export var food_sick_seconds := 0.0

@export_group("Resurrection")
## A Scroll of Resurrection: read on a fallen hero's portrait. revive_percent is the share of max HP
## they return with (a divine caster, the Cleric, returns with full HP but is shaken: no mana and no
## prayer for shaken_seconds). 0 means it is not one. See Party.revive.
@export var revive_percent := 0
@export var shaken_seconds := 0.0

@export_group("Breaking")
@export var breaks_walls := false     # A heavy weapon: one swing at a cracked wall breaks it (the war hammer).

@export_group("Magic")
@export var magic: Magic = Magic.NONE  # A FOCUS: which kind of caster can use it.
@export var spells: Array[Resource] = []  # SpellDef, in the order the pop-up lists them.


## Which item types a hand slot / the armour slot will accept (see inventory_slot.gd).
## A backpack slot takes anything, so it has no such check.
static func allowed_in_hand(item_type: Type) -> bool:
	return item_type in [Type.WEAPON, Type.CONSUMABLE, Type.FOCUS]


## The icon for the party panel's hand and quick slots.
func hud_texture() -> Texture2D:
	return hud_icon if hud_icon else icon


## A food (see the Food group): eaten, it heals over time.
func is_food() -> bool:
	return food_seconds > 0.0


func can_throw() -> bool:
	return throw_damage_max > 0


static func allowed_in_armour(item_type: Type) -> bool:
	return item_type == Type.ARMOUR
