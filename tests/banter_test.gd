extends SceneTree
## Tests of the banter engine (scripts/banter.gd; docs/code_review.md step 6, M3): placeholders, conditions, once-lines, replies, the
## minimum gap, quiet, cooldowns in game time, the GameEvents hooks, and that the real data/banter.json still works.
## Run: timeout 120 "$G" --headless --path . -s tests/banter_test.gd      (exit code = number of failed checks)
##
## It uses the real floor 1 scene but swaps the banter node's lines for small test tables, and moves the banter clock by hand
## (banter._process(seconds)), so every timing rule is checked exactly. Own settings and save files; nothing of yours is touched.

const DungeonMap := preload("res://scripts/dungeon_map.gd")
const CombatRules := preload("res://scripts/combat_rules.gd")
const Settings := preload("res://scripts/settings.gd")
const SaveGame := preload("res://scripts/save_game.gd")

const SAVE_PATH := "user://banter_test_save.json"
const CLASSES := ["cleric", "fighter", "thief", "mage"]
const LINE_FIELDS := ["speaker", "text", "about", "actor", "target", "holding", "not_holding", "slipped", "alone", "if", "in_fight",
		"once", "id", "flag", "priority", "always", "urgent", "reply", "delay"]
const MAX_TEXT := 55  # docs/tone.md: spoken text, never more than this many characters.
const LEGACY := ["It's alive. I don't like stabbing things that are alive.", "IT'S BEHIND US! I SAID THIS!"]  # From before the tone guide (its audit list): not checked.
const HERO_WORDS := ["Brother", "Felix", "Brannoc", "Wren", "Fennick"]  # A line never types a hero's name.
const BANNED_WORDS := ["okay", "guys", "awesome", "literally", "epic", "loot", "xp", "level", "hp"]  # docs/tone.md section 3.

var fails := 0
var banter: Node
var party: Node
var bus: Node
var real_events := {}


func check(name: String, ok: bool) -> void:
	print(("PASS " if ok else "FAIL ") + name)
	if not ok:
		fails += 1


func _init() -> void:
	Settings.path = "user://banter_test_settings.cfg"
	Settings.loaded = true
	SaveGame.path = SAVE_PATH
	DungeonMap.use_level("")
	CombatRules.seed_rng(777)
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	await create_timer(0.8).timeout
	banter = get_first_node_in_group("banter")
	party = get_first_node_in_group("party")
	bus = root.get_node_or_null("GameEvents")
	if banter == null or party == null or bus == null:
		check("the game has a banter node, a party and the GameEvents autoload", false)
		_finish()
		return
	banter.set_process(false)  # The tests move the banter clock themselves.
	party.fight.set_process(false)  # ...and a pretend fight must not end by itself.
	real_events = banter.events

	_check_real_data()
	await _check_real_lines()
	_check_starter_lines()
	_check_placeholders()
	_check_conditions()
	_check_flag_and_earlier()
	_check_once()
	_check_replies()
	_check_gap()
	_check_quiet()
	await _check_game_time()
	_check_game_events()
	await _check_game_events_from_the_game()
	banter.events = real_events
	_finish()


func _finish() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	print("DONE fails=", fails)
	quit(fails)


# --------------------------------------------------------------------------
# Helpers
# --------------------------------------------------------------------------

## A clean slate with these events (and no gap: the gap has its own tests).
func _events(table: Dictionary) -> void:
	banter.events = table
	banter.reset_timers()
	banter.said.clear()
	banter.min_gap = 0.0
	banter.enabled = true
	for reason in banter._quiet.keys():
		banter.set_quiet(reason, false)
	DungeonMap.flags.clear()
	party.fight.in_fight = false


func _advance(seconds: float) -> void:
	banter._process(seconds)


func _member(class_id: String) -> Object:
	for m in party.members:
		if m.class_id() == class_id:
			return m
	return null


func _line(speaker: String, text: String, extra := {}) -> Dictionary:
	var line := {"speaker": speaker, "text": text}
	line.merge(extra)
	return line


func _one(lines: Array, extra := {}) -> Dictionary:
	var e := {"lines": lines}
	e.merge(extra)
	return e


