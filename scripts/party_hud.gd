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
const SaveGame := preload("res://scripts/save_game.gd")

# Sizes are in 640x360 pixels. The art is drawn at 2x (see ui_layout.gd), so each of these is the
# art's own size: portraits 64x64, hand buttons 32x32.
const PORTRAIT_SIZE := Vector2(64, 64)
const HAND_SIZE := Vector2(40, 40)
const NAME_HOVER := Color(0.961, 0.812, 0.502)    # Palette torch_300: the name brightens to this on hover.
const NAME_NORMAL := Color(0.92, 0.89, 0.82)
const HOVER_BRIGHT := Color(1.22, 1.2, 1.15)      # Portraits, hands and quick slots brighten a little on hover.
const SCROLL_ICON := preload("res://art/ui/name_scroll.png")
const HAND_FRAME := preload("res://art/ui/handslot.png")
const HINT_UP := Color(0.525, 0.651, 0.447)     # Palette slime_300: better (the palette has no pure green; the arrow and number say it too).
const HINT_DOWN := Color(0.659, 0.404, 0.227)   # Palette rust_300: worse.
const HINT_FLAT := Color(0.482, 0.478, 0.533)   # Palette stone_300: no change.
const PANEL_SIZE := Vector2(98, 170)     # Two across, two down fill the party window (ui_layout.gd).
# Content margins (left, top, right, bottom). Everything in a panel sits on EVEN pixel
# coordinates, so the 2x2 blocks of the art line up with the frame's (a block starting on an
# odd pixel would straddle two of the frame's blocks). The inner width of 88 centres the 64-wide
# portrait, the 56-wide quick slots and the 68-wide hands on even x; every row height and gap is even.
const MARGIN_LEFT := 6
const MARGIN_TOP := 3
const MARGIN_RIGHT := 4
const MARGIN_BOTTOM := 3
const ROW_GAP := 1                       # Between the rows inside a panel.
const HP_HEIGHT := 6
const MANA_HEIGHT := 3

const HAND_READY := Color(1, 1, 1)
const HAND_COOLING := Color(0.35, 0.33, 0.38)
const PANEL_BG := Color(0.078, 0.075, 0.106, 0.88)  # Palette stone_900.
const PANEL_EDGE := Color(0.192, 0.188, 0.235)        # Palette stone_700.
const HP_FILL := Color(0.486, 0.267, 0.149)            # Palette rust_500.
const HP_BACK := Color(0.043, 0.039, 0.063)          # Palette ink.
const HAND_SWEEP := preload("res://art/ui/handslot_sweep.png")
const SWEEP_TINT := Color(1, 1, 1, 0.65)
const HIT_COLOUR := Color(0.659, 0.404, 0.227)          # Palette rust_300.
const MISS_COLOUR := Color(0.667, 0.663, 0.706)         # Palette stone_100.
const MANA_FILL := Color(0.851, 0.604, 0.212)        # Palette torch_500 (the palette has no blue).
const BUFF_EDGE := Color(0.961, 0.812, 0.502)        # Palette torch_300: the outline on a buffed hero's portrait, 3 px, ...
const BUFF_EDGE_DIM := MANA_FILL                     # ...stepping to torch_500 and back twice a second (steady torch_300 with Reduce flashing).
const BUFF_PULSE := 0.45
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
	party.hero_crit.connect(_on_hero_crit)
	party.formation_changed.connect(_on_formation_changed)
	add_to_group("party_hud")
	party.holy_cast.connect(_on_holy_cast)
	party.buff_cast.connect(_on_buff_cast)
	party.revive_requested.connect(_on_revive_requested)
	party.food_tick.connect(_on_food_tick.bind(false))
	party.sick_tick.connect(_on_food_tick.bind(true))
	party.revived.connect(_on_revived)

	_first_time_hint()

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


