# Tone: the writing bible for Eye of Bell

Read this before writing ANY text the player can see: banter, log messages, item
names and descriptions, death screens, tips, menus, signs, Bellius's pages.
When in doubt, copy the shape of an example here. Source lines and scenes are in
`docs/banter_ideas.md`; this file decides whether a line is allowed.

## 1. The game in two sentences

A grim, cursed dungeon crawler with pitch-black humour. The world is horrible,
and the party won't stop complaining about it.

## 2. The core rule

**The world plays it straight. Only the characters are funny.**

- The curse, the monsters, the traps, the scares and the narrator are never jokey.
- The comedy is four tired people reacting to how awful it all is.
- Test: delete the party from the scene. If anything left is still a joke, rewrite it.

| Straight (the world) | Funny (a character reacting) |
|---|---|
| "The stone is alive with pulsing green veins." | "{name}: It's alive. I don't like stabbing things that are alive." |
| "The corruption swallows the blow." | "{name}: It ATE it. The wall ate my fireball." |

## 3. Style rules

1. **Short.** The log is 35 characters wide and the speaker's name is part of the
   line ("Brother Felix: " is already 15). Spoken text: aim for 40 characters or
   fewer, never more than 55 (two rows with the longest name). One thought per line.
2. **Dry and deadpan.** Understatement beats exaggeration. "It was a bat." beats
   "Wow, that scared me half to death!"
3. **British and Scottish flavour is welcome**: "aye", "wee", "right", "bother",
   "daft", "rubbish", "I did say". British spelling everywhere (armour, colour, mould).
4. **No modern slang, memes, pop-culture references or fourth-wall breaks.**
   Nobody says "okay", "guys", "awesome", "literally", "seriously?", "epic",
   "boss", "loot" (they say "gold", "the takings", "that"), "XP", "level", "HP".
   Nobody mentions keys, buttons, the screen, the player or the game.
5. **Dark, not cruel.** Punch up: at the curse, the gods, the dungeon and the
   party's own failings. Never at real-world groups, never at disability, illness,
   looks, sex or origin. Insults inside the party are about what someone just DID.
6. **Plain punctuation.** Full stops do the work. One exclamation mark at most,
   and only for real alarm or a battle cry. Capitals for a shout are the Mage's
   habit and Grudge's "MORE."; nobody else gets them. No ellipses except a
   trailing-off Mage. No asterisk actions (`*cough*`): the narrator describes
   actions in a plain log line instead.
7. **No explaining the joke.** If a line needs a second line to make it funny, cut both.
8. **The Light** is the Cleric's god. No real-world religions, saints or scripture.

## 4. Timing: comedy sets up a scare, never interrupts one

| Moment | What is allowed |
|---|---|
| Quiet exploring | Banter, bickering, loot remarks. |
| Just BEFORE an ambush or scare | One quick exchange. The laugh lowers the player's guard. |
| The burst itself | Nothing. No text over the scare. |
| The fight starts | ONE battle-cry exchange, two short lines at most. |
| During an ambush fight | Silence. Only plain combat messages. |
| An ordinary fight | Barks only: crit and fumble reactions, 4 words or fewer is best. No conversations. |
| The fight is over | The party may react, complain and blame each other. |

The model exchange:

> {name} (Cleric): "I smell evil."
> {name} (Fighter): "Shut up."
> ... BOOM ...
> {name} (Cleric): "I did say!"
> {name} (Fighter): "Shut up, cleric!"
> (silence until the last monster falls)
> {name} (Cleric), grudgingly: "You're not so bad with a sword."

Never: a quip while a monster is mid-reveal, a pun on the thing that just
appeared, or a reaction that tells the player a scare was not serious.

## 5. Names and placeholders

Players will be able to rename the heroes. **Never type a hero's name in a line.**

- `{name}` = the speaker, or the hero the message is about.
- `{target}` = the other hero the line is aimed at.
- Calling someone by their job is fine and in character: "Shut up, cleric!",
  "Ask the thief."
- Avoid he/she/him/her for heroes. Use `{target}`, "you", "that one" or the job.
- The Cleric's "my son" is said only to the Fighter. To anyone else: "my child".
- Default names (for reading this file only): Cleric Brother Felix, Fighter
  Brannoc, Thief Wren, Mage Fennick.

## 6. The four voices

### Cleric (Brother Felix): the lead comic voice

- **Personality:** smug, holier-than-thou, passive-aggressive, no help at all.
  Takes credit for everything, blame for nothing. Believes he is the patient one.
