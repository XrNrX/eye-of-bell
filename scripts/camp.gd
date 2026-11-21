extends CanvasLayer
## Making camp (roadmap 7h.2; rules in docs/combat_design.md "Making camp"). A bedroll used where the party may (Party.camp_refusal) calls
## begin(); the 3D view is then covered by a near-black camp screen round a small fire with a bedroll for each hero, and for REST_SECONDS
## every living hero's HP and mana climb evenly to full. The rest ends by itself, by the Stop button, by any movement (Player.command asks
## consumes_move), or when a fight breaks it (interrupted: GameEvents.camp_ended(true)); what was gained is kept.
##
## Begin also: clears the Cleric's "shaken" and sickness, gives the rest of a running meal at once, clears spell recasts and starts
## Party.camping, which pauses every burn timer (Party._tick_lights, light_field.gd) and the slow mana regeneration. The end saves the game
## (not after an interruption; SaveGame refuses the test room and built levels).
##
## **Cooking (7h.3):** while camped, food with a `cooks_into` (raw rat meat, mouldy bread) can be cooked: the COOK button cooks every such stack the
## party carries, one by one (COOK_STEP s apart, each with a sizzle and a log line), or hold the food on the cursor and click the fire. Cooked
## food heals more and faster and carries no sickness (data/items/cooked_rat_meat.tres, toasted_bread.tres). A cook may burn the food
## (BURN_CHANCE): the same result and a line that says so.
##
## A bedroll is a button: click it and that hero's pack and character sheet open (the inventory pauses the game, and so the camp). A
## hero who can level up will say so there once levelling exists (Party.level_up_ready, Phase 7i: nothing yet).
##
## A node made by game_view.gd, group "camp", canvas layer 3 (over the 3D view and its effects, under the frame, so the party panels stay
## usable). Art: art/camp/ (tools/art/gen_camp.py); the camp's numbers are the consts below.

const UiLayout := preload("res://scripts/ui_layout.gd")
const Events := preload("res://scripts/game_events.gd")
const SaveGame := preload("res://scripts/save_game.gd")
const ItemStack := preload("res://scripts/item_stack.gd")
const CombatRules := preload("res://scripts/combat_rules.gd")

const REST_SECONDS := 30.0
const COOK_STEP := 0.8          # Seconds between one stack and the next when cooking everything.
const BURN_CHANCE := 0.15       # A cosmetic mishap: the food is cooked all the same, and the line says it was burnt.
const SIZZLE_SCALE := 1.1
const MOVE_LOCK := 0.35         # After the rest ends, a held movement key must not walk the party at once.
const DIR := "res://art/camp/"
const FIRE_AT := Vector2(208, 140)   # Where the fire stands in the camp screen (view units, 416x260).
const FIRE_SCALE := 1.5
const FLAME_WIDTH := 0.7
const BED_SIZE := Vector2(112, 84)
const BED_SPOTS := [Vector2(24, 44), Vector2(280, 44), Vector2(24, 138), Vector2(280, 138)]  # Hero positions 0 and 1 (the front pair) behind the fire.
const BG := Color(0.035, 0.028, 0.045)
const TEXT := Color("9c9278")        # bone_500
const GOLD := Color("f5cf80")        # torch_300
const INK := Color("0b0a10")
const GLOW := [Color(0.6, 0.37, 0.11, 0.05), Color(0.6, 0.37, 0.11, 0.07), Color(0.85, 0.6, 0.21, 0.08), Color(0.96, 0.81, 0.5, 0.07)]  # Stepped, never smooth.
const GLOW_RADII := [150.0, 112.0, 76.0, 44.0]

var active := false
var elapsed := 0.0
var move_lock := 0.0
var party: Node
var start_hp := {}      # Member -> HP when the rest began
var start_mana := {}
var anim_t := 0.0
var _hidden := []       # Nodes in "popup_avoid" (the corner map) hidden while camping: it would sit over a bedroll.

