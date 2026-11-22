extends RefCounted
## Demo level 1: a plain script of consts, the same shape as levels/floor_1.gd (DungeonMap.use_level(DungeonMap.DEMO_1_PATH) loads it).
## Traced from the hand-drawn map mapBell.png (35x35) and filled in by tools/level/gen_demo_1.py (the tables in that script are the design: run it again
## after changing them; hand edits to this file are lost). Room numbers in the comments are the map's.
##
## The way through: start in the corridor (m) -> the round room (12) -> room 7 -> room 8 -> room 6 -> room 5 -> room 10 -> the LOCKED door onto the
## stairs corridor, where the Cursed Warden stands before the stairs. Keys: one in room 16 (the south-east, behind the south chain's gates), one in
## room 9 (the west maze, behind a gate) for the vault door, and a spare in vault room 1. Sixteen portcullises, each raised by a lever hanging on a
## wall near it. The Hearth Coal lies in the closet off room 7 (the door at (8,19)).

const MAP := [
	[1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1],  # 0
	[1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 1],  # 1
	[1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 1, 1, 1, 3, 1, 0, 1, 4, 1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 1, 1, 1, 1, 1, 2, 1],  # 2
	[1, 0, 0, 0, 5, 0, 1, 1, 1, 0, 1, 0, 0, 0, 1, 0, 1, 4, 1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 2, 0, 0, 0, 0, 0, 1],  # 3
	[1, 0, 0, 0, 1, 0, 1, 1, 1, 0, 1, 0, 0, 0, 1, 0, 1, 1, 1, 1, 1, 2, 1, 1, 1, 1, 1, 0, 1, 0, 0, 0, 0, 0, 1],  # 4
	[1, 0, 0, 0, 1, 0, 1, 1, 1, 0, 1, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1],  # 5
	[1, 1, 1, 1, 1, 0, 1, 1, 1, 2, 1, 2, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 5, 1, 1, 1, 1, 1],  # 6
	[1, 0, 1, 0, 0, 0, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1],  # 7
	[1, 0, 1, 0, 1, 2, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1],  # 8
	[1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1],  # 9
	[1, 0, 1, 1, 1, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1],  # 10
	[1, 0, 1, 0, 5, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 1],  # 11
	[1, 5, 1, 2, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 2, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 1, 0, 1],  # 12
	[1, 0, 0, 0, 0, 0, 2, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 1],  # 13
	[1, 0, 0, 0, 0, 0, 1, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 1],  # 14
	[1, 0, 0, 0, 0, 0, 1, 0, 5, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 1],  # 15
	[1, 0, 0, 0, 0, 0, 1, 1, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 1],  # 16
	[1, 0, 0, 0, 0, 0, 1, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 1],  # 17
	[1, 0, 0, 0, 0, 0, 1, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 2, 1, 1, 1, 1, 1, 2, 1, 1, 1, 2, 1, 1, 1, 0, 1],  # 18
	[1, 0, 0, 0, 0, 0, 1, 0, 2, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 1],  # 19
	[1, 2, 1, 1, 1, 2, 1, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 1],  # 20
	[1, 0, 1, 1, 1, 0, 1, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 1, 0, 1],  # 21
	[1, 0, 1, 1, 1, 2, 1, 1, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 1],  # 22
	[1, 0, 1, 1, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 1],  # 23
	[1, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 1, 1, 3, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 1, 0, 1],  # 24
	[1, 0, 2, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 1],  # 25
	[1, 1, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 1],  # 26
	[1, 1, 1, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 1],  # 27
	[1, 1, 1, 5, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 1],  # 28
	[1, 1, 1, 0, 1, 1, 1, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 1],  # 29
	[1, 0, 0, 0, 0, 0, 1, 0, 1, 5, 1, 1, 1, 1, 1, 1, 1, 1, 1, 5, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 1],  # 30
	[1, 0, 0, 0, 0, 0, 2, 0, 1, 0, 0, 0, 5, 0, 0, 0, 1, 0, 0, 0, 1, 1, 1, 1, 1, 0, 2, 0, 0, 0, 2, 0, 0, 0, 1],  # 31
	[1, 0, 0, 0, 0, 0, 1, 0, 1, 0, 0, 0, 1, 1, 1, 0, 1, 0, 0, 0, 1, 1, 1, 1, 1, 0, 1, 0, 0, 0, 1, 1, 1, 0, 1],  # 32
	[1, 1, 1, 0, 1, 1, 1, 0, 5, 0, 0, 0, 1, 0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 1, 0, 0, 0, 5, 0, 0, 0, 1],  # 33
	[1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1],  # 34
]

