extends Node
## Banter: short lines in the message log when something happens. Scripts never hold this node; they call it through the
## group, and a scene without it is simply quiet. Read docs/tone.md before writing a line.
##
##     get_tree().call_group("banter", "event", "crit", {"actor": "thief", "weapon": "Dagger", "target": "mage"})
##     get_tree().call_group("banter", "set_quiet", "ambush", true)     # no banter until set_quiet("ambush", false)
##
## It also listens to GameEvents (monster_killed, hero_died, hero_revived, item_picked_up, door_unlocked, lever_pulled, wall_broken,
## wall_purified, puzzle_solved, level_completed, fight_started, fight_ended, hero_hurt, mana_low): each becomes an event of the same
## name, with a context made from the signal's arguments (see CONTEXTS below), so a line for "hero_died" in the JSON just works.
##
## THE DATA (data/banter.json), one entry per event:
##     chance    0..1, how often the event gets a line at all
##     cooldown  seconds of GAME time before this event may speak again (the game clock: it stops while paused)
##     lines     [{speaker, text, ...conditions}]
##
## THE CONTEXT of an event (a Dictionary the sender fills in; every key is optional):
##     actor     the hero it happened to or who did it, a class id ("cleric", "fighter", "thief", "mage")
##     target    a second hero the event is aimed at (a class id)
##     weapon    the name of the weapon involved ("Grudge")
##     slipped   true if a weapon slipped; any other key is free ("monster": "Skeleton", "puzzle": "gate_n") and a line may test it
## A revival also carries "earlier": true if another hero was revived before this one this run. The ambush system (docs/code_review.md
## phase 7d) sends three events of its own, not GameEvents signals: "ambush_warning" (a quick exchange before the burst), "ambush_started"
## (context {"warned": whether the warning was said}: the battle cry) and "ambush_over" (the grudging remark), and keeps banter quiet
## with set_quiet("ambush") between the first two and the last. The test room's ambush corridor sends them already.
##
## A LINE: `speaker` (a living hero by CLASS ID, so renaming a hero changes nothing here; a weapon the actor holds, "Grudge"; or "$actor"),
## `text`, and these optional fields:
##   conditions (all must hold):
##     about        "self" (the speaker is the actor), "target" (the speaker is the target) or anything else = another hero (not the actor)
##     actor / target   the context's actor / target must be this class id
##     holding / not_holding   the actor's weapon name contains / doesn't contain this
##     slipped      the context's "slipped" must equal this
##     alone        whether the actor is the only hero alive
##     if           {key: value, ...}: the context must have each key equal to the value (text is compared without caring about case)
##     in_fight     true / false: the party must (not) be in a fight (the fight tracker). A conversation is "in_fight": false
##     once         true: said once a RUN, remembered in the run flags (so saved). Give it an `id` ("first_death"): the default is the
##                  line's place in the file, which moves when lines are added
##     flag         a run flag that must be set: "banter.once.first_death" is set once the line with that id has been said, so this
##                  line only follows it (a scene told across the run: the first death, and later the first revival)
##   behaviour:
##     priority     among the lines that fit, only the highest priority is picked from (default 0)
##     always       said as well as the picked line
##     urgent       said even in quiet and inside the minimum gap (a battle cry, a shout of alarm)
##     reply        [{speaker, text, delay, ...}]: said one after another after the line, `delay` seconds (default REPLY_DELAY) after the
##                  one before. A reply has the same fields as a line (and may have its own `reply`). It is checked when it comes due: if its
##                  conditions no longer hold, or it is quiet and the reply is not urgent, it and the rest of its exchange are dropped
## PLACEHOLDERS in text: {name} the speaker, {actor} the event's actor, {target} the event's target (else its actor): always the hero's own
## name. A line that uses {actor} or {target} when the event has no such hero does not fit and is not said. Never type a hero's name.
##
## THE RULES (docs/code_review.md M3): after the cooldown and the chance, at most one line is picked from those that fit, plus any
## `always`; nothing at all is said while quiet (set_quiet: ambushes and scenes switch it on, any number of reasons at once) or less
## than min_gap seconds after the last line, except `urgent` lines and replies. Rolls use the combat dice, so tests can seed them.

const CombatRules := preload("res://scripts/combat_rules.gd")
const DungeonMap := preload("res://scripts/dungeon_map.gd")