var root: Control
var picture: Control
var status: Label
var beds := []          # [{root, bed, portrait, name, hp_fill, mana_fill, note}] by hero position
var stop_button: Button
var cook_button: Button
var fire_hit: Control   # The fire as a click target (food held on the cursor).
var _cook_queue := []   # Entries still to cook ({stack, member, where, index}), a stack every COOK_STEP.
var _cook_wait := 0.0
var sizzles := []       # [{t}] sizzle animations playing over the fire
var sizzle_sheet: Texture2D
var sizzle_info := {"frames": 12, "fps": 14.0, "frame_w": 74, "frame_h": 69}
var textures := {}
var flame_sheet: Texture2D
var flame_info := {"frames": 8, "fps": 10.0, "frame_w": 48, "frame_h": 76}


func _ready() -> void:
	layer = 3
	add_to_group("camp")


## Make camp. False if nobody is alive to rest. The caller has checked Party.camp_refusal().
func begin() -> bool:
	party = get_tree().get_first_node_in_group("party")
	if party == null or active:
		return false
	var living: Array = party.members.filter(func(m): return m.is_alive())
	if living.is_empty():
		return false
	active = true
	elapsed = 0.0
	party.camping = true
	for m in living:
		m.shaken_left = 0.0      # A camp clears "shaken", sickness...
		m.sick_left = 0.0
		m.sick_acc = 0.0
		if m.food_left > 0.0:     # ...gives the rest of a running meal at once...
			party.heal(m, int(ceil(m.food_left * m.food_rate - 0.001)), "food")
		m.food_left = 0.0
		m.food_acc = 0.0
		m.spell_wait.clear()      # ...and clears the spell recasts.
		start_hp[m] = m.hp        # The rest climbs from here (the meal's last healing is already in).
		start_mana[m] = m.mana
	_build_screen()
	_refresh_beds()
	root.visible = true
	for node in get_tree().get_nodes_in_group("popup_avoid"):
		if node is CanvasItem and node.visible:
			node.visible = false
			_hidden.append(node)
	Events.send(get_tree(), "camp_made", [])
	get_tree().call_group("hud", "show_message", "The party makes camp.")
	return true


func _process(delta: float) -> void:
	move_lock = maxf(0.0, move_lock - delta)
	if not active:
		return
	anim_t += delta
	var living: Array = party.members.filter(func(m): return m.is_alive())
	if living.is_empty():
		end(true)
		return
	if party.fight != null and party.fight.in_fight:
		end(true)
		return
	elapsed += delta
	rest_to(minf(1.0, elapsed / REST_SECONDS))
	_tick_cooking(delta)
	_refresh_beds()
	_refresh_cook_button()
	picture.queue_redraw()
	if elapsed >= REST_SECONDS:
		end(false)


## Bring every living hero to this share (0..1) of the way from where they started to full HP and mana: whole HP, evenly. Never lowers
## anything (a hero hurt by something else while resting keeps the lower value only if the rest is already ahead of it).
func rest_to(fraction: float) -> void:
	for m in start_hp:
		if not m.is_alive():
			continue
		var want: int = start_hp[m] + int(round((m.def.max_hp - start_hp[m]) * fraction))
		if want > m.hp:
			party.heal(m, want - m.hp, "rest")
		if m.def.max_mana > 0:
			m.mana = maxf(m.mana, start_mana[m] + (m.def.max_mana - start_mana[m]) * fraction)


## The rest is over: it ran out, the player stopped it (interrupted false), or a fight broke it (true). Keeps what was gained.
func end(interrupted := false) -> void:
	if not active:
		return
	active = false
	party.camping = false
	start_hp.clear()
	start_mana.clear()
	_cook_queue.clear()
	sizzles.clear()
	if root != null:
		root.visible = false
	for node in _hidden:
		if is_instance_valid(node):
			node.visible = true
	_hidden.clear()
	move_lock = MOVE_LOCK
	Events.send(get_tree(), "camp_ended", [interrupted])
	get_tree().call_group("hud", "show_message", "The rest is broken." if interrupted else "The party breaks camp.")
	if not interrupted:
		SaveGame.save(get_tree())  # "Camping saves the game." (Refused quietly in the test room.)


