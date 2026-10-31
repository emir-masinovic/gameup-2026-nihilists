extends Node3D
const GridData = preload("res://features/levels/forest/grid_data.gd")
const TREE = preload("res://features/levels/forest/nature/nature_tree.tscn")
const NatureProps = preload("res://features/levels/forest/nature/nature_visuals.gd")
signal audio_cue(cue: String, at: Vector3)
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
var objectives = preload("res://features/levels/forest/run_objectives.gd").new()
var cut_cells = {}
var logs = {}
var effects: Node3D
var water_material: StandardMaterial3D
var charred_material: ShaderMaterial
var last_weather = ""
var ground_cover: Node3D
var warned_fire = false

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
				tree.variant = data.get("variant", 0) % 2
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
	water_material = StandardMaterial3D.new()
	water_material.albedo_color = Color("477c88")
	water_material.roughness = 0.5
	charred_material = palette[0].duplicate()
	charred_material.set_shader_parameter("terrain_color", Color("30392f"))
	effects = preload("res://features/levels/forest/ecosystem_effects.gd").new()
	add_child(effects)
	effects.configure(grid, world_seed, flame_material)
	ground_cover = preload("res://features/levels/forest/nature/ground_cover.gd").new()
	add_child(ground_cover)
	ground_cover.configure(grid)
	hud.notify("Survey dry ground, clear a small firebreak, then find recovering vegetation. Interact at camp for your field notes.")
	_update_lighting()
	_refresh_visuals()
	_update_hud()

func _apply_shadow_quality():
	$Sun.shadow_enabled = SettingsManager.shadow_quality > 0
	$Sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	$Sun.directional_shadow_max_distance = 75.0
	$Sun.shadow_bias = 0.03
	$Sun.shadow_normal_bias = 0.7

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
		var hazard = climate.fire_at(cell)
		if hazard > 0 and not safe:
			survival.health = maxf(0, survival.health - hazard * 7.0 * SaveManager.get_fire_damage_multiplier())
			survival.exposure = minf(100, survival.exposure + hazard * 5.0)
			survival.dead = survival.health <= 0
			if not warned_fire:
				hud.notify("Fire nearby: retreat to wet ground or a cleared route")
				warned_fire = true
		if climate.weather != last_weather:
			last_weather = climate.weather
			audio_cue.emit("weather_" + last_weather, $GridPlayer.position)
		if climate.weather == "rain":
			_discover("climate.rainfall", "Rainfall supports recovery")
		if climate.weather == "heat" or grid.cells[cell.y * grid.SIZE + cell.x].moisture < 0.35:
			objectives.observe_problem()
			_discover("climate.drought", "Dry vegetation stores less moisture")
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
	else:
		interactions.duration = 1.2 * SaveManager.get_chop_multiplier()
		if interactions.begin($GridPlayer.cell, $GridPlayer.facing):
			hud.notify("Clearing... moving cancels the action")
			audio_cue.emit("chop", $GridPlayer.position)
		else:
			hud.notify("Interact beside a tree, stump or fallen log")
	get_viewport().set_input_as_handled()

func _on_cell_entered(cell: Vector2i):
	climate.trample(cell)
	audio_cue.emit("footstep", grid.world_position(cell))
	var here = grid.cells[cell.y * grid.SIZE + cell.x]
	if here.moisture < 0.45 or here.get("burned", false):
		objectives.observe_problem()
	if here.get("terrain", "grass") == "water" or _near_water(cell):
		_discover("terrain.pond", "Ponds shelter wet ground")
	for near in [cell, cell + Vector2i.UP, cell + Vector2i.LEFT, cell + Vector2i.DOWN, cell + Vector2i.RIGHT]:
		if grid.in_bounds(near) and grid.cells[near.y * grid.SIZE + near.x].get("burning", false):
			objectives.observe_problem()
			_discover("climate.wildfire", "Dry fuel carries wildfire")
	for offset in [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]:
		var next = cell + offset
		if grid.in_bounds(next):
			var data = grid.cells[next.y * grid.SIZE + next.x]
			if data.tree:
				var dead = data.tree_state == "dead"
				_discover("flora.dead_tree" if dead else "flora.healthy_tree", "Dead tree" if dead else "Healthy tree")
	_update_hud()
	if cell == grid.objective:
		if objectives.ready_for_clearing():
			_discover("landmark.refuge", "Forest refuge reached")
			call_deferred("_end_run", "success")
		else:
			hud.notify(objectives.summary())

func _discover(id: String, title: String):
	if SaveManager.discover(id):
		hud.notify("Discovery: " + title + "  +1 Knowledge")
		audio_cue.emit("discovery", $GridPlayer.position)

func _end_run(kind: String):
	if ended:
		return
	ended = true
	hud.show_modal(kind)

