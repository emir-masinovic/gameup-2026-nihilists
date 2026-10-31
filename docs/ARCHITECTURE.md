# Architecture

Keep feature scenes, scripts, resources and media together under `features/`; see [AGENTS.md](../AGENTS.md) for conventions and [DESIGN.md](DESIGN.md) for working design direction. Godot4.7.2 uses Compatibility rendering. Script/shader UIDs and asset import descriptors are tracked; generated `.godot/` caches and export output are not.

## Ownership and entry points

- `features/menus/`: Main Menu, Pause, shared Options, SceneFlow and the nature theme.
- `features/settings/`: SettingsManager and Master/Music/SFX bus layout.
- `features/save_system/`: version-1 permanent progression.
- `features/player/`: GridPlayer and the independent SurvivalState model.
- `features/levels/forest/`: region generation/climate, interactions, resource visuals, camera and RunHUD.
- `features/audio/`: SoundPalette, selected CC0 recordings and provenance.
- `tests/`: focused model, scene, persistence, camera/input, desktop and rendering regressions.

`main_menu.tscn` is startup; `application/run/playable_scene` selects the forest. SceneFlow owns scene transitions and a Pause canvas above the world HUD. Nested Options returns to Pause; Resume restores gameplay. Gameplay modals pause the world and camera. Active-run disk restoration is not implemented, so Continue is disabled.

## Camera, input and settings

Follow Player is the default for fresh settings. Board Center is the other supported targeting mode. C cycles between them by default; runtime cycling is temporary, while Gameplay Options persists the independent default. Old removed-mode or invalid settings migrate to Follow Player. Orthographic/Perspective projection, pole-safe yaw/pitch orbit and zoom10–56 remain independent. Transitions preserve view parameters and bind the camera to the arriving player or current grid center. Mode switches interpolate smoothly; Pause, Options and focus loss block/cancel camera gestures.

`configure_targets(center, player, restore={})` and `get_transition_state()` connect the level and camera. GridPlayer projects cardinal steps through Camera3D and chooses one opposite-paired four-key mapping, with aggregate hysteresis0.16. Truly edge-on projections use a nearest-visible fallback. `try_move(direction)` remains world-cardinal, and camera changes never mutate grid coordinates.

SettingsManager persists `user://settings.cfg`: audio, desktop window/resolution/VSync/FPS, MSAA, shadows, projection, default targeting mode and bindings. InputMap codes are positive physical keys, negative mouse buttons/wheels and zero for empty slots. Binding capture has two slots, conflict checks and Escape cancellation. Legacy C/F assignments remain intact; conflicting new defaults become unbound. Interact defaults E/Space, Eat F, orbit middle/right mouse and zoom the wheel. Controls reset bindings/sensitivity; Gameplay resets projection/mode. Window controls are disabled where Web/headless owns them.

## Run regions and simulation

SceneFlow owns one memory-only `RunRegions` cache: Forest connects west to Drylands and east to Wetlands. Stable regional seeds derive from the run seed with offsets104729/209458. Each region retains its live GridData/ClimateSimulation, RNG, cut history, forage and visit/time metadata. Survival, objectives and a run-local StatePlanting inventory are shared. Only one graphical world is loaded; returning reconstructs trees, stumps and oriented logs from logical state. Inactive climate/forage catch-up is capped at30 seconds and excess backlog is discarded. No wall-clock/background survival damage runs. New Game/Main Menu discards temporary models.

Generation version2 builds17×17 cells spaced2 world units apart. Protected central routes and named edge trails remain reachable; arrivals are one tile inside the corresponding edge. A narrow deterministic pond-shore approach guarantees drinking access. Transitions cancel interactions/orbit, guard Pause/loading and require held movement keys to be released.

Climate is authoritative: bounded warming approaches+12C over a600-second timescale, separate from60-second weather periods, local moisture, canopy and vegetation health. Drylands is hotter/drier with more heat periods; Wetlands is cooler/moister with more rain and a recovering habitat at(8,5). Rain supports surviving vegetation, drought/heat cause stress, and dead/cut trees do not return as mature trees. Wet ponds block movement, retain adjacent moisture and exclude wildfire; their rendered surface shrinks/disappears at the same .1 water threshold used for traversal.

Wildfire uses seeded snapshot cardinal spread on scheduled ticks. Dryness, heat and remaining fuel gate ignition; rain quenches flames and exhausted fuel cannot reignite. Camp is protected. Cutting/removing fuel creates a tradeoff with lost canopy; burned ground recovers slowly under favorable conditions. These are simplified game rules, not scientific prediction.

## Interactions, survival and progression

`InteractionContext` selects descriptors by Manhattan range, facing, priority and stable ID; it owns paused/cancellable timing and optional zero-argument callbacks. One target ring, saved-binding prompt and progress bar serve tree chopping, stump/log clearing, camp, berry harvest, pond drinking and seed planting. Movement cancels actions. Trees fall away from the player, retain blocked stumps and can create blocked logs at valid landings; trail/arrival cells are reserved. Clearing logs reopens routes. The existing `forest_interactions` model API remains usable.

`StatePlanting.availability/plant/collect_seed` owns planting eligibility and a shared run inventory (3 initial, 9 maximum). Interact plants on adjacent empty soil, excluding ponds, occupied cells, decorative props, registered objects, fire/char, camp and protected trails. Each original healthy mature tree yields at most one seed; planted trees and stumps never yield seeds. No watering action is imported. Seed count resets with New Game, while stable `interaction.first_planting` and `flora.planted_growth` discoveries award permanent Knowledge once each.

