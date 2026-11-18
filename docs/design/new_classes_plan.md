# Eight new classes: the plan

Revised 18 Nov 2026 to fit `docs/design/expansion_design.md` (first written 15 Nov). A design document only: no code
has been written for any of it.

**The rule: four roles, three classes each.** The party is always four heroes, one per role. A slot's role never
changes; the class inside it can. Every party therefore has a healer to be smug, a front-liner to be hit, a sneak to be
cynical and a caster to be frightened, and the banter always has someone to say each part. This replaces decision 9's
"one of each class" with "one of each role", and keeps its promise.

| Role | Classes | Ready-made hero |
|---|---|---|
| Front line | Fighter, **Barbarian**, **Monk** | Brannoc (Fighter) |
| Healer | Cleric, **Druid**, **Paladin** | Brother Felix (Cleric) |
| Sneak | Thief, **Ranger**, **Bard** | Wren (Thief) |
| Caster | Mage, **Necromancer**, **Spellsword** | Fennick (Mage) |

New Game is still one click: the ready-made four are already chosen.

## Contents

1. Decisions
2. Roles in the data and on the party screen
3. Stats: the 8b formulas, level 1, levels and perks
4. The classes: abilities, numbers and how each meets the existing systems
5. Things that would be unfair, and what this plan does about them
6. Banter
7. Groundwork and build order, with prompts
8. Portraits
9. Still open

---

## 1. Decisions

Eleven questions, all answered.

**From the first plan (answered 18 Nov):**

| # | Question | Decision |
|---|---|---|
| 1 | Party size | Four, one per role. The two spare panels on the six-hero screen are for minions. |
| 2 | Using an ability | A small button beside the hero's name opens their list, in the spell list's frame. |
| 3 | The Necromancer's minion | It fills a spare party panel. |
| 4 | Systems that do not exist yet | No stand-ins. The classes are built after 7h resting and 7i levelling, so "per rest" and "per level" use the real systems. Where a class leans on something that will still not exist (fear, stamina, hunger), it gets something that does, or a small real version is built as groundwork. |
| 5 | The Paladin's Vow | It stays, light: broken when a fight ends with a monster alive; he loses his aura until he next wins a fight. |
| 6 | Hero names | The placeholders below, for now. |

**From this revision (answered 18 Nov, "your picks"):**

| # | Question | Decision |
|---|---|---|
| 7 | The Paladin's foil, since he and the Cleric share a role and never meet | The **Bard**: the Bard improves every event for his ballad, and the Paladin cannot let a lie stand. The Necromancer pair stays too. |
| 8 | Who inherits the Bellius arc (roadmap Ideas inbox) when Wren is not there | **Whoever holds the sneak slot is Bellius's relation.** The Bard is the natural fit (the gift is a song he finally gets right); the Ranger takes it grudgingly. The healer is furious either way. |
| 9 | The floor 1 legendaries | **By role, not class.** Grudge for any front-liner who can hold a sword (the Monk refuses it, and Grudge takes offence); Penitent's Mace for any healer (not the Druid in beast form); the Unquenchable for anyone. |
| 10 | Can the Necromancer raise a fallen hero? | **No.** He offers, politely, every time, and is refused. Only the Scroll of Resurrection brings a hero back. |
| 11 | How the Bard's songs sound | **A short lute phrase** of 2 or 3 seconds when a song starts and when it stops, and a small note on his panel while it plays. Nothing loops. |

**Where this differs from the brief, and why**

- **"Epic" and "career pivot" are banned or modern words** in `docs/tone.md` (section 3, rule 4). The Bard writes a
  *ballad*, and the Spellsword calls it *a change of calling*.
- **There are no goblins.** "This is Gerald. Gerald was a goblin." becomes "This is {minion}. {minion} was a {was}.",
  where `{was}` is whatever the corpse was ("a skeleton guard").
- **The Paladin is never the Cleric's straight man**, because they share the healer role (decision 7).
- **Fear and stagger do not exist and are not planned.** The Barbarian's rage resists the grab instead, as the brief
  suggests, and the Paladin's aura is +1 defence.

---

## 2. Roles in the data and on the party screen

**In the data**

- `CharacterDef` gains `role`: `front`, `healer`, `sneak` or `caster` (a key, never shown). The existing four get
  theirs; the eight new ones are new files in `data/party/`.
- **A class list** (`data/classes.tres`, one entry per class file) is what the party screen and the save read. The
  ready-made party is four entries of it.
- `Party.hero_defs` stays a list of four `CharacterDef`s; it is filled from the party screen instead of being fixed in
  `main.tscn`. `hero_index` keeps meaning "which of the four", so formation, saving and the HUD need no change in kind.
- **A save remembers the class in each slot** (its `class_id`). An older save, with none, loads as the ready-made four.
- **The role decides the starting kit's shared part.** The healer slot always starts with the lit torch and two
  candles, whoever the healer is, because the light economy (expansion design section 2) assumes the party has them.
  The class adds its own gear.
- **The tests keep the ready-made four**, so the 192 smoke checks still mean what they meant. A new
  `tests/classes_test.gd` builds parties with each new class.

**On the party screen (8b.2's screen, with a class choice per slot)**

- Four slots in the 2x2 formation, as 8b plans. Each slot is labelled with its role and shows the class's portrait,
  the hero's name and one plain line on what the class does ("Rage builds as he is hurt.").
- **Arrows either side of the class name** step through that role's three classes. A slot can never hold another
  role's class.
- Changing the class resets that slot's name, portrait and scores to the class's defaults. 8b's rename, portrait
  picker and score reroll then work on whatever class is in the slot.
- **Play is lit from the start.** Clicking it with the ready-made four plays exactly as today.

The addendum to the 8b page of `expansion_design.md` says the same, shorter.

---

## 3. Stats

### The 8b formulas, per class

The formula table in expansion design 8b stands. Each class says which score feeds it:

| Class | Key score (needs 9+) | Attack from | Mana from | Special |
|---|---|---|---|---|
| Fighter | Strength | Strength | - | |
| Barbarian | Strength | Strength | - | HP takes 3 x the Constitution modifier, not 2 |
| Monk | Dexterity | Dexterity | - | Defence takes up to +2 from Dexterity, not +1 |
| Cleric | Wisdom | Strength | 2 x Wisdom | |
| Druid | Wisdom | Strength | 2 x Wisdom | |
| Paladin | Strength | Strength | 1 x Wisdom | |
| Thief | Dexterity | Dexterity | - | |
| Ranger | Dexterity | Dexterity | - | |
| Bard | Charisma | Dexterity | 2 x Charisma | |
| Mage | Intelligence | Strength | 2 x Intelligence | |
| Necromancer | Intelligence | Strength | 2 x Intelligence | |
| Spellsword | Intelligence | Strength | 1 x Intelligence | |

**Charisma's job (monsters hit the lowest)** now does useful work: the Bard's key score makes monsters pass him by,
and a Barbarian who rolled low Charisma draws the blows, which is what a tank wants. Each ready-made hero's scores give
modifiers of 0 where they count, so an untouched hero plays as the table below says.

### Level 1

Today's four from expansion design section 2, then the new eight. Seconds per action is 2.0 - 0.15 x speed (at least
0.8): speed 2 is 1.70, 3 is 1.55, 4 is 1.40.