- **Cares about:** being right, being thanked, his own comfort, the Light (as a
  thing that agrees with him).
- **Speech habits:** calm, complete sentences. Pious phrases turned into small
  knives. Forgives people who did nothing wrong. Says "I did say."
- **Words he uses:** the Light, faith, my son, my child, forgive, humble, pray,
  patience, I did warn, naturally, bless.
- **Never:** swears, shouts (except "I did say!"), admits fear, admits fault,
  says sorry, gives a straight compliment (grudging ones only, after a fight).
- **To the Fighter:** talks down to him like a slow pupil. Secretly feels safest
  behind him and will only ever say so sideways.
- **To the Thief:** a lost soul and a suspect. Counts his coins after speaking to them.
- **To the Mage:** books are no substitute for faith. Enjoys the Mage's fear.

### Fighter (Brannoc)

- **Personality:** blunt, tired, has seen too much, eats anything. The party's
  protector; goes berserk the moment a fight starts. Cares, will never admit it.
- **Cares about:** food, sleep, the party staying alive, getting it over with.
- **Speech habits:** the shortest lines in the game. Often one to four words.
  Drops the subject: "Feel stronger. Still hungry." Scottish edge: "aye", "wee".
- **Words he uses:** aye, shut up, mine, dinner, again, move, behind me, fine, daft.
- **Never:** long sentences, long words, theory, prayer, complaints about pain,
  an open "I care about you".
- **To the Cleric:** "Shut up." The oldest argument in the party. Would still
  die for him, and would hate that he knew.
- **To the Thief:** easy respect; both are practical. Checks his pockets anyway.
- **To the Mage:** stands in front of him without being asked. Calls the magic
  "the glowy thing" and does not want it explained.

### Thief (Wren)

- **Personality:** sarcastic, greedy, always eyeing the takings, denies everything.
  The realist: the only one who says out loud how bad the odds are.
- **Cares about:** gold, exits, their own skin, not being blamed.
- **Speech habits:** quick, dry asides. Answers accusations before they are made.
  Puts a price on things.
- **Words they use:** mine, finders keepers, worth, dibs, wasn't me, never touched
  it, how much, quietly.
- **Never:** pious talk, heroics, an honest confession, shouting.
- **To the Cleric:** constant sniping. The best snap-backs at him are Wren's.
- **To the Fighter:** the one person Wren would not rob. Much.
- **To the Mage:** teases him, then quietly keeps him out of trouble.

### Mage (Fennick)

- **Personality:** nervous, bookish, over-explains, terrified of everything.
  Usually right, never listened to, and says so afterwards.
- **Cares about:** staying alive, being correct, his books, anyone noticing he
  was correct.
- **Speech habits:** starts to explain, gets cut off or cuts himself off. Odds
  and "technically". Repeats himself when frightened. SHOUTS when surprised.
- **Words he uses:** technically, in theory, statistically, I read that, unlikely,
  oh no, I said this.
- **Never:** bravado, threats, calm in a crisis, short confident orders.
- **To the Cleric:** corrects his facts and regrets it at once.
- **To the Fighter:** hides behind him. Total, embarrassed trust.
- **To the Thief:** wary, and oddly fond. Counts his scrolls.

## 7. Relationships

They can't stand each other, and each would die for the others. Neither half is
ever said out loud.

- **Cleric against everyone.** He needles; they snap back. He never notices he lost.
- **Cleric and Fighter** are the main double act: sermon against "Shut up."
  After a hard fight the Cleric may pay one grudging compliment. The Fighter
  pretends not to hear it.
- **Thief and Cleric** snipe: greed against piety, and both are a bit of each.
- **Fighter and Mage:** the protector and the protected. No jokes at the Mage's
  expense from the Fighter once the Mage is really hurt.
- **Thief and Mage:** teasing that stops the moment it matters.
- **Solidarity moments:** when someone nearly dies the sniping stops for one
  line, then somebody says "Don't make it weird." and it starts again.
- Warmth is shown by what they DO (standing in front, sharing food, spending the
  scroll). It is denied in what they SAY: "I wasn't bothered."

Snap-backs at the Cleric (the pattern: he preaches, someone answers in six words):

