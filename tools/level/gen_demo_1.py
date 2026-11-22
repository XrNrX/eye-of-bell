"""Builds levels/demo_1.gd, the demo level, from the hand-drawn map C:/Users/bucki/Desktop/mapBell.png (35x35 squares of 18 px).

    python tools/level/gen_demo_1.py            # writes levels/demo_1.gd and prints a report (reachability, monster and item counts)

The map is read off the picture (black = wall, white = floor, a plain square on a wall line = door, a dotted line = portcullis, the striped block =
up stairs, the triangle = down stairs; the gap in the outer wall at the top left and the bottom right is sealed). Everything else (which doors are
locked, the levers, monsters, items, torches, the camp) is DESIGN and lives in the tables below, so the balance can be changed by editing them and
running the script again. The result is a plain level script like levels/floor_1.gd; hand edits to it are lost when the script is run again.

Rooms are named by the numbers (and letters) printed on the map. Distance from the start (steps through every door and gate) is the difficulty scale:
fodder near the start, elites in the middle, the Cursed Warden guarding the stairs, loot to match (docs/design/expansion_design.md section 2).
"""
import json
import random
import sys
from collections import deque
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
MAP_PNG = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(r"C:\Users\bucki\Desktop\mapBell.png")
OUT = ROOT / "levels" / "demo_1.gd"
X0, Y0, C, N = 94, 34, 18, 35   # Where the grid starts in the picture, the square size and the size of the map.
DIRS = [(-1, 0), (0, -1), (1, 0), (0, 1)]   # (row, col) steps for facing 0 N, 1 W, 2 S, 3 E.

# ----------------------------------------------------------------------------------------------------------------------------------------------
# 1. Read the map
# ----------------------------------------------------------------------------------------------------------------------------------------------


def read_map():
    g = np.array(Image.open(MAP_PNG).convert("L")).astype(float)
    legend = {"portcullis": 148, "door": 238}   # Where the legend's symbols are in the picture: their templates.
    templates = {k: g[692:709, cx - 8:cx + 9] for k, cx in legend.items()}

    def variants(t):
        return [t, np.rot90(t), np.rot90(t, 2), np.rot90(t, 3), np.fliplr(t), np.flipud(t)]
    grid = [[0] * N for _ in range(N)]
    for r in range(N):
        for c in range(N):
            cell = g[Y0 + r * C + 2:Y0 + (r + 1) * C - 1, X0 + c * C + 2:X0 + (c + 1) * C - 1]
            frac = (cell < 100).mean()
            cx, cy = X0 + c * C + 9, Y0 + r * C + 9
            patch = g[cy - 8:cy + 9, cx - 8:cx + 9]
            kind = None
            if 0.02 <= frac <= 0.9:
                for k, t in templates.items():
                    if min(np.abs(patch - v).mean() for v in variants(t)) < 10:
                        kind = k
            grid[r][c] = 2 if kind == "door" else 5 if kind == "portcullis" else (1 if frac > 0.5 else 0)
    return grid


MAP = read_map()
MAP[0][1] = 1     # The gaps in the outer wall (top left, bottom right) lead outside the map: sealed.
MAP[34][31] = 1
MAP[2][17] = 4    # The down stairs (the triangle): two squares in the dead end north of the top corridor.
MAP[3][17] = 4
START = (25, 1)   # (row, col): the landing south of nothing but the up stairs (the striped block at (26,1) and (27,1), left as wall).
START_FACING = 3  # East, at the door into the round room.
LOCKED = [(2, 13), (24, 17)]   # (row, col): the door onto the stairs corridor, and the vault's south door.

for r, c in LOCKED:
    MAP[r][c] = 3


def passable(r, c, gates_open=True, locked_open=True):
    t = MAP[r][c]
    return t in (0, 2, 4) or (t == 5 and gates_open) or (t == 3 and locked_open)


