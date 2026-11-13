extends RefCounted
## The test room: a level for trying features quickly (debug builds only; excluded from release exports, see export_presets.cfg).
## Same level format as floor 1 (scripts/dungeon_map.gd documents every field). Opened with F12 or the main menu's TEST ROOM
## button (DungeonMap.use_level). Generated once from a layout script, then edited by hand: keep the stations in step with
## the systems that exist, and add a station here whenever a new system lands (CLAUDE.md says so).
##
## A long hall (row 12 to 16) with a station off it at every doorway. North: combat arena, wall types, item table, legendary
## items. South: ambush corridor, puzzle room, campfire, XP and levels, traps; through the XP room, monster pacing (a long
## corridor to back away down, opening into a room for flanking), and south of that the held-monster room (Hold Monster:
## a skeleton, a skeleton guard and a slime, which can't be held). A sign in the hall and one inside labels each.
## "NOT BUILT YET" stations are empty rooms waiting for their system.
##
## Debug keys (scripts/debug/test_room_tools.gd, H shows them in the game): G god mode, R refill HP and mana, X +500 XP,
## U level up, Z kill all monsters, V spawn a monster in front, T teleport to a station, B banter, N fog, J screen shake,
## and for monster pacing O (which value), [ and ] (lower, raise), Y (reset from the files), I (a pack of three ahead);
## 9 holds the monster in front (no roll, no mana), 0 frees every held monster.


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
	[1, 1, 1, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1],  # 25
	[1, 1, 1, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1],  # 26
	[1, 1, 1, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1],  # 27
	[1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1],  # 28
	[1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1],  # 29
	[1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1],  # 30
	[1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1],  # 31
	[1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1],  # 32
	[1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1],  # 33
	[1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1],  # 34
	[1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1],  # 35
	[1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1],  # 36
	[1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1],  # 37
	[1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1],  # 38
	[1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1],  # 39
	[1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1],  # 40
]

const START_TILE := Vector2i(20, 14)
const START_FACING := 0

const TORCHES: Array[Vector3i] = [
	Vector3i(3, 12, 0),
	Vector3i(9, 12, 0),
	Vector3i(14, 12, 0),
	Vector3i(20, 12, 0),
	Vector3i(25, 12, 0),
	Vector3i(31, 12, 0),
	Vector3i(5, 16, 2),
	Vector3i(9, 16, 2),
	Vector3i(15, 16, 2),
	Vector3i(20, 16, 2),
	Vector3i(26, 16, 2),
	Vector3i(31, 16, 2),
	Vector3i(36, 16, 2),
	Vector3i(1, 13, 1),
	Vector3i(38, 15, 3),
	Vector3i(9, 2, 0),
	Vector3i(13, 3, 1),
	Vector3i(21, 3, 3),
	Vector3i(24, 2, 0),
	Vector3i(32, 2, 0),
	Vector3i(3, 20, 3),
	Vector3i(3, 25, 3),
	Vector3i(7, 18, 0),
	Vector3i(15, 18, 0),
	Vector3i(6, 25, 1),
	Vector3i(16, 25, 3),
	Vector3i(23, 18, 0),
	Vector3i(18, 22, 1),
	Vector3i(24, 22, 3),
	Vector3i(30, 20, 3),
	Vector3i(26, 20, 1),
	Vector3i(32, 20, 1),
	Vector3i(36, 20, 3),
	Vector3i(8, 10, 2),
	Vector3i(8, 31, 0),
	Vector3i(16, 31, 2),
	Vector3i(25, 29, 0),
	Vector3i(31, 34, 2),
	Vector3i(25, 36, 0),
	Vector3i(31, 39, 2),
]

# The corrupted wall of the wall-types station: one Bless burns it away.
const CORRUPTION := {
	Vector2i(18, 1): 1,
}

const PUZZLES := []

# The puzzle room: the plate and the lever both hold this door open.
const DOOR_IDS := {
	Vector2i(11, 23): "puzzle_door",
}

const PLATES := [
	{"cell": Vector2i(8, 20), "target": "puzzle_door"},
]