# --------------------------------------------------------------------------
# The real data
# --------------------------------------------------------------------------

func _line_problems(line: Dictionary, where: String, bad: Array) -> void:
	for key in line:
		if key not in LINE_FIELDS:
			bad.append("%s: unknown field '%s'" % [where, key])
	var speaker := str(line.get("speaker", ""))
	if speaker not in CLASSES and speaker not in ["Grudge", "$actor"]:
		bad.append("%s: speaker '%s' is not a class id, Grudge or $actor" % [where, speaker])
	if str(line.get("text", "")) == "":
		bad.append("%s: no text" % where)
	for i in line.get("reply", []).size():
		_line_problems(line.reply[i], "%s reply %d" % [where, i], bad)


func _tone_problems(line: Dictionary, where: String, out: Array) -> void:
	var text := str(line.get("text", ""))
	if text in LEGACY:
		return
	if text.length() > MAX_TEXT:
		out.append("%s: %d characters: %s" % [where, text.length(), text])
	for word in HERO_WORDS:
		if word in text:
			out.append("%s: types a hero's name (%s): %s" % [where, word, text])
	for word in BANNED_WORDS:
		for token in text.to_lower().split(" ", false):
			if token.trim_prefix("(").trim_suffix(".").trim_suffix(",").trim_suffix("?").trim_suffix("!") == word:
				out.append("%s: banned word '%s': %s" % [where, word, text])
	var left := text
	for known in ["{name}", "{actor}", "{target}"]:
		left = left.replace(known, "")
	if "{" in left or "}" in left:
		out.append("%s: unknown placeholder: %s" % [where, text])
	if text.count("!") > 1 or "*" in text:
		out.append("%s: punctuation: %s" % [where, text])
	for reply in line.get("reply", []):
		_tone_problems(reply, where + " reply", out)


func _check_real_data() -> void:
	var bad := []
	for event_name in real_events:
		var e: Dictionary = real_events[event_name]
		for key in e:
			if key not in ["chance", "cooldown", "lines"]:
				bad.append("%s: unknown field '%s'" % [event_name, key])
		for i in e.get("lines", []).size():
			_line_problems(e.lines[i], "%s line %d" % [event_name, i], bad)
	for b in bad:
		print("  ", b)
	check("data/banter.json: every event and line is well formed (%d events)" % real_events.size(), bad.is_empty() and real_events.size() >= 8)
	var tone := []
	for event_name in real_events:
		for line in real_events[event_name].lines:
			_tone_problems(line, event_name, tone)
	for t in tone:
		print("  ", t)
	check("data/banter.json: every line fits the tone guide (short, no typed names, no banned words, known placeholders)", tone.is_empty())


func _check_real_lines() -> void:
	banter.events = real_events
	_events(real_events)
	var lines: Array = banter.event("hit_behind", {"actor": "fighter"})
	check("existing line: hit_behind is the Mage, by name", lines.size() == 1 and str(lines[0]).begins_with("Fennick: ") and "BEHIND US" in str(lines[0]))
	banter.reset_timers()
	lines = banter.event("fail", {"actor": "fighter", "weapon": "Short Sword", "slipped": false})
	check("existing lines: a fumble gets a remark from somebody else", lines.size() >= 1 and not str(lines[0]).begins_with("Brannoc: "))
	banter.reset_timers()
	lines = banter.event("corruption_bounce", {"actor": "fighter"})
	check("existing lines: the corruption bounce, both `always` lines", lines.size() == 2 and "my son" in str(lines[0]) and "glowy" in str(lines[1]))
	var said_eat := false
	for i in 40:  # The line has a 50% chance: ask until it speaks.
		banter.reset_timers()
		var l: Array = banter.event("eat", {"actor": "fighter"})
		if not l.is_empty():
			said_eat = "Tastes like the floor" in str(l[0]) and str(l[0]).begins_with("Brannoc: ")
			break
	check("existing line: the Fighter's remark on eating", said_eat)
	var said_equip := false
	for i in 40:
		banter.reset_timers()
		var l: Array = banter.event("equip", {"actor": "mage", "weapon": "Leather Armour"})
		if not l.is_empty():
			said_equip = "legs" in str(l[0])
			break
	check("existing line: the Mage's remark on armour", said_equip)
	banter.reset_timers()
	check("a hero who is not alive does not speak", _dead_does_not_speak())


