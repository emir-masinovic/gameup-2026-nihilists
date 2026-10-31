# Feature ownership

Keep scenes, scripts, resources, and local media with their feature. Use snake_case files and folders, PascalCase node/class names, and matching scene/script names where useful. See [AGENTS.md](../AGENTS.md) for collaboration and Git rules and [DESIGN.md](DESIGN.md) for the game direction.

## Implemented systems

- `features/menus/`: editable Main Menu, Pause and shared sidebar Options scenes; `scene_flow.gd`; `theme_forest.tres`; licensed Alegreya Sans under `fonts/`.
- `features/settings/`: `settings_manager.gd`, `audio_bus_layout.tres`.
- `features/save_system/`: `save_manager.gd`.
- `features/player/`: `grid_player.gd/.tscn`, `survival_state.gd`.
- `features/levels/forest/`: `forest_level.gd/.tscn`, `grid_data.gd`, `climate_simulation.gd`, `forest_interactions.gd`, `forest_tree.tscn`, `forest_sapling.tscn`, `forest_seed.tscn`, `crop_indicator.gd`, `camera_orbit.gd`, `shader_grid.gdshader`, `run_hud.gd/.tscn`.
- `features/levels/prototype/prototype.tscn`: original bootstrap, retained unchanged.
- `tests/`: foundation, mouse bindings, camera/grid, projection, desktop video, persistence, climate, progression, eco_restoration, water_climate, tree_chop_facing, seed_system, farming_growth, water_bottle_system, and gameplay integration tests.

Required script/shader UID companions and font import descriptors are tracked. `.godot/` import, editor, shader and UID caches are ignored. Ten sparse decorative rocks use two small Kenney Nature Kit GLBs under `features/levels/forest/props/`; source originals stay in central-assets. The included CC0 license and ATTRIBUTION.md record provenance. Models use embedded materials, have no external textures or gameplay collision, and do not change grid passability or simulation seeds. Procedural trees remain to preserve foliage-state and falling-pivot behavior. Alegreya Sans Regular comes from the official Google Fonts repository (`ofl/alegreyasans`); its SIL Open Font License is included at `features/menus/fonts/OFL.txt`.

## Menus, settings and scene flow

The project starts at `main_menu.tscn`; `application/run/playable_scene` selects the forest. SceneFlow owns transitions and an always-processing Pause overlay on canvas layer 20, covering the world HUD when opaque Options is open. Back closes nested Options without resuming. New Game generates a fresh run seed; direct fixed-seed tests remain reproducible.

SettingsManager persists `user://settings.cfg`, independent of gameplay saves. It owns audio volumes, window mode/resolution, VSync, FPS cap, 3D MSAA Disabled/2x/4x, shadow quality, camera projection and bindings. Music and SFX feed Master. Video defaults reset only Video, Controls defaults reset all bindings and sensitivity, and Gameplay defaults reset projection only.

InputMap bindings use positive integers for physical keys, negative mouse indices, and zero for an empty slot. Older keyboard-only saves merge camera defaults. Two binding buttons per action capture input; the activation release cannot capture itself, Escape cancels, and conflicts are rejected across actions. Built-in menu navigation remains independent. Orbit accepts held mouse buttons; zoom accepts buttons/wheels. Mouse sensitivity is 0.002-0.020 radians/pixel (default 0.008).

Orthographic and Perspective projections share a fixed grid-center pivot and free yaw/pitch orbit through poles. Zoom is 10-56, default 42; perspective FOV is 55 degrees with near/far planes 0.1/200. The analytic orientation frame avoids look-at pole singularities. GridPlayer now projects the four hypothetical cardinal steps through the active Camera3D and chooses the closest screen-axis alignment. A 0.08 dot-score hysteresis prevents jitter near selection boundaries; deterministic ties and tiny-axis rejection handle poles/horizontal views. try_move remains a world-cardinal API and grid coordinates are unchanged. At exactly edge-on views a requested screen direction may have no visible grid-axis component; the deterministic nearest available direction is used.

Desktop window resolutions apply only in windowed mode and clamp to the usable display. Fullscreen uses desktop resolution. Web/headless window mode, resolution and VSync controls are disabled. Compatibility does not expose FXAA or TAA.

## Climate, water and vegetation

GridData generation version 1 produces the bounded 17x17 world from a seeded RNG. Logical cell centers are two units apart. The objective lies on the guaranteed traversable central route. ClimateSimulation enriches the existing cells without changing initial tree placement and owns moisture, grass health, tree health/state, water depth and evaporative cooling. Rendering reads these values; no shader simulates gameplay.

The level schedules one simulation second per tick. Its exported `simulation_time_scale` defaults to 1; climate ticks cap catch-up work to 30 seconds. Temperature is a 24 C baseline plus 0.025 C per elapsed second and transient weather offsets. Seeded 60-second clear/rain/cool/heat periods vary temperature and rainfall independently of the warming trend. This is a simplified greenhouse-warming game model, not an ozone or scientific climate model.

