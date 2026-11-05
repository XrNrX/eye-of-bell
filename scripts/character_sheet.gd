extends PanelContainer
## The character sheet: a panel beside the inventory window (built and positioned by
## inventory_screen.gd, which owns it) showing the focused hero's portrait, class,
## HP and mana, combat stats and equipped items. Opened by clicking a hero's name on
## the party HUD or the name in the inventory header (a second click on that closes it).
##
## Stat values come from Party.effective_stats() with buffs left out, so they show what
## the *gear* does: a stat that gear raises is green with a "+n", one it lowers is red
## with a "-n" (the base value is in the row's tooltip). Active buffs (Shield, Bless) are
## listed below the equipment, one per line. Plain colours alone would fail a colour-blind player, hence
## the signed numbers. The palette has no red or green: better = slime_300, worse =
## rust_300, the nearest it has.
##
## Pure view: it reads Party and writes nothing. refresh() is called by the inventory
## screen after every change, so equipping a sword updates it live.

const CombatRules := preload("res://scripts/combat_rules.gd")
const ItemDef := preload("res://scripts/item_def.gd")

const WIDTH := 150.0
const BG := Color(0.078, 0.075, 0.106, 0.95)     # Palette stone_900.
const EDGE := Color(0.192, 0.188, 0.235)           # Palette stone_700.
const TEXT := Color(0.92, 0.89, 0.82)
const MUTED := Color(0.482, 0.478, 0.533)         # Palette stone_300.
const TITLE := Color(1, 0.85, 0.3)
const BETTER := Color(0.525, 0.651, 0.447)          # Palette slime_300.
const WORSE := Color(0.659, 0.404, 0.227)         # Palette rust_300.
const FONT := 8

var party: Node
var portrait: TextureRect
var title: Label
var row_label: Label
var rows := {}          # stat key -> {name, value, delta} labels
var buff_label: Label
var gear_labels := []   # One per hand slot, then armour.
var mana_row: Control


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP  # Clicks on the sheet must not reach the backdrop (floor drop).
	custom_minimum_size.x = WIDTH
	var box := StyleBoxFlat.new()
	box.bg_color = BG
	box.border_color = EDGE
	box.set_border_width_all(2)
	box.set_content_margin_all(8)
	add_theme_stylebox_override("panel", box)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 3)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(col)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(head)
	portrait = TextureRect.new()
	portrait.custom_minimum_size = Vector2(48, 48)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_SCALE
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(portrait)
	var names := VBoxContainer.new()
	names.add_theme_constant_override("separation", 0)
	names.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(names)
	title = _label("", TITLE)
	names.add_child(title)
	row_label = _label("", MUTED)
	names.add_child(row_label)

	_stat_row(col, "hp", "HP")
	mana_row = _stat_row(col, "mana", "Mana")

	_stat_row(col, "attack", "Attack")
	_stat_row(col, "defence", "Defence")
	_stat_row(col, "damage", "Damage")
	_stat_row(col, "swing", "Swing")

	col.add_child(_heading("Equipped"))
	for i in 3:
		var l := _label("", TEXT)
		l.clip_text = true
		l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		l.custom_minimum_size.x = WIDTH - 16
		col.add_child(l)
		gear_labels.append(l)

	buff_label = _label("", BETTER)  # Buffs are good news.
	col.add_child(buff_label)


func _label(text: String, colour: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", FONT)
	l.add_theme_color_override("font_color", colour)
	l.mouse_filter = Control.MOUSE_FILTER_PASS  # Tooltips work, clicks still fall to the panel.
	return l


func _heading(text: String) -> Label:
	var l := _label(text, MUTED)
	l.add_theme_constant_override("line_spacing", 0)
	return l


## One stat row: "Attack   4 +1". The delta label is separate so it takes the colour too.
func _stat_row(parent: Control, key: String, text: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	var n := _label(text, MUTED)
	n.custom_minimum_size.x = 64
	var v := _label("", TEXT)
	var d := _label("", TEXT)
	for l in [n, v, d]:
		row.add_child(l)
	parent.add_child(row)
	rows[key] = {"name": n, "value": v, "delta": d, "row": row}
	return row


## Redraw for this hero.
func refresh(a_party: Node, slot: int) -> void:
	party = a_party
	var m = party.member(slot)
	portrait.texture = m.def.portrait if m.is_alive() else m.def.portrait_dead
	title.text = m.def.display_name  # A hero is their class: "Fighter", "Mage"...
	row_label.text = "Front row" if slot < 2 else "Back row"
	if not m.is_alive():
		row_label.text = "Dead"

	var gear = party.effective_stats(m, -1, false)  # Weapon and armour, no buffs.
	var base = m.def

	_show(rows.hp, "%d/%d" % [m.hp, m.def.max_hp], "", TEXT, "")
	mana_row.visible = m.def.max_mana > 0
	_show(rows.mana, "%d/%d" % [int(m.mana), m.def.max_mana], "", TEXT, "")

	_numeric("attack", gear.attack, base.attack)
	_numeric("defence", gear.defence, base.defence)

	var avg_gear: float = (gear.damage_min + gear.damage_max) / 2.0
	var avg_base: float = (base.damage_min + base.damage_max) / 2.0
	var dmg := "%d-%d" % [gear.damage_min, gear.damage_max]
	var dmg_tip := "Base %d-%d" % [base.damage_min, base.damage_max]
	_show(rows.damage, dmg, "", _colour_for(avg_gear - avg_base), dmg_tip)

	var swing := CombatRules.hero_cooldown(m.def.speed)
	_show(rows.swing, "%.2fs" % swing, "", TEXT,
			"Speed %d: one action every %.2f s (swing, throw or cast)" % [m.def.speed, swing])

	var hands: Array = m.hands
	gear_labels[0].text = "L " + _item_name(hands[0])
	gear_labels[1].text = "R " + _item_name(hands[1])
	gear_labels[2].text = "A " + _item_name(m.armour)
	for l in gear_labels:
		l.add_theme_color_override("font_color", MUTED if l.text.ends_with("-") else TEXT)

	var parts := []  # One line per buff, so a few of them can't push the sheet off the screen.
	for b in m.buffs:
		parts.append("%s %ds" % [b.spell.display_name, ceili(b.left)])
	buff_label.text = "
".join(parts)
	buff_label.visible = not parts.is_empty()


func _item_name(stack) -> String:
	return "-" if stack == null else stack.label()


func _numeric(key: String, gear_value: int, base_value: int) -> void:
	var diff := gear_value - base_value
	_show(rows[key], str(gear_value), "%+d" % diff if diff != 0 else "", _colour_for(diff),
			"Base %d" % base_value)


func _colour_for(diff: float) -> Color:
	if diff > 0.0:
		return BETTER
	if diff < 0.0:
		return WORSE
	return TEXT


func _show(row: Dictionary, value: String, delta: String, colour: Color, tip: String) -> void:
	row.value.text = value
	row.delta.text = delta
	row.value.add_theme_color_override("font_color", colour)
	row.delta.add_theme_color_override("font_color", colour)
	row.row.tooltip_text = tip