func stop() -> void:
	end(false)


## Player.command asks this before any step or turn: true means the key was spent ending the rest (or came just after it), so the party
## stays where it is.
func consumes_move() -> bool:
	if active:
		end(false)
		return true
	return move_lock > 0.0


# --------------------------------------------------------------------------
# The camp screen
# --------------------------------------------------------------------------

func _tex(file: String) -> Texture2D:
	if not textures.has(file):
		textures[file] = load(DIR + file) if ResourceLoader.exists(DIR + file) else null
	return textures[file]


func _build_screen() -> void:
	if root != null:
		return
	root = Control.new()
	root.name = "CampScreen"
	root.position = UiLayout.VIEW.position
	root.size = UiLayout.VIEW.size
	root.clip_contents = true
	root.mouse_filter = Control.MOUSE_FILTER_STOP   # The camp takes the view's clicks: nothing is picked up from the floor while resting.
	root.visible = false
	add_child(root)
	var bg := ColorRect.new()
	bg.color = BG
	bg.size = root.size
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bg)
	picture = Control.new()
	picture.size = root.size
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	picture.draw.connect(_draw_fire)
	root.add_child(picture)
	var sheet := _tex("flame_sheet.png")
	flame_sheet = sheet
	if FileAccess.file_exists(DIR + "flame_sheet.json"):
		var info = JSON.parse_string(FileAccess.get_file_as_string(DIR + "flame_sheet.json"))
		if info is Dictionary:
			flame_info = info
	for i in 4:
		beds.append(_make_bed(i))
	var title := _label("CAMP", GOLD)
	title.position = Vector2(0, 14)
	title.size = Vector2(root.size.x, 10)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(title)
	status = _label("", TEXT)
	status.position = Vector2(0, 28)
	status.size = Vector2(root.size.x, 10)
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(status)
	cook_button = Button.new()
	cook_button.text = "COOK"
	cook_button.size = Vector2(100, 16)
	cook_button.position = Vector2(root.size.x * 0.5 - 104.0, root.size.y - 32.0)
	cook_button.focus_mode = Control.FOCUS_NONE
	cook_button.add_theme_font_size_override("font_size", 8)
	cook_button.tooltip_text = "Cook every raw food the party carries."
	cook_button.pressed.connect(func(): cook_all())
	root.add_child(cook_button)
	fire_hit = Control.new()
	fire_hit.position = FIRE_AT + Vector2(-54, -78)
	fire_hit.size = Vector2(108, 104)
	fire_hit.mouse_filter = Control.MOUSE_FILTER_STOP
	fire_hit.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	fire_hit.tooltip_text = "Click food on the fire to cook it."
	fire_hit.gui_input.connect(_fire_input)
	root.add_child(fire_hit)
	if ResourceLoader.exists("res://art/spells/cooking/sizzle_sheet.png"):
		sizzle_sheet = load("res://art/spells/cooking/sizzle_sheet.png")
	if sizzle_sheet != null and FileAccess.file_exists("res://art/spells/cooking/sizzle_sheet.json"):
		var info = JSON.parse_string(FileAccess.get_file_as_string("res://art/spells/cooking/sizzle_sheet.json"))
		if info is Dictionary:
			sizzle_info = info
	stop_button = Button.new()
	stop_button.text = "STOP RESTING"
	stop_button.size = Vector2(112, 16)
	stop_button.position = Vector2(root.size.x * 0.5 + 4.0, root.size.y - 32.0)
	stop_button.add_theme_font_size_override("font_size", 8)
	stop_button.focus_mode = Control.FOCUS_NONE
	stop_button.pressed.connect(stop)
	root.add_child(stop_button)
	var hint := _label("CLICK A BEDROLL: PACK AND SHEET", Color(TEXT, 0.6))
	hint.position = Vector2(0, root.size.y - 46.0)
	hint.size = Vector2(root.size.x, 10)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(hint)


