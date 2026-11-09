# Game overview

**Pitch.** A grim, cursed Eye of the Beholder-style dungeon crawler with a pitch-black sense of humour: the world is horrible, and the party won't stop complaining about it.

**Tone rule.** The world plays it straight; the comedy comes from the characters. Party banter is a core feature (`scripts/banter.gd`, `data/banter.json`, voices in `docs/banter_ideas.md`).

## The party
- **Brannoc**, fighter: blunt protector, always hungry.
- **Brother Felix**, cleric: smug.
- **Wren**, thief: sarcastic and greedy.
- **Fennick**, mage: nervous.

They can't stand each other but would die for each other. (In data a hero's `display_name` is still the class.)

## Visual style
Dark, desaturated, cursed (`docs/art_style.md`). Sickly green means the curse and danger. Spells: fire orange, holy gold, arcane pale blue. Torchlight is the only warm colour.

## Systems built so far
- Real-time grid movement, first-person 3D view at 416x260 inside a stone frame, 640x360 integer-scaled.
- Level 1: doors, locked doors and keys, levers, plates, portcullises, cracked walls, two exits, 15 monsters of four kinds.
- Real-time combat with crits and fails, hit direction (hits from behind and the sides), monster telegraphs, combat feel.
- Map: a parchment corner map with PixelLab symbols and torchlight flicker, and a full-screen map on M with a legend (no fog of war yet).
- Enemy health bars (small bar over damaged or front monsters, name strip, wide boss bar; Options: On / Boss only / Off).
- Party: four heroes, front and back row, formation swapping, hands, throwing, quick slots.
- Inventory, stacks, equipping, character sheet, food and sickness, potions, scrolls, resurrection.
- Spells (Magic Missile, Fireball, Heal, Bless, Shield) with synced lighting and pixel particles, holy light.
- Banter system (crit, fail, hit from behind, eat, equip events).
- Corrupted walls that only a cleric's Bless can burn away (two on floor 1), and a small data-driven puzzle system.
- Intro cutscene: 14 painted shots with fog, rain, lightning and thunder, played once on first launch and from the menu.
- Ancient walls (stone variants, decals, structures), menus, pause, save and load, audio, display modes, options.
- Art pipeline: Python generators plus PixelLab imports (`tools/art/`).

## Planned next
Ambushes and scares, puzzles, more banter, legendaries, campfire and resting, levelling, fallen adventurers, Feeli the cat companion, the Tales of Bellius.

**Keep the "Systems built" list current whenever a major feature lands.**
