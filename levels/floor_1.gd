extends RefCounted
## Floor 1's level data: a plain script of consts, nothing else (the same shape as levels/test_room.gd). DungeonMap.use_level("")
## loads this file, DungeonMap.use_level_data(dict) takes the same fields from any dictionary (a generated level, later), and
## the fields below are what a level is. A level file leaves out any field it does not need (it becomes empty).
## (This used to live inside scripts/dungeon_map.gd; the formats of every field are documented here, with the data.)
##
## Edit MAP below like a text file:
## 1 = wall, 0 = floor, 2 = door (starts closed), 3 = locked door (needs a key),
## 4 = stairs down (stepping on any of them completes the level),
## 5 = portcullis (an iron grate: a door you can see through, never opened by hand; give it
## an ID in DOOR_IDS and only its linked lever or plate raises it),
## 6 = cracked wall (looks like a wall with an obvious crack; solid until a Fireball or a heavy
## weapon like the war hammer breaks it, after which it is walkable floor with rubble),
## 7 = corrupted wall (overgrown with the curse: pulsing green veins; weapons and Fireball just bounce off, only a Bless from a
## cleric purifies it, after which it is floor; CORRUPTION below says how many Blesses each one takes).
## Row index is Z (north at top), column index is X.
## TORCHES entries are Vector4i(x, z, side, state): state 0 lit, 1 unlit with a torch, 2 an empty bracket (DungeonMap.SCONCE_*).

## The level is traced from a hand-drawn map (the 23x23 grid of map.png, shifted two rows down and one
## column right so there is a wall border and room for two closets north of room 7). Where the map
## drew a feature the game has no tile for, it became: archway = open floor, portcullis = a door
## driven by a lever or plate (DOOR_IDS), up stairs = the landing the player starts on.
## Numbers in the comments are the room numbers on that map.
const MAP := [
	[1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1],  # 0
	[1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 1, 0, 1],  # 1
	[1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 2, 1, 3, 1],  # 2
	[1, 1, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 1, 0, 0, 0, 1],  # 3
	[1, 1, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 7, 1, 0, 0, 0, 1],  # 4
	[1, 1, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 2, 0, 0, 0, 1],  # 5
	[1, 1, 6, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 2, 1, 1, 1, 5, 1],  # 6
	[1, 1, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 1],  # 7
	[1, 1, 1, 1, 1, 1, 0, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 1],  # 8
	[1, 1, 1, 1, 0, 0, 0, 7, 0, 0, 0, 1, 0, 0, 0, 0, 0, 2, 0, 0, 0, 1],  # 9
	[1, 1, 1, 1, 1, 1, 0, 1, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 2, 1, 1, 1],  # 10
	[1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 1, 1, 1],  # 11
	[1, 1, 1, 1, 1, 1, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 1, 1, 1],  # 12
	[1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 0, 1, 1, 1],  # 13
	[1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 1, 1, 1, 1, 1, 0, 1, 1, 1],  # 14
	[1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1],  # 15
	[1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 0, 1, 1, 1],  # 16
	[1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 0, 0, 0, 1],  # 17
	[1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 1, 1, 0, 0, 0, 1, 1, 1, 1, 1, 3, 1],  # 18
	[1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 1],  # 19
	[1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 1, 0, 1],  # 20
	[1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 5, 0, 1],  # 21
	[1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 1],  # 22
	[1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 4, 4, 0, 1],  # 23
	[1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1],  # 24
]

const START_TILE := Vector2i(5, 9)  # (x, z) grid cell the player spawns in (the up-stairs landing).
const START_FACING := 3             # 0 = north (-Z), 1 = west, 2 = south, 3 = east.



