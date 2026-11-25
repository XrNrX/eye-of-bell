extends RefCounted
## The test room: a level for trying features quickly (debug builds only; excluded from release exports, see export_presets.cfg).
## Same level format as floor 1 (scripts/dungeon_map.gd documents every field). Opened with F12 or the main menu's TEST ROOM
## button (DungeonMap.use_level). Generated once from a layout script, then edited by hand: keep the stations in step with
## the systems that exist, and add a station here whenever a new system lands (CLAUDE.md says so).
##
## A long hall (row 12 to 16) with a station off it at every doorway. North: combat arena, wall types, item table, legendary
## items. South: ambush corridor, puzzle room, campfire, XP and levels, traps; through the XP room, monster pacing (a long
## corridor to back away down, opening into a room for flanking), and south of that the held-monster room (Hold Monster:
## a skeleton, a skeleton guard and a slime, which can't be held), and off the pacing corridor the light room (dark but for one lit sconce; unlit and empty
## sconces, a curse zone at the east end, torches and candles to try, and a slime that fears fire). A sign in the hall and one inside labels each.
## "NOT BUILT YET" stations are empty rooms waiting for their system.
##
## Debug keys (scripts/debug/test_room_tools.gd, H shows them in the game): G god mode, R refill HP and mana, X +500 XP,
## U level up, Z kill all monsters, V spawn a monster in front, T teleport to a station, B banter, N fog, J screen shake,
## and for monster pacing O (which value), [ and ] (lower, raise), Y (reset from the files), ; (a pack of three ahead);
## 9 holds the monster in front (no roll, no mana), 0 frees every held monster; = burns every lit light down to its last seconds.


const MAP := [
	[1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1],  # 0
	[1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 6, 1, 7, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1],  # 1
	[1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1],  # 2
	[1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1],  # 3
	[1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1],  # 4
	[1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1],  # 5
	[1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1],  # 6
	[1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1],  # 7
	[1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1],  # 8
	[1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1],  # 9
	[1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1],  # 10
	[1, 1, 1, 1, 1, 1, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 1, 1, 1, 1, 1, 1, 1, 0, 1, 1, 1],  # 11
	[1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1],  # 12
	[1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1],  # 13
	[1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1],  # 14
	[1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1],  # 15
	[1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1],  # 16
	[1, 1, 1, 0, 1, 1, 1, 1, 1, 1, 1, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 1, 1, 1, 1, 1, 1, 0, 1, 1, 1, 1, 1, 0, 1, 1, 1, 1, 1],  # 17
	[1, 1, 1, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 1, 1],  # 18
	[1, 1, 1, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 1, 1],  # 19
	[1, 1, 1, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 1, 1],  # 20
	[1, 1, 1, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 1, 1],  # 21
	[1, 1, 1, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 1, 1],  # 22
	[1, 1, 1, 0, 1, 1, 0, 1, 1, 1, 1, 2, 1, 1, 1, 1, 0, 1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 1, 1],  # 23
	[1, 1, 1, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 1, 1],  # 24
	[1, 1, 1, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 1, 1, 1, 1, 2, 1, 1, 1, 1, 1, 1],  # 25
	[1, 1, 1, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 0, 2, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1],  # 26
	[1, 1, 1, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 1, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1],  # 27
	[1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1],  # 28
	[1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1],  # 29
	[1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1],  # 30
	[1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1],  # 31
	[1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1],  # 32
	[1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1],  # 33
	[1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1],  # 34
	[1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1],  # 35
	[1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1],  # 36
	[1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1],  # 37
	[1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1],  # 38
	[1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1],  # 39
	[1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1],  # 40
]

const START_TILE := Vector2i(20, 14)
const START_FACING := 0

