extends RefCounted
## Where everything sits on the 320x200 screen: the classic Eye of the Beholder layout.
## Use via preload:  const UiLayout := preload("res://scripts/ui_layout.gd")
##
##   +--------------------------------+--------------+
##   |                                |   party      |
##   |   3D view (VIEW)               |   portraits  |
##   |                                |   (PARTY)    |
##   +---------+----------------------+              |
##   | arrows  |  message log (LOG)   |              |
##   +---------+----------------------+--------------+
##
## KEEP IN SYNC with tools/art/gen_frame.py, which draws the stone frame with these windows
## cut into it. A test checks that the frame's transparent hole is exactly VIEW.
##
## Canvas layers, bottom to top: 3D world, FRAME, log (Hud, 5), arrows and party (6), then
## the debug overlay, inventory, cursor and the full-screen end screens.

const SCREEN := Vector2(320, 200)

const VIEW := Rect2(8, 8, 176, 112)     # The 3D view.
const ARROWS := Rect2(8, 128, 56, 64)   # The movement arrows.
const LOG := Rect2(68, 128, 116, 64)    # The message log.
const PARTY := Rect2(192, 8, 120, 184)  # The party panels.

const FRAME_LAYER := 4