const PATH := "res://data/banter.json"
const MIN_GAP := 3.0       # Seconds of game time between one exchange and the next.
const REPLY_DELAY := 1.4   # Seconds between a line and its reply when the reply gives no `delay`.
const ONCE_FLAG := "banter.once."  # Run flags that remember the once-lines: "banter.once.<id>".
const REVIVED_FLAG := "banter.revived."  # ...and the heroes already revived this run: "banter.revived.<class id>".

var events := {}
var ready_at := {}          # event -> game time when it may speak again.
var said: Array = []        # Every line said this run, newest last, for tests.
var enabled := true         # Debug (the test room's B key) switches it off.
var game_time := 0.0        # Seconds of game time since this node was made: the clock for cooldowns, the gap and replies.
var min_gap := MIN_GAP
var last_line_at := -1000.0 # Game time of the last line said.
var pending: Array = []     # Replies waiting for their time: {at, seq, chain, line, context, event, path}, in order.
var _quiet := {}            # Reason -> true while that reason keeps banter quiet.
var _seq := 0
var _chain := 0


func _ready() -> void:
	add_to_group("banter")
	var file: Resource = load(PATH)
	if file != null and file.data is Dictionary:
		events = file.data
	_listen()


func _process(delta: float) -> void:
	game_time += delta
	_fire_replies()


# --------------------------------------------------------------------------
# Quiet
# --------------------------------------------------------------------------

## Keep banter quiet (or let it speak again) for this reason. Several reasons can hold at once; it speaks when none do.
func set_quiet(reason: String, on := true) -> void:
	if on:
		_quiet[reason] = true
	else:
		_quiet.erase(reason)


func is_quiet() -> bool:
	return not _quiet.is_empty()


## For the test room's help overlay: "OFF", "ON" or "ON  QUIET (ambush)".
func status() -> String:
	if not enabled:
		return "OFF"
	return "ON  QUIET (%s)" % ", ".join(_quiet.keys()) if is_quiet() else "ON"


## Forget cooldowns, the gap and any replies still waiting (a test starts from a clean slate).
func reset_timers() -> void:
	ready_at.clear()
	last_line_at = -1000.0
	pending.clear()


# --------------------------------------------------------------------------
# Events
# --------------------------------------------------------------------------

## Something happened: maybe say a line. Returns the lines said now (replies come later).
func event(event_name: String, context := {}) -> Array:
	var e: Dictionary = events.get(event_name, {})
	if e.is_empty() or not enabled:
		return []
	if game_time < float(ready_at.get(event_name, 0.0)):
		return []
	var chance := float(e.get("chance", 1.0))
	if chance < 1.0 and CombatRules.rng().randf() >= chance:
		return []
	var all_lines: Array = e.get("lines", [])
	var candidates := []
	for i in all_lines.size():
		if _fits(all_lines[i], context, event_name, str(i)):
			candidates.append({"line": all_lines[i], "path": str(i)})
	if is_quiet() or game_time - last_line_at < min_gap:  # Only an urgent line may speak now.
		candidates = candidates.filter(func(c): return c.line.get("urgent", false))
	var chosen := candidates.filter(func(c): return c.line.get("always", false))
	var pickable := candidates.filter(func(c): return not c.line.get("always", false))
	if not pickable.is_empty():
		var top := int(pickable.map(func(c): return int(c.line.get("priority", 0))).max())
		var best := pickable.filter(func(c): return int(c.line.get("priority", 0)) == top)
		chosen.append(best[CombatRules.rng().randi_range(0, best.size() - 1)])
	var out := []
	for c in chosen:
		out.append(_say(c.line, context, event_name, c.path))
	for c in chosen:
		_schedule_replies(c.line, context, event_name, c.path)
	if not out.is_empty():
		ready_at[event_name] = game_time + float(e.get("cooldown", 0.0))
	return out


## Say one line now: the log, `said`, the gap clock and (for a once-line) the run flag. Returns what was shown.
func _say(line: Dictionary, context: Dictionary, event_name: String, path: String) -> String:
	var speaker := _speaker_of(line, context)
	var text := "%s: %s" % [_display(speaker), _fill(str(line.get("text", "")), context, speaker)]
	get_tree().call_group("hud", "show_message", text, false, "banter")
	said.append(text)
	last_line_at = game_time
	if line.get("once", false):
		DungeonMap.set_flag(_once_key(line, event_name, path))
	return text


