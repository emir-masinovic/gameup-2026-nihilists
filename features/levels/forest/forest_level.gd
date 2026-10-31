extends Node3D
const GridData = preload("res://features/levels/forest/grid_data.gd")
const TREE = preload("res://features/levels/forest/forest_tree.tscn")
const SAPLING = preload("res://features/levels/forest/forest_sapling.tscn")
@export var world_seed: int = 2026
@export_range(0.1, 10.0) var simulation_time_scale = 1.0
@export_group("World presentation")
@export_range(30.0, 1200.0, 1.0) var day_night_duration = 240.0
@export_range(0.0, 1.0) var starting_day_phase = 0.18
@export_range(0.3, 1.0) var night_ambient_energy = 0.56
@export_range(0.0, 0.25) var terrain_variation_strength = 0.14
var presentation_elapsed = 0.0
var flame_material: ShaderMaterial
var grid = GridData.new()
var climate = preload("res://features/levels/forest/climate_simulation.gd").new()
var interactions = preload("res://features/levels/forest/forest_interactions.gd").new()
var survival = preload("res://features/player/survival_state.gd").new()
var grounds: Array[MeshInstance3D] = []
var trees = {}
var water_tiles: Dictionary = {}
var palette: Array[ShaderMaterial] = []
var leaf_materials: Array[StandardMaterial3D] = []
var tick_accumulator = 0.0
var ended = false
var hud: Control
var recovery_seen = false
var rain_particles: CPUParticles3D
var heat_particles: CPUParticles3D
var water_splash: CPUParticles3D
var wood_chips: CPUParticles3D

func _ready():
	if not OS.get_cmdline_user_args().has("--fixed-seed"):
		world_seed = SceneFlow.next_seed
	grid.generate(world_seed)
	climate.configure(grid, world_seed)
	interactions.configure(grid)
	hud = preload("res://features/levels/forest/run_hud.tscn").instantiate()
	$HUD.add_child(hud)
	hud.world = self
	$GridPlayer.cell_entered.connect(_on_cell_entered)
	$GridPlayer.chop_impact.connect(_on_chop_impact)
	for health_bin in range(4):
		for moisture_bin in range(4):
			var mat = ShaderMaterial.new()
			mat.shader = preload("res://features/levels/forest/shader_grid.gdshader")
			var green = Color("315f3c").lerp(Color("5c894a"), moisture_bin / 3.0)
			mat.set_shader_parameter("terrain_color", Color("80684a").lerp(green, health_bin / 3.0))
			mat.set_shader_parameter("terrain_health", health_bin / 3.0)
			mat.set_shader_parameter("world_seed", float(posmod(world_seed, 65521)))
			mat.set_shader_parameter("variation_strength", terrain_variation_strength)
			palette.append(mat)
	for color in [Color("665548"), Color("81783c"), Color("496b35"), Color("246043")]:
		var mat = StandardMaterial3D.new()
		mat.albedo_color = color
		mat.roughness = 1.0
		leaf_materials.append(mat)
	
	var water_container = Node3D.new()
	water_container.name = "Water"
	add_child(water_container)
	var water_mat = StandardMaterial3D.new()
	water_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water_mat.albedo_color = Color(0.18, 0.58, 0.88, 0.72)
	water_mat.roughness = 0.1
	water_mat.metallic = 0.15
	var water_box = BoxMesh.new()
	water_box.size = Vector3(grid.CELL_SIZE * 0.96, 0.08, grid.CELL_SIZE * 0.96)

	var tile = BoxMesh.new()
	tile.size = Vector3(grid.CELL_SIZE, 0.3, grid.CELL_SIZE)
	for z in range(grid.SIZE):
		for x in range(grid.SIZE):
			var cell = Vector2i(x, z)
			var data = grid.cells[z * grid.SIZE + x]
			var ground = MeshInstance3D.new()
			ground.mesh = tile
			ground.material_override = palette[15]
			ground.position = grid.world_position(cell) + Vector3(0, -0.15, 0)
			$Terrain.add_child(ground)
			grounds.append(ground)
			if data.get("water", false):
				var water_mesh = MeshInstance3D.new()
				water_mesh.mesh = water_box
				water_mesh.material_override = water_mat
				water_mesh.position = grid.world_position(cell) + Vector3(0, 0.02, 0)
				water_container.add_child(water_mesh)
				water_tiles[cell] = water_mesh
			elif data.tree:
				var tree = TREE.instantiate()
				tree.position = grid.world_position(cell)
				tree.rotation.y = data.rotation
				tree.scale = Vector3.ONE * data.scale
				$Vegetation.add_child(tree)
				trees[cell] = tree
	$GridPlayer.configure(grid)
	$CameraRig.position = grid.world_position(grid.start)
	$HUD/Info.hide()
	SettingsManager.graphics_changed.connect(_apply_shadow_quality)
	_apply_shadow_quality()
	_create_landmarks()
	_create_kenney_props()
	_create_weather_effects()
	_create_water_splash()
	_create_wood_chips()
	_update_lighting()
	_refresh_visuals()
	_update_weather_effects()
	_update_hud()

