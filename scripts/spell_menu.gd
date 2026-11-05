extends PanelContainer
## The small pop-up list of spells opened by clicking a hero's hand that holds a
## spellbook or holy symbol (see party_hud.gd). One row per spell: name and mana cost,
## greyed out while the hero can't afford it. Clicking a row emits `chosen`; the HUD
## then casts it, or asks for a target first (Shield, Heal). The game keeps running
## while it's open. The HUD closes it (cancel, cast, caster died, item left the hand).

signal chosen(spell: Resource)

const BG := Color(0.078, 0.075, 0.106, 0.95)  # Palette stone_900.
const EDGE := Color(0.851, 0.604, 0.212)      # Palette torch_500, like the mana bar.
const TEXT := Color(0.92, 0.89, 0.82)
const TEXT_OFF := Color(0.314, 0.31, 0.369)  # Palette stone_500.
const ROW_HOVER := Color(0.192, 0.188, 0.235)  # Palette stone_700.
const WIDTH := 150.0

var party: Node
var caster: int
var rows := []  # [{button, spell}]


func setup(a_party: Node, a_caster: int, spells: Array) -> void:
	party = a_party
	caster = a_caster
	var box := StyleBoxFlat.new()
	box.bg_color = BG
	box.border_color = EDGE
	box.set_border_width_all(2)
	box.set_content_margin_all(4)
	add_theme_stylebox_override("panel", box)
	custom_minimum_size.x = WIDTH
	mouse_filter = Control.MOUSE_FILTER_STOP  # A click on the frame shouldn't fall through.

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(col)
	for spell in spells:
		var b := Button.new()
		b.text = "%s  %d" % [spell.display_name, spell.mana_cost]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.focus_mode = Control.FOCUS_NONE
		b.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS  # Act on the press, like every other click.
		b.add_theme_font_size_override("font_size", 8)
		b.add_theme_color_override("font_color", TEXT)
		b.add_theme_color_override("font_hover_color", TEXT)
		b.add_theme_color_override("font_pressed_color", TEXT)
		b.add_theme_color_override("font_disabled_color", TEXT_OFF)
		for state in ["normal", "pressed", "disabled", "focus"]:
			b.add_theme_stylebox_override(state, _flat(Color(0, 0, 0, 0)))
		b.add_theme_stylebox_override("hover", _flat(ROW_HOVER))
		b.pressed.connect(func(): chosen.emit(spell))
		col.add_child(b)
		rows.append({"button": b, "spell": spell})
	refresh()


func _flat(colour: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = colour
	s.set_content_margin_all(3)
	s.content_margin_left = 6
	return s


func _process(_delta: float) -> void:
	refresh()  # Mana regenerates while the list is open.


func refresh() -> void:
	for r in rows:
		r.button.disabled = not party.can_afford(caster, r.spell)