## The first time the party panel appears in a new game (never on a loaded one, and only until it has been
## shown once): the names pulse gently twice and the log says how to open a character sheet. Remembered in
## the settings; switched off by Options: HINTS.
func _first_time_hint() -> void:
	if not Settings.show_hints or Settings.hint_seen("character_sheet") or not SaveGame.pending.is_empty():
		return
	Settings.mark_hint("character_sheet")
	await get_tree().create_timer(0.8).timeout
	for label in name_labels:
		if not is_instance_valid(label):
			continue
		var tween := create_tween()
		for i in 2:
			tween.tween_property(label, "modulate", Color(1.5, 1.25, 0.7), 0.4).set_trans(Tween.TRANS_SINE)
			tween.tween_property(label, "modulate", Color.WHITE, 0.4).set_trans(Tween.TRANS_SINE)
	get_tree().call_group("hud", "show_message", "Click a portrait to see their inventory and stats.")


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
		for hand in p.hands:  # The cooldown is a clock wipe over each hand button, as on the quick slots.
			var sweep: TextureProgressBar = hand.get_meta("sweep")
			sweep.visible = m.is_alive() and m.cooldown_left > 0.0
			sweep.value = (m.cooldown_left / total) * 100.0
		p.mana_bar.value = m.mana
		_update_equip_hint(m, p, cursor)
		p.buff_ring.visible = not m.buffs.is_empty()
		if p.buff_ring.visible:
			var bright: bool = Settings.reduce_flashing or int(Time.get_ticks_msec() / (BUFF_PULSE * 1000.0)) % 2 == 0
			p.ring_style.border_color = BUFF_EDGE if bright else BUFF_EDGE_DIM
		p.shaken.visible = m.shaken_left > 0.0 and m.is_alive()  # A dimmed holy symbol: too shaken to pray.
		p.food_mark.visible = m.is_alive() and (m.food_left > 0.0 or m.sick_left > 0.0)
		p.food_mark.color = SICK_TICK if m.sick_left > 0.0 else FOOD_TICK
	if not revive_pending.is_empty():  # The scroll left its quick slot (or its hero died): drop target mode.
		var src = party.member(revive_pending.slot)
		var held = src.quick[revive_pending.index] if src != null else null
		if held == null or held.def.revive_percent <= 0 or not src.is_alive():
			_end_revive()
	# Close the pop-up / target mode if the caster died or the item left their hand.
	for state in [menu_owner, pending]:
		if not state.is_empty() and party.action_for(state.caster, state.hand) != party.Act.SPELLS:
			cancel_casting()


# --------------------------------------------------------------------------
# The cleric's holy symbol glowing while Heal or Bless is cast
# --------------------------------------------------------------------------

const HOLY_GLOW_SHEET := "res://art/items/holy_symbol_glow.png"  # Three frames of 32x32: dim, medium, bright.
var holy_glows := {}  # hand TextureButton -> {"glow": TextureRect, "tween": Tween}
var revive_pending := {}  # {"slot", "index"}: a Scroll of Resurrection from this quick slot waits for a portrait click.
var column_texture: Texture2D  # The gold column over a revived hero (made once, in _revive_column_texture).
var holy_icon: Texture2D
var name_labels := []  # Every hero's name label (they pulse once, the first time the panel appears).


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
	glow.visible = k >= 0.2  # The frames carry the strength (weak, medium, strong); below the weakest it is simply gone: no alpha fade.
	glow.modulate = Color.WHITE


## Square specks that step down the gold palette ramp (torch 300, 500, 700) over their life and then vanish: alpha stays 1.
func _step_motes(motes: CPUParticles2D) -> void:
	var ramp := Gradient.new()
	ramp.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	ramp.offsets = PackedFloat32Array([0.0, 0.4, 0.75])
	ramp.colors = PackedColorArray([Color("f5cf80"), Color("d99a36"), Color("9a5f1c")])
	motes.color = Color.WHITE
	motes.color_ramp = ramp


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
	_step_motes(motes)
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
		party.Act.USE: hand.tooltip_text = "Use (right-click to take it out)"
		_: hand.tooltip_text = ""


# --------------------------------------------------------------------------
# Hands and casting
# --------------------------------------------------------------------------

