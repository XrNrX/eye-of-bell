extends Resource
## A hero described as data (see data/party/*.tres). Shares its combat fields with
## MonsterDef, so CombatRules.resolve_attack works for either side.

@export var display_name := "Hero"  # The CLASS as the player reads it ("Cleric"): the sheet's subtitle.
@export var class_id := ""     # The class as a key, never shown ("cleric"): banter speakers, ItemDef.cant_use. Empty: display_name in lower case.
@export var hero_name := ""    # The hero's own name ("Brother Felix"), what every message and panel shows. Empty: display_name.
@export var max_hp := 20
@export var attack := 3       # Accuracy: raises the chance to hit.
@export var defence := 3      # Lowers enemies' chance to hit this hero.
@export var speed := 2        # Shortens the attack cooldown.
@export var damage_min := 1
@export var damage_max := 6
@export var hand_icon: Texture2D  # An empty hand's button on the party HUD.
@export var max_mana := 0         # 0: no mana bar, no spells.
@export var magic := 0            # ItemDef.Magic: which FOCUS items this hero can cast from.
@export var start_hands: Array[Resource] = []  # ItemDef per hand (null for empty), at the start of a run.
@export var start_hand_counts: Array[int] = []  # Stack size per hand (missing or 0 means 1), e.g. 6 darts.

@export_group("Crits")
## Crit chance (CombatRules.crit_chance) = crit_base + (dexterity - 10) + weapon bonus + finesse_crit with a finesse
## weapon. Dexterity does nothing else yet. spell_crit is the chance for damage spells instead (0: their spells never crit).
@export var dexterity := 10
@export var crit_base := 0
@export var finesse_crit := 0
@export var spell_crit := 0

@export_group("Portrait")
@export var portrait: Texture2D        # Shown while alive.
@export var portrait_hurt: Texture2D   # Briefly shown (red tint) when hit.
@export var portrait_dead: Texture2D   # Shown once hp reaches 0 (greyed out).