Moisture/health remain within 0-1. Heat dries soil, drought and heat stress vegetation, rain/cool conditions can restore moisture and surviving vegetation. Healthy adjacent trees contribute shade proportional to health. Dead, cut and removed trees do not recover or provide shade. Repeated steps trample grass by 0.12 health each; favorable conditions allow recovery. Recovery discovery requires an actual rise after visible damage.

Water and lake cells:
- Seeded generation places organic lake bodies in a quadrant away from spawn and the central cross routes, preserving unobstructed paths.
- Lake cells with deep water (`water_depth > 0.25`) act as impassable barriers.
- During extreme heatwaves and droughts, water evaporates and levels drop. Once `water_depth <= 0.25`, the dried lakebed becomes passable, opening previously blocked routes and shortcuts across the terrain.
- When rain arrives, water inflows refill the lake basin back to full depth (`water_depth` returns towards 1.0), restoring the impassable barrier.
- Water provides an evaporative microclimate: nearby land cells receive cooling (`water_proximity(cell)`), mitigating extreme temperatures and contributing to shade and drought resistance for adjacent flora.
- Visually, water is rendered with a dedicated translucent water layer that dynamically lowers, shrinks, and hides when dry, exposing the cracked lakebed.

Saplings and crops:
- Planted seeds sprout into young saplings once their hydration requirements are met (`water_needed <= 0.0`), either via direct player watering or falling rain.
- Saplings grow steadily under favorable moisture (> 0.35) and temperatures (< 34 C) at a deliberate pace (~55s under good moisture, similar to Minecraft farming).
- Growing saplings contribute partial shade. Upon reaching maturity (0.95 health), they convert into full healthy trees that cast complete protective shade and shelter. Harsh heatwaves or droughts can wither unattended saplings.
- In-world billboard indicators display crop progress:
  - Seed stage: floating indicator above the seed displays a water droplet icon (💧) and blue hydration progress bar.
  - Sapling stage: floating indicator switches to a seedling sprout icon (🌱) and green growth progress bar.
  - Mature stage: indicator is cleanly freed once the tree matures.

Rendering uses 16 shared moisture/health terrain materials and four shared foliage materials, updated on simulation ticks. The terrain shader adds seed-dependent broad green/dirt clusters and restrained fine variation, modulated by the authoritative vegetation health. No per-tile material instances are created. Grid boundaries are derivative-antialiased shader patterns on closed tile meshes, not depth-conflicting overlays. A separate presentation clock drives a tunable 240-second day/night cycle: one directional light changes yaw/elevation continuously and dims to cool moonlight, with a 0.56 ambient-energy floor. Weather changes light color independently of the warming trend. User shadow settings still apply. Three opaque low-poly bonfire flame meshes share a vertex-flicker shader and pause with the world. World geometry remains procedural and bounded.

## Interaction, survival and run lifecycle

GridPlayer emits cell-entry events and keeps movement separate from generation. To interact with a tree or stump, the player must be in an adjacent cell AND directly facing it (`player + facing`). Facing away prevents accidental chopping.

Chopping animation, kinetics and seed economy:
- When chopping begins, a prominent lumberjack battleaxe with a dark ash handle and gleaming metallic blade is drawn in the astronaut's right hand.
- The astronaut raises the axe high over their shoulder while coiling their torso back in an athletic wind-up, then delivers an explosive downward swing leaning aggressively forward toward the tree trunk.
- On blade impact with the trunk, wood chip particles (`WoodChips`) burst outward, the tree trunk visibly shakes from the hit, and an impact shudder passes through the astronaut before resetting into the next strike.
- The 1.2-second chop executes two complete strikes before the tree cleanly falls away from the player through a deterministic tween and leaves a blocked stump. A second facing action removes the stump and opens the cell.
- Each tree cut awards +3 Seeds to the player's inventory (`seeds += 3`).
- Movement cancels active chopping immediately and stows the axe away.

Farming tools, tilling, and planting:
- In order to plant seeds, the ground must first be tilled using a farming hoe (çapa).
- When tilling untilled soil or clearing crops, the character equips the farming hoe in their right hand, raises the hoe upward, and plunges the blade down into the ground, pulling a furrow while crouching forward.
- Each hoe strike triggers a dirt puff particle effect (`DirtPuff`) and an impact shock.
- Completing the 0.8-second tilling action transforms the grass into rich dark brown tilled farmland (instantiated in the dedicated `$Farmland` container to preserve the 289-child `$Terrain` mesh invariants).
- Once soil is tilled, the player can plant a seed with a 1.0-second planting interaction, consuming 1 seed (`seeds -= 1`) and creating a furrowed seed visual (`forest_seed.tscn`). Strictly following the spatial design rule: seeds can only be planted on tilled soil (`tilled == true`), and only directly on whichever grid cell the character is standing on (`target = player`).
- If 0 seeds remain, planting cannot initiate, and the HUD notifies the player that they do not have enough seeds ("Yeterli tohumunuz yok! Ağaç keserek tohum toplayabilirsiniz.").
- Immature seeds or saplings can be harvested/cleared with the hoe via an adjacent facing interaction, refunding 1 seed back to the player.
- Seeds and saplings (`seed`, `sapling`) are traversable grid cells (`grid_data.gd: traversable() == true`), allowing the player to step directly onto them to nurture them, while mature trees and stumps remain impassable obstacles.
- Water can strictly only be poured when the character is standing directly on the grid cell of a growing seed or sapling (`current_cell.tree_state in ["seed", "sapling"]`, `target = player`). Untilled ground and tilled-but-empty ground cannot be watered under any circumstances. Each watering interaction lasts 0.8 seconds and pours 250 ml of water.