## Every distinct thing an event says over many draws (the pick among the lines that fit is random): {text: true}.
func _outputs(event_name: String, context: Dictionary, draws := 80, flags := []) -> Dictionary:
	var out := {}
	for i in draws:
		_events(real_events)
		for flag_name in flags:
			DungeonMap.set_flag(flag_name)  # (Without it the once-line of the first death always wins: it has the top priority.)
		for line in banter.event(event_name, context):
			out[str(line)] = true
	return out


func _has_text(outputs: Dictionary, part: String) -> bool:
	for text in outputs:
		if part in str(text):
			return true
	return false


## The starter lines of the brief (cleric, fighter, thief, mage), by the engine's own rules.
func _check_starter_lines() -> void:
	var fighter = _member("fighter")
	var cleric = _member("cleric")
	var out := _outputs("hero_died", {"actor": "fighter"})
	check("the Cleric on the Fighter's death", _has_text(out, "Brother Felix: You didn't have the faith, my son."))
	var told := ["banter.once.first_death"]  # (The first death has been told: these are the ones after it.)
	out = _outputs("hero_died", {"actor": "thief"}, 80, told)
	check("the Cleric on the Thief's death", _has_text(out, "The Light does not protect those who pick its pockets."))
	check("the others on the Thief's death use their own name (and the Thief says nothing)", _has_text(out, "Brannoc: Get up, Wren. That's an order.")
			and _has_text(out, "Fennick: Is Wren meant to be that colour?") and not _has_text(out, "Wren:") and not _has_text(out, "Brannoc: No. Not"))
	out = _outputs("hero_died", {"actor": "mage"}, 80, told)
	check("the Cleric on the Mage's death", _has_text(out, "All that reading, and not one prayer."))
	check("the others on the Mage's death", _has_text(out, "Wren: Dibs on Fennick's boots.") and _has_text(out, "Brannoc: Get up, Fennick. That's an order."))
	out = _outputs("hero_died", {"actor": "cleric"}, 80, told)
	check("nobody speaks as the Cleric when the Cleric is the one who died", not _has_text(out, "Brother Felix:") and out.size() >= 3)

	# The first death: told once, and it makes the first revival a scene.
	_events(real_events)
	var first: Array = banter.event("hero_died", {"actor": "thief"})
	check("the first death of a run gets the Fighter's line, once", first == ["Brannoc: No. Not Wren."] and DungeonMap.has_flag("banter.once.first_death"))
	banter.reset_timers()
	check("...and a second death does not get it again", banter.event("hero_died", {"actor": "mage"}) != ["Brannoc: No. Not Fennick."])
	banter.reset_timers()
	banter.said.clear()
	banter.min_gap = 50.0
	var revived: Array = banter.event("hero_revived", {"actor": "thief", "by_scroll": true})
	check("the first revival after it is the Fighter's scene", revived == ["Brannoc: I wasn't bothered."])
	_advance(1.5)
	check("...the revived hero answers as themselves", banter.said.size() == 2 and banter.said[1] == "Wren: I heard you.")
	_advance(1.5)
	check("...and the Fighter has the last word", banter.said.size() == 3 and banter.said[2] == "Brannoc: I'm hungry. Someone get a fire on.")
	banter.reset_timers()
	check("the scene is told once", banter.event("hero_revived", {"actor": "thief", "by_scroll": true}) != ["Brannoc: I wasn't bothered."])
	_events(real_events)
	banter.event("hero_revived", {"actor": "thief", "by_scroll": true})
	check("without a first death there is no 'I wasn't bothered'", not _has_text(_outputs("hero_revived", {"actor": "thief", "by_scroll": true}), "I wasn't bothered"))

	# Revivals: the Fighter snaps back at the Cleric, the Cleric on himself.
	var line: Array = []
	for i in 80:  # (A random pick among those who may speak: until it is the Cleric's.)
		_events(real_events)
		banter.min_gap = 50.0
		line = banter.event("hero_revived", {"actor": "fighter", "by_scroll": true})
		if line == ["Brother Felix: The Light brought you back, my son."]:
			break
	_advance(1.5)
	check("the Cleric claims the credit and the Fighter snaps back", line == ["Brother Felix: The Light brought you back, my son."]
			and banter.said.size() == 2 and banter.said[1] == "Brannoc: Faith didn't buy that scroll.")
	_events(real_events)
	banter.min_gap = 50.0
	out = {}
	for i in 60:  # (A random pick: collect what he says about himself.)
		_events(real_events)
		banter.min_gap = 50.0
		for l in banter.event("hero_revived", {"actor": "cleric", "by_scroll": true, "earlier": false}):
			out[str(l)] = true
	check("the Cleric revived: 'I was at peace', and the exchange continues in his own voice",
			_has_text(out, "I was at peace. There was light.") and not _has_text(out, "Oh, him first"))
	_events(real_events)
	banter.min_gap = 50.0
	banter.event("hero_revived", {"actor": "cleric", "by_scroll": true, "earlier": false})
	var peace_said := true
	for i in 40:  # Until the peace line comes up, then let its reply arrive.
		if banter.said.size() > 0 and "peace" in banter.said[0]:
			break
		_events(real_events)
		banter.min_gap = 50.0
		banter.event("hero_revived", {"actor": "cleric", "by_scroll": true, "earlier": false})
	_advance(1.5)
	peace_said = banter.said.size() == 2 and banter.said[1] == "Brother Felix: And you dragged me back here for this?"
	check("...'And you dragged me back here for this?' follows as a reply", peace_said)
	out = _outputs("hero_revived", {"actor": "cleric", "by_scroll": true, "earlier": true})
	check("the Cleric revived after another hero: 'Oh, him first. Naturally.'", _has_text(out, "Brother Felix: Oh, him first. Naturally."))

	# Out of mana.
	out = _outputs("mana_low", {"actor": "cleric"})
	check("the Cleric out of mana", _has_text(out, "My god is not a well you can keep drawing from."))
	out = _outputs("mana_low", {"actor": "mage"})
	check("the others on a caster out of mana", _has_text(out, "Out of magic? Try a knife, Fennick.") and _has_text(out, "No spells? Fine. Stand behind me.")
			and _has_text(out, "Pray, my child. It costs nothing."))

	# The ambush.
	_events(real_events)
	banter.min_gap = 50.0
	banter.event("ambush_warning", {})
	_advance(1.5)
	check("before the burst: a quick exchange", banter.said == ["Brother Felix: I smell evil.", "Brannoc: Shut up."])
	banter.reset_timers()
	banter.said.clear()
	banter.set_quiet("ambush")
	var cry: Array = banter.event("ambush_started", {"warned": true})
	check("the battle cry is said in quiet and inside the gap (urgent)", cry == ["Brother Felix: I did say!"])
	_advance(1.0)
	check("...and the Fighter answers it", banter.said == ["Brother Felix: I did say!", "Brannoc: Shut up, cleric!"])
	banter.reset_timers()
	banter.said.clear()
	check("an ambush nobody warned about: the Fighter alone", banter.event("ambush_started", {"warned": false}) == ["Brannoc: Behind me!"])
	banter.reset_timers()
	banter.said.clear()
	check("nothing ordinary is said during an ambush", banter.event("fight_ended", {}).is_empty() and banter.event("hero_died", {"actor": "thief"}).is_empty())
	banter.set_quiet("ambush", false)
	banter.reset_timers()
	out = _outputs("ambush_over", {})
	check("after it: the Cleric, grudgingly", _has_text(out, "Brother Felix: You're not so bad with a sword."))
	_events(real_events)


