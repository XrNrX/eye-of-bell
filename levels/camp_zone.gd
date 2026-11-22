extends RefCounted
## The safe campfire zone: a small walled room with a campfire and four bedrolls, no monsters, nothing to find. A Hearth Coal
## (data/items/hearth_coal.tres) takes the party here (scripts/camp_zone.gd) and BREAK CAMP in the campfire's pop-up takes them
## back to the exact tile they left. It is a level like the others (consts of floor 1's shapes) and cannot be saved.
## 9x9: the fire at (4,4), the party standing just south of it facing north (the fire is the tile in front, so a click on it opens its pop-up).

const MAP := [
	[1, 1, 1, 1, 1, 1, 1, 1, 1],
	[1, 0, 0, 0, 0, 0, 0, 0, 1],
	[1, 0, 0, 0, 0, 0, 0, 0, 1],
	[1, 0, 0, 0, 0, 0, 0, 0, 1],
	[1, 0, 0, 0, 0, 0, 0, 0, 1],
	[1, 0, 0, 0, 0, 0, 0, 0, 1],
	[1, 0, 0, 0, 0, 0, 0, 0, 1],
	[1, 0, 0, 0, 0, 0, 0, 0, 1],
	[1, 1, 1, 1, 1, 1, 1, 1, 1],
]

const START_TILE := Vector2i(4, 5)
const START_FACING := 0   # North, at the fire.

# Four lit wall sconces (x, z, side, state): the north wall's pair and one on each side wall.
const TORCHES := [
	Vector4i(2, 1, 0, 0),
	Vector4i(6, 1, 0, 0),
	Vector4i(1, 4, 1, 0),
	Vector4i(7, 4, 3, 0),
]

const CORRUPTION := {}
const PUZZLES := []
const DOOR_IDS := {}
const PLATES := []
const LEVERS := []
const STRUCTURES := [
	{"cell": Vector2i(4, 4), "kind": "campfire"},
]
const ITEMS := []
const MONSTERS := []
const SIGNS := []
const ARMED_TRAPS := []
const AMBUSHES := []
const STATIONS := []
const CURSE_ZONES := []