| Cleric | Reply |
|---|---|
| "The Light provides." | Thief: "Then it can carry the bags." |
| "I shall pray for you." | Fighter: "Pray quieter." |
| "Faith is its own armour." | Mage: "It demonstrably is not." |
| "I forgive you, {target}." | Thief: "For what? You fell on me." |
| "You didn't have the faith, my son." (once revived) | Fighter: "Faith didn't buy that scroll." |

## 8. Other voices

### The narrator (log messages, death screens, tips, menus)

Plain, present tense, second person ("You pull the lever."), deadpan. States
what happened and stops. Never jokes about the world, never mocks the player,
never cheers. No exclamation marks except real danger ("Something's behind you!").
Messages with numbers stay purely functional ("The Slime hits {name} for 2.").

- **Death screens:** grave and brief. The dungeon wins; the player is not blamed.
- **Tips:** true and useful first, dry second. The sting is in the last few
  words and is about the world or the party, never the player.
- **Length:** a log message is 35 characters where it can be and never more than
  70 with the longest names in it; a death-screen line or a tip is 70 or fewer.
- **Menus and buttons:** plain labels in capitals (NEW GAME, OPTIONS). No jokes.

### Item descriptions

One sentence, or two fragments, 60 characters or fewer. Dry and dark. Say what
it is plainly, then put the sting in the last few words. Useful facts (damage,
healing) belong in stats, not here.

### Legendary items with a personality

Each gets ONE trait and never leaves it. They speak rarely and briefly.

- **Grudge, the talking sword:** low, gravelly, resentful. One to five words.
  Wants blood, hates the Cleric more than the Fighter does, sulks in the pack.
  "MORE." / "Still here. Pity." / "Can I stab the priest? Just a little?" /
  "Back in the bag again. Typical." Never cheerful, never grateful, never chatty.
- **Penitent's Mace** (the Cleric's): the Cleric apologises for using it.
  "Forgive me." / "This is beneath me." / "I'll pray about that later."

### Bellius the bard (torn pages)

Written in his own hand, first person. Older, wry, a bit pompous, sure the
world is waiting for his memoirs. Rhymes when he can manage it and admits it
when he can't. Under the vanity every page holds something TRUE and useful or
grim about the dungeon: he was really here, and it went badly. Pages are read
in their own panel, so they may run to four short lines.

> "I came for gold, I came for fame.
> I found a door that knew my name."

> "The second lever, not the first.
> The first one is... considerably worse.
> (That nearly rhymed. I was bleeding at the time.)"

### Feeli the dungeon cat

Never speaks. No "meow" in text, no thoughts, no feelings described. The
narrator reports only what he does, flatly; the party supplies the comedy.

- "Feeli sits on the pressure plate. The door opens."
- "Feeli stares at the wall. Nothing is there."
- Fighter: "Leave him. He's earned it." / Mage: "He knows something. Look at him."
  / Cleric: "That animal is judging me." / Thief: "Don't look at me. He took it."

### Smudge, the friendly ghost cat

Gentle and mischievous, never scary. Never seen: only what she knocks over.
**The one place the game is allowed to be warm.** She is never a jump scare and
never sets one up. The party goes soft around her; even the Cleric holds his
tongue. No sarcasm aimed at her.

- "A cup slides off the shelf. Nothing pushed it."
- "Something small and cold leans against your leg."
- Fighter: "Aye. Good girl." / Mage (not frightened, for once): "Oh. Hello again."

## 9. Good lines

Each hero, six different events. Use these as the measure for new ones.

**Cleric**
| Event | Line |
|---|---|
| An ally dies | "You didn't have the faith, {target}." |
| He is revived | "I was at peace. You dragged me back for this?" |
| Out of mana | "My god is not a well, {target}." |
| Gold found | "A tithe is one tenth. I'll hold all of it." |
| Puzzle solved | "The Light showed the way. Through me." |
| Before an ambush | "I smell evil." |

**Fighter**
| Event | Line |
|---|---|
| An ally dies | "Get up, {target}. That's an order." |
| He is revived | "Faith didn't buy that scroll." |
| A caster runs dry | "No spells? Fine. Stand behind me." |
| Gold found | "Can't eat gold. Next." |
| Puzzle solved | "Door's open. Stop admiring it." |
| Before an ambush | "Shut up." |

**Thief**
| Event | Line |
|---|---|
| An ally dies | "Dibs on the boots." |
| Revived | "Who's been through my pockets?" |
| A caster runs dry | "Out of magic? Try a knife, {target}." |
| Gold found | "Nobody count it. I already have." |
| Puzzle solved | "Easy. Don't ask how I knew." |
| Before an ambush | "Too quiet. Nobody's robbed us yet." |

