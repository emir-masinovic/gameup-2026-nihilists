# Feature ownership

Keep scenes, scripts, resources, and local media with their feature. Use snake_case files and folders, PascalCase node/class names, and matching scene/script names where useful. See [AGENTS.md](../AGENTS.md) for collaboration and Git rules and [DESIGN.md](DESIGN.md) for the game direction.

## Implemented systems

- `features/menus/`: editable Main Menu, Pause and shared sidebar Options scenes; `scene_flow.gd`; `theme_forest.tres`; licensed Alegreya Sans under `fonts/`.
- `features/settings/`: `settings_manager.gd`, `audio_bus_layout.tres`.
- `features/save_system/`: `save_manager.gd`.
- `features/player/`: `grid_player.gd/.tscn`, `survival_state.gd`.
- `features/levels/forest/`: `forest_level.gd/.tscn`, `grid_data.gd`, `climate_simulation.gd`, `forest_interactions.gd`, `forest_tree.tscn`, `camera_orbit.gd`, `shader_grid.gdshader`, `run_hud.gd/.tscn`.
- `features/levels/prototype/prototype.tscn`: original bootstrap, retained unchanged.
- `tests/`: foundation, mouse bindings, camera/grid, projection, desktop video, persistence, climate, progression, and gameplay integration tests.

Required script/shader UID companions and font import descriptors are tracked. `.godot/` import, editor, shader and UID caches are ignored. Sparse decorative rocks use two small Kenney Nature Kit GLBs under `features/levels/forest/props/`; source originals stay in central-assets. The included CC0 license and ATTRIBUTION.md record provenance. Models use embedded materials, have no external textures or gameplay collision, and do not change grid passability or simulation seeds. Six additional CC0 models under `nature/` provide conifer/deciduous trees, stumps, logs, grass and shrubs; its ATTRIBUTION.md maps source names. Grounded tree adapters preserve falling pivots and share bark/foliage materials. Foliage states follow health; a cheap wind shader is presentation only. The procedural tree scene remains a fallback. Alegreya Sans Regular comes from the official Google Fonts repository (`ofl/alegreyasans`); its SIL Open Font License is included at `features/menus/fonts/OFL.txt`.

## Menus, settings and scene flow

The project starts at `main_menu.tscn`; `application/run/playable_scene` selects the forest. SceneFlow owns transitions and an always-processing Pause overlay on canvas layer 20, covering the world HUD when opaque Options is open. Back closes nested Options without resuming. New Game generates a fresh run seed; direct fixed-seed tests remain reproducible.

SettingsManager persists `user://settings.cfg`, independent of gameplay saves. It owns audio volumes, window mode/resolution, VSync, FPS cap, 3D MSAA Disabled/2x/4x, shadow quality, camera projection and bindings. Music and SFX feed Master. Video defaults reset only Video, Controls defaults reset all bindings and sensitivity, and Gameplay defaults reset projection only.

InputMap bindings use positive integers for physical keys, negative mouse indices, and zero for an empty slot. Older keyboard-only saves merge camera defaults. Two binding buttons per action capture input; the activation release cannot capture itself, Escape cancels, and conflicts are rejected across actions. Built-in menu navigation remains independent. Orbit accepts held mouse buttons; zoom accepts buttons/wheels. Mouse sensitivity is 0.002-0.020 radians/pixel (default 0.008).

Orthographic and Perspective projections share a fixed grid-center pivot and free yaw/pitch orbit through poles. Zoom is 10-56, default 42; perspective FOV is 55 degrees with near/far planes 0.1/200. The analytic orientation frame avoids look-at pole singularities. GridPlayer projects the four hypothetical cardinal steps through Camera3D and solves one opposite-paired, perpendicular, one-to-one mapping for all four keys. This prevents default-angle ties from making a world direction unreachable. Aggregate alignment hysteresis of 0.16 stabilizes camera boundaries; deterministic ties and tiny-axis rejection handle poles/horizontal views. Truly edge-on, collinear projections retain nearest-visible fallback with 0.08 per-key hysteresis. try_move remains a world-cardinal API and grid coordinates are unchanged. At exactly edge-on views a requested screen direction may have no visible grid-axis component; the deterministic nearest available direction is used.

Desktop window resolutions apply only in windowed mode and clamp to the usable display. Fullscreen uses desktop resolution. Web/headless window mode, resolution and VSync controls are disabled. Compatibility does not expose FXAA or TAA.

## Climate and vegetation

GridData generation version 2 produces the bounded 17x17 world from a seeded RNG. Logical cell centers are two units apart. The objective lies on the guaranteed traversable central route. Clustered tree placement, soil patches and a connected small pond vary the environment without blocking the protected central route. ClimateSimulation owns moisture, grass health, tree health/state, shade, water levels and wildfire; visual assets never decide passability. Rendering reads these values; no shader simulates gameplay.