Water bottle, volume in milliliters (ml), and lake filling:
- The player possesses a canteen/water bottle measured in milliliters with a maximum capacity of 1000 ml (`water_ml = 500` initially).
- Facing an adjacent lake or water puddle (`front_cell.water == true` and `water_depth > 0.08`) and interacting initiates a 2.4-second bottle filling interaction (`fill_water`).
- During filling, the player draws their stylized glass-and-brass canteen in their right hand, kneels down low toward the water edge, and submerges the bottle with periodic water ripples and bubbles (`water_fill_splash`).
- Completing the action fills +500 ml of water into the bottle up to the 1000 ml maximum. If already full, the interaction is blocked with a friendly notice ("Su şişeniz zaten tamamen dolu! (1000 ml)").
- Watering a growing seed or sapling under the player's feet consumes 250 ml (`WATER_PER_POUR = 250`). During watering, the astronaut draws the bottle, tilts it downward, and pours water onto the earth with water spray particles (`water_pour_splash`).
- If the player's water drops below 250 ml, watering cannot initiate and the player is notified ("Yeterli suyunuz yok! (250 ml gerekli) Gölden su doldurabilirsiniz.").
- The HUD includes a dedicated Water indicator row in `PlayerStatus` featuring a water droplet icon (`drop`), a progress bar (0-1000 ml) with a blue `WaterFill` stylebox, and exact milliliter text ("500 ml").

SurvivalState owns health, heat exposure and latched death. Unfavorable heat increases exposure, shade/resistance reduce accumulation, safer conditions cool the player, and severe exposure damages health. Bonfire shelter within 2.2 cells cools and heals. Death and reaching the golden clearing open modal end states with a new-attempt button. A fresh world/model resets all temporary state. The clearing is a deliberately simple, quickly reachable prototype goal; ten-minute pacing still needs playtesting.

RunHUD is an always-processing scene with compact upper-left health/heat/water bars and dedicated Seeds and Water indicators with custom icons (`sprout`, `drop`), and upper-right temperature/weather, long-term trend and Knowledge. The regular HUD has no quest/distance counter or instructional block. A contextual bonfire prompt appears only in shelter, and discoveries use temporary notices. Bonfire/end-state modals remain separate. These modals pause gameplay and camera input. Interact within 1.5 cells of spawn opens bonfire progression. Escape returns from the bonfire; end states require an explicit restart/menu choice.

## Permanent progression

SaveManager retains version-1 `user://progression.json`, validates data and atomically replaces it through a temporary file. `discover(id)` awards one Knowledge only on the first successful persisted discovery. Failed writes do not mutate the in-memory progression. Stable discoveries include healthy/dead trees, saplings, heatwaves, shade, recovery, tree cutting, soil revitalization, sapling planting, water sources, and dried lakebeds.

`purchase_heat_resistance()` costs 3 Knowledge, is available once, persists immediately, and halves heat accumulation. Bonfire UI shows Knowledge, discovered entries and ownership. Knowledge and the upgrade survive death, success and app restart. Settings are separate, and active-run serialization is not implemented: Continue remains disabled.

## Validation and playtesting

Run Godot 4.7.2 from the root with `--headless --editor --import --quit`, then `--headless --script res://tests/<name>.gd` for:

- `foundation_test`, `mouse_bindings_test`, `camera_grid_test`, `grid_world_test`, `playtest_feedback_test`.
- `climate_test`, `progression_test`, `interactions_test`, `gameplay_test`, `camera_projection_test`.
- `movement_camera_test`, `settings_layout_test`, `world_presentation_test`, `hud_polish_test`, `eco_restoration_test`, `water_climate_test`, `tree_chop_facing_test`, `seed_system_test`.
- `settings_restart_test` twice: first with `-- --write`, then without it.

`desktop_test`, `video_desktop_test`, `feedback_desktop_test`, `gameplay_desktop_test` and `polish_desktop_test` require a real display. The polish capture test covers day/night shadows Off/High, flame movement and imported decorative props. Set `NIHILISTS_CAPTURE_DIR` to an existing directory outside the repository for optional captures. Gameplay tests use separate save filenames. Camera invariance tests freeze the level clock so intentional climate/trampling changes are not mistaken for camera mutations.
