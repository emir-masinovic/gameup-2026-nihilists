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
	var previous_grass = settings.grass_density
	settings.grass_density = "Medium"
	var flow = root.get_node("SceneFlow")
	flow.next_seed = 2026
	var world = load("res://features/levels/forest/forest_level.tscn").instantiate()
	root.add_child(world)
	world.set_process(false)
	var original = world.grid.cells.duplicate(true)
	var live = world.get_node("DeveloperTuning")
	var vfx_defaults = load("res://features/levels/forest/ResourceClimateVFX.tres")
	check(not live.enabled and live.DEFAULTS.climate_vfx == vfx_defaults,"Debug node starts inactive and central defaults reference existing VFX")
	var climate_before = [world.climate.temperature,world.climate.weather,world.climate.elapsed]
	live.enabled = true
	live.preview_weather = "rain"
	live.rain_intensity = 0.5
	live.impact_size = 2.3
	live.override_visual_wind = true
	live.wind_intensity = 0.95
	live.wind_direction_degrees = 90.0
	live.grass_deformation = 2.8
	live.grass_gust_strength = 0.4
	live.wind_line_opacity = 0.8
	live.wind_line_count = 20
	live._process(0.1)
	check(world.effects.rain.visible and world.effects.rain.multimesh.visible_instance_count == 80 and world.effects.rain_impacts.multimesh.visible_instance_count == 80,"Live rain intensity changes both submitted pools")
	check(world.effects.impact_material.get_shader_parameter("splash_size") == 2.3,"Live impact size reaches material")
	var grass_material = world.ground_cover.batches[0].renderer.material_override
	check(grass_material.get_shader_parameter("wind_deformation") == 2.8 and grass_material.get_shader_parameter("gust_strength") == 0.4,"Live grass deformation and gusts reach GPU uniforms")
	check(grass_material.get_shader_parameter("wind_direction").distance_to(Vector2.DOWN) < 0.001 and world.effects.wind_material.get_shader_parameter("wind_strength") == 0.95,"Live wind override reaches existing grass and stroke consumers")
	check(world.effects.wind_streaks.multimesh.instance_count == 20 and world.effects.wind_material.get_shader_parameter("line_opacity") == 0.8,"Wind count rebuild and opacity update reach the actual renderer")
	live.preview_weather = "heat"
	live.override_visual_temperature = true
	live.visual_temperature = 44.0
	live.heat_overlay_multiplier = 1.5
	live.preview_sun_rays = true
	live.sun_ray_opacity = 0.4
	live.preview_rainbow = true
	live.rainbow_opacity = 0.5
	live._process(0.1)
	check(world.palette[0].get_shader_parameter("heat_tint") == 1.0 and is_equal_approx(world.palette[0].get_shader_parameter("heat_strength"),vfx_defaults.forest_heat_strength*1.5),"Live visual temperature and heat intensity reach terrain")
	check(world.effects.atmosphere.rays.visible and world.effects.atmosphere.ray_material.get_shader_parameter("ray_opacity") == 0.4,"Live ray opacity reaches active shafts")
	check(world.effects.atmosphere.rainbow.visible and world.effects.atmosphere.rainbow_material.albedo_color.a == 0.5,"Live rainbow demo reaches visible mesh")
	check([world.climate.temperature,world.climate.weather,world.climate.elapsed] == climate_before and world.grid.cells == original,"Live previews never mutate authoritative climate or saved ecological cells")
	live.enabled = false
	live._process(0.1)
	check(world.effects.wind_streaks.multimesh.instance_count == vfx_defaults.wind_line_count and grass_material.get_shader_parameter("wind_deformation") == vfx_defaults.wind_deformation,"Disabling preview restores pool size and grass defaults")
	check(world.effects.rain.multimesh.visible_instance_count == -1 and world.effects.impact_material.get_shader_parameter("splash_size") == vfx_defaults.splash_size,"Disabling preview restores normal rain capacity/material")
	check(vfx_defaults.wind_line_opacity == 0.5 and vfx_defaults.splash_size == 1.7,"Live overrides do not edit the shared default resource")

	var clouds = world.effects.clouds
	check(clouds.batches.size() == 4 and clouds.batches.all(func(batch): return batch.multimesh.instance_count == 8),"Four reusable cloud types keep the pool at32 slots")
	check(clouds.batches.all(func(batch): return batch.multimesh.mesh.get_faces().size() == 1084*3),"Imported c2Gaming cloud geometry retains source triangles")
	check(clouds.batches[1].multimesh.mesh == clouds.batches[3].multimesh.mesh,"Rain and puff batches reuse the same cached imported mesh")
	var cloud_pool = clouds.batches[0].multimesh.get_instance_id()
	clouds.weather = "clear"
	clouds._process(20.0)
	var clear_coverage = clouds.coverage
	clouds.weather = "rain"
	clouds._process(20.0)
	check(clouds.coverage > clear_coverage and clouds.darkening > 0.0,"Rain increases cloud coverage and darkening")
	clouds.weather = "heat"
	clouds._process(20.0)
	check(clouds.coverage < clear_coverage,"Heat leaves fewer clouds than clear weather")
	clouds.travel = Vector2.ZERO
	clouds.set_wind({"direction":Vector2.DOWN,"strength":0.0})
	clouds._process(1.0)
	var calm_travel = clouds.travel.y
	clouds.set_wind({"direction":Vector2.DOWN,"strength":1.0})
	var before_travel = clouds.travel
	clouds._process(1.0)
	check(clouds.travel.x == 0.0 and clouds.travel.y-before_travel.y > calm_travel,"Cloud drift follows wind and accelerates with strength")
	live.enabled = true
	live.cloud_count = 20
	live.cloud_opacity = 0.5
	live.cloud_altitude = 10.0
	live.cloud_scale = 2.0
	live.cloud_extent = 30.0
	live.preview_weather = "rain"
	live.cloud_rain_density = 1.5
	live._process(0.1)
	clouds._process(30.0)
	check(clouds.coverage == 30.0 and clouds.material.get_shader_parameter("cloud_opacity") == 0.5 and clouds.material.get_shader_parameter("altitude") == 10.0,"Live cloud count/density, opacity and height reach renderer")
	check(clouds.material.get_shader_parameter("cloud_scale") == 2.0 and clouds.material.get_shader_parameter("extent") == 30.0 and clouds.batches[0].multimesh.get_instance_id() == cloud_pool,"Live cloud scale/spread/count reuse existing geometry")
	live.clouds_enabled = false
	live._process(0.1)
	clouds._process(0.1)
	check(not clouds.visible,"Live cloud visibility disables rendering")
	live.enabled = false
	live._process(0.1)
	clouds._process(20.0)
	check(clouds.visible and clouds.preview.is_empty() and world.grid.cells == original,"Cloud defaults restore without changing saved ecological state")
	world.effects.atmosphere.rainbow.visible = true
	world.effects.atmosphere.rainbow_material.albedo_color.a = 0.45
	clouds.set_weather("clear",0.8,world.effects.atmosphere.rainbow)
	check(is_equal_approx(clouds.material.get_shader_parameter("rainbow_clearance"),1.0),"Active rainbow opens a soft gap in cloud coverage")
	world._update_lighting(0.0)
	check(clouds.material.get_shader_parameter("min_scale_variation") == 0.7 and clouds.material.get_shader_parameter("max_scale_variation") == 1.5,"Cloud size range uses centralized defaults")
	live.enabled = true
	live.cloud_min_scale = 0.8
	live.cloud_max_scale = 1.4
	live._process(0.1)
	clouds._process(0.1)
	check(clouds.material.get_shader_parameter("min_scale_variation") == 0.8 and clouds.material.get_shader_parameter("max_scale_variation") == 1.4,"Cloud scale bounds update live without mesh rebuild")
	live.enabled = false
	live._process(0.1)
	var props = world.ecology_props
	check(props.batches.size() == 10 and props.sites.size() <= 144,"Decorative flowers and branches use bounded shared batches")
	check(props.sites.any(func(site): return site.batch < 5) and props.sites.any(func(site): return site.batch >= 5),"Forest exercises both flowers and decorative branches")
	for site in props.sites:
		check(props._eligible(Vector2i(site.index%world.grid.SIZE,site.index/world.grid.SIZE)),"Decoration starts clear of reserved, water and interactive cells")
	# The headless dummy renderer returns black for color readback; native checks white.
	check(props.batches.all(func(batch): return batch.multimesh.use_colors and (DisplayServer.get_name() == "headless" or batch.multimesh.instance_count == 0 or batch.multimesh.get_instance_color(0) == Color.WHITE)),"Compatibility instance colors preserve imported petal palettes")
	var player = world.get_node("GridPlayer")
	var original_player_cell = player.cell
	for branch_prop in [false,true]:
		var decorated = props.sites.filter(func(site): return (site.batch >= 5) == branch_prop)[0]
		var decorated_cell = Vector2i(decorated.index%world.grid.SIZE,decorated.index/world.grid.SIZE)
		check(world.grid.traversable(decorated_cell),"Decorative flower/branch cells remain traversable")
		player.cell = decorated_cell
		props.update_state()
		check(decorated.active == 1.0,"Player entering a decorated cell does not hide it")
		player.cell = original_player_cell
		props.update_state()
		check(decorated.active == 1.0,"Player leaving a decorated cell does not hide it")
		world.decorated_cells[decorated_cell] = true
		props.update_state()
		check(decorated.active == 0.0,"Permanent decorative landmark occupancy still hides props")
		world.decorated_cells.erase(decorated_cell)
		var descriptor = {"id":"test.decoration.blocker","cell":decorated_cell}
		world.custom_interactables.append(descriptor)
		props.update_state()
		check(decorated.active == 0.0,"Registered interaction occupancy still hides props")
		world.custom_interactables.erase(descriptor)
	props.update_state()
	var duplicate_props = props.get_script().new()
	world.add_child(duplicate_props)
	duplicate_props.configure(world)
	check(duplicate_props.sites.map(func(site): return [site.index,site.transform,site.batch]) == props.sites.map(func(site): return [site.index,site.transform,site.batch]),"Decoration placement is deterministic and does not consume climate RNG")
	duplicate_props.free()
	var flower = props.sites.filter(func(site): return site.batch < 5)[0]
	var flower_data = world.grid.cells[flower.index]
	var flower_saved = flower_data.duplicate(true)
	flower_data.moisture = 0.8;flower_data.health = 1.0
	props.update_state()
	check(flower.target > 0.99,"Moist healthy cells support colorful full flowers")
	flower_data.moisture = 0.05;flower_data.health = 0.15
	props.update_state()
	check(flower.target < 0.05,"Severe drought targets a faded wilted/hidden flower")
	props._process(3.0)
	flower_data.moisture = 0.7;flower_data.health = 0.7
	props.update_state()
	check(flower.target > 0.65 and flower.from < flower.target,"Recovery interpolates instead of instantly restoring flowers")
	for blocker in ["pending_seeds","log","tree","prepared","berry_bush","water","burning","burned","tilled"]:
		flower_data[blocker] = 1 if blocker == "pending_seeds" else true
		props.update_state()
		check(flower.active == 0.0,"Decorations hide when interactive occupancy appears: "+blocker)
		flower_data.clear();flower_data.merge(flower_saved)
	props.update_state()
	var tuning = load("res://features/levels/forest/ResourceClimateVFX.tres")
	check(world.ground_cover.batches[0].renderer.material_override.get_shader_parameter("wind_deformation") == tuning.wind_deformation,"Grass reads centralized wind deformation")
	check(world.ground_cover.batches[0].renderer.material_override.get_shader_parameter("gust_strength") == tuning.gust_strength and world.ground_cover.batches[0].renderer.material_override.get_shader_parameter("gust_speed") == tuning.gust_speed,"Grass reads centralized gust parameters")
	check(world.effects.impact_material.get_shader_parameter("splash_size") == tuning.splash_size and world.effects.impact_material.get_shader_parameter("splash_opacity") == tuning.splash_opacity,"Rain reads centralized size and opacity")
	check(world.palette[0].get_shader_parameter("heat_strength") == tuning.forest_heat_strength and tuning.drylands_heat_strength == 0.16,"Forest heat is tunable; Drylands retains previous strength")
	check(not world.has_node("Bonfire") and world.flame_material != null and world.effects.flames.material_override == world.flame_material,"Wildfire has an animated material without automatic bonfire")
	world._advance_presentation(0.1)
	check(world.flame_material.get_shader_parameter("animation_time") > 0.0,"Wildfire animation clock remains connected")
	world.grid.cells[0].burning = true
	world.effects.update_state(world.grid,"rain")
	check(world.effects.flames.multimesh.visible_instance_count == 1,"Burning cells submit actual flame geometry")
	check(world.effects.rain.visible and world.effects.rain_impacts.visible and world.effects.rain_impacts.multimesh.instance_count == mini(world.effects.VFX.splash_count,256),"Rain enables bounded ground impacts")
	check(world.effects.rain.multimesh.instance_count == tuning.splash_count,"Each impact has a corresponding rain streak")
	check(world.effects.rain_material.get_shader_parameter("rain_sites") == world.effects.impact_material.get_shader_parameter("rain_sites"),"Drops and impacts share the exact landing site table")
	check(world.effects.rain_material.get_shader_parameter("rain_cycle_seconds") == tuning.rain_cycle_seconds,"Rain cycle reads central timing")
	for i in range(world.effects.rain_impacts.multimesh.instance_count):
		check(world.effects.rain.multimesh.get_instance_custom_data(i) == world.effects.rain_impacts.multimesh.get_instance_custom_data(i),"Drop and impact share seed, index and phase")
		check(world.effects.rain_impacts.multimesh.get_instance_transform(i).origin.y < 0.05,"Rain impacts stay at terrain surface")
	world.grid.cells[0].burning = false
	world.effects.update_state(world.grid,"clear")
	check(world.effects.flames.multimesh.visible_instance_count == 0 and not world.effects.rain.visible and not world.effects.rain_impacts.visible,"Extinguished fire and cleared rain hide immediately")
	var atmosphere = world.effects.atmosphere
	var daylight = Vector3(0.5,0.8,0.3).normalized()
	atmosphere.update_state(0.1,"forest",24.0,"clear",daylight)
	check(not atmosphere.rainbow.visible and not atmosphere.rays.visible,"No rainbow on fresh clear startup; Forest has no heat shafts")
	atmosphere.update_state(0.1,"drylands",42.0,"heat",daylight)
	check(atmosphere.rays.visible and atmosphere.rays.multimesh.instance_count == tuning.sun_ray_count,"Sunny Drylands heat enables bounded golden shafts")
	atmosphere.update_state(0.1,"drylands",42.0,"rain",daylight)
	check(not atmosphere.rays.visible,"Rain disables heat shafts")
	atmosphere.update_state(1.0,"wetlands",24.0,"clear",daylight)
	check(atmosphere.rainbow.visible and atmosphere.rainbow_alpha > 0.0,"Daylit clearing after rain fades in a rainbow")
	atmosphere.update_state(tuning.rainbow_duration+1,"wetlands",24.0,"clear",daylight)
	check(not atmosphere.rainbow.visible,"Rainbow expires without changing weather")
	atmosphere.update_state(0.1,"forest",24.0,"rain",Vector3.DOWN)
	atmosphere.update_state(1.0,"forest",24.0,"clear",Vector3.DOWN)
	check(not atmosphere.rainbow.visible,"Nighttime clearing cannot spawn a rainbow")
	check(world.effects.wind_streaks.multimesh.instance_count == tuning.wind_line_count,"Wind line count reads central cap")
	world.effects.update_wind({"strength":0.8,"direction":Vector2.RIGHT,"time":1.0},Vector3.ZERO)
	check(world.effects.wind_streaks.visible,"Strong authoritative wind enables readable ribbons")
	world.effects.update_wind({"strength":0.3,"direction":Vector2.RIGHT,"time":2.0},Vector3.ZERO)
	check(not world.effects.wind_streaks.visible,"Calm wind hides ribbons")
	world.terrain_renderer.update_weather_visuals(2.0,44.0,"heat")
	check(world.terrain_renderer.heat_visual == 1.0,"Hot weather activates bounded terrain tint")
	world.terrain_renderer.update_weather_visuals(2.0,44.0,"rain")
	check(world.terrain_renderer.heat_visual == 0.0,"Tint clears outside heat weather even at high ambient temperature")
	for quality in ["Off","Medium"]:
		settings.grass_density = quality
		settings.apply_settings()
		world.effects.update_state(world.grid,"rain")
		check(world.ground_cover.batches[0].renderer.visible == (quality != "Off") and world.effects.rain_impacts.visible,"Weather stays active independently of grass quality "+quality)
	world.effects.update_state(world.grid,"clear")
	check(world.grid.cells == original,"Weather presentation never changes ecological cells")
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
	check(cover.get_children().filter(func(child): return child is MultiMeshInstance3D).size() == 5 and cover.batches[0].indices.size() <= world.grid.cells.size()*33, "Abundant cover and cracks stay in five bounded draw batches")
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
	check(world.effects.wind_streaks.multimesh.instance_count <= 32,"Wind ribbons retain a bounded pool")
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
	var energy_at_horizon = sun.light_energy
	world._advance_presentation(0.002)
	check(absf(energy_at_horizon-sun.light_energy) < 0.001 and sun.light_energy < 0.001, "Sun/moon handoff occurs with zero directional energy at the horizon")
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
	check(world.palette[0].get_shader_parameter("heat_strength") == tuning.wetlands_heat_strength,"Wetlands uses its own heat strength")
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
	settings.grass_density = previous_grass
	settings.shadow_quality = previous_quality
	print("WORLD PRESENTATION: ", checks, " checks, ", failures, " failures")
	quit(0 if failures == 0 else 1)
