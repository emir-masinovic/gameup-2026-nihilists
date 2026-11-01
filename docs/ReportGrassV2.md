# Grass V2 isolated experiment

Base: f7f7d9b, with origin/emir-codex and origin/development both at that commit when work began. Branch: experiment/simondev-grass-v2. Workspace: `C:/Users/Administrator/Documents/codex-projects/nihilists-grass-v2`. The primary checkout's three user edits were not copied, staged or changed. The tracked player scene still contains its original Marker in this clean experiment; the primary checkout's local Marker deletion remains preserved. No gameplay, climate, audio, save or camera-control source was modified.

## Audit and reference comparison

Inspected ground_cover.gd, shader_foliage.gdshader, nature_tree.gd, camera_orbit.gd and the level's wind/shelter interfaces. Reference source: [grass-component.js](https://github.com/simondevyoutube/Quick_Grass/blob/main/src/base/render/grass-component.js), [vertex shader](https://github.com/simondevyoutube/Quick_Grass/blob/main/public/shaders/grass-lighting-model-vsh.glsl), [lighting shader](https://github.com/simondevyoutube/Quick_Grass/blob/main/public/shaders/grass-lighting-model-fsh.glsl). SimonDev credits the Ghost of Tsushima GDC presentation. Techniques were adapted independently; no Three.js framework or compute path was imported.

| Technique | Actual reference source | Existing Nihilists | Experimental result |
|---|---|---|---|
| Geometry | Indexed six-segment high/one-segment low blades, explicit front/back vertex sets | Three flat, three-segment blades/tuft, 45 unindexed vertices, 15 triangles; zero physical thickness | Identical near geometry indexed to 21 vertices, still 15 triangles; low has 9 vertices/3 triangles |
| Placement | Seeded random offsets within reusable patches | Continuous world-space stratified candidates weighted by Worley/coherent noise | Retained; higher-count generation expands the candidate set only when required |
| Curvature | Vertex-generated progressive bending | Baked quadratic curve plus shader lean | Near preserved; far line-morph matches low topology |
| Normals/lighting | Blended rotated normals, gradients, density AO | Rounded normals, two-sided opaque lighting, cached local crowding | Preserved near; gradual sky-normal blending at far LOD |
| Thickening | Face/view angle and view-space horizontal offsets | Absent | Conservative optional root/tip-pinned widening; not enabled by default because ordinary-view A/B difference is small |
| Wind | Multiple spatial noise samples for lean/direction/strength | Travelling directional sine waves | Two vertex samples from a seeded 128² seamless Perlin texture; bounded direction perturbation, authoritative strength and shelter retained |
| LOD | Patch distance thresholds and high/low pools | No mesh LOD | Representative projected height AND width at five board anchors; physical render resolution and both projection types respected |
| Culling | CPU patch-frustum checks | One biome-wide grass MultiMesh, whole-batch engine culling | Existing culling retained. Static 25-chunk diagnostic provided no meaningful benefit for this board and added draws |

The reference video's “15 vertices” is not the same quantity as our 15 triangles per three-blade tuft. The current reference repository's high setting also differs from that timestamp: six segments, 14 logical front vertices plus back-side vertices.

Grass, shrubs and three crack partitions remain five render batches. A non-rendering LOD helper is additional, not a new draw batch. Per-instance transform/custom data, environmental exclusions, Worley placement, root shading and cached updates remain authoritative. Grass still casts no shadows; it receives the existing sun/moon lighting. No fragment transparency, compute, native extensions or per-frame blade placement was added.

## Screen-space decision

At 1152×720, normal orthographic zoom42 yields approximately 6.27 px blade height/1.47 px representative width; max Board Center zoom56 yields 4.70/1.10 px. Perspective max zoom yields about 3.31/0.95 px. The metric samples a representative 0.5-unit blade and 0.1-unit width, not every instance. It accounts for render texture versus logical viewport scaling. This is a conservative region-level heuristic, not perfect per-blade visibility.

Between 10 and 5 effective pixels, shader curvature/width, wind profile, normals and gradients morph toward the cheap blade representation. Low topology is selected only after the morph is complete; zooming inward restores high topology while still in the common shape before restoring curvature. Selection is sampled every0.15s at five anchors; one material blend updates smoothly. No per-blade CPU LOD checks or placement updates occur. The normal screen-scale tests also cover Free Camera and viewport resizing.

At max Board Center zoom the blade height is still several pixels, so a flat terrain-only approximation was not selected. Truly subpixel Free Camera views can still alias; a terrain coverage representation remains future work rather than an unvalidated green overlay. No chunk-level production renderer was added: the static diagnostic gained little close-view culling while adding about24 calls in full-board views. Its frozen transforms are explicitly NOT suitable for live climate updates.

## Measurements

Godot4.7.2, Compatibility/OpenGL3.3, GTX940MX/NVIDIA582.66, seed2026, 1152×720, shadow quality2, VSync off, no engine FPS cap. World simulation is frozen to keep conditions identical; existing presentation/shader wind is sampled consistently. 150 warmup frames, then40 per camera case and120 measured frames. An initial and a repeated baseline were retained. These are short workstation samples, not statistically isolated GPU-driver measurements. `render_cpu_ms` measures viewport render submission, not the whole simulation CPU frame; main-loop wall time includes other engine/driver costs. Full CPU simulation timing was not separately measured. Movie-encoding timings are excluded.