func _on_hand_input(event: InputEvent, slot: int, hand: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		var cursor = get_tree().get_first_node_in_group("cursor")
		if cursor == null or party.member(slot).hands[hand] == null:
			return
		cancel_casting()
		var refused: String = party.lift_from_hand(slot, hand, cursor)
		if refused != "":
			get_tree().call_group("hud", "show_message", refused)
		else:
			get_tree().call_group("audio", "play", "pickup")


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


## `spells` overrides the hero's spell list (for tests).
func _open_menu(slot: int, hand: int, spells: Array = []) -> void:
	menu = SpellMenu.new()
	menu.setup(party, slot, spells if not spells.is_empty() else party.spells_in(slot, hand))
	menu.chosen.connect(_on_spell_chosen)
	# Preferred: left of the whole party grid (so it never covers a panel), level with the caster's hands. The popup layer
	# keeps it on screen and clear of the minimap, trying below and to the left of the map if that spot is covered.
	var r: Rect2 = panels[slot].root.get_global_rect()
	var preferred := func(size: Vector2) -> Vector2:
		return Vector2(panels_grid.get_global_rect().position.x - size.x - 2, r.position.y + 30)
	var popups := get_tree().get_first_node_in_group("popups")
	if popups:
		popups.open_popup(menu, preferred)
	else:  # No popup layer (a bare test scene): the old behaviour.
		add_child(menu)
		menu.size = menu.get_combined_minimum_size()
		menu.position = preferred.call(menu.size)
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
## `force_inventory` (for tests): a portrait click opens the inventory even with something on the cursor. In play, the way into it
## while carrying something is the hero's name (or the scroll beside it).
var force_inventory := false
## Shift held (or `force_equip`, for tests): a portrait click with armour or a weapon on the cursor puts it on that hero. A plain
## click puts it in their backpack, so a swap can never trap the item in a loop.
var force_equip := false
var told_about_equip := false  # The "Shift+click to equip" tip is said once a run, with the first stowing.


func _on_portrait(slot: int) -> void:
	if drag_just_ended:
		return  # This release ended a drag; it isn't a click.
	if not revive_pending.is_empty():
		_revive_from_quick(slot)
		return
	var cursor = get_tree().get_first_node_in_group("cursor")
	var carrying: bool = cursor != null and cursor.is_holding()
	if carrying and force_inventory and pending.is_empty():
		get_tree().call_group("inventory", "show_screen", slot, true)
		return
	if cursor != null and cursor.is_holding() and cursor.held.def.revive_percent > 0:
		_revive_from_cursor(slot, cursor)  # A Scroll of Resurrection on the cursor: read it on this portrait.
		return
	if cursor != null and cursor.is_holding() and cursor.held.def.is_food():
		_feed_from_cursor(slot, cursor)  # Food on the cursor: feed this hero.
		return
	if cursor != null and cursor.is_holding() and party.is_equippable(cursor.held.def) and pending.is_empty():
		var equip: bool = force_equip or Input.is_key_pressed(KEY_SHIFT)
		var result: Dictionary = party.equip_from_cursor(slot, cursor) if equip else party.stow_from_cursor(slot, cursor)
		var text: String = result.message
		if not equip and result.done and not told_about_equip:
			told_about_equip = true
			text += " (Shift+click a portrait to equip it instead.)"
		get_tree().call_group("hud", "show_message", text)
		return
	if pending.is_empty():
		get_tree().call_group("inventory", "show_screen", slot, true)  # The stat sheet opens alongside the inventory.
		return
	var p := pending
	_end_target_mode()
	party.cast(p.caster, p.hand, p.spell, slot)


## While armour or a weapon is on the cursor AND Shift is held (the click that would equip it), each portrait shows what it would
## change: an arrow and the number (defence for armour, average damage for a weapon), in torch-free colours, or the portrait greys
## out if that class can't use it. Without Shift a click stows the item, so nothing is promised.
func _update_equip_hint(m, p: Dictionary, cursor: Node) -> void:
	var hint: Control = p.equip_hint
	var show: bool = cursor != null and cursor.is_holding() and party.is_equippable(cursor.held.def) 			and (force_equip or Input.is_key_pressed(KEY_SHIFT))
	hint.visible = show
	var portrait: Control = p.portrait
	if not show:
		if portrait.has_meta("equip_grey"):
			portrait.remove_meta("equip_grey")
			portrait.self_modulate = Color.WHITE
		return
	var change: Dictionary = party.equip_change(m, cursor.held.def)
	var blocked: bool = change.blocked or change.dead
	portrait.set_meta("equip_grey", true)
	portrait.self_modulate = Color(0.4, 0.4, 0.45) if blocked else Color.WHITE
	var arrow: TextureRect = hint.get_node("Arrow")
	var label: Label = hint.get_node("Label")
	if blocked:
		arrow.visible = false
		label.text = "X"
		label.add_theme_color_override("font_color", HINT_DOWN)
		return
	var delta: int = change.delta
	arrow.visible = delta != 0
	arrow.texture = _arrow_texture(delta > 0)
	var colour: Color = HINT_UP if delta > 0 else (HINT_DOWN if delta < 0 else HINT_FLAT)
	arrow.self_modulate = colour
	label.text = ("%+d" % delta) if delta != 0 else "="
	label.add_theme_color_override("font_color", colour)
	hint.tooltip_text = "%s %s" % [("defence" if change.kind == "defence" else "damage"), ("%+d" % delta)]


var _arrow_up: ImageTexture
var _arrow_down: ImageTexture


## A 7x7 solid arrow, white (tinted by the caller), drawn here so the hint needs no art file.
func _arrow_texture(up: bool) -> ImageTexture:
	if _arrow_up == null:
		var image := Image.create(7, 7, false, Image.FORMAT_RGBA8)
		for row in 7:
			var half := row if row < 4 else 3
			for x in range(3 - mini(half, 3), 4 + mini(half, 3)):
				if row < 4:
					image.set_pixel(x, row, Color.WHITE)
		for y in range(4, 7):
			for x in range(2, 5):
				image.set_pixel(x, y, Color.WHITE)
		_arrow_up = ImageTexture.create_from_image(image)
		image.flip_y()
		_arrow_down = ImageTexture.create_from_image(image)
	return _arrow_up if up else _arrow_down


## Close the pop-up and leave target mode, casting nothing.
func cancel_casting() -> void:
	_close_menu()
	_end_target_mode()
	_end_revive()


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
	if menu == null and pending.is_empty() and revive_pending.is_empty():
		return
	var cancel: bool = (event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE) \
			or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT)
	if cancel:
		cancel_casting()
		get_viewport().set_input_as_handled()