const START_TILE := Vector2i(1, 25)
const START_FACING := 3

# Wall sconces as Vector4i(x, z, side, state): 0 lit, 1 unlit with a torch, 2 an empty bracket (DungeonMap.SCONCE_*).
const TORCHES := [
	Vector4i(1, 23, 1, 0),
	Vector4i(6, 23, 0, 0),
	Vector4i(4, 27, 2, 0),
	Vector4i(5, 19, 3, 0),
	Vector4i(1, 16, 1, 1),
	Vector4i(4, 7, 0, 0),
	Vector4i(5, 3, 3, 1),
	Vector4i(7, 11, 3, 2),
	Vector4i(1, 3, 0, 2),
	Vector4i(1, 32, 2, 0),
	Vector4i(5, 32, 2, 1),
	Vector4i(18, 25, 0, 0),
	Vector4i(18, 29, 2, 1),
	Vector4i(9, 19, 0, 1),
	Vector4i(14, 29, 2, 2),
	Vector4i(10, 33, 2, 2),
	Vector4i(18, 33, 2, 2),
	Vector4i(27, 32, 1, 0),
	Vector4i(31, 31, 0, 0),
	Vector4i(33, 19, 3, 1),
	Vector4i(33, 14, 3, 2),
	Vector4i(27, 24, 1, 0),
	Vector4i(27, 19, 0, 1),
	Vector4i(22, 29, 2, 2),
	Vector4i(31, 27, 3, 2),
	Vector4i(23, 7, 0, 0),
	Vector4i(27, 15, 1, 1),
	Vector4i(31, 9, 3, 2),
	Vector4i(22, 11, 2, 2),
	Vector4i(10, 7, 0, 0),
	Vector4i(13, 17, 2, 1),
	Vector4i(14, 11, 2, 1),
	Vector4i(19, 7, 0, 2),
	Vector4i(11, 3, 1, 0),
	Vector4i(19, 17, 3, 2),
	Vector4i(23, 17, 2, 2),
	Vector4i(15, 21, 1, 0),
	Vector4i(19, 21, 3, 1),
	Vector4i(23, 23, 2, 2),
	Vector4i(19, 3, 1, 0),
	Vector4i(23, 3, 2, 2),
	Vector4i(33, 4, 3, 0),
	Vector4i(29, 3, 0, 1),
	Vector4i(15, 4, 1, 0),
]

const CORRUPTION := {}
const PUZZLES := []

# The portcullises: each is raised by the lever(s) linked to it.
const DOOR_IDS := {
	Vector2i(4, 3): "gate_4_3",
	Vector2i(29, 6): "gate_29_6",
	Vector2i(4, 11): "gate_4_11",
	Vector2i(32, 11): "gate_32_11",
	Vector2i(1, 12): "gate_1_12",
	Vector2i(8, 15): "gate_8_15",
	Vector2i(14, 15): "gate_14_15",
	Vector2i(26, 21): "gate_26_21",
	Vector2i(3, 28): "gate_3_28",
	Vector2i(9, 30): "gate_9_30",
	Vector2i(19, 30): "gate_19_30",
	Vector2i(12, 31): "gate_12_31",
	Vector2i(8, 33): "gate_8_33",
	Vector2i(16, 33): "gate_16_33",
	Vector2i(20, 33): "gate_20_33",
	Vector2i(30, 33): "gate_30_33",
}

const PLATES := []

