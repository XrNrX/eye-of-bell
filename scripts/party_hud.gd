extends CanvasLayer
## Party HUD: a 2x2 grid of hero panels (portrait, two quick slots, name, HP bar, mana
## bar, two hand buttons, cooldown bar), floating damage numbers when a hero is hit,
## and a red screen flash. Talks to the party through its signals, group and polling.
##
## Each hand button shows the item in that hand (an empty hand shows the fist) and
## acts with it (Party.act): swing, throw, or -- for a spellbook or holy symbol --
## open the spell pop-up (spell_menu.gd). Dragging a portrait (or name) onto another
## panel swaps the two characters' positions (see "Formation drag" below). Picking a spell that needs a hero (Shield,
## Heal) enters target mode: the next portrait click casts it. Right-click, Esc or a
## click anywhere else cancels the pop-up or target mode. Otherwise a portrait click
## opens that hero's inventory (group "inventory"). The game keeps running throughout.

const CombatRules := preload("res://scripts/combat_rules.gd")
const QuickSlot := preload("res://scripts/quick_slot.gd")
const SpellMenu := preload("res://scripts/spell_menu.gd")
const SpellDef := preload("res://scripts/spell_def.gd")
const UiLayout := preload("res://scripts/ui_layout.gd")
const FeelConfigScript := preload("res://scripts/combat_feel_config.gd")
const StackCount := preload("res://scripts/stack_count.gd")
const SpellEffectsConfig := preload("res://scripts/spell_effects_config.gd")
const Settings := preload("res://scripts/settings.gd")

# Sizes are in 640x360 pixels. The art is drawn at 2x (see ui_layout.gd), so each of these is the
# art's own size: portraits 64x64, hand buttons 32x32.
const PORTRAIT_SIZE := Vector2(64, 64)
const HAND_SIZE := Vector2(32, 32)
const PANEL_SIZE := Vector2(98, 170)     # Two across, two down fill the party window (ui_layout.gd).
# Content margins (left, top, right, bottom). Everything in a panel sits on EVEN pixel
# coordinates, so the 2x2 blocks of the art line up with the frame's (a block starting on an
# odd pixel would straddle two of the frame's blocks). The inner width of 88 centres the 64-wide
# portrait, the 56-wide quick slots and the 68-wide hands on even x; every row height and gap is even.
const MARGIN_LEFT := 6
const MARGIN_TOP := 4
const MARGIN_RIGHT := 4
const MARGIN_BOTTOM := 4
const ROW_GAP := 2                       # Between the rows inside a panel.
const HP_HEIGHT := 6
const MANA_HEIGHT := 4
const COOL_HEIGHT := 4

const HAND_READY := Color(1, 1, 1)
const HAND_COOLING := Color(0.35, 0.33, 0.38)
const PANEL_BG := Color(0.078, 0.075, 0.106, 0.88)  # Palette stone_900.
const PANEL_EDGE := Color(0.192, 0.188, 0.235)        # Palette stone_700.
const HP_FILL := Color(0.486, 0.267, 0.149)            # Palette rust_500.
const HP_BACK := Color(0.043, 0.039, 0.063)          # Palette ink.
const COOL_FILL := Color(0.482, 0.478, 0.533)        # Palette stone_300.
const HIT_COLOUR := Color(0.659, 0.404, 0.227)          # Palette rust_300.
const MISS_COLOUR := Color(0.667, 0.663, 0.706)         # Palette stone_100.
const MANA_FILL := Color(0.851, 0.604, 0.212)        # Palette torch_500 (the palette has no blue).
const BUFF_EDGE := MANA_FILL                         # Outline on a buffed hero's portrait.
const HURT_FLASH_TIME := 0.3  # How long the portrait shows its red-tinted variant.

var feel_cfg: Resource = FeelConfigScript.get_config()  # data/combat_feel.tres
@onready var flash: ColorRect = %Flash
@onready var panels_grid: GridContainer = %Panels

var party: Node
var panels := {}  # slot -> {root, portrait, buff_ring, quick, hp_bar, mana_bar, hands, cool_bar}

# Casting state: the open pop-up, and the spell waiting for a target hero.
var menu: Control
var menu_owner := {}   # {"caster", "hand"} for the open pop-up.
var pending := {}      # {"caster", "hand", "spell"} in target mode.
var catcher: Control   # Full-screen, under the panels: a click on it cancels.