## Queue the replies of a line that was just said, each after the one before it. One chain: if one is dropped, so are the rest.
func _schedule_replies(line: Dictionary, context: Dictionary, event_name: String, path: String) -> void:
	var replies: Array = line.get("reply", [])
	if replies.is_empty():
		return
	_chain += 1
	var at := game_time
	for i in replies.size():
		at += float(replies[i].get("delay", REPLY_DELAY))
		_seq += 1
		pending.append({"at": at, "seq": _seq, "chain": _chain, "line": replies[i], "context": context, "event": event_name,
				"path": "%s.r%d" % [path, i]})
	pending.sort_custom(func(a, b): return a.at < b.at or (a.at == b.at and a.seq < b.seq))


## Say every reply that has come due, unless it no longer fits (a hero died, a fight began, quiet fell).
func _fire_replies() -> void:
	while not pending.is_empty() and float(pending[0].at) <= game_time:
		var p: Dictionary = pending.pop_front()
		var urgent: bool = p.line.get("urgent", false)
		if not enabled or (is_quiet() and not urgent) or not _fits(p.line, p.context, p.event, p.path):
			pending = pending.filter(func(other): return other.chain != p.chain)  # The exchange is over.
			continue
		_say(p.line, p.context, p.event, p.path)
		_schedule_replies(p.line, p.context, p.event, p.path)


# --------------------------------------------------------------------------
# Does a line fit
# --------------------------------------------------------------------------

func _fits(line: Dictionary, context: Dictionary, event_name: String, path: String) -> bool:
	var actor: String = str(context.get("actor", ""))
	var weapon: String = str(context.get("weapon", "")).to_lower()
	var speaker := _speaker_of(line, context)
	if speaker == "":
		return false
	var living := _living()
	if speaker not in living and (weapon == "" or speaker.to_lower() not in weapon):
		return false
	if line.has("about"):
		match str(line.about):
			"self":
				if speaker != actor:
					return false
			"target":
				if speaker != _target_class(context):
					return false
			_:
				if speaker == actor:
					return false
	if line.has("actor") and line.actor != actor:
		return false
	if line.has("target") and line.target != str(context.get("target", "")):
		return false
	if line.has("holding") and str(line.holding).to_lower() not in weapon:
		return false
	if line.has("not_holding") and str(line.not_holding).to_lower() in weapon:
		return false
	if line.has("slipped") and bool(line.slipped) != bool(context.get("slipped", false)):
		return false
	if line.has("alone") and bool(line.alone) != (living == [actor]):
		return false
	if line.has("if"):
		for key in line["if"]:
			if not context.has(key) or not _same(context[key], line["if"][key]):
				return false
	if line.has("in_fight") and bool(line.in_fight) != _in_fight():
		return false
	if line.get("once", false) and DungeonMap.has_flag(_once_key(line, event_name, path)):
		return false
	if line.has("flag") and not DungeonMap.has_flag(str(line.flag)):
		return false
	var text := str(line.get("text", ""))
	if "{actor}" in text and _name_of(actor) == "":
		return false
	if "{target}" in text and _name_of(_target_class(context)) == "":
		return false
	return true


func _speaker_of(line: Dictionary, context: Dictionary) -> String:
	return str(context.get("actor", "")) if line.get("speaker", "") == "$actor" else str(line.get("speaker", ""))


## The class id of the hero a line is "about": the context's target, else its actor.
func _target_class(context: Dictionary) -> String:
	var target := str(context.get("target", ""))
	return target if target != "" else str(context.get("actor", ""))


## The flag that remembers a once-line: its `id`, or where it is in the file.
func _once_key(line: Dictionary, event_name: String, path: String) -> String:
	return ONCE_FLAG + str(line.get("id", "%s.%s" % [event_name, path]))


func _same(a, b) -> bool:
	if typeof(a) == TYPE_STRING and typeof(b) == TYPE_STRING:
		return a.to_lower() == b.to_lower()
	return a == b


func _in_fight() -> bool:
	var party := get_tree().get_first_node_in_group("party")
	return party != null and party.get("fight") != null and party.fight.in_fight


## The text with {name}, {actor} and {target} filled in with the heroes' own names.
func _fill(text: String, context: Dictionary, speaker: String) -> String:
	return text.replace("{name}", _display(speaker)).replace("{actor}", _name_of(str(context.get("actor", "")))) \
			.replace("{target}", _name_of(_target_class(context)))


