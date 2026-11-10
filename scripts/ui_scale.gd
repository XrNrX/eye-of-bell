extends RefCounted
## The screen is a 640x360 canvas the window shows at a whole-number scale (project.godot: stretch mode canvas_items, scale mode
## integer), so everything 2D (UI, text, frame, party panels) is laid out in 640x360 units and drawn k times as many screen pixels,
## sharp: k is 2 in a 1280x720 window, 3 at 1080p, 4 at 1440p. The 3D views are different: they are SubViewports, and a container
## draws its viewport in canvas units, so left alone they would render 640x360-sized pictures and be enlarged k times. `fit_view`
## makes the container k times bigger and draws it at 1/k, so the viewport renders at the real screen resolution (e.g. 832x520 at k = 2)
## and each of its pixels is one screen pixel. Art drawn for a higher resolution can then be shown at 1/k of its pixel size in the
## UI's own units (a 96 px icon in a 48 unit box) and arrive at the screen 1:1.

## The whole-number scale the window is showing the canvas at (1 in a headless run).
static func factor(tree: SceneTree) -> int:
	return maxi(1, floori(tree.root.get_final_transform().x.x + 0.001))


## Make `view` (a SubViewportContainer with stretch on) show a viewport that is `logical_size` * k pixels in a space that stays
## `logical_size` units wide, at `position`. Call again whenever the window changes (see keep_fitted).
static func fit_view(view: SubViewportContainer, position: Vector2, logical_size: Vector2) -> int:
	var k := factor(view.get_tree())
	view.set_anchors_preset(Control.PRESET_TOP_LEFT)
	view.size = logical_size * k
	view.pivot_offset = Vector2.ZERO
	view.scale = Vector2.ONE / float(k)
	view.position = position
	var port := view.get_node_or_null("Port")
	if port is SubViewport:
		port.set_meta("view_scale", k)
	view.set_meta("view_scale", k)
	return k


## Refit whenever the window is resized or switches between fullscreen and windowed.
static func keep_fitted(view: SubViewportContainer, position: Vector2, logical_size: Vector2, on_change := Callable()) -> void:
	var refit := func():
		var before: int = view.get_meta("view_scale", 0)
		var k := fit_view(view, position, logical_size)
		if on_change.is_valid() and k != before:
			on_change.call(k)
	refit.call()
	view.get_window().size_changed.connect(refit)
