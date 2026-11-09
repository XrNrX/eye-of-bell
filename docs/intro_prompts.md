# Intro cutscene: prompts and pipeline

The party walks up to and into the dungeon entrance from the title screen: 14 shots, about 47 seconds, played by `scripts/intro_player.gd` (`scenes/intro.tscn`). Use this file to redo a shot or add one. Follow `docs/art_style.md` too.

## Settings

- **Tool:** `create_image_pro`, `width` 640, `height` 360, `no_background` false. 25 generations per attempt; 2 to 8 minutes.
- **The approved look is shot 2's colour and shading** (`art/intro/shot_02_travellers.png`, chosen by the project owner): cold neutral greys, with green only on the moon and the arch's glow.
- **Style image** (`style_image_url`): `art/intro/shot_02_travellers.png`, the imported file, or `art/ui/title.png`. Both gave the same look.
- **One reference image** (`reference_images`), uploaded with `get_upload_url` (uploads last 3 days):
  - `art/ui/title.png` for the entrance. Usage: `the same moon, the same ruined brick archway and broken walls, and the same dead trees, here seen from <distance>`.
  - `tools/art/pieces/intro/shot_01_road_raw.png` for the road. Usage: `the same road, low hill, ruins, moon and dead trees, full frame composition, seen from further along the road`.
  - `art/intro/shot_02_travellers.png` for the figures. Usage: `the same four cloaked figures, same builds and cloaks, in the same order, full frame composition`.
  - `tools/art/pieces/intro/travellers_ref.png`, the four figures cropped from shot 2, for details such as boots.

## About half the pictures come back inset

**Out of 19 attempts, 11 came back as a complete 16:9 picture, usually 446x251, centred in a flat border.** No prompt wording, style image, reference or figure size explained it, so treat it as chance, and don't pay to retry unless the picture itself is wrong. `Full-bleed` wording did not stop it, and it remains in the prompts only because the kept shots used it.

**The free fix:** `python tools/art/fix_intro_shot.py FILE` crops the border and enlarges to 640x360 with nearest-neighbour. The pixels come out coarser (1.22x to 1.44x), and it holds up well. Inpainting cannot fill the border on this plan: above 256 px it needs Tier 2.

## Words to reuse exactly

**{START}**
```
Full-bleed scene filling the whole canvas edge to edge, no border, no frame, no margin.
```

**{FOUR}** the four travellers:
```
The four travellers: four grown adults, anonymous hooded figures in long tattered dark grey cloaks, hoods up, faces never visible, seen only from behind, grim realistic proportions with small heads, not children, not cute. From left to right: a tall broad figure with a sword hilt showing over one shoulder; a shorter stocky figure with a faint dull gold glint of a holy symbol at the belt; a slight lean figure, slightly hunched, with a pack; a tall thin figure leaning on a long staff. Thin pale moonlight on the edges of their cloaks and hoods so their silhouettes read against the road.
```
For a silhouette, replace `seen only from behind` with `seen only in silhouette` and leave out the glint and the moonlight sentence.

**{WEATHER}**
```
Clear night air, no fog, no mist, no lightning, no rain, no text.
```

**{END}** the suffix from `art_style.md` without `front view`, which contradicts a landscape or a party seen from behind:
```
Dark cursed dungeon, gloomy, desaturated cold greys, deep near-black shadows, sickly pale green curse glow, decayed and rotten, 1991 pixel art, 1px dark outline, no anti-aliasing, limited palette
```

## Shots

"Attempts" is what was paid; kept pictures are in `tools/art/pieces/intro/<shot>_raw.png`, already fixed. Every prompt is the text below plus the blocks named. Shots 1 to 3 said `A pale full moon partly behind ragged dark clouds in the upper right.` before the weather. Shots 1 and 2 predate the word `no rain`.

| Shot | Attempts | Generations | Result |
|---|---|---|---|
| 1 road | 1 | 25 | Native |
| 2 travellers | 2 | 50 | Native |
| 3 crow | 1 | 25 | Native |
| 4 trees | 4 | 100 | Enlarged 1.43x |
| 5 boots | 1 | 25 | Native |
| 6 ruins | 1 | 25 | Native, `--dim-moon` |
| 7 silhouette | 2 | 50 | Enlarged 1.43x, `--grey` |
| 8 holy symbol | 1 | 25 | Native, `--dim-moon` |
| 9 sword | 1 | 25 | Enlarged 1.43x, `--grey` |
| 10 entrance | 1 | 25 | Enlarged 1.44x, `--dim-moon` |
| 11 archway | 1 | 25 | Enlarged 1.22x, `--dim-moon` |
| 12 tunnel | 1 | 25 | Enlarged 1.43x |
| 13 inside | 1 | 25 | Native |
| 14 looking out | 1 | 25 | Native, `--grey 342 60 506 285` |
| **Total** | **19** | **475** | Checked against the account balance |