# ----------------------------------------------------------------------------------------------------------------------------------------------
# 2. Rooms: the connected squares with doors and gates taken as walls, named by the labels printed on the map.
# ----------------------------------------------------------------------------------------------------------------------------------------------
LABELS = {(4, 2): "9", (4, 12): "10", (10, 6): "13", (2, 22): "19", (4, 31): "18", (9, 14): "5", (9, 26): "6", (15, 17): "1", (15, 23): "2",
          (16, 3): "11", (21, 17): "3", (21, 23): "4", (25, 5): "12", (27, 14): "7", (27, 26): "8", (31, 3): "17", (32, 10): "15",
          (32, 18): "14", (32, 28): "16", (1, 11): "a", (3, 15): "c", (5, 9): "e", (13, 7): "i", (21, 1): "m", (33, 7): "n"}
ROOM_AT = {}   # (row, col) -> room id
ROOMS = {}     # room id -> [(row, col)]
_n = 0
for _r in range(N):
    for _c in range(N):
        if MAP[_r][_c] in (1, 2, 3, 5) or (_r, _c) in ROOM_AT:
            continue
        _n += 1
        q = deque([(_r, _c)])
        ROOM_AT[(_r, _c)] = _n
        cells = [(_r, _c)]
        while q:
            a, b = q.popleft()
            for dr, dc in DIRS:
                x, y = a + dr, b + dc
                if 0 <= x < N and 0 <= y < N and MAP[x][y] not in (1, 2, 3, 5) and (x, y) not in ROOM_AT:
                    ROOM_AT[(x, y)] = _n
                    q.append((x, y))
                    cells.append((x, y))
        ROOMS[_n] = cells
NAME = {}      # room id -> a name (the map's labels in it, joined), or "r<id>" for rooms with no label
for rid, cells in ROOMS.items():
    labels = sorted({LABELS[p] for p in cells if p in LABELS})
    NAME[rid] = "+".join(labels) if labels else "r%d" % rid
BY_NAME = {v: k for k, v in NAME.items()}


def room(name):
    """The squares of the room with the map label `name` (a room that carries several labels is found by any of them)."""
    for rid, n in NAME.items():
        if name == n:
            return ROOMS[rid]
    for rid, n in NAME.items():
        if name in n.split("+"):
            return ROOMS[rid]
    raise KeyError(name)


# ----------------------------------------------------------------------------------------------------------------------------------------------
# 3. Gates: every portcullis gets a lever (a wall lever on a floor square near it, on the room named in the table)
# ----------------------------------------------------------------------------------------------------------------------------------------------
# portcullis (row, col): the room whose side the lever hangs on.
GATE_LEVER_ROOM = {
    (3, 4): "r5",     # the west maze -> room 9 (treasure)
    (6, 29): "6",     # room 6 -> room 18
    (11, 4): "13",    # room 13 -> the little passage to room 11
    (11, 32): "6",    # room 6 -> the east corridor
    (12, 1): "11",    # room 11 -> the west maze
    (15, 8): "5",     # a shortcut: pulled from room 5's side, it joins room 5 to the 'i' passage and room 11
    (15, 14): "5",    # room 5's strip -> vault room 1
    (21, 26): "8",    # room 8 -> vault room 4
    (28, 3): "12",    # the round room -> the hexagon (17)
    (30, 9): "7",     # room 7 -> room 15
    (30, 19): "7",    # room 7 -> room 14
    (31, 12): "15",   # room 15 -> the passage east of it
    (33, 8): "15",    # the 'n' passage <-> room 15
    (33, 16): "14",   # room 14 <-> the passage west of it
    (33, 20): "14",   # room 14 -> the passage east of it
    (33, 30): "16",   # room 16 -> the east corridor
}


def wall_faces(r, c):
    """The faces (side 0 N, 1 W, 2 S, 3 E) of floor square (r, c) that are plain wall: where a lever or a sconce can hang."""
    out = []
    for side, (dr, dc) in enumerate(DIRS):
        x, y = r + dr, c + dc
        if 0 <= x < N and 0 <= y < N and MAP[x][y] == 1:
            out.append(side)
    return out


