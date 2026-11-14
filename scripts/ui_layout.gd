extends RefCounted
## Where everything sits on the 640x360 base screen: the classic Eye of the Beholder
## arrangement, laid out natively at 640x360 (the window scales it by whole numbers: 1280x720,
## 1920x1080, 2560x1440).
## Use via preload:  const UiLayout := preload("res://scripts/ui_layout.gd")
##
##   +--------+--------------------------------+--------+
##   | hero 1 |                                | hero 2 |
##   +--------+   3D view (VIEW), 416x260      +--------+
##   | hero 3 |                                | hero 4 |
##   +--------+-----------------------+--------+--------+
##   | hero 5 |  message log (LOG)    | arrows | hero 6 |
##   +--------+-----------------------+--------+--------+
##
## THE SIX-HERO LAYOUT (a trial, 14 Nov 2026): three hero panels down each side of the view, room for six heroes
## (PARTY_SLOTS). Positions run left to right, top to bottom, so the front row (positions 0 and 1) is the top pair,
## as it was in the old 2x2 grid on the right. The game still has four heroes: the two bottom panels are empty.
##
## TWO PIXEL SIZES. The dungeon is rendered small (VIEW_SOURCE, 208x130, the same aspect as
## the old 320x200 screen); it is now rendered at 416x260 and shown at VIEW_SCALE = 1, so 3D pixels are screen pixels. The UI is
## drawn at UI = 2 (art at twice the old size) on the native 640x360 grid, so its pixels match.
## 320x200 at 2x would not fit under a 360-pixel-tall screen, hence 208x130.
##
## KEEP IN SYNC with tools/art/gen_frame.py (LAYOUT, in 1x units, multiplied by the scale),
## which draws the stone frame with these windows cut into it. A test checks that the frame's
## transparent hole is exactly VIEW.
##
## Canvas layers, bottom to top: the 3D view (1), FRAME (4), log (Hud, 5), arrows and party
## (6), then the debug overlay, inventory, cursor and the full-screen end screens.

const SCREEN := Vector2(640, 360)
const UI := 2                           # Pixel size of the UI art, relative to the old 320x200 art.

const VIEW_SCALE := 1                   # The 3D view is rendered at the size it is shown (1x). It used to be rendered at half size and enlarged 2x.
const VIEW_SOURCE := Vector2(416, 260)  # The SubViewport's size.

const VIEW := Rect2(112, 8, 416, 260)   # Where the 3D view appears (VIEW_SOURCE * VIEW_SCALE).
const LOG := Rect2(112, 276, 296, 76)   # The message log.
const ARROWS := Rect2(416, 276, 112, 76)  # The movement arrows.
const PARTY_LEFT := Rect2(8, 8, 96, 344)    # The left column of hero panels (positions 0, 2, 4).
const PARTY_RIGHT := Rect2(536, 8, 96, 344)  # The right column (positions 1, 3, 5).
const PARTY_SLOTS := 6                  # Panels on screen: three a side.
const PANEL_SIZE := Vector2(96, 112)    # One hero panel.
const PANEL_GAP := 4                    # Between the panels of a column.


## Where the hero panel of a party position sits: even positions down the left column, odd ones down the right.
static func panel_rect(pos: int) -> Rect2:
	var well: Rect2 = PARTY_LEFT if pos % 2 == 0 else PARTY_RIGHT
	return Rect2(well.position + Vector2(0, (pos / 2) * (PANEL_SIZE.y + PANEL_GAP)), PANEL_SIZE)


## True for a position in the left column.
static func on_left(pos: int) -> bool:
	return pos % 2 == 0

const FRAME_LAYER := 4
const VIEW_LAYER := 1
const POPUP_LAYER := 16  # Every pop-up and menu (popup_layer.gd): above the minimap overlay (10), inventory (11) and held item (15), below the full-screen map (18) and pause menu (19).
