# Eye of Bell: expansion design

A design pass over everything still to build on floor 1: ambushes (7d), puzzles (7e), legendaries (7g), resting (7h),
levelling (7i), fallen adventurers (7j), what is left of the bear trap (7k.2) and of light and darkness (7l), and the
character generator (8b). No code was written for this. Written 14 Nov 2026 against commit `0462061`.

**How to read it.** Section 1 is the settled taste calls. Section 2 is the one numbers table every phase must obey.
Section 3 has a page per phase. Section 4 is what happens where two systems meet. Section 5 is where everything goes
on floor 1. Section 6 is the build order. Section 7 is replacement prompts to paste into the roadmap.

**Already built, so described as it is:** the bear trap (7k.2) and torches and candles (7l.1). Hold Monster, tiers,
monster pacing, banter and the loot pop-up are in too.

---

## 1. Decisions

The ten open questions (`docs/design/open_questions.md`) were answered "your picks" on 14 Nov 2026:

| # | Question | Decision |
|---|---|---|
| 1 | How scarce is light? | Only the first stretch stays lit. A careful party has light to spare; a careless one walks the last third by candle. |
| 2 | Does the dark cost anything in a fight? | Yes, a little: heroes with no light hit 10 points less often. Monsters are unaffected. |
| 3 | Can an ambush kill a hero? | A healthy party never loses anyone. A hero who walked in under half health can die. |
| 4 | The mini-boss | The Cursed Warden (parked on `wip/boss-ambush`) guards the stairs. The key room gets the giant hand. |
| 5 | Trap and Hold Monster on the boss | Both work, briefly: the trap holds him 1.5 s, once a fight. Hold Monster lands 35% of the time for 2.5 s. |
| 6 | Levelling on floor 1 | Level 3 at the stairs for most parties, 4 for thorough ones. Level 5 waits for floor 2. |
| 7 | Saving | Camping saves, and F5 and the pause menu keep working. |
| 8 | Legendaries on floor 1 | Grudge (mid-floor), Penitent's Mace, and the Unquenchable as the reward at the very end. |
| 9 | Character generator | The four heroes stay as the ready-made party. One of each class is required. No races for now. |
| 10 | Bellius | One trace: a note on a fallen adventurer. |

### What a first-time player meets today

Walking floor 1 in my head as a new player, at the current build:

- **The critical path is short.** Start, room 5 for the key, the long corridor, the east corridor, one guard, the locked
  door, the stairs. About eight minutes. The north-east rooms (2, 3, 7) hold every good weapon and are optional. The
  south-west rooms (6, 4, the cave) are only reachable from the stairs corridor, after the locked door, so most
  players never see them.
- **Nothing stops you at the stairs.** An acid slime and a guard stand there, the same as everywhere else. There is no
  mini-boss (roadmap Leftovers).
- **The dark does not bite.** 25 wall torches are all lit, so the new darkness only shows between them.
- **Healing is free.** Mana comes back at 1 point per 2.5 seconds, so the Cleric heals about 7 HP every 10 seconds for
  ever. Potions, food and (later) rest all compete with standing still. This is the one existing number that breaks
  the expansion, and section 2 changes it.
- **The Cleric's torch dies at minute four**, which is about when a new player reaches the long corridor. That is a
  good beat, and the plan below leans on it.

---

## 2. The shared numbers

One table for the whole game. A phase that needs a number takes it from here. **Changed** marks a number that
differs from the game today; **new** marks one that does not exist yet.

### Heroes (today, level 1)

| | HP | Attack | Defence | Speed | Bare hands | Mana | Seconds per action |
|---|---|---|---|---|---|---|---|
| Fighter | 30 | 4 | 4 | 3 | 2-8 | 0 | 1.55 |
| Cleric | 24 | 3 | 3 | 2 | 2-6 | 10 | 1.70 |
| Thief | 18 | 3 | 2 | 4 | 1-6 | 0 | 1.40 |
| Mage | 14 | 1 | 1 | 2 | 1-4 | 12 | 1.70 |

Party HP 86. Hit chance is 60 + 5 x (attack - defence), between 10 and 95. A party with a long sword, a mace, darts
and Magic Missile does about 8 damage a second in a burst and about 5 once the Mage is dry.

### Damage budgets per monster tier

"Cost" is the share of the party's total HP a fair fight with one of them should take from a party that plays it
straight (no trap, no Hold, no oil).

| Tier | What | HP | Damage a second at the front row | Fight lasts | Cost | XP | Trap | Hold Monster |
|---|---|---|---|---|---|---|---|---|
| 1 | Fodder: slime, acid slime, skeleton, plague rat, tentacle | 5-12 | 0.5-1.0 | 2-4 s | 2-5% | 10 | 100%, 3 s | 90%, 5 s |
| 2 | Elite: skeleton guard, giant hand | 18-36 | 1.3-1.7 | 5-9 s | 8-14% | 25 | 100%, 3 s | 65%, 5 s |
| 3 | Mini-boss: the Cursed Warden | 70-90 | 1.7-2.0 | 12-18 s | 25-35% | 150 | 100%, 1.5 s, once a fight | 35%, 2.5 s |
| 4 | Boss (floor 2 and later) | 150+ | 3.0+ | 30 s+ | 50%+ | 400 | 100%, 1.5 s, once a fight | 15%, 2.5 s |

Wall monsters (the giant hand) are immune to every status and never step, so neither the trap nor Hold touches them.

### Monsters

| Monster | Tier | HP | Attack | Defence | Damage | Seconds per blow | Notes |
|---|---|---|---|---|---|---|---|
| Slime | 1 | 6 | 1 | 0 | 1-4 | 2.5 | Fears fire. Oozes through traps. |
| Acid slime | 1 | 10 | 2 | 1 | 2-5 | 2.2 | Fears fire. Oozes through traps. |
| Skeleton | 1 | 12 | 3 | 2 | 1-6 | 2.0 | Drops stale bread 25%. |
| Plague rat (**new**) | 1 | 5 | 2 | 1 | 1-3 | 1.4 | Fast (a step every 0.7 s). Fears fire. A bite has a 20% chance of sickness (the food sickness: 6 HP over 6 s, never kills). Drops raw rat meat 40%. |
| Tentacle (**new**; parked data said 18 HP, 2-5) | 1 | 12 | 3 | 1 | 1-4 | 2.0 | Rooted to its tile. The party cannot leave while one is beside it. |
| Skeleton guard | 2 | 20 | 4 | 3 | 2-8 | 1.8 | Drops dried meat 30%. |
| Giant hand (**new**) | 2 | 36 | - | 2 | squeeze 2 every 1.5 s | - | In a wall. Grabs one hero; see 7d. |
| Cursed Warden (**changed** from the parked 40 HP, 4 / 3, 3-8, 2.2 s) | 3 | 80 | 5 | 4 | 3-9 | 2.0 | Sight 8. Carries the Unquenchable. |

The Warden went from 40 HP to 80 because a level 3 party kills 40 HP in about six seconds, which is a guard, not a
boss. At 80 he lasts about 14 seconds and costs a quarter to a third of the party's HP.

### Spells, mana and cooldowns

| Spell | Mana | Effect | Recast |
|---|---|---|---|
| Magic Missile | 3 | 2-6, never misses | - |
| Shield | 4 | +3 defence for 20 s | - |
| Hold Monster | 5 | Held 5 s (by tier) | 12 s |
| Fireball | 6 | 5-11, half to those beside the target | - |
| Heal | 4 | 4-10 HP | - |
| Bless | 5 | +2 attack for 20 s; purifies corruption; **new:** a 20 s pocket in a curse zone | - |

| | Today | Proposed | Why |
|---|---|---|---|
| Mana regained | 1 point per 2.5 s | **Changed: 1 point per 6 s** | At 2.5 s the Cleric out-heals every potion, meal and campfire by standing still for a minute. At 6 s a full Heal costs 24 s of waiting, and waiting burns your torch. A rest refills everything, so the campfire has a job. |
| Hero action | 2.0 - 0.15 x speed, at least 0.8 s | same | |
| Quick slot | 1.0 s | same | |
| Fumble | 8% of misses; half of those a slip | same | |

The mana change needs a playtest before it is kept: the Mage gets two Fireballs a fight instead of three. If he feels
weak, raise his mana from 12 to 14 before touching the regen again.

### Light

| | Light | Reach | Burns | Stack | Notes |
|---|---|---|---|---|---|
| Torch | 1.6 | 9 units (4½ tiles) | 240 s | 3 | Swing 1-2, +1-2 fire. |
| Candle | 0.8 | 5 units (2½ tiles) | 600 s | 5 | Swing 1. |
| Sconce torch (**new**) | as a torch | as a torch | 120 s once taken out | - | Does not burn down while it sits in the sconce. |
| The Unquenchable (**new**) | 1.8 | 10 units | never | 1 | Monsters notice the party 2 tiles further away. |
| Lit brazier (**new**) | 1.4 | 7 units | until snuffed | - | Does not move. |
| Burning oil (**new**) | 1.2 | 6 units | 6 s | - | |

| | Number |
|---|---|
| Extra lights held | +10% each, at most +20% |
| The dark | Ambient (0.17, 0.18, 0.25); sprites never below 0.35 |
| Fighting with no light on your tile (**new**) | Heroes: -10 to hit with weapons. Spells are unaffected. Monsters are unaffected. |
| A flame in its last seconds | Flickers hard for the last 15 s |

### Fire and oil (**all new**)