def lever_spot(gate, room_name):
    """A floor square in `room_name` near the portcullis with a wall face beside it, preferring the wall that flanks the gate."""
    gr, gc = gate
    best = None
    for (r, c) in room(room_name):
        d = max(abs(r - gr), abs(c - gc))
        if d > 3 or MAP[r][c] != 0:
            continue
        for side in wall_faces(r, c):
            wr, wc = r + DIRS[side][0], c + DIRS[side][1]
            flank = max(abs(wr - gr), abs(wc - gc))
            score = (flank > 1, d, abs(r - gr) + abs(c - gc))
            if best is None or score < best[0]:
                best = (score, (r, c), side)
    if best is None:
        raise ValueError("no lever spot near %s in %s" % (gate, room_name))
    return best[1], best[2]


DOOR_IDS = {}
LEVERS = []
for gate, rn in sorted(GATE_LEVER_ROOM.items()):
    gid = "gate_%d_%d" % (gate[1], gate[0])
    DOOR_IDS[gate] = gid
    (lr, lc), side = lever_spot(gate, rn)
    LEVERS.append({"cell": (lr, lc), "side": side, "target": gid})
assert all(MAP[r][c] == 5 for (r, c) in GATE_LEVER_ROOM) and sum(row.count(5) for row in MAP) == len(GATE_LEVER_ROOM)

# ----------------------------------------------------------------------------------------------------------------------------------------------
# 4. Distance from the start (every door and gate open), the difficulty scale
# ----------------------------------------------------------------------------------------------------------------------------------------------
DIST = {START: 0}
_q = deque([START])
while _q:
    a, b = _q.popleft()
    for dr, dc in DIRS:
        x, y = a + dr, b + dc
        if 0 <= x < N and 0 <= y < N and passable(x, y) and (x, y) not in DIST:
            DIST[(x, y)] = DIST[(a, b)] + 1
            _q.append((x, y))

# ----------------------------------------------------------------------------------------------------------------------------------------------
# 5. Design tables
# ----------------------------------------------------------------------------------------------------------------------------------------------
RNG = random.Random(1991)
MON = "res://data/monsters/%s.tres"
ITM = "res://data/items/%s.tres"

# room -> monsters (kind names). Rooms not listed have none. Tier 1: slime, slime_acid, skeleton, plague_rat, goblin. Tier 2: skeleton_guard, zombie,
# red_shaman, knight, spider, halberdier. Tier 3: warden. The start (m), the round room (12) and the closets are quiet.
MONSTERS_BY_ROOM = {
    "11": ["slime", "skeleton"],                                   # near the start
    "r5": ["plague_rat", "plague_rat"],                            # the west maze
    "13": ["goblin", "skeleton"],
    "9": ["skeleton_guard"],                                       # guards the vault key
    "17": ["slime_acid", "slime_acid"],                            # the hexagon, behind the first gate
    "n": ["plague_rat"],
    "7": ["goblin", "skeleton", "skeleton", "slime_acid"],  # the first big room: fodder only
    "15": ["skeleton"], "r28": ["plague_rat", "plague_rat"],       # the south chain
    "14": ["zombie"], "r30": ["goblin"],
    "16": ["skeleton_guard", "red_shaman"],                        # holds the stairs key
    "r12": ["spider", "plague_rat", "plague_rat"],                 # the east corridor
    "8": ["goblin", "skeleton", "spider", "halberdier"],
    "6": ["skeleton_guard", "halberdier", "red_shaman", "knight"],
    "5": ["zombie", "skeleton_guard", "knight", "goblin", "skeleton"],
    "10": ["skeleton_guard"],                                      # beside the stairs door
    "1": ["knight"], "2": ["slime_acid", "slime_acid"], "3": ["skeleton", "skeleton"], "4": ["halberdier", "zombie"],  # the vault rooms
    "a+c": [],                                                     # (the Warden is placed by hand below)
    "19": ["skeleton_guard", "red_shaman"], "18": ["knight", "halberdier"],
}
WARDEN_AT = (1, 16)   # (row, col): in the corridor before the stairs