func _label(text: String, colour: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", colour)
	l.add_theme_color_override("font_outline_color", INK)
	l.add_theme_constant_override("outline_size", 2)
	l.add_theme_font_size_override("font_size", 8)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## One hero's bedroll: the picture (the pillow toward the edge of the screen), their portrait on the pillow, their name, small HP and mana
## bars and a note. A press opens their pack and sheet.
func _make_bed(i: int) -> Dictionary:
	var spot: Vector2 = BED_SPOTS[i]
	var bed := Control.new()
	bed.position = spot
	bed.size = BED_SIZE
	bed.mouse_filter = Control.MOUSE_FILTER_STOP
	bed.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	root.add_child(bed)
	var picture_rect := TextureRect.new()
	picture_rect.texture = _tex("bedroll.png")
	picture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture_rect.stretch_mode = TextureRect.STRETCH_SCALE
	picture_rect.flip_h = (i % 2 == 0)   # The art's pillow is on the right: the left-hand beds turn it outward.
	picture_rect.position = Vector2(8, 4)
	picture_rect.size = Vector2(96, 60)
	picture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bed.add_child(picture_rect)
	var portrait := TextureRect.new()
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_SCALE
	portrait.size = Vector2(26, 26)
	portrait.position = Vector2(8 + 4, 4 + 2) if i % 2 == 0 else Vector2(8 + 96 - 30, 4 + 2)
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bed.add_child(portrait)
	var name_label := _label("", TEXT)
	name_label.position = Vector2(0, 62)
	name_label.size = Vector2(BED_SIZE.x, 10)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bed.add_child(name_label)
	var hp_back := ColorRect.new()
	hp_back.color = INK
	hp_back.position = Vector2(20, 74)
	hp_back.size = Vector2(72, 4)
	hp_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bed.add_child(hp_back)
	var hp_fill := ColorRect.new()
	hp_fill.color = Color("7a3030")
	hp_fill.position = Vector2(21, 75)
	hp_fill.size = Vector2(70, 2)
	hp_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bed.add_child(hp_fill)
	var mana_fill := ColorRect.new()
	mana_fill.color = Color("d99a36")
	mana_fill.position = Vector2(21, 77)
	mana_fill.size = Vector2(70, 1)
	mana_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bed.add_child(mana_fill)
	var note := _label("", GOLD)
	note.position = Vector2(0, 30)   # On the blanket itself, so it is plainly that bedroll's.
	note.size = Vector2(BED_SIZE.x, 10)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bed.add_child(note)
	bed.gui_input.connect(_bed_input.bind(i))
	bed.mouse_entered.connect(func(): bed.modulate = Color(1.25, 1.2, 1.1))
	bed.mouse_exited.connect(func(): bed.modulate = Color.WHITE)
	return {"root": bed, "bed": picture_rect, "portrait": portrait, "name": name_label, "hp_fill": hp_fill, "mana_fill": mana_fill, "note": note}


func _bed_input(event: InputEvent, i: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		get_tree().call_group("inventory", "show_screen", i, true)
		get_viewport().set_input_as_handled()


## Keep each bedroll in step with its hero: portrait, name, bars, and a note ("FALLEN", or that they can level up once that exists).
func _refresh_beds() -> void:
	if party == null:
		return
	for i in beds.size():
		var b: Dictionary = beds[i]
		var m = party.members[i] if i < party.members.size() else null
		b.root.visible = m != null
		if m == null:
			continue
		var alive: bool = m.is_alive()
		b.name.text = m.short_name(12)
		b.portrait.texture = m.def.portrait if alive else m.def.portrait_dead
		b.bed.modulate = Color.WHITE if alive else Color(0.5, 0.5, 0.55)
		b.hp_fill.size.x = 70.0 * float(m.hp) / maxf(1.0, float(m.def.max_hp))
		b.mana_fill.size.x = 70.0 * m.mana / maxf(1.0, float(m.def.max_mana)) if m.def.max_mana > 0 else 0.0
		if not alive:
			b.note.text = "FALLEN"
		elif party.has_method("level_up_ready") and party.level_up_ready(m):
			b.note.text = "READY TO LEVEL"   # (Phase 7i builds Party.level_up_ready.)
		else:
			b.note.text = ""
	status.text = "RESTING  %d / %d" % [int(minf(elapsed, REST_SECONDS)), int(REST_SECONDS)]


## The fire: a stepped glow, the pit, the kindling, the flame, and the front logs over its base (the same layers as the 3D camp).
func _draw_fire() -> void:
	var flicker := 1.0 + 0.04 * sin(anim_t * 9.0) + 0.03 * sin(anim_t * 23.0)
	picture.draw_set_transform(FIRE_AT + Vector2(0, 14), 0.0, Vector2(1.0, 0.6))
	for i in GLOW.size():
		picture.draw_circle(Vector2.ZERO, GLOW_RADII[i] * flicker, GLOW[i])
	picture.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var pit := _tex("pit.png")
	var front := _tex("pit_front.png")
	var kindling := _tex("kindling.png")
	if pit == null:
		return
	var s := FIRE_SCALE
	var pit_size := Vector2(pit.get_width(), pit.get_height()) * s
	var pit_pos := FIRE_AT - Vector2(pit_size.x * 0.5, pit_size.y * 0.5 - 8.0)
	picture.draw_texture_rect(pit, Rect2(pit_pos, pit_size), false)
	if flame_sheet != null:
		var frames := int(flame_info.frames)
		var fw := float(flame_info.frame_w)
		var fh := float(flame_info.frame_h)
		var f := int(anim_t * float(flame_info.fps)) % frames
		var size := Vector2(fw * FLAME_WIDTH, fh) * s * 0.95
		# The frame's anchor is 18 px above its bottom edge: stand it on the middle of the logs.
		var base := FIRE_AT + Vector2(0, 14)
		picture.draw_texture_rect_region(flame_sheet, Rect2(base - Vector2(size.x * 0.5, size.y - 18.0 * s * 0.95), size), Rect2(f * fw, 0, fw, fh))
	if front != null:
		picture.draw_texture_rect(front, Rect2(pit_pos, pit_size), false)
	if kindling != null:
		var ks := Vector2(kindling.get_width(), kindling.get_height()) * s * 0.7
		picture.draw_texture_rect(kindling, Rect2(FIRE_AT + Vector2(-ks.x * 0.5, 12.0 - ks.y * 0.4), ks), false)
	if sizzle_sheet != null:
		var zw := float(sizzle_info.frame_w)
		var zh := float(sizzle_info.frame_h)
		for z in sizzles:
			var frame := int(z.t * float(sizzle_info.fps))
			if frame < int(sizzle_info.frames):
				var anchor := FIRE_AT + Vector2(0, -8)  # The frame's anchor (43, 27) sits just above the logs.
				picture.draw_texture_rect_region(sizzle_sheet, Rect2(anchor - Vector2(43.0, 27.0) * SIZZLE_SCALE, Vector2(zw, zh) * SIZZLE_SCALE), Rect2(frame * zw, 0, zw, zh))


# --------------------------------------------------------------------------
# Cooking (7h.3)
# --------------------------------------------------------------------------

## Every stack of food the party carries that can be cooked (hands, packs and quick slots, the fallen's too): [{stack, member, where, index}].
func cookables() -> Array:
	var out := []
	if party == null:
		return out
	for m in party.members:
		for i in m.hands.size():
			if m.hands[i] != null and m.hands[i].def.can_cook():
				out.append({"stack": m.hands[i], "member": m, "where": "hand", "index": i})
		for i in m.backpack.size():
			if m.backpack[i] != null and m.backpack[i].def.can_cook():
				out.append({"stack": m.backpack[i], "member": m, "where": "pack", "index": i})
		for i in m.quick.size():
			if m.quick[i] != null and m.quick[i].def.can_cook():
				out.append({"stack": m.quick[i], "member": m, "where": "quick", "index": i})
	return out


## How many raw items (not stacks) could be cooked now.
func cookable_count() -> int:
	var n := 0
	for e in cookables():
		n += e.stack.count
	return n


## The COOK button: cook everything raw the party carries, a stack at a time. Returns how many stacks are queued (0 outside a camp).
func cook_all() -> int:
	if not active:
		return 0
	_cook_queue = cookables()
	_cook_wait = 0.0   # The first one at once.
	_refresh_cook_button()
	return _cook_queue.size()


func _tick_cooking(delta: float) -> void:
	if not _cook_queue.is_empty():
		_cook_wait -= delta
		if _cook_wait <= 0.0:
			_cook_next()
			_cook_wait = COOK_STEP
	for z in sizzles:
		z.t += delta
	sizzles = sizzles.filter(func(z): return int(z.t * float(sizzle_info.fps)) < int(sizzle_info.frames))


## Cook the next queued stack, if it is still where it was (the player may have moved it meanwhile).
func _cook_next() -> void:
	while not _cook_queue.is_empty():
		var e: Dictionary = _cook_queue.pop_front()
		var m = e.member
		var here = null
		match e.where:
			"hand": here = m.hands[e.index]
			"pack": here = m.backpack[e.index]
			"quick": here = m.quick[e.index]
		if here == e.stack and here.def.can_cook():
			var cooked := ItemStack.of(here.def.cooks_into, here.count)
			match e.where:
				"hand": m.hands[e.index] = cooked
				"pack": m.backpack[e.index] = cooked
				"quick": party.set_quick(m.slot, e.index, cooked)
			_cooked(here.def, m)
			return


## Click on the fire: food held on the cursor is cooked, a held thing that will not cook is refused, an empty hand is told what to do.
func _fire_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	var cursor := get_tree().get_first_node_in_group("cursor")
	if cursor == null:
		return
	get_viewport().set_input_as_handled()
	cook_held(cursor)


## The cursor's held stack goes on the fire. Returns true if it was cooked.
func cook_held(cursor: Node) -> bool:
	if cursor.held == null:
		get_tree().call_group("hud", "show_message", "Hold food to cook it.")
		return false
	if not cursor.held.def.can_cook():
		get_tree().call_group("hud", "show_message", "That will not cook.")
		return false
	var raw: Resource = cursor.held.def
	cursor.hold(ItemStack.of(raw.cooks_into, cursor.held.count))
	var cook = null
	for m in party.members:
		if m.is_alive():
			cook = m
			break
	_cooked(raw, cook, -1)
	return true


## One stack has been cooked: the sizzle (picture and sound), the log line (a cook may burn it), and the news.
func _cooked(raw: Resource, cook, hero_index := -2) -> void:
	sizzles.append({"t": 0.0})
	get_tree().call_group("audio", "play", "sizzle")
	var who: String = cook.short_name() if cook != null else "Someone"
	var food: String = raw.display_name.to_lower().replace("raw ", "")
	var burnt: bool = CombatRules.rng().randf() < BURN_CHANCE
	get_tree().call_group("hud", "show_message", ("%s burns the %s. Nobody mentions it." if burnt else "%s cooks the %s.") % [who, food])
	var hero: int = hero_index
	if hero == -2:
		hero = cook.hero_index if cook != null else -1
	Events.send(get_tree(), "food_cooked", [raw, hero])


func _refresh_cook_button() -> void:
	if cook_button == null:
		return
	var n := cookable_count()
	cook_button.text = "COOK (%d)" % n if n > 0 else "NOTHING TO COOK"
	cook_button.disabled = n == 0 or not _cook_queue.is_empty()
