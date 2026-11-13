extends PanelContainer
## The pop-up list of spells opened by clicking a hero's hand that holds a spellbook or holy symbol (see party_hud.gd),
## placed by popup_layer.gd. An iron-bound frame (art/ui/spell_frame.png, PixelLab, a nine-patch), a header with the hero's
## mana, and one row per spell: its icon (art/spells/icons/<spell>.png, PixelLab), name and mana cost, greyed out while the
## hero can't afford it. Clicking a row emits `chosen`; the HUD then casts it, or asks for a target first (Shield, Heal).
## The game keeps running while it's open. The HUD closes it (cancel, cast, caster died, item left the hand).

signal chosen(spell: Resource)

const FRAME := preload("res://art/ui/spell_frame.png")
const FRAME_MARGIN := 10          # Must match FRAME_MARGIN in tools/art/gen_spell_menu.py.
const ICON_DIR := "res://art/spells/icons/%s.png"
const ICON_SIZE := 16
const ROW_HEIGHT := 20
const WIDTH := 176.0

const TEXT := Color("c9c0a4")      # Palette bone_300.
const TEXT_OFF := Color("504f5e")  # stone_500.
const COST := Color("d99a36")      # torch_500, like the mana bar.
const HEADING := Color("9c9278")   # bone_500.
const LINE := Color("4e2a1a")      # rust_700.
const ROW_HOVER := Color("31303c") # stone_700.
const ROW_EDGE := Color("d99a36")  # torch_500: the hovered row's marker.
const ICON_OFF := Color(0.5, 0.5, 0.55)

var party: Node
var caster: int
var rows := []  # [{button, spell, icon, name, cost}]
var mana_label: Label


func setup(a_party: Node, a_caster: int, spells: Array) -> void:
	party = a_party
	caster = a_caster
	var box := StyleBoxTexture.new()
	box.texture = FRAME
	box.set_texture_margin_all(FRAME_MARGIN)
	box.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	box.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	box.set_content_margin_all(FRAME_MARGIN + 2)
	add_theme_stylebox_override("panel", box)
	custom_minimum_size.x = WIDTH
	mouse_filter = Control.MOUSE_FILTER_STOP  # A click on the frame shouldn't fall through.
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(col)

	var head := HBoxContainer.new()
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(head)
	head.add_child(_label("SPELLS", HEADING, true))
	mana_label = _label("", COST, false)
	mana_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	head.add_child(mana_label)
	var rule := ColorRect.new()  # A thin rusted rule under the heading.
	rule.color = LINE
	rule.custom_minimum_size = Vector2(0, 1)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(rule)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 3)
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(gap)

	for spell in spells:
		var b := Button.new()
		b.custom_minimum_size = Vector2(0, ROW_HEIGHT)
		b.focus_mode = Control.FOCUS_NONE
		b.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS  # Act on the press, like every other click.
		for state in ["normal", "pressed", "disabled", "focus"]:
			b.add_theme_stylebox_override(state, _flat(Color(0, 0, 0, 0), false))
		b.add_theme_stylebox_override("hover", _flat(ROW_HOVER, true))
		b.pressed.connect(func(): chosen.emit(spell))
		col.add_child(b)
		var line := HBoxContainer.new()
		line.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		line.offset_left = 4
		line.offset_right = -4
		line.add_theme_constant_override("separation", 6)
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(line)
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var path: String = ICON_DIR % spell.resource_path.get_file().get_basename()
		if ResourceLoader.exists(path):
			icon.texture = load(path)
		line.add_child(icon)
		var name_label := _label(spell.display_name, TEXT, true)
		name_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		line.add_child(name_label)
		var cost := _label(str(spell.mana_cost), COST, false)
		cost.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		cost.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		line.add_child(cost)
		rows.append({"button": b, "spell": spell, "icon": icon, "name": name_label, "cost": cost})
	refresh()


func _label(text: String, colour: Color, expand: bool) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 8)
	l.add_theme_color_override("font_color", colour)
	l.add_theme_color_override("font_shadow_color", Color("0b0a10"))  # ink, a 1 px shadow like the party panel's names.
	l.add_theme_constant_override("shadow_offset_x", 1)
	l.add_theme_constant_override("shadow_offset_y", 1)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if expand:
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


func _flat(colour: Color, marker: bool) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = colour
	if marker:  # The hovered row gets a torch-gold bar on its left edge.
		s.border_width_left = 2
		s.border_color = ROW_EDGE
	return s


func _process(_delta: float) -> void:
	refresh()  # Mana regenerates while the list is open.


func refresh() -> void:
	var m = party.member(caster)
	if m != null:
		mana_label.text = "MANA %d" % floori(m.mana)
	for r in rows:
		var wait: float = party.spell_wait_left(caster, r.spell)  # SpellDef.recast_seconds: the cost shows the seconds left instead.
		var ok: bool = party.can_afford(caster, r.spell) and wait <= 0.0
		r.cost.text = "%dS" % ceili(wait) if wait > 0.0 else str(r.spell.mana_cost)
		r.button.disabled = not ok
		r.name.add_theme_color_override("font_color", TEXT if ok else TEXT_OFF)
		r.cost.add_theme_color_override("font_color", COST if ok else TEXT_OFF)
		r.icon.modulate = Color.WHITE if ok else ICON_OFF