# Wall sconces as Vector4i(x, z, side, state): 0 lit, 1 unlit with a torch, 2 an empty bracket (see DungeonMap.TORCHES). The light room's
# are at the end: two of each dark kind and a lit one, for lighting, taking and hanging torches.
const TORCHES := [
	Vector4i(3, 12, 0, 0),
	Vector4i(9, 12, 0, 0),
	Vector4i(14, 12, 0, 0),
	Vector4i(20, 12, 0, 0),
	Vector4i(25, 12, 0, 0),
	Vector4i(31, 12, 0, 0),
	Vector4i(5, 16, 2, 0),
	Vector4i(9, 16, 2, 0),
	Vector4i(15, 16, 2, 0),
	Vector4i(20, 16, 2, 0),
	Vector4i(26, 16, 2, 0),
	Vector4i(31, 16, 2, 0),
	Vector4i(36, 16, 2, 0),
	Vector4i(1, 13, 1, 0),
	Vector4i(38, 15, 3, 0),
	Vector4i(9, 2, 0, 0),
	Vector4i(13, 3, 1, 0),
	Vector4i(21, 3, 3, 0),
	Vector4i(24, 2, 0, 0),
	Vector4i(32, 2, 0, 0),
	Vector4i(3, 20, 3, 0),
	Vector4i(3, 25, 3, 0),
	Vector4i(7, 18, 0, 0),
	Vector4i(15, 18, 0, 0),
	Vector4i(6, 25, 1, 0),
	Vector4i(16, 25, 3, 0),
	Vector4i(23, 18, 0, 0),
	Vector4i(18, 22, 1, 0),
	Vector4i(24, 22, 3, 0),
	Vector4i(30, 20, 3, 0),
	Vector4i(31, 26, 0, 0),    # The sealed pen.
	Vector4i(26, 20, 1, 0),
	Vector4i(32, 20, 1, 0),
	Vector4i(36, 20, 3, 0),
	Vector4i(8, 10, 2, 0),
	Vector4i(8, 31, 0, 0),
	Vector4i(16, 31, 2, 0),
	Vector4i(25, 29, 0, 0),
	Vector4i(31, 34, 2, 0),
	Vector4i(25, 36, 0, 0),
	Vector4i(31, 39, 2, 0),
	Vector4i(9, 33, 0, 1),    # The light room: unlit, holding a torch.
	Vector4i(6, 36, 1, 1),    # Unlit, holding a torch.
	Vector4i(15, 33, 0, 2),   # An empty bracket.
	Vector4i(19, 36, 3, 2),   # An empty bracket.
	Vector4i(9, 38, 2, 0),    # Lit (far from the zone: a wall torch within 2 tiles of its haze goes out too).
]

# The light room's curse zone: its east end (x 14-19, z 35-38), where the slime waits. Flames die in it: held torches and candles sputter and go
# out, sconces will not light, a torch dropped there fizzles; a Bless makes a 20 s pocket; the backslash key lifts it or puts it back (a puzzle effect
# does the same on a real level).
const CURSE_ZONES := [
	{"id": "light_room", "tiles": [
		Vector2i(14, 35), Vector2i(15, 35), Vector2i(16, 35), Vector2i(17, 35), Vector2i(18, 35), Vector2i(19, 35),
		Vector2i(14, 36), Vector2i(15, 36), Vector2i(16, 36), Vector2i(17, 36), Vector2i(18, 36), Vector2i(19, 36),
		Vector2i(14, 37), Vector2i(15, 37), Vector2i(16, 37), Vector2i(17, 37), Vector2i(18, 37), Vector2i(19, 37),
		Vector2i(14, 38), Vector2i(15, 38), Vector2i(16, 38), Vector2i(17, 38), Vector2i(18, 38), Vector2i(19, 38),
	]},
]

# The corrupted wall of the wall-types station: one Bless burns it away.
const CORRUPTION := {
	Vector2i(18, 1): 1,
}

# The sealed pen (T: Sealed pen): step in and both doors seal; kill what is inside and they open, and a reliquary rises.
const AREAS := [
	{"id": "pen", "rect": Rect2i(30, 26, 5, 2)},
]
# The brazier station (T: Braziers): light both and the ward on the closet door east of them breaks.
const BRAZIERS := [
	{"cell": Vector2i(15, 25), "group": "ward", "lit": false},
	{"cell": Vector2i(15, 27), "group": "ward", "lit": false},
]
const PUZZLES := [
	{"id": "brazier_ward", "when": [{"kind": "braziers", "group": "ward", "lit": true}], "then": [
		{"kind": "open_door", "id": "brazier_door"},
		{"kind": "message", "text": "The ward on the door breaks."},
	]},
	{"id": "pen_seal", "when": [{"kind": "party_in", "area": "pen"}], "then": [
		{"kind": "seal_area", "area": "pen"},
		{"kind": "set_flag", "name": "puzzle.pen.sealed"},
		{"kind": "message", "text": "The doors slam and seal."},
	]},
	{"id": "pen_purged", "when": [{"kind": "flag", "name": "puzzle.pen.sealed"}, {"kind": "monsters_dead", "area": "pen"}], "then": [
		{"kind": "unseal_area", "area": "pen"},
		{"kind": "raise_reliquary", "cell": Vector2i(31, 27), "items": [{"def": "res://data/items/healing_potion.tres", "count": 2}]},
		{"kind": "sound", "name": "rumble"},
		{"kind": "message", "text": "The seals crumble. Stone grinds up."},
	]},
]