const TORCHES := [
	Vector4i(3, 7, 0, 0),  # lit
	Vector4i(5, 9, 2, 0),  # lit
	Vector4i(6, 11, 1, 0),  # lit
	Vector4i(6, 12, 3, 0),  # lit
	Vector4i(9, 13, 2, 0),  # lit
	Vector4i(12, 14, 1, 1),  # unlit, holds a torch
	Vector4i(14, 15, 0, 1),  # unlit, holds a torch
	Vector4i(17, 15, 2, 1),  # unlit, holds a torch
	Vector4i(18, 13, 3, 1),  # unlit, holds a torch
	Vector4i(18, 16, 1, 1),  # unlit, holds a torch
	Vector4i(20, 19, 3, 0),  # lit
	Vector4i(20, 22, 3, 0),  # lit
	Vector4i(9, 9, 0, 0),  # lit
	Vector4i(14, 7, 0, 1),  # unlit, holds a torch
	Vector4i(12, 9, 1, 2),  # empty bracket
	Vector4i(14, 11, 2, 2),  # empty bracket
	Vector4i(16, 5, 1, 2),  # empty bracket
	Vector4i(19, 3, 0, 2),  # empty bracket
	Vector4i(19, 9, 2, 1),  # unlit, holds a torch
	Vector4i(13, 17, 0, 2),  # empty bracket
	Vector4i(17, 21, 2, 2),  # empty bracket
	Vector4i(8, 15, 0, 2),  # empty bracket
	Vector4i(9, 18, 3, 2),  # empty bracket
	Vector4i(18, 1, 0, 2),  # empty bracket
	Vector4i(20, 1, 0, 2),  # empty bracket
]

# Corrupted walls (tile 7): how many Blesses each takes to burn away (1 = thin, 2 = thick). Every tile 7 in MAP needs an entry.
const CORRUPTION := {
	Vector2i(7, 9): 1,   # Right in front of the fighter at the start: the first thing anyone tries to smash. Opens the way into room 5.
	Vector2i(16, 4): 2,  # North of the nook above room 3 (a dead end that begs to be smashed): a closet of loot behind it.
}

# --- Puzzles ---
# A puzzle is data: when every condition in "when" holds, its "then" effects run, once (scripts/puzzles.gd).
#   conditions: {"kind": "wall_purified", "cell": Vector2i}   a corrupted wall has been burned away
#               {"kind": "lever_on", "cell": Vector2i, "side": int}   a wall lever is switched on
#               {"kind": "monsters_dead", "def": String (optional), "area": Rect2i (optional)}   every monster of that kind (and/or standing
#                                                    in that area) the level placed is dead; needs at least one placed, so an empty level never fires it
#               {"kind": "flag", "name": String, "value": true}   a run flag has this value (memory: see below)
#               {"kind": "lever_order", "levers": [{"cell": Vector2i, "side": int}, ...]}   those levers pulled one after another
#   Puzzles listen to the event bus and are re-checked on ANY event (scripts/puzzles.gd), so a condition needs no call site.
#   A condition that needs memory keeps it in the run flags (DungeonMap.flags, saved), "puzzle.<id>.<what>": lever_order keeps
#   its progress in "puzzle.<id>.step".
#   effects:    {"kind": "message", "text": String}           a line in the log
#               {"kind": "open_door", "id": String}           a DOOR_IDS door stays open for good (as if a switch held it)
#               {"kind": "break_wall", "cell": Vector2i}      a cracked wall breaks
#               {"kind": "purify_wall", "cell": Vector2i}     a corrupted wall is purified (a lever or plate can do it)
#               {"kind": "set_flag", "name": String, "value": true}   set a run flag (another puzzle can wait on it)
#               {"kind": "clear_curse_zone", "id": String}    a curse zone is lifted for good (CURSE_ZONES; the flag "curse_zone.<id>.cleared")
const PUZZLES := [
	{"id": "nook_blessing", "when": [{"kind": "wall_purified", "cell": Vector2i(16, 4)}], "then": [
		{"kind": "message", "text": "The curse bleeds out of the stone. Somewhere in the dark, a latch gives way."},
		{"kind": "open_door", "id": "gate_n"},
	]},
	{"id": "cave_cleansed", "when": [{"kind": "monsters_dead", "def": "res://data/monsters/plague_rat.tres"}], "then": [
		{"kind": "message", "text": "The air in the cave loosens. Fire would live there now."},
		{"kind": "clear_curse_zone", "id": "cave"},
	]},
]

# --- Switches and linked doors ---
# Give a door an ID here and it is controlled only by switches that name that ID
# as their "target" (F does nothing on it). A door is open while ANY of its
# switches is active: a lever that is switched on, or a plate someone stands on.
const DOOR_IDS := {
	Vector2i(20, 6): "gate_n",
	Vector2i(19, 21): "gate_s",
}

# Pressure plates: open their target door while the player stands on "cell".
const PLATES := [
	{"cell": Vector2i(18, 21), "target": "gate_s"},
]

