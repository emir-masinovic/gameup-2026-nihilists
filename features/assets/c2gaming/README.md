# c2Gaming asset gallery

35 original FBX files copied unchanged from `C:\Users\Administrator\Documents\central-assets\c2Gaming\c2Gaming`. Original names and source bytes are preserved. Godot4.7.2 imports them as PackedScenes with tracked `.fbx.import` descriptors; `.godot/` caches remain untracked.

The supplied folder contained no separate textures, license, attribution or readme files. This provenance note is not a license. The team must confirm redistribution terms before publishing these assets. Cloud and rock imports have white untextured materials; no texture files were supplied. Other models retain their imported material colors. No substitute materials have been applied in the gallery.

## Inspect

Open `res://features/assets/c2gaming/AssetGallery.tscn` in Godot's3D editor. Expand Clouds, Trees, DeadTrees, Flowers, Grass, Logs and Rocks. Select an instance and press F to frame it, then orbit/zoom normally. F6 runs the gallery's overview camera. It is not connected to the main menu or gameplay entry point.

The gallery contains ordinary scene instances and exact source-filename labels, lighting, neutral floor and a camera. Per-instance scales normalize category footprints/heights; measured imported bounds place every model just above its stand. These presentation transforms do not change the FBX files. Original source proportions and poses are retained; logs include both upright and fallen forms.

| Category | Original models |
|---|---|
| Clouds | Cloud_01–03.fbx |
| Trees | Tree01–04.fbx |
| Dead trees | DeadTree01–04.fbx |
| Flowers | Flower01–05.fbx |
| Grass | Grass01.fbx |
| Logs | Log01–09.fbx |
| Rocks | Rock01–09.fbx |

All35 imports contain a mesh, nonempty triangles and finite normals. Source sizes differ substantially: flowers around0.3–0.55 units tall, trees around5.8–6.9, clouds around11.6–18.5 units wide. The gallery uses instance normalization instead of changing import units.

## Gameplay clouds only

MeshCloudLibrary.gd instantiates the three cloud imports once, bakes their existing node transforms into three shared ArrayMeshes and frees those temporary scenes. Each model has1084 triangles and one material surface. Geometry/normals are retained; the existing cloud shader overrides material color, opacity and weather presentation. No exported mesh duplicates or per-cloud FBX scene nodes are created.

Mapping: SmallWhite=Cloud_03, Puff=Cloud_02, WindStretched=Cloud_01, RainCloud=reuses Cloud_02. Their long X axes normalize to3.8/4.4/5.2 world units respectively and are centered before existing scale/yaw/drift. Four MultiMesh batches and32 total slots are unchanged. Smooth world-up wind rotation and seeded +/-12-degree variation, shelter-independent drift, weather coverage, player/rainbow clearance, transparency and DeveloperTuning all remain unchanged.

This increases cloud vertex cost relative to the procedural spheres: at most34688 submitted cloud triangles before visibility/fragment rejection, while draw batches remain four. Native Compatibility sanity captures were approximately6.3ms at normal view and3.2ms at Board Center on the local940MX; these are short QA samples, not controlled performance claims. Web runtime was not revalidated.

Only cloud models are referenced by gameplay. Trees, dead trees, flowers, grass, logs and rocks are gallery-only; existing biome generation, Kenney vegetation, climate, survival and saves are untouched.
