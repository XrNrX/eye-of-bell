# Game overview

**Pitch.** A grim, cursed Eye of the Beholder-style dungeon crawler with a pitch-black sense of humour: the world is horrible, and the party won't stop complaining about it.

**Tone rule.** The world plays it straight; the comedy comes from the characters. Party banter is a core feature (`scripts/banter.gd`, `data/banter.json`, voices in `docs/banter_ideas.md`).

## The party
- **Brannoc**, fighter: blunt protector, always hungry.
- **Brother Felix**, cleric: smug.
- **Wren**, thief: sarcastic and greedy.
- **Fennick**, mage: nervous.

They can't stand each other but would die for each other. (In data a hero has a `hero_name` (these names), a `class_id` (`cleric`...) and a `display_name` that is the class.)

## Visual style
Dark, desaturated, cursed (`docs/art_style.md`). Sickly green means the curse and danger. Spells: fire orange, holy gold, arcane pale blue. Torchlight is the only warm colour.

## Systems built so far
- Real-time grid movement, first-person 3D view at 416x260 inside a stone frame, 640x360 integer-scaled.
- Test room (debug builds only, F12 or the main menu): a hall with stations for combat, an ambush stand-in, a puzzle, each wall type, every item and not-yet-built systems, wall signs and debug keys (god mode, refill, kill all, spawn, teleport, toggles). Add a station when a new system lands.
- Level 1: doors, locked doors and keys, levers, plates, portcullises, cracked walls, two exits, 15 monsters of four kinds.
- Real-time combat with crits and fails, hit direction (hits from behind and the sides), monster swings timed to land with the hit feedback, combat feel. Monster pacing for the step-back dance: monsters move on their own slower clock, pause before following, can't strike the moment they arrive, and queue instead of surrounding the party (one flanker at a time, after a delay); tunable in the test room. Status effects on monsters (data-driven; held so far) and the Mage's Hold Monster spell: rooted for 5 s unless it resists, helpless to crits (the Thief's most), cold blue runes from PixelLab's VFX suite. A rusty bear trap to set on the floor (the Thief sets it fastest): it snaps and holds the first monster to step on it, then can be picked up again. Light and darkness: no light follows the party; a torch or candle takes a hero's hand, burns down only while held (a bar on the hand slot, a PixelLab flame), the dark is a faint cold ambient with monsters and items tinted by the light that reaches them, a torch's fire makes slimes recoil, and a slipped torch burns on the floor where it fell.
- Map: a parchment corner map with PixelLab symbols and torchlight flicker, and a full-screen map on M with a legend (no fog of war yet).
- Real shadows from spell lights and torches: walls, pillars, arches and doors block light (Options: SPELL SHADOWS, off for weaker machines).
- Enemy health bars (small bar over damaged or front monsters, name strip, wide boss bar; Options: On / Boss only / Off).
- Party: four heroes, front and back row, formation swapping, hands, throwing, quick slots.
- Inventory, stacks, equipping, character sheet, food and sickness, potions, scrolls, resurrection. A right-click loot pop-up on floor items: choose which hero's backpack takes it (room and "can't use" shown, the dead listed last), or Take all to share a pile out.
- Spells (Magic Missile, Fireball, Hold Monster, Heal, Bless, Shield) with synced lighting and pixel particles, holy light.
- Banter system (crit, fail, hit from behind, eat, equip events).
- Corrupted walls that only a cleric's Bless can burn away (two on floor 1), and a small data-driven puzzle system.
- Intro cutscene: 14 painted shots with fog, rain, lightning and thunder, played once on first launch and from the menu.
- Ancient walls (stone variants, decals, structures), menus, pause, save and load, audio, display modes, options.
- Art pipeline: Python generators plus PixelLab imports (`tools/art/`).

## Planned next
Ambushes and scares, puzzles, more banter, legendaries, campfire and resting, levelling, fallen adventurers, Feeli the cat companion, the Tales of Bellius.

**Keep the "Systems built" list current whenever a major feature lands.**
