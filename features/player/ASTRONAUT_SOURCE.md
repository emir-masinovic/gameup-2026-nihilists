# Astronaut provenance

Visual meshes/materials and walking/chopping animation curves adapted from Onur (LyotardPostmodernizm), teammate branch `environmental-changes(like-planting-seeds,-watering-the-soil)`, commit `638ba2037c51d4a599704933407f9531b3e16556`.

Source files: `features/player/grid_player.tscn` and visual portions of `grid_player.gd`. The packed Body is independently replaceable; current GridPlayer controller, camera mapping and 0.16-second logical step remain authoritative. Source controller, camera, HUD and forest implementation were not imported.

The sprout geometry in `../levels/forest/VisualSapling.tscn` also comes from Onur’s `forest_sapling.tscn` at the same commit. Planting is adapted to our contextual actions, run-local inventory and climate model; no watering or source controller is imported.

Hoe/bottle meshes and tilling, filling, watering and gathering animation poses are selectively adapted from Onur’s `d347d2a`; all animation remains inside VisualAstronaut, outside GridPlayer.

`../levels/forest/VisualSeedDrop.tscn` adapts Onur’s `forest_seed.tscn` at `d347d2a` as a collectible, with the sprout hidden and a lighter seed shell.