# The traps station: one bear trap already armed, and a skeleton at the far end to lure onto it (T: Traps, then step back).
const ARMED_TRAPS := [
	{"cell": Vector2i(34, 20), "def": "res://data/items/bear_trap.tres"},
]

# The puzzle room: the plate and the lever both hold this door open.
const DOOR_IDS := {
	Vector2i(11, 23): "puzzle_door",
	Vector2i(17, 26): "brazier_door",
}

const PLATES := [
	{"cell": Vector2i(8, 20), "target": "puzzle_door"},
]

const LEVERS := [
	{"cell": Vector2i(16, 19), "side": 3, "target": "puzzle_door"},
]

const STRUCTURES := [
	{"cell": Vector2i(3, 21), "kind": "arch", "axis": "z"},  # In the ambush corridor: cast a spell past it and press P to compare shadows.
	{"cell": Vector2i(21, 21), "kind": "campfire"},  # The campfire station: fire, spit and four bedrolls (scripts/camp_site.gd).
	{"cell": Vector2i(21, 20), "kind": "camp_spot"},  # Old ash where the party rests: a camp here is rarely disturbed (7h.4 will roll for it).
]

# The item table: one of every item in data/items, in rows (the third row, y 8, takes what did not fit in two). (Add new items here when they exist.)
const ITEMS := [
	{"cell": Vector2i(24, 8), "def": "res://data/items/threadbare_robes.tres"},
	{"cell": Vector2i(24, 4), "def": "res://data/items/dagger.tres"},
	{"cell": Vector2i(25, 4), "def": "res://data/items/darts.tres"},
	{"cell": Vector2i(26, 4), "def": "res://data/items/dried_meat.tres"},
	{"cell": Vector2i(27, 4), "def": "res://data/items/hard_cheese.tres"},
	{"cell": Vector2i(28, 4), "def": "res://data/items/healing_potion.tres"},
	{"cell": Vector2i(29, 4), "def": "res://data/items/holy_symbol.tres"},
	{"cell": Vector2i(30, 4), "def": "res://data/items/key.tres"},
	{"cell": Vector2i(31, 4), "def": "res://data/items/leather_armour.tres"},
	{"cell": Vector2i(32, 4), "def": "res://data/items/mace.tres"},
	{"cell": Vector2i(24, 6), "def": "res://data/items/mouldy_bread.tres"},
	{"cell": Vector2i(25, 6), "def": "res://data/items/scroll.tres"},
	{"cell": Vector2i(26, 6), "def": "res://data/items/scroll_resurrection.tres"},
	{"cell": Vector2i(27, 6), "def": "res://data/items/short_sword.tres"},
	{"cell": Vector2i(28, 6), "def": "res://data/items/spellbook.tres"},
	{"cell": Vector2i(29, 6), "def": "res://data/items/stale_bread.tres"},
	{"cell": Vector2i(30, 6), "def": "res://data/items/war_hammer.tres"},
	{"cell": Vector2i(31, 6), "def": "res://data/items/withered_apple.tres"},
	{"cell": Vector2i(32, 6), "def": "res://data/items/long_sword.tres"},
	{"cell": Vector2i(33, 6), "def": "res://data/items/flail.tres"},
	{"cell": Vector2i(33, 4), "def": "res://data/items/slingshot.tres"},
	{"cell": Vector2i(23, 6), "def": "res://data/items/bow.tres"},
	{"cell": Vector2i(24, 5), "def": "res://data/items/raw_rat_meat.tres"},
	{"cell": Vector2i(23, 5), "def": "res://data/items/arrow.tres", "count": 20},
	{"cell": Vector2i(23, 4), "def": "res://data/items/stone.tres", "count": 20},
	{"cell": Vector2i(24, 2), "def": "res://data/items/bear_trap.tres", "count": 2},
	{"cell": Vector2i(25, 2), "def": "res://data/items/oil_flask.tres", "count": 3},
	{"cell": Vector2i(26, 2), "def": "res://data/items/mana_potion.tres", "count": 3},
	{"cell": Vector2i(33, 22), "def": "res://data/items/bear_trap.tres", "count": 2},  # The traps station.
	{"cell": Vector2i(11, 26), "def": "res://data/items/healing_potion.tres"},
	{"cell": Vector2i(19, 26), "def": "res://data/items/mana_potion.tres"},  # The warded closet.
	{"cell": Vector2i(23, 2), "def": "res://data/items/torch.tres"},
	{"cell": Vector2i(23, 3), "def": "res://data/items/candle.tres"},
	# A pile right in front of the Item table station (T), for the loot pop-up's "Take all" (right-click it).
	{"cell": Vector2i(28, 9), "def": "res://data/items/healing_potion.tres", "count": 2},
	{"cell": Vector2i(28, 9), "def": "res://data/items/stale_bread.tres", "count": 3},
	{"cell": Vector2i(28, 9), "def": "res://data/items/dagger.tres"},
	{"cell": Vector2i(35, 9), "def": "res://data/items/azure_brand.tres"},  # The Azure Brand: a real legendary (fighter or thief), to look at and use.
	{"cell": Vector2i(36, 9), "def": "res://data/debug/test_legendary.tres"},  # The legendary station: a framework test item (data/debug, debug builds only).
	{"cell": Vector2i(21, 19), "def": "res://data/items/hearth_coal.tres", "count": 3},  # Hearth Coals in the pile in front of the T teleport (with the bedrolls): use one to go to the safe campfire zone (BREAK CAMP at its fire brings the party back).
	{"cell": Vector2i(21, 19), "def": "res://data/items/bedroll.tres", "count": 3},  # The camp survival station: a bedroll right in front of the T teleport.
	{"cell": Vector2i(19, 19), "def": "res://data/items/bedroll.tres"},
	{"cell": Vector2i(22, 19), "def": "res://data/items/raw_rat_meat.tres", "count": 5},  # Camp cooking: raw food to cook on the fire (COOK, or hold it on the cursor and click the fire)...
	{"cell": Vector2i(20, 19), "def": "res://data/items/mouldy_bread.tres", "count": 3},
	{"cell": Vector2i(24, 3), "def": "res://data/items/cooked_rat_meat.tres", "count": 3},  # ...and what it becomes, on the item table.
	{"cell": Vector2i(25, 3), "def": "res://data/items/toasted_bread.tres", "count": 3},
	{"cell": Vector2i(10, 34), "def": "res://data/items/torch.tres", "count": 3},  # The light room.
	{"cell": Vector2i(14, 34), "def": "res://data/items/candle.tres", "count": 5},
	{"cell": Vector2i(12, 35), "def": "res://data/items/oil_flask.tres", "count": 3},  # Flasks of oil: throw at the floor, at the slime, or use on a weapon; light them with a torch, a swing or a Fireball.
	{"cell": Vector2i(9, 36), "def": "res://data/items/bear_trap.tres"},               # ...and a trap, for the best trick: a held monster on a slick.
]

