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
	check(cover.get_child_count() == 5 and cover.batches[0].indices.size() <= world.grid.cells.size()*33, "Abundant cover and cracks stay in five bounded draw batches")
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
	check(grass_batch.renderer.multimesh.mesh.get_faces().size() == 45, "Grass uses three rooted segmented blades, fifteen non-degenerate triangles per tuft")
	check(grass_batch.renderer.multimesh.mesh.get_aabb().position.y == 0.0, "Grass roots sit exactly on the ground")
	check(grass_batch.renderer.material_override.get_shader_parameter("wind_height") == 0.5, "Wind bend height matches blade geometry")
	var slot = grass_batch.indices.find(test_cell.y*17+test_cell.x)
	for blocker in ["log","berry_bush","tree"]:
		ground_data[blocker] = true
		cover.update_state(world.grid)
		check(grass_batch.targets[slot] == 0.0,"Grass clears occupied " + blocker + " cells")
		ground_data.clear()
		ground_data.merge(saved_ground)
	cover.update_state(world.grid)
	var state_before = world.grid.cells.duplicate(true)
	var wind = world.climate.wind_state(0.25,world.regions.elapsed)
	var next_wind = world.climate.wind_state(0.26,world.regions.elapsed)
	check(is_equal_approx(wind.direction.length(),1.0) and wind.strength >= 0.0 and wind.strength <= 1.0, "Wind exposes unit world direction and normalized intensity")
	check(wind.direction.distance_to(next_wind.direction) < 0.001 and absf(wind.strength-next_wind.strength) < 0.01, "Wind changes continuously, without abrupt direction or strength jumps")
	check(world.climate.wind_state(0.25,world.regions.elapsed) == wind and world.grid.cells == state_before, "Wind sampling is deterministic and leaves gameplay state untouched")
	world._update_wind(0.25)
	check(grass_batch.renderer.material_override.get_shader_parameter("wind_direction") == wind.direction and grass_batch.renderer.material_override.get_shader_parameter("wind_strength") == wind.strength, "Grass consumes the actual shared wind sample")
	var tree_script = load("res://features/levels/forest/nature/nature_tree.gd")
	check(tree_script._foliage_materials[0].get_shader_parameter("wind_direction") == wind.direction and tree_script._foliage_materials[0].get_shader_parameter("wind_time") == wind.time, "Tree foliage shares grass wind direction and clock")
	var forbidden_count = 0
	for j in range(grass_batch.indices.size()):
		var i = grass_batch.indices[j]
		var cell = Vector2i(i%17,i/17)
		var data = world.grid.cells[i]
		if data.tree or data.get("log",false) or data.get("berry_bush",false) or cell == world.grid.start or world.decorated_cells.has(cell):
			forbidden_count += 1
			if grass_batch.targets[j] != 0.0: check(false,"Occupied objects must not grow grass")
	check(forbidden_count > 0,"Occupied-cell grass exclusion was exercised")
	var wetlands = world.regions.get_region("wetlands")
	check(wetlands.climate.wind_state(0.25,world.regions.elapsed) == wind,"Regional travel keeps the shared run wind continuous")
	cover._process(1.0)
	check(grass_batch.pending.is_empty(),"Settled grass has no pending instance-buffer updates")
	cover.update_state(world.grid)
	check(grass_batch.pending.is_empty(),"Unchanged soil does not requeue thousands of grass transforms")
	var unaffected = 0
	while grass_batch.indices[unaffected] == test_cell.y*17+test_cell.x: unaffected += 1
	var unchanged_transform = grass_batch.renderer.multimesh.get_instance_transform(unaffected)
	ground_data.health = 0.4
	cover.update_state(world.grid)
	check(not grass_batch.pending.is_empty() and grass_batch.pending.size() < 40,"Local soil changes only queue the affected grass cell")
	cover._process(0.016)
	check(grass_batch.renderer.multimesh.get_instance_transform(unaffected) == unchanged_transform,"Growth animation leaves unrelated instance buffers untouched")
	ground_data.clear()
	ground_data.merge(saved_ground)
	cover.update_state(world.grid)
	cover._process(1.0)
	var diagonal_phase = Vector2.ZERO
	for offset in grass_batch.offsets:
		diagonal_phase += Vector2.from_angle(TAU*(offset.x-offset.z)/1.8)
	check(diagonal_phase.length()/grass_batch.offsets.size() < 0.25,"Grass offsets do not collapse onto correlated diagonal hash bands")
	check(absf(cover.grass_density_at(Vector2(1.0-0.0001,3.4))-cover.grass_density_at(Vector2(1.0+0.0001,3.4))) < 0.001,"World density remains continuous across gameplay tile boundaries")
	check(grass_batch.indices.size() == 5298,"World placement triples the seed-2026 grass budget without taller blades")
	var sites_before = cover._grass_sites.size()
	cover.update_state(world.grid)
	cover._process(0.1)
	check(cover._grass_sites.size() == sites_before,"Climate appearance updates never regenerate spatial noise")
	var source_cell = Vector2i(5,5)
	var sheltered = Vector2i(6,5)
	var source_data: Dictionary = world.grid.cells[5*17+5]
	for i in range(world.grid.cells.size()): world.grid.cells[i].tree = false
	source_data.merge({"tree":true,"tree_state":"healthy","tree_health":1.0,"growth_age":120.0,"burning":false},true)
	var behind = world.climate.wind_exposure_at(sheltered,Vector2.RIGHT)
	check(behind < 0.5 and world.climate.wind_exposure_at(Vector2i(4,5),Vector2.RIGHT) == 1.0,"Directional shelter reduces downwind exposure, not upwind wind")
	source_data.tree_state = "dead"
	check(world.climate.wind_exposure_at(sheltered,Vector2.RIGHT) > behind,"Dead leafless trees provide weaker shelter")
	source_data.tree_state = "stump"
	check(world.climate.wind_exposure_at(sheltered,Vector2.RIGHT) == 1.0,"Cutting a tree exposes its downwind grass immediately")
	source_data.tree_state = "sapling"
	source_data.growth_age = 30.0
	check(world.climate.wind_exposure_at(sheltered,Vector2.RIGHT) > behind,"New seedlings restore shelter gradually with maturity")
	for i in range(world.grid.cells.size()):
		world.grid.cells[i].clear()
		world.grid.cells[i].merge(original[i].duplicate(true))
	world._refresh_visuals()
	check(grass_batch.renderer.material_override.get_shader_parameter("shelter_enabled") and grass_batch.renderer.material_override.get_shader_parameter("wind_exposure").size() == 73,"Shared GPU wind consumes one cached exposure value per cell")
	var arrays = grass_batch.renderer.multimesh.mesh.surface_get_arrays(0)
	var blade_vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var blade_uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var blade_normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var root_count = 0
	for i in range(blade_vertices.size()):
		if blade_uv[i].y == 0.0:
			root_count += 1
			check(blade_vertices[i].y == 0.0,"Resting blade roots remain grounded")
		check(blade_normals[i].y > 0.0,"Rounded blade normals retain sky-facing softness")
	check(root_count > 0 and grass_batch.renderer.material_override.get_shader_parameter("blade_grass"),"Grass-only curvature/lighting metadata is present")
	check(world.effects.wind_streaks.multimesh.instance_count == 6,"Wind ribbons remain capped at six instances")
	world.effects.wind_streaks_enabled = false
	world._update_wind(0.0)
	check(not world.effects.wind_streaks.visible,"Optional wind ribbons disable independently of grass wind")
	world.effects.wind_streaks_enabled = true
	check(grass_batch.crowding.size() == grass_batch.indices.size() and grass_batch.crowding.min() < grass_batch.crowding.max(),"Spatial crowding cache distinguishes sparse and overlapping tufts")
	var cached_crowding = grass_batch.crowding.duplicate()
	cover.update_state(world.grid)
	check(grass_batch.crowding == cached_crowding,"Climate refresh reuses crowding without resampling neighbors")
	var close_pair: Array[Dictionary] = [{"position":Vector3.ZERO},{"position":Vector3(0.1,0,0)}]
	var distant_pair: Array[Dictionary] = [{"position":Vector3.ZERO},{"position":Vector3(3,0,0)}]
	check(cover._crowding(close_pair)[0] > cover._crowding(distant_pair)[0],"Overlapping blades receive more ambient occlusion than isolated blades")
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
	check(not world.has_node("Bonfire"),"Normal regions have no automatic camp")
	world.region_state.camp_enabled = true
	world._create_landmarks() # Retained reusable camp factory, explicitly opted in.
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
	flow.run_regions.current_id = "wetlands"
	world = load("res://features/levels/forest/forest_level.tscn").instantiate()
	root.add_child(world)
	world.set_process(false)
	world.get_node("GridPlayer").set_process(false)
	var transitions = 0
	for label in world.find_children("*","Label3D",true,false):
		check(label.text != "Recovering habitat","Temporary habitat label is absent")
		if label.text.begins_with("To "): transitions += 1
	check(transitions > 0 and not world.has_node("Bonfire") and world.interaction_marker != null,"Region transitions and interaction markers remain without automatic campfires")
	var old_globe = false
	for node in world.get_children():
		if node is MeshInstance3D and node.material_override is StandardMaterial3D and node.material_override.emission_enabled:
			old_globe = old_globe or node.mesh is SphereMesh or node.mesh is CylinderMesh
	check(not old_globe,"Obsolete golden objective meshes are not generated")
	world.objectives.problem_seen = true
	world.objectives.mitigation_done = true
	world.objectives.recovery_seen = true
	world._on_cell_entered(world.grid.objective)
	await process_frame
	check(not world.ended and world.hud.field_notes.is_empty(),"Old refuge tile no longer wins the game or shows objective directions")
	world.free()
	settings.shadow_quality = previous_quality
	print("WORLD PRESENTATION: ", checks, " checks, ", failures, " failures")
	quit(0 if failures == 0 else 1)