# Formation drag: press on a portrait/name, move past DRAG_THRESHOLD, release over another
# panel. The release position picks the target (not Godot's control routing, which sends
# a release to the control that got the press).
const DRAG_THRESHOLD := 4.0       # Pixels (in the 640x360 space) before a press becomes a drag.
const DRAG_GHOST := Color(1, 1, 1, 0.55)
const DROP_EDGE := Color(0.851, 0.604, 0.212)  # Palette torch_500, like the mana bar.
var press_slot := -1               # Position pressed on, -1 if none.
var press_pos := Vector2.ZERO
var dragging := false
var drag_from := -1
var drag_over := -1                # Position it would swap with, or -1.
var ghost: TextureRect
var drag_just_ended := false       # So the click that ends a drag isn't also a click.


func _ready() -> void:
	party = get_tree().get_first_node_in_group("party")
	# The red hit flash covers the 3D view only, not the whole screen.
	flash.set_anchors_preset(Control.PRESET_TOP_LEFT)
	flash.position = UiLayout.VIEW.position
	flash.size = UiLayout.VIEW.size
	panels_grid.position = UiLayout.PARTY.position
	if party == null:
		return
	for m in party.members:
		panels[m.slot] = _make_panel(m)
		_update_hp(m.slot)
	party.hp_changed.connect(_update_hp)
	party.hero_hit.connect(_on_hero_hit)
	party.formation_changed.connect(_on_formation_changed)
	party.holy_cast.connect(_on_holy_cast)

	catcher = Control.new()
	catcher.set_anchors_preset(Control.PRESET_FULL_RECT)
	catcher.mouse_filter = Control.MOUSE_FILTER_STOP
	catcher.visible = false
	catcher.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed:
			catcher.accept_event()
			cancel_casting())
	add_child(catcher)
	move_child(catcher, panels_grid.get_index())  # Under the panels, so portraits still get clicks.


func _process(_delta: float) -> void:
	if party == null:
		return
	drag_just_ended = false
	var cursor = get_tree().get_first_node_in_group("cursor")
	var holding: bool = cursor != null and cursor.is_holding()
	for m in party.members:
		var p: Dictionary = panels[m.slot]
		# A hand cooling down can still be clicked to put an item in it; a dead hero's can't.
		var cooling: bool = (m.cooldown_left > 0.0 and not holding) or not m.is_alive()
		for i in p.hands.size():
			var hand: TextureButton = p.hands[i]
			hand.disabled = cooling
			hand.modulate = HAND_COOLING if cooling else HAND_READY
			_show_hand(m, i, hand)
		var total := CombatRules.hero_cooldown(m.def.speed)
		p.cool_bar.value = (m.cooldown_left / total) * 100.0 if m.is_alive() else 0.0
		p.mana_bar.value = m.mana
		p.buff_ring.visible = not m.buffs.is_empty()
	# Close the pop-up / target mode if the caster died or the item left their hand.
	for state in [menu_owner, pending]:
		if not state.is_empty() and party.action_for(state.caster, state.hand) != party.Act.SPELLS:
			cancel_casting()


# --------------------------------------------------------------------------
# The cleric's holy symbol glowing while Heal or Bless is cast
# --------------------------------------------------------------------------

const HOLY_GLOW_SHEET := "res://art/items/holy_symbol_glow.png"  # Three frames of 32x32: dim, medium, bright.
var holy_glows := {}  # hand TextureButton -> {"glow": TextureRect, "tween": Tween}


