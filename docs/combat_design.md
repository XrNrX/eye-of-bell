# Combat design

The combat rules, including critical hits and critical fails, live on one page, so there is a single copy to keep up to date:

https://claude.ai/artifact/BGAw8C4bkJfdBrSScE49yY

See the "Critical hits and fails" and "Hits from behind and the sides" sections. The maths is in `scripts/combat_rules.gd`, the tunable feedback in `data/combat_feel.tres` and the lines in `data/banter.json`.

## Equipment rules

- **Mages can't wear armour. This is intentional.** It is set per item with `ItemDef.cant_use` (a list of class names); today only Leather Armour lists "Mage", so any armour added later must list it too. The inventory slots and portrait-click equipping both refuse with "The mage can't wear that."
- Armour or a weapon on the cursor, clicked onto a portrait, equips it (armour slot, or the main hand). Shift-click on floor armour equips it on the hero who gains the most defence.

## Monster pacing: the step-back dance

The aim is the Eye of the Beholder dance: step back or sidestep and get a free swing or a breather, instead of monsters closing the gap at once and surrounding the party. Code: `scripts/monster.gd` ("Movement AI" and `_fight`). Numbers: each monster's `MonsterDef` ("Movement and pacing" group in `data/monsters/*.tres`) and the shared `data/monster_ai.tres`. Tune by feel in the test room's **Monster pacing** station (T to teleport; I spawns a pack, O picks a value, [ and ] lower or raise it on every kind at once, Y resets; the H overlay shows the table; nothing is saved, so copy what feels right into the `.tres` files).

**What was wrong (2026-11-13):** monsters stepped every 0.8 s (slimes 1.0 to 1.14 s) on a free-running timer at a random phase, so after the party stepped back the next move came 0 to 0.8 s later, about 0.4 s on average, with no reaction beat. Adjacency counted from the *start* of their 0.3 s step, so the wind-up was already running while they slid in (the guard began its swing 0.18 s after it arrived). Chasing was greedy per axis: a monster blocked by another sidestepped onto the diagonal and then into the tile beside the party, so every extra monster took another side.

| | Step interval | Reaction delay | Arrival recovery | Wind-up | Flank after |
|---|---|---|---|---|---|
| Party (for comparison) | 0.2 s a tile | | | | |
| Skeleton | 1.2 s | 0.5 s | 0.5 s | 0.5 × 2.0 s = 1.0 s | 3.0 s |
| Skeleton guard | 1.1 s | 0.4 s | 0.5 s | 0.5 × 1.8 s = 0.9 s | 2.5 s |
| Slime | 1.6 s | 0.6 s | 0.6 s | 0.5 × 2.5 s = 1.25 s | 3.5 s |
| Acid slime | 1.5 s | 0.6 s | 0.6 s | 0.5 × 2.2 s = 1.1 s | 3.5 s |

Shared (`data/monster_ai.tres`): `max_flankers` 1, `step_seconds` 0.3 (the step animation), `wander_pause` 0.3, `path_radius` 12.

**The rules and why:**
- **Own clock only** (`step_interval`). Nothing the party does resets or speeds up a monster's next move. At 1.1 to 1.6 s against the party's 0.2 s a tile, a party that keeps moving gets away (5 to 8 times faster); a party that stands and fights is caught. No rat exists yet; when it does, give it about 0.7 s so it is the one thing that keeps up.
- **Reaction delay** (`reaction_delay`). When the party steps out of a monster's reach, its next move is pushed to at least this far off (never brought forward). It is the beat that makes a step back pay: the monster is seen to notice, then follow.
- **Arrival recovery** (`arrival_recovery`). A monster that steps up next to the party can't start attacking until this long after its step animation *ends*; then the usual wind-up (`wind_up` × `attack_interval`) runs, with the swing animation leading the blow as before. It can never step and strike in the same moment (smoke test: "a monster can't step and attack in the same tick"). The party walking up to a monster gets only the wind-up: that was the party's choice.
- **The dance, in numbers (skeleton):** step back (0.2 s); 0.5 s later it moves; 0.3 s slide; 0.5 s recovery; 1.0 s wind-up. Its blow comes about 2.3 s after the step back, longer than any hero's swing (1.4 to 1.7 s), so stepping back, swinging as it arrives and stepping back again before it strikes works, and walking away at a steady pace leaves it behind. If that proves too safe, shorten `reaction_delay` or `arrival_recovery` first.
- **Queueing, not surrounding.** Only one monster heads for the party at a time: once a monster stands next to the party, the others may not step onto any other tile beside it; they queue as close as they can behind the ones already there (breadth-first paths, so in a corridor they line up, in a room they wait on the diagonals). Of two equally near free tiles, the one in front of the party wins.
- **Flanking is possible, not automatic.** A monster held back for `flank_after` seconds may take a flank pass (at most `max_flankers`, 1, at once) and go round to any free side of the party; the pass is handed back when it can't find a way, loses sight of the party, or becomes the only monster there. A monster that reaches the party from behind or the side first (the party turned its back, or walked into it) attacks from there: that is the party's doing, and the side rules ("Hits from behind and the sides" on the blueprint page) still punish it.
