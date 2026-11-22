# Combat design

The combat rules, including critical hits and critical fails, live on one page, so there is a single copy to keep up to date:

https://claude.ai/artifact/BGAw8C4bkJfdBrSScE49yY

See the "Critical hits and fails" and "Hits from behind and the sides" sections. The maths is in `scripts/combat_rules.gd`, the tunable feedback in `data/combat_feel.tres` and the lines in `data/banter.json`.

## Equipment rules

- **Mages can't wear armour, only robes. This is intentional.** It is set per item with `ItemDef.cant_use` (a list of class ids): Leather Armour lists "mage", so any armour added later must list it too unless it is cloth made for casters. **The Wool Robes** (`data/items/threadbare_robes.tres`, found in room 5 on floor 1: +1 defence, a light armour against the leather's +2) list "fighter" and "thief" instead, so the Mage and the Cleric may wear them and the fighters may not. The inventory slots and portrait-click equipping both refuse with "The mage can't wear that." (and likewise for the fighter and the robes.)
- **Only a caster holds a spellbook or holy symbol.** A FOCUS goes in a hand only if its `magic` matches the hero's `CharacterDef.magic` (the spellbook the Mage, the holy symbol the Cleric; `Party.can_equip`). The Fighter and the Thief can carry one in a backpack but not hold it: "Brannoc can't make use of the spellbook." The inventory hands, the party panel's hands and the loot pop-up ("can't use") all follow it.
- Armour or a weapon on the cursor, clicked onto a portrait, equips it (armour slot, or the main hand). Shift-click on floor armour equips it on the hero who gains the most defence.

## Monster pacing: the step-back dance

The aim is the Eye of the Beholder dance: step back or sidestep and get a free swing or a breather, instead of monsters closing the gap at once and surrounding the party. Code: `scripts/monster.gd` ("Movement AI" and `_fight`). Numbers: each monster's `MonsterDef` ("Movement and pacing" group in `data/monsters/*.tres`) and the shared `data/monster_ai.tres`. Tune by feel in the test room's **Monster pacing** station (T to teleport; ; (semicolon) spawns a pack, O picks a value, [ and ] lower or raise it on every kind at once, Y resets; the H overlay shows the table; nothing is saved, so copy what feels right into the `.tres` files).

**What was wrong (2026-11-13):** monsters stepped every 0.8 s (slimes 1.0 to 1.14 s) on a free-running timer at a random phase, so after the party stepped back the next move came 0 to 0.8 s later, about 0.4 s on average, with no reaction beat. Adjacency counted from the *start* of their 0.3 s step, so the wind-up was already running while they slid in (the guard began its swing 0.18 s after it arrived). Chasing was greedy per axis: a monster blocked by another sidestepped onto the diagonal and then into the tile beside the party, so every extra monster took another side.

| | Step interval | Reaction delay | Arrival recovery | Wind-up | Flank after |
|---|---|---|---|---|---|
| Party (for comparison) | 0.2 s a tile | | | | |
| Skeleton | 1.2 s | 0.5 s | 0.5 s | 0.5 × 2.0 s = 1.0 s | 3.0 s |
| Skeleton guard | 1.1 s | 0.4 s | 0.5 s | 0.5 × 1.8 s = 0.9 s | 2.5 s |
| Slime | 1.6 s | 0.6 s | 0.6 s | 0.5 × 2.5 s = 1.25 s | 3.5 s |
| Acid slime | 1.5 s | 0.6 s | 0.6 s | 0.5 × 2.2 s = 1.1 s | 3.5 s |
| Plague rat | 0.7 s | 0.3 s | 0.3 s | 0.4 × 1.4 s = 0.56 s | 2.0 s |

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

## Mana

Mana comes back at **1 point per 6 seconds** (`Party.MANA_REGEN_TIME`), always, in or out of a fight. It was 1 per 2.5 s until 14 Nov 2026.
At that rate the Cleric healed about 7 HP every 10 seconds for ever, so potions, food and (later) a campfire all lost to standing still.
Now a Heal (4 mana) takes 24 s to come back, a Fireball (6) 36 s, a full Cleric (10) a minute and a full Mage (12) 72 s. Waiting is
still allowed; it costs torchlight. No spell's cost changed. To be judged in play: the Mage gets two Fireballs a fight, not three; if he
feels weak, raise his mana from 12 to 14 before touching the rate. Reasons and the wider budget: `docs/design/expansion_design.md` section 2.

