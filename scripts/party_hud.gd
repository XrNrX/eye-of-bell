extends CanvasLayer
## Party HUD: one panel per hero (name, HP, weapon-hand button), floating damage
## numbers when a hero is hit, and a red screen flash. Click a hand (or press 1-4)
## to attack; the hand greys out while that hero's attack cools down.
## Talks to the party only through its signals and the "party" group.

const CombatRules := preload("res://scripts/combat_rules.gd")

const HAND_READY := Color(1, 1, 1)
const HAND_COOLING := Color(0.35, 0.33, 0.38)
const PANEL_BG := Color(0.137, 0.118, 0.169, 0.88)  # Palette stone_900.
const PANEL_EDGE := Color(0.275, 0.247, 0.31)        # Palette stone_700.
const HP_FILL := Color(0.69, 0.35, 0.165)            # Palette rust_500.
const HP_BACK := Color(0.078, 0.063, 0.102)          # Palette ink.
const COOL_FILL := Color(0.588, 0.557, 0.604)        # Palette stone_300.
const HIT_COLOUR := Color(0.85, 0.51, 0.26)          # Palette rust_300.
const MISS_COLOUR := Color(0.76, 0.74, 0.75)         # Palette stone_100.

@onready var flash: ColorRect = %Flash
@onready var panels_box: HBoxContainer = %Panels

var party: Node
var panels := {}  # slot -> {hand, cool_bar, hp_bar, hp_label, root}


func _ready() -> void:
	party = get_tree().get_first_node_in_group("party")
	if party == null:
		return
	for m in party.members:
		panels[m.slot] = _make_panel(m)
		_update_hp(m.slot)
	party.hp_changed.connect(_update_hp)
	party.hero_hit.connect(_on_hero_hit)


func _process(_delta: float) -> void:
	if party == null:
		return
	for m in party.members:
		var p: Dictionary = panels[m.slot]
		var cooling: bool = m.cooldown_left > 0.0 or not m.is_alive()
		p.hand.disabled = cooling
		p.hand.modulate = HAND_COOLING if cooling else HAND_READY
		var total := CombatRules.hero_cooldown(m.def.speed)
		p.cool_bar.value = (m.cooldown_left / total) * 100.0 if m.is_alive() else 0.0


func _update_hp(slot: int) -> void:
	var m = party.member(slot)
	var p: Dictionary = panels[slot]
	p.hp_bar.max_value = m.def.max_hp
	p.hp_bar.value = m.hp
	p.hp_label.text = "%d/%d" % [m.hp, m.def.max_hp]
	if not m.is_alive():
		p.root.modulate = Color(0.5, 0.5, 0.5)


## A hero was attacked: float the damage (or "Miss") above their panel; red flash on a hit.
func _on_hero_hit(slot: int, damage: int) -> void:
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


func _make_panel(m) -> Dictionary:
	var root := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = PANEL_BG
	box.border_color = PANEL_EDGE
	box.set_border_width_all(1)
	box.set_content_margin_all(3)
	root.add_theme_stylebox_override("panel", box)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panels_box.add_child(root)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(row)

	# Weapon hand: a button, with a thin cooldown bar under it.
	var hand_col := VBoxContainer.new()
	hand_col.add_theme_constant_override("separation", 1)
	row.add_child(hand_col)
	var hand := TextureButton.new()
	hand.texture_normal = m.def.hand_icon
	hand.custom_minimum_size = Vector2(24, 24)
	hand.ignore_texture_size = true
	hand.stretch_mode = TextureButton.STRETCH_KEEP_CENTERED
	hand.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	hand.focus_mode = Control.FOCUS_NONE  # Space/Enter shouldn't trigger it.
	hand.tooltip_text = "Attack (%d)" % (m.slot + 1)
	hand.pressed.connect(func(): party.attack(m.slot))
	hand_col.add_child(hand)
	var cool_bar := _bar(COOL_FILL, Vector2(24, 2), 100)
	hand_col.add_child(cool_bar)

	# Name, HP numbers and HP bar.
	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 1)
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(info)
	var name_label := _label(m.def.display_name, 9)
	info.add_child(name_label)
	var hp_label := _label("", 8)
	info.add_child(hp_label)
	var hp_bar := _bar(HP_FILL, Vector2(36, 3), m.def.max_hp)
	info.add_child(hp_bar)

	return {"root": root, "hand": hand, "cool_bar": cool_bar, "hp_bar": hp_bar, "hp_label": hp_label}


func _label(text: String, size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Color(0.92, 0.89, 0.82))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
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
