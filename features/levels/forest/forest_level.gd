extends Node3D
const GridData = preload("res://features/levels/forest/grid_data.gd")
const TREE = preload("res://features/levels/forest/forest_tree.tscn")
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
var palette: Array[ShaderMaterial] = []
var leaf_materials: Array[StandardMaterial3D] = []
var tick_accumulator = 0.0
var ended = false
var hud: Control
var recovery_seen = false

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
			if data.tree:
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
	_update_lighting()
	_refresh_visuals()
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
		_finish_interaction(event)
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
		if survival.dead:
			_end_run("death")
		_update_hud()

func _unhandled_input(event):
	if ended or $GridPlayer.moving or not event.is_action_pressed("interact"):
		return
	if $GridPlayer.cell.distance_to(grid.start) <= 1.5:
		hud.show_modal("bonfire")
	elif interactions.begin($GridPlayer.cell, $GridPlayer.facing):
		hud.notify("Chopping... moving cancels the action")
	else:
		hud.notify("Move beside a tree or stump to interact")
	get_viewport().set_input_as_handled()

func _on_cell_entered(cell: Vector2i):
	climate.trample(cell)
	for offset in [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]:
		var next = cell + offset
		if grid.in_bounds(next):
			var data = grid.cells[next.y * grid.SIZE + next.x]
			if data.tree:
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
	var cell: Vector2i = event.cell
	if event.kind == "tree_cut":
		_discover("interaction.first_tree_cut", "Tree cut: shade is lost")
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
	else:
		if trees.has(cell):
			trees[cell].queue_free()
			trees.erase(cell)
		hud.notify("Stump removed: the cell is now open")
	_refresh_visuals()

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
		if trees.has(cell) and data.tree_state in ["healthy", "dead"]:
			var tree = trees[cell]
			var bucket = clampi(int(data.tree_health * 3.99), 0, 3)
			for child in tree.get_children():
				if child is MeshInstance3D and child.name.begins_with("Crown"):
					child.material_override = leaf_materials[bucket]

func _update_hud():
	var safe = $GridPlayer.cell.distance_to(grid.start) <= 2.2
	hud.update_status(survival.health, survival.exposure, climate.temperature, climate.weather, climate.elapsed * 0.025, SaveManager.progression.knowledge, safe, interactions.target.x >= 0)

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
