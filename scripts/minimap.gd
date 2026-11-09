extends Control
## The in-world map: the cells around the player, with the player always in the middle (north is up) and a
## triangle for the way they face, inked on a torn parchment inside a small rusted iron frame
## (art/ui/map_parchment.png and map_frame.png from tools/art/gen_map_art.py, native pixels).
## Cells are drawn as on the full-screen map (automap.gd, via map_symbols.gd): floor an ink wash, walls inked where they
## touch floor. Every cell near the party is drawn (there is no fog of war: a first version was shelved).
## Drawn by debug_overlay.gd on Tab. Everything is palette colours.

const DungeonMap := preload("res://scripts/dungeon_map.gd")
const Settings := preload("res://scripts/settings.gd")
const MapSymbols := preload("res://scripts/map_symbols.gd")

const PARCHMENT := preload("res://art/ui/map_parchment.png")
const FRAME := preload("res://art/ui/map_frame.png")
const TORCH_SHEET := preload("res://art/ui/map/torchlight_sheet.png")  # 4x3 frames of 104x80 (gen_map_torchlight.py).
const TORCH_FRAMES := 12
const TORCH_FPS := 10.0
const TORCH_STRENGTH := 0.16   # Additive, so this stays a faint warmth on the paper.
const TORCH_STEADY := 0.08     # With Reduce flashing: one still frame, dimmer.
const BORDER := 4                  # Thickness of the iron frame, in pixels.

const CELL_PX := 8                 # One map cell, in 640x360 pixels.
const COLS := 13                   # How many cells wide and tall the window shows (odd: the player is in the middle).
const ROWS := 10

const INK := Color("0b0a10")

var player: Node3D  # Assigned by debug_overlay.gd.
var torch: TextureRect        # The torchlight flicker laid over the parchment.
var torch_frame := AtlasTexture.new()
var clock := 0.0
var icons := {}     # name -> Texture2D, loaded once.
var wash: Texture2D # One cell of floor wash.


func _ready() -> void:
	torch_frame.atlas = TORCH_SHEET
	torch = TextureRect.new()
	torch.texture = torch_frame
	torch.position = Vector2(BORDER, BORDER)
	torch.size = Vector2(TORCH_SHEET.get_width() / 4, TORCH_SHEET.get_height() / 3)
	torch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	torch.material = add
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	add_child(torch)
	_set_torch_frame(0)
	icons = MapSymbols.load_icons(true)
	wash = MapSymbols.make_wash(CELL_PX)
	custom_minimum_size = FRAME.get_size()
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	clip_contents = true


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), INK)  # Behind the torn edges of the paper.
	draw_texture(PARCHMENT, Vector2(BORDER, BORDER))
	if player == null:
		draw_texture(FRAME, Vector2.ZERO)
		return
	var origin: Vector2i = player.cell - Vector2i(COLS / 2, ROWS / 2)  # Map cell drawn in the top-left corner.
	draw_set_transform(Vector2(BORDER, BORDER))
	for row in ROWS:
		for col in COLS:
			var c := origin + Vector2i(col, row)
			if c.y < 0 or c.y >= DungeonMap.MAP.size() or c.x < 0 or c.x >= DungeonMap.MAP[c.y].size():
				continue  # Off the edge of the level: empty.
			MapSymbols.draw_cell(self, c, Vector2(col, row) * CELL_PX, CELL_PX, wash)  # The same cells as the M map.

	# (Monsters are not drawn: the map is the party's own sketch, and shows nothing it has not met.
	# Traps and ambushes are not drawn either.)
	for row in ROWS:
		for col in COLS:
			var poi := MapSymbols.poi_for(origin + Vector2i(col, row))
			if poi != "":
				MapSymbols.draw_poi(self, icons[poi], Vector2(col, row) * CELL_PX, CELL_PX, true)
	for lever in DungeonMap.LEVERS:
		var at: Vector2i = lever.cell - origin
		if at.x >= 0 and at.y >= 0 and at.x < COLS and at.y < ROWS:
			MapSymbols.draw_poi(self, icons["lever"], Vector2(at) * CELL_PX, CELL_PX, true)

	# The party: a small arrow in the middle cell, turned to the way they face.
	MapSymbols.draw_arrow(self, Vector2(COLS / 2, ROWS / 2) * CELL_PX, CELL_PX, player.facing)
	draw_set_transform(Vector2.ZERO)  # Back to the panel's own corner for the frame.
	draw_texture(FRAME, Vector2.ZERO)


## Which frame of the flicker shows. Reduce flashing holds one still frame, dimmer.
func _process(delta: float) -> void:
	clock += delta
	var steady: bool = Settings.reduce_flashing
	_set_torch_frame(0 if steady else int(clock * TORCH_FPS) % TORCH_FRAMES)
	torch.modulate.a = TORCH_STEADY if steady else TORCH_STRENGTH


func _set_torch_frame(i: int) -> void:
	var w := TORCH_SHEET.get_width() / 4
	var h := TORCH_SHEET.get_height() / 3
	torch_frame.region = Rect2((i % 4) * w, (i / 4) * h, w, h)