# --------------------------------------------------------------------------
# Scroll of Resurrection
# --------------------------------------------------------------------------

# --------------------------------------------------------------------------
# Food
# --------------------------------------------------------------------------

const FOOD_TICK := Color(0.961, 0.812, 0.502)   # Palette torch_300: a warm tick, never the curse green.
const SICK_TICK := Color(0.498, 0.722, 0.541)   # Palette curse_500: sickness is the curse.


## Food on the cursor, clicked onto a hero's portrait: they eat it (one from the stack).
func _feed_from_cursor(target: int, cursor: Node) -> void:
	var result: Dictionary = party.eat(target, cursor.held.def)
	if result.message != "":
		get_tree().call_group("hud", "show_message", result.message)
	if not result.used:
		return  # It stays on the cursor.
	cursor.held.count -= 1
	if cursor.held.count <= 0:
		cursor.release()
	else:
		cursor.refresh()


## Each point food heals (or sickness takes): the hero's HP bar flares a warm gold (a sickly green for sickness) and a small
## "+1" (or "-1") rises off it. While food works a thin warm line runs along the bar's foot (see _process).
func _on_food_tick(slot: int, amount: int, sick: bool) -> void:
	if not panels.has(slot):
		return
	var bar: ProgressBar = panels[slot].hp_bar
	var tint: Color = SICK_TICK if sick else FOOD_TICK
	bar.modulate = Color(1.0 + tint.r * 0.6, 1.0 + tint.g * 0.6, 1.0 + tint.b * 0.6)
	create_tween().tween_property(bar, "modulate", Color.WHITE, 0.35)
	var label := Label.new()
	label.text = "%s%d" % ["-" if sick else "+", amount]
	label.add_theme_font_size_override("font_size", 8)
	label.add_theme_color_override("font_color", tint)
	label.add_theme_color_override("font_outline_color", HP_BACK)
	label.add_theme_constant_override("outline_size", 2)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	var r: Rect2 = bar.get_global_rect()
	label.position = Vector2(r.position.x + r.size.x - 18.0, r.position.y - 9.0)
	var tween := create_tween().set_parallel()
	tween.tween_property(label, "position:y", label.position.y - 8.0, 0.7)
	tween.tween_property(label, "modulate:a", 0.0, 0.7).set_delay(0.25)
	tween.chain().tween_callback(label.queue_free)


## From a quick slot: wait for the portrait click that says who to raise.
func _on_revive_requested(slot: int, index: int) -> void:
	cancel_casting()
	revive_pending = {"slot": slot, "index": index}
	catcher.visible = true
	get_tree().call_group("hud", "show_message", "Raise whom?", true)


func _end_revive() -> void:
	if revive_pending.is_empty():
		return
	revive_pending = {}
	get_tree().call_group("hud", "clear_message", "Raise whom?")
	catcher.visible = menu != null or not pending.is_empty()


func _revive_from_quick(target: int) -> void:
	var src: Dictionary = revive_pending
	var stack = party.member(src.slot).quick[src.index]
	var tex: Texture2D = stack.def.icon if stack != null else null
	var from: Vector2 = get_viewport().get_mouse_position()
	if party.revive_from_quick(src.slot, src.index, target):
		_end_revive()
		_burn_scroll(tex, from)
	else:
		_end_revive()  # "The scroll needs the fallen." was already said; the scroll is kept.