func _finish_interaction(event: Dictionary):
	var cell: Vector2i = event.cell
	if event.kind == "tree_cut":
		cut_cells[cell] = true
		_discover("interaction.first_tree_cut", "Tree cut: less shade and less fuel")
		audio_cue.emit("tree_fall", grid.world_position(cell))
		if trees.has(cell):
			var falling = trees[cell]
			trees.erase(cell)
			var direction = Vector3(event.direction.x,0,event.direction.y).normalized()
			falling.rotation = Vector3.ZERO
			var fall = falling.create_tween()
			fall.tween_property(falling,"quaternion",Quaternion(Vector3.UP.cross(direction),PI*0.5),0.7).set_trans(Tween.TRANS_SINE)
			fall.tween_callback(falling.queue_free)
		var stump = NatureProps.instantiate_stump()
		stump.position = grid.world_position(cell)
		$Vegetation.add_child(stump)
		trees[cell] = stump
		if event.has("landing"):
			var landing: Vector2i = event.landing
			var log_visual = NatureProps.instantiate_log()
			log_visual.position = grid.world_position(landing)
			log_visual.rotation.y = atan2(event.direction.x, event.direction.y)
			$Vegetation.add_child(log_visual)
			logs[landing] = log_visual
	elif event.kind == "log_cleared":
		if logs.has(cell):
			logs[cell].queue_free()
			logs.erase(cell)
		_discover("interaction.fallen_log", "A cleared log reopens the route")
	else:
		if trees.has(cell):
			trees[cell].queue_free()
			trees.erase(cell)
		if cut_cells.has(cell) and objectives.record_mitigation():
			_discover("interaction.firebreak", "Cleared fuel breaks the fire path; shade is lost")
		hud.notify("Stump removed: fuel cleared and route open")
	_refresh_visuals()

func _refresh_visuals():
	for i in range(grid.cells.size()):
		var data = grid.cells[i]
		var health_bin = clampi(int(data.health * 3.99), 0, 3)
		var moisture_bin = clampi(int(data.moisture * 3.99), 0, 3)
		if data.get("terrain", "grass") == "water" and data.get("water_level", 0.0) > 0.1:
			grounds[i].material_override = water_material
		elif data.get("burned", false):
			grounds[i].material_override = charred_material
		else:
			grounds[i].material_override = palette[health_bin * 4 + moisture_bin]
		var moisture_low = data.get("moisture_low", data.moisture)
		data.moisture_low = minf(moisture_low, data.moisture)
		if climate.weather == "rain" and moisture_low < 0.5 and data.moisture > moisture_low + 0.15:
			objectives.observe_recovery()
		var low = data.get("recovery_low", 1.0)
		if data.health < low:
			data.recovery_low = data.health
		if low < 0.85 and data.health > low + 0.08:
			objectives.observe_recovery()
			if not recovery_seen:
				recovery_seen = true
				_discover("flora.recovery", "Vegetation recovers in favorable weather")
		var cell = Vector2i(i % grid.SIZE, floori(float(i) / grid.SIZE))
		if trees.has(cell) and data.tree_state in ["healthy", "dead"]:
			trees[cell].set_health(data.tree_health, data.tree_state == "dead")
			if data.get("burned", false):
				_discover("flora.burned_tree", "Burned trees lose shade")
		if logs.has(cell) and not data.get("log", false):
			logs[cell].queue_free()
			logs.erase(cell)
	if effects != null:
		effects.update_state(grid, climate.weather)
	if ground_cover != null:
		ground_cover.update_state(grid)

func _update_hud():
	var safe = $GridPlayer.cell.distance_to(grid.start) <= 2.2
	hud.update_status(survival.health, survival.exposure, climate.temperature, climate.weather, climate.warming_pressure(), SaveManager.progression.knowledge, safe, interactions.target.x >= 0)
	hud.set_environment_context(climate.fire_at($GridPlayer.cell), objectives.summary(), objectives.ready_for_clearing())

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
	var smoke = CPUParticles3D.new()
	smoke.name = "Smoke"
	smoke.amount = 10
	smoke.lifetime = 3.0
	smoke.direction = Vector3.UP
	smoke.spread = 18
	smoke.initial_velocity_min = 0.4
	smoke.initial_velocity_max = 0.6
	smoke.gravity = Vector3(0.08, 0.12, 0.03)
	smoke.position = Vector3(0,1.0,0)
	var puff = SphereMesh.new()
	puff.radius = 0.12
	puff.height = 0.24
	puff.radial_segments = 6
	puff.rings = 3
	var smoke_material = StandardMaterial3D.new()
	smoke_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smoke_material.albedo_color = Color(0.45,0.49,0.45,0.2)
	puff.material = smoke_material
	smoke.mesh = puff
	smoke.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	fire.add_child(smoke)
	var warmth = OmniLight3D.new()
	warmth.name = "Warmth"
	warmth.position = Vector3(0,1.0,0)
	warmth.light_color = Color(1,0.5,0.19)
	warmth.light_energy = 0.5
	warmth.omni_range = 3.5
	warmth.shadow_enabled = false
	fire.add_child(warmth)
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
	if has_node("Bonfire/Warmth"):
		$Bonfire/Warmth.light_energy = 0.45 + sin(presentation_elapsed * 6.0) * 0.06
	if flame_material != null:
		flame_material.set_shader_parameter("animation_time", fposmod(presentation_elapsed, TAU * 100.0))
	_update_lighting(delta)
	if effects != null:
		effects.update_clock(presentation_elapsed)

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
		if data.tree or data.get("terrain", "grass") == "water" or cell.distance_to(grid.start) < 2.5 or cell == grid.objective or data.shade < 0.32 or data.shade > 0.36:
			continue
		var prop = models[i % 2].instantiate()
		prop.name = "DecorativeRock%d" % i
		prop.position = grid.world_position(cell) + Vector3(0.45, 0, 0.35)
		prop.rotation.y = data.rotation
		prop.scale = Vector3.ONE * 1.5
		prop.add_to_group("forest_props")
		add_child(prop)

func _near_water(cell: Vector2i) -> bool:
	for offset in [Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT]:
		var candidate = cell + offset
		if grid.in_bounds(candidate):
			var data = grid.cells[candidate.y * grid.SIZE + candidate.x]
			if data.get("terrain", "grass") == "water" and data.get("water_level", 0.0) > 0.1:
				return true
	return false
