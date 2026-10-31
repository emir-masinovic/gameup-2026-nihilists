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

`StatePlanting` owns a shared run inventory (3 initial seeds, 9 maximum; bottle 500 initial/1000 maximum ml). `soil_availability/prepare/availability/plant` exposes Prepare Soil then Plant Seed on adjacent authored soil, retaining exclusions for ponds, occupied cells, props, registered objects, fire/char, camp and protected trails. Preparation persists in regional cells. Existing Interact bindings and target selection serve every action; no separate chopping input is added.

`water_availability/water_plant/fill_bottle` spends 250 ml to add .5 real moisture to thirsty living planted saplings. Rain remains the existing natural moisture source; watering neither advances age nor resurrects dead plants. Ponds above the shared .1 water threshold simultaneously offer Drink / Fill Bottle (+500 ml, capped); dry ponds offer neither. The prompt/toast reports bottle contents without expanding the survival HUD. Once a young plant is sufficiently wet it offers the existing Remove action; a dry plant with an empty bottle asks for a refill rather than switching to destructive removal.

An eligible healthy original tree produces one visible seed drop at its stump through `record_seed_drop`; chopping no longer awards inventory. `collect_seed` uses an adjacent contextual action, leaves blocked stump/log behavior intact, and retains pending drops when the pouch is full. Planted/dead trees cannot create drops; each original yield is claimed once. Pending drops, preparation, growth and shared bottle/seed inventory persist across regional round trips. New Game resets temporary inventories; existing unique planting/growth Knowledge IDs remain permanent.

VisualAstronaut adapts Onur's hoe/bottle and tilling/filling/watering/gathering poses (provenance beside it). Actions put tools away on completion, cancellation, movement or region transitions; animation never owns logical movement.

Climate advances saplings through three visible sizes at 0/30/75 favorable seconds and matures them at 120. Moisture must exceed .35 and canopy-adjusted temperature stay within 8–34°C. Drought/heat stop growth and damage seedlings; dead seedlings stay dead. Mature trees use existing canopy, cutting and fire systems. Young plants also burn and never regrow after exhausted fire. Plants, death, growth progress and inventory survive regional round trips; inactive growth follows the existing bounded climate catch-up. `VisualSapling` reuses Onur's shared procedural geometry. RunHUD adds one Seeds row using the existing theme.

`ResourceForaging` seeds4/3/1 nonblocking berry bushes in Forest/Wetlands/Drylands with separate RNG. Harvest yields two berries, preserves the bush and requires180 accumulated favorable seconds to replenish. Depletion survives regional re-entry. Eating restores food reserves; adjacent wet freshwater restores water without changing pond volume. First discoveries award Knowledge once.

SurvivalState owns health, body temperature, wetness, remaining food/water, berry count and latched death. `tick(seconds, ambient, shade, safe, heat_resistance, context={})` receives weather/canopy/wind/fire context; `damage`, `add_berries`, `eat_berry` and `drink` expose mutations. Exposure is only a legacy view of body temperature. Heat Resistance reduces warming; living canopy reduces heat/rain exposure; wetness increases cold pressure. Camp restores comfortable temperature, dries and heals without refilling reserves. Fire health damage stays level-owned. RunHUD separates compact player stats from region/climate status.

SaveManager atomically retains version-1 `user://progression.json`. `discover(id)` awards one Knowledge only after a successful first persisted discovery. Heat Resistance costs3; Quick Chop costs2 and scales action time by.65; Fire Resilience costs2 and scales fire damage by.6. Existing upgrade IDs survive. The current visible field-note sequence is Drylands survey/fuel clearing, nearby Wetlands recovery, then its northern refuge. Human pacing remains a playtest concern.

## Player model and vegetation extension points

`GridPlayer/Body` instances the independently replaceable `VisualAstronaut` scene adapted from Onur (source/provenance beside it). Its step signal drives hopping and limb motion at the existing .16-second cadence; contextual chopping calls `start_chopping`/`stop_chopping`. The controller, grid coordinates and camera-relative mapping remain unchanged. `cell`, `facing`, `moving` and `try_move` remain the movement interface. Steps tween for.16 seconds; `cell_entered` fires at step start, `move_tween.finished` at arrival. Camera targeting uses GridPlayer, not bones/meshes. WetIndicator and AudioListener3D are independent children. Animations may read movement and `world.context_action.active/progress`; no extra FSM or binding obligation is imposed.

