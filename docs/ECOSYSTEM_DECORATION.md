# Decorative ecosystem presentation

Visual-only c2Gaming Flower01–05 and Log04–08 use10 fixed MultiMesh batches,10 cached meshes and two shared shader materials. Imported material colors are baked into mesh vertex colors; explicit white instance colors preserve them on Compatibility. No collisions, interactions, resources, inventory or ecological state are created.

## Placement and response

World-seeded coherent noise makes flower clusters; per-cell RNG fixes offsets, types, yaw and scale without consuming gameplay RNG. Forest has moderate flowers and tree-biased branches, Wetlands denser flowers weighted toward adjacent freshwater and fewer damp branches, Drylands sparse flowers and more exposed pale branches. Maximum flower/branch candidates: Forest120/24, Wetlands160/12, Drylands40/32. For seed2026, actual counts are100/12,130/3 and13/23 respectively; drought can hide allocated flowers.

All decorations exclude water (including dry pond schema), trees/saplings, stumps, interactive logs, berry bushes, seed leftovers, prepared/tilled/plantable soil, fire/char, spawn, boundary cells, central trails, the reserved objective, decorative rocks and registered interactions. Occupancy is rechecked at the existing visual refresh. New blocked/pickup locations hide their decoration immediately on that refresh; flowers never hide or consume seed rewards. Candidate sites are fixed during a region visit and reconstructed cosmetically on returning, without new save fields.

Visual vigor is the minimum of authoritative cell health and moisture mapped smoothly from0.04–0.65. It controls flower saturation, size, stem slump and severe-stress disappearance. Recovery follows real moisture/health recovery; a2.5-second shader interpolation avoids threshold flicker. The same state makes branch wood richer/darker when wet and pale/desaturated when dry. Wetlands wood has an additional dark tint. Branch models retain their horizontal footprint but compress to0.14m high before seeded scale, distinguishing them from large interactive fallen logs.

No MultiMesh geometry/transforms are rebuilt each frame. Changed ecological targets update custom data at the existing refresh; two clock uniforms drive GPU interpolation. Existing Grass V2 meshes, presets, placement, growth and climate rules are untouched. Decoration visibility is independent of grass quality. Existing shadows/lighting illuminate these small opaque props; they cast no additional shadows.

## Cloud size

ResourceClouds.gd defaults now expose min/max variation0.7/1.5. Remote/ForestLevel/DeveloperTuning -> Enabled -> Clouds (Live) -> Cloud Min/Max Scale edits apply immediately. Each existing cloud slot uses its seeded value to select a stable size, plus modest roughly+/-8% local proportions. The cloud's existing world-up yaw, drift, weather fades and player/rainbow clearance remain intact. No mesh rebuilding or new random draws occur.

## Validation and manual review

- Original-project import and638 focused native Compatibility presentation checks passed, including deterministic placement, resource identity, exclusions, moisture/health targets, recovery interpolation, palette instance colors and live scale bounds.
- Native seed2026 captures cover healthy Forest, rainy Wetlands, stressed Drylands, Forest drought after120 one-second heat ticks and recovery after35 one-second rain ticks. QA uses the actual simulation rules in isolated user data, not hand-painted final states. Clouds are hidden only in ground-inspection captures; a separate frame shows clouds and size variation.
- Short1280x720 ground-inspection samples on940MX stayed at the configured60FPS cap; measured GPU render times were approximately5.44msForest,5.05msWetlands,4.22msDrylands. These are sanity samples, not before/after performance claims. Up to10 extra mesh draws and tens of thousands of triangles are added; Web runtime was not retested.

Playtest: compare flowers near wet/tree-sheltered ground with exposed dry ground; wait through rain and drought to see wilting/color recovery; inspect pale low twigs in Drylands and darker sparse twigs in Wetlands. Confirm they offer no action prompts and nearby real stumps/logs/seed pickups still do. In Remote Inspector vary cloud min/max size, then disable tuning to restore defaults. Full biological flower reproduction and branch gameplay are intentionally absent.
