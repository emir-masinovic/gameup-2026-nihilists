extends Resource
## Central entry point for existing visual defaults. Runtime overrides live on DeveloperTuning.
## Expand this shared resource rather than making a unique copy.
@export_group("Climate VFX Defaults")
@export var climate_vfx: Resource = preload("res://features/levels/forest/ResourceClimateVFX.tres")

@export_group("Cloud Defaults")
@export var clouds: Resource = preload("res://features/levels/forest/ResourceClouds.tres")