The active world exposes `grid`, `climate`, `region_state`, `regions` and `survival`. Use `grid.in_bounds`, `grid.traversable`, `grid.world_position` and `grid.cells[y * grid.SIZE + x]`. `climate.cell_conditions(cell)` returns a read-only snapshot of temperature/weather, moisture/health, tree health/state, burning, terrain/water, canopy and hazard; invalid cells return `{}`. Mature-tree simulation recognizes `tree`, `tree_state` (healthy/dead/stump/removed) and `tree_health`0–1. The additional `sapling` tree state uses `planted`, `growth_age` and `growth_discovered` in the same regional cells.

`world.register_vegetation_visual(cell, unparented_node)` registers a visual without changing logical state/passability. An optional adapter may implement `set_health(health, dead, moisture, burned)`. `world.register_interactable(descriptor)` accepts a unique nonempty `id` and valid `cell`, plus `name`, `action`, `range` (grid Manhattan units), `duration`, `available`, `reason`, `priority`, and optional zero-argument `complete/cancel` Callables. Update the shared descriptor's availability as conditions change. Re-register scene visuals/interactions from logical regional state on loading; never cache freed nodes. Use stable SaveManager discovery IDs rather than per-action IDs.

## Rendering, assets and validation

Terrain uses at most20 shared material batches, including wet/dry brown generated soil with no grass cover; vegetation, fire and rain use bounded shared resources. Terrain receives tree/prop shadows but does not cast self-shadow acne. Climate drives foliage/ground appearance; shader motion is cosmetic. Day/night lighting and bonfire flame/smoke remain independent of simulation authority. SoundPalette is a SceneFlow child with four UI and eight world voices routed to SFX; Dummy headless output validates dispatch without decoder playback. Finished ambience/music is pending.

Kenney model/audio license and attribution files remain beside selected assets; central originals are untouched. Alegreya Sans retains its OFL under `features/menus/fonts/`. Preserve notices with distributions.

Import with Godot `--headless --editor --import --quit`. Run focused `tests/*_test.gd` scripts through `--headless --script`; settings_restart_test requires `-- --write` followed by a fresh reload process. Desktop/capture tests require a real display; set NIHILISTS_CAPTURE_DIR outside the repository. Use separate test save paths. Export presets supply Windows Desktop and single-thread Web; serve Web output via HTTP(S), not file://. No Cross-Origin Isolation is needed by this preset. Keep exports, screenshots and benchmark output outside Git.

ClimateSimulation.temperature_at(cell) exposes canopy-cooled ground temperature; cell_conditions also retains regional_temperature for comparisons. Drying, stress and recovery use the local ground value, with snapshot canopy per simulation step. Survival keeps regional ambient plus its existing canopy response to avoid duplicate cooling. Debug-only --microclimate-demo sets sapling_growth_rate=4 in RunRegions; only favorable growth age/health advance faster. The shared StatePlanting duration/stage definition drives maturity, visuals and juvenile interactions. The contextual caption adds ground °C and soil moisture without another HUD panel.

Visual ecosystem: ground_cover owns two vegetation MultiMeshes and three partitioned crack MultiMeshes (one crack variant per cell; one to four clustered grass clumps per grass cell, no decoration nodes per clump). Transform interpolation runs only until targets settle, using live moisture/health; it never changes passability or RNG. Leaf materials remain a shared four-state palette, with stable thinning/hysteresis and shared dead-branch geometry. Brown soil excludes grass/cracks. Debug-only --ecosystem-demo selects deterministic seed/initial patches and a clear/rain/clear weather schedule; all later conditions remain climate-driven, and normal generation is unchanged.