| Role | Class (hero) | HP | Atk | Def | Speed | Bare hands | Mana | Crit base | Helpless crit | Starts with |
|---|---|---|---|---|---|---|---|---|---|---|
| Front | Fighter (Brannoc) | 30 | 4 | 4 | 3 | 2-8 | 0 | 4 | 10 | nothing |
| Front | **Barbarian (Hrolf)** | 36 | 4 | 2 | 3 | 2-8 | 0 | 5 | 10 | nothing |
| Front | **Monk (Tam)** | 24 | 4 | 5 | 4 | 3-8 | 0 | 8 | 15 | nothing (and never anything) |
| Healer | Cleric (Brother Felix) | 24 | 3 | 3 | 2 | 2-6 | 10 | 3 | 8 | holy symbol, torch, 2 candles |
| Healer | **Druid (Morwen)** | 22 | 2 | 2 | 2 | 1-6 | 10 | 3 | 8 | torch, 2 candles |
| Healer | **Paladin (Ser Aldric)** | 28 | 4 | 4 | 2 | 2-8 | 6 | 5 | 10 | torch, 2 candles |
| Sneak | Thief (Wren) | 18 | 3 | 2 | 4 | 1-6 | 0 | 8 | 25 | 6 darts, dagger |
| Sneak | **Ranger (Marra)** | 20 | 3 | 2 | 3 | 1-6 | 0 | 8 | 15 | bow, 12 arrows, dagger |
| Sneak | **Bard (Odo)** | 18 | 2 | 2 | 3 | 1-4 | 10 | 3 | 8 | dagger |
| Caster | Mage (Fennick) | 14 | 1 | 1 | 2 | 1-4 | 12 | 1 | 8 | spellbook |
| Caster | **Necromancer (Aubrey)** | 16 | 1 | 1 | 2 | 1-4 | 12 | 1 | 8 | dagger |
| Caster | **Spellsword (Corwin)** | 22 | 3 | 3 | 3 | 2-6 | 6 | 5 | 10 | dagger |

Nobody new starts with a weapon that lies on floor 1 (the war hammer, the mace, the swords), so no class takes a find
away from the floor. The Ranger's bow is the exception: it is his whole point, and the floor's bow becomes a spare.

**Is each role fair to itself?** Against a skeleton (attack 3), a hero's hit chance taken is 60 + 5 x (3 - defence):

- **Front.** Effective HP (HP divided by the chance to be hit): Fighter 30 / 55% = 55; Barbarian 36 / 65% = 55; Monk
  24 / (50% x 85% after dodging) = 56. Even. The Fighter is best with gear (a long sword and leather armour take him to
  67), the Barbarian best in a burst (rage) but cannot drink potions, the Monk best with nothing and can never improve
  by finding things. Their damage at level 1 is close: about 2.3, 2.3 and 2.8 a second bare-handed, with the Fighter
  ahead once he holds a long sword (3.2).
- **Healer.** The Cleric heals most and fastest (Heal, 4-10 for 4 mana) and has Bless. The Druid heals more per mana
  but slowly, and can become a tank or a scout. The Paladin heals least (Lay on Hands, once a rest) but is a second
  front-liner and gives the whole party +1 defence, which takes about a tenth off every blow it receives.
- **Sneak.** The Thief crits and sets traps. The Ranger shoots best and warns of what is ahead. The Bard does little
  damage but makes the other three better.
- **Caster.** The Mage has the big spells (Fireball, Hold Monster). The Necromancer turns corpses into bodies and
  armour. The Spellsword is half a fighter and half a caster.

### Levels and perks (7i style)

The existing four are in expansion design section 2. The new eight, in the same shape:

| | Each level | Level 2 | Level 3 (perk) | Level 4 | Level 5 (perk, floor 2) |
|---|---|---|---|---|---|
| Barbarian | +7 HP | +1 attack | **Blood up:** every fight starts with half a rage bar | +1 defence | Unstoppable: rage lasts twice as long |
| Monk | +4 HP, fists +1 (top of the range) | +1 defence | **Still water:** dodges 25% of blows, not 15% | +1 defence, fists +1 (bottom) | Open hand: a counter knocks the monster back a tile |
| Druid | +4 HP, +2 mana | - | **Deep roots:** a poultice heals 18 over 12 s, not 12 | +1 defence | Old growth: a shape lasts twice as long |
| Paladin | +6 HP, +1 mana | +1 attack | **Steadfast:** Lay on Hands twice a rest | +1 defence | Beacon: the aura is +2 defence |
| Ranger | +4 HP | +1 attack | **Keen nose:** tracking reaches 3 tiles, and the tiles to each side | +1 attack | Volley: every third arrow costs nothing |
| Bard | +4 HP, +2 mana | +1 attack | **Encore:** songs drain half as fast | +1 defence | Crescendo: songs work a quarter better |
| Necromancer | +3 HP, +3 mana | - | **Dear departed:** a minion rises with all of the monster's HP, not half | +1 defence | A third minion |
| Spellsword | +5 HP, +1 mana | +1 attack | **Spellstrike:** learns Magic Missile | +1 defence | Twin edge: two enchantments at once |

The Monk's fists by level: 3-8, 3-9, 3-10, 4-11, 4-12. His defence: 5, 6, 6, 7, 7.

---

## 4. The classes

**How abilities work.** A class's abilities are `SpellDef` files listed on the class (`CharacterDef.abilities`), so
mana, the action wait, recast waits, sounds and the spell list all work as they do now. The small button beside the
hero's name opens the list. The Cleric and the Mage keep their holy symbol and spellbook exactly as now; the new
classes need nothing in a hand. The new effect kinds (a song, a shape, an enchantment, a raise, a corpse cost) are
new fields on `SpellDef`.

**How each meets the existing systems** is the last block of every class. "Systems" means: light and the dark's -10,
fire and oil (7l.5), curse zones (7l.3), traps (7k), Hold Monster and the tier table, ambushes and the giant hand's
grab (7d), resting (7h), levelling (7i), the legendaries (7g) and fallen adventurers (7j).

