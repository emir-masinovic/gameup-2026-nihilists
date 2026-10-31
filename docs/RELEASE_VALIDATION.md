# Ecosystem demo validation

This batch extends the approved `6f6b8f8` checkpoint. All work is local; no publication or push is authorized. Godot 4.7.2, Compatibility renderer, Windows/NVIDIA GeForce 940MX.

## Implemented scope

- Generation v2: clustered conifer/deciduous forest, clearings, soil patches and a small connected pond; the protected central route remains reachable.
- Bounded warming, weather, shade, moisture, surviving vegetation recovery and deterministic grid wildfire. Fuel clearing trades shade for a firebreak. Wet ponds block movement, retain nearby moisture and resist fire; drying can open cells.
- Timed chopping/stump removal, predictable blocked log landings and log clearing. Exhausted burned logs release their cells. Falling remains away from the player.
- Ordered run evidence: survey environmental stress, clear fuel, observe recovery, reach the golden refuge. Camp field notes show the next step; there is no artificial minimum run timer.
- Unique persistent ecosystem discoveries plus Quick Chop (2 Knowledge, 35% shorter actions) and Fire Resilience (2 Knowledge, 40% less fire health damage). Heat Resistance remains 3 Knowledge and existing version-1 saves remain supported.
- Six selected Kenney models, shared foliage states/wind, batched grass/shrubs, rain and fire, small bonfire smoke and warm light. Menus and movement retain their existing architecture.
- Terrain batches replace 289 separate tile nodes. Audio event hooks exist for footsteps, chopping, tree falling, discovery and weather; no finished audio library is included.

Deferred: bridges, hydrodynamics, mature tree regrowth, larger maps/biomes, finished sounds, touch/controller support, and active-run save/Continue. The 5–10 minute human run target remains a playtest question, not a measured victory time.

## Automated validation

All listed final checks passed with no script/resource errors:

| Suite | Checks |
| --- | ---: |
| Foundation | 52 |
| Climate | 884 |
| Ecosystem | 3778 |
| Interactions | 12 |
| Progression | 42 |
| Objectives/progression | 51 |
| Nature assets | 32 |
| Ecosystem gameplay | 15 |
| Gameplay | 16 |
| Grid world | 121 |
| Movement/camera | 7040 |
| Camera grid | 39 |
| Camera projection | 67 |
| Mouse bindings | 9 |
| Settings layout | 87 |
| Playtest feedback | 48 |
| HUD polish | 14 |
| World presentation after batching | 67 |

Settings restart passed in two fresh processes (`-- --write`, then reload). The initial read-only invocation failed because its required write setup had not run; the correctly initialized check passes. A presentation assertion was also corrected to handle both water and shader materials without a typed-array lookup diagnostic.

Actual-display tests passed: gameplay captures (initial/warmed world, simulated rain/wildfire, bonfire, Options, death and main menu), polish (zero failures), Video (14 checks), Desktop (4), Feedback Desktop (66). Existing desktop layout coverage includes 800x600, 1152x720 and 1600x900. Native Godot editor import completed successfully. Test save paths remain separate from normal progression.

## Ten-minute deterministic scenarios

| Seed | First fire | Peak burning cells | Exposed heat danger | Exposed death | Mean ground health at 600s |
| --- | ---: | ---: | ---: | ---: | ---: |
| 2026 | 270s | 1 | 299s | 543s | 0.795 |
| 42 | 390s | 2 | 408s | 435s | 0.985 |
| 7 | 270s | 1 | 299s | 543s | 0.811 |

Temperature ranged approximately 18.1–39.6 C. Each world had two exhausted burned cells by 600 seconds. These fires are deliberately restrained. Stationary comparison players with constant 0.6 shade, or Heat Resistance in open ground, retained 100 health in all three scenarios; wildfire damage is covered separately by integration tests. Shelter heals/cools and is fire-protected. These comparisons isolate survival rules, not navigation, player skill, or time to victory.

## Performance

Same fixed-seed desktop test and active 120 FPS cap:

| Version | Draw calls | Nodes | 360 climate seconds |
| --- | ---: | ---: | ---: |
| Approved baseline | 917 | 542 | 1062 ms |
| Expanded ecosystem before terrain batching | 814 | 495 | 1523 ms |
| Expanded ecosystem with batching | 242 | 225 | 1517–2356 ms |