func _apply_shadow_quality():
	$Sun.shadow_enabled = SettingsManager.shadow_quality > 0
	$Sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL

func _process(delta):
	if ended:
		return
	_advance_presentation(delta)
	var event = interactions.tick(delta, $GridPlayer.cell)
	if not event.is_empty():
		$GridPlayer.stop_chopping()
		_finish_interaction(event)
	elif interactions.target.x < 0 and $GridPlayer.is_chopping:
		$GridPlayer.stop_chopping()
	tick_accumulator += delta * simulation_time_scale
	if tick_accumulator >= 1.0:
		tick_accumulator -= 1.0
		var health_before = survival.health
		climate.tick(1.0)
		var cell = $GridPlayer.cell
		var shade = climate.shade_at(cell)
		var safe = cell.distance_to(grid.start) <= 2.2
		survival.tick(1.0, climate.temperature, shade, safe, SaveManager.has_heat_resistance())
		hud.damage_feedback(survival.health < health_before)
		if climate.weather == "heat":
			_discover("climate.heatwave", "Heatwave: weather intensifies the warming trend")
		if shade > 0.0:
			_discover("interaction.tree_shade", "Trees reduce heat exposure")
		_refresh_visuals()
		_update_weather_effects()
		if survival.dead:
			_end_run("death")
		_update_hud()

func _unhandled_input(event):
	if ended or $GridPlayer.moving or not event.is_action_pressed("interact"):
		return
	if $GridPlayer.cell.distance_to(grid.start) <= 1.5:
		hud.show_modal("bonfire")
	elif interactions.begin($GridPlayer.cell, $GridPlayer.facing):
		var msg = "Chopping... moving cancels the action"
		if interactions.action_kind == "water_soil":
			msg = "Revitalizing soil... moving cancels the action"
		elif interactions.action_kind == "plant_sapling":
			msg = "Planting sapling... moving cancels the action"
		elif interactions.action_kind == "stump_removed":
			msg = "Removing stump... moving cancels the action"
		hud.notify(msg)
		if interactions.action_kind in ["tree_cut", "stump_removed"]:
			$GridPlayer.start_chopping(grid.world_position(interactions.target))
	else:
		if interactions.last_error == "no_seeds":
			hud.notify("Yeterli tohumunuz yok! Ağaç keserek tohum toplayabilirsiniz.")
		else:
			hud.notify("Face an adjacent tree, stump, or clear ground to interact")
	get_viewport().set_input_as_handled()

