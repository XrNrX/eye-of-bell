extends SceneTree
## Pop-ups must draw above the HUD, stay fully on screen, and never overlap the minimap, whichever hero opens them.
## Run:  timeout 120 "$G" --headless --path . -s tests/popup_layout_test.gd   (exits non-zero on any failure)

const PopupLayer := preload("res://scripts/popup_layer.gd")
var fails := 0


func check(name: String, ok: bool) -> void:
	print(("PASS " if ok else "FAIL ") + name)
	if not ok:
		fails += 1


func _init() -> void:
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await create_timer(0.6).timeout
	var popups: Node = get_first_node_in_group("popups")
	var hud: Node = get_first_node_in_group("party_hud")
	var minimap: Control = get_first_node_in_group("popup_avoid")
	var automap: Node = root.find_child("Automap", true, false)
	check("popup layer, party hud and minimap exist", popups != null and hud != null and minimap != null)

	# Layering: above every HUD layer, below the full-screen map and the pause menu.
	var highest_hud := 0
	for n in root.find_children("*", "CanvasLayer", true, false):
		if n.get_viewport() == root and n != popups and n != automap and n.name not in ["PauseMenu", "LevelComplete", "GameOver"]:
			highest_hud = maxi(highest_hud, n.layer)
	check("popup layer is above every HUD layer (%d > %d)" % [popups.layer, highest_hud], popups.layer > highest_hud)
	check("popup layer is below the full-screen map", popups.layer < automap.layer)

	var spells := []
	for f in ["magic_missile", "fireball", "heal"]:
		spells.append(load("res://data/spells/%s.tres" % f))
	var screen := Rect2(0, 0, 640, 360)
	hud.set_process(false)  # (Its per-frame check would close a pop-up whose hero holds no spellbook; the test uses made-up spells.)

	for slot in 4:  # Every position on the party panel.
		hud._open_menu(slot, 0, spells)
		await process_frame
		var menu: Control = hud.menu
		var r := menu.get_global_rect()
		var map_rect := minimap.get_global_rect()
		check("slot %d: pop-up is on the popup layer" % slot, menu.get_parent() == popups)
		check("slot %d: pop-up fully on screen %s" % [slot, r], screen.encloses(r))
		check("slot %d: pop-up clear of the minimap (%s vs %s)" % [slot, r, map_rect], not r.intersects(map_rect))
		check("slot %d: minimap dimmed while it is open" % slot, minimap.modulate.r < 1.0)
		hud.cancel_casting()
		await process_frame
		await process_frame
		check("slot %d: minimap back to normal after" % slot, minimap.modulate == Color.WHITE and popups.open_count == 0)

	# The old spot (left of the party grid, level with a top-row hero's hands) does overlap the map: it must be moved.
	var size := Vector2(150, 60)
	var old_spot := Vector2(280, 38)
	check("the old spot really overlaps the minimap", Rect2(old_spot, size).intersects(minimap.get_global_rect()))
	var moved: Vector2 = PopupLayer.best_position(size, PopupLayer.around(old_spot, size, [minimap.get_global_rect()]),
			[minimap.get_global_rect()])
	check("best_position moves it clear", not Rect2(moved, size).intersects(minimap.get_global_rect()) and moved != old_spot)
	var off := PopupLayer.best_position(Vector2(150, 60), [Vector2(900, 900)], [])
	check("best_position clamps a far-off candidate onto the screen", screen.encloses(Rect2(off, Vector2(150, 60))))

	# Minimap hidden (Tab): nothing to avoid, the pop-up still opens fully on screen.
	var overlay: CanvasLayer = minimap.get_parent().get_parent()
	overlay.visible = false
	hud._open_menu(0, 0, spells)
	await process_frame
	check("minimap hidden: pop-up on screen", screen.encloses(hud.menu.get_global_rect()))
	hud.cancel_casting()
	overlay.visible = true

	# The full-screen map closes any open pop-up.
	hud._open_menu(1, 0, spells)
	await process_frame
	automap.open()
	await process_frame
	check("opening the full-screen map closes the pop-up", hud.menu == null)
	await process_frame
	check("no pop-up left open under the map", popups.open_count == 0 and popups.get_child_count() == 0)
	automap.close()

	print("DONE fails=", fails)
	quit(fails)
