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

## Status effects and Hold Monster

**Status effects** (`scripts/status_def.gd`, one `.tres` per status in `data/statuses/`; carried by `scripts/monster.gd`, "Status effects"). A monster can carry timed statuses: `Monster.add_status(def, seconds, source)` (the hero_index who put it on, -1 for nobody; putting it on again keeps the longer time), `remove_status(id)`, `has_status(id)`, `status_left(id)`, `is_helpless()`. Every rule is a field of the `StatusDef`, so a new status is a new `.tres`, not new code:

| Field | What it does | Held |
|---|---|---|
| `stops_moving` | no steps; the move clock pauses | yes |
| `stops_attacking` | no blows or wind-up; the attack clock pauses, a swing in progress is cancelled and starts again from the top when it is free | yes |
| `freezes_animation` | the sprite holds the frame it was showing | yes |
| `move_time_scale`, `attack_time_scale` | slower moves or attacks (2.0 = half speed): for "slowed" later | 1.0 |
| `damage_per_second` | HP lost per second in whole points, the source hero named as the killer: for "poisoned" later | 0 |
| `helpless` | heroes' blows get their `CharacterDef.helpless_crit` | yes |
| `tint`, `icon` | a faint colour on the sprite; an icon beside the health bar (and the bar stays up while it lasts) | pale blue; a padlock |
| `fx_spell`, `fx_start`, `fx_loop`, `fx_end`, `fx_tint`, `fx_light_*` | flipbooks played once as it starts, looped while it lasts and once as it ends, with a steady light | Hold Monster's runes |
| `resist_message`, `immune_message` | the log lines (how likely it lands and for how long is the tier table's row for its id, below) | "The {monster} shrugs off the spell." |
| `started_event`, `ended_event` | the GameEvents signals | `monster_held(monster, source)`, `monster_released(monster)` |

A monster that dies while held is not "released" (no signal, no shatter). Statuses and their time left are saved with each monster (`statuses` in the save; an older save has none), and loading puts them back quietly: no signal, no binding again.

**Hold Monster** (`data/spells/hold_monster.tres`, the Mage's fourth spell in the spellbook):

| | Value | Why |
|---|---|---|
| Target | the monster in the tile directly in front (`SpellDef.reach` 1) | a close-quarters escape or set-up, not a sniping tool |
| Hold | 5 s (`status_seconds`) | long enough for two or three blows, or to walk out of a corner |
| Mana | 5 of the Mage's 12 | two casts empty him; competes with Fireball (6) and Shield (4) |
| Recast wait | 12 s (`SpellDef.recast_seconds`, per hero; the spell list shows the seconds left) | it can't be chained: at most 5 s held in every 12, so a fight is never frozen |
| Lands | by the monster's tier (see Monster tiers): 90% on fodder (skeletons, slimes), 65% on the skeleton guard, 35% and 15% on tiers 3 and 4, which are held for half the time | tier 1: a spell almost always works; tier 4: a gamble |
| Slimes | held, but for 75% of the time: "The slime quivers against the runes." (`MonsterDef.status_overrides`) | they wobble free |
| Wall monsters | immune | |

- Nothing in front, or a monster it can never affect (a wall monster, or an override with chance 0): refused, costs nothing, like every spell that can't take effect.
- A resisted cast is still a cast: mana, the action cooldown and the recast wait are spent. "Fennick casts Hold Monster. The skeleton shrugs off the spell." The runes form and shatter at once.
- Casting it starts a fight (the fight tracker counts it as a blow).
- **Helpless:** blows on a held monster get the hero's `helpless_crit` on top of their crit chance: Thief +25, Fighter +10, Cleric and Mage +8, capped at 60% (`CombatRules.HELPLESS_CRIT_CAP`; the normal cap is 40). A Thief with a dagger goes from 22% to 47%: the stab in the back. It applies to melee, thrown and fired weapons; spells don't get it.
- **Look** (arcane: cold pale blue, per `docs/art_style.md`): PixelLab VFX flipbooks drawn in greys and tinted blue in the game (`art/spells/hold_monster/`: `bind`, `held`, `shatter`), drawn just in front of the monster towards the camera; a soft steady blue light on it; the sprite frozen and tinted pale blue; a padlock beside its health bar. Placement and size are in the "Status effects on monsters" group of `data/spell_effects.tres`. Reduce flashing dims the light.
- **Banter** (`data/banter.json`): `monster_held` (the Mage, the first time only: "It worked! It actually... ahem. As expected."), `hit_held` (the Thief stabbing a held monster: "Hold still. Good lad."), `status_resisted` and `monster_released`.
- Every status source puts a status on through `Monster.try_status(status, seconds, source)`, which reads the tier table: the spell now, a bear trap or anything else later.
- **Test room:** the "Held monster" station (a skeleton, a skeleton guard and a slime); 9 holds the monster in front without a roll or mana, 0 frees every held monster.

## Monster tiers

Every monster has a tier (`MonsterDef.tier`), and every status effect reads one table by it: `data/tiers.tres` (`scripts/monster_tiers.gd`). **Rule of thumb: on tier 1 a spell almost always works; on tier 4 it is a gamble.**

| Tier | Meaning | Monsters |
|---|---|---|
| 1 | fodder | Skeleton, Slime, Acid Slime (and the rat, when there is one) |
| 2 | tough | Skeleton Guard |
| 3 | elite or mini-boss | none yet (the floor 1 mini-boss, when it is built) |
| 4 | boss | none yet |

The table, one row per status (chance to land, and the share of the status's time it lasts):

| Status | Tier 1 | Tier 2 | Tier 3 | Tier 4 |
|---|---|---|---|---|
| held | 90%, full | 65%, full | 35%, half | 15%, half |

- **Rows:** `rows["held"] = {"chance": [90, 65, 35, 15], "duration": [1.0, 1.0, 0.5, 0.5]}`. A new status (slowed, poisoned, a bear trap's snare) needs only a new row; a status with no row always lands in full.
- **Special cases:** `MonsterDef.status_overrides`, per status id: any of `chance`, `duration` and `message`. The slimes use `{"held": {"duration": 0.75, "message": "The {monster} quivers against the runes."}}`. `chance` 0 makes a monster immune.
- **Wall monsters** are immune to every status.
- **One way in:** `Monster.try_status(status, seconds, source)` rolls the table with the combat dice and returns `landed`, `resisted` or `immune` with the time it got; a resisted try plays the status's ending effect. Hold Monster calls it; a bear trap must call it too.
- The `boss` flag no longer changes a status (tier 4 does that); it still gives the wide named health bar.
- The test room's spawn list (V) shows each monster's tier ("SKELETON  T1").
- Hold Monster stays at 5 mana and a 12 s recast wait for now, to be judged in play now that fodder is held 90% of the time.
