extends Node
## Banter: one short line in the message log when something happens. Scripts never hold this node; they call it
## through the group, and a scene without it is simply quiet:
##
##     get_tree().call_group("banter", "event", "crit", {"actor": "thief", "weapon": "Dagger"})
##
## The lines live in data/banter.json, one entry per event:
##     chance    0..1, how often the event gets a line at all
##     cooldown  seconds before this event may speak again
##     lines     [{speaker, text, ...conditions}]
## A line's conditions (all optional), checked against the event's context:
##     about        "self" (the speaker is the actor) or "other"
##     actor        the actor must be this hero
##     holding / not_holding   the actor's weapon name contains / doesn't contain this
##     slipped      the context's "slipped" must equal this
##     alone        whether the actor is the only hero alive
##     priority     among the lines that fit, only the highest priority is picked from (default 0)
##     always       said as well as the picked line
## A speaker is a living hero by CLASS ID ("cleric", "fighter", "thief", "mage": CharacterDef.class_id, so renaming a hero changes nothing here;
## the log shows the hero's own name), a weapon the actor holds (Grudge), or "$actor". `actor` (in the context and as a condition) is a class id too. Rolls use the combat dice, so tests can seed them.

const CombatRules := preload("res://scripts/combat_rules.gd")

const PATH := "res://data/banter.json"

var events := {}
var ready_at := {}   # event -> Time.get_ticks_msec() when it may speak again.
var said: Array = [] # Every line said this run, newest last, for tests.
var enabled := true  # Debug (the test room's B key) switches it off.


func _ready() -> void:
	add_to_group("banter")
	var file: Resource = load(PATH)
	if file != null and file.data is Dictionary:
		events = file.data


## Something happened: maybe say a line. Returns the lines said.
func event(event_name: String, context := {}) -> Array:
	var e: Dictionary = events.get(event_name, {})
	if e.is_empty() or not enabled:
		return []
	var now := Time.get_ticks_msec()
	if now < int(ready_at.get(event_name, 0)):
		return []
	var chance := float(e.get("chance", 1.0))
	if chance < 1.0 and CombatRules.rng().randf() >= chance:
		return []
	var fitting: Array = e.get("lines", []).filter(func(line): return _fits(line, context))
	var lines := fitting.filter(func(line): return line.get("always", false))
	var pickable := fitting.filter(func(line): return not line.get("always", false))
	if not pickable.is_empty():
		var top := int(pickable.map(func(line): return int(line.get("priority", 0))).max())
		var best := pickable.filter(func(line): return int(line.get("priority", 0)) == top)
		lines.append(best[CombatRules.rng().randi_range(0, best.size() - 1)])
	var out := []
	for line in lines:
		var speaker: String = context.get("actor", "") if line.speaker == "$actor" else line.speaker
		var text := "%s: %s" % [_display(speaker), line.text]
		get_tree().call_group("hud", "show_message", text, false, "banter")
		said.append(text)
		out.append(text)
	if not out.is_empty():
		ready_at[event_name] = now + int(float(e.get("cooldown", 0.0)) * 1000.0)
	return out


func _fits(line: Dictionary, context: Dictionary) -> bool:
	var actor: String = context.get("actor", "")
	var weapon: String = str(context.get("weapon", "")).to_lower()
	var speaker: String = actor if line.speaker == "$actor" else line.speaker
	var living := _living()
	if speaker not in living and (weapon == "" or speaker.to_lower() not in weapon):
		return false
	if line.has("about") and (line.about == "self") != (speaker == actor):
		return false
	if line.has("actor") and line.actor != actor:
		return false
	if line.has("holding") and str(line.holding).to_lower() not in weapon:
		return false
	if line.has("not_holding") and str(line.not_holding).to_lower() in weapon:
		return false
	if line.has("slipped") and bool(line.slipped) != bool(context.get("slipped", false)):
		return false
	if line.has("alone") and bool(line.alone) != (living == [actor]):
		return false
	return true


## The class ids of the heroes still alive ("cleric"...), which is what a line's `speaker` and `actor` are.
func _living() -> Array:
	var names := []
	var party := get_tree().get_first_node_in_group("party")
	if party != null:
		for m in party.members:
			if m.is_alive():
				names.append(m.class_id())
	return names


## What the log shows before a line: the hero's own name for a class id ("cleric" -> "Brother Felix"), else the speaker as written
## (a weapon: "Grudge").
func _display(speaker: String) -> String:
	var party := get_tree().get_first_node_in_group("party")
	if party != null:
		for m in party.members:
			if m.class_id() == speaker:
				return m.name()
	return speaker