func _revive_from_cursor(target: int, cursor: Node) -> void:
	var def: Resource = cursor.held.def
	var from: Vector2 = get_viewport().get_mouse_position()
	var result: Dictionary = party.revive(target, def)
	if not result.used:
		return  # The scroll stays on the cursor; the log said why.
	cursor.held.count -= 1
	if cursor.held.count <= 0:
		cursor.release()
	else:
		cursor.refresh()
	_burn_scroll(def.icon, from)


## The scroll's icon burns away in gold light where it was read: it flares to bright gold and fades,
## drifting up a little.
func _burn_scroll(tex: Texture2D, at: Vector2) -> void:
	if tex == null:
		return
	var c := SpellEffectsConfig.get_config()
	var icon := TextureRect.new()
	icon.texture = tex
	icon.size = tex.get_size()
	icon.position = at - icon.size / 2.0
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	icon.material = mat
	add_child(icon)
	var seconds: float = c.revive_burn_seconds * (1.5 if Settings.reduce_flashing else 1.0)
	var bright: float = 1.0 if Settings.reduce_flashing else 2.2
	# Three steps down in brightness (it is additive, so darker is fainter) and up 4 px each: alpha stays 1.
	icon.modulate = Color(1.2, 1.0, 0.6, 1.0)
	var tween := create_tween()
	var levels := [1.0, 0.55, 0.25]
	var rest_y := icon.position.y
	for i in levels.size():
		var l: float = levels[i]
		tween.tween_callback(func():
			icon.modulate = Color(bright * l, bright * 0.75 * l, bright * 0.3 * l, 1.0)
			icon.position.y = rest_y - 4.0 * (i + 1))
		tween.tween_interval(seconds / levels.size())
	tween.tween_callback(icon.queue_free)


## Heal, Bless or Shield took hold: the PixelLab effect (art/spells/<spell>/portrait_sheet.png, the same animation shrunk to the portrait)
## plays over each portrait that got it, so it reads as cast on the hero and not out at the monster.
func _on_buff_cast(slots: Array, effect: String) -> void:
	for slot in slots:
		_play_portrait_fx(slot, effect)


func _play_portrait_fx(slot: int, effect: String) -> void:
	if not panels.has(slot):
		return
	var png := "res://art/spells/%s/portrait_sheet.png" % effect
	var json_path := "res://art/spells/%s/portrait_sheet.json" % effect
	if not ResourceLoader.exists(png) or not FileAccess.file_exists(json_path):
		return
	var info = JSON.parse_string(FileAccess.get_file_as_string(json_path))
	if not info is Dictionary:
		return
	var sheet: Texture2D = load(png)
	var frames := int(info.frames)
	var size := Vector2(int(info.frame_w), int(info.frame_h))
	var atlas := AtlasTexture.new()
	atlas.atlas = sheet
	atlas.region = Rect2(Vector2.ZERO, size)
	var fx := TextureRect.new()
	fx.top_level = true
	fx.texture = atlas
	fx.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fx.size = size
	fx.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	fx.material = mat
	if Settings.reduce_flashing:
		fx.modulate = Color(0.65, 0.65, 0.65, 1.0)  # Dimmer, never an alpha fade.
	var rect: Rect2 = panels[slot].portrait.get_global_rect()
	var lower: float = 14.0 if effect == "bless" else 0.0  # The ring spreads over the portrait's lower half.
	fx.global_position = (rect.get_center() + Vector2(0, lower) - size / 2.0).round()
	panels[slot].root.add_child(fx)
	var seconds: float = frames / float(info.fps)
	var tween := create_tween()
	tween.tween_method(func(t: float) -> void:
		atlas.region = Rect2(Vector2(minf(floorf(t * info.fps), frames - 1.0) * size.x, 0.0), size), 0.0, seconds, seconds)
	tween.tween_callback(fx.queue_free)


