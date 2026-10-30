extends Node3D
const GridData = preload("res://features/levels/forest/grid_data.gd")
const TREE = preload("res://features/levels/forest/forest_tree.tscn")
@export var world_seed: int = 2026
@export_range(0.1, 10.0) var simulation_time_scale = 1.0
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
			var green = Color("778f50").lerp(Color("a7b66b"), moisture_bin / 3.0)
			mat.set_shader_parameter("terrain_color", Color("80684a").lerp(green, health_bin / 3.0))
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
	$HUD/Info.text = "FOREST"
	SettingsManager.graphics_changed.connect(_apply_shadow_quality)
	_apply_shadow_quality()
	_create_landmarks()
	_refresh_visuals()
	_update_hud()

func _apply_shadow_quality():
	$Sun.shadow_enabled = SettingsManager.shadow_quality > 0
	$Sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL

func _process(delta):
	if ended:
		return
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
		if survival.health < health_before:
			hud.get_node("Stats").modulate = Color(1, 0.5, 0.4)
		else:
			hud.get_node("Stats").modulate = Color.WHITE
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
	$Sun.light_color = Color(1, 0.78, 0.58) if climate.weather == "heat" else Color(0.78, 0.88, 1.0) if climate.weather == "rain" else Color(1, 0.91, 0.74)

func _update_hud():
	var safe = $GridPlayer.cell.distance_to(grid.start) <= 2.2
	hud.get_node("Stats").text = "Health %d / 100   Heat exposure %d / 100\nTemperature %.1f C   Weather: %s\nWarming trend +%.1f C   Knowledge %d\n%s" % [survival.health, survival.exposure, climate.temperature, climate.weather.capitalize(), climate.elapsed * 0.025, SaveManager.progression.knowledge, "Bonfire shelter - Interact to rest / upgrade" if safe else "Interact beside trees to chop; move to cancel"]
	hud.get_node("Objective").text = "Reach the golden clearing\nDistance: %d cells" % (abs($GridPlayer.cell.x - grid.objective.x) + abs($GridPlayer.cell.y - grid.objective.y))

func _create_landmarks():
	var fire = MeshInstance3D.new()
	var cone = CylinderMesh.new()
	cone.top_radius = 0.05
	cone.bottom_radius = 0.45
	cone.height = 1.1
	cone.radial_segments = 7
	fire.mesh = cone
	var glow = StandardMaterial3D.new()
	glow.albedo_color = Color("ffc25b")
	glow.emission_enabled = true
	glow.emission = Color("d45e24")
	fire.material_override = glow
	fire.position = grid.world_position(grid.start) + Vector3(0.6, 0.55, 0.6)
	add_child(fire)
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
		log_node.position = fire.position + Vector3(0, -0.4, 0)
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
