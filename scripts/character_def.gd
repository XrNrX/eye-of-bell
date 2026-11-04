extends Resource
## A hero described as data (see data/party/*.tres). Shares its combat fields with
## MonsterDef, so CombatRules.resolve_attack works for either side.

@export var display_name := "Hero"
@export var max_hp := 20
@export var attack := 3       # Accuracy: raises the chance to hit.
@export var defence := 3      # Lowers enemies' chance to hit this hero.
@export var speed := 2        # Shortens the attack cooldown.
@export var damage_min := 1
@export var damage_max := 6
@export var hand_icon: Texture2D  # The weapon-hand button on the party HUD.