## The Cursed Warden (floor 1's mini-boss)

`data/monsters/warden.tres`, at (20,22): the one-tile corridor before the stairs, behind the locked door. Tier 3, a boss bar with his name.

| HP | Attack | Defence | Damage | A blow every | A step every | Sight |
|---|---|---|---|---|---|---|
| 80 | 5 | 4 | 3-9 | 2.0 s | 1.3 s | 8 tiles |

- **The budget (tier 3):** a fight of 12 to 18 s that costs a quarter to a third of the party's HP. A party with a long sword, a mace, darts and Magic Missile does about 5 to 8 damage a second, so 80 HP is about 14 s; he does about 1.7 to 2.0 a second to the front row. The parked version had 40 HP, which a level 3 party kills in six seconds.
- **Hold Monster:** 35%, for 2.5 s (the tier table).
- **Bear trap:** always holds him, for 1.5 s, but **only once a fight** (`MonsterTiers.trap_once_from_tier` 3; `trap_field.gd` forgets when `GameEvents.fight_ended` fires). A second trap in the same fight bites for its damage and he tears free. So two traps in his corridor are not a stun lock.
- **Banter:** `boss_seen` the first time he sees the party (Thief: "He's bigger than the others." Fighter: "Good."), and a line when he falls (Cleric: "I softened him up." Fighter: "With what?"). Both once a run.
- **Art:** the user's PixelLab "hardcore warden" (21 Nov 2026): a horned warden in spiked red and black plate with a tall axe and chains, animated with PixelLab clips (idle 5, attack 6, walk 8 frames) and a hurt made in code (a lean back and a flash), 128x128 frames (`tools/art/gen_warden_hd.py`). The axe's slam is attack frame 3 (`attack_hit_frame` 3). The old single-pose placeholder (`gen_warden.py`) is no longer built.
- **Not built yet:** he does not carry the Unquenchable (7g), and his hall's sconces are not special (7l.2).

## The Red Shaman and ranged attacks

A monster with `MonsterDef.ranged_range` above 1 casts at the party from up to that many tiles away along a clear straight line (the same row or column, nothing in the way). The first caster is
the Red Shaman (`data/monsters/red_shaman.tres`, a goblin in a red hood with a skull staff): tier 2, 9 HP, attack 3, defence 1, damage 2-5, a bolt every 2.4 s, notices the party from 6 tiles.

- **Behaviour:** it walks toward a firing line (in line with the party, 2 to 4 tiles away, in sight) rather than the party's side, stops there and casts; at point blank it casts too. Anything in the way
  (a wall, a closed door) means no shot; a portcullis does not block it.
- **The bolt:** a crimson orb leaves on the cast animation's hit frame (`attack_hit_frame` 3) and flies 0.07 s a tile; the damage lands when it arrives, rolled like any monster blow (hit chance, crits,
  hit direction, the red flash and a bolt-burst `hit_effect` across the view). A shaman killed while the bolt is in the air takes it with him.
- **Where:** floor 1, at (18,14) in the long corridor south of door (18,10), four tiles from the door; also the test room arena.
- **Not built:** he has no drop and no banter, and keeps no distance (he does not back off from a party that closes in).
- Art: PixelLab (see `docs/asset_log.md` "The Red Shaman").

## Reach: the Goblin Halberdier

A monster with `MonsterDef.ranged_range` of 2 and no `bolt_effect` has a **polearm's reach**: it can strike from the next tile or from exactly two tiles away on the party's row or column with a clear line (a wall or closed door stops it; a portcullis does not). The Goblin Halberdier (`data/monsters/halberdier.tres`) is the first: tier 2, 11 HP, attack 4, defence 3, damage 2-5, a stab every 2.0 s.