# Hand-placed scenery (see wall_decor.gd): {"cell": the floor tile, "kind": "arch" | "pillar" | "alcove", "side": 0 north,
# 1 west, 2 south, 3 east (for a pillar or alcove: which wall of the tile it is on), "axis": "x" | "z" (arch only; the
# direction the corridor runs, found from the walls if left out)}. Nothing here blocks movement. Long corridors also
# get arches by rule (data/wall_decor.tres), so list only the spots you want to be sure of.
const STRUCTURES := [
	{"cell": Vector2i(8, 13), "kind": "alcove", "side": 0},  # Beside the long first corridor: the first thing a player sees.
]

# Wall levers: "cell" is the floor tile you stand on, "side" the wall it hangs on
# (0 = north, 1 = west, 2 = south, 3 = east). Face that wall and press F to toggle.
const LEVERS := [
	{"cell": Vector2i(19, 7), "side": 0, "target": "gate_n"},
	{"cell": Vector2i(20, 5), "side": 3, "target": "gate_n"},
	{"cell": Vector2i(20, 20), "side": 3, "target": "gate_s"},
]

# Items lying on the floor at the start: the cell and an ItemDef resource (see
# scripts/item_def.gd). dungeon_builder.gd owns their sprites and run-time state
# (picked up / dropped); this is just the starting layout. Optional "count": a stack.
const ITEMS := [
	{"cell": Vector2i(6, 10), "def": "res://data/items/short_sword.tres"},  # In front of the start.
	{"cell": Vector2i(6, 11), "def": "res://data/items/leather_armour.tres"},
	{"cell": Vector2i(6, 8), "def": "res://data/items/healing_potion.tres"},
	{"cell": Vector2i(4, 7), "def": "res://data/items/darts.tres", "count": 4},
	{"cell": Vector2i(10, 10), "def": "res://data/items/key.tres"},  # Room 5: key one (opens the way to the stairs).
	{"cell": Vector2i(10, 9), "def": "res://data/items/healing_potion.tres"},
	{"cell": Vector2i(8, 11), "def": "res://data/items/dagger.tres"},
	{"cell": Vector2i(12, 11), "def": "res://data/items/mace.tres"},  # Room 3.
	{"cell": Vector2i(14, 7), "def": "res://data/items/scroll.tres"},
	{"cell": Vector2i(16, 11), "def": "res://data/items/healing_potion.tres"},
	{"cell": Vector2i(12, 7), "def": "res://data/items/darts.tres", "count": 3},
	{"cell": Vector2i(16, 5), "def": "res://data/items/scroll.tres"},  # The nook north of room 3.
	{"cell": Vector2i(20, 3), "def": "res://data/items/key.tres"},  # Room 7: key two.
	{"cell": Vector2i(20, 9), "def": "res://data/items/healing_potion.tres"},  # Room 2.
	{"cell": Vector2i(18, 1), "def": "res://data/items/healing_potion.tres", "count": 3},  # Closet behind the plain door.
	{"cell": Vector2i(20, 1), "def": "res://data/items/scroll.tres"},  # Closet behind the locked door: the best loot.
	{"cell": Vector2i(20, 1), "def": "res://data/items/healing_potion.tres", "count": 2},
	{"cell": Vector2i(20, 1), "def": "res://data/items/darts.tres", "count": 6},
	{"cell": Vector2i(20, 1), "def": "res://data/items/scroll_resurrection.tres"},  # Rare: the locked closet.
	{"cell": Vector2i(13, 19), "def": "res://data/items/key.tres"},  # Room 4: key three (opens the locked closet).
	{"cell": Vector2i(14, 17), "def": "res://data/items/healing_potion.tres"},
	{"cell": Vector2i(16, 21), "def": "res://data/items/darts.tres", "count": 5},  # Room 6.
	{"cell": Vector2i(17, 21), "def": "res://data/items/dagger.tres"},
	{"cell": Vector2i(9, 16), "def": "res://data/items/slingshot.tres"},  # The cave: a ranged weapon that spends stones...
	{"cell": Vector2i(10, 16), "def": "res://data/items/stone.tres", "count": 10},
	{"cell": Vector2i(6, 7), "def": "res://data/items/stone.tres", "count": 6},  # ...and more stones near the start and in room 3.
	{"cell": Vector2i(14, 9), "def": "res://data/items/stone.tres", "count": 8},
	{"cell": Vector2i(19, 9), "def": "res://data/items/bow.tres"},  # Room 2: a better launcher than the slingshot, with its arrows.
	{"cell": Vector2i(18, 9), "def": "res://data/items/arrow.tres", "count": 8},
	{"cell": Vector2i(13, 7), "def": "res://data/items/arrow.tres", "count": 6},  # Room 3.
	{"cell": Vector2i(18, 19), "def": "res://data/items/arrow.tres", "count": 6},  # The corridor to the far stairs.
	{"cell": Vector2i(15, 19), "def": "res://data/items/flail.tres"},  # The passage into room 6: a wild, heavy weapon.
	{"cell": Vector2i(7, 17), "def": "res://data/items/scroll.tres"},  # The cave.
	{"cell": Vector2i(7, 18), "def": "res://data/items/healing_potion.tres", "count": 2},
	{"cell": Vector2i(8, 15), "def": "res://data/items/leather_armour.tres"},
	{"cell": Vector2i(20, 19), "def": "res://data/items/healing_potion.tres"},  # The corridor to the far stairs.
	{"cell": Vector2i(15, 9), "def": "res://data/items/long_sword.tres"},  # Room 3: a better sword than the short one, with the mace and hammer.
	{"cell": Vector2i(7, 11), "def": "res://data/items/bear_trap.tres"},  # Beside the long corridor whose skeleton chases you.
	{"cell": Vector2i(18, 14), "def": "res://data/items/bear_trap.tres"},  # The east corridor, above the skeleton guard.
	{"cell": Vector2i(12, 10), "def": "res://data/items/war_hammer.tres"},  # Room 3, by the mace: the heavy weapon that breaks a cracked wall.
	{"cell": Vector2i(2, 3), "def": "res://data/items/healing_potion.tres", "count": 3},  # The secret closet behind the cracked wall.
	{"cell": Vector2i(2, 4), "def": "res://data/items/scroll.tres"},
	{"cell": Vector2i(2, 5), "def": "res://data/items/darts.tres", "count": 8},
	{"cell": Vector2i(2, 5), "def": "res://data/items/scroll_resurrection.tres"},  # Rare: the secret closet.
	{"cell": Vector2i(16, 3), "def": "res://data/items/healing_potion.tres", "count": 3},  # The closet behind the thick corrupted wall.
	{"cell": Vector2i(16, 3), "def": "res://data/items/scroll.tres"},
	{"cell": Vector2i(16, 3), "def": "res://data/items/dried_meat.tres", "count": 2},
	{"cell": Vector2i(2, 3), "def": "res://data/items/leather_armour.tres"},
	# Food: scavenged rations (heal slowly; the mouldy bread is a gamble).
	{"cell": Vector2i(6, 9), "def": "res://data/items/stale_bread.tres"},  # Near the start.
	{"cell": Vector2i(10, 11), "def": "res://data/items/withered_apple.tres"},  # Room 5.
	{"cell": Vector2i(16, 10), "def": "res://data/items/hard_cheese.tres"},  # Room 3.
	{"cell": Vector2i(20, 8), "def": "res://data/items/mouldy_bread.tres"},  # Room 2: tempting, and risky.
	{"cell": Vector2i(14, 18), "def": "res://data/items/dried_meat.tres"},  # Room 4.
	{"cell": Vector2i(7, 16), "def": "res://data/items/mouldy_bread.tres"},  # The cave.
	{"cell": Vector2i(20, 1), "def": "res://data/items/dried_meat.tres", "count": 2},  # The locked closet.
	{"cell": Vector2i(2, 4), "def": "res://data/items/hard_cheese.tres"},  # The secret closet.
	# Light (docs/design/expansion_design.md section 5): loose torches and a candle; the sconce torches are in TORCHES.
	{"cell": Vector2i(15, 15), "def": "res://data/items/torch.tres"},  # The east corridor, where the sconces have gone dark.
	{"cell": Vector2i(20, 7), "def": "res://data/items/torch.tres"},  # Room 2.
	{"cell": Vector2i(16, 8), "def": "res://data/items/candle.tres"},  # Room 3, among the weapons.
]