1. `A wide moonlit landscape at night: a lonely empty dirt road winds from the bottom foreground through black dead twisted leafless trees toward a distant hill. On top of the far hill, very small in the frame, sit crumbled stone brick ruins around one ruined stone archway, with a tiny sickly pale green glow inside the arch, the only green in the scene.` {WEATHER}, also `no people`. {END}
2. {START} `The same low rounded hill and winding dirt road at night, seen from further along the road. Four cloaked travellers walk away from the viewer along the road in a loose line, seen from behind, small in the frame, in the lower middle of the picture.` {FOUR} `Black dead twisted leafless trees on both sides. The low rounded hill, not a mountain, with the small ruined stone archway and its tiny sickly green glow straight ahead in the distance.` {WEATHER} {END}. By hand afterwards: 6 gold pixels on the belt ring, the holy symbol's glint.
3. {START} `Close view beside the same winding dirt road at night: a black crow perched on top of a broken, leaning wooden signpost with one snapped, rotten plank sign; the sign's lettering is completely worn away, blank weathered wood with no letters. The crow is seen side-on, dark with a thin pale rim of moonlight along its back. Black dead twisted leafless trees behind, and far off the low rounded hill.` {WEATHER}, also `no people`. {END}
4. {START} `Close to the viewer at night: four cloaked travellers push through a dense thicket of black dead twisted leafless trees, seen from behind, the figures large in the picture, each about a third of the picture's height, with their feet near the bottom edge; branches claw across them and crowd right up to all four edges of the picture.` {FOUR} `A pale full moon partly behind ragged dark clouds in the upper right, seen through the branches.` {WEATHER} {END}. Style: title. Reference: road.
5. {START} `Close-up at ground level on a muddy road at night: worn cracked leather boots and the tattered hems of long dark grey cloaks, seen from behind and from the knees down only, no faces, stepping over old yellowed bones and a cracked human skull half-buried in dark wet mud. Puddles catch thin pale moonlight. Dead black roots at the edges of the picture.` {WEATHER} {END}. Reference: `travellers_ref.png`, usage `the same boots and tattered cloak hems as these figures`.
6. {START} `The ruins come into view at night, seen from partway up the hill, at middle distance: the same crumbled stone brick walls around the same ruined stone archway, with a sickly pale green glow inside the arch, black dead twisted trees either side. Heavy dark storm clouds roll in and darken the sky; the moon in the upper right is dim, almost swallowed by the clouds, only a faint pale smudge.` {WEATHER}, also `no people`. {END}. The moon still came out bright: `--dim-moon` did the dimming.
7. {START} `Close to the viewer on a bare ridge at night, seen from low down: the four travellers stand in a row in pure near-black silhouette against a heavy dark grey storm sky, the figures large in the picture, each about half of the picture's height, with their feet near the bottom edge, the storm clouds reaching all four edges of the picture.` {FOUR, as a silhouette} `Bare black dead twisted trees at the edges. The moon hidden behind thick cloud. The sky is cold grey, not green.` {WEATHER} {END}, without `sickly pale green curse glow`. Style: title. Reference: road, usage `the same dead trees and night sky, full frame composition`.
8. {START} `One hooded figure seen from behind, from the waist up, large in the frame, a shorter stocky grown adult in a long tattered dark grey cloak, hood up, face never visible, grim realistic proportions, raises one arm high holding up a small worn holy symbol on a chain. The symbol glows a faint dull gold, a small weak pool of gold light on the raised hand and the edge of the hood, the only warm colour in the picture. Beyond them, far off and blurred with darkness, the low rounded hill with the small ruined stone archway and its tiny sickly green glow. Black dead twisted trees at the edges. Thin pale moonlight on the edges of the cloak and hood. Heavy dark clouds, the moon dim behind them.` {WEATHER} {END}. Reference: shot 2, usage `the second figure from the left, the short stocky one: same build and cloak, full frame composition`.
9. {START} `One hooded figure seen side-on, from the thighs up, large in the frame, a tall broad grown adult in a long tattered dark grey cloak, hood up pulled low, face never visible, only deep shadow inside the hood, grim realistic proportions, draws a notched worn sword from a scabbard over the shoulder, the blade half out catching a thin line of pale light. Dark stormy sky and black dead twisted trees behind. Thin pale moonlight on the edges of the cloak and hood.` {WEATHER} {END}. Reference: shot 2, usage `the tall broad figure on the far left with the sword over the shoulder: same build and cloak, full frame composition`.
10. {START} `The dungeon entrance seen from the party's point of view, now close, from standing height at the foot of worn stone steps that climb to it: the same ruined stone brick archway fills most of the picture, broken walls either side, a strong sickly pale green glow deep inside the black tunnel, spilling onto the steps. Black dead twisted trees either side. Dark storm clouds above, the moon dim behind them.` {WEATHER}, also `no people`. {END}. Reference: title, seen from close up.
11. {START} `The huge ruined stone brick archway towers over the four travellers, who stand small at its foot on worn stone steps, seen from behind, tiny figures dwarfed by the stone, the arch filling the picture from top to bottom. A sickly pale green glow from deep inside the black tunnel outlines them.` {FOUR, without the moonlight sentence} `Broken walls and black dead twisted trees either side, storm clouds above, the moon dim.` {WEATHER} {END}. Reference: title, usage `the same ruined brick archway and broken walls, here seen from below, much larger`.
12. {START} `Over-the-shoulder view into the tunnel: in the near foreground at one side, the dark hooded shoulder and head of one traveller seen from behind, a long tattered dark grey cloak, hood up, face never visible. Ahead, the old stone brick tunnel runs into deep darkness, with a sickly pale green glow far inside. Faint worn carvings of faces and borders on the tunnel walls, half gone, just catching the green light.` `Clear air,` then {WEATHER} {END}. Reference: title, usage `the same stone brick masonry and the same dark tunnel with its green glow, here seen from just inside the arch`.
13. {START} `The four travellers step inside the stone brick tunnel, seen from behind, walking away from the viewer toward a faint sickly pale green glow ahead. The last thin cold moonlight falls in from behind the viewer across the floor, catching the edges of their cloaks and fading to black.` {FOUR, without the moonlight sentence} `Clear air,` then {WEATHER} {END}. Reference: shot 2.
14. {START} `From deep inside the dark stone brick tunnel looking back out through the arch: black tunnel walls frame a bright opening of stormy night sky with heavy grey clouds. Four small near-black silhouettes stand in the archway, seen from the front but in pure silhouette with no features at all, faces never visible, hoods up.` {FOUR, as a silhouette, `long tattered cloaks`} `A faint sickly green glow on the tunnel floor at the bottom edge.` `Clear air,` then {WEATHER} {END}. Reference: title, usage `the same stone brick arch and masonry, here seen from inside looking out`.