Visual polish uses seeded cosmetic noise for clump counts and cached position/scale/rotation variations. Three crack patterns share a single material and partition the existing cell count. Terrain reuses existing fine noise for moisture/health-driven green flecks; no extra noise sample or texture is added. Living improving trees may use two shared sparse-green recovery materials; logical dead trees remain barren. None of these presentation choices changes soil simulation, hazards or passability.


### Living vegetation and camp soil (Batch 3)

Grass retains deterministic noise-clustered MultiMesh placement, seeded rotations and size variation. Each shared tuft now has three tapered, three-segment blades (18 triangles versus the previous imported clump's 132). Soil vitality controls density, scale, height and color; recovering vegetation starts as short shoots. Shrubs retain their imported mesh. Crack batches and prepared soil exclusions are unchanged.

The shared foliage vertex shader uses a travelling world-space wind field, slow sinusoidal gusts, a small seeded instance phase offset and quadratic height weighting. Roots have zero displacement; tall healthy blades bend more. Tree leaves share the direction/field with reduced amplitudes for stressed foliage; trunks and dead branches remain rigid. Wind requires no CPU instance updates. Existing growth interpolation remains on the CPU while appearance changes settle.

Technical inspiration: [SimonDev Quick_Grass](https://github.com/simondevyoutube/Quick_Grass), specifically instanced procedural blades, coherent wind and height-weighted bending. This is an original small Godot adaptation, not a port of the renderer. The video was unavailable during inspection.

Region bonfire intensity feeds the existing climate simulation, defaulting to zero in standalone simulations. A smooth 3.2-world-unit radius around the rendered fire adds at most 3.5 degrees of ground warmth and 0.003 extra moisture loss per second (plus existing temperature-driven evaporation). Water tiles and distant cells are excluded. Rain can overcome this drying, and weak/extinguished fires contribute proportionally less/no influence. This changes soil conditions only: existing player warmth/drying, fire weakening, rest/progression and hazard rules are unchanged.

Inspect with `-- --ecosystem-demo` for the existing deterministic drought/rain recovery schedule. At normal zoom, compare rooted grass tips over several seconds; use Board Center for clustered height/color transitions. Near camp, compare ground before and after one to two dry minutes, then rain. Desktop Compatibility captures and Web export validate rendering/export, not a browser FPS benchmark.


### Dense vegetation and shared wind (Batch 4)

Ground cover now allocates a noise-dependent 3–11 tuft capacity per eligible cell instead of 1–4. Seeded clustering, jitter, rotation and scale variation remain independent of simulation RNG. Real health/moisture still controls visibility and height; the blade mesh and maximum height have not increased. Grass is suppressed on camp, rocks, trees/stumps, logs, berry bushes, water and prepared soil; capacities remain available for growth after occupied grass cells are cleared. No per-blade nodes or extra render batches are added.

`ClimateSimulation.wind_state(fractional_seconds = 0.0, run_seconds = -1.0)` is a pure deterministic API returning `direction: Vector2` (world X/Z travel **towards**), `strength: float` (normalized 0–1) and `time: float`. Regions share the run wind seed and run clock to prevent direction/strength jumps on travel; standalone samples default to local climate time. It uses seeded smooth direction drift and gentle strength variations, not an additional weather simulation. North is -Z, east +X, south +Z, west -X. Future hazards may sample this API, but this batch deliberately does not alter survival wind exposure, movement, fire spread or damage.

The active scene sends one wind sample to the two ground-cover materials, six shared foliage materials and existing HUD. Grass has stronger rooted tip bending; foliage retains its restrained condition-dependent amplitudes. The shader uses this clock/direction/strength for travelling local gusts. CPU work is bounded by shared materials, not blade count. The HUD shows prevailing compass direction and normalized percentage alongside Knowledge without a new row or panel. Local gust and height weighting modulate the visible response.


Batch 4 desktop inspection (seed 2026): Forest allocated 1,766 grass tufts, with 1,444 non-negligible target scales; Wetlands 1,824 / 1,498; Drylands 1,821 / 685. All retain five ground-cover batches and 18 triangles per grass tuft. The reference allocation rose from 705 to 1,766 (2.5x); hidden instances still consume capacity, so these are geometry/instance counts, not FPS claims. Compatibility captures, HUD checks at 800x600 / 1152x720 / 1600x900, and Web export pass. Browser runtime/FPS remains a manual acceptance check.


### Grass distribution correction

Batch 4's single-round integer hash produced correlated X/Z samples: `_sample(key + 13)` was almost a constant wrapped offset from `_sample(key)`. Tile-local anchors/clamping reinforced the diagonal rows; low-frequency noise only changed the count per tile. World-to-local conversion was correct. The accepted blades, shader, wind, tree sway, climate, height range and HUD are unchanged by this correction.

Grass placement now generates fully jittered candidates in fine world-space strata across the entire region. Independent seeded RNG draws supply coordinates and appearance. A generation-only density field blends custom 2D Worley F1 (nearest of neighboring seeded cellular feature points), low-frequency coherent coverage and higher-frequency variation. Weighted sampling selects the existing total capacity from this field, allowing irregular gaps and dense patches across gameplay tile boundaries. Mapping accepted positions to logical cells happens afterwards, only for exclusions and real health/moisture response. There is no per-tile population quota or clamped tile-local offset. Appearance and growth update cached instances without resampling noise.

SimonDev's inspected `grass-component.js` uses separate seeded random X/Z draws for instanced positions; the Worley field and global stratified/budgeted selection here are our implementation, not a claimed algorithm from that reference. Shrub placement, crack patterns and five ground-cover batches remain intact. Seed 2026 retains 1,766 grass instances (Forest), 1,824 (Wetlands), and 1,821 (Drylands); active population differs slightly because world-space candidates now land in different excluded/climate cells.


### Natural regeneration and directional shelter (Batch 5)

Healthy mature trees accumulate reproduction credit only above 50% soil moisture and at 8–32 degrees local ground temperature. After 90 favorable seconds they may establish one nearby sapling; each region attempts at most one birth every 30 seconds. New trees reuse the existing 120-favorable-second growth stages, drought/fire health and regional persistence. At most twelve natural trees coexist, also bounded by initial tree population plus twelve and 32% grid occupancy. Eligible targets exclude water, camp/trails/pond approaches, prepared soil, rocks, forage, logs/stumps, seed drops and the active player. A flood-fill check rejects births that disconnect previously reachable ground. Climate drives regional differences; no biome reproduction bonus exists. Natural trees are marked to suppress seed drops and planted-growth Knowledge; manual replanting clears the natural-origin marker. No seed inventory is spent or awarded.

A 5x5 upwind stencil derives per-cell wind exposure from direction, tree health and maturity. Healthy near-upwind canopy attenuates strongly; multiple trees combine down to a 25% exposure floor. Young trees restore shelter gradually, dead branches provide only slight attenuation, and stumps provide none. The active region uploads 289 exposures packed into 73 vec4 uniforms on existing shared materials during visual refreshes (normally once per simulation second, immediately after interactions). Grass and foliage retain coherent GPU gusts and the global HUD is unchanged. There is no new survival or soil-drying wind formula. Inactive regions retain existing bounded catch-up; regeneration shares that limit. Field/maturation timing remains simulation time, not guaranteed wall-clock minutes under drought.


### Final cleanup and density checkpoint

Main Menu New Game atomically resets only saved progression (Knowledge, discoveries, perks), then starts fresh run state. Death-screen New attempt uses `SceneFlow.retry_game()` and retains progression. Settings are separate and unchanged. The temporary Wetlands golden refuge meshes, habitat marker/label, refuge win trigger and objective directions are disconnected from normal gameplay; recovery simulation and transition/interaction markers remain.

Grass population scale is now three, with world-space candidate strata tightened by sqrt(3) to retain the Worley field's acceptance ratio and irregular distribution. Seed-2026 capacities are Forest 5,298, Wetlands 5,472 and Drylands 5,463. Degraded soil still thins cover, so visible Drylands counts need not scale exactly threefold. Blade height/geometry, wind, exclusions and five cover batches are unchanged; higher vertex workload requires browser performance acceptance.