# Monsters: the floor cell they start on and their definition resource (see
# scripts/monster_def.gd). New monsters are just new .tres files listed here. An entry may add "holds": true: that monster does not wander
# at random, it stands where it is until it sees the party.
const MONSTERS := [
	{"cell": Vector2i(9, 10), "def": "res://data/monsters/slime.tres"},
	{"cell": Vector2i(9, 13), "def": "res://data/monsters/skeleton.tres"},
	{"cell": Vector2i(15, 15), "def": "res://data/monsters/slime.tres"},
	{"cell": Vector2i(14, 9), "def": "res://data/monsters/skeleton_guard.tres"},
	{"cell": Vector2i(13, 8), "def": "res://data/monsters/slime_acid.tres"},
	{"cell": Vector2i(19, 4), "def": "res://data/monsters/skeleton.tres"},
	{"cell": Vector2i(19, 3), "def": "res://data/monsters/slime_acid.tres"},
	{"cell": Vector2i(19, 8), "def": "res://data/monsters/skeleton.tres"},
	{"cell": Vector2i(19, 17), "def": "res://data/monsters/skeleton_guard.tres"},
	{"cell": Vector2i(20, 22), "def": "res://data/monsters/warden.tres"},  # The Cursed Warden: the mini-boss, in the one-tile corridor before the stairs.
	{"cell": Vector2i(17, 20), "def": "res://data/monsters/skeleton.tres"},
	{"cell": Vector2i(13, 17), "def": "res://data/monsters/slime_acid.tres"},
	{"cell": Vector2i(16, 21), "def": "res://data/monsters/skeleton_guard.tres"},  # Room 6 (it stood in the cave, but nothing above tier 1 may stand in a curse zone).
	{"cell": Vector2i(15, 11), "def": "res://data/monsters/zombie.tres"},  # Room 3, far corner: the zombie (slow, tough, tier 2).
	# The rats' nest in the cave: three plague rats (they replace the skeleton that stood at (9,18)).
	{"cell": Vector2i(8, 17), "def": "res://data/monsters/plague_rat.tres"},
	{"cell": Vector2i(7, 18), "def": "res://data/monsters/plague_rat.tres"},
	{"cell": Vector2i(8, 18), "def": "res://data/monsters/plague_rat.tres"},
]