func _dead_does_not_speak() -> bool:
	var mage = _member("mage")
	mage.hp = 0
	var lines: Array = banter.event("hit_behind", {"actor": "fighter"})
	mage.hp = mage.def.max_hp
	return lines.is_empty()


# --------------------------------------------------------------------------
# Placeholders and conditions
# --------------------------------------------------------------------------

func _check_placeholders() -> void:
	_events({"t": _one([_line("cleric", "{name} to {target} about {actor}.")])})
	var lines: Array = banter.event("t", {"actor": "fighter", "target": "thief"})
	check("{name}, {actor} and {target} are the heroes' own names", lines == ["Brother Felix: Brother Felix to Wren about Brannoc."])
	banter.reset_timers()
	lines = banter.event("t", {"actor": "fighter"})
	check("{target} is the actor when the event has no target", lines == ["Brother Felix: Brother Felix to Brannoc about Brannoc."])
	banter.reset_timers()
	check("a line that needs a hero the event does not have is not said", banter.event("t", {}).is_empty())
	var thief_def: Resource = _member("thief").def
	thief_def.hero_name = "Wren the Test"  # (Put back below: this resource is shared.)
	banter.reset_timers()
	lines = banter.event("t", {"actor": "fighter", "target": "thief"})
	thief_def.hero_name = "Wren"
	check("renaming a hero changes the placeholders and nothing in the data", lines == ["Brother Felix: Brother Felix to Wren the Test about Brannoc."])
	_events({"t": _one([_line("$actor", "Mine.")])})
	check("$actor speaks as the actor", banter.event("t", {"actor": "thief"}) == ["Wren: Mine."])
	banter.reset_timers()
	check("$actor with no actor says nothing", banter.event("t", {}).is_empty())