# The combat arena. (V spawns more.)
const MONSTERS := [
	{"cell": Vector2i(4, 4), "def": "res://data/monsters/skeleton.tres"},
	{"cell": Vector2i(8, 4), "def": "res://data/monsters/slime.tres"},
	{"cell": Vector2i(5, 7), "def": "res://data/monsters/skeleton_guard.tres"},
	{"cell": Vector2i(9, 7), "def": "res://data/monsters/slime_acid.tres"},
	{"cell": Vector2i(11, 5), "def": "res://data/monsters/plague_rat.tres"},
	{"cell": Vector2i(7, 5), "def": "res://data/monsters/zombie.tres"},
	{"cell": Vector2i(9, 5), "def": "res://data/monsters/goblin.tres"},  # Fodder: weak, quick, a spear jab.
	{"cell": Vector2i(6, 8), "def": "res://data/monsters/halberdier.tres"},  # Reach: it stabs from two tiles away down a clear line.
	{"cell": Vector2i(3, 8), "def": "res://data/monsters/spider.tres"},  # Fast, a venomous bite (the food sickness, 25%).
	{"cell": Vector2i(10, 3), "def": "res://data/monsters/knight.tres"},  # The heavy one: slow, armoured (defence 5), a greatsword chop.
	{"cell": Vector2i(7, 3), "def": "res://data/monsters/red_shaman.tres"},  # A caster: a bolt from up to 4 tiles away down a clear line.
	# The held-monster room: different hold resistances (skeleton 35%, guard 45%, slime immune).
	{"cell": Vector2i(25, 39), "def": "res://data/monsters/skeleton.tres"},
	{"cell": Vector2i(28, 39), "def": "res://data/monsters/skeleton_guard.tres"},
	{"cell": Vector2i(31, 39), "def": "res://data/monsters/slime.tres"},
	{"cell": Vector2i(34, 24), "def": "res://data/monsters/skeleton.tres", "holds": true},  # The traps station: lure it onto the armed trap. (It holds its ground: left to wander it walked onto the trap by itself.)
	{"cell": Vector2i(34, 27), "def": "res://data/monsters/skeleton.tres", "holds": true},  # The sealed pen.
	{"cell": Vector2i(18, 38), "def": "res://data/monsters/slime.tres"},  # The light room: it fears fire (a torch's hit makes it recoil).
]