func _on_cell_entered(cell: Vector2i):
	climate.trample(cell)
	if climate.water_proximity(cell) > 0.15:
		_discover("terrain.water_source", "Lake: water cools the surroundings and resists drought")
	var current_cell_data = grid.cells[cell.y * grid.SIZE + cell.x]
	if current_cell_data.get("water", false) and current_cell_data.get("water_depth", 0.0) <= 0.25:
		_discover("terrain.dried_lakebed", "Dried lakebed: passable during heatwaves")
	for offset in [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]:
		var next = cell + offset
		if grid.in_bounds(next):
			var data = grid.cells[next.y * grid.SIZE + next.x]
			if data.tree:
				if data.tree_state == "sapling":
					_discover("flora.sapling", "Young sapling")
				else:
					var dead = data.tree_state == "dead"
					_discover("flora.dead_tree" if dead else "flora.healthy_tree", "Dead tree" if dead else "Healthy tree")
	_update_hud()
	if cell == grid.objective:
		call_deferred("_end_run", "success")

func _discover(id: String, title: String):
	if SaveManager.discover(id):
		hud.notify("Discovery: " + title + "  +1 Knowledge")

func _end_run(kind: String):
	if ended:
		return
	ended = true
	hud.show_modal(kind)

func _finish_interaction(event: Dictionary):
	$GridPlayer.stop_chopping()
	var cell: Vector2i = event.cell
	if event.kind == "tree_cut":
		_discover("interaction.first_tree_cut", "Tree cut: shade is lost")
		hud.notify("Tree cut (+3 Seeds)! A stump remains.")
		if trees.has(cell):
			var falling = trees[cell]
			trees.erase(cell)
			var direction = Vector3(event.direction.x, 0, event.direction.y).normalized()
			var axis = Vector3.UP.cross(direction)
			falling.rotation = Vector3.ZERO
			var fall = falling.create_tween()
			fall.tween_property(falling, "quaternion", Quaternion(axis, PI * 0.5), 0.7).set_trans(Tween.TRANS_SINE)
			var landing: Vector2i = cell + event.direction
			if not grid.traversable(landing):
				fall.tween_callback(falling.queue_free)
		var stump = MeshInstance3D.new()
		var mesh = CylinderMesh.new()
		mesh.top_radius = 0.24
		mesh.bottom_radius = 0.3
		mesh.height = 0.35
		mesh.radial_segments = 7
		stump.mesh = mesh
		stump.material_override = leaf_materials[0]
		stump.position = grid.world_position(cell) + Vector3(0, 0.175, 0)
		$Vegetation.add_child(stump)
		trees[cell] = stump
	elif event.kind == "stump_removed":
		if trees.has(cell):
			trees[cell].queue_free()
			trees.erase(cell)
		hud.notify("Stump removed: the cell is now open")
	elif event.kind == "water_soil":
		_discover("interaction.water_soil", "Soil revitalized: moisture and nutrients restored")
		hud.notify("Soil revitalized! Fertile and moist.")
		if water_splash != null:
			water_splash.position = grid.world_position(cell) + Vector3(0, 0.15, 0)
			water_splash.restart()
	elif event.kind == "plant_sapling":
		_discover("interaction.plant_sapling", "Sapling planted: will grow into a shade-giving tree")
		hud.notify("Sapling planted (-1 Seed)! Keep it moist to help it grow.")
		var sapling = SAPLING.instantiate()
		sapling.position = grid.world_position(cell)
		sapling.scale = Vector3.ONE * 0.8
		$Vegetation.add_child(sapling)
		trees[cell] = sapling
	_refresh_visuals()
	_update_hud()