const LEVERS := [
	{"cell": Vector2i(5, 3), "side": 0, "target": "gate_4_3"},
	{"cell": Vector2i(28, 7), "side": 0, "target": "gate_29_6"},
	{"cell": Vector2i(5, 11), "side": 2, "target": "gate_4_11"},
	{"cell": Vector2i(31, 10), "side": 3, "target": "gate_32_11"},
	{"cell": Vector2i(1, 13), "side": 1, "target": "gate_1_12"},
	{"cell": Vector2i(9, 14), "side": 1, "target": "gate_8_15"},
	{"cell": Vector2i(13, 14), "side": 3, "target": "gate_14_15"},
	{"cell": Vector2i(27, 20), "side": 1, "target": "gate_26_21"},
	{"cell": Vector2i(3, 27), "side": 1, "target": "gate_3_28"},
	{"cell": Vector2i(9, 29), "side": 1, "target": "gate_9_30"},
	{"cell": Vector2i(18, 29), "side": 2, "target": "gate_19_30"},
	{"cell": Vector2i(11, 31), "side": 0, "target": "gate_12_31"},
	{"cell": Vector2i(9, 33), "side": 2, "target": "gate_8_33"},
	{"cell": Vector2i(17, 33), "side": 2, "target": "gate_16_33"},
	{"cell": Vector2i(19, 33), "side": 2, "target": "gate_20_33"},
	{"cell": Vector2i(29, 33), "side": 2, "target": "gate_30_33"},
]

const STRUCTURES := [
	{"cell": Vector2i(5, 25), "kind": "campfire"},  # A camp in the round room (12): fire, spit and four bedrolls; click it to rest or cook.
	{"cell": Vector2i(5, 24), "kind": "camp_spot"},  # Old ash where the party rests.
]