The level schedules one simulation second per tick. Its exported `simulation_time_scale` defaults to 1; climate ticks cap catch-up work to 30 seconds. Temperature is a 24 C baseline plus a bounded warming pressure approaching +12 C (600-second timescale), and transient weather offsets. The HUD reports the actual warming pressure separately. Seeded 60-second clear/rain/cool/heat periods vary temperature and rainfall independently of the warming trend. This is a simplified greenhouse-warming game model, not an ozone or scientific climate model.

Moisture/health remain within 0-1. Heat dries soil, drought and heat stress vegetation, rain/cool conditions can restore moisture and surviving vegetation. Healthy adjacent trees contribute shade proportional to health. Dead, cut and removed trees do not recover or provide shade. Repeated steps trample grass by 0.12 health each; favorable conditions allow recovery. Recovery discovery requires an actual rise after visible damage.

Rendering uses 16 shared moisture/health terrain materials, shared wet/charred surfaces and health-driven imported foliage materials, updated on simulation ticks. Grass/shrubs, wildfire flames and rain use bounded MultiMesh batches. The terrain shader adds seed-dependent broad green/dirt clusters and restrained fine variation, modulated by the authoritative vegetation health. No per-tile material instances are created. `RendererTerrain.gd` groups the 289 closed tiles into at most 18 shared material batches and refreshes transforms on simulation ticks. Grid boundaries are derivative-antialiased shader patterns on closed tile meshes, not depth-conflicting overlays. A separate presentation clock drives a tunable 240-second day/night cycle: one directional light changes yaw/elevation continuously and dims to cool moonlight, with a 0.56 ambient-energy floor. Weather changes light color independently of the warming trend. User shadow settings still apply. Three opaque low-poly bonfire flame meshes share a vertex-flicker shader and pause with the world. Ten small CPU smoke particles and a non-shadowing warm light complement the bonfire. World geometry remains bounded. Directional shadows use two cascades and a 75-unit range to concentrate atlas detail; Off still disables them. GPU A/B testing identified diagonal terrain stripes as self-shadow acne, not procedural color variation. Terrain batches receive tree/prop shadows but do not cast; explicit grid-sized bounds cover initially empty batches.

## Interaction, survival and run lifecycle

GridPlayer emits cell-entry events and keeps movement separate from generation. Interact beside a tree begins a 1.2-second chop; movement cancels it. The tree falls away from the player through a deterministic tween and leaves a blocked stump. A second action removes the stump and opens the cell. A dry, traversable landing beyond the protected spawn becomes a blocked log cell in the fall direction. Interact clears that log and reopens the route; exhausted burned logs also release their cells. Invalid landings leave no persistent log. Log orientations are stored in logical cells and rebuilt on regional re-entry. Reserved trail/arrival cells cannot receive dropped logs. No physics, inventory or bridges are added. Cut tree data immediately loses shade and cannot regrow.

SurvivalState owns health, heat exposure and latched death. Unfavorable heat increases exposure, shade/resistance reduce accumulation, safer conditions cool the player, and severe exposure damages health. Bonfire shelter within 2.2 cells cools and heals. Death and completing the environmental sequence at the golden clearing open modal end states with a new-attempt button. A fresh world/model resets all temporary state. `run_objectives.gd` orders regional evidence: survey dry ground in Drylands, cut and remove a stump there to clear fuel, then observe nearby natural recovery in Wetlands before reaching its northern golden refuge. Camp field notes and brief notices explain the next step. This prevents an immediate clearing victory without an artificial timer; the 5–10 minute pacing target still needs human playtesting.

RunHUD is an always-processing scene with compact upper-left health/heat bars and original drawn icons, and upper-right temperature/weather, long-term trend and Knowledge. The regular HUD has no quest/distance counter or instructional block. A contextual bonfire prompt appears only in shelter, and discoveries use temporary notices. Bonfire/end-state modals remain separate. These modals pause gameplay and camera input. Interact within 1.5 cells of spawn opens bonfire progression. Escape returns from the bonfire; end states require an explicit restart/menu choice.

## Permanent progression

SaveManager retains version-1 `user://progression.json`, validates data and atomically replaces it through a temporary file. `discover(id)` awards one Knowledge only on the first successful persisted discovery. Failed writes do not mutate the in-memory progression. Stable discoveries include healthy/dead trees, heatwaves, shade, recovery, first cutting, rainfall, drought, wildfire, burned trees, ponds, cleared logs, firebreaks and the refuge.

`purchase_heat_resistance()` costs 3 Knowledge, is available once, persists immediately, and halves heat accumulation. Bonfire UI shows Knowledge, discovered entries and ownership. Quick Chop costs 2 Knowledge and multiplies chopping time by 0.65; Fire Resilience costs 2 and multiplies fire health damage by 0.6. The seven total Knowledge needed is below the available first-discovery catalog. Knowledge and upgrades survive death, success and app restart. Settings are separate, and active-run serialization is not implemented: Continue remains disabled.

## Validation and playtesting

Run Godot 4.7.2 from the root with `--headless --editor --import --quit`, then `--headless --script res://tests/<name>.gd` for:

