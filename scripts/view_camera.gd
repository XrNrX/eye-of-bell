extends Camera3D
## The player's camera, framed so that the 3D view appears only in the VIEW window of the
## stone UI frame (see ui_layout.gd) instead of filling the screen.
##
## The scene is still rendered across the whole 320x200 viewport (the frame, which is opaque
## everywhere except the view window, covers the rest); this just centres the picture on the
## window and sets the field of view for the window, not the screen. It uses an off-axis
## ("frustum") projection, so the picture is the same as a camera that rendered only the window,
## with no distortion. Pixels stay 1:1 with the screen, so the view has the same chunky pixel
## size as a classic 176x112 view.
##
## Camera shake (combat_feel.gd) moves h_offset/v_offset, which still works with this.

const UiLayout := preload("res://scripts/ui_layout.gd")

## Vertical field of view of the VIEW window, in degrees.
@export var window_fov := 75.0


func _ready() -> void:
	frame_view()


func frame_view() -> void:
	var window := UiLayout.VIEW
	projection = PROJECTION_FRUSTUM
	keep_aspect = KEEP_HEIGHT
	# How tall the window is at the near plane for the field of view we want, then how
	# much near-plane height one screen pixel is, so the whole screen can be sized from it.
	var window_height := 2.0 * near * tan(deg_to_rad(window_fov) / 2.0)
	var per_pixel := window_height / window.size.y
	size = per_pixel * UiLayout.SCREEN.y
	var centre := window.get_center() - UiLayout.SCREEN / 2.0  # Window centre, relative to screen centre.
	# The picture moves the opposite way to the frustum, so to bring the scene's centre to the
	# window (left and above the screen centre) the frustum shifts right and down.
	frustum_offset = Vector2(-centre.x * per_pixel, centre.y * per_pixel)
