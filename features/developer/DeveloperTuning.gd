extends Node
## DEBUG Remote Inspector visual overrides only. Never writes Resources, climate or saves.
const CLOUDS = preload("res://features/levels/forest/ResourceClouds.tres")
const DEFAULTS = preload("res://features/developer/NihilistsTuning.tres")
const VFX = preload("res://features/levels/forest/ResourceClimateVFX.tres")
@export_group("Preview Safety")
## Enable to apply the visual overrides below. Disable to restore normal presentation.
@export var enabled = false
@export_group("Weather & Biome Preview")
## Visual-only weather. Does NOT water soil, damage trees or affect survival/HUD/audio.
@export_enum("Authoritative","clear","rain","heat") var preview_weather = "Authoritative"
## Visual-only biome selection for shafts and heat tint. Does not change the region.
@export_enum("Authoritative","forest","wetlands","drylands") var preview_biome = "Authoritative"
## Preview temperature affects heat tint and rays only; simulation temperature is untouched.
@export var override_visual_temperature = false
@export_range(0.0,50.0,0.5) var visual_temperature = 40.0
@export_group("Visual Wind")
## Override grass, tree foliage and stroke direction/strength, never climate/HUD/audio.
@export var override_visual_wind = false
@export_range(0.0,1.0,0.01) var wind_intensity = 0.8
@export_range(0.0,360.0,1.0) var wind_direction_degrees = 35.0
@export_range(0.0,3.0,0.05) var grass_deformation: float = VFX.wind_deformation
@export_range(0.0,1.0,0.05) var grass_gust_strength: float = VFX.gust_strength
@export_group("Rain & Impacts")
## Fraction of the existing paired pool submitted, without reallocating geometry.
@export_range(0.0,1.0,0.05) var rain_intensity = 1.0
@export_range(0.1,3.0,0.1) var impact_size: float = VFX.splash_size
@export_range(0.0,1.0,0.05) var impact_opacity: float = VFX.splash_opacity
@export_group("Wind Strokes")
@export_range(0.0,1.0,0.05) var wind_line_opacity: float = VFX.wind_line_opacity
## Resizes and reseeds ONLY this tiny pool when edited; no per-frame pool rebuild.
@export_range(0,32,1) var wind_line_count: int = VFX.wind_line_count
@export_group("Heat & Sun Rays")
## Multiplier on the selected biome's real heat-overlay strength.
@export_range(0.0,2.0,0.05) var heat_overlay_multiplier = 1.0
## Force shafts for inspecting their appearance even outside Drylands heat.
@export var preview_sun_rays = false
@export_range(0.0,0.5,0.01) var sun_ray_opacity: float = VFX.drylands_ray_opacity
@export_group("Rainbow Demo")
## Force a visual arc; disable to return to the normal post-rain lifecycle.
@export var preview_rainbow = false
@export_range(0.0,0.6,0.01) var rainbow_opacity: float = VFX.rainbow_opacity
@export_group("Clouds (Live)")
@export var clouds_enabled: bool = CLOUDS.enabled
## Pool is fixed at32 slots. Count edits change faded coverage, not geometry.
@export_range(0,24,1) var cloud_count: int = CLOUDS.count
@export_range(0.0,3.0,0.05) var cloud_speed: float = CLOUDS.speed_multiplier
@export_range(0.0,0.85,0.05) var cloud_opacity: float = CLOUDS.opacity
@export_range(0.5,3.0,0.1) var cloud_scale: float = CLOUDS.cloud_scale
@export_range(0.5,2.0,0.05) var cloud_min_scale: float = CLOUDS.min_scale_variation
@export_range(0.5,2.0,0.05) var cloud_max_scale: float = CLOUDS.max_scale_variation
@export_range(2.0,16.0,0.5) var cloud_altitude: float = CLOUDS.altitude
@export_range(12.0,36.0,1.0) var cloud_extent: float = CLOUDS.extent
@export_range(0.0,2.0,0.05) var cloud_rain_density: float = CLOUDS.rain_density
@export_range(0.0,1.0,0.05) var cloud_heat_density: float = CLOUDS.heat_density
@export_range(0.0,1.0,0.05) var cloud_clear_density: float = CLOUDS.clear_density
@export_range(0.0,1.0,0.05) var cloud_rain_darkening: float = CLOUDS.rain_darkening
var _active = false
var _world: Node3D

func _ready():
	_world = get_parent()
	# Apply after the level's normal presentation update, including one-second refreshes.
	process_priority = 100