# item tables: room -> [(item name, count, "far" | "near" | "any")]
ITEMS_BY_ROOM = {
    "m": [("torch", 1, "any"), ("healing_potion", 1, "any")],
    "12": [("bedroll", 1, "any"), ("dried_meat", 1, "any")],
    "11": [("short_sword", 1, "any"), ("healing_potion", 1, "any"), ("darts", 4, "any"), ("stale_bread", 2, "any")],
    "i": [("healing_potion", 1, "any")],
    "r17": [("hearth_coal", 1, "any"), ("candle", 2, "any")],   # the closet off room 7: the level's Hearth Coal
    "r5": [("stone", 8, "any"), ("healing_potion", 1, "any")],
    "13": [("leather_armour", 1, "any"), ("mana_potion", 1, "any"), ("stone", 6, "any")],
    "9": [("key", 1, "far"), ("scroll", 1, "any"), ("healing_potion", 2, "any")],              # key two (the vault)
    "17": [("long_sword", 1, "any"), ("healing_potion", 1, "any"), ("oil_flask", 2, "any")],
    "n": [("dried_meat", 1, "any")],
    "7": [("healing_potion", 2, "any"), ("arrow", 8, "any"), ("torch", 1, "any"), ("hard_cheese", 1, "any"), ("dagger", 1, "any"), ("scroll", 1, "any")],
    "15": [("bow", 1, "any"), ("healing_potion", 1, "any")],
    "r28": [("mouldy_bread", 2, "any"), ("arrow", 6, "any")],
    "14": [("mace", 1, "any"), ("healing_potion", 1, "any"), ("bear_trap", 1, "any")],
    "r30": [("dried_meat", 1, "any"), ("mana_potion", 1, "any")],
    "16": [("key", 1, "far"), ("healing_potion", 2, "any"), ("scroll", 1, "any")],              # key one (the stairs door)
    "r12": [("healing_potion", 1, "any"), ("withered_apple", 1, "any"), ("stone", 8, "any")],
    "8": [("healing_potion", 2, "any"), ("arrow", 6, "any"), ("flail", 1, "any"), ("mana_potion", 1, "any"), ("hard_cheese", 1, "any")],
    "6": [("healing_potion", 4, "any"), ("war_hammer", 1, "any"), ("scroll", 1, "any"), ("bedroll", 1, "any"), ("darts", 4, "any")],
    "5": [("healing_potion", 4, "any"), ("slingshot", 1, "any"), ("dried_meat", 1, "any"), ("oil_flask", 1, "any"), ("torch", 1, "any"), ("leather_armour", 1, "any")],
    "10": [("healing_potion", 1, "any"), ("mana_potion", 1, "any")],
    "e": [("scroll_resurrection", 1, "far")],                                                   # the dead end 'e'
    "1": [("healing_potion", 2, "any"), ("key", 1, "any"), ("bear_trap", 1, "any")],            # a spare key
    "2": [("healing_potion", 2, "any"), ("mana_potion", 1, "any"), ("threadbare_robes", 1, "any")],
    "3": [("scroll_resurrection", 1, "any"), ("healing_potion", 3, "any"), ("holy_symbol", 1, "any"), ("spellbook", 1, "any")],
    "4": [("healing_potion", 2, "any"), ("scroll", 2, "any"), ("dagger", 1, "any"), ("candle", 1, "any")],
    "19": [("healing_potion", 2, "any"), ("mana_potion", 1, "any"), ("scroll", 1, "any")],
    "18": [("healing_potion", 2, "any"), ("dried_meat", 2, "any"), ("arrow", 6, "any")],
    "a+c": [("healing_potion", 1, "any"), ("torch", 1, "any")],
}


def free_cells(name, taken, near_doors_ok=False):
    out = []
    for (r, c) in room(name):
        if (r, c) in taken or (r, c) == START or MAP[r][c] != 0:
            continue
        if not near_doors_ok and any(0 <= r + dr < N and 0 <= c + dc < N and MAP[r + dr][c + dc] in (2, 3, 5, 4) for dr, dc in DIRS):
            continue
        out.append((r, c))
    return out