# Wall signs: {"cell": the floor tile you stand on, "side": the wall it hangs on (0 north, 1 west, 2 south, 3 east), "text": String}.
# Floor 1 has none; the test room labels its stations with them (wall_signs.gd).
const SIGNS := []

# Traps already set when the level starts ({"cell": Vector2i, "def": ItemDef path}): armed bear traps (trap_field.gd). Floor 1 has
# none (its traps lie about as items to pick up); the test room's traps station sets one.
const ARMED_TRAPS := []

# Test-room only (read by scripts/debug/, never by the game): trap tiles that spawn monsters when stepped on
# ({"trigger": Vector2i, "text": String, "monsters": [{"cell": Vector2i, "def": String}]}, re-armed when the party leaves the
# station's rows) and the named places T teleports to ({"name": String, "cell": Vector2i, "facing": int}).
const AMBUSHES := []
const STATIONS := []

# --- Curse zones (docs/design/expansion_design.md section 3, roadmap 7l.3) ---
# Places where flames die: {"id": String, "tiles": Array of Vector2i}. Inside one (outside a Bless's pocket) a held torch or candle
# sputters for a second and goes out and will not relight, a sconce or brazier will not light, a burning torch lying or thrown there goes
# out and oil will not catch; a light with ItemDef.curse_proof (the Unquenchable) and spell light are untouched. A thin green haze lies on
# the floor of the zone. A puzzle effect {"kind": "clear_curse_zone", "id": ...} lifts one for good (the run flag
# "curse_zone.<id>.cleared", saved). Nothing above tier 1 may stand in one (zone_tier_violations: a warning when the level loads).
# Rules and numbers: scripts/curse_zones.gd, data/light.tres "Curse zones".
const CURSE_ZONES := [
	# The cave (x 6-10, y 15-19, its floor tiles): where the three plague rats nest. Lifted for good when they are dead (PUZZLES "cave_cleansed").
	{"id": "cave", "tiles": [
		Vector2i(8, 15), Vector2i(9, 15),
		Vector2i(7, 16), Vector2i(8, 16), Vector2i(9, 16), Vector2i(10, 16),
		Vector2i(6, 17), Vector2i(7, 17), Vector2i(8, 17), Vector2i(9, 17), Vector2i(10, 17),
		Vector2i(6, 18), Vector2i(7, 18), Vector2i(8, 18), Vector2i(9, 18),
		Vector2i(7, 19), Vector2i(8, 19), Vector2i(9, 19),
	]},
]

# Where the main menu's backdrop camera stands: a cell of this level, looking east down its long south corridor (main_menu.gd). A level
# that leaves this out gets its START_TILE.
const MENU_VIEW_CELL := Vector2i(6, 13)