## Light the holy symbol in that hand slot: a gold glow (added over the icon, so the metal still
## looks worn) pulsing for the length of the cast, a few light motes rising, then fading out.
## "Reduce flashing" makes it one steady swell with no pulsing and no motes.
func _on_holy_cast(slot: int, hand_index: int, _spell: Resource) -> void:
	if not panels.has(slot) or not ResourceLoader.exists(HOLY_GLOW_SHEET):
		return
	var hand: TextureButton = panels[slot].hands[hand_index]
	var c := SpellEffectsConfig.get_config()
	var entry: Dictionary = holy_glows.get(hand, {})
	if entry.is_empty():
		var sheet: Texture2D = load(HOLY_GLOW_SHEET)
		var frames: Array[Texture2D] = []
		for i in 3:
			var atlas := AtlasTexture.new()
			atlas.atlas = sheet
			atlas.region = Rect2(i * 32, 0, 32, 32)
			frames.append(atlas)
		var glow := TextureRect.new()
		glow.top_level = true  # Not under the hand button: a cooling hand is dimmed and the glow must not be.
		glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		glow.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		glow.size = Vector2(32, 32)
		var mat := CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		glow.material = mat
		glow.set_meta("frames", frames)
		panels[slot].root.add_child(glow)
		entry = {"glow": glow, "tween": null}
		holy_glows[hand] = entry
	var glow: TextureRect = entry.glow
	if entry.tween != null and entry.tween.is_valid():
		entry.tween.kill()
	var reduced: bool = Settings.reduce_flashing
	var seconds: float = c.holy_hud_seconds
	var fade: float = c.holy_hud_fade
	var pulses: int = maxi(1, c.holy_hud_pulses)
	glow.visible = true
	var tween := create_tween()
	entry.tween = tween
	tween.tween_method(func(t: float) -> void:
		var k: float
		if t < seconds:
			if reduced:
				k = minf(1.0, t / (seconds * 0.5)) * 0.7  # One steady swell.
			else:
				k = lerpf(0.4, 1.0, 0.5 - 0.5 * cos(TAU * pulses * t / seconds))
		else:
			var end_k: float = 0.7 if reduced else lerpf(0.4, 1.0, 0.5 - 0.5 * cos(TAU * pulses))
			k = end_k * clampf(1.0 - (t - seconds) / fade, 0.0, 1.0)
		_set_holy_glow(hand, glow, k), 0.0, seconds + fade, seconds + fade)
	tween.tween_callback(func():
		glow.visible = false)
	if not reduced and c.holy_hud_motes > 0:
		_holy_motes(glow, c, seconds)


## One frame of the glow: the frame shows how strong it is, and it follows its hand button.
func _set_holy_glow(hand: TextureButton, glow: TextureRect, k: float) -> void:
	var frames: Array = glow.get_meta("frames")
	glow.global_position = hand.global_position
	glow.texture = frames[0 if k < 0.45 else (1 if k < 0.75 else 2)]
	glow.modulate = Color(1, 1, 1, clampf(k * 1.3, 0.0, 1.0))


func _holy_motes(glow: Control, c: Resource, seconds: float) -> void:
	var motes := CPUParticles2D.new()
	motes.position = Vector2(16, 20)
	motes.amount = maxi(1, int(c.holy_hud_motes * 2))
	motes.lifetime = c.holy_hud_mote_seconds
	motes.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	motes.emission_rect_extents = Vector2(7, 5)
	motes.direction = Vector2(0, -1)
	motes.spread = 12.0
	motes.gravity = Vector2.ZERO
	motes.initial_velocity_min = c.holy_hud_mote_rise * 0.6
	motes.initial_velocity_max = c.holy_hud_mote_rise
	motes.scale_amount_min = 2.0  # 2x2 pixel specks, like the art.
	motes.scale_amount_max = 2.0
	motes.color = c.holy_hud_mote_color
	motes.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	glow.add_child(motes)
	motes.emitting = true
	get_tree().create_timer(seconds).timeout.connect(func():
		if is_instance_valid(motes):
			motes.emitting = false)
	get_tree().create_timer(seconds + c.holy_hud_mote_seconds + 0.2).timeout.connect(func():
		if is_instance_valid(motes):
			motes.queue_free())


## Draw what's in a hand: the item's small icon (with a count for a stack of darts),
## or the fist when it's empty.
func _show_hand(m, i: int, hand: TextureButton) -> void:
	var stack = m.hands[i]
	var tex: Texture2D = m.def.hand_icon
	if stack:
		tex = stack.def.hud_texture()
	if hand.texture_normal != tex:
		hand.texture_normal = tex
	hand.get_child(0).set_count(stack.count if stack else 0)
	match party.action_for(m.slot, i):
		party.Act.MELEE: hand.tooltip_text = "Attack"
		party.Act.THROW: hand.tooltip_text = "Throw"
		party.Act.SPELLS: hand.tooltip_text = "Cast"
		party.Act.CANT_REACH: hand.tooltip_text = "Can't reach"
		_: hand.tooltip_text = ""