# Items by room (the comment names the room). A key's "opens" is the locked door it is meant for (the dungeon editor's link; the game ignores it).
const ITEMS := [
	{"cell": Vector2i(1, 22), "def": "res://data/items/torch.tres"},  # m
	{"cell": Vector2i(1, 24), "def": "res://data/items/healing_potion.tres"},  # m
	{"cell": Vector2i(7, 25), "def": "res://data/items/bedroll.tres"},  # 12
	{"cell": Vector2i(4, 27), "def": "res://data/items/dried_meat.tres"},  # 12
	{"cell": Vector2i(2, 14), "def": "res://data/items/short_sword.tres"},  # 11
	{"cell": Vector2i(2, 14), "def": "res://data/items/healing_potion.tres"},  # 11
	{"cell": Vector2i(4, 14), "def": "res://data/items/darts.tres", "count": 4},  # 11
	{"cell": Vector2i(5, 13), "def": "res://data/items/stale_bread.tres", "count": 2},  # 11
	{"cell": Vector2i(7, 13), "def": "res://data/items/healing_potion.tres"},  # i
	{"cell": Vector2i(7, 20), "def": "res://data/items/hearth_coal.tres"},  # r17
	{"cell": Vector2i(7, 19), "def": "res://data/items/candle.tres", "count": 2},  # r17
	{"cell": Vector2i(5, 3), "def": "res://data/items/stone.tres", "count": 8},  # r5
	{"cell": Vector2i(1, 9), "def": "res://data/items/healing_potion.tres"},  # r5
	{"cell": Vector2i(7, 9), "def": "res://data/items/leather_armour.tres"},  # 13
	{"cell": Vector2i(7, 11), "def": "res://data/items/mana_potion.tres"},  # 13
	{"cell": Vector2i(7, 9), "def": "res://data/items/stone.tres", "count": 6},  # 13
	{"cell": Vector2i(1, 5), "def": "res://data/items/key.tres", "opens": Vector2i(17, 24)},  # 9
	{"cell": Vector2i(3, 3), "def": "res://data/items/scroll.tres"},  # 9
	{"cell": Vector2i(3, 4), "def": "res://data/items/healing_potion.tres", "count": 2},  # 9
	{"cell": Vector2i(3, 33), "def": "res://data/items/long_sword.tres"},  # 17
	{"cell": Vector2i(3, 31), "def": "res://data/items/healing_potion.tres"},  # 17
	{"cell": Vector2i(3, 30), "def": "res://data/items/oil_flask.tres", "count": 2},  # 17
	{"cell": Vector2i(7, 33), "def": "res://data/items/dried_meat.tres"},  # n
	{"cell": Vector2i(11, 20), "def": "res://data/items/healing_potion.tres", "count": 2},  # 7
	{"cell": Vector2i(11, 26), "def": "res://data/items/arrow.tres", "count": 8},  # 7
	{"cell": Vector2i(18, 29), "def": "res://data/items/torch.tres"},  # 7
	{"cell": Vector2i(17, 29), "def": "res://data/items/hard_cheese.tres"},  # 7
	{"cell": Vector2i(10, 22), "def": "res://data/items/dagger.tres"},  # 7
	{"cell": Vector2i(16, 29), "def": "res://data/items/scroll.tres"},  # 7
	{"cell": Vector2i(10, 32), "def": "res://data/items/bow.tres"},  # 15
	{"cell": Vector2i(11, 33), "def": "res://data/items/healing_potion.tres"},  # 15
	{"cell": Vector2i(13, 31), "def": "res://data/items/mouldy_bread.tres", "count": 2},  # r28
	{"cell": Vector2i(14, 33), "def": "res://data/items/arrow.tres", "count": 6},  # r28
	{"cell": Vector2i(18, 33), "def": "res://data/items/mace.tres"},  # 14
	{"cell": Vector2i(17, 32), "def": "res://data/items/healing_potion.tres"},  # 14
	{"cell": Vector2i(18, 33), "def": "res://data/items/bear_trap.tres"},  # 14
	{"cell": Vector2i(22, 33), "def": "res://data/items/dried_meat.tres"},  # r30
	{"cell": Vector2i(21, 33), "def": "res://data/items/mana_potion.tres"},  # r30
	{"cell": Vector2i(29, 33), "def": "res://data/items/key.tres", "opens": Vector2i(13, 2)},  # 16
	{"cell": Vector2i(29, 33), "def": "res://data/items/healing_potion.tres", "count": 2},  # 16
	{"cell": Vector2i(27, 32), "def": "res://data/items/scroll.tres"},  # 16
	{"cell": Vector2i(33, 20), "def": "res://data/items/healing_potion.tres"},  # r12
	{"cell": Vector2i(33, 19), "def": "res://data/items/withered_apple.tres"},  # r12
	{"cell": Vector2i(33, 19), "def": "res://data/items/stone.tres", "count": 8},  # r12
	{"cell": Vector2i(30, 20), "def": "res://data/items/healing_potion.tres", "count": 2},  # 8
	{"cell": Vector2i(27, 23), "def": "res://data/items/arrow.tres", "count": 6},  # 8
	{"cell": Vector2i(26, 26), "def": "res://data/items/flail.tres"},  # 8
	{"cell": Vector2i(27, 24), "def": "res://data/items/mana_potion.tres"},  # 8
	{"cell": Vector2i(22, 26), "def": "res://data/items/hard_cheese.tres"},  # 8
	{"cell": Vector2i(28, 14), "def": "res://data/items/healing_potion.tres", "count": 4},  # 6
	{"cell": Vector2i(29, 11), "def": "res://data/items/war_hammer.tres"},  # 6
	{"cell": Vector2i(29, 9), "def": "res://data/items/scroll.tres"},  # 6
	{"cell": Vector2i(24, 7), "def": "res://data/items/bedroll.tres"},  # 6
	{"cell": Vector2i(30, 7), "def": "res://data/items/darts.tres", "count": 4},  # 6
	{"cell": Vector2i(11, 14), "def": "res://data/items/healing_potion.tres", "count": 4},  # 5
	{"cell": Vector2i(10, 14), "def": "res://data/items/slingshot.tres"},  # 5
	{"cell": Vector2i(17, 7), "def": "res://data/items/dried_meat.tres"},  # 5
	{"cell": Vector2i(15, 8), "def": "res://data/items/oil_flask.tres"},  # 5
	{"cell": Vector2i(14, 11), "def": "res://data/items/torch.tres"},  # 5
	{"cell": Vector2i(10, 17), "def": "res://data/items/leather_armour.tres"},  # 5
	{"cell": Vector2i(12, 3), "def": "res://data/items/healing_potion.tres"},  # 10
	{"cell": Vector2i(13, 3), "def": "res://data/items/mana_potion.tres"},  # 10
	{"cell": Vector2i(2, 1), "def": "res://data/items/scroll_resurrection.tres"},  # e
	{"cell": Vector2i(16, 14), "def": "res://data/items/healing_potion.tres", "count": 2},  # 1
	{"cell": Vector2i(16, 13), "def": "res://data/items/key.tres", "opens": Vector2i(13, 2)},  # 1
	{"cell": Vector2i(16, 16), "def": "res://data/items/bear_trap.tres"},  # 1
	{"cell": Vector2i(25, 15), "def": "res://data/items/healing_potion.tres", "count": 2},  # 2
	{"cell": Vector2i(21, 17), "def": "res://data/items/mana_potion.tres"},  # 2
	{"cell": Vector2i(23, 15), "def": "res://data/items/threadbare_robes.tres"},  # 2
	{"cell": Vector2i(17, 20), "def": "res://data/items/scroll_resurrection.tres"},  # 3
	{"cell": Vector2i(15, 23), "def": "res://data/items/healing_potion.tres", "count": 3},  # 3
	{"cell": Vector2i(19, 21), "def": "res://data/items/holy_symbol.tres"},  # 3
	{"cell": Vector2i(15, 20), "def": "res://data/items/spellbook.tres"},  # 3
	{"cell": Vector2i(25, 23), "def": "res://data/items/healing_potion.tres", "count": 2},  # 4
	{"cell": Vector2i(25, 21), "def": "res://data/items/scroll.tres", "count": 2},  # 4
	{"cell": Vector2i(23, 23), "def": "res://data/items/dagger.tres"},  # 4
	{"cell": Vector2i(21, 20), "def": "res://data/items/candle.tres"},  # 4
	{"cell": Vector2i(23, 3), "def": "res://data/items/healing_potion.tres", "count": 2},  # 19
	{"cell": Vector2i(20, 2), "def": "res://data/items/mana_potion.tres"},  # 19
	{"cell": Vector2i(19, 1), "def": "res://data/items/scroll.tres"},  # 19
	{"cell": Vector2i(31, 3), "def": "res://data/items/healing_potion.tres", "count": 2},  # 18
	{"cell": Vector2i(29, 3), "def": "res://data/items/dried_meat.tres", "count": 2},  # 18
	{"cell": Vector2i(29, 4), "def": "res://data/items/arrow.tres", "count": 6},  # 18
	{"cell": Vector2i(26, 5), "def": "res://data/items/healing_potion.tres"},  # a+c
	{"cell": Vector2i(13, 1), "def": "res://data/items/torch.tres"},  # a+c
]

