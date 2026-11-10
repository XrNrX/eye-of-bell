extends CanvasLayer
## The stone UI frame: one picture (art/ui/frame.png: 1280x720 on the hires-720 branch, drawn by tools/art/gen_frame_hd.py; it was
## 640x360 from tools/art/gen_frame.py) shown over the whole 640x360 canvas
## laid over the 3D world. It is opaque everywhere except the 3D view window, so it hides the
## rest of the rendered world and gives the log, arrows and party their dark recessed panels.
## The HUD layers (log, arrows, party) sit on top of it. Never takes a click.
## Self-contained: delete this node and the 3D view fills the screen behind the HUD again.

const UiLayout := preload("res://scripts/ui_layout.gd")
const FRAME := preload("res://art/ui/frame.png")


func _ready() -> void:
	layer = UiLayout.FRAME_LAYER
	var picture := TextureRect.new()
	picture.texture = FRAME
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE  # The picture has more pixels than the canvas has units: scale it to fit.
	picture.stretch_mode = TextureRect.STRETCH_SCALE
	picture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	picture.position = Vector2.ZERO
	picture.size = UiLayout.SCREEN
	add_child(picture)