| | Number |
|---|---|
| Thrown torch | Flies up to 4 tiles; 1-3 fire on a hit; keeps burning where it lands |
| Flask of oil | Stacks to 3 |
| Oil slick | Lasts until lit or 120 s |
| Burning tile | 6 s; 2 fire a second to a monster on it, 1 a second to a hero |
| Doused monster | Lasts 30 s; the next fire hit does +6 and sets it burning for 2 a second over 3 s |
| Oiled weapon | The next 3 landed hits do +2 fire |
| Fears fire | Slimes, acid slimes, plague rats: recoil from a torch hit (their next blow 1 s later, back a tile), and will not step onto a burning tile or a tile with a burning torch |

### Resting (**all new**)

| | Number |
|---|---|
| Making camp | 1 firewood. No living monster within 4 tiles or in sight. Not in a fight. |
| A full rest | 30 s on screen. HP and mana rise evenly to full. Stop at any time and keep what you have. |
| Also clears | The Cleric's "shaken", sickness, a running meal |
| Does not | Raise the dead |
| Interruption, rolled 3 times a rest (at 10, 20 and 30 s) | At a camp spot 3% each (about 1 rest in 11). In a dead end 6% (1 in 6). In the open 12% (1 in 3). |
| An interruption | One or two tier 1 monsters, 2 tiles away. Never during the first 10 s. Never twice in a row. |
| Cooked food | Heals half as much again, in half the time |
| Cooked mouldy bread | No sickness |
| Raw rat meat | 6 HP over 6 s, 50% sickness. Cooked: 12 HP over 6 s, none. |
| Camping | Saves the game |

### XP and levels (**all new**)

| Source | XP |
|---|---|
| Kill, tier 1 / 2 / 3 / 4 | 10 / 25 / 150 / 400 |
| Ambush survived (all its monsters dead) | 60 |
| Puzzle solved | 50 |
| Secret found (a hidden room opened) | 40 |
| Legendary found | 30 |
| Remains searched | 5 |

| Level | 1 | 2 | 3 | 4 | 5 |
|---|---|---|---|---|---|
| Total XP | 0 | 150 | 400 | 800 | 1400 |

XP is shared. A level is applied at the next camp. Floor 1 holds 930 XP in all (section 5 has the tally).

| | Each level | Level 2 | Level 3 (perk) | Level 4 | Level 5 (perk, floor 2) |
|---|---|---|---|---|---|
| Fighter | +6 HP | +1 attack | **Follow-through:** a landed blow has a 20% chance to halve his wait | +1 defence | Stand fast |
| Cleric | +5 HP, +2 mana | - | **Firm hand:** Heal restores half as much again | +1 defence | Turn Undead |
| Thief | +4 HP | +1 attack | **Light fingers:** monsters drop loot half as often again; her traps never break | +1 attack | Backstab |
| Mage | +3 HP, +3 mana | - | **Deep breath:** his mana returns a quarter faster | +1 defence | A fifth spell |

### What lies on floor 1

| Item | Count | Where it comes from |
|---|---|---|
| Firewood | 3 | Remains 1, the brazier closet, remains 4 |
| Torch (loose) | 2 | The east corridor, room 2. Plus the Cleric's. |
| Candle (loose) | 2 | Room 3, remains 3. Plus the Cleric's two. |
| Sconces lit at the start | 8 | The start, the long corridor's first half, the Warden's hall |
| Sconces unlit, holding a torch | 7 | The east corridor, rooms 2 and 3 |
| Empty brackets | 10 | Everywhere else |
| Flask of oil | 3 | Two in the brazier closet, one on remains 5 |
| Bear trap | 2 | One near the start, one on remains 5 |
| Scroll of Resurrection | 2 | As today |

**Does the light add up?** A full clear takes about 40 minutes of unpaused play. Torch-quality light: the Cleric's
(4 min), two loose (8), and up to fifteen sconce torches at 2 minutes each (30), which each cost a lit corridor. That is
42 minutes if you strip the dungeon. Candle light: four candles, 40 minutes. So a player who puts lights away when
standing about finishes comfortably; one who lets the torch burn while reading the map ends on candles, in a
2½-tile pool of light, at the Warden's door. That is decision 1.

**Does the XP add up?** The critical path alone gives 155 XP before the Warden: level 2 at the last camp. Add the
north-east rooms and it is about 520: level 3. Everything, including the south-west after the Warden: 930, level 4.
Level 5 (1400) cannot be reached. That is decision 6.

---

## 3. One page per phase

### 7d. Ambushes

**The idea.** The dungeon fights back, twice on floor 1. A scare is build-up, silence, burst, and then a fight you
cannot walk away from.

**Rules**

- **An ambush is data:** an id, what arms it, its trigger tiles, its monsters, its lock-in, its clues, and its timings.
  Its state is one run flag, `ambush.<id>`: `armed`, `sprung` or `done`. It fires once.