# Monsters by room, weak near the start and tougher toward the stairs, the Cursed Warden last.
const MONSTERS := [
	{"cell": Vector2i(1, 16), "def": "res://data/monsters/slime.tres"},  # 11
	{"cell": Vector2i(5, 18), "def": "res://data/monsters/skeleton.tres"},  # 11
	{"cell": Vector2i(4, 7), "def": "res://data/monsters/plague_rat.tres"},  # r5
	{"cell": Vector2i(3, 9), "def": "res://data/monsters/plague_rat.tres"},  # r5
	{"cell": Vector2i(6, 11), "def": "res://data/monsters/goblin.tres"},  # 13
	{"cell": Vector2i(6, 9), "def": "res://data/monsters/skeleton.tres"},  # 13
	{"cell": Vector2i(2, 4), "def": "res://data/monsters/skeleton_guard.tres"},  # 9
	{"cell": Vector2i(4, 30), "def": "res://data/monsters/slime_acid.tres"},  # 17
	{"cell": Vector2i(1, 32), "def": "res://data/monsters/slime_acid.tres"},  # 17
	{"cell": Vector2i(7, 29), "def": "res://data/monsters/plague_rat.tres"},  # n
	{"cell": Vector2i(12, 28), "def": "res://data/monsters/goblin.tres"},  # 7
	{"cell": Vector2i(16, 27), "def": "res://data/monsters/skeleton.tres"},  # 7
	{"cell": Vector2i(13, 21), "def": "res://data/monsters/skeleton.tres"},  # 7
	{"cell": Vector2i(10, 21), "def": "res://data/monsters/slime_acid.tres"},  # 7
	{"cell": Vector2i(10, 31), "def": "res://data/monsters/skeleton.tres"},  # 15
	{"cell": Vector2i(13, 33), "def": "res://data/monsters/plague_rat.tres"},  # r28
	{"cell": Vector2i(14, 31), "def": "res://data/monsters/plague_rat.tres"},  # r28
	{"cell": Vector2i(18, 32), "def": "res://data/monsters/zombie.tres"},  # 14
	{"cell": Vector2i(25, 32), "def": "res://data/monsters/goblin.tres"},  # r30
	{"cell": Vector2i(28, 31), "def": "res://data/monsters/skeleton_guard.tres"},  # 16
	{"cell": Vector2i(27, 33), "def": "res://data/monsters/red_shaman.tres"},  # 16
	{"cell": Vector2i(33, 14), "def": "res://data/monsters/spider.tres"},  # r12
	{"cell": Vector2i(33, 32), "def": "res://data/monsters/plague_rat.tres"},  # r12
	{"cell": Vector2i(33, 23), "def": "res://data/monsters/plague_rat.tres"},  # r12
	{"cell": Vector2i(23, 25), "def": "res://data/monsters/goblin.tres"},  # 8
	{"cell": Vector2i(24, 28), "def": "res://data/monsters/skeleton.tres"},  # 8
	{"cell": Vector2i(29, 28), "def": "res://data/monsters/spider.tres"},  # 8
	{"cell": Vector2i(29, 20), "def": "res://data/monsters/halberdier.tres"},  # 8
	{"cell": Vector2i(29, 8), "def": "res://data/monsters/skeleton_guard.tres"},  # 6
	{"cell": Vector2i(26, 8), "def": "res://data/monsters/halberdier.tres"},  # 6
	{"cell": Vector2i(31, 17), "def": "res://data/monsters/red_shaman.tres"},  # 6
	{"cell": Vector2i(21, 10), "def": "res://data/monsters/knight.tres"},  # 6
	{"cell": Vector2i(12, 9), "def": "res://data/monsters/zombie.tres"},  # 5
	{"cell": Vector2i(17, 10), "def": "res://data/monsters/skeleton_guard.tres"},  # 5
	{"cell": Vector2i(12, 17), "def": "res://data/monsters/knight.tres"},  # 5
	{"cell": Vector2i(9, 9), "def": "res://data/monsters/goblin.tres"},  # 5
	{"cell": Vector2i(16, 7), "def": "res://data/monsters/skeleton.tres"},  # 5
	{"cell": Vector2i(12, 5), "def": "res://data/monsters/skeleton_guard.tres"},  # 10
	{"cell": Vector2i(18, 14), "def": "res://data/monsters/knight.tres"},  # 1
	{"cell": Vector2i(24, 13), "def": "res://data/monsters/slime_acid.tres"},  # 2
	{"cell": Vector2i(22, 17), "def": "res://data/monsters/slime_acid.tres"},  # 2
	{"cell": Vector2i(17, 22), "def": "res://data/monsters/skeleton.tres"},  # 3
	{"cell": Vector2i(15, 19), "def": "res://data/monsters/skeleton.tres"},  # 3
	{"cell": Vector2i(24, 23), "def": "res://data/monsters/halberdier.tres"},  # 4
	{"cell": Vector2i(22, 19), "def": "res://data/monsters/zombie.tres"},  # 4
	{"cell": Vector2i(21, 2), "def": "res://data/monsters/skeleton_guard.tres"},  # 19
	{"cell": Vector2i(24, 1), "def": "res://data/monsters/red_shaman.tres"},  # 19
	{"cell": Vector2i(30, 3), "def": "res://data/monsters/knight.tres"},  # 18
	{"cell": Vector2i(33, 4), "def": "res://data/monsters/halberdier.tres"},  # 18
	{"cell": Vector2i(16, 1), "def": "res://data/monsters/warden.tres"},  # a+c
]

const SIGNS := []
const ARMED_TRAPS := []
const AMBUSHES := []
const STATIONS := []
const CURSE_ZONES := []
const MENU_VIEW_CELL := Vector2i(1, 25)
