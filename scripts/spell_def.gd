extends Resource
## A spell as data (data/spells/*.tres), cast from a FOCUS item in a hero's hand
## (ItemDef.spells) through the party HUD's pop-up list. See Party.cast for what the
## fields do. Costs mana only if it takes effect.

enum Target { AHEAD, HERO, PARTY }  # First monster ahead / one hero you pick / everyone alive.

@export var display_name := "Spell"
@export var mana_cost := 3
@export var target: Target = Target.AHEAD
@export var damage_min := 0      # AHEAD: never misses, like the scroll.
@export var damage_max := 0
@export var heal_min := 0        # HERO: restore this much HP.
@export var heal_max := 0
@export var buff_attack := 0     # HERO or PARTY: added to attack while it lasts.
@export var buff_defence := 0    # Added to defence while it lasts.
@export var duration := 0.0      # Seconds a buff lasts; recasting refreshes it.
