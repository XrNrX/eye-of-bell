extends Resource
## A spell as data (data/spells/*.tres), cast from a FOCUS item in a hero's hand
## (ItemDef.spells) through the party HUD's pop-up list. See Party.cast for what the
## fields do. Costs mana only if it takes effect.

enum Target { AHEAD, HERO, PARTY }  # First monster ahead / one hero you pick / everyone alive.

@export var display_name := "Spell"
@export var sound := ""          # The effect played when it is cast (see audio.gd); "" for none.
@export var effect := ""         # The lighting played with it (spell_effects.gd): "missile", "heal", "bless", "shield"; "" for none.
@export var mana_cost := 3
@export var target: Target = Target.AHEAD
@export var damage_min := 0      # AHEAD: never misses, like the scroll.
@export var damage_max := 0
@export var purifies_corruption := false  # A divine caster's cast also sends its light into a corrupted wall in front (one tile): Bless.
@export var breaks_walls := false  # AHEAD: can also be cast at a cracked wall, and its blast breaks cracked walls beside a target.
@export var splash_radius := 0   # AHEAD: other monsters within this many tiles (8 around, so 1 = the ring) of the target also burn...
@export var splash_percent := 0  # ...for this percent of the same roll (rounded up, at least 1); no second roll, never hits the party.
@export var heal_min := 0        # HERO: restore this much HP.
@export var heal_max := 0
@export var buff_attack := 0     # HERO or PARTY: added to attack while it lasts.
@export var buff_defence := 0    # Added to defence while it lasts.
@export var duration := 0.0      # Seconds a buff lasts; recasting refreshes it.
@export var reach := 0           # AHEAD: how many tiles ahead it can reach (0: Party.MISSILE_RANGE; 1: only the tile in front).
@export var recast_seconds := 0.0  # After a cast that took effect, this hero can't cast this spell again for this long.
@export var applies_status: Resource  # AHEAD: a StatusDef put on the target for status_seconds (Hold Monster), rolled against
@export var status_seconds := 0.0     # the tier table (data/tiers.tres) for the monster's tier. No damage unless damage_max is set.
