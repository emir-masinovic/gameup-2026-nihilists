extends SceneTree

var checks = 0
var failures = 0

func check(value: bool, message: String):
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func _initialize():
	call_deferred("run")

func run():
	var settings = root.get_node("SettingsManager")
	var previous_quality = settings.shadow_quality
	var flow = root.get_node("SceneFlow")
	flow.next_seed = 2026
	var world = load("res://features/levels/forest/forest_level.tscn").instantiate()
	root.add_child(world)
	world.set_process(false)
	var original = world.grid.cells.duplicate(true)
	check(world.palette.size() == 16, "Terrain uses only 16 shared climate materials")
	var seeds = []
	for material in world.palette:
		seeds.append(material.get_shader_parameter("world_seed"))
		check(material.get_shader_parameter("variation_strength") > 0.0, "Shared terrain shader enables subtle spatial patches")
	check(world.terrain_renderer.rendered_cell_count() == world.grid.cells.size(), "All logical cells rendered once")
	check(world.terrain_renderer.batches.size() <= 20, "Terrain batches remain bounded")
	for ground in world.terrain_renderer.batches:
		check(ground.material_override == world.water_material or ground.material_override == world.charred_material or ground in [world.terrain_renderer.batches[18],world.terrain_renderer.batches[19]] or (ground.material_override is ShaderMaterial and ground.material_override in world.palette), "Every tile reuses the shared terrain palette")
	var sun = world.get_node("Sun")
	var direction = sun.global_basis.z
	world._advance_presentation(20.0)
	check(direction.distance_to(sun.global_basis.z) > 0.1, "Sun direction changes as day progresses")
	check(world.grid.cells == original, "Presentation leaves logical world generation and climate unchanged")
	world.presentation_elapsed = (1.0 - world.starting_day_phase) * world.day_night_duration - 0.001
	world._update_lighting()
	direction = sun.global_basis.z
	world._advance_presentation(0.002)
	check(direction.distance_to(sun.global_basis.z) < 0.001, "Light direction is continuous across a complete cycle")
	world.presentation_elapsed = (0.75 - world.starting_day_phase) * world.day_night_duration
	world._update_lighting()
	check(sun.light_energy < 0.3, "Night has reduced directional energy")
	check(world.get_node("Environment").environment.ambient_light_energy >= 0.5, "Night retains readable ambient illumination")
	for quality in [0, 1, 2, 3]:
		settings.shadow_quality = quality
		world._apply_shadow_quality()
		world._advance_presentation(1.0)
		check(sun.shadow_enabled == (quality > 0), "Day cycle respects shadow Off through High")
	var fire = world.get_node("Bonfire")
	check(fire.has_node("Flame0") and fire.has_node("Flame1") and fire.has_node("Flame2"), "Bonfire retains three lightweight flames")
	check(fire.get_node("Smoke").amount <= 10 and not fire.get_node("Warmth").shadow_enabled, "Bonfire atmosphere remains bounded")
	var material = fire.get_node("Flame0").material_override
	var before = material.get_shader_parameter("animation_time")
	world._advance_presentation(0.25)
	check(material.get_shader_parameter("animation_time") != before, "Bonfire animation advances without climate ticks")
	check(fire.get_node("Flame2").material_override == material, "Flames share one opaque animated material")
	var animation_before = world.presentation_elapsed
	world._advance_presentation(NAN)
	check(world.presentation_elapsed == animation_before, "Invalid presentation delta is ignored")
	world.free()
	flow.next_seed = 2026
	world = load("res://features/levels/forest/forest_level.tscn").instantiate()
	root.add_child(world)
	world.set_process(false)
	for i in range(world.palette.size()):
		check(world.palette[i].get_shader_parameter("world_seed") == seeds[i], "Same world seed produces identical spatial variation parameters")
	world.free()
	settings.shadow_quality = previous_quality
	print("WORLD PRESENTATION: ", checks, " checks, ", failures, " failures")
	quit(0 if failures == 0 else 1)