Climate advances saplings through three visible sizes at 0/60/120 favorable seconds and matures them at 240. Moisture must exceed .35 and canopy-adjusted temperature stay within 8–34°C. Drought/heat stop growth and damage seedlings; dead seedlings stay dead. Mature trees use existing canopy, cutting and fire systems. Young plants also burn and never regrow after exhausted fire. Plants, death, growth progress and inventory survive regional round trips; inactive growth follows the existing bounded climate catch-up. `VisualSapling` reuses Onur's shared procedural geometry. RunHUD adds one Seeds row using the existing theme.

`ResourceForaging` seeds4/3/1 nonblocking berry bushes in Forest/Wetlands/Drylands with separate RNG. Harvest yields two berries, preserves the bush and requires180 accumulated favorable seconds to replenish. Depletion survives regional re-entry. Eating restores food reserves; adjacent wet freshwater restores water without changing pond volume. First discoveries award Knowledge once.

SurvivalState owns health, body temperature, wetness, remaining food/water, berry count and latched death. `tick(seconds, ambient, shade, safe, heat_resistance, context={})` receives weather/canopy/wind/fire context; `damage`, `add_berries`, `eat_berry` and `drink` expose mutations. Exposure is only a legacy view of body temperature. Heat Resistance reduces warming; living canopy reduces heat/rain exposure; wetness increases cold pressure. Camp restores comfortable temperature, dries and heals without refilling reserves. Fire health damage stays level-owned. RunHUD separates compact player stats from region/climate status.

SaveManager atomically retains version-1 `user://progression.json`. `discover(id)` awards one Knowledge only after a successful first persisted discovery. Heat Resistance costs3; Quick Chop costs2 and scales action time by.65; Fire Resilience costs2 and scales fire damage by.6. Existing upgrade IDs survive. The current visible field-note sequence is Drylands survey/fuel clearing, nearby Wetlands recovery, then its northern refuge. Human pacing remains a playtest concern.

## Player model and vegetation extension points

`GridPlayer/Body` instances the independently replaceable `VisualAstronaut` scene adapted from Onur (source/provenance beside it). Its step signal drives hopping and limb motion at the existing .16-second cadence; contextual chopping calls `start_chopping`/`stop_chopping`. The controller, grid coordinates and camera-relative mapping remain unchanged. `cell`, `facing`, `moving` and `try_move` remain the movement interface. Steps tween for.16 seconds; `cell_entered` fires at step start, `move_tween.finished` at arrival. Camera targeting uses GridPlayer, not bones/meshes. WetIndicator and AudioListener3D are independent children. Animations may read movement and `world.context_action.active/progress`; no extra FSM or binding obligation is imposed.

The active world exposes `grid`, `climate`, `region_state`, `regions` and `survival`. Use `grid.in_bounds`, `grid.traversable`, `grid.world_position` and `grid.cells[y * grid.SIZE + x]`. `climate.cell_conditions(cell)` returns a read-only snapshot of temperature/weather, moisture/health, tree health/state, burning, terrain/water, canopy and hazard; invalid cells return `{}`. Mature-tree simulation recognizes `tree`, `tree_state` (healthy/dead/stump/removed) and `tree_health`0–1. The additional `sapling` tree state uses `planted`, `growth_age` and `growth_discovered` in the same regional cells.

`world.register_vegetation_visual(cell, unparented_node)` registers a visual without changing logical state/passability. An optional adapter may implement `set_health(health, dead, moisture, burned)`. `world.register_interactable(descriptor)` accepts a unique nonempty `id` and valid `cell`, plus `name`, `action`, `range` (grid Manhattan units), `duration`, `available`, `reason`, `priority`, and optional zero-argument `complete/cancel` Callables. Update the shared descriptor's availability as conditions change. Re-register scene visuals/interactions from logical regional state on loading; never cache freed nodes. Use stable SaveManager discovery IDs rather than per-action IDs.

## Rendering, assets and validation

Terrain uses at most19 shared material batches, including persistent brown generated soil with no grass cover; vegetation, fire and rain use bounded shared resources. Terrain receives tree/prop shadows but does not cast self-shadow acne. Climate drives foliage/ground appearance; shader motion is cosmetic. Day/night lighting and bonfire flame/smoke remain independent of simulation authority. SoundPalette is a SceneFlow child with four UI and eight world voices routed to SFX; Dummy headless output validates dispatch without decoder playback. Finished ambience/music is pending.

Kenney model/audio license and attribution files remain beside selected assets; central originals are untouched. Alegreya Sans retains its OFL under `features/menus/fonts/`. Preserve notices with distributions.

Import with Godot `--headless --editor --import --quit`. Run focused `tests/*_test.gd` scripts through `--headless --script`; settings_restart_test requires `-- --write` followed by a fresh reload process. Desktop/capture tests require a real display; set NIHILISTS_CAPTURE_DIR outside the repository. Use separate test save paths. Export presets supply Windows Desktop and single-thread Web; serve Web output via HTTP(S), not file://. No Cross-Origin Isolation is needed by this preset. Keep exports, screenshots and benchmark output outside Git.
