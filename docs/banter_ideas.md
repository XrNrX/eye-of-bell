# Banter Ideas: Party Lines and Scenes

Source material for the party banter system (roadmap Phase 7f) and related
in-game text. When building `data/banter.json`, use these lines as the
starting point, follow `docs/tone.md`, and keep each line short enough to
fit on one message-log line.

`{name}` = the speaking or affected character's name. `{target}` = who the
line is about.

---

## The tone in one line

A grim, cursed dungeon crawler with a pitch-black sense of humour: the world
is horrible, and the party won't stop complaining about it. The world plays
it straight; the comedy comes from the characters.

## Character voices

- **Cleric:** smug, holier-than-thou, passive-aggressive, no help at all.
- **Fighter:** the party's protector. Blunt, tired, always hungry, goes
  berserk when a fight starts. Secretly cares, will never admit it.
  (Think Riggs to the cleric's Murtaugh.)
- **Thief:** sarcastic, greedy, always eyeing the loot, denies everything.
- **Mage:** nervous, bookish, over-explains, terrified of everything.
- **Grudge (the talking sword):** low, gravelly, resentful. Hates the cleric
  even more than the fighter does.

The party doesn't need to like each other. They just need to be heroes.

---

## Cleric

| Event | Line |
|---|---|
| Fighter dies | "You didn't have the faith, my son." |
| Thief dies | "The Light does not protect those who pick its pockets." |
| Mage dies | "All that reading, and not one prayer." |
| Someone else revived before him | "Oh, him first. Naturally." |
| Out of mana | "My god is not a well you can keep drawing from." |
| Revived himself (short) | "I was at peace. There was light. And you dragged me back here for this?" |
| Revived himself (long) | "I was at PEACE. There was LIGHT. And you dragged me back to a damp corridor full of plague rats for THIS?" |
| Ambush setup (build-up) | "I smell evil." |
| Real ambush starts (battle cry) | "I did say!" |
| After the real ambush, grudgingly | "You're not so bad with a sword." |
| After a fake-out scare | "Evil comes in many forms." |
| Levels up | "The Light rewards the faithful." |
| Fighter eating a charred leg | "Do we even know what that was?" |

**Penitent's Mace (complains on every hit, with a cooldown):**
- "Forgive me."
- "This is beneath me."
- "I'll pray about that later."

**Shaken after resurrection (system messages):**
- "{name} returns, whole in body but too shaken to pray."
- "{name} is too shaken to pray."
- "{name}'s faith steadies."

---

## Fighter

| Event | Line |
|---|---|
| Ambush setup (reply to "I smell evil.") | "Shut up." |
| Real ambush starts (battle cry, charging in) | "Shut up, cleric!" |
| First party death of the game (once only) | "NOOOO! My comrade!" |
| That comrade is resurrected | "I wasn't bothered." |
| ...called out on it | "*cough* I'm hungry. Someone get a fire on." |
| Revived himself, to the cleric | "Faith didn't buy that scroll." |
| After a fake-out scare | "It was a bat." |
| Eats food | "Tastes like the floor. Still good." |
| Levels up | "Feel stronger. Still hungry." |
| Asked what he's eating (charred leg) | *chewing* "Dinner." |

Alternate (earlier draft), cleric "I did say." → fighter:
"Aye, you did say. Now shut up before I kill you myself."

---

## Grudge, the talking sword

| Event | Line |
|---|---|
| Idle / cleric nearby | "Can I stab the priest? Just a little?" |
| After a kill | "More." |
| Unequipped / put in the backpack | "Back in the bag again. Typical." |

Sulks (deals less damage) if left in the backpack too long.

---

## Thief and mage

No lines written yet. Notes:
- **Thief:** always denies stealing (pairs with the Gilded Hand dagger,
  which pinches items from the party). Constantly snipes with the cleric.
- **Mage:** nervous lines about the Tome of Screams frightening him.

---

## Whole party

| Event | Line |
|---|---|
| After a solidarity moment (sniping stopped while someone nearly died) | "Don't make it weird." |
| A revived character, to the fighter who said "I wasn't bothered" | "I heard you." |
| Woken by monsters during a rest | "Five more minutes..." |
| Wearing the Rat King's Crown | The rest of the party complains about the smell. |

---

## Scenes (multi-line sequences)

### The double-tap ambush

1. Build-up: torch flickers, sound drops out.
2. **Cleric:** "I smell evil."
3. **Fighter:** "Shut up."
4. BOOM, but it's only a bat or a falling skull (the fake-out).
5. **Fighter:** "It was a bat." **Cleric:** "Evil comes in many forms."
6. A few tiles later, with no warning: tentacles burst from the walls and
   portcullises slam shut.
7. **Cleric:** "I did say!" **Fighter:** "Shut up, cleric!" (charges in)
8. After the fight, **Cleric**, grudgingly: "You're not so bad with a sword."

### The first death

1. A party member dies for the first time in the game.
2. **Fighter:** "NOOOO! My comrade!"
3. Later, they're resurrected.
4. **Fighter:** "I wasn't bothered."
5. **Revived:** "I heard you."
6. **Fighter:** "*cough* I'm hungry. Someone get a fire on."

### Campfire dinner

1. The cleric says grace over a thimble of stew.
2. The fighter rips into a whole charred leg of something.
3. **Cleric:** "Do we even know what that was?"
4. **Fighter:** *chewing* "Dinner."

### Levelling up

1. The cleric levels up. **Cleric:** "The Light rewards the faithful."
2. The fighter levels up. **Fighter:** "Feel stronger. Still hungry."
3. The fighter levels up again soon after. The cleric is quietly furious.

---

## System messages and world text

**Message log:**
- "{name} burns the meat. Nobody mentions it."
- "Not with that thing watching." (can't rest, monsters nearby)
- "You are held fast!" (grabbed during an ambush)
- "The altar ignores your offering."
- "The scroll needs the fallen." (resurrection scroll used on the living)
- "You need your holy symbol."
- "Something of yours has gone missing." (the Gilded Hand strikes)
- "The portcullis won't budge."
- "You found a secret passage!"
- "Secret found. +50 XP."

**Item descriptions:**
- Stale bread: "Baked in a better century."
- The Too Old For This Shield: "Older than you. Tougher than you. Still
  complaining."

**Level complete screen:**
- "Secrets found: 1 of 4. The dungeon is disappointed in you."

**Tips:**
- "Plague rats are not friendly. We checked."

---

## Ideas for later

- Cooking mini-game at the campfire: monster meat, pots, pans and
  ingredients found in the dungeon. The cleric refuses to eat anything that
  was trying to kill him an hour ago.
