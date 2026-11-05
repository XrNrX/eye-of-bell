extends CanvasLayer
## The stone UI frame: one 320x200 picture (art/ui/frame.png, drawn by tools/art/gen_frame.py)
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
	picture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	picture.position = Vector2.ZERO
	picture.size = UiLayout.SCREEN
	add_child(picture)
