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
	var cover = world.ground_cover
	check(cover.get_child_count() == 5 and cover.batches[0].indices.size() <= world.grid.cells.size()*4, "Abundant cover and cracks stay in five bounded draw batches")
	var test_cell = Vector2i(7,5)
	var ground_data: Dictionary = world.grid.cells[test_cell.y*world.grid.SIZE+test_cell.x]
	var saved_ground: Dictionary = ground_data.duplicate(true)
	ground_data.terrain = "grass"
	ground_data.health = 1.0
	ground_data.moisture = 0.8
	cover.update_state(world.grid)
	var healthy_density = 0.0
	for j in range(cover.batches[0].indices.size()):
		if cover.batches[0].indices[j] == test_cell.y*17+test_cell.x: healthy_density += cover.batches[0].targets[j]
	ground_data.health = 0.2
	ground_data.moisture = 0.05
	cover.update_state(world.grid)
	var dry_density = 0.0
	for j in range(cover.batches[0].indices.size()):
		if cover.batches[0].indices[j] == test_cell.y*17+test_cell.x: dry_density += cover.batches[0].targets[j]
	check(dry_density < healthy_density*0.2 and cover._crack_targets[test_cell.y*17+test_cell.x] > 0.8, "Severe drought removes grass geometry and exposes cracks")
	ground_data.moisture = 0.7
	ground_data.health = 0.45
	cover.update_state(world.grid)
	var recovering_density = 0.0
	for j in range(cover.batches[0].indices.size()):
		if cover.batches[0].indices[j] == test_cell.y*17+test_cell.x: recovering_density += cover.batches[0].targets[j]
	check(recovering_density > dry_density and recovering_density < healthy_density, "Recovering ground returns patchy vegetation before full cover")
	ground_data.clear()
	ground_data.merge(saved_ground)
	cover.update_state(world.grid)
	var grass_batch = cover.batches[0]
	var distinct_offsets = {}
	var per_cell = {}
	for j in range(grass_batch.indices.size()):
		distinct_offsets[grass_batch.offsets[j]] = true
		var index: int = grass_batch.indices[j]
		per_cell[index] = per_cell.get(index,0)+1
	check(distinct_offsets.size() > 20, "Grass positions vary instead of repeating four corners")
	check(per_cell.values().min() < per_cell.values().max(), "Noise clusters create uneven healthy patch density")
	check(cover._crack_batches.size() == 3, "Three crack meshes share partitioned cells")
	var crack_total = 0
	for batch in cover._crack_batches: crack_total += batch.indices.size()
	check(crack_total == world.grid.cells.size(), "Crack variants never multiply per-cell geometry")
	var second_cover = load("res://features/levels/forest/nature/ground_cover.gd").new()
	root.add_child(second_cover)
	second_cover.configure(world.grid)
	check(second_cover.batches[0].offsets == cover.batches[0].offsets and second_cover.batches[0].indices == cover.batches[0].indices, "Rebuilding the same region preserves cosmetic clusters without simulation RNG changes")
	second_cover.free()
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