# --------------------------------------------------------------------------
# Hands and casting
# --------------------------------------------------------------------------

func _on_hand(slot: int, hand: int) -> void:
	# An item on the cursor: put it in this hand (top up, or swap) instead of acting.
	var cursor = get_tree().get_first_node_in_group("cursor")
	if cursor and cursor.is_holding():
		cancel_casting()
		var refused: String = party.place_in_hand(slot, hand, cursor)
		if refused != "":
			get_tree().call_group("hud", "show_message", refused)
		return
	if party.action_for(slot, hand) != party.Act.SPELLS:
		cancel_casting()
		party.act(slot, hand)
		return
	cancel_casting()
	if party.member(slot).cooldown_left > 0.0:
		return
	var why: String = party.cast_refusal(slot, hand)
	if why != "":
		get_tree().call_group("hud", "show_message", why)
		return
	_open_menu(slot, hand)


func _open_menu(slot: int, hand: int) -> void:
	menu = SpellMenu.new()
	menu.setup(party, slot, party.spells_in(slot, hand))
	menu.chosen.connect(_on_spell_chosen)
	add_child(menu)
	menu.size = menu.get_combined_minimum_size()
	# Left of the whole party grid (so it never covers a panel), level with the
	# caster's hands, kept inside the 320x200 view.
	var r: Rect2 = panels[slot].root.get_global_rect()
	var view: Vector2 = get_viewport().get_visible_rect().size
	menu.position = Vector2(panels_grid.get_global_rect().position.x - menu.size.x - 2,
			clampf(r.position.y + 30, 2, view.y - menu.size.y - 2))
	menu_owner = {"caster": slot, "hand": hand}
	catcher.visible = true


func _on_spell_chosen(spell: Resource) -> void:
	var from := menu_owner
	_close_menu()
	if spell.target == SpellDef.Target.HERO:
		pending = {"caster": from.caster, "hand": from.hand, "spell": spell}
		catcher.visible = true
		get_tree().call_group("hud", "show_message", "%s whom?" % spell.display_name, true)
		return
	catcher.visible = false
	party.cast(from.caster, from.hand, spell)


## A portrait was clicked: in target mode it picks the spell's target, otherwise it
## opens that hero's inventory.
func _on_portrait(slot: int) -> void:
	if drag_just_ended:
		return  # This release ended a drag; it isn't a click.
	if pending.is_empty():
		get_tree().call_group("inventory", "show_screen", slot)  # (the screen clicks for itself)
		return
	var p := pending
	_end_target_mode()
	party.cast(p.caster, p.hand, p.spell, slot)


## Close the pop-up and leave target mode, casting nothing.
func cancel_casting() -> void:
	_close_menu()
	_end_target_mode()


func _close_menu() -> void:
	if menu:
		menu.queue_free()
		menu = null
	menu_owner = {}
	catcher.visible = not pending.is_empty()


func _end_target_mode() -> void:
	if not pending.is_empty():
		get_tree().call_group("hud", "clear_message", "%s whom?" % pending.spell.display_name)
	pending = {}
	catcher.visible = menu != null


func _input(event: InputEvent) -> void:
	_drag_input(event)
	if menu == null and pending.is_empty():
		return
	var cancel: bool = (event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE) \
			or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT)
	if cancel:
		cancel_casting()
		get_viewport().set_input_as_handled()


func _update_hp(slot: int) -> void:
	var m = party.member(slot)
	var p: Dictionary = panels[slot]
	p.name_label.text = m.def.display_name  # (Changes when the formation does.)
	p.mana_bar.max_value = maxi(1, m.def.max_mana)
	p.mana_bar.modulate.a = 1.0 if m.def.max_mana > 0 else 0.0
	p.hp_bar.max_value = m.def.max_hp
	p.hp_bar.value = m.hp
	p.portrait.texture_normal = m.def.portrait if m.is_alive() else m.def.portrait_dead
	p.root.modulate = Color(0.5, 0.5, 0.5) if not m.is_alive() else Color.WHITE


