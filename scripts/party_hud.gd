extends CanvasLayer
## Party HUD: a 2x2 grid of hero panels (portrait, two quick slots, name, HP bar, mana
## bar, two hand buttons, cooldown bar), floating damage numbers when a hero is hit,
## and a red screen flash. Talks to the party through its signals, group and polling.
##
## Each hand button shows the item in that hand (an empty hand shows the fist) and
## acts with it (Party.act): swing, throw, or -- for a spellbook or holy symbol --
## open the spell pop-up (spell_menu.gd). Picking a spell that needs a hero (Shield,
## Heal) enters target mode: the next portrait click casts it. Right-click, Esc or a
## click anywhere else cancels the pop-up or target mode. Otherwise a portrait click
## opens that hero's inventory (group "inventory"). The game keeps running throughout.

const CombatRules := preload("res://scripts/combat_rules.gd")
const QuickSlot := preload("res://scripts/quick_slot.gd")
const SpellMenu := preload("res://scripts/spell_menu.gd")
const SpellDef := preload("res://scripts/spell_def.gd")
const StackCount := preload("res://scripts/stack_count.gd")

const PORTRAIT_SIZE := Vector2(24, 24)
const HAND_SIZE := Vector2(12, 12)
const BAR_WIDTH := 24.0

const HAND_READY := Color(1, 1, 1)
const HAND_COOLING := Color(0.35, 0.33, 0.38)
const PANEL_BG := Color(0.137, 0.118, 0.169, 0.88)  # Palette stone_900.
const PANEL_EDGE := Color(0.275, 0.247, 0.31)        # Palette stone_700.
const HP_FILL := Color(0.69, 0.35, 0.165)            # Palette rust_500.
const HP_BACK := Color(0.078, 0.063, 0.102)          # Palette ink.
const COOL_FILL := Color(0.588, 0.557, 0.604)        # Palette stone_300.
const HIT_COLOUR := Color(0.85, 0.51, 0.26)          # Palette rust_300.
const MISS_COLOUR := Color(0.76, 0.74, 0.75)         # Palette stone_100.
const MANA_FILL := Color(0.941, 0.722, 0.227)        # Palette torch_500 (the palette has no blue).
const BUFF_EDGE := MANA_FILL                         # Outline on a buffed hero's portrait.
const HURT_FLASH_TIME := 0.3  # How long the portrait shows its red-tinted variant.

@onready var flash: ColorRect = %Flash
@onready var panels_grid: GridContainer = %Panels

var party: Node
var panels := {}  # slot -> {root, portrait, buff_ring, quick, hp_bar, mana_bar, hands, cool_bar}

# Casting state: the open pop-up, and the spell waiting for a target hero.
var menu: Control
var menu_owner := {}   # {"caster", "hand"} for the open pop-up.
var pending := {}      # {"caster", "hand", "spell"} in target mode.
var catcher: Control   # Full-screen, under the panels: a click on it cancels.


func _ready() -> void:
	party = get_tree().get_first_node_in_group("party")
	if party == null:
		return
	for m in party.members:
		panels[m.slot] = _make_panel(m)
		_update_hp(m.slot)
	party.hp_changed.connect(_update_hp)
	party.hero_hit.connect(_on_hero_hit)

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
	for m in party.members:
		var p: Dictionary = panels[m.slot]
		var cooling: bool = m.cooldown_left > 0.0 or not m.is_alive()
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


## Draw what's in a hand: the item's small icon (with a count for a stack of darts),
## or the fist when it's empty.
func _show_hand(m, i: int, hand: TextureButton) -> void:
	var stack = m.hands[i]
	var tex: Texture2D = m.def.hand_icon
	if stack:
		tex = stack.def.floor_icon if stack.def.floor_icon else stack.def.icon
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
	if pending.is_empty():
		get_tree().call_group("inventory", "show_screen", slot)
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
	label.add_theme_font_size_override("font_size", 12)
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
		flash.color.a = 0.35
		create_tween().tween_property(flash, "color:a", 0.0, 0.35)
		if m.is_alive():  # Still alive: flash the hurt portrait, then revert. Dead
			p.portrait.texture_normal = m.def.portrait_hurt  # already shows portrait_dead permanently.
			var timer := get_tree().create_timer(HURT_FLASH_TIME)
			timer.timeout.connect(func():
				if m.is_alive():
					p.portrait.texture_normal = m.def.portrait)


func _make_panel(m) -> Dictionary:
	var root := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = PANEL_BG
	box.border_color = PANEL_EDGE
	box.set_border_width_all(1)
	box.set_content_margin_all(3)
	root.add_theme_stylebox_override("panel", box)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panels_grid.add_child(root)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 1)
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
	portrait.pressed.connect(_on_portrait.bind(m.slot))
	col.add_child(portrait)

	# A gold outline over the portrait while a buff (Shield, Bless) is active.
	var buff_ring := Panel.new()
	var ring := StyleBoxFlat.new()
	ring.draw_center = false
	ring.border_color = BUFF_EDGE
	ring.set_border_width_all(1)
	buff_ring.add_theme_stylebox_override("panel", ring)
	buff_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	buff_ring.visible = false
	portrait.add_child(buff_ring)
	portrait.resized.connect(func(): buff_ring.size = portrait.size)

	# Two quick slots under the portrait (consumables; see quick_slot.gd).
	var quick_row := HBoxContainer.new()
	quick_row.add_theme_constant_override("separation", 0)
	quick_row.alignment = BoxContainer.ALIGNMENT_CENTER
	quick_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(quick_row)
	var quick_slots := []
	for qi in party.QUICK_SLOTS:
		var qs := QuickSlot.new()
		qs.setup(party, m.slot, qi)
		quick_row.add_child(qs)
		quick_slots.append(qs)

	col.add_child(_label(m.def.display_name, 8))

	var hp_bar := _bar(HP_FILL, Vector2(BAR_WIDTH, 3), m.def.max_hp)
	col.add_child(hp_bar)

	# Mana, for casters. Every panel keeps the row (invisible without mana) so the
	# hand buttons line up across a row of panels.
	var mana_bar := _bar(MANA_FILL, Vector2(BAR_WIDTH, 2), maxi(1, m.def.max_mana))
	mana_bar.modulate.a = 1.0 if m.def.max_mana > 0 else 0.0
	col.add_child(mana_bar)

	# Two hands (left/right), each acting with the item it holds.
	var hands_row := HBoxContainer.new()
	hands_row.add_theme_constant_override("separation", 2)
	hands_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(hands_row)
	var hands := []
	for i in party.HAND_SLOTS:
		var hand := _make_hand(m, i)
		hands_row.add_child(hand)
		hands.append(hand)

	var cool_bar := _bar(COOL_FILL, Vector2(BAR_WIDTH, 2), 100)
	col.add_child(cool_bar)

	return {"root": root, "portrait": portrait, "buff_ring": buff_ring, "hands": hands,
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