### Barbarian (front line)

**Rage.** A rage bar sits where a caster's mana bar is, in blood red.
- It fills 5 points for each HP he loses and 10 for each monster he kills (full is 100: about 20 HP of hurt).
- At full it **ignites for 10 seconds**: his blows do half as much damage again, and **he cannot be grabbed** (below).
  Then the bar is empty.
- Out of a fight it drains 5 points a second.

**Won't use potions or scrolls.** A potion or a scroll in his hands, quick slots or inventory does nothing when used:
"{name} won't touch it." (a new `CharacterDef.refuses` list of item kinds, checked wherever an item is used).
Food, heals from the healer, and a Scroll of Resurrection read over his corpse by someone else all work.

**How he meets the systems**
- **The grab.** While raging, the giant hand cannot take him; it takes another front-row hero, or nobody if he stands
  alone. If the hand already holds someone, his first raging blow on it makes it let go.
- **Tentacles and lock-ins** still hold the party in place, raging or not (see section 5, item 3).
- **Light.** He fights the dark like anyone: -10 to hit with no light on his tile.
- **Resting** empties the bar. **Levelling:** Blood up at 3.
- **Grudge** (decision 9) suits him: a sword he can hold.

### Monk (front line)

**No weapons, no armour.** Two new class flags, checked wherever the Fighter's are. He may carry a torch or candle:
a light is not a weapon, and a Monk who cannot hold a light leaves the party in the dark.