## A hero was raised: a column of warm holy light rises over their portrait (taller, wider and
## brighter for a Cleric) with light motes, all steadier and dimmer with "Reduce flashing".
func _on_revived(slot: int, shaken: bool) -> void:
	if not panels.has(slot):
		return
	var c := SpellEffectsConfig.get_config()
	var reduced: bool = Settings.reduce_flashing
	var portrait: TextureButton = panels[slot].portrait
	var scale: float = c.revive_column_scale * (c.revive_cleric_scale if shaken else 1.0)
	var bright: float = c.revive_column_brightness * (c.revive_cleric_brightness if shaken else 1.0) * (c.revive_reduced_scale if reduced else 1.0)
	var column := TextureRect.new()
	column.top_level = true
	column.texture = _revive_column_texture()
	column.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	column.stretch_mode = TextureRect.STRETCH_SCALE
	column.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.size = Vector2(36, 84) * scale
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	column.material = mat
	var rect: Rect2 = portrait.get_global_rect()
	var base := Vector2(rect.get_center().x - column.size.x / 2.0, rect.end.y + 6.0 - column.size.y)  # Its foot at the portrait's foot.
	column.global_position = base
	column.modulate = Color(0, 0, 0, 1.0)  # Additive: black is nothing. It steps up and down in brightness, alpha stays 1.
	panels[slot].root.add_child(column)
	var seconds: float = c.revive_column_seconds * (1.4 if reduced else 1.0)
	var rise := create_tween()
	rise.tween_method(func(y: float) -> void: column.global_position.y = roundf(y / 2.0) * 2.0, base.y, base.y - c.revive_column_rise, seconds)
	var tween := create_tween()
	for l in [0.35, 0.7, 1.0]:  # Up in three steps over the first 30%.
		tween.tween_callback(func(): column.modulate = Color(bright * l, bright * l, bright * l, 1.0))
		tween.tween_interval(seconds * 0.1)
	tween.tween_interval(seconds * 0.7)
	for l in [0.65, 0.35, 0.15]:  # Down in three steps over the last 70%.
		tween.tween_callback(func(): column.modulate = Color(bright * l, bright * l, bright * l, 1.0))
		tween.tween_interval(seconds * 0.7 / 3.0)
	tween.tween_callback(column.queue_free)
	if not reduced:
		_revive_motes(portrait, column, c.revive_cleric_motes if shaken else c.revive_motes, seconds)


func _revive_motes(portrait: Control, parent: Control, amount: int, seconds: float) -> void:
	var c := SpellEffectsConfig.get_config()
	var motes := CPUParticles2D.new()
	motes.position = Vector2(parent.size.x / 2.0, parent.size.y * 0.92)
	motes.amount = maxi(1, amount)
	motes.lifetime = 1.1
	motes.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	motes.emission_rect_extents = Vector2(parent.size.x * 0.25, 6)
	motes.direction = Vector2(0, -1)
	motes.spread = 10.0
	motes.gravity = Vector2.ZERO
	motes.initial_velocity_min = 24.0
	motes.initial_velocity_max = 48.0
	motes.scale_amount_min = 2.0
	motes.scale_amount_max = 2.0
	_step_motes(motes)
	motes.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	parent.add_child(motes)
	motes.emitting = true
	get_tree().create_timer(seconds * 0.6).timeout.connect(func():
		if is_instance_valid(motes):
			motes.emitting = false)


## The column's picture: 18 x 55 logical pixels (drawn 2x2) of torch gold, bright down the middle and
## fading toward the sides and the top, with a dithered edge, so it looks like pixel art, not a gradient.
## Added over the portrait (additive), so black is nothing.
func _revive_column_texture() -> Texture2D:
	if column_texture != null:
		return column_texture
	const W := 18
	const H := 55
	var image := Image.create(W, H, false, Image.FORMAT_RGBA8)
	var ramp := [Color("9a5f1c"), Color("d99a36"), Color("f5cf80")]  # Palette torch_700 / 500 / 300.
	for y in H:
		var down: float = pow(clampf(float(y) / float(H - 1), 0.0, 1.0), 0.7)  # Strongest at the bottom.
		for x in W:
			var across: float = 1.0 - absf((x + 0.5) / W * 2.0 - 1.0)  # 1 in the middle, 0 at the sides.
			var v: float = across * down
			var bayer: float = (((x & 1) * 2 + (y & 1) * 3) % 4) / 4.0 * 0.18  # Tiny ordered dither.
			v += bayer - 0.09
			var colour := Color(0, 0, 0, 0)
			if v > 0.62:
				colour = ramp[2]
			elif v > 0.36:
				colour = ramp[1]
			elif v > 0.14:
				colour = ramp[0]
			image.set_pixel(x, y, colour)
	column_texture = ImageTexture.create_from_image(image)
	return column_texture


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
	p.shaken.visible = m.shaken_left > 0.0 and m.is_alive()


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
		if party.last_hit_side == "front":  # From behind or the side, the glow on that edge says it instead (direction_warning.gd).
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