## A hero was attacked: float the damage (or "Miss") above their panel, flash the
## screen red on a hit, and briefly swap in the hurt (red-tinted) portrait.
func _on_hero_hit(slot: int, damage: int) -> void:
	var m = party.member(slot)
	var p: Dictionary = panels[slot]
	var label := Label.new()
	label.text = str(damage) if damage > 0 else "Miss"
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", HIT_COLOUR if damage > 0 else MISS_COLOUR)
	label.add_theme_color_override("font_outline_color", HP_BACK)
	label.add_theme_constant_override("outline_size", 3)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	var r: Rect2 = p.root.get_global_rect()
	label.position = Vector2(r.position.x + r.size.x * 0.5 - 6, r.position.y - 14)
	var t := create_tween().set_parallel()
	t.tween_property(label, "position:y", label.position.y - 14, 0.8).set_ease(Tween.EASE_OUT)
	t.tween_property(label, "modulate:a", 0.0, 0.8).set_ease(Tween.EASE_IN)
	t.chain().tween_callback(label.queue_free)

	if damage > 0:
		_shake_portrait(p.portrait, damage)
		flash.color.a = 0.35
		create_tween().tween_property(flash, "color:a", 0.0, 0.35)
		if m.is_alive():  # Still alive: flash the hurt portrait, then revert. Dead
			p.portrait.texture_normal = m.def.portrait_hurt  # already shows portrait_dead permanently.
			var timer := get_tree().create_timer(HURT_FLASH_TIME)
			timer.timeout.connect(func():
				if m.is_alive():  # The hero may have moved to another position meanwhile.
					panels[m.slot].portrait.texture_normal = m.def.portrait)


# --------------------------------------------------------------------------
# Formation drag
# --------------------------------------------------------------------------

## A left press landed on a portrait or name. It becomes a drag only if the mouse
## moves on, and only when nothing is in the way: no item on the cursor (items own the
## click), no spell pop-up or target mode, no inventory screen open.
func _press_on(slot: int, global_pos: Vector2) -> void:
	var cursor = get_tree().get_first_node_in_group("cursor")
	if (cursor and cursor.is_holding()) or menu != null or not pending.is_empty() \
			or get_tree().paused or dragging:
		return
	press_slot = slot
	press_pos = global_pos


func _drag_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and press_slot != -1:
		var pos: Vector2 = event.position
		if not dragging and pos.distance_to(press_pos) >= DRAG_THRESHOLD:
			_begin_drag()
		if dragging:
			_update_drag(pos)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		if dragging:
			_finish_drag(event.position)
		press_slot = -1  # Released without moving far: a plain click, handled by the buttons.
	elif dragging and ((event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE) \
			or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT)):
		_end_drag()
		get_viewport().set_input_as_handled()


func _begin_drag() -> void:
	dragging = true
	drag_from = press_slot
	var m = party.member(drag_from)
	ghost = TextureRect.new()
	ghost.texture = m.def.portrait if m.is_alive() else m.def.portrait_dead
	ghost.size = PORTRAIT_SIZE
	ghost.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ghost.stretch_mode = TextureRect.STRETCH_SCALE
	ghost.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ghost.modulate = DRAG_GHOST
	add_child(ghost)  # Last child: drawn over the panels.
	panels[drag_from].portrait.modulate.a = 0.35  # The origin looks vacated.
	_update_drag(get_viewport().get_mouse_position())


## Which position's panel is under this point, or -1.
func _panel_at(pos: Vector2) -> int:
	for slot in panels:
		if panels[slot].root.get_global_rect().has_point(pos):
			return slot
	return -1


func _update_drag(pos: Vector2) -> void:
	ghost.position = pos - ghost.size / 2.0
	var over := _panel_at(pos)
	if over == drag_from:
		over = -1  # Over its own panel: it would swap with nothing.
	if over != drag_over:
		_highlight(drag_over, false)
		drag_over = over
		_highlight(drag_over, true)


func _highlight(slot: int, on: bool) -> void:
	if slot < 0 or not panels.has(slot):
		return
	var box: StyleBoxFlat = panels[slot].box
	box.border_color = DROP_EDGE if on else PANEL_EDGE
	box.set_border_width_all(4 if on else 2)  # (2 px is the panel border: whole 2x2 blocks)


