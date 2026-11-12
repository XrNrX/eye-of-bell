extends Node
## The game's news: signals only, no logic. An autoload (project.godot: GameEvents), so it outlives a scene reload and
## listeners (banter, XP, puzzles, legendary items) connect to it in their _ready:
##
##     get_node("/root/GameEvents").monster_killed.connect(_on_monster_killed)
##
## A listener that is freed drops its connection by itself. Use call_group for commands ("do this"); this is for news
## ("this happened"). Each signal is sent from the ONE place the thing happens, through send(), which is quiet when the
## autoload is missing (a bare test scene):
##
##     const Events := preload("res://scripts/game_events.gd")
##     Events.send(get_tree(), "monster_killed", [def, cell, hero])
##
## A hero is always their `hero_index` (Party.Member.hero_index: who they are, whatever position they stand in), or -1
## when no hero did it. Nothing is sent while a save is being loaded: these are things that happen in play.

## A monster died. killer: the hero_index of whoever struck the last blow (-1: nobody, e.g. a debug kill).
signal monster_killed(def: Resource, cell: Vector2i, killer: int)
## A hero's HP reached 0.
signal hero_died(hero: int)
## A fallen hero was raised. by_scroll: with a Scroll of Resurrection (the only way so far).
signal hero_revived(hero: int, by_scroll: bool)
## The party took an item (or part of a stack) off the floor: onto the cursor, into a pack, a hand or a quick slot.
signal item_picked_up(def: Resource, count: int)
## A key was spent on a locked door.
signal door_unlocked(cell: Vector2i)
## A wall lever was switched (cell and side as in DungeonMap.LEVERS).
signal lever_pulled(cell: Vector2i, side: int, on: bool)
## A cracked wall was broken open.
signal wall_broken(cell: Vector2i)
## A corrupted wall has finished burning away.
signal wall_purified(cell: Vector2i)
## A puzzle's conditions were met and its effects have run (DungeonMap.PUZZLES id).
signal puzzle_solved(id: String)
## The party took the stairs.
signal level_completed

# Sent by Party.hurt, Party.cast (mana_low) and the fight tracker.
signal hero_hurt(hero: int, amount: int, source: String)  # Sent by Party.hurt: a hero lost HP (source: "monster", "sickness"...).
signal fight_started                                      # Sent by the fight tracker (fight_tracker.gd): the first blow, or a monster noticed the party.
signal fight_ended                                        # ...and quiet again: nothing struck for a few seconds and no monster aware.
signal mana_low(hero: int)                                # Sent by Party.cast: this hero tried to cast and could not afford it ("Not enough mana.").


## Send one of the signals above, if the autoload is there. args are the signal's arguments, in order.
static func send(tree: SceneTree, event: StringName, args: Array = []) -> void:
	if tree == null:
		return
	var bus := tree.root.get_node_or_null("GameEvents")
	if bus != null:
		bus.callv("emit_signal", [event] + args)