func _process(_delta: float):
	if not enabled:
		if _active: _restore()
		_active = false
		return
	_active = true
	var weather = _world.climate.weather if preview_weather == "Authoritative" else preview_weather
	var biome = _world.region_id if preview_biome == "Authoritative" else preview_biome
	var temperature = visual_temperature if override_visual_temperature else _world.climate.temperature
	var effects = _world.effects
	effects.rain.visible = weather == "rain"
	effects.rain_impacts.visible = effects.rain.visible
	var count = roundi(effects.rain.multimesh.instance_count*rain_intensity)
	effects.rain.multimesh.visible_instance_count = count
	effects.rain_impacts.multimesh.visible_instance_count = count
	effects.impact_material.set_shader_parameter("splash_size",impact_size)
	effects.impact_material.set_shader_parameter("splash_opacity",impact_opacity)
	for batch in _world.ground_cover.batches:
		if batch.renderer.name == "Grass":
			batch.renderer.material_override.set_shader_parameter("wind_deformation",grass_deformation)
			batch.renderer.material_override.set_shader_parameter("gust_strength",grass_gust_strength)
	if override_visual_wind:
		var state = _world.climate.wind_state(_world.tick_accumulator,_world.regions.elapsed).duplicate()
		state.strength = wind_intensity
		state.direction = Vector2.from_angle(deg_to_rad(wind_direction_degrees))
		_world.ground_cover.set_wind(state)
		preload("res://features/levels/forest/nature/nature_tree.gd").set_wind(state)
		effects.update_wind(state,_world.get_node("GridPlayer").global_position)
	effects.clouds.preview = {"enabled":clouds_enabled,"count":cloud_count,"speed_multiplier":cloud_speed,"opacity":cloud_opacity,"cloud_scale":cloud_scale,"min_scale_variation":cloud_min_scale,"max_scale_variation":cloud_max_scale,"altitude":cloud_altitude,"extent":cloud_extent,"rain_density":cloud_rain_density,"heat_density":cloud_heat_density,"clear_density":cloud_clear_density,"rain_darkening":cloud_rain_darkening}
	effects.clouds.weather = weather
	_resize_wind_pool(wind_line_count)
	effects.wind_material.set_shader_parameter("line_opacity",wind_line_opacity)
	var heat = clampf((temperature-28.0)/16.0,0.0,1.0) if weather == "heat" else 0.0
	for batch in _world.terrain_renderer.batches:
		if batch.material_override is ShaderMaterial:
			batch.material_override.set_shader_parameter("heat_strength",VFX.heat_strength(biome)*heat_overlay_multiplier)
			batch.material_override.set_shader_parameter("heat_tint",heat)
	var angle = (_world.starting_day_phase+_world.presentation_elapsed/_world.day_night_duration)*TAU
	var sun = Vector3(cos(angle),sin(angle),0.3).normalized()
	var atmosphere = effects.atmosphere
	# Do not feed preview weather into the normal rainbow lifecycle or climate clock.
	atmosphere.rays.visible = preview_sun_rays or (biome == "drylands" and weather == "heat" and temperature > 28.0 and sun.y > VFX.rainbow_min_sun_height)
	var ray_strength = 1.0 if preview_sun_rays else clampf((temperature-28.0)/12.0,0.0,1.0)
	atmosphere.ray_material.set_shader_parameter("ray_opacity",sun_ray_opacity*ray_strength)
	if preview_rainbow:
		atmosphere.rainbow.visible = true
		atmosphere.rainbow_material.albedo_color = Color(1,1,1,rainbow_opacity)
		effects.clouds.material.set_shader_parameter("rainbow_clearance",1.0 if rainbow_opacity > 0.0 else 0.0)

func _resize_wind_pool(count: int):
	var mesh = _world.effects.wind_streaks.multimesh
	if mesh.instance_count == count: return
	mesh.instance_count = clampi(count,0,32)
	var rng = RandomNumberGenerator.new()
	rng.seed = _world.world_seed ^ 0x51A17
	for i in range(mesh.instance_count):
		mesh.set_instance_transform(i,Transform3D(Basis.IDENTITY,Vector3(rng.randf_range(-VFX.wind_line_extent,VFX.wind_line_extent),rng.randf_range(1.8,3.0),rng.randf_range(-VFX.wind_line_extent,VFX.wind_line_extent))))
		mesh.set_instance_custom_data(i,Color(rng.randf(),0,0,1))

func _restore():
	var effects = _world.effects
	effects.clouds.preview.clear()
	effects.clouds.weather = _world.climate.weather
	effects.rain.visible = _world.climate.weather == "rain"
	effects.rain_impacts.visible = effects.rain.visible
	effects.rain.multimesh.visible_instance_count = -1
	effects.rain_impacts.multimesh.visible_instance_count = -1
	effects.impact_material.set_shader_parameter("splash_size",VFX.splash_size)
	effects.impact_material.set_shader_parameter("splash_opacity",VFX.splash_opacity)
	for batch in _world.ground_cover.batches:
		if batch.renderer.name == "Grass":
			batch.renderer.material_override.set_shader_parameter("wind_deformation",VFX.wind_deformation)
			batch.renderer.material_override.set_shader_parameter("gust_strength",VFX.gust_strength)
	_resize_wind_pool(VFX.wind_line_count)
	effects.wind_material.set_shader_parameter("line_opacity",VFX.wind_line_opacity)
	_world._update_wind(_world.tick_accumulator)
	for batch in _world.terrain_renderer.batches:
		if batch.material_override is ShaderMaterial:
			batch.material_override.set_shader_parameter("heat_strength",VFX.heat_strength(_world.region_id))
			batch.material_override.set_shader_parameter("heat_tint",_world.terrain_renderer.heat_visual)
	_world._update_lighting(0.0)