## Dropping on another panel swaps; anywhere else (including its own panel) cancels.
func _finish_drag(pos: Vector2) -> void:
	var target := _panel_at(pos)
	var from := drag_from
	_end_drag()
	drag_just_ended = true  # Suppress the click this release would otherwise be.
	if target != -1 and target != from:
		party.swap_positions(from, target)


func _end_drag() -> void:
	_highlight(drag_over, false)
	if panels.has(drag_from):
		panels[drag_from].portrait.modulate.a = 1.0
	if ghost:
		ghost.queue_free()
		ghost = null
	dragging = false
	drag_from = -1
	drag_over = -1
	press_slot = -1


## The party was rearranged: every panel redraws for whoever now stands there. (Hands,
## cooldown, mana and buffs are polled each frame; quick slots listen to quick_changed.)
func _on_formation_changed() -> void:
	cancel_casting()
	for slot in panels:
		_update_hp(slot)
		var portrait: Control = panels[slot].portrait
		if portrait.has_meta("rest_x"):
			portrait.position.x = portrait.get_meta("rest_x")  # Cancel a shake that was in progress.


## The portrait of a hero who was hit jolts sideways and settles (a bigger hit shakes
## a little harder). Pure feedback; see data/combat_feel.tres.
func _shake_portrait(portrait: Control, damage: int) -> void:
	if not feel_cfg.portrait_shake_enabled or damage < feel_cfg.portrait_shake_min_damage:
		return
	var amp: float = feel_cfg.portrait_shake_pixels * (1.0 + minf(damage, 8) / 8.0)
	var t: float = feel_cfg.portrait_shake_seconds
	# The portrait sits centred in its panel, not at x=0: remember where, and shake around it.
	if not portrait.has_meta("rest_x"):
		portrait.set_meta("rest_x", portrait.position.x)
	var rest: float = portrait.get_meta("rest_x")
	if portrait.has_meta("shake_tween"):
		portrait.get_meta("shake_tween").kill()
	var tween := create_tween()
	portrait.set_meta("shake_tween", tween)
	var steps := 6
	for i in steps:
		var fall := 1.0 - float(i) / steps
		var dir := 1.0 if i % 2 == 0 else -1.0
		tween.tween_property(portrait, "position:x", rest + dir * amp * fall, t / (steps + 1))
	tween.tween_property(portrait, "position:x", rest, t / (steps + 1))


