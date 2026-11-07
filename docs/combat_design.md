# Combat design

The combat rules, including critical hits and critical fails, live on one page, so there is a single copy to keep up to date:

https://claude.ai/artifact/BGAw8C4bkJfdBrSScE49yY

See the "Critical hits and fails" and "Hits from behind and the sides" sections. The maths is in `scripts/combat_rules.gd`, the tunable feedback in `data/combat_feel.tres` and the lines in `data/banter.json`.

## Equipment rules

- **Mages can't wear armour. This is intentional.** It is set per item with `ItemDef.cant_use` (a list of class names); today only Leather Armour lists "Mage", so any armour added later must list it too. The inventory slots and portrait-click equipping both refuse with "The mage can't wear that."
- Armour or a weapon on the cursor, clicked onto a portrait, equips it (armour slot, or the main hand). Shift-click on floor armour equips it on the hero who gains the most defence.