| Projection / zoom | Wall median ms, baseline → final | Render CPU ms | Viewport GPU ms | Wall p95 ms | Final world draw calls |
|---|---|---|---|---|---|
| Ortho 20 | 7.939 → 7.668 | 1.720 → 1.818 | 6.517 → 6.036 | 14.457 → 13.945 | 278 |
| Ortho 42 | 5.359 → 5.197 | 1.981 → 2.111 | 4.974 → 4.217 | 9.675 → 7.718 | 303 |
| Ortho 56 | 5.299 → 4.935 | 1.860 → 2.258 | 4.399 → 3.105 | 7.191 → 5.446 | 303 |
| Perspective 20 | 6.930 → 6.583 | 1.836 → 1.836 | 5.762 → 5.351 | 12.185 → 11.655 | 284 |
| Perspective 42 | 5.226 → 4.980 | 2.030 → 2.220 | 4.427 → 3.177 | 7.506 → 5.440 | 300 |
| Perspective 56 | 5.185 → 4.934 | 1.998 → 2.145 | 3.976 → 2.765 | 7.297 → 5.385 | 232 |

Near grass totals: 5,298 allocated tufts × 3 blades = 15,894 allocated blades; 4,316 tufts have nonzero ecological scale. This is not an occlusion-correct on-screen blade count. Baseline near:238,410 submitted vertices/79,470 triangles. Indexed near:111,258 vertices/79,470 triangles. Far:47,682 vertices/15,894 triangles. Whole-world draw calls remain identical for matched default cases; CPU/draw cost elsewhere still limits wall time. Hiding grass in the control reduces ortho42 GPU time to2.903ms while wall median stays4.935ms, confirming both a grass GPU contribution and a separate engine/driver/world floor.

Measured cover generation:382.7ms repeated baseline versus397.9ms final. Initial update sample:2.09 versus2.36ms; these single update samples do not establish a CPU-update improvement. Existing caching tests pass and LOD does not rewrite instance buffers. Forest instance payload is339,072 bytes, unchanged. Noise image including mips is21,845 bytes. These are measured payloads, not total CPU/GPU memory including driver and Variant-array overhead.

### Density trials (experimental shader/thickening on)

| Allocated / nonzero tufts | Near vertices / triangles | Far vertices / triangles | Ortho20 median / GPU ms | Ortho42 median / GPU ms | Ortho56 median / GPU ms | Cover generation ms |
|---|---|---|---|---|---|---|
| 8,000 / 6,560 | 168,000 / 120,000 | 72,000 / 24,000 | 8.870 / 7.254 | 5.788 / 5.376 | 5.007 / 3.586 | 497.8 |
| 12,000 / 9,889 | 252,000 / 180,000 | 108,000 / 36,000 | 9.029 / 8.017 | 6.518 / 5.849 | 5.084 / 4.176 | 806.2 |
| 20,000 / 16,500 | 420,000 / 300,000 | 180,000 / 60,000 | 11.576 / 9.867 | 7.631 / 6.416 | 5.650 / 5.085 | 1489.7 |

The final default retains current density. 8k is visibly fuller but exceeds the preferred close-view cost; 12k/20k are progressively more expensive. The experiment did NOT establish a higher default density at the desired budget. Higher presets remain opt-in. Wetlands retains5,472 allocated/4,383 nonzero tufts; Drylands5,463/1,825, preserving dry sparse ecology. Raw perspective, p95, chunk, hidden-grass and ablation results are in MeasurementsGrassV2.json. Older trial records are labelled separately from the final default.

## Validation and limits

Passed native Compatibility screen-space/mesh/wind checks (34), existing world-presentation/ecology/cache checks (141), Godot import and single-threaded Web export. Compared same-seed normal/edge-on close views, whole-board views, Wetlands, Drylands and moonlight. Near roots remain grounded; far topology retains ecological field patterns. Wind motion was captured with LOD locked to avoid confusing geometry transition with wind. Automated checks do not certify imperceptible transitions under every camera path or human preference. Browser runtime/performance was not tested. The field uses a standard NoiseTexture2D with internal asynchronous generation; its actual single-threaded Web startup remains part of browser acceptance.

## A/B and manual review

Open this experimental worktree only. Start the forest scene with `-- --fixed-seed` to reproduce seed2026. Add `--grass-baseline` for old rendering, `--grass-thickening` for optional width compensation, `--grass-no-perlin` for old wind, or `--grass-no-lod` for indexed high-only rendering. `--grass-count=8000` /12000 /20000 are debug density trials. No settings page or project.godot edits are needed. Shared branches are not merged automatically.

Run `tests/BenchmarkGrassV2.gd` natively for the six-case camera matrix; set GRASS_BENCH_OUT to an external filename prefix for JSON/PNGs. Debug harness-only arguments include --grass-chunks (frozen diagnostic), --grass-hide, --grass-pitch=0.09, --grass-close, --grass-biome=wetlands/drylands, --grass-night and --grass-wind-frames. Normal gameplay does not use the static chunk diagnostic.

Review grass fullness at zoom20/42, then maximum Board Center zoom in both projections; watch the morph while zooming slowly and rapidly, including underneath the board and Free Camera. Compare exposed/sheltered grass, cut away shelter, observe drought/rain recovery, move between regions and inspect dusk/night. Higher density must be accepted visually and profiled on target hardware before promotion. Browser startup, pause/resume, zoom and density must be checked separately. No subjective final acceptance is implied.