func _refresh_visuals():
	for i in range(grid.cells.size()):
		var data = grid.cells[i]
		var health_bin = clampi(int(data.health * 3.99), 0, 3)
		var moisture_bin = clampi(int(data.moisture * 3.99), 0, 3)
		grounds[i].material_override = palette[health_bin * 4 + moisture_bin]
		var low = data.get("recovery_low", 1.0)
		if data.health < low:
			data.recovery_low = data.health
		if low < 0.85 and data.health > low + 0.08 and not recovery_seen:
			recovery_seen = true
			_discover("flora.recovery", "Vegetation recovers in favorable weather")
		var cell = Vector2i(i % grid.SIZE, floori(float(i) / grid.SIZE))
		if trees.has(cell):
			var node = trees[cell]
			if data.tree_state == "sapling":
				node.scale = Vector3.ONE * clampf(data.tree_health * 1.1, 0.5, 1.1)
			elif data.tree_state in ["healthy", "dead"]:
				if node.has_node("Stem"):
					# Sapling matured into full tree
					node.queue_free()
					var mature_tree = TREE.instantiate()
					mature_tree.position = grid.world_position(cell)
					$Vegetation.add_child(mature_tree)
					trees[cell] = mature_tree
					node = mature_tree
					_discover("flora.tree_matured", "Mature tree: grown from planted sapling")
					hud.notify("A sapling has grown into a mature tree!")
				var bucket = clampi(int(data.tree_health * 3.99), 0, 3)
				for child in node.get_children():
					if child is MeshInstance3D and child.name.begins_with("Crown"):
						child.material_override = leaf_materials[bucket]
						child.visible = data.tree_state != "dead"
	for cell in water_tiles.keys():
		var node: MeshInstance3D = water_tiles[cell]
		var data = grid.cells[cell.y * grid.SIZE + cell.x]
		var depth = data.get("water_depth", 0.0)
		if depth < 0.12:
			node.visible = false
		else:
			node.visible = true
			node.scale = Vector3(clampf(0.6 + depth * 0.4, 0.6, 1.0), clampf(depth, 0.2, 1.0), clampf(0.6 + depth * 0.4, 0.6, 1.0))
			node.position.y = lerpf(-0.04, 0.02, depth)

func _update_hud():
	var safe = $GridPlayer.cell.distance_to(grid.start) <= 2.2
	hud.update_status(survival.health, survival.exposure, climate.temperature, climate.weather, climate.elapsed * 0.025, SaveManager.progression.knowledge, safe, interactions.target.x >= 0, interactions.seeds)

func _create_landmarks():
	var fire = Node3D.new()
	fire.name = "Bonfire"
	fire.position = grid.world_position(grid.start) + Vector3(0.6, 0.0, 0.6)
	add_child(fire)
	flame_material = ShaderMaterial.new()
	flame_material.shader = preload("res://features/levels/forest/shader_bonfire.gdshader")
	for i in range(3):
		var flame = MeshInstance3D.new()
		flame.name = "Flame%d" % i
		var cone = CylinderMesh.new()
		cone.top_radius = 0.015
		cone.bottom_radius = 0.36
		cone.height = 1.1
		cone.radial_segments = 5
		cone.rings = 3
		flame.mesh = cone
		flame.material_override = flame_material
		flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		flame.position = Vector3((i - 1) * 0.19, 0.63 if i == 1 else 0.46, 0.08 if i == 1 else -0.06)
		flame.scale = Vector3.ONE * (1.0 if i == 1 else 0.72)
		flame.rotation.y = i * 1.8
		fire.add_child(flame)
	var glow = StandardMaterial3D.new()
	glow.albedo_color = Color("ffc25b")
	glow.emission_enabled = true
	glow.emission = Color("d45e24")
	var clearing = MeshInstance3D.new()
	var marker = CylinderMesh.new()
	marker.top_radius = 0.9
	marker.bottom_radius = 0.9
	marker.height = 0.08
	marker.radial_segments = 12
	clearing.mesh = marker
	clearing.material_override = glow
	clearing.position = grid.world_position(grid.objective) + Vector3(0, 0.05, 0)
	add_child(clearing)

	# Crossed logs make the procedural fire recognizable without asset packs.
	var wood = StandardMaterial3D.new()
	wood.albedo_color = Color("493325")
	for angle in [-0.6, 0.6]:
		var log_mesh = BoxMesh.new()
		log_mesh.size = Vector3(1.35, 0.2, 0.24)
		var log_node = MeshInstance3D.new()
		log_node.mesh = log_mesh
		log_node.material_override = wood
		log_node.position = fire.position + Vector3(0, 0.14, 0)
		log_node.rotation.y = angle
		add_child(log_node)
	var landmark = MeshInstance3D.new()
	var stone = SphereMesh.new()
	stone.radius = 0.55
	stone.height = 1.3
	stone.radial_segments = 6
	stone.rings = 3
	landmark.mesh = stone
	landmark.material_override = glow
	landmark.position = clearing.position + Vector3(0, 0.6, 0)
	add_child(landmark)