const SIGNS := [
	{"cell": Vector2i(1, 14), "side": 1, "text": "TEST ROOM
H = HELP
F12 = LEAVE"},
	{"cell": Vector2i(38, 14), "side": 3, "text": "T = TELEPORT
V = SPAWN"},
	{"cell": Vector2i(7, 12), "side": 0, "text": "COMBAT ARENA"},
	{"cell": Vector2i(18, 12), "side": 0, "text": "WALL TYPES"},
	{"cell": Vector2i(29, 12), "side": 0, "text": "ITEM TABLE"},
	{"cell": Vector2i(35, 12), "side": 0, "text": "LEGENDARY ITEMS
AZURE BRAND: FLAME BLADE
(FIGHTER OR THIEF)
TEST BLADE: THE HOOKS
V FOR A TARGET"},
	{"cell": Vector2i(4, 16), "side": 2, "text": "AMBUSH
CORRIDOR"},
	{"cell": Vector2i(12, 16), "side": 2, "text": "PUZZLE ROOM"},
	{"cell": Vector2i(22, 16), "side": 2, "text": "CAMP SURVIVAL
USE A BEDROLL TO CAMP
RAW FOOD NEARBY: COOK IT
, WOUNDS THE PARTY
V SPAWNS A MONSTER:
THAT REFUSES THE CAMP"},
	{"cell": Vector2i(29, 16), "side": 2, "text": "XP AND LEVELS
!NOT BUILT YET"},
	{"cell": Vector2i(35, 16), "side": 2, "text": "TRAPS
BEAR TRAP"},
	{"cell": Vector2i(4, 2), "side": 0, "text": "COMBAT ARENA
V SPAWNS MONSTERS"},
	{"cell": Vector2i(15, 2), "side": 0, "text": "< NORMAL
NOTHING HAPPENS"},
	{"cell": Vector2i(17, 2), "side": 0, "text": "< DESTRUCTIBLE
HAMMER OR FIRE"},
	{"cell": Vector2i(19, 2), "side": 0, "text": "< CORRUPTED
ONLY A BLESS"},
	{"cell": Vector2i(21, 2), "side": 0, "text": "< SECRET
!NOT BUILT YET"},
	{"cell": Vector2i(28, 2), "side": 0, "text": "ITEM TABLE
ONE OF EACH
RIGHT-CLICK: WHO TAKES IT"},
	{"cell": Vector2i(36, 2), "side": 0, "text": "!NOTHING HERE YET"},
	{"cell": Vector2i(3, 19), "side": 1, "text": "AMBUSH TILE
AHEAD"},
	{"cell": Vector2i(3, 26), "side": 1, "text": "DEAD END"},
	{"cell": Vector2i(8, 18), "side": 0, "text": "PLATE OPENS THE
DOOR. SO DOES
THE LEVER."},
	{"cell": Vector2i(9, 22), "side": 2, "text": "BRAZIERS: LIGHT
BOTH TO BREAK THE
WARD ON THE DOOR"},
	{"cell": Vector2i(11, 27), "side": 2, "text": "ALTAR
!NOT BUILT YET"},
	{"cell": Vector2i(19, 18), "side": 0, "text": "CAMPFIRE SPOT"},
	{"cell": Vector2i(21, 24), "side": 2, "text": "BEDROLLS BY THE DOOR
. CAMPS WITHOUT ONE
CLICK A BED ON THE
CAMP SCREEN: ITS PACK"},
	{"cell": Vector2i(27, 18), "side": 0, "text": "XP AND LEVELS
!NOT BUILT YET"},
	{"cell": Vector2i(33, 18), "side": 0, "text": "BEAR TRAP: SET
IT FROM A HAND.
LURE ONE ON."},
	{"cell": Vector2i(28, 27), "side": 3, "text": "SEALED PEN
STEP IN: IT SEALS
KILL TO GET OUT"},
	{"cell": Vector2i(4, 31), "side": 1, "text": "MONSTER PACING
; = PACK AHEAD
O [ ] Y = TUNE"},
	{"cell": Vector2i(26, 29), "side": 0, "text": "OPEN ROOM
FLANKING"},
	{"cell": Vector2i(22, 37), "side": 1, "text": "HELD MONSTER
9 = HOLD AHEAD
0 = FREE ALL"},
	{"cell": Vector2i(30, 24), "side": 3, "text": "PACING
SOUTH"},
	{"cell": Vector2i(13, 31), "side": 2, "text": "LIGHT AND DARK
SOUTH"},
	{"cell": Vector2i(14, 38), "side": 2, "text": "CURSE ZONE
FLAMES DIE HERE
BLESS: 20 S POCKET
\\ LIFTS IT"},
	{"cell": Vector2i(8, 33), "side": 0, "text": "LIGHT AND DARK
SCONCES: RIGHT-CLICK
LIGHTS, CLICK TAKES
OR HANGS A TORCH
= BURNS LIGHTS DOWN"},
]

# Stand-in ambush until the real system exists: stepping on the trigger tile spawns these (re-armed when the party leaves the
# corridor). Read by scripts/debug/test_room_tools.gd only.
const AMBUSHES := [
	{"trigger": Vector2i(3, 22), "text": "Ambush! Something steps out of the dark.", "monsters": [
		{"cell": Vector2i(3, 20), "def": "res://data/monsters/skeleton.tres"},
		{"cell": Vector2i(3, 24), "def": "res://data/monsters/slime.tres"},
	]},
]

const STATIONS := [
	{"name": "Hall", "cell": Vector2i(20, 14), "facing": 0},
	{"name": "Combat arena", "cell": Vector2i(6, 10), "facing": 0},
	{"name": "Wall types", "cell": Vector2i(17, 10), "facing": 0},
	{"name": "Item table", "cell": Vector2i(28, 10), "facing": 0},
	{"name": "Legendary items", "cell": Vector2i(36, 10), "facing": 0},
	{"name": "Ambush corridor", "cell": Vector2i(3, 18), "facing": 2},
	{"name": "Puzzle room", "cell": Vector2i(11, 18), "facing": 2},
	{"name": "Campfire", "cell": Vector2i(21, 18), "facing": 2},
	{"name": "XP and levels", "cell": Vector2i(28, 18), "facing": 2},
	{"name": "Traps", "cell": Vector2i(34, 18), "facing": 2},
	{"name": "Monster pacing", "cell": Vector2i(10, 31), "facing": 3},
	{"name": "Held monster", "cell": Vector2i(28, 36), "facing": 2},
	{"name": "Light and dark", "cell": Vector2i(12, 33), "facing": 2},
	{"name": "Sealed pen", "cell": Vector2i(28, 26), "facing": 3},
	{"name": "Braziers", "cell": Vector2i(13, 26), "facing": 3},
]
