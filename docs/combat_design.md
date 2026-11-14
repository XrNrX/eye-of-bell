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
| trap (a bear trap's hold) | 100%, full | 100%, full | 100%, half | 100%, half |

- **Rows:** `rows["held"] = {"chance": [90, 65, 35, 15], "duration": [1.0, 1.0, 0.5, 0.5]}`. A new status (slowed, poisoned, a bear trap's snare) needs only a new row; a status with no row always lands in full.
- **Special cases:** `MonsterDef.status_overrides`, per status id: any of `chance`, `duration` and `message`. The slimes use `{"held": {"duration": 0.75, "message": "The {monster} quivers against the runes."}}`. `chance` 0 makes a monster immune.
- **Wall monsters** are immune to every status.
- **One way in:** `Monster.try_status(status, seconds, source, row)` rolls the table with the combat dice and returns `landed`, `resisted` or `immune` with the time it got; `row` lets a source use its own row (the bear trap's `trap` row). A resisted try by a spell plays the status's ending effect. Hold Monster and the bear trap both call it.
- The `boss` flag no longer changes a status (tier 4 does that); it still gives the wide named health bar.
- The test room's spawn list (V) shows each monster's tier ("SKELETON  T1").
- Hold Monster stays at 5 mana and a 12 s recast wait for now, to be judged in play now that fodder is held 90% of the time.

## Bear trap

**Rusty Bear Trap** (`data/items/bear_trap.tres`, item type TRAP, stacks to 2; `scripts/trap_field.gd`, the node "Traps" in the
dungeon). Every number is on the item ("Trap" group) and the tier table's `trap` row.

| | Value | Notes |
|---|---|---|
| Setting | 1.5 s (`set_seconds`) | Click the trap in a hand or a quick slot, or drop it from the cursor onto the tile in front (then the living hero who sets traps fastest does it: the Thief): it is set on the tile in front. The hero is busy for that long (their action cooldown); the Thief takes half (`CharacterDef.trap_set_time` 0.5). If the party moves or turns away, or the tile stops being free, the trap is left lying there unset |
| Where | an empty floor tile | Not a wall or door, the stairs, a pressure plate, a monster, a tile with items on it, or another trap. Refused with a line, nothing spent |
| Armed | lies open on the floor | `ItemDef.armed_icon`, unshaded and tipped slightly up so it reads from eye height. The party steps over it safely ("Brannoc steps carefully over the trap."). Clicking it in front with an empty hand picks it back up, disarmed |
| Snap | the first monster to finish a step onto it | 1-3 damage (`trap_damage`, the setter named as the killer), then held for 3 s (`trap_status` held, `trap_seconds`) through `Monster.try_status` on the tier table's `trap` row: nothing gets past it (100% at every tier, changed from 95/83/68/58% on 14 Nov 2026; tiers 3-4 are held half the time). "The trap snaps shut on the skeleton." Starts a fight |
| Slimes | ooze through | Their `status_overrides.trap` is chance 0: no damage, no hold, the trap stays armed. "The slime oozes through the trap." |
| Wall monsters | never trigger it | They never step, and are immune anyway |
| After | closed on the tile | It lies there as an ordinary item (its floor icon is the closed trap) to pick up and set again, unless its spring snaps (`break_chance` 10%): "The trap's spring snaps." and it is gone |

- **Why these numbers:** the trap is a cheap, slow, one-tile ambush. Setting it costs a hero's action for 1.5 s, so it is set before a fight, not in one; the Thief, the party's trapper, does it in 0.75 s. It holds for 3 s, less than Hold Monster's 5 s, but it costs no mana and has no recast wait, and nothing resists it (it is a steel jaw, not a spell). The 10% chance to break keeps two traps from lasting a whole floor.
- **News:** `GameEvents.trap_triggered(trap, monster)` (the trap's ItemDef). Not sent when a slime oozes through.
- **Saving:** armed traps, their tiles and who set them are saved under `dungeon.armed_traps` (one being set is saved as set); a closed trap is a floor item, saved with the piles. An older save has none.
- **Look:** PixelLab art: the inventory and closed-floor icon, a 32x32 hand icon, the open trap (`art/items/bear_trap*.png`), and a VFX snap of iron jaws biting shut with sparks and a spatter (`art/spells/bear_trap/snap_sheet.png`, drawn normally, not added, because the jaws are dark iron), with a small screen shake. Sounds `trap_set` and `trap_snap` (`gen_sounds.py`).
- **Banter:** `trap_triggered` when it holds (Fighter: "Ha. Stay.", Cleric: "Crude. But effective."), `trap_broke` (Thief: "Typical.").
- **Where:** floor 1 has two lying about: beside the long corridor near the start, whose skeleton chases you (7,11), and in the east corridor above the skeleton guard (18,14). The test room has one on the item table and the Traps station (one armed, one to pick up, and a skeleton to lure onto it).
- **Not built:** traps that catch the party (hidden traps, detecting, disarming); monsters do not avoid armed traps.

## Monster hit effects

When a monster's blow lands, its own effect plays across the 3D view with the red flash, so you feel what hit you (feedback only, no rule changes). Each monster names one (`MonsterDef.hit_effect`, a PixelLab VFX sheet in `art/spells/hit_fx/`); a monster with none gets the red flash alone.

| Monster | Effect |
|---|---|
| Skeleton (unarmed) | `skeleton_claws`: three bloody claw rakes |
| Skeleton Guard (axe) | `guard_axe`: a heavy crescent axe swing with sparks |
| Slime | `slime_splat`: a wet glob slapping across and dripping off |
| Acid Slime | `acid_splat`: the same in its sicklier acid green, the other way round |

- **Placement:** centred for a blow from the front, towards that edge for the left or right (mirrored for the right), low for behind, matching the direction glow.
- **Crits** play 35% bigger and hold their strongest frame 0.12 s longer. **Misses** play nothing, so a landed hit always reads.
- **Reduce flashing:** 75% size, 1.5 times as fast.
- **Code:** `scripts/hit_overlay.gd` (node `HitOverlay` in `main.tscn`, canvas layer 2, above the view and under the frame), fed by `Party.monster_struck(monster, side, damage, crit)`. Numbers in the "Hit effects" group of `data/combat_feel.tres`. Frames step, no alpha fades.
- **Test room:** the minus key plays the next monster kind's effect, cycling front, left, right and behind, without damage.

## Light and darkness

Light is something the party carries (roadmap 7l.1). The always-on light that followed the party is gone: a torch or a candle takes up
a hero's hand, so lighting the way costs a weapon, a focus or a backup, and who carries it is a choice. Every number is in
`data/light.tres` (`scripts/light_config.gd`) or on the light's own item (`ItemDef` "Light" group).

**The dark.** A faint cold ambient, "eyes adjusted" (`ambient_color` (0.17, 0.18, 0.25), picked from before-and-after shots on
14 Nov 2026): the nearest walls and a silhouette can be made out, nothing more. Everything else is the wall torches and what the party
holds. Monsters, floor items, armed traps and levers are tinted by the light that reaches them (`sprite_lighting.gd`: each light in
range whose tile can see theirs adds its colour x energy x (1 - distance / range) ^ falloff), never below `sprite_min_light` 0.35, a
cold dim silhouette that still reads (the art style's readability rule). They stay unshaded sprites: Godot lights a billboard sprite from
behind, so a lit sprite in front of a torch-bearing party came out a silhouette lit by the wall torch beyond it.

| | Torch | Candle | Notes |
|---|---|---|---|
| Light | energy 1.6, range 9, falloff 1.5, the old party light's colour | energy 0.8, range 5, warmer | The party's light (`party_light.gd`, the Player's `Torch` node) shines as the brightest one held |
| Burns | 240 s (`burn_seconds`) | 600 s | Only while lit: held in a living hero's hand, or burning on the floor. The time left is on the stack (`ItemStack.burn_left`), so a light put away keeps it |
| Stack | 3 | 5 | Fresh ones only: a used light never stacks with fresh ones |
| Hand action | a weak swing: 1-2, -1 attack, +1-2 fire on a hit | a weak swing: 1, -2 attack | From the front row; the back row "can't reach" |

- **Holding:** a light works only in a hand, and it takes that hand. Several held: the brightest counts, plus 10% of it for each extra
  light, at most +20% (`extra_light_bonus`, `extra_light_cap`). A dead hero's light goes out (it neither shines nor burns).
- **Quick slots** take torches and candles. Clicking one puts it lit into a hand: the one already holding a light, else a free one, else
  the second hand. A single light swaps with what was there, which waits in the quick slot (so the next click brings the shield back and
  puts the light out, keeping its time); from a stack of several, one comes off and the hand's item goes into the backpack.
- **Running out:** in its last 15 s (`gutter_seconds`) the flame flickers hard and its hand bar blinks (not with Reduce flashing), then
  "{name}'s torch gutters out." and the stub is gone. A thin bar along the foot of the hand slot shows the time left; a PixelLab flame
  plays over the icon while it is lit.
- **Fire:** a torch's landed blow adds 1-2 fire damage. A monster with `MonsterDef.fears_fire` (both slimes; the rat when it exists)
  recoils: a swing it had started is lost, its next blow comes 1 s later (`recoil_delay`), and it backs off one tile if the tile behind
  it is free. "The slime recoils from the flame."
- **Critical fails:** a missed torch swing can slip like any melee weapon (half of the 8% fails): the torch rolls onto the tile in front
  still burning ("It rolls away, still burning."), and the light is there now, not with the party (`light_field.gd`, 70% of its
  energy). It burns down there; burned out on the floor it is gone. Picked up, it goes back to the hand it slipped from, lit again.
- **News:** `GameEvents.light_out(hero)` when a held light burns out; `light_changed(level)` when the party's light really changes (0 is
  dark, else the brightest's energy with the bonus), never as it flickers, never for a new run or while a save loads.
- **Saving:** each stack's burn time (`burn`) and whether it lies burning on the floor (`burning`); burning floor lights are lit again
  after a load. An older save has none (fresh lights).
- **Start:** the Cleric holds a lit torch and carries two candles in a quick slot.
- **Banter:** `light_taken` (the Cleric with a torch: "I am a priest, not a lamp."), `light_out` (the Fighter, in a fight: "Brilliant.").
- **Why these numbers:** a torch lasts about one long stretch of the floor, a candle about the floor but barely lights past the next
  tile, so a party in a hurry burns torches and a careful one walks by candle. The fire is a nudge (a slime backs off, it doesn't run).
- **Not built yet:** wall sconces, curse zones that snuff flames, throwing torches, oil, monsters that avoid fire (roadmap 7l.2-7l.6).
