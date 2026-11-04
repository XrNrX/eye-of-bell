extends ColorRect
## The inventory screen's backdrop: everything outside the inventory window.
## Clicking it while holding an item puts the item on the floor tile in front of the
## party, Eye-of-the-Beholder style. A click inside the window but between slots is
## caught by the window panel instead, so a near-miss never throws an item away.

var screen: Node  # InventoryScreen.


func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	accept_event()
	var cursor = screen.cursor
	if not cursor.is_holding():
		return
	if not screen.can_drop_on_floor():
		screen.say("There's no room to put it down there.")
		return
	screen.drop_on_floor(cursor.release())