# Presentation has its own clock: no changes to seeded climate or logical cells.
# The one light stays above the scene at night as cool moonlight, keeping shadows
# continuous across the cycle without a second shadow-casting light.
func _advance_presentation(delta: float):
	if not is_finite(delta) or delta <= 0.0:
		return
	presentation_elapsed += delta
	if flame_material != null:
		flame_material.set_shader_parameter("animation_time", fposmod(presentation_elapsed, TAU * 100.0))
	_update_lighting(delta)

func _update_lighting(delta: float = 0.0):
	var phase = starting_day_phase + presentation_elapsed / maxf(day_night_duration, 1.0)
	var elevation = sin(phase * TAU)
	var daylight = smoothstep(-0.2, 0.3, elevation)
	$Sun.rotation = Vector3(deg_to_rad(-10.0 - 52.0 * absf(elevation)), phase * TAU - 1.7, 0.0)
	$Sun.light_energy = lerpf(0.2, 1.15, daylight)
	var weather_color = Color(1, 0.78, 0.58) if climate.weather == "heat" else Color(0.78, 0.88, 1.0) if climate.weather == "rain" else Color(1, 0.91, 0.74)
	var target_color = Color("93b3e0").lerp(weather_color, daylight)
	$Sun.light_color = $Sun.light_color.lerp(target_color, 1.0 - exp(-delta * 2.0)) if delta > 0.0 else target_color
	var environment: Environment = $Environment.environment
	environment.ambient_light_energy = lerpf(night_ambient_energy, 0.7, daylight)
	environment.ambient_light_color = Color("a2bbd6").lerp(Color(0.8, 0.89, 0.9), daylight)

func _create_kenney_props():
	var models = [preload("res://features/levels/forest/props/rock_small_a.glb"), preload("res://features/levels/forest/props/rock_small_b.glb")]
	for i in range(grid.cells.size()):
		var data = grid.cells[i]
		var cell = Vector2i(i % grid.SIZE, floori(float(i) / grid.SIZE))
		if data.tree or cell.distance_to(grid.start) < 2.5 or cell == grid.objective or data.shade < 0.32 or data.shade > 0.36:
			continue
		var prop = models[i % 2].instantiate()
		prop.name = "DecorativeRock%d" % i
		prop.position = grid.world_position(cell) + Vector3(0.45, 0, 0.35)
		prop.rotation.y = data.rotation
		prop.scale = Vector3.ONE * 1.5
		prop.add_to_group("forest_props")
		add_child(prop)

func _create_weather_effects():
	var center = grid.world_position(Vector2i(grid.SIZE / 2, grid.SIZE / 2))
	
	rain_particles = CPUParticles3D.new()
	rain_particles.name = "RainParticles"
	rain_particles.emitting = false
	rain_particles.amount = 140
	rain_particles.lifetime = 1.2
	rain_particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	rain_particles.emission_box_extents = Vector3(18.0, 1.0, 18.0)
	rain_particles.direction = Vector3(-0.2, -1.0, -0.1)
	rain_particles.spread = 4.0
	rain_particles.initial_velocity_min = 18.0
	rain_particles.initial_velocity_max = 24.0
	
	var rain_mat = StandardMaterial3D.new()
	rain_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rain_mat.albedo_color = Color(0.75, 0.88, 1.0, 0.45)
	rain_mat.roughness = 0.2
	
	var drop = BoxMesh.new()
	drop.size = Vector3(0.025, 0.38, 0.025)
	drop.material = rain_mat
	rain_particles.mesh = drop
	rain_particles.position = center + Vector3(0, 12.0, 0)
	add_child(rain_particles)

	heat_particles = CPUParticles3D.new()
	heat_particles.name = "HeatParticles"
	heat_particles.emitting = false
	heat_particles.amount = 40
	heat_particles.lifetime = 2.4
	heat_particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	heat_particles.emission_box_extents = Vector3(18.0, 0.2, 18.0)
	heat_particles.direction = Vector3(0.0, 1.0, 0.0)
	heat_particles.spread = 15.0
	heat_particles.initial_velocity_min = 0.5
	heat_particles.initial_velocity_max = 1.2

	var heat_mat = StandardMaterial3D.new()
	heat_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	heat_mat.albedo_color = Color(1.0, 0.65, 0.25, 0.55)
	heat_mat.emission_enabled = true
	heat_mat.emission = Color(1.0, 0.5, 0.15)
	heat_mat.emission_energy_multiplier = 0.8

	var ember = SphereMesh.new()
	ember.radius = 0.035
	ember.height = 0.07
	ember.radial_segments = 5
	ember.rings = 3
	ember.material = heat_mat
	heat_particles.mesh = ember
	heat_particles.position = center + Vector3(0, 0.2, 0)
	add_child(heat_particles)