func _check_conditions() -> void:
	_events({"c": _one([_line("mage", "target only", {"target": "thief"})])})
	check("condition `target`: the event's target must match", banter.event("c", {"actor": "fighter", "target": "thief"}).size() == 1)
	banter.reset_timers()
	check("condition `target`: another target does not", banter.event("c", {"actor": "fighter", "target": "cleric"}).is_empty())
	_events({"c": _one([_line("thief", "that was you", {"about": "target"})])})
	check("about `target`: the speaker is the target", banter.event("c", {"actor": "fighter", "target": "thief"}).size() == 1)
	banter.reset_timers()
	check("about `target`: not when somebody else is", banter.event("c", {"actor": "fighter", "target": "mage"}).is_empty())
	_events({"c": _one([_line("fighter", "skeletons", {"if": {"monster": "skeleton"}})])})
	check("condition `if`: a free context key, case-insensitive", banter.event("c", {"actor": "cleric", "monster": "Skeleton"}).size() == 1)
	banter.reset_timers()
	check("condition `if`: another value does not fit", banter.event("c", {"actor": "cleric", "monster": "Slime"}).is_empty())
	banter.reset_timers()
	check("condition `if`: a missing key does not fit", banter.event("c", {"actor": "cleric"}).is_empty())
	_events({"c": _one([_line("fighter", "calm", {"in_fight": false}), _line("fighter", "fighting", {"in_fight": true, "priority": 1})])})
	check("condition `in_fight`: out of a fight", banter.event("c", {}) == ["Brannoc: calm"])
	banter.reset_timers()
	party.fight.in_fight = true
	check("condition `in_fight`: in a fight", banter.event("c", {}) == ["Brannoc: fighting"])
	party.fight.in_fight = false


# --------------------------------------------------------------------------
# Once, replies, the gap, quiet, time
# --------------------------------------------------------------------------

func _check_flag_and_earlier() -> void:
	_events({"f": _one([_line("fighter", "after the first", {"flag": "banter.once.test_first"})])})
	check("condition `flag`: the line waits for its flag", banter.event("f", {}).is_empty())
	DungeonMap.set_flag("banter.once.test_first")
	check("condition `flag`: and is said once it is set", banter.event("f", {}) == ["Brannoc: after the first"])
	_events({"hero_revived": _one([_line("$actor", "alone", {"if": {"earlier": false}}), _line("$actor", "after another", {"if": {"earlier": true}})])})
	var fighter = _member("fighter")
	var cleric = _member("cleric")
	bus.hero_revived.emit(fighter.hero_index, true)
	check("a revival with nobody revived before it: earlier is false", banter.said == ["Brannoc: alone"])
	check("...and is remembered in the run flags", DungeonMap.has_flag("banter.revived.fighter"))
	banter.reset_timers()
	banter.said.clear()
	bus.hero_revived.emit(cleric.hero_index, true)
	check("a revival after another hero's: earlier is true", banter.said == ["Brother Felix: after another"])
	banter.reset_timers()
	banter.said.clear()
	bus.hero_revived.emit(cleric.hero_index, true)
	check("the same hero revived twice does not count as another hero", banter.said == ["Brother Felix: after another"])
	DungeonMap.flags.clear()
	banter.reset_timers()
	banter.said.clear()
	bus.hero_revived.emit(cleric.hero_index, true)
	check("a new run forgets who was revived", banter.said == ["Brother Felix: alone"])