**Fists and defence rise with level** (section 3's table).

**Dodge and counter.** 15% of blows that would have landed on him miss instead ("{name} sways aside."). If the
attacker is in front of the party and he is in the front row, he strikes back at once for his fists' damage, a
normal hit roll. A dodge never happens while he is grabbed.

**Refuses the takings.** His backpack holds 4 things, not 12, and Take all passes him by. The loot pop-up still lists
him ("LIGHT PACK"), and a single item can still go to him; the banter carries the refusal.

**How he meets the systems**
- **The grab** holds him like anyone, and he cannot dodge while held.
- **Hold Monster:** his counter on a held monster gets his helpless crit (15).
- **Resting** changes nothing for him. **Levelling** is where all his power comes from.
- **Grudge** he refuses: a line from each of them.
- **Leather armour** cannot go on him (refused at the slot, as `cant_use` refuses it for the Mage today).

### Druid (healer)

**Poultice** (4 mana, a hero): heals 12 HP over 12 seconds on its own track, so it does not cancel a meal and a meal
does not cancel it. A second poultice on the same hero restarts it.

**Reclaim** (5 mana, the tile in front): the Druid's answer to Bless's other job. It purifies a corrupted wall the same
way Bless does (one for a thin wall, two for a thick one), and cast with nothing in front it makes Bless's curse-zone
pocket (20 seconds, one tile round the party). Without it, a party with no Cleric could not open floor 1's corrupted
walls (section 5, item 1).

**Bear and wolf** (3 mana each). She changes for 30 seconds, or until she picks "Change back" from her list. A
different portrait, her own HP carried over, hands become paws: **no casting, no items, no quick slots** while changed.

| | Attack | Defence | Damage | Speed | Also |
|---|---|---|---|---|---|
| Bear | 4 | 6 | 3-9 | 2 | The tank |
| Wolf | 4 | 3 | 2-6 | 5 (1.25 s) | Smells monsters as the Ranger tracks them; no -10 in the dark |

**How she meets the systems**
- **Light.** **Changing stows any light she holds** (it stops burning, keeping its time; section 5, item 6). The wolf
  ignores the dark's -10; the bear does not.
- **Curse zones:** Reclaim's pocket works as Bless's does.
- **Penitent's Mace:** hers to use, but not in beast form.
- **The grab:** a grabbed Druid cannot change shape or change back.
- **Resting** returns her to her own shape. **Levelling:** Deep roots at 3.

### Paladin (healer)

A fighter who heals a bit. No Heal, no Bless, no holy symbol.

**Lay on Hands** (no mana, a hero): heals 12 HP. Once per rest (7h); twice at level 3. Refused on the Necromancer.

**Aura.** While he lives and his Vow holds, every hero has +1 defence. It adds to Shield.

**Smite** (2 mana): his next landed melee blow within 10 seconds does +4 to 8 against an undead or cursed monster,
+1 to 2 against anything else.
- Two new `MonsterDef` flags: `undead` (skeleton, skeleton guard, the Warden) and `cursed` (slime, acid slime, the
  Warden, tentacles, the giant hand). The plague rat is neither.
- **The holy flash also burns every minion in the party for 3**, wherever it stands (the brief's "including the
  Necromancer's minions"; minions are allies, so this is the only way he hits them).
- Cast with a corrupted wall in front, Smite purifies it as a Bless would; cast with nothing in front, it makes the
  curse-zone pocket (section 5, item 1).

**The Vow.** When a fight ends (`GameEvents.fight_ended`) while a monster **that struck or was struck in it** is still
alive, the Vow is broken: no aura until he next wins a fight (one that ends with every such monster dead). The log
says it plainly, and he says something worse. Reaching the stairs with a fight unfinished breaks it too.

**How he meets the systems**
- **Resting** restores Lay on Hands, not the Vow. **Levelling:** Steadfast at 3.
- **Hold Monster** and traps: a held or trapped monster that the party walks away from still counts as left alive.
- **Penitent's Mace** suits him: front row, a healer, and he does not complain.

### Ranger (sneak)

**Tracking.** When a monster stands within 2 tiles in front, along open tiles (not through walls or shut doors), a
small paw mark shows at the top of the 3D view, and the log says "{name} smells something ahead." once per monster.
It works in the dark.

**Launchers.** With a bow or slingshot: +2 attack, and half his missed arrows or stones land on the floor to be picked
up again (today every shot is lost, hit or miss).

**Eats anything.** Raw rat meat and mouldy bread never make him sick (7h's raw meat, today's mouldy bread).

**How he meets the systems**
- **Ambushes:** tracking cannot see an ambush, because its monsters do not exist until it springs. The scare is safe.
- **Fallen adventurers:** a body that sits up is not a monster until it does. Safe too.
- **Light:** tracking ignores it; his shots still take the dark's -10 like anyone's.
- **Traps:** he sets them at the normal speed; the Thief stays the fastest.
- **Levelling:** Keen nose at 3. **Bellius** (decision 8): he can be the relation, grudgingly.

### Bard (sneak)

**Songs.** Three, one at a time, chosen from his list; choosing the one that is playing stops it. Starting a song
costs 1 mana, and it drains 1 more every 3 seconds while it plays. From full mana that is about a minute, longer
between fights as mana returns.

| Song | Effect on the party (not on the Bard himself) |
|---|---|
| Marching song | Every hero's action wait is 15% shorter |
| Supper song | Food heals in two-thirds of the time (the same amount) |
| Patience song | Mana returns half as fast again |

The song stops when his mana runs out, when he dies, when the party makes camp and when he is grabbed. A small note
on his panel shows which song is playing. **Sound** (decision 11): a short lute phrase when each song starts, one
when any song stops, and nothing looping: four sounds, listed in `docs/asset_log.md` wherever they come from.

**How he meets the systems**
- **Not the Bard himself**, or Patience would keep his own songs going for ever.
- **Ambushes:** the build-up ignores input, so no song starts during it. A song already playing carries on.
- **Resting** stops the song. **Levelling:** Encore at 3.
- **Bellius** (decision 8): the natural relation. The class hero is not Bellius, who escaped long ago and is kept for
  game 2 (roadmap Ideas inbox).

### Necromancer (caster)

**Corpses** (groundwork, not a stand-in). A slain skeleton, skeleton guard or plague rat leaves a corpse on its tile
for 45 seconds: a small heap on the floor, with a placeholder picture until PixelLab art. Corpses do not block, sit
beside floor items and never appear on the map. Slimes, tentacles, the giant hand and minions leave none. **The
Warden's corpse crumbles at once** (section 5, item 9). They are called *corpses*, not remains, so they are never
confused with 7j's fallen adventurers.

**Raise Dead** (6 mana, the corpse in front). It becomes a minion in a spare panel (positions 4 and 5, the bottom
pair of the six-hero screen). At most two.
- Half the dead monster's HP (skeleton 6, guard 10, rat 3), and its attack, defence, damage and blow timing.
- **It strikes by itself, but only from the front row.** Drag it there like any hero; the hero it swaps with goes to
  the spare panel.
- It carries nothing and is never healed: the Cleric, the Paladin, potions and food do nothing for it.
- It falls apart after 90 seconds, at 0 HP, at the end of the level, or when the party wakes from a rest.
- **It is named** from a list (Gerald, Maud, Edwin, Agnes, Tom, Pip, Hilda, Nell, Bertram, Ysolde, Duncan, Ida),
  shown on its panel and in the log. Short names, so a line with two of them stays under 55 characters.
- A kill by a minion counts for the party's XP.

**Life Drain** (4 mana, up to 4 tiles ahead, never misses): 3 to 7 damage, and he heals half of it, rounded up.
**An undead monster gives nothing back** ("Nothing in it.").

**Bone Armour** (3 mana, the corpse in front, a hero): uses the corpse up; that hero has +3 defence for 40 seconds.
It does not add to Shield: the larger of the two counts.

**Refused healing.** The Cleric's Heal and Bless and the Paladin's Lay on Hands are refused on him, cost nothing, and
fire a banter event. The Druid's poultice, potions and food work.

**A fallen hero** (decision 10): he offers to raise them, every time, and is refused. Raise Dead never targets a hero.

**How he meets the systems**
- **The third row.** With minions there are three rows: front (0, 1), middle (2, 3) and back (4, 5). A blow from
  behind lands on the rearmost row that holds anyone, so a minion at the back shields the casters. Who can swing is
  unchanged: the front row, or a middle-row hero whose front-row partner is dead.
- **The grab:** the giant hand can take a minion in the front row, which is a fine use for one.
- **Light:** minions need none and take no -10 in the dark.
- **Traps:** minions step over the party's traps, as the party does.
- **Resting:** a minion keeps watch. A rest with a minion standing is interrupted half as often, and the minion falls
  apart when the party wakes. Corpses are gone by morning.
- **Saving:** minions are saved (kind, name, HP, time left); corpses are not. A loaded game has no corpses.
- **Levelling:** Dear departed at 3.

### Spellsword (caster)

**Enchant** (3 mana, the melee weapon in his hand). One at a time, for the next 4 landed hits or 20 seconds,
whichever comes first.

| | Each landed hit | Fits these rules |
|---|---|---|
| Fire | +2 to 4 fire | Counts as a torch's fire: a monster that fears fire recoils; a doused monster takes +6 and burns (7l.5). Puts the blade's glow on his tile: a small light (0.6, 3 tiles), so no -10 in the dark for him. |
| Frost | The monster is slowed for 4 seconds: it steps and strikes 50% slower | A new status file, `slowed` (the status system already has `move_time_scale` and `attack_time_scale`), with its own row in the tier table: 100 / 100 / 60 / 30%, tiers 3-4 half the time. |
| Shock | A 25% chance the monster loses its next blow (10% at tier 3 or 4) | Its attack timer starts again. Does nothing to a held monster, which is not swinging anyway. |

He knows nothing else until level 3 brings Magic Missile.

**How he meets the systems**
- **Oil:** an oiled weapon (next 3 hits +2 fire) and a fire enchantment do not add up; the larger counts.
- **Curse zones:** a fire enchantment goes out inside one, like any flame. Frost and shock work.
- **Hold Monster** and frost together: held wins while it lasts, then slowed takes over.
- **Resting** ends an enchantment. **Levelling:** Spellstrike at 3.

---

## 5. Things that would be unfair, and what this plan does about them

1. **Only Bless purifies corruption and makes the curse-zone pocket.** A party without the Cleric could never open
   floor 1's corrupted walls (one of them is the puzzle that opens `gate_n`). Fixed: the Druid's Reclaim and the
   Paladin's Smite do both.
2. **Only the Cleric starts with the torch.** Fixed: the light belongs to the healer slot.
3. **The brief says rage stops him being "held fast" by tentacles.** But "held fast" is the ambush lock-in on the whole
   party: a raging Barbarian would walk the party out of a sealed ambush and skip it. This plan makes rage stop the
   **grab** only. Tentacles still pin the party until they die.
4. **A Barbarian with a Paladin is the thinnest healing in the game**: he drinks nothing and the Paladin heals 12 a
   rest. That is a real choice, not a bug, but the party screen's one-line descriptions should make it visible.
5. **The Vow and a monster watching through a portcullis.** The fight tracker ends a fight 12 seconds after the last
   blow even if a monster is still aware of the party. Counting only monsters that struck or were struck stops a
   watcher behind bars breaking the Vow.
6. **A Druid carrying the party's torch goes into bear form.** The torch is stowed and the corridor goes dark. Fair,
   and visible, but the log must say it ("{name}'s torch goes out as fur comes in.").
7. **A Monk who cannot hold a light** would leave a Monk-heavy party unlit. A light is not a weapon, so he can.
8. **Life Drain on floor 1** heals nothing from the undead, who are most of the floor. Balanced by Raise Dead and
   Bone Armour, which only the undead (and rats) feed.
9. **Raising the Warden** would give the party an 80 HP boss as a pet right before the stairs, and he carries the
   Unquenchable. His corpse crumbles.
10. **Smite and minions.** 3 damage a Smite kills a skeleton minion (6 HP) in two. That is the joke, and the
    Necromancer will mention it.
11. **No Hold Monster without the Mage.** The Warden's fight is harder for a Necromancer or Spellsword party. Traps
    still work on him once a fight, and frost slows him. Acceptable.
12. **Existing lines that name a job.** "Shut up, cleric!" is wrong when the healer is a Druid. Every existing line that
    names a job, or answers a particular class, gets a `with` condition (section 6), so it only fires when that class
    is there.

---

## 6. Banter

Read with `docs/tone.md`: 40 characters of speech, 55 at most; `{name}` the speaker, `{target}` the hero the line is
about; no typed hero names; no "epic", "loot", "boss", "level" or other banned words; one exclamation mark, for alarm
or a battle cry only; capitals for the Mage and Grudge only; nothing over a scare. Each new class gets a voice entry
in `docs/tone.md` section 6 when it is built (prompt C.3).

**What the engine needs** (prompt C.3)

- **Role speakers.** A line's speaker may be `role:front`, `role:healer`, `role:sneak` or `role:caster`: whoever holds
  that slot. **A class line wins; a role line speaks only when the slot's class has no line for that event.** So no
  party is ever silent at the moments that matter.
- **`with`**: a list of class ids that must all be in the party (alive) for the line, and its replies, to be said.
  Pair lines use it; the old lines that name a job get it.
- **New placeholders:** `{minion}` (the minion's name) and `{was}` (what it was, lower case: "skeleton guard").
- **New events:** `rage_full`, `item_refused`, `dodge`, `loot_refused`, `shapeshift` (context `form`), `change_back`,
  `poultice`, `lay_on_hands`, `smite`, `minion_smitten`, `vow_broken`, `vow_restored`, `tracking`, `song_started`
  (context `song`), `song_stopped`, `minion_raised`, `minion_fell`, `life_drain`, `bone_armour`, `heal_refused`,
  `enchant` (context `kind`), `scroll_read`. Several are `GameEvents` signals, so other systems can hear them too.
- **The banter test** checks every new line against the tone guide, as it does now, and also that every class has a
  line, or its role has a line, for each of: `fight_started`, `hero_died`, `hero_revived`, `ambush_warning`,
  `ambush_started`, `ambush_over`, `boss_seen`.

The line counts below: Barbarian 17, Monk 15, Druid 15, Paladin 15, Ranger 15, Bard 25, Necromancer 15, Spellsword 15,
16 role lines and 42 pair lines (in 21 exchanges).

### Barbarian (Hrolf): takes everything literally; fights the dark itself

Plain, slow words, no jokes he knows about. Not the Fighter's Scots ("aye", "wee" stay Brannoc's).

| Event | Line |
|---|---|
| `fight_started` | Good. Something to hit. |
| `rage_full` | Now I am angry. |
| `light_out` | The dark took it. I'll take it back. |
| `light_out` | Come out, dark. Fight me properly. |
| `item_refused` (a potion) | I don't drink from tiny bottles. |
| `item_refused` (a scroll) | I don't read. I won't start now. |
| `ambush_warning` | Something's coming. Good. |
| `puzzle_solved` | It was a door. Why was it a riddle? |
| `hero_died` | Who did that? Point at it. |
| `hero_revived` (himself) | I was winning. Who stopped me? |
| `crit` | Again. |
| `fail` | My hand slipped. Something will pay. |
| `mana_low` (someone else) | Hit it with the book, then. |
| `wall_broken` | That wall started it. |
| `boss_seen` | Big one. More to hit. |
| `corruption_bounce` | The wall ate my hit. I'll eat the wall. |
| `eat` | Food is food. |

### Monk (Tam): serene about everything, including being eaten

Calm, complete, short. Never hurried, never cross.

| Event | Line |
|---|---|
| `fight_started` | Breathe. It will pass. |
| `dodge` | Not today. |
| `dodge` | It missed. It was meant to. |
| `hero_hurt` (himself) | Being eaten is also a way to travel. |
| `loot_refused` | I carry nothing. It is lighter. |
| `item_picked_up` (someone else) | Each thing you carry carries you. |
| `hero_died` | {target} has gone ahead of us. |
| `hero_revived` (himself) | I was nearly at peace. Thank you. |
| `boss_seen` | He is only a storm. Storms pass. |
| `light_out` | The dark was here first. Be polite. |
| `crit` | Ah. There it is. |
| `eat` | Bread. Enough. |
| `ambush_over` | Well. That happened. Breathe. |
| `mana_low` (someone else) | Then rest. The well refills. |
| `fight_ended` | Still here. All of us. Good. |

### Druid (Morwen): furious at what the curse did to the land; talks to the fungus

| Event | Line |
|---|---|
| `corruption_bounce` | Look what it did to the stone. |
| `corruption_purified` | Grow back. Go on. You're safe. |
| `fight_ended` | Hush, little ones. They've gone. |
| `fight_started` | Something here needs composting. |
| `shapeshift` (bear) | Better. |
| `shapeshift` (wolf) | I can smell all of you. Wash. |
| `change_back` | Fur in my mouth. Every time. |
| `hero_died` | Back to the soil, {target}? Not yet. |
| `poultice` | Chew this. Don't ask what's in it. |
| `eat` (mouldy bread) | That mould has a name. Spit it out. |
| `light_out` | Good. The fungus prefers it. |
| `mana_low` (herself) | The land's given all it has. |
| `monster_killed` (a slime) | Even that was a pond once. |
| `wall_broken` | Stone breaks. Stone forgives. Mostly. |
| `puzzle_solved` | The moss knew. Nobody asked it. |

### Paladin (Ser Aldric): sincere, earnest, painfully good

The only hero who means every word. He apologises, which the Cleric never does.

| Event | Line |
|---|---|
| `fight_started` | Stand fast. We do this honestly. |
| `lay_on_hands` | Be well, {target}. I mean it. |
| `vow_broken` | We left one alive. I'll carry that. |
| `vow_restored` | There. That's put right. |
| `smite` | In the Light's name. |
| `hero_died` | {target} fell bravely. I'll say so. |
| `hero_revived` (himself) | Thank you. Truly. I owe you. |
| `item_picked_up` | We should ask whose that was. |
| `mana_low` (someone else) | No shame in it, {target}. Rest soon. |
| `crit` | A fair blow. |
| `fail` | My fault entirely. Sorry. |
| `puzzle_solved` | Well reasoned, all of you. |
| `heal_refused` (by him) | I can't. I'm sorry. I truly am. |
| `boss_seen` | Yield, and you'll be treated fairly. |
| `trap_triggered` | A trap. Is that fair? I suppose. |

### Ranger (Marra): grim survivalist; everything is edible

| Event | Line |
|---|---|
| `tracking` | Something ahead. Two paces. |
| `tracking` | Wet bones. Close. Ahead. |
| `monster_killed` (a plague rat) | That's supper. |
| `eat` (mouldy bread) | Mould's just bread trying harder. |
| `monster_killed` (a slime) | Tastes of nothing. Filling, though. |
| `fight_started` | Keep low. Let me work. |
| `hero_died` | Cover {target}. Rats come quick. |
| `light_out` | Eyes adjust. Mostly. |
| `crit` | Clean. |
| `fail` | Damp string. Not my fault. |
| `item_picked_up` (food) | Smell it first. Then eat it anyway. |
| `boss_seen` | Big. Slow. Aim for the joints. |
| `hero_revived` (himself) | Lost a day. Who ate my boots? |
| `ambush_over` | Should have smelt that. Didn't. |
| `trap_triggered` | Good snare. I'd eat what's in it. |

### Bard (Odo): writing a ballad about the party, and improving it; the Cleric's nemesis

Theatrical, delighted with himself, rewrites every event as it happens. The most lines of anyone.

| Event | Line |
|---|---|
| `fight_started` | Verse four. The heroes, unafraid. |
| `fight_ended` | Close. I'll write it closer. |
| `crit` | Mark that. That's going in. |
| `fail` | We'll call that a feint. |
| `hero_died` | {target} dies nobly. Revised. |
| `hero_died` | I'll give {target} a better death. |
| `hero_revived` (someone else) | A return. The crowd weeps. |
| `hero_revived` (himself) | Was I tragic? Tell me I was tragic. |
| `mana_low` (himself) | Not now. I'm mid-chorus. |
| `song_started` (marching) | From the top. And march. |
| `song_started` (supper) | A song for supper. Eat up. |
| `song_started` (patience) | Something slow. Breathe with me. |
| `song_stopped` | And that's the end of that one. |
| `item_picked_up` | A gleaming prize, I'll call it. |
| `puzzle_solved` | Our hero solves it. That's me. |
| `light_out` | And darkness fell. Good line. |
| `boss_seen` | At last, a villain I can rhyme. |
| `ambush_over` | Ambushed by twelve. It was three. |
| `eat` | Stale bread. I'll write feast. |
| `trap_triggered` | Cunning. I'll take the credit. |
| `wall_broken` | The wall fell. I'll add thunder. |
| `lever_pulled` | Nothing rhymes with portcullis. |
| `hero_hurt` (himself) | Ow. I'll write that I laughed. |
| `ambush_warning` | This is the bit where it goes wrong. |
| `monster_killed` | Another foe for the second verse. |

### Necromancer (Aubrey): polite, well-spoken, deeply creepy; sentimental about bones

| Event | Line |
|---|---|
| `minion_raised` | This is {minion}. {minion} was a {was}. |
| `minion_raised` | Up you get, {minion}. There's a dear. |
| `minion_fell` | Goodbye, {minion}. You were good. |
| `minion_fell` | Oh, {minion}. All over the floor. |
| `hero_died` (decision 10) | I could help {target}. No? Fine. |
| `heal_refused` | I'm not offended. I'm used to it. |
| `life_drain` | Just a sip. |
| `bone_armour` | Wear it. They'd have wanted that. |
| `fight_started` | Try not to break them. I need them. |
| `monster_killed` | Oh, that one had lovely bones. |
| `light_out` | The dark. How restful. |
| `hero_revived` (himself) | Was I gone? How rude of me. |
| `boss_seen` | What a frame. I'd love to keep him. |
| `mana_low` (himself) | Forgive me. I'm quite used up. |
| `item_picked_up` | Is that a finger? May I keep it? |

### Spellsword (Corwin): flunked mage school, washed out of the guard; "a change of calling"

| Event | Line |
|---|---|
| `fight_started` | Sword or spell? Bit of both. |
| `enchant` (fire) | Fire. Mostly where I meant it. |
| `enchant` (fire) | My sword's brighter than your torch. |
| `enchant` (frost) | Frost. I nearly passed frost. |
| `enchant` (shock) | Shock. Nobody touch me. |
| `mana_low` (himself) | That's my lot. Sword it is. |
| `fail` | This is why the guard let me go. |
| `crit` | Did you see that? Write that down. |
| `hero_died` | I trained for this. Briefly. |
| `hero_revived` (himself) | Back again. Like my exam resits. |
| `item_picked_up` (a spellbook) | I was thrown out for less. |
| `fight_ended` | Not failing. A change of calling. |
| `boss_seen` | We did him in class. I left early. |
| `ambush_over` | Two careers. Neither covered that. |
| `corruption_bounce` | Swords don't work. Nor spells. Lovely. |

### Role lines (spoken only when the slot's class has none for the event)

Plain, so they suit any class in the role.

| Role | Event | Line |
|---|---|---|
| Front | `ambush_started` (urgent) | To me! |
| Front | `hero_died` | Not on my watch. Up. |
| Front | `ambush_over` | Done. Anyone bleeding? |
| Front | `boss_seen` | That one's mine. |
| Healer | `ambush_started` (urgent) | Stay close to me! |
| Healer | `hero_died` | Hold on. I'm coming. |
| Healer | `hero_revived` | Welcome back. Don't do that again. |
| Healer | `ambush_over` | Everyone breathing? Good. |
| Sneak | `ambush_warning` | Too quiet. I don't like quiet. |
| Sneak | `ambush_started` (urgent) | Here they come! |
| Sneak | `hero_died` | Well. That's worse. |
| Sneak | `ambush_over` | We're alive. Don't push it. |
| Caster | `ambush_warning` | Something's wrong. I can feel it. |
| Caster | `ambush_started` (urgent) | Get behind someone! |
| Caster | `hero_died` | That's not good. That's really not. |
| Caster | `ambush_over` | Is it over? Is it really over? |

### Pairs (said only when both are in the party: `with`)

**Paladin and Necromancer**

| Event | Lines |
|---|---|
| `minion_smitten` | Paladin: Sorry. The Light did that. / Necromancer: That was {minion}'s good arm. |
| `minion_smitten` | Necromancer: You've singed {minion}. / Paladin: It was trying to hug me. |
| `minion_raised` | Paladin: Please put that back. / Necromancer: {minion} is staying, thank you. |
| `heal_refused` (by the Paladin) | Necromancer: Just a little? A plaster? / Paladin: I can't. It isn't personal. |
| `vow_broken` | Necromancer: I could raise the one that ran. / Paladin: No. |

**Bard and Cleric** (the nemesis)

| Event | Lines |
|---|---|
| `fight_ended` | Cleric: I shall pray for you all. / Bard: Can I quote that? Out of context? |
| `song_started` | Cleric: Do not put me in that song. / Bard: You're the villain. It's a good part. |
| `puzzle_solved` | Cleric: The Light showed the way. Through me. / Bard: Noted. I'm cutting the "me". |
| `hero_revived` (by the Cleric's scroll) | Bard: The priest takes the credit. Again. / Cleric: The Light takes it. I hold it. |

**Bard and Paladin** (decision 7: the straight man)

| Event | Lines |
|---|---|
| `fight_ended` | Bard: Our paladin, wreathed in glory. / Paladin: I fell over. / Bard: Wreathed. |
| `ambush_over` | Bard: Twelve of them, single-handed. / Paladin: There were three. We all helped. |
| `song_started` | Paladin: Is that song true? / Bard: It is now. |

**Monk and Thief** (the takings)

| Event | Lines |
|---|---|
| `loot_refused` | Thief: Carry this. Just this once. / Monk: I carry nothing. / Thief: Then carry nothing, in a bag. |
| `item_picked_up` (by the Thief) | Monk: Possessions own you. / Thief: Good. Let them. |
| `fight_ended` | Thief: Your pack's empty. It hurts me. / Monk: That is your burden, not mine. |

**Barbarian and anyone reading a scroll** (`scroll_read`, with the Barbarian)

| Who reads | Lines |
|---|---|
| anyone | Barbarian: Cheating. |
| the Mage | Barbarian: Stop reading. Fight. / Mage: This IS fighting. |
| the Bard | Barbarian: Is that a song or a spell? / Bard: Yes. |
| the Spellsword | Barbarian: Half a wizard. Still reading. / Spellsword: A quarter, really. |
| a Scroll of Resurrection | Barbarian: Talked them back from death. Wrong. |

**Also, because they write themselves:** Ranger and Druid on `eat`: Ranger: That's edible. / Druid: That's a friend.

---

## 7. Groundwork and build order

**Every C step comes after the expansion's build order is done through step 12 (8b).** In particular: Foundations
steps 7 (saves that grow), 8 (hero stats) and 11 (item hooks); 7l.3 curse zones and 7l.5 oil (fire and the pocket);
7d (the grab, lock-ins, tentacles); 7j (so "corpses" and "remains" never collide); 7h resting; 7i levelling; 7g
legendaries; and 8b's party screen, names, portraits and scores.

| Step | What | After |
|---|---|---|
| C.1 | Roles and the class picker | 8b.5 |
| C.2 | Class abilities and the ability button | C.1 |
| C.3 | Banter groundwork and the new voices | C.1 |
| C.4 | Corpses | C.2 |
| C.5 | Minions and the third row | C.4 |
| C.6 | Placeholder portraits | C.1 |
| C.7 to C.11 | **Batch 1:** Barbarian, Bard, Ranger, Necromancer, and the batch check | C.2 to C.6 |
| C.12 to C.16 | **Batch 2:** Monk, Spellsword, Druid, Paladin, and the batch check | C.11 |

Each class step ends with: its smoke and class-test checks, a test-room key that swaps that class into its slot, its
banter, and the docs (CLAUDE.md, the game overview's "Systems built", the combat design page and blueprint).

**C.1 prompt (Roles and the class picker)**

```
Read docs/design/new_classes_plan.md sections 1-3 and the 8b page of
docs/design/expansion_design.md with its addendum. Add CharacterDef.role
(front, healer, sneak, caster), set it on the four existing classes, and
add data/classes.tres listing every class file. Give the party screen's
four slots a class choice: arrows step through the classes of that
slot's role only; changing class resets the slot's name, portrait and
scores to the class defaults; Play stays lit with the ready-made four.
Fill Party.hero_defs from the screen. Save each slot's class_id; an
older save loads as the ready-made four. The healer slot always starts
with the lit torch and two candles. Keep the smoke test on the
ready-made four and add tests/classes_test.gd. Show me the screen
before going further.
```

**C.2 prompt (Class abilities and the ability button)**

```
Read the plan's section 4 opening. Add CharacterDef.abilities (SpellDef
files) and a small button beside each hero's name that opens that list
in the spell list's frame, through the pop-up layer. Abilities use the
spell rules that exist: mana, the action wait, recast waits, sounds.
Add the SpellDef fields the classes need (toggled song, shape, weapon
enchantment, raise, corpse cost, no-mana once per rest) without using
them yet. The Cleric and Mage keep their holy symbol and spellbook as
they are. Add CharacterDef.refuses (item kinds) and the no-weapons /
no-armour flags. Test with a dummy ability in the test room.
```

**C.3 prompt (Banter groundwork and the new voices)**

```
Read docs/tone.md and the plan's section 6. Add role speakers
(role:front etc., spoken only when the slot's class has no line for the
event), the `with` condition (class ids that must be in the party), and
the {minion} and {was} placeholders. Give every existing line that
names a job or answers a particular class a `with`. Extend
tests/banter_test.gd: every class or its role must cover fight_started,
hero_died, hero_revived, ambush_warning, ambush_started, ambush_over
and boss_seen. Add the plan's 16 role lines. Add a voice entry for each
new class to docs/tone.md section 6, from the plan. No class lines yet.
```

**C.4 prompt (Corpses)**

```
Read the plan's Necromancer section. A slain skeleton, skeleton guard
or plague rat leaves a corpse on its tile for 45 s: a placeholder heap
sprite, tinted by sprite_lighting, never blocking, never on the map,
never saved. Slimes, tentacles, the giant hand and minions leave none;
the Warden's crumbles at once. Call them corpses, never remains (7j).
GameEvents.corpse_left / corpse_gone. Add MonsterDef.undead and
.cursed and set them as the plan says. Smoke checks.
```

**C.5 prompt (Minions and the third row)**

```
Read the plan's Necromancer section and "the third row". A minion is a
party member without a class: it sits in a spare panel (positions 4
and 5), has the stats the plan gives, strikes by itself only from the
front row, can be dragged like a hero, is never healed, and falls apart
on the plan's four conditions. Widen the party code to three rows: a
blow from behind lands on the rearmost occupied row; who can swing is
unchanged. Names from the plan's list on the panel and in the log.
Minions are saved. No Necromancer yet: spawn one with a test-room key.
```

**C.6 prompt (Placeholder portraits)**

```
Make placeholder portraits for the plan's section 8 list by script from
the existing portraits (recoloured, with the class's initial), at the
real portrait size, with hurt and dead versions derived as usual. List
every one in the placeholder list of docs/asset_log.md. Do not spend
PixelLab generations.
```

**C.7 prompt (Barbarian)**

```
Read the plan's Barbarian section, his row in section 3 and his
banter. Build him: data file, rage bar in the mana row (5 per HP lost,
10 per kill, ignites at 100 for 10 s: damage x1.5 and no grab; drains 5
a second out of a fight; empties at camp), refuses potions and scrolls,
the grab rule, level gains and Blood up. Add his banter and the
Barbarian scroll pairs. Smoke and class-test checks, a test-room key,
docs and the blueprint. Run all tests and the game.
```

**C.8 prompt (Bard)**

```
Read the plan's Bard section and his banter. Build him: data file, the
three songs as toggled abilities (1 mana to start, 1 every 3 s; one at
a time; never on himself; stop on no mana, death, camp or grab), the
note on his panel, four short lute sounds (log them in
docs/asset_log.md), level gains and Encore. Add his 25 lines and the
Bard pairs with the Cleric and the Paladin. Checks, a test-room key,
docs and the blueprint. Run all tests and the game.
```

**C.9 prompt (Ranger)**

```
Read the plan's Ranger section and his banter. Build him: data file,
tracking (2 tiles ahead along open tiles, a paw mark at the top of the
view and one log line per monster, works in the dark, never sees an
ambush or an unsearched body), +2 attack and half of misses recoverable
with a launcher, no sickness from raw or mouldy food, level gains and
Keen nose. His banter. Checks, a test-room key, docs and the blueprint.
Run all tests and the game.
```

**C.10 prompt (Necromancer)**

```
Read the plan's Necromancer section and his banter. Build him on C.4
and C.5: Raise Dead, Life Drain (nothing back from the undead), Bone
Armour (does not add to Shield), refused healing from the Cleric and
the Paladin, the minion's watch at camp, level gains and Dear departed.
His banter (including the offer over a fallen hero) and nothing for the
Paladin pairs yet. Checks, a test-room key, docs and the blueprint. Run
all tests and the game.
```

**C.11 prompt (Batch 1 check)**

```
Play floor 1 start to stairs with each batch 1 class in its slot (four
runs, the rest ready-made), then once with all four. Fix what breaks,
note what feels off, measure the new front and sneak numbers against
the plan's section 3, and report. Build a demo only if I ask.
```

**C.12 prompt (Monk)**

```
Read the plan's Monk section and his banter. Build him: data file, no
weapons or armour (a light is allowed), fists and defence by level,
dodge 15% and the counter, a 4-slot backpack that Take all skips,
"LIGHT PACK" in the loot pop-up, Still water, Grudge's refusal. His
banter and the Monk and Thief pairs. Checks, a test-room key, docs and
the blueprint. Run all tests and the game.
```

**C.13 prompt (Spellsword)**

```
Read the plan's Spellsword section and his banter. Build him: data
file, Enchant (fire, frost, shock; 4 hits or 20 s; one at a time), the
slowed status with its tier row, fire counting as a torch's fire with
oil, the blade's light, fire going out in a curse zone, level gains and
Spellstrike (Magic Missile). His banter. Checks, a test-room key, docs
and the blueprint. Run all tests and the game.
```

**C.14 prompt (Druid)**

```
Read the plan's Druid section and her banter. Build her: data file,
Poultice on its own track, Reclaim (purifies corruption and makes the
curse-zone pocket as Bless does), bear and wolf (a stat and portrait
swap; no casting, items or quick slots; a held light is stowed; the
wolf tracks and ignores the dark), Change back, level gains and Deep
roots. Her banter and the Ranger and Druid pair. Checks, a test-room
key, docs and the blueprint. Run all tests and the game.
```

**C.15 prompt (Paladin)**

```
Read the plan's Paladin section and his banter. Build him: data file,
Lay on Hands once per rest (refused on the Necromancer), the +1 defence
aura, Smite (undead and cursed, the flash on minions, purifying and the
pocket with no monster in front), the Vow (only monsters that struck or
were struck count), level gains and Steadfast. His banter and the
Paladin pairs with the Necromancer and the Bard. Checks, a test-room
key, docs and the blueprint. Run all tests and the game.
```

**C.16 prompt (Batch 2 check)**

```
As C.11, for batch 2, then three runs with mixed parties chosen to be
hard (Barbarian with Paladin; Monk with Necromancer; Bard, Ranger and
Spellsword together). Report what is too strong and too weak against
the plan's section 3, with numbers, before changing any.
```

---

## 8. Portraits

For PixelLab later, at the existing portraits' size and style (128 px, an extreme close-up with the head filling the
frame; the hurt and dead versions are derived as now). 8b plans three portraits per class: these are each class's
first. Placeholders until then (C.6).

| Portrait | Short description |
|---|---|
| Barbarian | Huge, braided beard, fur across the shoulders, a puzzled, honest frown |
| Monk | Shaven head, calm eyes, a plain undyed robe, a faint smile that never changes |
| Druid | Grey-streaked wild hair with twigs in it, moss on the shoulders, furious eyes |
| Druid as a bear | A scarred brown bear's face, the same furious eyes |
| Druid as a wolf | A lean grey wolf's face, ears flat, the same eyes |
| Paladin | Square jaw, a dented helm pushed back, earnest and hopeful |
| Ranger | Weathered, a mud-green hood, a scar through one eyebrow, chewing something |
| Bard | Bright-eyed, a feathered cap gone limp in the damp, ink on the fingers, very pleased |
| Necromancer | Neat, pale, well-combed, a high black collar, a kind and unsettling smile |
| Spellsword | Young and sharp-faced, a singed fringe, a guard's gorget under a scholar's collar |
| Minion | A plain skull close up, one green spark in an eye socket (one picture for every minion) |

Eleven pictures. Also wanted, not portraits: the corpse heap on the floor (one per monster that leaves one), the paw
mark for tracking, the song note on the Bard's panel, and the Spellsword's three blade glows, which as animated
effects come from PixelLab's VFX suite (CLAUDE.md, art pipeline).

---

## 9. Still open

Nothing that blocks the plan. Two things to settle when their step comes:

- **The balance numbers** in section 3 are first guesses, to be measured in C.11 and C.16.
- **Three portraits per class** (8b) means 22 more new-class portraits after the first eleven: decide at C.6 whether
  the new classes get three each or one.