**Mage**
| Event | Line |
|---|---|
| An ally dies | "Is {target} meant to be that colour?" |
| He is revived | "I was dead. I have so many questions." |
| Out of mana | "I'm out of mana. This is how I die." |
| Gold found | "Don't touch it. Everything's cursed." |
| Puzzle solved | "As I predicted. Eventually." |
| Before an ambush | "Statistically, we're due something." |

**Item descriptions**
- Stale Bread: "Baked in a better century."
- Healing Potion: "Tastes of copper and regret. Works anyway."
- Scroll of Resurrection: "Brings back the dead. They are rarely grateful."
- Leather Armour: "Someone died in it. It's your size."

**Death screens**
- "Your party has perished. The dungeon keeps what it catches."
- "The torch burns out. Nobody comes to relight it."

**Tips**
- "Skeletons do not tire. Doors help."
- "Only a blessing burns away corruption. The cleric will mention it."

## 10. Don't do this

| Bad line | Why |
|---|---|
| "{name}: According to my calculations, and I have checked them twice, the chance of us surviving this corridor is roughly one in nine." | Too long. One thought, 40 characters. |
| "{name}: Well, that escalated quickly." | Modern catchphrase. Nobody here has heard it. |
| "{name}: Tentacles! Did someone order squid?" (as they burst from the wall) | A joke during the scare. Silence, or a battle cry. |
| "The skeleton tips its helmet and does a little jig." | The world being jokey. Monsters are never funny. |
| "{name}: Press F to open it, genius." | Breaks the fourth wall. No keys, no player. |
| "{name}: A blind beggar fights better than you." | Cruel, and punches down at real people. Mock what was done. |
| "You died. Perhaps this isn't the game for you." | The narrator mocking the player. Never. |
| "Felix heals Wren for 6." | Hard-coded names. Use {name} and {target}. |
| "{name}: That was sarcasm, by the way." | Explains the joke. |
| "{name}: *sighs* *rolls eyes* Fine." | Asterisk actions and modern body language. |

## 11. Where text hooks in (so lines fit the systems)

- **Banter:** `data/banter.json`, one entry per event (`crit`, `fail`,
  `hit_behind`, `equip`, `eat`, `corruption_bounce`, `corruption_resists`,
  `corruption_purified`), with `chance`, `cooldown` and conditions; see the header
  of `scripts/banter.gd`. `speaker` and `actor` are the hero's CLASS ID
  ("cleric", "fighter", "thief", "mage": a role key, never shown); the log shows
  the hero's own name in front ("Brother Felix: text"), so renaming a hero changes
  nothing in the JSON.
  `banter.gd` does not replace `{name}` / `{target}` yet: add that to the code
  before adding lines that use them.
- **Fights:** `Party.fight.in_fight` (the fight tracker) says whether a fight is on; `GameEvents.fight_started` and `fight_ended` announce it. Use
  them for the timing in section 4: banter before a scare, a battle cry as it starts, silence during, reactions after `fight_ended`.
- **Log messages:** `Party._say(text, tone)` and `Hud.show_message`; tones `miss`,
  `crit`, `hurt`, `fail`, `banter` set the colour. Narrator voice.
- **Status row** (one row under the log, hover text and prompts like "Heal whom?"):
  35 characters, no wrapping.
- **Banner** (`Hud.show_banner`, big text over the view): 20 characters or fewer.
- **Puzzle messages:** the `message` effect in `DungeonMap.PUZZLES`. Narrator voice.
- **Item names:** `display_name` in `data/items/*.tres`. Items have no
  description field yet.
- **End screens:** `scenes/game_over.tscn`, `scenes/level_complete.tscn`.
- **Not built yet:** tips, item descriptions, Bellius's pages, Feeli, Smudge,
  Grudge, ambush scenes. The intro cutscene has no words.

## 12. Checklist for any new line

Would it fit in 40 characters (55 at the very most) with the speaker's name in
front? Is it the world being straight, or a character reacting, and never the
world being funny? Could only THIS character have said it, in their own words,
with none of their banned words? Is it free of names (only `{name}` and
`{target}`), modern slang, references and anything about keys, screens or the
player? Does it punch at the curse, the gods or the party's own failings, and
never at real people or the player? Is it clear of a scare (before it, or after
the fight, or one battle cry)? Does it work without a second line explaining it?
If any answer is no, rewrite it or cut it.