- **Behaviour:** he heads for a tile two away in line with the party and stops there, stabbing; he does not close in while he can strike. A hero in the front row cannot hit back at two tiles (melee reaches one): the answer is to close in, throw something, shoot or cast.
- **The blow:** nothing flies; the damage lands a moment after the stab (0.05 s a tile), rolled like any monster blow, with the usual flash, direction and hit effect.
- **Not built:** he does not keep his distance: a party that closes to the next tile is stabbed from there too.

## The Bone Spider's web

A monster with `MonsterDef.web_range` above 1 (the Bone Spider, `data/monsters/spider.tres`: range 4) can spit a web. It does so instead of closing in whenever it has a clear straight line (the same row or column, nothing in the way) to the party from 2 to 4 tiles away and its web is ready:
the first web at first sight, then one every 10 seconds (`web_interval`), never while the party is already stuck in one, and never while the spider is held.

- **Spitting:** the spider plays its attack animation and the web leaves on that animation's impact frame, flying 0.09 s a tile. A spider that dies, or a party that steps out of line, before it leaves means no web; a spider that dies while it flies takes it with it.
- **Landing:** the party is pinned for `web_seconds` (3 s): **no stepping, forward, back or sideways** ("You are stuck fast in the web."), but turning, attacking, throwing and casting work as usual. A web already on the party is not lengthened and does not restart. It is not saved; a camp cannot be made while stuck, and a web never lands on a party that is camping.
- **Feedback:** "Webbing pins the party in place." and later "The webbing tears loose.", the sounds `web_spit` and `web_stick`, and a web laid over the 3D view that blinks off just before it ends (steady and then gone with Reduce flashing).
- **Why it matters:** it takes away the step-back dance: the spider webs you down a corridor and closes while you cannot back off. A bear trap set in front of you still works on it.
- **Not built:** no banter for it yet, no way to cut free early (fire or a weapon), and only the spider uses it.

## Monster tiers

Every monster has a tier (`MonsterDef.tier`), and every status effect reads one table by it: `data/tiers.tres` (`scripts/monster_tiers.gd`). **Rule of thumb: on tier 1 a spell almost always works; on tier 4 it is a gamble.**

| Tier | Meaning | Monsters |
|---|---|---|
| 1 | fodder | Skeleton, Slime, Acid Slime, Plague Rat |
| 2 | tough | Skeleton Guard |
| 3 | elite or mini-boss | The Cursed Warden |
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
| Snap | the first monster to finish a step onto it | 1-3 damage (`trap_damage`, the setter named as the killer), then held for 3 s (`trap_status` held, `trap_seconds`) through `Monster.try_status` on the tier table's `trap` row: nothing gets past it (100% at every tier, changed from 95/83/68/58% on 14 Nov 2026; tiers 3-4 are held half the time). A monster of tier 3 or more is held only once a fight; a second trap bites and it tears free. "The trap snaps shut on the skeleton." Starts a fight |
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

## The plague rat