const LEVERS := [
	{"cell": Vector2i(16, 19), "side": 3, "target": "puzzle_door"},
]

const STRUCTURES := [
	{"cell": Vector2i(3, 21), "kind": "arch", "axis": "z"},  # In the ambush corridor: cast a spell past it and press P to compare shadows.
]

# The item table: one of every item in data/items, two rows. (Add new items here when they exist.)
const ITEMS := [
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
	{"cell": Vector2i(23, 5), "def": "res://data/items/arrow.tres", "count": 20},
	{"cell": Vector2i(23, 4), "def": "res://data/items/stone.tres", "count": 20},
	{"cell": Vector2i(11, 26), "def": "res://data/items/healing_potion.tres"},
]

# The combat arena. (V spawns more.)
const MONSTERS := [
	{"cell": Vector2i(4, 4), "def": "res://data/monsters/skeleton.tres"},
	{"cell": Vector2i(8, 4), "def": "res://data/monsters/slime.tres"},
	{"cell": Vector2i(5, 7), "def": "res://data/monsters/skeleton_guard.tres"},
	{"cell": Vector2i(9, 7), "def": "res://data/monsters/slime_acid.tres"},
	# The held-monster room: different hold resistances (skeleton 35%, guard 45%, slime immune).
	{"cell": Vector2i(25, 39), "def": "res://data/monsters/skeleton.tres"},
	{"cell": Vector2i(28, 39), "def": "res://data/monsters/skeleton_guard.tres"},
	{"cell": Vector2i(31, 39), "def": "res://data/monsters/slime.tres"},
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
	{"cell": Vector2i(35, 12), "side": 0, "text": "LEGENDARY
!NOT BUILT YET"},
	{"cell": Vector2i(4, 16), "side": 2, "text": "AMBUSH
CORRIDOR"},
	{"cell": Vector2i(12, 16), "side": 2, "text": "PUZZLE ROOM"},
	{"cell": Vector2i(22, 16), "side": 2, "text": "CAMPFIRE
!NOT BUILT YET"},
	{"cell": Vector2i(29, 16), "side": 2, "text": "XP AND LEVELS
!NOT BUILT YET"},
	{"cell": Vector2i(35, 16), "side": 2, "text": "TRAPS
!NOT BUILT YET"},
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
ONE OF EACH"},
	{"cell": Vector2i(36, 2), "side": 0, "text": "!NOTHING HERE YET"},
	{"cell": Vector2i(3, 19), "side": 1, "text": "AMBUSH TILE
AHEAD"},
	{"cell": Vector2i(3, 26), "side": 1, "text": "DEAD END"},
	{"cell": Vector2i(8, 18), "side": 0, "text": "PLATE OPENS THE
DOOR. SO DOES
THE LEVER."},
	{"cell": Vector2i(9, 22), "side": 2, "text": "BRAZIERS
!NOT BUILT YET"},
	{"cell": Vector2i(11, 27), "side": 2, "text": "ALTAR
!NOT BUILT YET"},
	{"cell": Vector2i(19, 18), "side": 0, "text": "CAMPFIRE SPOT"},
	{"cell": Vector2i(21, 24), "side": 2, "text": "FIREWOOD
!NOT BUILT YET"},
	{"cell": Vector2i(27, 18), "side": 0, "text": "XP AND LEVELS
!NOT BUILT YET"},
	{"cell": Vector2i(33, 18), "side": 0, "text": "TRAPS
!NOT BUILT YET"},
	{"cell": Vector2i(4, 31), "side": 1, "text": "MONSTER PACING
I = PACK AHEAD
O [ ] Y = TUNE"},
	{"cell": Vector2i(26, 29), "side": 0, "text": "OPEN ROOM
FLANKING"},
	{"cell": Vector2i(22, 37), "side": 1, "text": "HELD MONSTER
9 = HOLD AHEAD
0 = FREE ALL"},
	{"cell": Vector2i(30, 24), "side": 3, "text": "PACING
SOUTH"},
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
]