func _check_once() -> void:
	_events({"o": _one([_line("cleric", "the first time", {"once": true, "id": "test_first"}), _line("fighter", "after that", {"priority": -1})])})
	check("a once-line is said", banter.event("o", {}) == ["Brother Felix: the first time"])
	check("...and remembered in the run flags", DungeonMap.has_flag("banter.once.test_first"))
	banter.reset_timers()
	check("...so it is not said again, and another line takes over", banter.event("o", {}) == ["Brannoc: after that"])
	_events({"o": _one([_line("cleric", "no id", {"once": true})])})
	banter.event("o", {})
	check("a once-line with no id is remembered by its place in the file", DungeonMap.has_flag("banter.once.o.0"))
	banter.reset_timers()
	check("...and stays quiet", banter.event("o", {}).is_empty())
	# Saved with the game: a flag that survives a save and load keeps the line quiet.
	var error: String = SaveGame.save(self)
	DungeonMap.flags.clear()
	banter.reset_timers()
	check("(a new run says it again)", banter.event("o", {}).size() == 1)
	banter.reset_timers()
	error += SaveGame.apply(self, SaveGame.read_file())
	check("a saved once-flag comes back with a load", error == "" and DungeonMap.has_flag("banter.once.o.0"))
	check("...and the line stays quiet after the load", banter.event("o", {}).is_empty())


func _check_replies() -> void:
	var exchange := _one([_line("cleric", "I smell evil.", {"reply": [_line("fighter", "Shut up."), _line("cleric", "I did say.", {"delay": 2.0})]})])
	_events({"x": exchange})
	banter.min_gap = 50.0  # Replies are part of the exchange: the gap never stops them.
	check("the first line is said at once", banter.event("x", {}) == ["Brother Felix: I smell evil."])
	_advance(1.0)
	check("a reply waits for its delay (1.4 s by default)", banter.said.size() == 1)
	_advance(0.5)
	check("...then is said", banter.said.size() == 2 and banter.said[1] == "Brannoc: Shut up.")
	_advance(1.8)
	check("the next reply waits its own delay after that one", banter.said.size() == 2)
	_advance(0.3)
	check("...and the exchange comes out in order", banter.said == ["Brother Felix: I smell evil.", "Brannoc: Shut up.", "Brother Felix: I did say."])

	_events({"x": exchange})
	banter.event("x", {})
	var fighter = _member("fighter")
	fighter.hp = 0
	_advance(1.5)
	fighter.hp = fighter.def.max_hp
	_advance(5.0)
	check("a reply whose speaker has died is dropped, with the rest of the exchange", banter.said.size() == 1 and banter.pending.is_empty())

	_events({"x": exchange})
	banter.event("x", {})
	banter.set_quiet("ambush")
	_advance(5.0)
	check("quiet falling mid-exchange drops the replies", banter.said.size() == 1 and banter.pending.is_empty())

	_events({"x": _one([_line("cleric", "up", {"reply": [_line("fighter", "shout", {"urgent": true})]})])})
	banter.event("x", {})
	banter.set_quiet("ambush")
	_advance(2.0)
	check("an urgent reply is still said in quiet", banter.said.size() == 2)

	_events({"x": exchange})
	banter.event("x", {})
	party.fight.in_fight = true
	_advance(1.5)
	party.fight.in_fight = false
	_events({"x": _one([_line("cleric", "talk", {"reply": [_line("fighter", "calm only", {"in_fight": false})]})])})
	banter.event("x", {})
	party.fight.in_fight = true
	_advance(2.0)
	party.fight.in_fight = false
	check("a reply that needs a calm moment is dropped when a fight has begun", banter.said.size() == 1)

	_events({"x": _one([_line("cleric", "one", {"reply": [_line("fighter", "two", {"reply": [_line("thief", "three")]})]})])})
	banter.event("x", {})
	_advance(1.5)
	_advance(1.5)
	check("a reply may have a reply of its own", banter.said == ["Brother Felix: one", "Brannoc: two", "Wren: three"])