## A monster's crit: the hero's portrait flashes red, so it's felt (two pulses, or with Reduce flashing one steady, dimmer tint).
func _on_hero_crit(slot: int, _damage: int) -> void:
	if not feel_cfg.portrait_crit_flash_enabled or not panels.has(slot):
		return
	var portrait: Control = panels[slot].portrait
	if portrait.has_meta("crit_tween"):
		portrait.get_meta("crit_tween").kill()
	var tween := create_tween()
	portrait.set_meta("crit_tween", tween)
	var seconds: float = feel_cfg.portrait_crit_flash_seconds
	if Settings.reduce_flashing:
		portrait.modulate = feel_cfg.portrait_crit_flash_reduced
		tween.tween_interval(seconds * 0.5)
		tween.tween_property(portrait, "modulate", Color.WHITE, seconds * 0.5)
		return
	var pulses: int = maxi(1, feel_cfg.portrait_crit_flash_pulses)
	for i in pulses:
		tween.tween_callback(func(): portrait.modulate = feel_cfg.portrait_crit_flash_colour)
		tween.tween_property(portrait, "modulate", Color.WHITE, seconds / pulses)


## The portrait of a hero who was hit jolts sideways and settles (a bigger hit shakes
## a little harder). Pure feedback; see data/combat_feel.tres. Reduce flashing stops it.
func _shake_portrait(portrait: Control, damage: int) -> void:
	if not feel_cfg.portrait_shake_enabled or Settings.reduce_flashing or damage < feel_cfg.portrait_shake_min_damage:
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
	portrait.tooltip_text = "Inventory and stats (holding armour, a weapon or food: click to use it, Shift+click for the inventory)"
	_make_hoverable(portrait, portrait)
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
	# What equipping the item on the cursor would change (arrow and number), top-right of the portrait; hidden otherwise.
	var equip_hint := HBoxContainer.new()
	equip_hint.add_theme_constant_override("separation", 1)
	equip_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	equip_hint.visible = false
	equip_hint.position = Vector2(2, 2)
	var hint_arrow := TextureRect.new()
	hint_arrow.name = "Arrow"
	hint_arrow.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	hint_arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint_arrow.stretch_mode = TextureRect.STRETCH_KEEP
	hint_arrow.custom_minimum_size = Vector2(7, 8)
	equip_hint.add_child(hint_arrow)
	var hint_label := _label("", 8)
	hint_label.name = "Label"
	equip_hint.add_child(hint_label)
	frame.add_child(equip_hint)
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
	ring.set_border_width_all(3)
	buff_ring.add_theme_stylebox_override("panel", ring)
	buff_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	buff_ring.visible = false
	portrait.add_child(buff_ring)
	buff_ring.anchor_right = 1.0   # Fills its parent whatever size layout gives it
	buff_ring.anchor_bottom = 1.0  # (a resized signal missed the portrait's first layout).

	# A small dimmed holy symbol on a resurrected Cleric's portrait while they are too shaken to pray.
	var shaken := TextureRect.new()
	shaken.texture = load("res://art/items/holy_symbol_hud.png")
	shaken.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shaken.stretch_mode = TextureRect.STRETCH_SCALE
	shaken.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	shaken.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shaken.modulate = Color(1, 1, 1, 0.5)
	shaken.size = Vector2(24, 24)
	shaken.position = Vector2(2, PORTRAIT_SIZE.y - 26)
	shaken.visible = false
	shaken.tooltip_text = "Too shaken to pray"
	portrait.add_child(shaken)

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

	# Clicking the name (or the little scroll beside it) opens the inventory screen with the character sheet
	# showing. Hovering the name brightens it, underlines it and shows a pointing hand and a tooltip.
	var name_label := _label(m.def.display_name, 8)
	name_label.mouse_filter = Control.MOUSE_FILTER_STOP
	name_label.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	name_label.tooltip_text = "Character sheet (C)"
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var underline := ColorRect.new()
	underline.color = NAME_HOVER
	underline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	underline.visible = false
	name_label.add_child(underline)
	name_label.mouse_entered.connect(func(): _hover_name(name_label, underline, true))
	name_label.mouse_exited.connect(func(): _hover_name(name_label, underline, false))
	name_label.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
			if e.pressed:
				_press_on(pos, name_label.get_global_rect().position + e.position)  # Might become a drag...
			elif not drag_just_ended and pending.is_empty():
				# ...otherwise it's a click, acted on at the release (after the drag logic has run).
				get_tree().call_group("inventory", "show_screen", pos, true))
	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 2)
	name_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_row.add_child(name_label)
	var scroll_button := TextureButton.new()
	scroll_button.texture_normal = SCROLL_ICON
	scroll_button.custom_minimum_size = Vector2(16, 10)  # (the 16x16 art overhangs by 2 px into the row gaps, so the panel keeps its 170 px)
	scroll_button.ignore_texture_size = true
	scroll_button.stretch_mode = TextureButton.STRETCH_KEEP_CENTERED
	scroll_button.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	scroll_button.focus_mode = Control.FOCUS_NONE
	scroll_button.tooltip_text = "Character sheet (C)"
	scroll_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	scroll_button.pressed.connect(func():
		if pending.is_empty() and revive_pending.is_empty():
			get_tree().call_group("inventory", "show_screen", pos, true))
	_make_hoverable(scroll_button, scroll_button)
	name_row.add_child(scroll_button)
	col.add_child(name_row)
	name_labels.append(name_label)

	var hp_bar := _bar(HP_FILL, Vector2(0, HP_HEIGHT), m.def.max_hp)
	col.add_child(hp_bar)
	# A thin line along the foot of the HP bar while food is working (warm) or sickness is (green): it overlays the
	# bar, so the panel does not grow.
	var food_mark := ColorRect.new()
	food_mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	food_mark.anchor_right = 1.0
	food_mark.anchor_top = 1.0
	food_mark.anchor_bottom = 1.0
	food_mark.offset_top = -2.0
	food_mark.visible = false
	hp_bar.add_child(food_mark)

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

	return {"root": root, "box": box, "name_label": name_label, "portrait": portrait, "buff_ring": buff_ring, "ring_style": ring, "shaken": shaken, "food_mark": food_mark, "hands": hands,
		"equip_hint": equip_hint, "hp_bar": hp_bar, "mana_bar": mana_bar, "quick": quick_slots}