## Pipeline

1. Add the shot's name to `SHOTS` in `tools/art/gen_intro.py` and run `python tools/art/build_all.py --only intro`: the placeholder gives the importer its size. Add it to `SHOTS` in `scripts/intro_player.gd` too.
2. Save the export as `tools/art/inbox/intro/<shot>.png`, and run `python tools/art/fix_intro_shot.py` on it, with `--dim-moon` from shot 6 on and `--grey` if a sky comes out tan or green.
3. Copy it to `tools/art/pieces/intro/<shot>_raw.png`, because the inbox is git-ignored.
4. `python tools/art/import_pixellab.py --dry-run`, then the real run. Then `build_all.py --only intro` again if the shot has a pulsing glow layer (`GLOWS`).
5. Check it next to the title and shot 2. Target: 0 off-palette pixels, curse accents about 0 to 3%, no bruise purple.

**Palette traps:** PixelLab's night greys lean violet and snap to bruise purple, so the importer turns bruise colours grey for `intro/` keys (`grey_out_bruise`), and purple won't survive in an intro shot. A mid grey snaps to tan (`bone_700`), even a neutral one; `--grey` tints it bluer first.

## Effect layers

All in `art/intro/fx/`, drawn by `gen_intro.py`, so they cost nothing and are never baked into a shot; hard pixel edges, with density from dithering. `lightning_1..3` (200x320), `flash` (640x360), `fog_thin` and `fog_thick` (640x180, seamless sideways), `rain_0..7` (128x176, tiling, looping), `<shot>_glow` (only that shot's glowing pixels, pulsed by the player). `audio/sfx/thunder.wav` is a placeholder from `tools/audio/gen_sounds.py`.
