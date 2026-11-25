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
- Real-time grid movement, first-person 3D view at 416x260 inside a stone frame, 640x360 integer-scaled. Screen layout for six heroes: the view in the middle and three hero panels down each side (the party is still four; two panels are empty).
- Test room (debug builds only, F12 or the main menu): a hall with stations for combat, an ambush stand-in, a puzzle, each wall type, every item and not-yet-built systems, wall signs and debug keys (god mode, refill, kill all, spawn, teleport, toggles). Add a station when a new system lands.
- Making camp (bedroll): a rest screen with a fire and a bedroll for each hero, 30 s of HP and mana climbing evenly, cleared sickness and shaken, saved game; click a bedroll for that hero's pack. A 3D camp (fire, spit, bedrolls) and ash camp spots exist as scenery in the test room. Cook raw rat meat and mouldy bread at the fire (the COOK button or food held on the fire): cooked food heals more and never makes you sick. No interruptions or levelling at camp yet.
- Item behaviour hooks and the legendary-item framework: a gold slot frame and slow shimmer, the item's description, power and price in its tooltip and on the character sheet, a line from whoever first holds one. The Azure Brand (a glowing blue long sword that burns what it hits and singes its wielder on a kill) is the first real one, in the test room; Grudge, the Mace and the Unquenchable are next, and a test blade shows the hooks.
- A reach attacker: the Goblin Halberdier (tier 2), who stabs from two tiles away, in floor 1's optional north-east room.
- Armour for the Mage: the Wool Robes, a light robe (+1 defence) that only casters can wear, found in room 5 on floor 1.
- A fast venomous biter: the Bone Spider (tier 2), whose bite can sicken a hero and who spits a web down a corridor that pins the party in place for three seconds (they can still turn, fight and cast), lurking in a floor 1 corridor link.
- A heavy hitter: the Horned Knight, a slow, armoured tier 2 swordsman (defence 5) alone in a floor 1 corridor.
- Fodder: the Goblin, a weak, quick spear carrier (tier 1), two of them guarding floor 1's west corridor.
- A ranged monster: the Red Shaman, a goblin caster who throws a crimson bolt from up to four tiles down a clear line, in the test room's arena and on floor 1 in the corridor south of door (18,10).
- Demo level 1 (the main menu's DEMO LEVEL button): a 35x35 level from the designer's hand-drawn map, with a short intro card, sixteen lever-driven portcullises (small wooden levers), two locked doors and three keys, about fifty monsters scaled by distance from the start with the Cursed Warden before the stairs, a camp, a Hearth Coal, plenty of items, and saving.
- Campfires and the Hearth Coal: campfires are solid and clickable (make camp, cook, break camp); each level hides a Hearth Coal that carries the party, through a PixelLab smoke surge, to a safe monster-free camp room (walkable, with a fire, bedrolls and sconces) and back to the exact tile.
- Inventory handling: double-click an item for DROP or COMBINE (merge stacks in a hero's pack), a DISCARD button that drops the held item on the floor, and the character sheet shows gear bonuses in brackets. The test room stocks every hero with a different dozen items.
- Level 1: doors, locked doors and keys, levers, plates, portcullises, cracked walls, two exits, 16 monsters of six kinds (plague rats nest in the cave: fast, and a bite can make you sick), with a mini-boss, the Cursed Warden, guarding the stairs.
- Real-time combat with crits and fails, hit direction (hits from behind and the sides), monster swings timed to land with the hit feedback, combat feel. Monster pacing for the step-back dance: monsters move on their own slower clock, pause before following, can't strike the moment they arrive, and queue instead of surrounding the party (one flanker at a time, after a delay); tunable in the test room. Status effects on monsters (data-driven; held so far) and the Mage's Hold Monster spell: rooted for 5 s unless it resists, helpless to crits (the Thief's most), cold blue runes from PixelLab's VFX suite. A rusty bear trap to set on the floor (the Thief sets it fastest): it snaps and holds the first monster to step on it, then can be picked up again. Light and darkness: no light follows the party; a torch or candle takes a hero's hand, burns down only while held (a bar on the hand slot, a PixelLab flame), the dark is a faint cold ambient with monsters and items tinted by the light that reaches them, a torch's fire makes slimes recoil, and a slipped torch burns on the floor where it fell. Wall torches are sconces: lit, unlit with a torch (light it from a flame in a hand or with a Fireball) or empty brackets; take the torch (120 s) or hang one back, and no torch is ever made. Curse zones: a green haze on the floor where flames die (a torch sputters and goes out, a sconce will not light), until a Bless makes a short pocket or a puzzle lifts it. A lit torch can be thrown (shift+click its hand): it burns where it lands. Flasks of oil (thrown at the floor for a slick, at a monster to douse it) turn a torch, a swing or a Fireball into a wall of fire that slimes and rats will not cross.
- Map: a parchment corner map with PixelLab symbols and torchlight flicker, and a full-screen map on M with a legend (no fog of war yet).
- Real shadows from spell lights and torches: walls, pillars, arches and doors block light (Options: SPELL SHADOWS, off for weaker machines).
- Enemy health bars (small bar over damaged or front monsters, name strip, wide boss bar; Options: On / Boss only / Off).
- Party: four heroes, front and back row, formation swapping, hands, throwing, quick slots.
- Inventory, stacks, equipping, character sheet, food and sickness, potions, scrolls, resurrection. A right-click loot pop-up on floor items: choose which hero's backpack takes it (room and "can't use" shown, the dead listed last), or Take all to share a pile out.
- Spells (Magic Missile, Fireball, Hold Monster, Heal, Bless, Shield) with synced lighting and pixel particles, holy light, and a pixel-exact shockwave ripple on Fireball and Magic Missile impacts.
- Banter system (crit, fail, hit from behind, eat, equip events).
- Corrupted walls that only a cleric's Bless can burn away (two on floor 1), and a data-driven puzzle system: conditions (levers, dead monsters, braziers, altars, plates, areas) and effects (open or seal doors, raise a reliquary, lift a curse zone). A purge room (in the test room so far): glowing eye seals on the doors until every monster is dead, then they crumble and a reliquary chest grinds up out of the floor and opens.
- Intro cutscene: 14 painted shots with fog, rain, lightning and thunder, played once on first launch and from the menu.
- Ancient walls (stone variants, decals, structures), menus, pause, save and load, audio, display modes, options.
- Art pipeline: Python generators plus PixelLab imports (`tools/art/`).

## Planned next
Ambushes and scares, puzzles, more banter, legendaries, campfire and resting, levelling, fallen adventurers, Feeli the cat companion, the Tales of Bellius.

**Keep the "Systems built" list current whenever a major feature lands.**