func _check_gap() -> void:
	_events({"a": _one([_line("cleric", "first")]), "b": _one([_line("fighter", "second")]),
			"u": _one([_line("fighter", "urgent", {"urgent": true})])})
	banter.min_gap = 3.0
	check("a line is said when nothing has been said lately", banter.event("a", {}) == ["Brother Felix: first"])
	check("another event inside the gap says nothing", banter.event("b", {}).is_empty())
	_advance(2.9)
	check("...still nothing at 2.9 s", banter.event("b", {}).is_empty())
	check("an urgent line ignores the gap", banter.event("u", {}) == ["Brannoc: urgent"])
	_advance(2.9)  # The urgent line restarted the gap.
	check("the gap runs from the last line said, whatever it was", banter.event("b", {}).is_empty())
	_advance(0.2)
	check("after the gap the next event may speak", banter.event("b", {}) == ["Brannoc: second"])


func _check_quiet() -> void:
	_events({"q": _one([_line("cleric", "calm")]), "u": _one([_line("fighter", "alarm", {"urgent": true})])})
	check("status: on", banter.status() == "ON" and not banter.is_quiet())
	banter.set_quiet("ambush")
	banter.set_quiet("scene")
	check("quiet: nothing is said", banter.is_quiet() and banter.event("q", {}).is_empty())
	check("status: quiet, and why", "QUIET" in banter.status() and "ambush" in banter.status())
	banter.set_quiet("ambush", false)
	check("quiet: it stays quiet while any reason holds", banter.event("q", {}).is_empty())
	check("an urgent line speaks in quiet", banter.event("u", {}) == ["Brannoc: alarm"])
	banter.set_quiet("scene", false)
	banter.reset_timers()
	check("quiet over: banter speaks again", not banter.is_quiet() and banter.event("q", {}) == ["Brother Felix: calm"])
	banter.enabled = false
	banter.reset_timers()
	check("switched off (the test room's B key): nothing, and the status says so", banter.event("q", {}).is_empty() and banter.status() == "OFF")
	banter.enabled = true

	# The cooldown is counted in game time.
	_events({"k": _one([_line("cleric", "again")], {"cooldown": 5.0})})
	check("cooldown: said", banter.event("k", {}).size() == 1)
	_advance(4.0)
	check("cooldown: not at 4 s of game time", banter.event("k", {}).is_empty())
	_advance(1.1)
	check("cooldown: at 5.1 s it may speak again", banter.event("k", {}).size() == 1)


func _check_game_time() -> void:
	banter.set_process(true)
	await process_frame
	await process_frame
	var before: float = banter.game_time
	paused = true
	await create_timer(0.5, true).timeout  # Half a second of real time with the game paused.
	var during: float = banter.game_time
	paused = false
	await process_frame
	await process_frame
	await process_frame
	banter.set_process(false)
	check("the banter clock stops while the game is paused (not the real clock)", is_equal_approx(before, during))
	check("...and runs while it is not", banter.game_time > during)


# --------------------------------------------------------------------------
# GameEvents
# --------------------------------------------------------------------------

