extends RefCounted
## The window style for overlays (inventory, character sheet): the main screen's blackened brick inside rusted iron lips,
## tiled so it fits any size. art/ui/panel_stone.png comes from tools/art/gen_frame.py.

const TEXTURE := preload("res://art/ui/panel_stone.png")
const LIP := 8.0      # The iron lip, in screen pixels: the part of the texture that never tiles.
const PADDING := 10.0 # From the outer edge to the content.


static func make() -> StyleBoxTexture:
	var box := StyleBoxTexture.new()
	box.texture = TEXTURE
	box.set_texture_margin_all(LIP)
	box.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	box.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	box.set_content_margin_all(PADDING)
	return box
