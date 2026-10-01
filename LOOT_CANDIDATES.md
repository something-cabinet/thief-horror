# Haunted House Loot Catalog

Source: `PSX Mega Pack v3.2.1.zip`, audited across all 592 GLB models.

The runtime catalog contains **38 item families**, **106 model variants**
(102 selected pack models plus 4 existing game models), and **38 rendered 3D
inventory icons**. Every accepted visual variant is selected randomly within its
family, so repeated books, cash, food, medicine, and tools do not reuse one model.

## Runtime placement balance

The house exposes 236 candidate sockets. The deterministic QA seed places 102
items with these totals:

| Furniture | Candidate sockets | Items placed |
| --- | ---: | ---: |
| Drawer | 18 | 18 |
| Cabinet | 33 | 33 |
| Wardrobe | 8 | 8 |
| Fridge | 4 | 8 |
| Shelf | 156 | 20 |
| Table / counter | 17 | 15 |

Every independently openable cabinet or wardrobe door maps to exactly one
populated compartment; every drawer is populated, and each refrigerator shelf
holds two items. If a randomized model cannot fit, the spawner tries another
item/model instead of leaving the compartment empty. Shelf loot uses 18 occupied
sockets, including 2 double-item sockets, chosen across the whole house. Tables
are filtered for clear player access and full-footprint mesh support; invalid
randomized positions are retried, not forced onto empty space.

## Item families

- Valuables and personal: cash, coins, gold bar, books, notebook, paintings,
  photo frames, clocks, and crucifixes.
- Food and kitchen: canned food, raw meat, lollipops, glass bottles, plates,
  cutlery, rusty tins, fish bones, kitchen knives, and sponges.
- Medical: medicine bottles, medicine packets, loose pills, bandages, and
  syringes.
- Household and utility: cigarettes, ashtrays, lighters, matches, writing tools,
  magnets, flashlights, batteries, hand saws, screwdrivers, nails, antique radios,
  banker's lamps, and potted plants.

## Semantic placement rules

- Raw meat, rusty tins, and fish bones are fridge-only. They sit on the actual
  hollow refrigerator/freezer shelves, never inside the moving door rails.
- Food, crockery, cleaning items, and hand tools favor cabinets.
- Gold bars are hidden in drawers or wardrobes, never left on tables.
- Lamps, radios, plants, frames, books, and clocks use visible shelves/tables.
- Personal valuables, medicine, smoking items, and small tools use drawers.
- Every catalog family is guaranteed at least one valid furniture category.

## Deliberate exclusions

- Modern electronics: computers, mobile phones, game consoles, and similar props.
- Structural or oversized props: furniture, doors, appliances, jerrycans, and car
  batteries that do not make sense in the five-slot handheld inventory.
- Story-state objects: keys, locks, documents, and puzzle-specific props.
- Joke props and unrelated weapons that would dilute the house's grounded tone.

Run the complete geometry, reachability, catalog, icon, and placement checks with:

```bash
godot --headless --path . --script tools/verify_house_loot_sockets.gd
godot --headless --path . --script tools/verify_loot_seed_coverage.gd
```