All runs held the cap; this does not measure uncapped gameplay throughput. Simulation averages about 4.2–6.5 ms per one-second tick versus 3.0 ms in the simpler baseline. Background workload affects timing. Final debug static-memory monitor reported 41.2 MiB; this is not total process/GPU memory. Terrain uses at most 18 material batches with bounded capacity. Grass/shrubs and rain/fire also use bounded shared batches. High-shadow fine detail still has Compatibility atlas limits; two cascades and a shorter range improve allocation without claiming perfect soft shadows.

## Exports and browser

`export_presets.cfg` provides Windows Desktop x86_64 and single-thread Web presets, excluding tests and docs. Supply an output path outside the repository:

```powershell
Godot_v4.7.2-stable_win64_console.exe --headless --path . --export-release "Windows Desktop" <external-path>/Nihilists.exe
Godot_v4.7.2-stable_win64_console.exe --headless --path . --export-release "Web" <external-path>/index.html
```

Both exports succeeded without export warnings/errors. Windows executable is 109,268,480 bytes plus a 301,120-byte PCK. Web WASM is 39,514,754 bytes plus JS/PCK/HTML. Distribution folders include LICENSES with Alegreya Sans OFL and Kenney license/provenance; retain those notices when sharing builds. Builds and capture/benchmark output are outside Git.

The exported Windows executable launched under OpenGL Compatibility and exited successfully after 180 frames. Its only diagnostic was an unavailable Windows root certificate store; no script/resource failure occurred. The game uses no online service.

A real in-app browser loaded the single-thread Web build from a temporary localhost HTTP server without Cross-Origin Isolation headers. Verified main menu, New Game/initial forest, held-key movement and discoveries, wheel zoom, Escape/Pause, Options over Pause, projection selection, Restore Defaults, scene transitions, settings persistence after reload and retained Knowledge across new runs/reloads. Browser warning/error log was empty. The initial gameplay transition briefly exceeded an automation snapshot timeout, then rendered correctly. No quantitative browser FPS benchmark or complete browser victory run was performed. Touch input and broad browser/device coverage remain unverified. The test tab and localhost server were closed afterward; nothing was deployed.

Web sharing requires serving the complete output folder via HTTP(S), not opening file:// HTML. No thread/COI hosting configuration is required by this preset. Browser storage may be unavailable or cleared in private/restricted sessions.

## Asset provenance and integration

Central Kenney originals were inspected read-only. GLB, FBX, DAE, OBJ and STL formats are available; the six selected GLBs total 51,268 bytes. Conifer (`tree_pineTallA`), deciduous (`tree_default`), `stump_round`, `log`, `grass` and `plant_bushSmall` are mapped in [nature attribution](../features/levels/forest/nature/ATTRIBUTION.md), with CC0 license beside them. The existing two rock models remain. Embedded source material metallic settings are corrected in shared runtime materials; source files are unchanged. Tree wrappers keep grounded pivots and shared visual states independent of logical tree IDs/passability.

Climate/asset agents used GPT-6.1 Sol Medium; progression/objectives used Sol High; release preparation used Sol Low. The coordinator retained the session model configuration; no claim is made that its model was switched. Shared integration, HUD, rendering optimization, documentation and commits were coordinated centrally with exclusive subsystem file ownership.

## Manual approval checklist

1. F5/New Game at 800x600, 1152x720 and 1600x900: confirm readable HUD, camp field notes and upgrade buttons; menus and bindings unchanged.
2. Orbit above/below the board, switch projection, zoom both ways; move relative to the camera and check Pause/Options disable world input.
3. Explore dry ground, cut a tree, watch it fall away, remove its stump, then clear its landing log. Check blocked/open cells match visible props and shade is lost.
4. Follow camp field notes through mitigation and actual recovery, then return to the golden clearing. Confirm early clearing visits cannot win. Judge whether a first-time run feels engaging over 5–10 minutes.
5. Observe rain, drought and a small wildfire. Compare shaded/open ground, retreat from flames, and confirm camp recovery. Check fire warnings, charred cells and wet pond boundaries are readable.
6. Earn unique discoveries, buy all three upgrades across attempts, restart and confirm ownership/Knowledge. Repeat discoveries must not farm currency.
7. Check day/night and shadows Off/High at near/far camera positions; verify wind, rain, smoke and falling trees remain restrained.
8. Launch the exported desktop build and Web folder through local HTTP. Complete a full run in the target browser, test orbit bindings/focus after tab switching, and assess first-load time/frame pacing.

Local commits are ready for manual review only. Do not push until the user approves.