func _create_water_splash():
	water_splash = CPUParticles3D.new()
	water_splash.name = "WaterSplash"
	water_splash.emitting = false
	water_splash.one_shot = true
	water_splash.explosiveness = 0.92
	water_splash.amount = 24
	water_splash.lifetime = 0.55
	water_splash.direction = Vector3(0, 1, 0)
	water_splash.spread = 55.0
	water_splash.initial_velocity_min = 2.0
	water_splash.initial_velocity_max = 4.0
	water_splash.gravity = Vector3(0, -9.8, 0)
	
	var water_mat = StandardMaterial3D.new()
	water_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water_mat.albedo_color = Color(0.35, 0.72, 1.0, 0.75)
	water_mat.roughness = 0.1
	
	var drop = SphereMesh.new()
	drop.radius = 0.04
	drop.height = 0.08
	drop.radial_segments = 5
	drop.rings = 3
	drop.material = water_mat
	water_splash.mesh = drop
	add_child(water_splash)

func _create_wood_chips():
	wood_chips = CPUParticles3D.new()
	wood_chips.name = "WoodChips"
	wood_chips.emitting = false
	wood_chips.one_shot = true
	wood_chips.explosiveness = 0.95
	wood_chips.amount = 20
	wood_chips.lifetime = 0.45
	wood_chips.direction = Vector3(0, 1, 0)
	wood_chips.spread = 65.0
	wood_chips.initial_velocity_min = 2.0
	wood_chips.initial_velocity_max = 4.2
	wood_chips.gravity = Vector3(0, -9.8, 0)
	
	var chip_mat = StandardMaterial3D.new()
	chip_mat.albedo_color = Color(0.82, 0.66, 0.45)
	chip_mat.roughness = 0.9
	
	var chip = BoxMesh.new()
	chip.size = Vector3(0.045, 0.045, 0.045)
	chip.material = chip_mat
	wood_chips.mesh = chip
	add_child(wood_chips)

func _on_chop_impact(impact_pos: Vector3):
	if wood_chips != null:
		wood_chips.position = impact_pos
		wood_chips.restart()
	if interactions.target.x >= 0 and trees.has(interactions.target):
		var tree_node = trees[interactions.target]
		if tree_node != null and is_instance_valid(tree_node):
			var orig_pos = grid.world_position(interactions.target)
			var hit_dir = Vector3(interactions.target.x - $GridPlayer.cell.x, 0, interactions.target.y - $GridPlayer.cell.y).normalized()
			var tween = tree_node.create_tween()
			tween.tween_property(tree_node, "position", orig_pos + hit_dir * 0.07, 0.04)
			tween.tween_property(tree_node, "position", orig_pos - hit_dir * 0.03, 0.05)
			tween.tween_property(tree_node, "position", orig_pos, 0.06)

func _update_weather_effects():
	if rain_particles != null:
		rain_particles.emitting = (climate.weather == "rain")
	if heat_particles != null:
		heat_particles.emitting = (climate.weather == "heat")
