extends RefCounted
## The base class of an item's optional behaviour (Foundations step 11, S5 in docs/code_review.md): a script on `ItemDef.behaviour`
## that extends this and overrides the hooks it needs. Ordinary items keep the fields they have and need none; legendary items (7g)
## are made of these, so ten of them do not add ten flags to every item and ten branches to party.gd.
##
## `Party` calls the hooks; one instance of the script is made per ItemDef per run (`Party.behaviour_of(def)`), so it may keep state in its
## own vars. That state is NOT saved: anything that must survive a save and load goes in the run flags
## (`DungeonMap.set_flag("legend.<what>", value)`), which are. Every hook gets the party, the hero (a `Party.Member`) and the item's
## `ItemStack`. A behaviour never changes the shared ItemDef; it may change the stack and hand news to the world through the event bus,
## the banter system (`party.get_tree().call_group("banter", "event", ...)`) and `Party.hurt` / `Party.heal`.
##
## Where the hooks fire (party.gd, `_tick_items` and the three attack paths):
##   on_equip    the item came into a living hero's hand or armour slot (also the first frame of a run or a load that finds it there)
##   on_unequip  it left them (to a pack, the cursor, the floor, or its holder died)
##   on_hit      a blow struck with it landed (a swing, a throw or a shot): `result` is the attack's result, so `result.damage` may be changed
##   on_kill     a blow struck with it killed `target`
##   on_tick     every frame it is in a living hero's hand or armour slot (`delta` is 0 while the party is camped: the clocks wait)
##   on_stowed   every frame it sits in a backpack (the hero may be dead; `delta` is 0 while camped)


func on_equip(_party: Node, _m, _stack) -> void:
	pass


func on_unequip(_party: Node, _m, _stack) -> void:
	pass


func on_hit(_party: Node, _m, _stack, _target: Node, _result: Dictionary) -> void:
	pass


func on_kill(_party: Node, _m, _stack, _target: Node) -> void:
	pass


func on_tick(_party: Node, _m, _stack, _delta: float) -> void:
	pass


func on_stowed(_party: Node, _m, _stack, _delta: float) -> void:
	pass