- **The sequence.** Build-up 1.8 s: input ignored, the party's light and nearby sconces sink to 30%, music and ambience
  fade, a scrape. Burst: the wall breaks (the cracked wall's cubes), a sting, a shake, a flash. Snap: the party is
  turned to face it in 0.15 s. Then the fight, with tense music. With Reduce flashing: no flash, no shake, the light
  sinks instead of flickering.
- **In the dark.** If the party holds no light there is nothing to dim, so the build-up pulses the ambient green
  instead. A scare must not depend on the player carrying a torch.
- **The giant hand** lives in a wall tile. It grabs one living front-row hero: that hero cannot act and takes 2
  damage every 1.5 s. After it has taken 10 damage since the grab it lets go and takes 4 s to grab again (another
  hero if it can). 36 HP. Tier 2 for XP. Immune to every status.
- **The grab's limit (decision 3).** A squeeze cannot take a hero below 1 HP if they had half their health or more when
  grabbed. A hero grabbed below half can die.
- **Tentacles** are ordinary monsters that cannot move. Three sprout from cracks in the floor on free tiles beside the
  party: front, left, right. So they use the hit-direction rules that exist: the one on the left hits the left column,
  and the party must turn to kill each. 12 HP, 1-4.
- **Fighting back.** No new rule. After the snap the hand is the tile in front, so the front row swings at it and the
  back row throws and casts as usual. This replaces the roadmap's "side attacks" design question.
- **Lock-ins.** Grab hold: while a grabbing limb lives, the party cannot step or turn ("You are held fast!").
  Trap shut: every way out of the room closes and holds until the ambush's monsters are dead. Portcullises drop;
  plain doors slam and take a curse seal (the same seal as the purge room in 7e).
- **The budget.** An ambush costs at most 25% of a full-health party's HP: about 12 for the hand, 13 for three
  tentacles.
- **Clues.** Every real ambush has at least two, and at least one works without light: claw scratches and bones
  (need a torch to see), a faint green glow in the mortar (shows best in the dark), and a scrape you can hear from
  two tiles away.
- **The double tap,** once a floor: a fake-out with the full build-up and a banter set-up, a harmless bang (a skull
  drops from a niche), relief lines, and then the real ambush a few tiles on with no build-up and no banter.
- **Banter** follows the contract already in CLAUDE.md and `docs/tone.md` section 4: one exchange before, silence
  through the burst and the fight, one battle cry, a remark afterwards.
- **Saving.** Saving is refused only during the 1.8 s build-up. A save made mid-ambush stores the flag as `sprung`;
  loading puts the monsters back and re-applies the lock-in from them, with no second scare.

**What the roadmap gets wrong or leaves out**

- 7d.1 asks for a design pass. This page is it. The step becomes "copy these rules into the combat page".
- 7d.1's side-attack question is moot: the snap turn makes the wall monster the tile in front.
- 7d.2 dims "the torchlight". There may be none now. See "In the dark" above.
- 7d.3 says tentacles "occupy a wall tile". A wall monster can only reach a party standing beside its wall, and a
  room's middle is not beside any wall. Tentacles are floor-rooted instead. Only the hand is a true wall monster.
- 7d.4 uses portcullises only. Floor 1's ambush room has plain doors, so trap shut must seal those too.
- 7d.5's Options toggle exists already (Reduce flashing). Only the clue art and the debug key are left.
- The banter quiet switch, the ambush events and the test room's stand-in ambush are already built: 7d must use them,
  not add its own.
- `wip/boss-ambush` has a working `DungeonMap.AMBUSHES` with `pickup`, `trigger`, `seal` and `walls`, an immobile
  party-holding tentacle and the Warden. It predates the fight tracker, pacing, statuses and tiers. Take its data
  shape and its art; rewrite its logic on Foundations step 10.
- Nobody said what Hold Monster does to the hand. It is immune, and an immune target costs no mana (the existing
  rule). Give it its own refusal line so the player learns why.

### 7e. Puzzles

**The idea.** Old dungeon puzzles in curse clothing. The reward is always in the world: a door, a nook, a relic.

**Rules**

- **The framework exists in part** (`scripts/puzzles.gd`: `when` and `then` as data, saved in `puzzles_done`). New
  conditions: every monster in an area dead; a group of braziers all lit, or all dark; an item on an altar; a plate
  held. New effects: raise a reliquary, clear a curse zone, seal and unseal an area's doors.
- **Purge room.** Entering the area seals its exits with green curse seals. When the last monster inside dies the
  seals crumble and a reliquary grinds up out of the floor. No jingle.
- **Braziers** are props that do not block a tile. Lit by: clicking with a lit torch or candle in hand, a Fireball
  that passes or lands within a tile, a thrown torch landing on its tile, or burning oil beside it. Snuffed by an
  empty-handed click. A lit brazier lights 7 units and cannot be lit inside a curse zone.
- **Darkness runes** are on a wall face. They show only when the light reaching the tile in front of them is no
  more than the ambient: no held light, no lit sconce or brazier in reach, no spell mid-flight. Clicking the wall
  while they show opens it.
- **Weighted plates.** Every item has a weight (default 1; leather armour 2, a bear trap 3, the war hammer 4). A
  plate has a weight it needs (default 3). The party and any monster standing on it always hold it.
- **Offering altars** are built and put in the test room. Floor 1 does not use one.

**What the roadmap gets wrong or leaves out**

- 7e.1 describes a framework from scratch. Extend the one that exists, after Foundations step 9.
- 7e.2's seals are the same thing as 7d.4's trap shut. Build one sealing mechanism and use it for both.
- 7e.3 was written before torches existed and says "a torch item". It now means a lit light in hand, and four
  other ways to bring fire.
- 7e.4 asks for light levels "from nearby light sources". `sprite_lighting.gd` already computes exactly that
  (`light_at`). Use it; do not write a second light query.
- 7e.4's puzzle (snuff the braziers) breaks if the player simply holds a torch. The runes must check the party's
  light too, and a wall sign should hint at it.
- 7e.7 wants a brazier door "Fireball can solve early". Good, and oil and a thrown torch should solve it too.

### 7g. Legendaries

**The idea.** A few items with a personality and a price. Three on floor 1.

**Shared rules**

- A legendary is an `ItemDef` with `legendary` set and a behaviour script (Foundations step 11's hooks).
- A worn-gold slot frame and a slow shimmer, never the curse green.
- Finding one: 30 XP, a line from the finder, once.
- They speak through the banter engine as their own speaker (the hook for a held weapon is already there).

| Legendary | Who | Numbers | Price |
|---|---|---|---|
| **Grudge** (floor 1) | Fighter | Sword, +1 attack, 4-11. Never slips on a fumble (`never_slips` exists). | Sulks: 120 s in a backpack and it does 2 less damage for his next two fights. It talks. |
| **Penitent's Mace** (floor 1) | Cleric | 3-8. Each landed blow heals him 2. | He complains every time (one line per 25 s). He must stand in the front row to use it. |
| **The Unquenchable** (floor 1) | Anyone | A torch: light 1.8, never burns down, cannot be snuffed by a curse zone, a slip or a gutter. Swing as a torch. | Monsters notice the party 2 tiles further away. It mutters. It still takes a hand. |
| Too Old For This Shield (later) | Fighter | +1 defence, rising to +5 as his HP falls to a quarter. | Needs the shield slot, which does not exist yet. |
| The Gilded Hand (later) | Thief | Dagger. A kill has a 25% chance of a second drop. | Every few minutes it moves a small item from another pack to hers. |
| Tome of Screams (later) | Mage | Missile and Fireball do half as much again. | Each cast wakes every monster within 8 tiles. |
| The Rat King's Crown (later) | Anyone | Rats never attack the wearer. | Needs a head slot. The others complain about the smell. |

**What the roadmap gets wrong or leaves out**

- 7g.1 invents hooks (`on_cast`, `on_damage_taken`, `periodic`). Foundations step 11 defines `on_equip`,
  `on_unequip`, `on_hit`, `on_kill`, `on_tick`, `on_stowed`. Use those; add `on_cast` only when the Tome needs it.
- 7g.1 says "examine text (right-click)". Right-click on a floor item is now the loot pop-up, and in the inventory it
  splits a stack. Put the description in the tooltip and on the character sheet instead.
- The Shield and the Crown need slots the game does not have (one armour slot only). Later floors.
- 7g.7b says the Unquenchable "ignores curse zones and rain". There is no rain.
- 7g.7b must also say it cannot roll away burning on a fumble, or the party's one permanent light can be lost.
- Grudge's `never_slips` and the banter speaker hook are already in the code, waiting.
- The hand rule added on 14 Nov (only a caster holds a spellbook) is the pattern for "Fighter only": use
  `ItemDef.cant_use`.

### 7h. Resting

**The idea.** The calm between scares, and where levels land.

**Rules.** The numbers are in section 2. In words:

- One firewood makes one camp, anywhere no monster is near. **There is no tinderbox.** Lights already light
  themselves in a hand, so a second fire-making item is only a way to be locked out of camping.
- The view sinks to a small fire. HP and mana climb for 30 s. Stop at any time.
- A camp clears "shaken" and sickness, applies waiting levels, and saves the game.
- **Camp spots** are marked places (old ash on the floor, a symbol on the map once seen) where a rest is rarely
  disturbed. Anywhere else is a gamble.
- An interrupted rest keeps what it healed and keeps its levels. The firewood is gone.
- Cooking is a button in the camp view: it cooks every raw thing the party carries, one by one.
- Lights do not burn down during a rest. The fire is the light.

**What the roadmap gets wrong or leaves out**

- 7h.1 is a design pass; this page is it.
- 7h.1 and 7h.2 require a tinderbox. Dropped (above).
- 7h.2 gives camp a Rest button and the R key. R is "refill" in the test room, and the screen has no room for
  another button. Bind nothing new: camp is made by using the firewood (from a hand, a quick slot or the
  inventory), like every other item.
- 7h.2 says resting "also saves". Decision 7: it does, and F5 still works.
- 7h.3's raw meat needs a monster to drop it. That is the plague rat.
- 7h.4 never says an interruption cannot happen in the first seconds. Without that, firewood feels like a coin toss.
- Nothing says what a rest does to a held torch, to a running meal, to Hold Monster's recast or to an armed trap.
  Torches pause; the meal's remaining healing is given at once; recasts clear; traps stay armed.
- The fight tracker (`Party.fight.in_fight`) is the "is a monster near" test's first half. Use it.

### 7i. Levelling

**The idea.** Clever play earns as much as fighting. Levels land by the fire.

**Rules.** The table is in section 2. In words:

- XP is one number for the party. Each award is a short log line.
- Everyone shares it, dead or alive. (The roadmap says the dead earn nothing until revived. That means tracking XP
  per hero for a party that otherwise has one number, and a dead hero is punishment enough.)
- A waiting level shows as a small warm mark on the portrait. It is applied at the next camp, one hero at a time.
- A level's gains are fixed, not rolled. The roll belongs to the character generator.
- Perks at 3 and 5. Each is one line on the character sheet.

**What the roadmap gets wrong or leaves out**

- 7i.1 is a design pass; this page is it.
- 7i.1 says level 5 on floor 1. Decision 6: level 3 or 4. The cap stays 5 in the data.
- 7i.1 says "ability scores from the character generator if it exists". Levelling is built first. Level gains are flat
  and the generator's scores change the base, so neither waits for the other.
- 7i.2's "Secret found. +50 XP." reads like a score. Keep the number out of the sentence the world says: the log
  shows the event as it does today and the XP as its own small line.
- 7i.4's "trap disarming" perk has nothing to disarm: traps never catch the party. The Thief's perk is loot and
  unbreakable traps instead.
- 7i.4 gives the Mage "a new spell" at 3. He got Hold Monster already. His level 3 is mana; the spell waits for 5.
- Test-room keys X and U already exist and call `Party.add_xp` and `Party.level_up_party` by name. Keep those names.
- Needs Foundations step 8 (a hero's own stats) and step 7 (saves that can grow).

### 7j. Fallen adventurers

**The idea.** Bodies you hesitate over, and search anyway.

**Rules**

- Remains sit against a wall on a floor tile and do not block it. Four looks.
- Searching is the F key facing them, or a click. Once. Afterwards they look disturbed.
- The result is set in the level data: an item, a note, nothing and a dry line, a bite, or it sits up.
- **A bite:** a bear trap closes on the searcher for 1-3, and the party gets the trap.
- **Sits up:** a skeleton, already beside the party. It is an ordinary fight; no scare sequence, no lock-in.
- Notes open a small parchment panel. One on floor 1 is Bellius's (decision 10).
- 5 XP each.

**What the roadmap gets wrong or leaves out**

- "Pressing E" would turn the party: E is turn right. The use key is F.
- "A trap (reusing the trap system)": the trap system only catches monsters. A bite is `Party.hurt` plus a free
  item, not a trap that springs.
- A body that sits up next to an ambush must not happen: one scare at a time.
- The remains object needs a symbol on the map only after it has been searched (an X), or the map tells the player
  where the loot is.
- Banter: the Thief loots, the Cleric prays, the Fighter takes the boots. The `item_picked_up` event exists; remains
  need their own `remains_searched(kind)` event so lines can tell a joke from a bite.

### 7k.2. Bear trap

Built on 13 Nov and changed on 14 Nov (dropping it sets it; nothing gets past it). What is left:

- **Tiers 3 and 4: once a fight.** Decision 5. The tier table gives 1.5 s; add "a monster of tier 3 or more can be
  caught once per fight" so two traps in a corridor are not a stun lock on the Warden.
- **The roadmap prompt is out of date** on three points: `hold_resist` no longer exists (the tier table replaced it),
  setting is by clicking the trap or dropping it, and the resist chance is gone.
- **Plague rats** are tier 1 and are caught like anything else. They do not ooze.
- **Remains can bite** with one (7j).
- **Weight 3** for plates (7e).

### 7l. Light and darkness

7l.1 is built. What is left:

**Sconces (7l.2)**

- Every wall torch becomes one of three: **lit**, **unlit with a torch**, or an **empty bracket**.
- Light an unlit one by clicking it with a lit light in hand, or with a Fireball or thrown torch.
- Take the torch from a sconce with an empty hand: it has 120 s on it, and that corridor goes dark.
- Put a torch in an empty bracket and it lights the corridor for good. It keeps the burn time it had and does not
  lose any while it hangs there.
- Shown on the map once seen.

**Curse zones (7l.3)**

- Held flames sputter for a second and go out. They will not relight inside. Sconces and braziers inside will not
  light. Burning things thrown in fizzle.
- Spell light works. The Unquenchable works.
- **Bless** makes a pocket: for 20 s, flames can be lit and stay lit on the party's tile and the tiles beside it.
- A zone can be cleared for good by a puzzle effect.
- A thin green haze on the floor says where it is. No message until a flame dies.

**Throwing torches (7l.4):** as the roadmap says, with the numbers in section 2.

**Oil (7l.5):** as the roadmap says, with the numbers in section 2.

**The dark in a fight (new, decision 2):** -10 to hit for a hero whose tile gets no light beyond the ambient.

**What the roadmap gets wrong or leaves out**

- **7l.2 as written gives endless torches.** Light an unlit sconce with your torch, pull the torch out, "you gain a
  torch with a full burn time", repeat. The fix: a sconce holds one real torch, taking it empties the bracket, and a
  sconce torch is a two-minute stub.
- 7l.2 has no empty brackets, so every corridor can be relit for nothing. Ten of the 25 should be empty.
- 7l.3 does not say what happens to a torch already burning on the floor in a zone, or to a brazier. Both go out.
- 7l.3's Bless pocket has no size or time. One tile around the party, 20 s (Bless's own length).
- 7l.4 forgets that a critical-fail slip already leaves a torch burning on the floor (`light_field.gd`). Throwing
  uses the same node.
- 7l.5's "doused" status needs a row in the tier table, and must say that slimes can be doused (they ooze through
  traps, but oil sticks).
- 7l.5 lets a burning tile hurt the party. Keep it, at half the monsters' rate, and never from the party's own tile
  igniting under it without warning: oil thrown "at the floor" always lands on the tile in front, never underfoot.
- 7l.6 checks that clues "can be spotted with a torch". One clue per ambush must also work without one (7d).
- Monsters and items are tinted by the light that reaches them. Braziers, burning oil and the Unquenchable must all
  join the `sprite_lights` group or monsters beside them stay dark.

### 8b. Character generator

**The idea (decision 9).** You do not roll four strangers. You are handed Brannoc, Brother Felix, Wren and
Fennick, and you may change them.

**Rules**

- New Game opens the party screen: the four heroes in their 2x2 formation, with **Play** already lit. A player who
  wants to start does so in one click.
- Click a hero to change them: a name (up to 14 letters, with a Random button), a portrait (three per class), and
  their scores.
- **One of each class, always.** The class of a slot cannot be changed. This is what lets every banter line work.
- **Six scores,** 3 to 18: Strength, Dexterity, Constitution, Intelligence, Wisdom, Charisma. Rolled 4d6, drop the
  lowest. Reroll as often as you like; the whole set rerolls together.
- A score's **modifier** is (score - 10) / 2 rounded down, between -2 and +3.

| What | Formula |
|---|---|
| HP | Class HP + 2 x Constitution modifier |
| Attack | Class attack + Strength modifier (Thief: Dexterity) |
| Defence | Class defence + Dexterity modifier, at most +1 from it |
| Mana | Class mana + 2 x Intelligence modifier (Mage) or Wisdom (Cleric) |
| Crit | As today: the class's base + (Dexterity - 10) |
| Speed | Class speed (not rolled: it sets the rhythm of every fight) |
| Charisma | Monsters choosing whom to hit prefer the hero with the lowest. |

- The four ready-made heroes have scores that give exactly today's numbers (modifiers of 0 where it matters), so an
  untouched party plays as it does now.
- A class needs 9 or more in its key score (Strength, Wisdom, Dexterity, Intelligence). Below that the roll is
  refused with a line and you roll again.
- Level gains (7i) are flat and sit on top.

**What the roadmap gets wrong or leaves out**

- Races are out for now (decision 9). 8b.1 and 8b.3 are built around them.
- 8b.2's four empty slots and a Play button that unlocks when all are filled makes the first two minutes of the game
  a form. Start full.
- 8b.4 uses "my procedural portrait script". Portraits are PixelLab art at 128 px now. Three per class is eight new
  pictures, to be generated one first and approved.
- 8b.4 caps names at 10 letters. "Brother Felix" is 13. The panel already shortens a long name.
- 8b.5's Quick Party of a dwarf, a human, a halfling and an elf is replaced by the four named heroes.
- The intro plays on the first launch and the party screen comes after it; say so, or New Game lands in the film.
- Needs Foundations step 8. A hero's scores are saved with the hero.
- Charisma needs a job or it is a dump stat with a funny name. Being hit more is a job.

---

## 4. Where systems meet

**Flag** marks one that would break or feel unfair if built the obvious way. The rule in bold is the fix.

### Light

| Meeting | What happens |
|---|---|
| Torchlight and darkness runes | Any light on the tile in front of the wall hides them. **Flag:** a player holding a torch will never see them. **The room's sign must hint, and the party's own light must count, so putting the torch away is the answer.** |
| A candle and darkness runes | A candle hides them too. Any flame does. |
| Spell light and darkness runes | A Fireball in flight hides them for its moment. Harmless. |
| The Unquenchable and darkness runes | It cannot be put out, but it can be put away. Stowed, it gives no light. |
| A curse zone and held flames | Out in a second. **Flag:** the party is suddenly at -10 to hit among whatever lives there. **The haze must be visible from the tile before, and nothing in a zone may be above tier 1.** |
| A curse zone and the Unquenchable | Stays lit. This is what the torch is for. |
| A curse zone and a brazier or sconce inside | Will not light. Clearing the zone lets them. |
| A curse zone and Bless | A 20 s pocket of one tile around the party where flames live. |
| A curse zone and a burning torch thrown in | Fizzles where it lands, and can be picked up cold. |
| Oil and a curse zone | A slick will not light there. A doused monster will not catch. The flask is not spent uselessly: the throw is refused with a line while the party stands in a zone. |
| The dark and hit chance | -10 for weapons. **Flag:** with no light at all a level 1 Mage with a dagger hits a guard one time in three. **Spells are exempt, so the back row is never useless in the dark.** |
| The dark and ambush clues | Scratches need light. **Flag:** unfair if they are the only clue. **Each ambush has a glow and a sound that need none.** |
| A dead hero holding the party's only light | It goes out with them. **Flag:** a death can drop the party into the dark mid-fight. Fair: it is the cost of who carries the torch. The torch stays in the dead hand to be taken. |
| Waiting for mana and the torch | Mana at 1 per 6 s means a full Heal costs a tenth of a torch. Putting the light away while you wait is allowed and safe. |
| Resting and burn time | Paused. The fire is the light. |
| A slipped torch and the Unquenchable | The Unquenchable never slips. |
| Fire and a monster that fears it | It recoils from a hit and will not cross a burning tile. **Flag:** a 1-wide corridor with a burning tile is a wall against slimes and rats, for 6 s. Intended: it is what oil is for. |

### Stopping monsters

| Meeting | What happens |
|---|---|
| Hold Monster and wall monsters | Immune. No mana spent. Its own line, so the player learns why. |
| Hold Monster and tentacles | They are ordinary tier 1 monsters: held 90% of the time. A held tentacle does not hold the party, so Hold is a way out of the trap-shut room's grip, though not out of the room. |
| Hold Monster and the Warden | 35%, 2.5 s. A resisted cast still costs 5 mana and the 12 s wait. |
| The trap and tiers | Always holds. 3 s for tiers 1 and 2, 1.5 s for 3 and 4, and tiers 3 and 4 once a fight. |
| The trap and slimes | They ooze through. The trap stays armed. |
| The trap and rats | Caught. |
| The trap and wall monsters, tentacles | They never step, so never. |
| The trap, oil and fire | A held monster on a slick can be lit. With Fireball on a doused Warden that is about 20 damage: a quarter of him for one flask, one trap and 6 mana. Intended as the best trick in the game. |
| A helpless monster and crits | As today: the Thief's bonus most of all. |
| A recoiling slime and a trap behind it | It backs onto the trap and oozes through. Nothing happens. |

### Scares

| Meeting | What happens |
|---|---|
| Saving during an ambush | Allowed, except in the 1.8 s build-up. The flag is saved as `sprung`; a load restores the monsters and the lock-in without a second scare. **Flag (from the code review):** today a mid-fight save drops the fight state, so a load would open the doors. **Foundations step 7 first, and the lock-in must be re-derived from the living ambush monsters, not remembered separately.** |
| Banter during a scare | Quiet from the burst until the last monster falls, except one battle cry. The engine's quiet switch does this already. |
| Banter set-up and the double tap | The fake-out gets the set-up exchange; the real ambush gets none. That is the trick. |
| An ambush and a body that sits up | Never within 6 tiles of each other. |
| An ambush and a rest | A camp cannot be made on an armed trigger tile or within 2 tiles of one: the "no monster near" test counts an armed ambush. Otherwise a player camps in the trap room and the interruption table has to deal with it. |
| An ambush and the map | Never drawn, before or after. |
| The grab and the grabbed hero's torch | It stays lit in their hand. They cannot swing it. |
| The grab and the grabbed Cleric | He cannot cast. **Flag:** a party whose only healer is squeezed has no answer but damage. Fair, because the hand lets go after 10 damage. |
| The grab and a hero under half health | Can die (decision 3). The 50% line is read when the grab starts. |
| A grab and "can't turn" | The party cannot turn away from the hand, so nothing can reach its back row. Never put another monster in an ambush with the hand. |
| Trap shut and the loot pop-up, the inventory | Both still open. The fight goes on while the loot pop-up is up; the inventory pauses, as it does now. |
| Reduce flashing and a scare | No flash, no shake; the light sinks and the sound does the work. |

### Growing

| Meeting | What happens |
|---|---|
| Levelling and legendaries | Grudge's +1 attack and the Fighter's +1 at level 2 take him to 75% against a guard. The cap is 95, so nothing breaks. Penitent's Mace with "Firm hand" does not stack: the perk is Heal only. |
| Levelling and the Warden | A level 2 rusher with a short sword takes about 18 s and loses about 35 HP from the front row. A level 3 party about 13 s and 24 HP. Both live. |
| Levelling and camps | Three firewood means three chances to level. **Flag:** a player who burns all three early cannot apply a later level. **A waiting level is also applied at the stairs, so XP is never lost.** |
| Levelling and a dead hero | Shares the XP all the same (the simple rule). |
| Levelling and the generator | Flat gains on top of rolled bases. A hero's Constitution changes level 1 HP only. |
| Perks and loot | "Light fingers" multiplies drop chances by 1.5: skeleton bread 25% to 38%, rat meat 40% to 60%. |
| The mana change and the Mage | Two Fireballs a fight, not three. "Deep breath" at level 3 gives some back. Watch this in the playtest. |
| The generator and banter | One of each class, so every speaker exists. Lines use `{name}`, so renaming is safe. |
| Charisma and the back row | Only among heroes the monster can already reach. It never lets a monster hit past the front row. |
| The loot pop-up and legendaries | "Can't use" already shows for class limits. A legendary's row should carry its gold frame. |
| Remains and the loot pop-up | An item from remains drops on the tile in front and uses the same pop-up. No second loot window. |
| Weighted plates and dropping a trap | Dropping a trap in front sets it (14 Nov). **Flag:** then a trap cannot be dropped onto a plate. **A plate tile refuses a trap already ("The trap won't sit flat there."), so a trap dropped at a plate is put down as an item, and holds it.** |
| Firewood and the campfire's light | The fire is a light source for the room (it must join `sprite_lights`). |

---

## 5. Floor 1 pacing plan

The floor falls into three acts. Act one is the road everyone walks. Act two is the north-east, optional, where the
weapons are. Act three is the Warden, and after him the south-west, which most players have never seen.

```
     0123456789012345678901
  0  ######################      #  wall          .  floor
  1  ##################.#.#      +  door          L  locked door
  2  ##################+#L#      =  portcullis    >  stairs down
  3  ##.#############G#b.b#      %  corrupted wall (Bless)
  4  ##c#############%#...#      x  cracked wall (hammer, Fireball)
  5  ##.#############3+...#      @  start
  6  ##x#############+###=#
  7  ##.....#####.....#...#      H  the giant hand (in the wall)
  8  ######.#####.....#.T.#      F  fake-out      T  tentacles
  9  ####.@.%2..#.....+...#      W  the Cursed Warden
 10  ######.H...#.....#+###      P  purge room, reliquary
 11  ######.....#.....#.###      b  brazier       N  darkness runes
 12  ######.###########F###      r  plague rats, curse zone (the cave)
 13  ######..1....#####.###      G  Grudge        c  safest camp
 14  ############.#####.###      1-6  fallen adventurers
 15  ########..##....5..###      _  weighted plate
 16  #######....##N####.###
 17  ######..r.....b###..4#      Rooms: 5 = (8-10, 9-11)   3 = (12-16, 7-11)
 18  ######....##...#####L#             2 = (18-20, 7-9)   7 = (18-20, 3-5)
 19  #######...##b.6+...#.#             4 = (12-14, 17-19) 6 = (16-18, 19-21)
 20  ################.P.#.#             the cave = (6-10, 15-19)
 21  ################.._=.#
 22  ####################W#
 23  ##################>>.#
 24  ######################
```

### Act one: the road (about 10 minutes)

| # | Where | What | Beat |
|---|---|---|---|
| 1 | Start (5,9) | Lit. Sword, armour, bread at your feet. The Cleric holds the torch. | Calm |
| 2 | Thin corrupted wall (7,9) | One Bless opens it. Teaches Bless. | Small reward |
| 3 | The wall between the two ways into room 5, (7,10) | Claw scratches on both faces, bones, a glow in the mortar. You walk past them going in. | A clue nobody reads |
| 4 | Room 5 | A slime. Key one at (10,10). Remains 2 at (8,9): nothing. | First fight |
| 5 | Leaving room 5 with the key, by (7,9) or (7,11) | **The giant hand** bursts from (7,10) into whichever passage you take. Grab hold. Armed by picking up the key. | **Scare one** |
| 6 | Long corridor, alcove (8,13) | Remains 1: firewood. A bear trap lies at (6,12). The skeleton comes. | Relief, then a lesson |
| 7 | About here | The Cleric's torch gutters out. | The dark arrives |
| 8 | (12,14) on | The sconces are unlit from here. | Tension |
| 9 | East corridor | A slime. A torch lying at (15,15). Remains 5 at (16,15): it bites, and you keep the trap, plus a flask of oil. | A flinch, a tool |
| 10 | Junction (18,15) | North to act two. South to the door. | A choice |
| 11 | (19,17) | A skeleton guard at the locked door. | Fight |
| 12 | Stub (20,17) | **Camp spot.** Remains 4: firewood, beside a cold fire. | **Relief.** Level 2 lands here for a rusher. |

### Act two: the north-east (about 15 minutes, optional)

| # | Where | What | Beat |
|---|---|---|---|
| 13 | North leg (18,12) | **Fake-out.** The full build-up, the Cleric smells evil, a skull drops from a niche. Relief lines. | False scare |
| 14 | Room 2, three steps in | **Tentacles**, no warning. The doors slam and seal, the portcullis stays shut. | **Scare two** |
| 15 | Room 2 after | The bow, arrows, a torch. The lever for the north gate. | Reward |
| 16 | Room 3 by the west door | A guard and an acid slime among the weapons: long sword, mace, war hammer, a candle. | Fight, big reward |
| 17 | Room 7 | A skeleton and an acid slime. Key two. Two cold braziers in the corners (18,3) and (20,3). | Fight |
| 18 | Closet door (18,2) | Warded until both braziers burn. Torch, candle, Fireball, oil or a thrown torch. Inside: three potions, two oil, firewood. | **Puzzle one**, reward |
| 19 | Nook (16,5) | **Camp spot**, two doors to shut. Remains 3: a candle and Bellius's note. | **Relief.** Level 2 or 3. |
| 20 | Thick corrupted wall (16,4) | Two Blesses. Behind it: **Grudge**. The north gate unlatches (the puzzle that exists today). | Secret, legendary |
| 21 | Back west: the cracked wall (2,6) | The war hammer or a Fireball. The closet behind: the safest camp on the floor, and a Scroll of Resurrection. | Secret |

### Act three: the Warden and after (about 15 minutes)

| # | Where | What | Beat |
|---|---|---|---|
| 22 | Locked door (20,18) | Key one or two. | A breath |
| 23 | The hall (20,19) to (20,23) | Lit sconces, the first in a long time. The **Cursed Warden** at (20,22) with a burning torch in his fist. One tile wide: a trap at (20,21), oil, a held Fireball. | **The climax** |
| 24 | Where he falls | **The Unquenchable.** The stairs are three steps away. | The reward |
| 25 | Stairs (18,23) | The end, for most. Waiting levels are applied here. | |
| 26 | Lever (20,20), the south gate | The way into rooms nobody has seen, for a party with a torch that cannot die. | An invitation |
| 27 | Room 6 | **Purge room.** A skeleton, a guard and an acid slime. The exits seal. The reliquary rises at (17,20): **Penitent's Mace**. The plate at (18,21) now holds with weight. | Fight, **puzzle two**, legendary |
| 28 | Room 4 | An acid slime. Key three. Two lit braziers. Remains 6 at (14,19): it sits up. A sign: "What the light hides." | A flinch |
| 29 | Room 4, north wall (13,16) | Snuff both braziers and put your light away: **runes**. The wall opens onto the east corridor, a short cut home. | **Puzzle three** |
| 30 | The cave | **Curse zone.** Flames die at the edge. Three **plague rats** nest at (8,17). Kill them all and the zone lifts for good. The slingshot, armour, a scroll, potions. | The hard part, optional |
| 31 | Back north by the short cut | Key three opens the locked closet (20,2): the best loot, and the other Scroll of Resurrection. | The last reward |

### Why this order

- **Scare, relief, reward, three times.** The hand, then firewood and the trap. The tentacles, then weapons and a
  camp. The Warden, then the torch.
- **No two scares touch.** The hand is at minute three, the fake-out and tentacles around minute twelve, the Warden
  at the end. The body that sits up is in act three, far from any of them.
- **No puzzle straight after an ambush.** After the tentacles comes loot and a lever. The brazier door is two rooms on.
- **The light tells the story.** Lit at the start, a dying torch on the long corridor, black through the middle, and
  the brightest room on the floor is the one with the Warden in it.
- **Each tool is taught before it is needed.** Bless on the thin wall before the thick one. The trap by the skeleton
  that chases you, long before the Warden's corridor. Fire on the braziers before the rats.
- **The legendaries are spaced:** minute 20 (Grudge), the end (the Unquenchable), and after the end (the Mace).

### Changes to the level data

| What | Change |
|---|---|
| Monsters removed | The skeleton in room 2 (19,8); the acid slime (20,21) and guard (20,22) at the stairs; the cave's skeleton (9,18) |
| Monsters moved | The cave's guard (8,16) to room 6 (16,21); the stairs' acid slime to room 6 (18,19) |
| Monsters added | The hand (7,10); three tentacles (room 2); the Warden (20,22); three rats (cave); the sitting skeleton (remains 6) |
| Total | 16 tier 1, 4 tier 2, 1 tier 3 |
| New door | A plain door at (15,19), so room 6 has two exits to seal |
| Key two | From (20,3) to (19,4), to make room for a brazier |
| Bear traps | (7,11) to (6,12), off the hand's trigger tile; (18,14) becomes remains 5 |
| Sconces lit | (3,7) (5,9) (6,11) (6,12) (9,9) (9,13) (20,19) (20,22) |
| Sconces unlit, with a torch | (12,14) (14,15) (17,15) (18,13) (18,16) (14,7) (19,9) |
| Empty brackets | (12,9) (14,11) (16,5) (19,3) (13,17) (17,21) (8,15) (9,18) (18,1) (20,1) |

After any of this: run the walk-through check (doors, keys, levers, plate, both exits) that CLAUDE.md asks for.

### The XP on the floor

| | XP |
|---|---|
| 16 tier 1 kills | 160 |
| 4 tier 2 kills (three guards, the hand) | 100 |
| The Warden | 150 |
| Two ambushes survived | 120 |
| Four puzzles (the nook's latch, the braziers, the purge, the runes) | 200 |
| Two secrets (the cracked closet, Grudge's closet) | 80 |
| Three legendaries | 90 |
| Six remains | 30 |
| **Total** | **930** |

---

## 6. Build order

Each phase ends by placing its own things on floor 1 and playing it, so the floor is never left half-furnished. The
roadmap's separate "place it in floor 1" steps (7d.6, 7e.7, 7g.8, 7h.6, 7j.2, 7l.6) become the last step of each
phase, using section 5.

| # | Build | Needs first | Why here |
|---|---|---|---|
| 1 | **Foundations step 7:** saves that can grow | - | Every phase below adds saved state. Do it once, first. |
| 2 | **The mana change** and the Warden's hall (the Warden as a plain tier 3 monster, no torch yet) | 1 | Two small changes that fix the two worst things about the floor today. Playtest before going on. |
| 3 | **7l.2 sconces, 7l.4 thrown torches, the dark's -10** | 1 | Finishes the light that is half built. Floor 1 becomes dark in earnest. |
| 4 | **Foundations step 9,** then **7e:** framework, braziers, runes, purge room, plates, altar (test room only) | 3 | Braziers and runes are light puzzles. The sealing built here is reused by ambushes. |
| 5 | **7l.3 curse zones, 7l.5 oil,** the plague rat | 4 | Zones need the puzzle effect that clears them. Oil needs braziers to be worth finding. |
| 6 | **Foundations step 10,** then **7d:** the hand, tentacles, lock-ins, clues, the double tap | 4 | Needs monster behaviours, and the seals from 7e. Take data and art from `wip/boss-ambush`. |
| 7 | **7j** fallen adventurers | - | Small. Places the firewood that resting needs. |
| 8 | **7h** resting and cooking | 7 | Needs firewood on the floor and rat meat to cook. |
| 9 | **Foundations step 8,** then **7i** levelling | 6, 8 | Needs camps to land levels, and ambushes and puzzles to pay XP. |
| 10 | **Foundations step 11,** then **7g:** framework, Grudge, the Mace, the Unquenchable | 9 | Balanced against a levelled party. The Warden gets his torch. |
| 11 | **A balance pass and demo v0.8** | 10 | The whole floor, start to stairs, three times: rushing, thorough, careless with light. |
| 12 | **8b** character generator | 9 | Needs step 8, already done. Last, because it changes nothing a returning player sees. |
| - | **Foundations step 12** (levels as data) | - | Not needed until a second floor or phase 9. |
| - | **7b.8 dead weight, 7f.3 to 7f.5** | - | Independent. 7f.3's new events come free with each phase above. |

Which Foundations step guards which phase:

| Step | Must come before |
|---|---|
| 7 Tolerant saves | Everything from here on (sconce states are the first new saved thing) |
| 8 Hero stats | 7i, 8b |
| 9 Puzzles on the event bus | 7e |
| 10 Monster behaviours | 7d, and the plague rat's sickness bite if it is written as a behaviour |
| 11 Item behaviour hooks | 7g |
| 12 Levels as data | A second floor, phase 9 |

---

## 7. Replacement prompts

Copy each over the roadmap prompt of the same name. Every one assumes this document is at
`docs/design/expansion_design.md`.

**Mini-boss prompt (The Cursed Warden; replaces the Leftovers line)**

```
Add the floor 1 mini-boss from docs/design/expansion_design.md (sections 2
and 5). Bring the Cursed Warden's data and art over from the branch
wip/boss-ambush (data/monsters/warden.tres, its sheet and gen_warden.py);
do not bring its ambush code.
- Stats: tier 3, 80 HP, attack 5, defence 4, damage 3-9, a blow every
  2.0 s, sight 8. Set attack_hit_frame for his attack animation.
- He stands at (20,22) in the stairs corridor. Remove the acid slime at
  (20,21) and the guard at (20,22).
- Tier table: a monster of tier 3 or more can be caught by a bear trap
  once per fight (the fight tracker says when a fight ends). Add that
  rule and a smoke check for it.
- The sconces at (20,19) and (20,22) stay lit.
- Banter (read docs/tone.md first): one line when he is first seen, one
  when he falls.
- Add him to the test room's combat arena spawn list, run the tests, and
  redo the walk-through check of floor 1.
```

**Mana prompt (Slower mana)**

```
Change mana regeneration from 1 point per 2.5 s to 1 per 6 s
(Party.MANA_REGEN_TIME), as docs/design/expansion_design.md section 2
explains. Update the combat design page and the blueprint artifact, the
smoke test, and any README text that quotes the old rate. Do not change
any spell's cost. Then tell me how long a full Heal and a full Fireball
take to come back, so I can playtest it.
```

**7d.1 prompt (Ambush rules into the combat page)**

```
Copy the ambush rules from docs/design/expansion_design.md (section 3,
"7d", and the tier and monster tables in section 2) into
docs/combat_design.md and the combat blueprint artifact, replacing the
parked boss-ambush rules there. No code. Show me the two sections before
you publish the artifact.
```

**7d.2 prompt (Trigger tiles and the scare sequence)**

```
Do Foundations step 10 first if it is not ticked.

Build ambushes as data, following docs/design/expansion_design.md section
3 "7d". Start from the DungeonMap.AMBUSHES shape on the branch
wip/boss-ambush (pickup, trigger, seal, walls) and from the test room's
stand-in ambush, which already drives the banter quiet switch and the
ambush_warning / ambush_started / ambush_over events. Use those; add no
second set.
- An ambush has: id, armed_by (nothing, or picking up an item on a cell),
  trigger tiles, monsters, a lock-in kind, and its timings in a config.
- State is one run flag, ambush.<id>: armed, sprung or done.
- The sequence: build-up 1.8 s (input ignored, the party's light and
  sconces within 3 tiles sink to 30%, music and ambience fade, a scrape),
  burst (the cracked wall's cubes, a sting, a shake, a flash), snap (the
  party turns to face it in 0.15 s), fight.
- If the party holds no light, pulse the ambient green during the
  build-up instead.
- Reduce flashing: no flash or shake; the light sinks without flicker.
- Saving is refused during the build-up only. A save made while sprung
  restores the monsters and the lock-in on load, with no second scare.
- 60 XP when the last ambush monster dies, if Party.add_xp exists.
- A debug key in the test room that springs the nearest ambush.
Sounds can be placeholders, listed in docs/asset_log.md. Run the tests.
```

**7d.3 prompt (The giant hand and the tentacles)**

```
Add the two ambush monsters from docs/design/expansion_design.md (section
2 for numbers, section 3 "7d" for rules).
- The giant hand is a wall monster (MonsterDef.wall_monster): it sits in
  a wall tile, is registered in DungeonMap.occupied there so the tile in
  front of the party can be struck, draws on the wall face, never moves
  and is immune to every status. It grabs one living front-row hero:
  that hero cannot act and takes 2 damage every 1.5 s through Party.hurt.
  After 10 damage since the grab it lets go for 4 s. A squeeze cannot
  take a hero below 1 HP if they had half their HP or more when grabbed.
- Hold Monster on it costs nothing and says why, in one dry line.
- Tentacles are ordinary tier 1 monsters with a rooted behaviour: three
  sprout on free tiles beside the party (front, left, right). The party
  cannot step away while a living, unheld tentacle is beside it.
- Art with PixelLab, following docs/art_style.md, one first for my OK: a
  huge rotting hand with cracked grey skin, blackened nails and green
  veins; dark slick tentacles with pale suckers. Reach out, idle, attack
  or squeeze, hurt, death. Reuse the tentacle on wip/boss-ambush if it
  still fits the style. Log everything in docs/asset_log.md.
- Hit effects for both (MonsterDef.hit_effect) from the VFX tool.
- A test-room station with one of each. Smoke checks for the grab's
  limit, letting go, and the tentacles holding the party. Run the tests.
```

**7d.4 prompt (Locking the party in)**

```
Add the two lock-ins from docs/design/expansion_design.md section 3 "7d".
- Grab hold: while a grabbing limb lives the party cannot step or turn
  ("You are held fast!").
- Trap shut: every exit of the ambush's area closes and holds until its
  monsters are dead. Portcullises drop. Plain doors slam and take a curse
  seal. Build the seal as one shared mechanism (Dungeon.seal_area /
  unseal_area) because the purge room in 7e uses the same one.
- A door never closes on the party or a monster standing in it (the rule
  that exists).
- The lock-in is worked out from the living ambush monsters, never
  stored on its own, so a loaded save has it right.
- The inventory, the map and the loot pop-up still open while locked in.
Run the tests, and add a smoke check that saving and loading inside a
trap-shut room leaves the doors shut.
```

**7d.5 prompt (Clues and tuning)**

```
Add ambush clues, following docs/design/expansion_design.md section 3
"7d". The Reduce flashing option already exists; do not add another.
- Clue decals near an ambush wall: deep claw scratches, piled bones, wet
  drag marks (these need light to see), and a faint green glow in the
  mortar (an emissive decal, like the curse veins, so it shows best in
  the dark).
- A scraping sound when the party is within 2 tiles of an armed ambush,
  at most once every 20 s.
- Every ambush must have at least two clues, one of which needs no light.
  Make the level check this when it loads and warn in the log if not.
- Art from PixelLab following docs/art_style.md; log it.
Run the tests.
```

**7d.6 prompt (Ambushes on floor 1)**

```
Place the ambushes from docs/design/expansion_design.md section 5.
- The hand: wall tile (7,10), armed by picking up key one at (10,10),
  trigger tiles (7,9) and (7,11), bursting into whichever the party is
  on. Grab hold. Clues on both faces of (7,10). Move the bear trap from
  (7,11) to (6,12).
- The double tap: a fake-out at (18,12) (a skull drops from a niche; add
  the alcove), then tentacles in room 2 with no build-up, three steps in.
  Trap shut on the doors at (18,10) and (17,9) and the gate at (20,6).
  Remove the skeleton at (19,8).
- Banter lines for the fake-out's set-up and relief (read docs/tone.md
  first; show me the lines before they go in).
Redo the walk-through check, run the tests, and tell me what a first run
through each felt like in numbers: HP lost, seconds, mana spent.
```

**7e.1 prompt (Puzzle framework)**

```
Do Foundations step 9 first if it is not ticked.

Extend the puzzle framework that exists (scripts/puzzles.gd,
DungeonMap.PUZZLES) rather than adding a new one. See
docs/design/expansion_design.md section 3 "7e".
- New conditions: every monster in an area dead; every brazier in a
  group lit, or every one dark; an item (by file or by tag) on an altar;
  a plate held.
- New effects: seal and unseal an area's exits (the shared seal from
  7d.4 if it exists, else build it here), raise a reliquary on a cell
  with given items, clear a curse zone, play a sound.
- 50 XP when a puzzle is solved, if Party.add_xp exists.
- A list in the test room's H overlay: each puzzle, its conditions, and
  which are met.
Keep every existing puzzle working. Run the tests.
```

**7e.3 prompt (Braziers)**

```
Add braziers, following docs/design/expansion_design.md sections 2 and 3.
- A prop on a floor tile that does not block it, lit or dark, in a named
  group. Saved.
- Lit by: clicking it with a lit torch or candle in a hand; a Fireball
  that passes or lands within a tile; a thrown torch landing on its
  tile; burning oil beside it. Snuffed by clicking with empty hands.
- A lit brazier is a light (energy 1.4, range 7) in the sprite_lights
  group, so monsters and items beside it are lit. It will not light
  inside a curse zone.
- Art and flames from PixelLab (the flames from the VFX tool), following
  docs/art_style.md; log it. One picture first for my OK.
- A test-room station: two braziers and a warded door.
Run the tests.
```

**7e.4 prompt (Paths that only appear in darkness)**

```
Add darkness runes, following docs/design/expansion_design.md section 3.
- A decal on a wall face that shows only when the light reaching the
  floor tile in front of it is no more than the ambient. Use
  sprite_lighting.gd's light_at for this; do not write a second light
  query. The party's own held light counts.
- It fades in over a second in palette steps, never a smooth fade.
- While the runes show, clicking the wall (or F) opens it, as a purified
  wall opens. A puzzle condition "runes_read".
- Art from the VFX tool, in the curse greens; log it.
- A test-room station: a room with two lit braziers and a sign.
Run the tests, and show me the room lit, then dark.
```

**7e.7 prompt (Puzzles on floor 1)**

```
Place the puzzles from docs/design/expansion_design.md section 5.
- Room 7: braziers at (18,3) and (20,3); the closet door (18,2) is
  warded until both burn. Move key two to (19,4). The closet holds three
  potions, two flasks of oil and one firewood.
- Room 6: a purge room. Add a plain door at (15,19). A skeleton at
  (17,20), a guard at (16,21), an acid slime at (18,19). The reliquary
  rises at (17,20) with whatever 7g has put in it (a placeholder scroll
  until then). The plate at (18,21) needs weight 3.
- Room 4: lit braziers at (12,19) and (14,17), runes on the north wall
  (13,16), which opens onto (13,15). A sign: "What the light hides."
Redo the walk-through check and run the tests.
```

**7g.1 prompt (Legendary framework)**

```
Do Foundations step 11 first if it is not ticked.

Add legendary items, following docs/design/expansion_design.md section 3
"7g". No design pass is needed: the table there is the design.
- ItemDef.legendary, and a behaviour script using the hooks from step
  11 (on_equip, on_unequip, on_hit, on_kill, on_tick, on_stowed).
- A worn-gold slot frame and a slow shimmer in the inventory, hand
  slots and loot pop-up. Gold, never curse green. Art from PixelLab,
  the shimmer from the VFX tool; log both.
- Its description, powers and price show in the item's tooltip and on
  the character sheet. Not on right-click: that splits a stack in the
  inventory and opens the loot pop-up on the floor.
- GameEvents.legendary_found(item, hero), once per item per run (a run
  flag). 30 XP if Party.add_xp exists. A banter event of the same name.
- Class limits through ItemDef.cant_use, as the spellbook does.
Run the tests.
```

**7g.7b prompt (The Unquenchable)**

```
Add the Unquenchable, a legendary torch, from
docs/design/expansion_design.md sections 2 and 3.
- A light (ItemDef.Type.LIGHT): energy 1.8, range 10, burn_seconds 0
  meaning it never burns down (make 0 mean that everywhere burn time is
  read, and hide the burn bar).
- A curse zone cannot put it out. A critical fail cannot make it slip
  (never_slips). Stowed, it gives no light, like any torch.
- While it is lit in a hand, every monster's sight range is 2 tiles
  longer. Write that in docs/combat_design.md.
- It mutters: a banter speaker of its own, rarely, never in a fight.
  Read docs/tone.md first and show me the lines.
- The Cursed Warden carries it: he is lit by it while he lives, and it
  drops where he falls, always.
Run the tests.
```

**7h.1 prompt (Resting rules into the combat page)**

```
Copy the resting rules and numbers from docs/design/expansion_design.md
(sections 2 and 3 "7h") into docs/combat_design.md. No code. There is no
tinderbox.
```

**7h.2 prompt (Making camp)**

```
Add making camp, following docs/design/expansion_design.md sections 2
and 3 "7h".
- Firewood is an item (stacks to 3). Using it (from a hand, a quick slot
  or the inventory) makes camp, if no living monster is within 4 tiles
  or in sight, the party is not in a fight, and no armed ambush trigger
  is within 2 tiles. Otherwise refuse with a line and spend nothing.
- Camp view: the dungeon view sinks to near black round a small fire
  that lights the walls beside it (a light in the sprite_lights group).
  HP and mana climb evenly to full over 30 s. A Stop button, and any
  movement key, ends it and keeps what was gained.
- A rest clears shaken and sickness, gives the rest of a running meal at
  once, clears spell recasts, and pauses every burn timer.
- Camp spots (DungeonMap.CAMP_SPOTS): old ash on the floor, a symbol on
  the map once seen. The interruption chances in section 2 depend on it.
- Making camp saves the game. F5 and the pause menu still save.
- GameEvents.camp_made and camp_ended(interrupted).
- The fire from the VFX tool, the firewood and ash from PixelLab; log.
- A test-room station replacing the "not built yet" campfire.
Run the tests.
```

**7h.4 prompt (Interrupted rests)**

```
Add interrupted rests with the numbers in
docs/design/expansion_design.md section 2: three rolls a rest, at 10, 20
and 30 s, never in the first 10 s, never two rests running. On one: the
fire spits, the view cuts back, one or two tier 1 monsters appear 2
tiles away on a free tile the party can see, and a fight begins. The
party keeps what it healed and any level it gained. A short sting, not
the ambush build-up. One groggy line once the fight is over.
Run the tests, with a smoke check that seeds the dice for an
interruption and for none.
```

**7i.1 prompt (Levelling rules into the combat page)**

```
Copy the XP table, the level curve, the per-level gains and the perks
from docs/design/expansion_design.md section 2 (and the rules in section
3 "7i") into docs/combat_design.md and the blueprint artifact. No code.
```

**7i.2 prompt (Shared XP)**

```
Do Foundations steps 7 and 8 first if they are not ticked.

Add shared party XP, following docs/design/expansion_design.md sections
2 and 3 "7i".
- Party.add_xp(amount, reason) and Party.level_up_party(): the test
  room's X and U keys already call these names.
- Award XP by listening to GameEvents: monster_killed (by the monster's
  tier), puzzle_solved, wall_broken and wall_purified where they open a
  hidden room, legendary_found, remains_searched, and the ambush's end.
- Everyone shares, dead or alive.
- The log shows the XP as its own short line under the event's line.
- A waiting level shows as a small warm mark on the portrait and is
  applied at the next camp, or at the stairs.
- A thin XP bar on the character sheet.
Run the tests.
```

**7i.4 prompt (Class perks)**

```
Add the level 3 perks from docs/design/expansion_design.md section 2:
Follow-through (Fighter), Firm hand (Cleric), Light fingers (Thief),
Deep breath (Mage). Each is a line of data on the class and one hook in
the system it touches; no special cases by class name. Each shows on the
character sheet with a one-line description (read docs/tone.md first and
show me the four lines). Leave level 5 perks as named placeholders.
Run the tests.
```

**7j.1 prompt (Searchable remains)**

```
Add searchable remains, following docs/design/expansion_design.md
section 3 "7j".
- A prop against a wall on a floor tile; it does not block the tile.
  Four looks from PixelLab following docs/art_style.md. One first, shown
  in the game, for my OK.
- Search with F facing it, or a click, once. Afterwards it looks
  disturbed and the map marks it.
- DungeonMap.REMAINS sets the result: items (dropped on the tile in
  front, taken with the usual clicks and the loot pop-up), a note (a
  small parchment panel), nothing and a dry line, a bite (1-3 damage to
  the searcher through Party.hurt, and a closed bear trap to take), or
  it sits up (a skeleton beside the party; an ordinary fight).
- GameEvents.remains_searched(kind, hero); 5 XP if Party.add_xp exists.
- Banter for each kind (read docs/tone.md first; show me the lines).
- Saved. A test-room station with one of each kind.
Run the tests.
```

**7j.2 prompt (Remains on floor 1)**

```
Place the six remains from docs/design/expansion_design.md section 5:
1 at (8,13) in the alcove: firewood. 2 at (8,9): nothing. 3 at (16,5):
a candle and Bellius's note (ask me for the text). 4 at (20,17):
firewood, with old ash beside it (a camp spot). 5 at (16,15): it bites;
a bear trap and a flask of oil (remove the loose trap at (18,14)). 6 at
(14,19): it sits up. Run the tests.
```

**7k.2 prompt (Bear trap: what is left)**

```
The bear trap is built. Finish it from docs/design/expansion_design.md
section 3 "7k.2": a monster of tier 3 or more can be caught once per
fight; give the trap a weight of 3 for plates; a plague rat is caught
like any tier 1 monster. Update docs/combat_design.md. Run the tests.
```

**7l.2 prompt (Wall sconces you can light and take)**

```
Do Foundations step 7 first if it is not ticked.

Turn the wall torches into sconces, following
docs/design/expansion_design.md sections 2 and 3 "7l".
- DungeonMap.TORCHES entries gain a state: lit, unlit (holding a torch)
  or empty (a bare bracket). Saved.
- Light an unlit one by clicking it with a lit torch or candle in a
  hand, or with a Fireball or a thrown torch. It stays lit.
- Take the torch from a lit or unlit sconce with an empty hand: you get
  a torch with 120 s on it, and the bracket is empty.
- Put a torch into an empty bracket: it lights that stretch for good,
  keeps the burn time it had, and loses none while it hangs there.
  Taken out again, it has that same time.
- So torches are never created: check that lighting a sconce and taking
  its torch back cannot be repeated for free, with a smoke check.
- The map shows a sconce once seen, lit or dark.
- A bracket's art (empty, with an unlit torch) from PixelLab; log it.
- Both kinds in the test room's light room. Run the tests.
```

**7l.3 prompt (Curse zones that snuff flames)**

```
Add curse zones, following docs/design/expansion_design.md section 3.
- DungeonMap.CURSE_ZONES: an id and its tiles.
- Inside one: held torches and candles sputter for a second and go out,
  and will not relight; sconces and braziers will not light; a burning
  torch lying or thrown there goes out; oil will not catch. The
  Unquenchable and spell light are untouched.
- Bless makes a pocket for 20 s: the party's tile and the tiles beside
  it, where flames can be lit and stay lit.
- A thin green haze on the floor of the zone (the VFX tool), visible
  from the tile before it. No message until a flame dies: "The air here
  hates fire."
- A puzzle effect clears a zone for good (a run flag).
- GameEvents.entered_curse_zone and left_curse_zone; banter hooks.
- Nothing above tier 1 may be placed in a zone: warn at load if so.
- A zone in the test room's light room. Run the tests.
```

**7l.4 prompt (Throwing torches)**

```
Let a lit torch be thrown, with the numbers in
docs/design/expansion_design.md section 2. Reuse the thrown-weapon code
and light_field.gd, which already keeps a slipped torch burning on the
floor. It flies up to 4 tiles with its light, does 1-3 fire to a monster
it hits (which recoils if it fears fire), and burns where it lands.
Monsters that fear fire will not step onto its tile. Picking it up sends
it home to the hand it left, as other throwables do. A candle cannot be
thrown. Run the tests.
```

**7l.5 prompt (Flask of oil)**

```
Add the Flask of oil with the numbers in
docs/design/expansion_design.md section 2 and the rules in section 3.
As the old prompt, with these changes:
- Thrown "at the floor" it always lands on the tile in front, never
  under the party.
- "Doused" is a StatusDef with its own row in data/tiers.tres; slimes
  can be doused.
- A burning tile does 2 a second to a monster and 1 a second to a hero.
- The throw is refused, and nothing spent, while the party stands in a
  curse zone.
- Burning oil is a light in the sprite_lights group.
Run the tests.
```

**7l.6 prompt (Light and darkness on floor 1)**

```
Place the light from docs/design/expansion_design.md section 5: the
three lists of sconces (8 lit, 7 unlit with a torch, 10 empty), loose
torches at (15,15) and in room 2, a candle in room 3, the curse zone
over the cave (x 6-10, y 15-19) which lifts when its three plague rats
are dead, and add the -10 to hit for a hero whose tile gets no light
beyond the ambient (weapons only, never spells, never monsters). Then
play the floor three ways and give me the numbers: seconds of torch and
candle left at the Warden's door for a careful run, a careless one, and
a full clear.
```

**Plague rat prompt (replaces the Leftovers line)**

```
Add the plague rat from docs/design/expansion_design.md section 2: tier
1, 5 HP, attack 2, defence 1, damage 1-3, a blow every 1.4 s, a step
every 0.7 s, fears fire. A bite has a 20% chance of the food sickness (6
HP over 6 s, never kills). Drops raw rat meat 40% of the time (6 HP over
6 s, 50% sickness; cooked, 12 HP and none). Art and all four animations
from PixelLab following docs/art_style.md, one picture first for my OK;
a hit effect from the VFX tool; log it. Three nest in the cave at
(8,17), replacing the skeleton at (9,18). Run the tests.
```

**8b.1 prompt (Stats rules into the combat page)**

```
Copy the character generator's rules from
docs/design/expansion_design.md section 3 "8b" into
docs/combat_design.md: six scores, the modifier, the formula table, the
key-score minimums. No races. Then give the four heroes scores that
produce exactly today's numbers and show me the table. No code.
```

**8b.2 prompt (Party screen)**

```
Do Foundations step 8 first if it is not ticked.

Add the party screen from docs/design/expansion_design.md section 3
"8b", at 640x360 in the stone UI style. New Game opens it (after the
intro on a first launch). It shows Brannoc, Brother Felix, Wren and
Fennick in their 2x2 formation with Play already lit: one click starts
the game with the party as it is today. Clicking a hero opens their
editor (next step). Dragging one portrait onto another swaps places, as
in the game. Show me a screenshot of the layout before going on.
```

**8b.3 prompt (Scores and rolling)**

```
Add the hero editor's scores, from docs/design/expansion_design.md
section 3 "8b". The class of a slot cannot be changed. Six scores,
rolled 4d6 dropping the lowest, all six at once, with a quick tumble of
the numbers and no limit on rerolls. Under them, the HP, attack,
defence, mana and crit they give, with the change from the ready-made
hero in the sheet's better/worse colours. A roll below 9 in the class's
key score is refused with a line. A Reset button puts the ready-made
scores back. Saved with the hero. Run the tests.
```

**8b.4 prompt (Portrait and name)**

```
Add the name and portrait to the hero editor. A name of up to 14
letters with a Random button (a short list per class; read docs/tone.md
and show me the lists first). Three portraits per class to flick
through: the one that exists and two new ones from PixelLab at the same
size and style, generated one at first for my OK, with hurt and dead
versions derived as the existing ones were. Log them. Run the tests.
```

**8b.5 prompt (Finishing the generator)**

```
Finish the party screen: starting gear stays the class's own
(CharacterDef.start_hands and start_quick); the formation chosen on the
screen is the one the game starts in; the save stores scores, name and
portrait, and an older save loads with the ready-made heroes. There is
no Quick Party button: the screen already starts full. Add a paragraph
to CLAUDE.md. Run the tests.
```

---

## 8. Still open

Nothing blocks the build. Three things will need your eye when they arrive, and each prompt above already stops to
ask:

- **Bellius's note.** One short text, in his voice. Yours to write, or to approve.
- **The mana change.** Play it before anything is balanced on top of it.
- **How dark the middle of the floor feels** once the sconces go out. The numbers say it works; the corridor will say
  whether it is fun.