func _make_panel(m) -> Dictionary:
	# This panel's fixed position. Closures below use `pos`, never `m.slot`: the member
	# standing here changes when the formation does, but the panel stays put.
	var pos: int = m.slot
	var root := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = PANEL_BG
	box.border_color = PANEL_EDGE
	box.set_border_width_all(2)
	box.content_margin_left = MARGIN_LEFT
	box.content_margin_top = MARGIN_TOP
	box.content_margin_right = MARGIN_RIGHT
	box.content_margin_bottom = MARGIN_BOTTOM
	root.add_theme_stylebox_override("panel", box)
	root.custom_minimum_size = PANEL_SIZE
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panels_grid.add_child(root)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", ROW_GAP)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(col)

	# A button (not a plain TextureRect) so clicking it can open the inventory.
	var portrait := TextureButton.new()
	portrait.texture_normal = m.def.portrait
	portrait.custom_minimum_size = PORTRAIT_SIZE
	portrait.ignore_texture_size = true
	portrait.stretch_mode = TextureButton.STRETCH_SCALE
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	portrait.focus_mode = Control.FOCUS_NONE
	portrait.tooltip_text = "Inventory"
	portrait.pressed.connect(_on_portrait.bind(pos))
	portrait.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			_press_on(pos, portrait.get_global_rect().position + e.position))
	# In a plain Control frame, not straight in the column: a container keeps resetting
	# its children's positions, which would undo the portrait's hit shake.
	var frame := Control.new()
	frame.custom_minimum_size = PORTRAIT_SIZE
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(frame)
	frame.add_child(portrait)
	# 32x32 in the middle of the panel's width, however wide the frame turns out to be.
	portrait.anchor_left = 0.5
	portrait.anchor_right = 0.5
	portrait.anchor_top = 0.0
	portrait.anchor_bottom = 1.0
	portrait.offset_left = -PORTRAIT_SIZE.x / 2.0
	portrait.offset_right = PORTRAIT_SIZE.x / 2.0
	portrait.offset_top = 0.0
	portrait.offset_bottom = 0.0

	# A gold outline over the portrait while a buff (Shield, Bless) is active.
	var buff_ring := Panel.new()
	var ring := StyleBoxFlat.new()
	ring.draw_center = false
	ring.border_color = BUFF_EDGE
	ring.set_border_width_all(2)
	buff_ring.add_theme_stylebox_override("panel", ring)
	buff_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	buff_ring.visible = false
	portrait.add_child(buff_ring)
	buff_ring.anchor_right = 1.0   # Fills its parent whatever size layout gives it
	buff_ring.anchor_bottom = 1.0  # (a resized signal missed the portrait's first layout).

	# Two quick slots under the portrait (consumables; see quick_slot.gd).
	var quick_row := HBoxContainer.new()
	quick_row.add_theme_constant_override("separation", 0)
	quick_row.alignment = BoxContainer.ALIGNMENT_CENTER
	quick_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(quick_row)
	var quick_slots := []
	for qi in party.QUICK_SLOTS:
		var qs := QuickSlot.new()
		qs.setup(party, pos, qi)
		quick_row.add_child(qs)
		quick_slots.append(qs)

	# Clicking the name opens the inventory screen with the character sheet showing.
	var name_label := _label(m.def.display_name, 8)
	name_label.mouse_filter = Control.MOUSE_FILTER_STOP
	name_label.tooltip_text = "Character sheet"
	name_label.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
			if e.pressed:
				_press_on(pos, name_label.get_global_rect().position + e.position)  # Might become a drag...
			elif not drag_just_ended and pending.is_empty():
				# ...otherwise it's a click, acted on at the release (after the drag logic has run).
				get_tree().call_group("inventory", "show_screen", pos, true))
	col.add_child(name_label)

	var hp_bar := _bar(HP_FILL, Vector2(0, HP_HEIGHT), m.def.max_hp)
	col.add_child(hp_bar)

	# Mana, for casters. Every panel keeps the row (invisible without mana) so the
	# hand buttons line up across a row of panels.
	var mana_bar := _bar(MANA_FILL, Vector2(0, MANA_HEIGHT), maxi(1, m.def.max_mana))
	mana_bar.modulate.a = 1.0 if m.def.max_mana > 0 else 0.0
	col.add_child(mana_bar)

	# Two hands (left/right), each acting with the item it holds.
	var hands_row := HBoxContainer.new()
	hands_row.add_theme_constant_override("separation", 4)
	hands_row.alignment = BoxContainer.ALIGNMENT_CENTER
	hands_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(hands_row)
	var hands := []
	for i in party.HAND_SLOTS:
		var hand := _make_hand(m, i)
		hands_row.add_child(hand)
		hands.append(hand)

	var cool_bar := _bar(COOL_FILL, Vector2(0, COOL_HEIGHT), 100)
	col.add_child(cool_bar)

	return {"root": root, "box": box, "name_label": name_label, "portrait": portrait, "buff_ring": buff_ring, "hands": hands,
		"cool_bar": cool_bar, "hp_bar": hp_bar, "mana_bar": mana_bar, "quick": quick_slots}


func _make_hand(m, i: int) -> TextureButton:
	var hand := TextureButton.new()
	hand.texture_normal = m.def.hand_icon
	hand.custom_minimum_size = HAND_SIZE
	hand.ignore_texture_size = true
	hand.stretch_mode = TextureButton.STRETCH_KEEP_CENTERED
	hand.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	hand.focus_mode = Control.FOCUS_NONE  # Space/Enter shouldn't trigger it.
	hand.pressed.connect(_on_hand.bind(m.slot, i))
	hand.add_child(StackCount.new())  # How many darts are left (child 0; see _show_hand).
	return hand


func _label(text: String, size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Color(0.92, 0.89, 0.82))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


func _bar(fill_colour: Color, size: Vector2, max_value: float) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.custom_minimum_size = size
	bar.max_value = max_value
	bar.show_percentage = false
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var back := StyleBoxFlat.new()
	back.bg_color = HP_BACK
	var fill := StyleBoxFlat.new()
	fill.bg_color = fill_colour
	bar.add_theme_stylebox_override("background", back)
	bar.add_theme_stylebox_override("fill", fill)
	return bar