- `foundation_test`, `mouse_bindings_test`, `camera_grid_test`, `grid_world_test`, `playtest_feedback_test`.
- `climate_test`, `progression_test`, `interactions_test`, `gameplay_test`, `camera_projection_test`.
- `movement_camera_test`, `settings_layout_test`, `world_presentation_test`, `hud_polish_test`.
- `settings_restart_test` twice: first with `-- --write`, then without it.

`desktop_test`, `video_desktop_test`, `feedback_desktop_test`, `gameplay_desktop_test` and `polish_desktop_test` require a real display. The polish capture test covers day/night shadows Off/High, flame movement and imported decorative props. Set `NIHILISTS_CAPTURE_DIR` to an existing directory outside the repository for optional captures. Gameplay tests use separate save filenames. Camera invariance tests freeze the level clock so intentional climate/trampling changes are not mistaken for camera mutations.

For native resolution/fullscreen testing, disable **Embed Game on Next Play** in the editor Game menu or launch with `--path` without `--editor`. Embedded Game view owns its own sizing and cannot change window mode. To compare FPS caps, run standalone with VSync off and use `video_desktop_test`; repeat with VSync on to observe display/driver limits. No permanent FPS counter is added.

## Ecosystem hazards and feedback

Wildfire uses a separate seeded RNG and snapshot cardinal spread on simulation ticks. Ignition begins no earlier than 120 seconds, attempts every 30 seconds with probability 0.65, and requires temperature >=32 C, dry ground and remaining fuel. Spread probability is 0.025 per neighbor/second. Rain suppresses spread and extinguishes flames; exhausted cells cannot reignite. Spawn is protected. Own-cell fire applies 7 health damage/second, adjacent fire half, reduced by Fire Resilience. Firebreaks remove fuel but also tree shade. This is an intentionally small game model, not a scientific prediction.

Pond cells hold bounded water levels, retain nearby moisture and exclude fire. Wet cells block movement; a sufficiently dried pond cell opens. Bridges, hydrodynamics, tree regrowth, additional biomes and larger maps are deferred.

The level exposes `audio_cue(cue, at)` for footsteps, chopping, falling, discoveries and weather changes. `SoundPalette.gd`, a SceneFlow child, connects these hooks and existing/new button signals to eight licensed Kenney CC0 recordings on SFX. Four UI voices and eight world voices are bounded; a player-owned AudioListener3D keeps spatial gain independent of camera orbit. Real-driver waveform tests verify output. Dummy-driver headless tests validate dispatch/routing without outputless decoder playback. Fire/rain/wind/music recordings remain pending. Logical simulation and effect clocks pause; foliage shader wind is cosmetic.

New tests: `ecosystem_test`, `objectives_progression_test`, `ecosystem_gameplay_test`, `nature_assets_test` and `balance_scenarios_test`. See [release validation](RELEASE_VALIDATION.md) for measured scenarios, exports and remaining manual checks.

## Settings layout refinements

Options uses shared label/control rows. Projection, 3D MSAA and all four shadow qualities are exclusive equal-width segments. Fullscreen/VSync are compact background-free checkboxes. FPS is a whole number from 0 to 1000 (0 is Unlimited), committed only on Enter or focus loss; invalid/empty text reverts. Binding rows share identical label/primary/secondary columns. Selected sidebar backgrounds and filled button surfaces are independent of subtle keyboard focus, with no selected left bar.

## Connected run regions

SceneFlow owns one `RunRegions.gd` RefCounted cache per active run. Forest connects west to Drylands and east to Wetlands; the side regions return to Forest. Stable seeds derive from the run seed with offsets 104729/209458. Each state retains its live GridData/ClimateSimulation (including fire RNG), cut history and visit/time metadata. Survival and objectives are shared across regions; permanent Knowledge stays in SaveManager. Main Menu or New Game discards the run cache. Continue and disk run saves remain unavailable.

Only the active graphical forest scene exists. Edge markers name each trail; arrivals sit one tile inside the corresponding edge. Transitions cancel chopping/orbit, reject Pause until loading completes, preserve camera yaw/pitch/zoom, and require held movement keys to be released. Returning rebuilds remaining trees, stumps and oriented logs from logical state. Inactive climate catches up at most 30 simulation seconds; excess backlog is discarded explicitly, with no wall-clock/background damage.

Drylands starts hotter/drier with stressed vegetation; Wetlands is cooler/moister and contains an actually damaged recovering patch north of camp at (8,5). Objectives require local observation, not a globally remote recovery event. Trampling that patch delays recovery; observing beside it preserves growth. Field notes appear at camp and in the region label tooltip. The compact HUD adds only the region name.

Water planes shrink with actual water level and disappear at the same .1 traversability threshold; soil beds remain. Dry foliage/ground cover follow moisture and health, burned ground recovers slowly under sustained favorable conditions, and dead trees stay dead. See [regional validation](REGIONS_VALIDATION.md) for this batch's evidence and remaining review.
