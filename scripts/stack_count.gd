extends Control
## The small pixel number in the bottom-right corner of an item icon ("3" for a stack
## of three). Add it as a child of the icon's Control (it sizes itself to fill it) and call
## set_count(); it draws nothing for a count of 0 or 1. Digits come from the 5x7-cell
## sheet art/ui/digits.png (see tools/art/gen_ui.py): a 3x5 glyph with a 1px outline,
## cells overlapping by that outline so the digits sit close together.

const DIGITS := preload("res://art/ui/digits.png")
const CELL := Vector2i(5, 7)
const ADVANCE := 4  # Cells overlap by their outline column.

var count := 0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# Match the parent's size by hand (anchors alone left this at 0x0 inside a slot that
	# was already laid out), and keep matching when it resizes.
	var parent := get_parent_control()
	_fit(parent)
	parent.resized.connect(_fit.bind(parent))


func _fit(parent: Control) -> void:
	position = Vector2.ZERO
	size = parent.size


func set_count(n: int) -> void:
	if n != count:
		count = n
		queue_redraw()


func _draw() -> void:
	if count < 2:
		return
	var text := str(count)
	var width := ADVANCE * (text.length() - 1) + CELL.x
	var origin := Vector2(size.x - width, size.y - CELL.y)  # Flush with the corner; stays inside the control.
	for i in text.length():
		var d := text.unicode_at(i) - 48
		draw_texture_rect_region(DIGITS,
				Rect2(origin + Vector2(i * ADVANCE, 0), Vector2(CELL)),
				Rect2(Vector2(d * CELL.x, 0), Vector2(CELL)))
