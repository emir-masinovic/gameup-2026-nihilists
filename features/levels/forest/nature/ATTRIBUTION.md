# Kenney Nature Kit subset

Author: Kenney (https://kenney.nl/). Pack: Nature Kit.
License: CC0 1.0 Universal; see LICENSE.txt.
Source: user-provided local central-assets/kenney_nature-kit/Models/GLTF format.
No central originals were modified. Models contain embedded geometry/materials and no external textures.

| Local filename | Original filename |
| --- | --- |
| tree_conifer.glb | tree_pineTallA.glb |
| tree_deciduous.glb | tree_default.glb |
| stump.glb | stump_round.glb |
| log.glb | log.glb |
| grass.glb | grass.glb |
| shrub.glb | plant_bushSmall.glb |

Runtime adapters correct the source mesh child Y=-0.05 offset. Tree scales are
1.63 (conifer, 2.49 high) and 1.46 (deciduous, 2.49 high, 1.10 crown diameter).
The tree root remains at ground level for existing falling tweens. Leaf surfaces
are identified from imported material names leafsDark/leafsGreen. Four shared
Compatibility shader materials show healthy, stressed, dry, and bare states;
bare discards leaves while bark remains. The wind shader moves leaves only and
never changes gameplay. Stumps/logs have grounded wrapper pivots. The original
procedural forest_tree.tscn remains available as a fallback.