# --------------------------------------------------------------------------
# Hover: the same treatment on every clickable thing in the panel
# --------------------------------------------------------------------------

## A hero's name under the pointer: it brightens to torch gold and gets a thin underline.
func _hover_name(label: Label, underline: ColorRect, on: bool) -> void:
	label.add_theme_color_override("font_color", NAME_HOVER if on else NAME_NORMAL)
	underline.visible = on
	if on:
		var font: Font = label.get_theme_font("font")
		var width: float = font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
		underline.size = Vector2(width, 2)
		underline.position = Vector2((label.size.x - width) / 2.0, label.size.y - 2.0)


## Any clickable control: a pointing hand over it, and `target` (the control or its picture) brightens
## while the pointer is on it. Uses self_modulate, which nothing else here touches (the cooling dim, the
## drag fade and the dead grey all use modulate).
func _make_hoverable(control: Control, target: CanvasItem) -> void:
	control.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	control.mouse_entered.connect(func(): target.self_modulate = HOVER_BRIGHT)
	control.mouse_exited.connect(func(): target.self_modulate = Color.WHITE)


## Which panel (position) the mouse is over, or -1. Used by the C key.
func slot_under_mouse() -> int:
	return _panel_at(get_viewport().get_mouse_position())


func _make_hand(m, i: int) -> TextureButton:
	var hand := TextureButton.new()
	hand.texture_normal = m.def.hand_icon
	hand.custom_minimum_size = HAND_SIZE
	hand.ignore_texture_size = true
	hand.stretch_mode = TextureButton.STRETCH_KEEP_CENTERED
	hand.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	hand.focus_mode = Control.FOCUS_NONE  # Space/Enter shouldn't trigger it.
	hand.pressed.connect(_on_hand.bind(m.slot, i))
	hand.gui_input.connect(_on_hand_input.bind(m.slot, i))  # Right-click lifts the item out onto the cursor.
	hand.add_child(StackCount.new())  # How many darts are left (child 0; see _show_hand).
	var frame := TextureRect.new()  # The iron bevel behind the icon, at the portraits' pixel density.
	frame.texture = HAND_FRAME
	frame.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.show_behind_parent = true
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	hand.add_child(frame)
	var sweep := TextureProgressBar.new()
	sweep.texture_progress = HAND_SWEEP
	sweep.tint_progress = SWEEP_TINT
	sweep.fill_mode = TextureProgressBar.FILL_CLOCKWISE
	sweep.min_value = 0.0
	sweep.max_value = 100.0
	sweep.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sweep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sweep.visible = false
	hand.add_child(sweep)
	hand.set_meta("sweep", sweep)
	_make_hoverable(hand, hand)
	return hand


func _label(text: String, size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Color(0.92, 0.89, 0.82))
	l.add_theme_color_override("font_shadow_color", HP_BACK)  # A 1 px ink drop shadow: whole pixels only, so every letter stays crisp.
	l.add_theme_constant_override("shadow_offset_x", 1)
	l.add_theme_constant_override("shadow_offset_y", 1)
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