func _check_game_events() -> void:
	var fighter = _member("fighter")
	var cleric = _member("cleric")
	var table := {
		"monster_killed": _one([_line("$actor", "killed {actor}'s skeleton", {"if": {"monster": "Skeleton"}})]),
		"hero_died": _one([_line("cleric", "{target} is dead", {"about": "other"})]),
		"hero_revived": _one([_line("cleric", "{actor} is back", {"if": {"by_scroll": true}})]),
		"hero_hurt": _one([_line("fighter", "{actor} hurt by {name}", {"if": {"source": "monster"}})]),
		"mana_low": _one([_line("mage", "low mana")]),
		"item_picked_up": _one([_line("thief", "took a key", {"if": {"item": "Key"}})]),
		"door_unlocked": _one([_line("thief", "unlocked")]),
		"lever_pulled": _one([_line("fighter", "lever on", {"if": {"on": true}})]),
		"wall_broken": _one([_line("fighter", "wall broken")]),
		"wall_purified": _one([_line("cleric", "wall purified")]),
		"puzzle_solved": _one([_line("mage", "solved", {"if": {"puzzle": "gate_n"}})]),
		"level_completed": _one([_line("cleric", "down we go")]),
		"fight_started": _one([_line("fighter", "here we go")]),
		"fight_ended": _one([_line("cleric", "that is that")]),
	}
	var cases := [
		["monster_killed", func(): bus.monster_killed.emit(load("res://data/monsters/skeleton.tres"), Vector2i(1, 1), fighter.hero_index), "Brannoc: killed Brannoc's skeleton"],
		["hero_died", func(): bus.hero_died.emit(fighter.hero_index), "Brother Felix: Brannoc is dead"],
		["hero_revived", func(): bus.hero_revived.emit(fighter.hero_index, true), "Brother Felix: Brannoc is back"],
		["hero_hurt", func(): bus.hero_hurt.emit(cleric.hero_index, 3, "monster"), "Brannoc: Brother Felix hurt by Brannoc"],
		["mana_low", func(): bus.mana_low.emit(_member("mage").hero_index), "Fennick: low mana"],
		["item_picked_up", func(): bus.item_picked_up.emit(load("res://data/items/key.tres"), 1), "Wren: took a key"],
		["door_unlocked", func(): bus.door_unlocked.emit(Vector2i(2, 2)), "Wren: unlocked"],
		["lever_pulled", func(): bus.lever_pulled.emit(Vector2i(2, 2), 0, true), "Brannoc: lever on"],
		["wall_broken", func(): bus.wall_broken.emit(Vector2i(2, 6)), "Brannoc: wall broken"],
		["wall_purified", func(): bus.wall_purified.emit(Vector2i(16, 4)), "Brother Felix: wall purified"],
		["puzzle_solved", func(): bus.puzzle_solved.emit("gate_n"), "Fennick: solved"],
		["level_completed", func(): bus.level_completed.emit(), "Brother Felix: down we go"],
		["fight_started", func(): bus.fight_started.emit(), "Brannoc: here we go"],
		["fight_ended", func(): bus.fight_ended.emit(), "Brother Felix: that is that"],
	]
	for c in cases:
		_events(table)
		c[1].call()
		check("GameEvents.%s makes the banter event of that name" % c[0], banter.said == [c[2]])
	_events(table)
	bus.monster_killed.emit(load("res://data/monsters/skeleton.tres"), Vector2i(1, 1), -1)
	check("a kill with no hero to credit has no $actor to speak", banter.said.is_empty())
	_events(table)
	bus.lever_pulled.emit(Vector2i(2, 2), 0, false)
	bus.puzzle_solved.emit("another")
	check("the context reaches the conditions: wrong values say nothing", banter.said.is_empty())


## The signals as the game really sends them, not emitted by hand.
func _check_game_events_from_the_game() -> void:
	var dungeon: Node = get_first_node_in_group("dungeon")
	_events({"lever_pulled": _one([_line("fighter", "pulled it", {"if": {"on": true}})]),
			"hero_died": _one([_line("cleric", "{actor} died", {"about": "other"})])})
	dungeon.pull_lever(Vector2i(19, 7), 0)
	check("pulling a lever in the game makes its banter", banter.said == ["Brannoc: pulled it"])
	var thief = _member("thief")
	banter.reset_timers()
	banter.said.clear()
	party.hurt(thief, 999, "test")
	check("a hero dying in the game makes its banter", banter.said == ["Brother Felix: Wren died"])
	banter.said.clear()
	await process_frame  # (The wipe check runs at the end of the frame.)
	party.heal(thief, thief.def.max_hp, "test", true)
