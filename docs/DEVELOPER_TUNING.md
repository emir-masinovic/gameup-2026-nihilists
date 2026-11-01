# Live developer visual tuning

Run the project from Godot4.7.2 (F6 on forest_level.tscn or F5 then New Game/Continue). Keep the game running, switch the Scene dock from **Local** to **Remote**, then select **/root/ForestLevel/DeveloperTuning**. The node exists only in debug builds, once a playable region is loaded, not in Main Menu. If the level has been renamed, expand the active level root and find its DeveloperTuning child. Select the node, not its script or the local TRES.

1. Turn **Enabled** on under Preview Safety.
2. Set Preview Weather to rain; adjust Rain Intensity, Impact Size and Impact Opacity. Both falling streak and impact pools update together.
3. Enable Override Visual Wind; try intensity1 and change Direction Degrees. Grass, foliage and strokes follow, retaining canopy exposure. Adjust Grass Deformation/Gust Strength, Stroke Opacity/Count.
4. Set Preview Weather to heat, enable Override Visual Temperature, set44C; adjust Heat Overlay Multiplier. Biome Preview chooses the heat palette and shaft eligibility without changing regions.
5. Enable Preview Sun Rays and edit opacity to inspect shafts in any biome. Enable Preview Rainbow and edit opacity to inspect the arc without waiting for rain. For natural ray/rainbow behavior, leave those switches off.
6. Turn Enabled off to restore normal presentation. Stop/relaunch also discards every override. After a region transition, select the newly created node and re-enable if needed.

Changes apply on the next presentation frame without restarting. Resume the game if paused. Remote edits are not saved to the scene, defaults resource, run save or user settings. Visual weather/temperature/biome controls DO NOT change soil, growth, hazard/survival damage, HUD climate numbers or environmental audio. There is deliberately no second climate simulation. These are appearance previews, not a climate-balancing sandbox.

## What is live

| Group | Live properties | Cost |
|---|---|---|
| Weather/biome | Visual clear/rain/heat, presentation biome, preview temperature | Existing effects/materials only |
| Wind | Visual strength/direction; grass deformation/gust strength | Shared shader uniforms, existing shelter masks |
| Rain | Intensity0–1, ring size/opacity | Changes visible_instance_count in both existing pools; no allocation |
| Strokes | Opacity | Shader uniform |
| Strokes | Count0–32 | Reallocates/reseeds this tiny MultiMesh only when the count changes |
| Heat | Overlay multiplier | Existing batched terrain shader uniforms |
| Shafts | Force visibility and opacity | Existing bounded MultiMesh |
| Rainbow | Force visibility and opacity | Existing arc mesh; normal post-rain timer stays authoritative |

## Default configuration and restart-only settings

Select `res://features/developer/NihilistsTuning.tres` in FileSystem. Expand Climate VFX to browse the SAME `res://features/levels/forest/ResourceClimateVFX.tres` used by current consumers. Do not Make Unique or replace that reference: this resource is a convenient index into shared defaults, not a runtime injection system. Save default edits and restart the scene; existing pools/geometry and runtime exported preview values initialize from those defaults. Runtime node values never write back to that resource.

Deferred rather than showing nonfunctional live controls:

- Climate periods, temperature offsets, warming/drying/rain/recovery/ignition formulas: `features/levels/forest/climate_simulation.gd`.
- Actual biome initialization/moisture and weather order: `features/levels/forest/RunRegions.gd`.
- Authoritative120 favorable-second maturation/inventory: `features/levels/forest/StatePlanting.gd`; hydration/growth/health thresholds remain in climate_simulation.gd.
- Survival rates/exposure: `features/player/survival_state.gd`.
- Day/night duration/phase, terrain variation: existing ForestLevel exports.
- Camera: existing camera/settings architecture, unchanged.
- Grass distribution/density, geometry, rain maximum capacity/cycle, stroke dimensions/lifetime, ray geometry/count and rainbow geometry/lifetime remain in existing resources/scripts. Editing these defaults requires a restart. No grass renderer or climate refactor was introduced.

## Focused validation

The existing world_presentation_test exercises live property edits, actual renderer uniforms/pool counts, restoration, shared default identity and unchanged climate/cell state. Existing Save/Continue tests cover save compatibility. Native Compatibility captures demonstrate baseline, rain/wind, heat/shafts/rainbow and restored states in one running scene. Automated edits use the same exported properties/normal node processing as Remote Inspector; manual editor interaction should follow the steps above.

## Clouds (live)

In Remote/ForestLevel/DeveloperTuning, enable Preview Safety/Enabled, then expand **Clouds (Live)**. Clouds Enabled, Count, Speed, Opacity, Scale, Altitude, Extent, Rain/Heat/Clear Density and Rain Darkening all apply while running. Use Preview Weather to compare clear/rain/heat appearance and Override Visual Wind to inspect direction and speed. These remain visual-only. Disable the top-level Enabled switch to restore authoritative weather/wind and cloud defaults; disable Clouds Enabled to hide clouds while retaining other previews.

Count is a base population, multiplied by weather density and capped at32 shared slots. It controls smooth coverage, not a new allocation. Clear uses0.35, rain1.0, heat0.12, cool0.65. Coverage/darkness ease over a few seconds; opacity/height/scale/spread take effect on the next cloud update. Very large scales or low altitudes can obstruct terrain; a small screen-space fade protects the astronaut. Rainbow visibility softly clears nearby clouds. Wind drift wraps at the area boundary with a fade, not a visible teleport.

Defaults: `res://features/levels/forest/ResourceClouds.tres`, also expandable from NihilistsTuning.tres. Enabled=true, count12, speed1, opacity0.7, scale1.5, altitude7, extent23, rain density1, heat density0.12, clear density0.35, rain darkening0.55. Save default changes and restart for consistent initialization. Four baked mesh variants (small, puff, stretched, darker rain) and the32-slot capacity require code/restart to change; none of the exposed live controls rebuilds geometry. Clouds have no shadows, collisions, particles, textures, atmospheric scattering or simulation consequences.

Implementation files: `features/levels/forest/VisualClouds.gd`, `ShaderClouds.gdshader`, `ResourceClouds.gd/.tres` and script/shader UIDs; wiring in `ecosystem_effects.gd`; live exports in `features/developer/DeveloperTuning.gd`; default reference in `ResourceDeveloperTuning.gd`; focused checks in `tests/world_presentation_test.gd`.

Cloud Min Scale and Cloud Max Scale now control deterministic per-instance size variation live (defaults0.7–1.5). The shader sorts reversed bounds safely. Existing seeded values also supply modest local-axis proportions; orientation/drift and pool capacity are unchanged.