def pick_spread(cands, count, taken_pts, mind):
    """`count` squares of `cands`, none within `mind` of each other or of `taken_pts` where that is possible."""
    chosen = []
    pool = cands[:]
    RNG.shuffle(pool)
    for p in pool:
        if len(chosen) == count:
            break
        if all(max(abs(p[0] - q[0]), abs(p[1] - q[1])) >= mind for q in chosen + taken_pts):
            chosen.append(p)
    for p in pool:   # Not enough room at that spacing: take what is left.
        if len(chosen) == count:
            break
        if p not in chosen:
            chosen.append(p)
    return chosen


TAKEN = {(25, 5), (24, 5)}   # The camp in the round room.
MONSTER_LIST = []
for name, kinds in MONSTERS_BY_ROOM.items():
    if not kinds:
        continue
    cands = free_cells(name, TAKEN)
    spots = pick_spread(cands, len(kinds), [], 3 if len(room(name)) > 20 else 2)
    for kind, spot in zip(kinds, spots):
        MONSTER_LIST.append({"cell": spot, "def": MON % kind, "room": name})
        TAKEN.add(spot)
MONSTER_LIST.append({"cell": WARDEN_AT, "def": MON % "warden", "room": "a+c"})
TAKEN.add(WARDEN_AT)

ITEM_LIST = []
for name, rows in ITEMS_BY_ROOM.items():
    for item, count, where in rows:
        cands = free_cells(name, TAKEN, near_doors_ok=True)
        if where == "far":   # The far end of the room from the start.
            cands.sort(key=lambda p: -DIST.get(p, 0))
            cands = cands[:max(1, len(cands) // 4)]
        spot = pick_spread(cands, 1, [], 1)[0]
        entry = {"cell": spot, "def": ITM % item, "room": name}
        if count > 1:
            entry["count"] = count
        ITEM_LIST.append(entry)
        if item != "key":
            pass
# Keys: link each to a locked door (the editor's "opens"): the stairs door and the vault door; the spare opens the stairs door too.
_keys = [e for e in ITEM_LIST if e["def"].endswith("/key.tres")]
_link = {"16": (2, 13), "9": (24, 17), "1": (2, 13)}
for e in _keys:
    e["opens"] = _link[e["room"]]

# sconces
SCONCE_LIST = []
SCONCE_PLAN = {   # room -> (count, how many of them unlit with a torch, how many empty brackets)
    "m": (1, 0, 0), "12": (2, 0, 0), "11": (2, 1, 0), "i": (0, 0, 0), "r5": (2, 1, 0), "13": (1, 0, 1), "9": (1, 0, 1), "17": (2, 1, 0), "n": (0, 0, 0),
    "7": (4, 2, 1), "15": (1, 0, 1), "14": (1, 0, 1), "16": (2, 1, 0), "r12": (3, 1, 1), "8": (4, 1, 2), "6": (4, 1, 2), "5": (4, 2, 1),
    "10": (1, 0, 0), "1": (1, 0, 1), "2": (1, 0, 1), "3": (2, 1, 0), "4": (1, 0, 1), "19": (2, 0, 1), "18": (2, 1, 0), "a+c": (3, 1, 1), "e": (1, 0, 0),
}
for name, (count, unlit, empty) in SCONCE_PLAN.items():
    cands = []
    for (r, c) in room(name):
        if MAP[r][c] != 0:
            continue
        for side in wall_faces(r, c):
            cands.append((r, c, side))
    RNG.shuffle(cands)
    chosen = []
    for r, c, side in cands:
        if len(chosen) == count:
            break
        if all(max(abs(r - q[0]), abs(c - q[1])) >= 4 for q in chosen + [(a, b) for (a, b, s, t) in SCONCE_LIST]):
            chosen.append((r, c, side))
    for i, (r, c, side) in enumerate(chosen):
        state = 0 if i < count - unlit - empty else 1 if i < count - empty else 2
        SCONCE_LIST.append((r, c, side, state))

# ----------------------------------------------------------------------------------------------------------------------------------------------
# 6. Checks (the level can be finished) and a report
# ----------------------------------------------------------------------------------------------------------------------------------------------


def solvable():
    """Flood fill with levers and keys: a gate opens once a lever linked to it stands on a square reached; a locked door once a key linked to it lies
    on a square reached. True if every floor square and the stairs end up reached."""
    open_gates, open_locked = set(), set()
    seen = {START}
    changed = True
    while changed:
        changed = False
        q = list(seen)
        i = 0
        while i < len(q):
            a, b = q[i]
            i += 1
            for dr, dc in DIRS:
                x, y = a + dr, b + dc
                if (x, y) in seen or not (0 <= x < N and 0 <= y < N):
                    continue
                t = MAP[x][y]
                if t in (0, 2, 4) or (t == 5 and (x, y) in open_gates) or (t == 3 and (x, y) in open_locked):
                    seen.add((x, y))
                    q.append((x, y))
                    changed = True
        for e in ITEM_LIST:
            if (e["cell"][0], e["cell"][1]) in seen and "opens" in e and e["opens"] not in open_locked:
                open_locked.add(e["opens"])
                changed = True
        for lv in LEVERS:
            if lv["cell"] in seen:
                for gate, gid in DOOR_IDS.items():
                    if gid == lv["target"] and gate not in open_gates:
                        open_gates.add(gate)
                        changed = True
    floor = {(r, c) for r in range(N) for c in range(N) if MAP[r][c] in (0, 2, 4)}
    return floor - seen, seen


def report():
    left, seen = solvable()
    print("floor squares:", sum(1 for r in range(N) for c in range(N) if MAP[r][c] in (0, 2, 3, 4, 5)), "| rooms:", len(ROOMS))
    print("unreachable floor squares after levers and keys:", len(left), sorted(left)[:10])
    stairs_ok = (2, 17) in seen and (3, 17) in seen
    print("stairs reachable:", stairs_ok)
    by_kind = {}
    for m in MONSTER_LIST:
        by_kind[m["def"].split("/")[-1][:-5]] = by_kind.get(m["def"].split("/")[-1][:-5], 0) + 1
    print("monsters:", len(MONSTER_LIST), by_kind)
    tiers = {"slime": 1, "slime_acid": 1, "skeleton": 1, "plague_rat": 1, "goblin": 1, "skeleton_guard": 2, "zombie": 2, "red_shaman": 2, "knight": 2,
             "spider": 2, "halberdier": 2, "warden": 3}
    cost = {1: 3.5, 2: 11.0, 3: 30.0}   # % of the party's HP a fair fight with one costs (expansion_design.md).
    total = sum(cost[tiers[k]] * v for k, v in by_kind.items())
    print("fight cost if every monster were fought: about %d%% of the party's HP" % total)
    by_item = {}
    for e in ITEM_LIST:
        k = e["def"].split("/")[-1][:-5]
        by_item[k] = by_item.get(k, 0) + e.get("count", 1)
    print("items:", sum(by_item.values()), by_item)
    heal = by_item.get("healing_potion", 0)
    print("healing potions:", heal, "(each ~10 HP of a party of 86)")
    print("sconces:", len(SCONCE_LIST), "levers:", len(LEVERS))
    far = max(DIST.values())
    print("farthest square from the start:", far, "steps; stairs at", DIST[(2, 17)], "steps")


# ----------------------------------------------------------------------------------------------------------------------------------------------
# 7. Write the level file
# ----------------------------------------------------------------------------------------------------------------------------------------------
def v2(p):
    return "Vector2i(%d, %d)" % (p[1], p[0])   # The game's Vector2i is (x = column, y = row).


def write():
    lines = []
    w = lines.append
    w("extends RefCounted")
    w("## Demo level 1: a plain script of consts, the same shape as levels/floor_1.gd (DungeonMap.use_level(DungeonMap.DEMO_1_PATH) loads it).")
    w("## Traced from the hand-drawn map mapBell.png (35x35) and filled in by tools/level/gen_demo_1.py (the tables in that script are the design: run it again")
    w("## after changing them; hand edits to this file are lost). Room numbers in the comments are the map's.")
    w("##")
    w("## The way through: start in the corridor (m) -> the round room (12) -> room 7 -> room 8 -> room 6 -> room 5 -> room 10 -> the LOCKED door onto the")
    w("## stairs corridor, where the Cursed Warden stands before the stairs. Keys: one in room 16 (the south-east, behind the south chain's gates), one in")
    w("## room 9 (the west maze, behind a gate) for the vault door, and a spare in vault room 1. Sixteen portcullises, each raised by a lever hanging on a")
    w("## wall near it. The Hearth Coal lies in the closet off room 7 (the door at (8,19)).")
    w("")
    w("const MAP := [")
    for r in range(N):
        w("\t[" + ", ".join(str(v) for v in MAP[r]) + "],  # %d" % r)
    w("]")
    w("")
    w("const START_TILE := Vector2i(%d, %d)" % (START[1], START[0]))
    w("const START_FACING := %d" % START_FACING)
    w("")
    w("# Wall sconces as Vector4i(x, z, side, state): 0 lit, 1 unlit with a torch, 2 an empty bracket (DungeonMap.SCONCE_*).")
    w("const TORCHES := [")
    for (r, c, side, state) in SCONCE_LIST:
        w("\tVector4i(%d, %d, %d, %d)," % (c, r, side, state))
    w("]")
    w("")
    w("const CORRUPTION := {}")
    w("const PUZZLES := []")
    w("")
    w("# The portcullises: each is raised by the lever(s) linked to it.")
    w("const DOOR_IDS := {")
    for gate, gid in sorted(DOOR_IDS.items()):
        w("\t%s: \"%s\"," % (v2(gate), gid))
    w("}")
    w("")
    w("const PLATES := []")
    w("")
    w("const LEVERS := [")
    for lv in LEVERS:
        w("\t{\"cell\": %s, \"side\": %d, \"target\": \"%s\"}," % (v2(lv["cell"]), lv["side"], lv["target"]))
    w("]")
    w("")
    w("const STRUCTURES := [")
    w("\t{\"cell\": Vector2i(5, 25), \"kind\": \"campfire\"},  # A camp in the round room (12): fire, spit and four bedrolls; click it to rest or cook.")
    w("\t{\"cell\": Vector2i(5, 24), \"kind\": \"camp_spot\"},  # Old ash where the party rests.")
    w("]")
    w("")
    w("# Items by room (the comment names the room). A key's \"opens\" is the locked door it is meant for (the dungeon editor's link; the game ignores it).")
    w("const ITEMS := [")
    for e in ITEM_LIST:
        extra = ""
        if "count" in e:
            extra += ", \"count\": %d" % e["count"]
        if "opens" in e:
            extra += ", \"opens\": %s" % v2(e["opens"])
        w("\t{\"cell\": %s, \"def\": \"%s\"%s},  # %s" % (v2(e["cell"]), e["def"], extra, e["room"]))
    w("]")
    w("")
    w("# Monsters by room, weak near the start and tougher toward the stairs, the Cursed Warden last.")
    w("const MONSTERS := [")
    for m in MONSTER_LIST:
        w("\t{\"cell\": %s, \"def\": \"%s\"},  # %s" % (v2(m["cell"]), m["def"], m["room"]))
    w("]")
    w("")
    w("const SIGNS := []")
    w("const ARMED_TRAPS := []")
    w("const AMBUSHES := []")
    w("const STATIONS := []")
    w("const CURSE_ZONES := []")
    w("const MENU_VIEW_CELL := Vector2i(%d, %d)" % (START[1], START[0]))
    OUT.write_text("\n".join(lines) + "\n", encoding="utf-8", newline="\n")


if __name__ == "__main__":
    write()
    report()
    print("wrote", OUT)
