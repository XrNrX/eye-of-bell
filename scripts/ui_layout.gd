extends RefCounted
## Where everything sits on the 640x360 base screen: the classic Eye of the Beholder
## arrangement, laid out natively at 640x360 (the window scales it by whole numbers: 1280x720,
## 1920x1080, 2560x1440).
## Use via preload:  const UiLayout := preload("res://scripts/ui_layout.gd")
##
##   +--------------------------------+--------------+
##   |                                |   party      |
##   |   3D view (VIEW), a 208x130    |   portraits  |
##   |   SubViewport shown at 2x      |   (PARTY)    |
##   +-----------------------+--------+              |
##   |  message log (LOG)    | arrows |              |
##   +-----------------------+--------+--------------+
##
## TWO PIXEL SIZES. The dungeon is rendered small (VIEW_SOURCE, 208x130, the same aspect as
## the old 320x200 screen) and shown at VIEW_SCALE = 2, so its pixels are chunky. The UI is
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

const VIEW_SCALE := 2                   # The 3D view is rendered small and shown this many times larger.
const VIEW_SOURCE := Vector2(208, 130)  # The SubViewport's size.

const VIEW := Rect2(8, 8, 416, 260)     # Where the 3D view appears (VIEW_SOURCE * VIEW_SCALE).
const LOG := Rect2(8, 276, 296, 76)     # The message log.
const ARROWS := Rect2(312, 276, 112, 76)  # The movement arrows.
const PARTY := Rect2(432, 8, 200, 344)  # The party panels.

const FRAME_LAYER := 4
const VIEW_LAYER := 1
