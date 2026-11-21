extends Control
## The worn-gold frame and slow golden shimmer of a legendary item (7g.1), laid over whatever shows the item: an inventory slot, a hand
## or quick slot on the party panel, the loot pop-up's header. Gold, never curse green (docs/art_style.md).
##
##     LegendaryMark.sync(slot_control, stack)   # adds the mark when the stack is a legendary item, removes it otherwise; cheap to call every frame
##
## Art: art/ui/legend_frame.png (a PixelLab frame, a 32x32 nine-patch with a clear centre) and art/ui/legend_shimmer_sheet.png (the VFX tool's
## glints on a gold ramp, a row of frames at 12 fps played slowly), made by tools/art/gen_legendary.py. The frame stretches to the
## control; the glint is drawn at its own pixel size, centred on the item. `Settings.reduce_flashing` keeps the frame and drops the twinkle.

const Settings := preload("res://scripts/settings.gd")

const NODE_NAME := "LegendMark"
const FRAME_PATH := "res://art/ui/legend_frame.png"
const SHEET_PATH := "res://art/ui/legend_shimmer_sheet.png"
const INFO_PATH := "res://art/ui/legend_shimmer_sheet.json"
const PATCH := 5          # The frame's border, in pixels, that never stretches.
const SLOWNESS := 0.6     # The shimmer plays this much slower than its 12 fps: a slow twinkle, not a flash.

var _frame: NinePatchRect
var _shimmer: TextureRect
var _atlas: AtlasTexture
var _frames := 16
var _fps := 12.0
var _w := 27
var _h := 34
var _t := 0.0


## Add the mark to `parent` if `stack` holds a legendary item, take it away if it does not.
static func sync(parent: Control, stack) -> void:
	var mark := parent.get_node_or_null(NODE_NAME)
	var want: bool = stack != null and stack.def.legendary
	if want and mark == null:
		mark = load("res://scripts/legendary_mark.gd").new()
		mark.name = NODE_NAME
		parent.add_child(mark)
	elif not want and mark != null:
		parent.remove_child(mark)
		mark.queue_free()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if ResourceLoader.exists(FRAME_PATH):
		_frame = NinePatchRect.new()
		_frame.texture = load(FRAME_PATH)
		_frame.patch_margin_left = PATCH
		_frame.patch_margin_right = PATCH
		_frame.patch_margin_top = PATCH
		_frame.patch_margin_bottom = PATCH
		_frame.draw_center = false
		_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(_frame)
	if ResourceLoader.exists(SHEET_PATH):
		if FileAccess.file_exists(INFO_PATH):
			var info = JSON.parse_string(FileAccess.get_file_as_string(INFO_PATH))
			if info is Dictionary:
				_frames = int(info.frames)
				_fps = float(info.fps)
				_w = int(info.frame_w)
				_h = int(info.frame_h)
		_atlas = AtlasTexture.new()
		_atlas.atlas = load(SHEET_PATH)
		_atlas.region = Rect2(0, 0, _w, _h)
		_shimmer = TextureRect.new()
		_shimmer.texture = _atlas
		_shimmer.size = Vector2(_w, _h)
		_shimmer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_shimmer.visible = not Settings.reduce_flashing
		add_child(_shimmer)


func _process(delta: float) -> void:
	if _shimmer == null:
		return
	_shimmer.visible = not Settings.reduce_flashing
	_t += delta
	var i := int(_t * _fps * SLOWNESS) % _frames
	_atlas.region = Rect2(i * _w, 0, _w, _h)
	_shimmer.position = ((size - Vector2(_w, _h)) * 0.5).round()