## The class ids of the heroes still alive ("cleric"...), which is what a line's `speaker` and `actor` are.
func _living() -> Array:
	var names := []
	var party := get_tree().get_first_node_in_group("party")
	if party != null:
		for m in party.members:
			if m.is_alive():
				names.append(m.class_id())
	return names


## A hero's own name from their class id, or "" if no hero has it.
func _name_of(class_id: String) -> String:
	var party := get_tree().get_first_node_in_group("party")
	if party != null and class_id != "":
		for m in party.members:
			if m.class_id() == class_id:
				return m.name()
	return ""


## What the log shows before a line: the hero's own name for a class id ("cleric" -> "Brother Felix"), else the speaker as written
## (a weapon: "Grudge").
func _display(speaker: String) -> String:
	var hero := _name_of(speaker)
	return hero if hero != "" else speaker


## The class id of the hero with this hero_index (who they are, wherever they stand), or "".
func _class_of(hero_index: int) -> String:
	var party := get_tree().get_first_node_in_group("party")
	if party != null:
		for m in party.members:
			if m.hero_index == hero_index:
				return m.class_id()
	return ""


# --------------------------------------------------------------------------
# GameEvents: each signal is an event of the same name
# --------------------------------------------------------------------------

func _listen() -> void:
	var bus := get_tree().root.get_node_or_null("GameEvents")
	if bus == null:
		return
	bus.monster_killed.connect(_on_monster_killed)
	bus.hero_died.connect(_on_hero_died)
	bus.hero_revived.connect(_on_hero_revived)
	bus.hero_hurt.connect(_on_hero_hurt)
	bus.mana_low.connect(_on_mana_low)
	bus.item_picked_up.connect(_on_item_picked_up)
	bus.door_unlocked.connect(_on_door_unlocked)
	bus.lever_pulled.connect(_on_lever_pulled)
	bus.wall_broken.connect(_on_wall_broken)
	bus.wall_purified.connect(_on_wall_purified)
	bus.puzzle_solved.connect(_on_puzzle_solved)
	bus.level_completed.connect(_on_level_completed)
	bus.fight_started.connect(_on_fight_started)
	bus.fight_ended.connect(_on_fight_ended)


func _on_monster_killed(def: Resource, cell: Vector2i, killer: int) -> void:
	event("monster_killed", {"actor": _class_of(killer), "monster": def.display_name, "cell": cell})


func _on_hero_died(hero: int) -> void:
	event("hero_died", {"actor": _class_of(hero)})


func _on_hero_revived(hero: int, by_scroll: bool) -> void:
	var who := _class_of(hero)
	var earlier := false  # Has another hero been revived before this one this run?
	for flag_name in DungeonMap.flags:
		if str(flag_name).begins_with(REVIVED_FLAG) and flag_name != REVIVED_FLAG + who:
			earlier = true
	if who != "":
		DungeonMap.set_flag(REVIVED_FLAG + who)
	event("hero_revived", {"actor": who, "by_scroll": by_scroll, "earlier": earlier})


func _on_hero_hurt(hero: int, amount: int, source: String) -> void:
	event("hero_hurt", {"actor": _class_of(hero), "amount": amount, "source": source})


func _on_mana_low(hero: int) -> void:
	event("mana_low", {"actor": _class_of(hero)})


func _on_item_picked_up(def: Resource, count: int) -> void:
	event("item_picked_up", {"item": def.display_name, "count": count})


func _on_door_unlocked(cell: Vector2i) -> void:
	event("door_unlocked", {"cell": cell})


func _on_lever_pulled(cell: Vector2i, side: int, on: bool) -> void:
	event("lever_pulled", {"cell": cell, "side": side, "on": on})


func _on_wall_broken(cell: Vector2i) -> void:
	event("wall_broken", {"cell": cell})


func _on_wall_purified(cell: Vector2i) -> void:
	event("wall_purified", {"cell": cell})


func _on_puzzle_solved(id: String) -> void:
	event("puzzle_solved", {"puzzle": id})


func _on_level_completed() -> void:
	event("level_completed")


func _on_fight_started() -> void:
	event("fight_started")


func _on_fight_ended() -> void:
	event("fight_ended")
