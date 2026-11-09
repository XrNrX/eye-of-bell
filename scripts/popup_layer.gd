extends CanvasLayer
## The one home for every pop-up and menu (the spell list, and anything added later): a canvas layer above the whole HUD
## (the minimap's overlay is 10, the inventory 11, the held item 15) and below only the full-screen map (18), the pause
## menu (19) and the end screens, so a pop-up can never be drawn behind the minimap or a panel. Put a pop-up here with
##     get_tree().get_first_node_in_group("popups").open_popup(control, func(size): return preferred_top_left)
## and never add it to a HUD node. It also:
##  - places it fully on screen and clear of every visible node in group "popup_avoid" (the minimap), trying the
##    candidate positions in order, then below and to the left of each avoided rectangle;
##  - dims the minimap (group "popup_avoid", `set_dimmed(true)`) while any pop-up is open, so the pop-up is the focus.
## Godot's own tooltips are drawn by the engine above every canvas layer, so they never need this.

const UiLayout := preload("res://scripts/ui_layout.gd")

const MARGIN := 2.0
const SCREEN := Rect2(0, 0, 640, 360)

var open_count := 0


func _ready() -> void:
	layer = UiLayout.POPUP_LAYER
	add_to_group("popups")


## Add `popup` (a Control that has been set up) to this layer. `preferred` is a Callable taking the pop-up's real size
## (known only once it is in the tree, with its theme applied) and returning where its top-left would like to be. The
## pop-up goes there if it fits on screen and clears the minimap, else below or to the left of the minimap, else wherever it
## overlaps least.
func open_popup(popup: Control, preferred: Callable) -> void:
	add_child(popup)
	popup.size = popup.get_combined_minimum_size()
	var avoid := avoid_rects()
	popup.position = best_position(popup.size, around(preferred.call(popup.size), popup.size, avoid), avoid)
	open_count += 1
	_dim_avoided(true)
	popup.tree_exited.connect(_closed)


func _closed() -> void:
	open_count = maxi(0, open_count - 1)
	if open_count == 0:
		_dim_avoided(false)


## Screen rectangles that a pop-up must keep clear of: every visible node in group "popup_avoid".
func avoid_rects() -> Array:
	var out := []
	for n in get_tree().get_nodes_in_group("popup_avoid"):
		if n is Control and n.is_visible_in_tree():
			out.append(n.get_global_rect())
	return out


func _dim_avoided(on: bool) -> void:
	get_tree().call_group("popup_avoid", "set_dimmed", on)


## The extra candidates round the avoided rectangles: straight below each (same x) and to the left of each (same y), for
## a pop-up whose preferred spot is `preferred`.
static func around(preferred: Vector2, size: Vector2, avoid: Array) -> Array:
	var out := [preferred]
	for r in avoid:
		out.append(Vector2(preferred.x, r.end.y + MARGIN))
		out.append(Vector2(r.position.x - size.x - MARGIN, preferred.y))
	return out


## The first candidate (clamped so the whole pop-up is on screen) that overlaps none of `avoid`; if every one overlaps,
## the clamped candidate with the smallest overlap. A pure function so tests can call it.
static func best_position(size: Vector2, candidates: Array, avoid: Array) -> Vector2:
	var best := Vector2(MARGIN, MARGIN)
	var best_overlap := INF
	for c in candidates:
		var p := Vector2(clampf(c.x, MARGIN, SCREEN.end.x - size.x - MARGIN),
				clampf(c.y, MARGIN, SCREEN.end.y - size.y - MARGIN))
		var overlap := 0.0
		for r in avoid:
			var i: Rect2 = Rect2(p, size).intersection(Rect2(r).grow(MARGIN))
			overlap += i.get_area()
		if overlap == 0.0:
			return p
		if overlap < best_overlap:
			best_overlap = overlap
			best = p
	return best