`data/monsters/plague_rat.tres`, tier 1: 5 HP, attack 2, defence 1, damage 1-3, a blow every 1.4 s, a step every 0.7 s (the fastest thing on the floor), sight 4, fears fire (a torch's hit makes it recoil, like the slimes). Caught by a bear trap and held like anything else (it does not ooze). Three nest in the cave at (8,17), (7,18) and (8,18).

- **The bite:** a landed blow has a 20% chance of the food sickness: 6 HP over 6 s, never kills (`MonsterDef.sick_chance`, `sick_damage`, `sick_seconds`; rolled in `Party.take_hit_from`, and only for a monster that has a chance, so every other fight's dice are untouched). The log adds "The bite festers: {name} feels sick."
- **What it leaves:** raw rat meat 40% of the time (`data/items/raw_rat_meat.tres`): 6 HP over 6 s, and 50% of the food sickness. Cooking it (12 HP over 6 s, no sickness) belongs to resting (7h), which does not exist yet.
- **Art:** PixelLab picture, four animations and its own hit effect (`rat_bite`); see `docs/asset_log.md`.

## Monster hit effects

When a monster's blow lands, its own effect plays across the 3D view with the red flash, so you feel what hit you (feedback only, no rule changes). Each monster names one (`MonsterDef.hit_effect`, a PixelLab VFX sheet in `art/spells/hit_fx/`); a monster with none gets the red flash alone.

| Monster | Effect |
|---|---|
| Skeleton (unarmed) | `skeleton_claws`: three bloody claw rakes |
| Skeleton Guard (axe) | `guard_axe`: a heavy crescent axe swing with sparks |
| Slime | `slime_splat`: a wet glob slapping across and dripping off |
| Acid Slime | `acid_splat`: the same in its sicklier acid green, the other way round |
| Plague Rat | `rat_bite`: two rows of fangs snapping shut, with a few drops |

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

- **Wall sconces** (roadmap 7l.2; `DungeonMap.TORCHES` entries are `Vector4i(x, z, side, state)`, run state `sconce_state` / `sconce_seconds` /
  `sconce_seen`, saved under the dungeon's `sconces`): every wall torch is **lit**, **unlit with a torch** or an **empty bracket**. Floor 1 has 8,
  7 and 10 (the lists in `docs/design/expansion_design.md` section 2), the test room's light room two of each dark kind and a lit one.
  *Light an unlit one:* right-click it (the wall in front) with a lit torch or candle in a hero's hand ("Brother Felix lights the sconce."), or
  cast a Fireball at it (aimed down a corridor that ends in an unlit sconce, or any blast within a tile of one). It stays lit and nothing is used up.
  *Take the torch* (lit or unlit): left-click with an empty cursor. You get a torch with the time it has left (120 s, `LightConfig.sconce_torch_seconds`,
  for one the level started with) and the bracket is empty, its stretch dark. *Hang a torch:* left-click an empty bracket with a torch on the cursor
  (`ItemDef.fits_sconce`, the torch only): it lights that stretch for good, keeps the time it had (a fresh torch 240 s) and **loses none while it hangs
  there**; taken out it has that same time. **Torches are never made:** a sconce holds one real torch or none, taking it empties the bracket, and lighting
  one needs a flame it does not use up, so light, take, hang, take is a closed loop (smoke checks add up every torch-second in the game). The map shows a
  sconce once the party has seen it (a clear line within `sconce_see_range` 6), gold if lit, grey if unlit, dark if bare. A thrown torch lighting one
  A lit torch thrown so that it lands beside one lights it the same way (7l.4: `LightField` keeps the landed torch burning, `Dungeon.ignite_near`).
- **Curse zones** (roadmap 7l.3; `DungeonMap.CURSE_ZONES` = `{"id", "tiles"}`, the node `scripts/curse_zones.gd`, numbers in `data/light.tres` "Curse
  zones"): a place where flames die. In one (outside a Bless's pocket): a **held torch or candle sputters for a second** (the light flickers hard) **and goes
  out**, burning no time, and relights the moment the party leaves; put away and taken up again inside, it sputters again. A **sconce will not light** (right
  click: "The air here hates fire."; a torch hung in a bare bracket there stays unlit; a lit one goes out; **this reaches 2 tiles past the zone's tiles** (`sconce_reach`, as far as the haze looks), so the wall torches along its edge go dark too, and so does every other light fixed in the world there: the candle in a wall niche (its picture swaps to `art/decals/niche_out.png`, a flame-less one made by `tools/art/gen_niche_out.py`, and its light is hidden) and a burning torch lying on the floor: `DungeonMap.curse_zone_near`, `Dungeon.sconce_blocked` / `light_blocked`; **held flames** still only die on the zone's own tiles, so the party can walk up to the haze with its torch), a **burning torch lying or thrown there goes out**
  (`LightField.drop` fizzles it, cold, with its time) and **oil** and braziers (not built) ask `Dungeon.flame_blocked(cell)`. `ItemDef.curse_proof` (the
  Unquenchable, not built) and spell light are untouched. **Bless makes a pocket:** `SpellDef.pocket_seconds` 20, the tile the party stood on and the tiles
  beside it (`zone_pocket_radius` 1): flames light and live there; when it ends whatever still burns inside goes out. **Nothing is said until a flame dies**,
  then "The air here hates fire." (and a banter remark, event `flames_snuffed`). **The look is "it eats light", not poison gas** (`docs/art_style.md`: curse green, but darker and murkier): a murky **fog**
  (PixelLab VFX, `art/spells/curse/fog_sheet.png`, normal blending so it darkens the floor, unshaded, two patches a tile, a little wider than the tile) that
  **creeps in from the zone's edges** (`fog_creep_seconds` 6: the tiles beside open floor fill first, the middle last), swells round the party while a held
  flame sputters, and a flame that dies in the world leaves a **wisp** curling up (`art/spells/curse/wisp_sheet.png`, `wisp_seconds`). A flame in a hand
  **bends and gutters** (drops out now and then) with a wisp curling round it during its second (`party_hud._gutter_flame`). **The edge glow**
  (`curse_vignette.gd`, `shaders/curse_vignette.gdshader`, over the view, under the frame): a slow yellow-green vignette in stepped, dithered bands (never
  a smooth ramp, never red or sharp, so never the damage flash) that creeps in over `vignette_in_seconds` 3.5 while the party stands in a zone, starts at
  `vignette_min` and **thickens the longer it stays dark** (full after `vignette_full_seconds` 40), and breathes gently (`vignette_pulse`, `_hz`).
  **A Bless's pocket**: the fog shrinks and slides off the pocket's tiles in `fog_recoil_seconds` 0.7, the glow pulls back in `vignette_pull_seconds`, and
  for the last `pocket_warn_seconds` 4 both creep back as a warning (the glow to `vignette_warn` 0.5), the fog fully a couple of seconds after. **Reduce flashing**:
  one still fog frame, no flicker, and a steady vignette with no breathing. Every strength, colour and time is in the "Curse zones" group of `data/light.tres`. A puzzle effect `clear_curse_zone` lifts a zone
  for good (the run flag `curse_zone.<id>.cleared`, saved). `GameEvents.entered_curse_zone` / `left_curse_zone` (banter lines for both). **Nothing above tier 1
  may be placed in a zone:** the builder warns when the level loads (`DungeonMap.zone_tier_violations`). Floor 1 has the cave's (over x 6-10, y 15-19
  and lifting when its three rats die; a zone's reach (2 tiles) stops at walls); the test room's light room has one over its east end and the backslash key lifts it or puts it back.
- **Fighting in the dark** (roadmap 7l.6): a hero's weapon blow (swing, throw, shot) has -10 percentage points to hit when no light reaches the party's tile beyond the ambient (`Party.tile_is_lit`: the party's own light, a wall torch or floor flame with a clear line, a spell's glow). Spells and monsters are unaffected.
- **Throwing a torch** (roadmap 7l.4; `ItemDef` torch `throw_damage_min/max` 1-3): **shift+click the hand** that holds a lit torch (`Party.act(slot, hand, true)`:
  a plain click still swings it, and shift+click also throws a dagger from the front row; a quick slot still swaps a light into a hand). It flies up to 4 tiles
  (`MISSILE_RANGE`, the thrown-weapon code `_do_throw`) with its light (a light rides the flying sprite, `Dungeon.show_throw`), the usual hit roll,
  and on a hit does 1-3 **fire** (a crit may double it; `result.fire`: a doused monster takes the +6 and burns), and a monster that `fears_fire`
  recoils from it. It then **burns where it lands** (`LightField.drop`, the same node that keeps a slipped torch burning: it keeps the burn time it had,
  never merges into a pile, lights a slick it lands on, and is put out at once by a curse zone, or its 2-tile reach, and can then be picked up cold).
  Monsters that fear fire will not step onto its tile (`Dungeon.fire_at`). **Picking it up sends it home** to the hand it left like any thrown piece
  (`ItemStack.origin`, `Party.return_to_origin`: a lit torch in a hand is lit). **A candle cannot be thrown** (no throw damage). A torch snuffed in a
  curse zone is thrown cold.
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

## Oil and fire

Roadmap 7l.5; the numbers are in `docs/design/expansion_design.md` section 2 and live in `data/light.tres` ("Oil"), the code is `scripts/oil_field.gd`
(the node "Oil", `Dungeon.oil`), `Party._throw_oil` / `_oil_weapon` / `burn_party`, and `Monster.take_hit`.

| | Number |
|---|---|
| Flask of oil (`data/items/oil_flask.tres`, `ItemDef.is_oil`) | Stacks to 3. A quick slot or a hand takes it; clicking it throws it |
| Oil slick | Lasts until lit or 120 s (`slick_seconds`) |
| Burning tile | 6 s (`burn_seconds`); 2 fire a second to a monster on it, 1 a second to each hero when the party stands on it (source `"fire"`); a light of energy 1.2, range 6 in the `sprite_lights` group |
| Doused monster | 30 s (`doused_seconds`); the next fire that touches it does +6 and sets it burning: 2 a second for 3 s (status `burning`) |
| Oiled weapon | The next 3 landed melee hits do +2 fire (`oiled_hits`, `oiled_bonus`) |

- **Throwing.** A hand or quick-slot click throws a flask (`Party._throw_oil`, the hero's action cooldown, one flask spent). **At a monster in line**
  (within `MISSILE_RANGE` 4): it bursts on it and the monster is DOUSED (`try_status` on the tier table's row `doused`: 100% at every tier, slimes and
  the Warden included; a wall monster is immune, "The oil runs off"). **Otherwise it is thrown AT THE FLOOR: it always lands on the tile in front, never
  under the party**, and leaves a slick there (more oil on a slick makes it a fresh 120 s). Refused, and nothing spent, with no room to throw or while
  **the party stands in a curse zone** ("The air here hates fire. The flask stays corked."). The splash is a PixelLab VFX (`art/spells/oil/burst_sheet.png`).
- **Lighting a slick** (`OilField.ignite`, the news `GameEvents.oil_ignited(cell)`, "The oil catches!" if the party sees it): **a Fireball** (its blast lights
  every slick within a tile of where it lands, `spell_effects.explosion`), **a lit torch's swing at that tile** (`Party._melee`: hit or miss), and **a burning
  torch lying on it** (a slipped one, or one thrown there: `LightField.drop`; a thrown torch does exactly that). A slick in a curse zone will not catch,
  and neither will a doused monster there.
- **A burning tile** shows PixelLab flames (`art/spells/oil/flames_sheet.png`) and lights its surroundings for 6 s. Each second it does 2 to a monster
  standing on it (a doused one catches and takes +6) and 1 to each hero if the party is on it; someone remarks on the party's own fire (banter
  `walked_into_fire`). **Monsters that fear fire** (slimes, acid slimes, plague rats) **will not step onto a burning tile or a tile with a burning
  torch** (`Dungeon.fire_at`, `Monster._can_enter`): a one-wide corridor with a burning tile is a wall to them for 6 s. Intended: it is what oil is for.
- **Doused** (`data/statuses/doused.tres`, no effect of its own but a darker tint) **and burning** (`data/statuses/burning.tres`: 2 a second, flames on the monster)
  are `StatusDef`s with rows in `data/tiers.tres`. A hit counts as FIRE when it carries `fire: true`: a Fireball (`SpellDef.fire`), a torch's flame, oil on a
  weapon, or standing in burning oil. Fire on a doused monster: +6 damage, `doused` ends, `burning` begins; fire on a plain monster does only its own damage.
- **Oil on a weapon:** use a flask on a hero (the inventory's shift+right-click: `Party.use_item` -> `_oil_weapon`, which needs a weapon in a hand and
  refuses a second coat): the next 3 landed melee hits do +2 and count as fire (so they light a doused monster). Saved per hero (`oiled`).
- **The trap combo:** a monster held by a bear trap on a slick can be lit and takes 2 a second while it burns; with a Fireball on a doused Warden that is
  about 20 damage (+6 and the burning) for one flask, one trap and 6 mana. Intended: the best trick in the game.
- **Saving:** slicks and burning tiles (with the time left) are saved under the dungeon's `oil`; doused and burning monsters ride on their `statuses`;
  an older save has none.

## Making camp

Roadmap 7h.2 (the numbers are in `docs/design/expansion_design.md` section 2 "Resting"). Interrupted rests, cooking and banter are 7h.3 to 7h.5.

- **Making camp.** One **Bedroll** (`data/items/bedroll.tres`, `ItemDef.makes_camp`, a consumable that stacks to 3) used from a hand, a quick slot or the
  pack, if `Party.camp_refusal()` says "" (the log says why not and nothing is spent): not in a fight (`Party.fight.in_fight`), no living monster within
  4 tiles (a square, `CAMP_MONSTER_REACH`) or in sight within 12 (`CAMP_SIGHT_REACH`), no armed ambush trigger within 2 (`CAMP_AMBUSH_REACH`;
  `DungeonMap.ambush_trigger_near`). There is no tinderbox.
- **The rest** (`scripts/camp.gd`, group `camp`, canvas layer 3 over the 3D view): the view is covered by a near-black camp screen round a small fire with
  a bedroll for each hero (portrait on the pillow, name, HP and mana bars). For 30 s (`REST_SECONDS`) every living hero's HP (whole points) and mana climb
  evenly from where they began to full. The dead are not raised. The corner map is hidden meanwhile.
- **It ends** at 30 s, by the STOP RESTING button, by any step or turn (`Player.command` asks `Camp.consumes_move`; the key that did it goes no further and
  a held key stays spent for 0.35 s) or when a fight starts (`GameEvents.camp_ended(true)`). Everything gained is kept. **A camp that ends by itself or by
  Stop saves the game** (`SaveGame.save`; refused in the test room and built levels, quietly). An interrupted one does not.
- **Beginning a camp also:** clears the Cleric's "shaken", everyone's sickness and their spell recasts, gives the rest of a running meal's healing at once,
  and starts `Party.camping`: burn timers stop (held lights `_tick_lights`, lights lying burning `light_field.gd`), meals and the slow mana regeneration wait.
- **Bedrolls** are buttons: a click opens that hero's pack and character sheet (`inventory.show_screen`, which pauses the game and so the camp). A hero who can
  level up will say so on their bedroll once levelling exists (`Party.level_up_ready`, Phase 7i: nothing yet).
- **Camp spots** are STRUCTURES entries `{"cell", "kind": "camp_spot"}` (old ash on the floor, `art/camp/ash.png`; `DungeonMap.camp_spot_at`). They carry no rule yet:
  the interruption chances (3% at a camp spot, 6% in a dead end, 12% in the open, rolled at 10, 20 and 30 s) are 7h.4. The map symbol for a camp spot is not drawn yet.
- **Cooking** (7h.3): while camped, food whose `ItemDef.cooks_into` is set can be cooked: the **COOK (n)** button cooks every such stack the party carries (hands, packs, quick slots, the fallen's too), one stack every 0.8 s, each with a sizzle (`art/spells/cooking/sizzle_sheet`, a PixelLab VFX burst of sparks and smoke, and `audio/sfx/sizzle.wav`) and a log line ("Wren cooks the rat meat."); or hold the food on the cursor and click the fire. A cook burns the food 15% of the time (the line "Wren burns the rat meat. Nobody mentions it.", the same result). Cooking keeps the count. What it makes: **raw rat meat** (6 HP over 6 s, 50% sickness) becomes **Cooked Rat Meat** (12 HP over 6 s, none); **mouldy bread** (6 HP over 8 s, 35% sickness) becomes **Toasted Bread** (9 HP over 4 s, none). Nothing else is cookable yet: another food is made cookable by giving it a cooked item and a `cooks_into`. `GameEvents.food_cooked(def, hero)`. Cooking needs a camp (the button and the fire exist only on the camp screen).
- **News:** `GameEvents.camp_made` and `camp_ended(interrupted)`. Test room: the camp survival station (T "Campfire"): bedroll in front, ash on the spot, a 3D camp
  (`camp_site.gd`) and the keys `,` (wound, drain and sicken the party) and `.` (make camp without bedroll); the H overlay shows `CAMP MAY CAMP` or why not.

