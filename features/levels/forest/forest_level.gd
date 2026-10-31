extends Node3D
const GridData = preload("res://features/levels/forest/grid_data.gd")
const SEED_DROP = preload("res://features/levels/forest/VisualSeedDrop.tscn")
const SAPLING = preload("res://features/levels/forest/VisualSapling.tscn")
const TREE = preload("res://features/levels/forest/nature/nature_tree.tscn")
const NatureProps = preload("res://features/levels/forest/nature/nature_visuals.gd")
const CROP_INDICATOR = preload("res://features/levels/forest/crop_indicator.gd")
const FOREST_SEED = preload("res://features/levels/forest/forest_seed.tscn")
const FOREST_SAPLING = preload("res://features/levels/forest/forest_sapling.tscn")
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
var terrain_renderer: Node3D
var trees = {}
var palette: Array[ShaderMaterial] = []
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
var regions: RefCounted
var region_id = "forest"
var region_state = {}
var transitioning = false
var interaction_ring: TorusMesh
var interaction_marker: MeshInstance3D
var habitat_marker: MeshInstance3D
var previous_objective = ""
var context_action = preload("res://features/levels/forest/InteractionContext.gd").new()
var foraging: RefCounted
var forage_visuals: Node3D
var selected_interaction = {}
var custom_interactables: Array = []
var planting: RefCounted
var farmland_container: Node3D
var tilled_meshes: Dictionary = {}
var crop_indicators: Dictionary = {}
var water_tiles: Dictionary = {}
var water_splash: CPUParticles3D
var wood_chips: CPUParticles3D
var dirt_puff: CPUParticles3D
var seed_visuals = {}
var decorated_cells = {}
var wet_indicator: MeshInstance3D



func _ready():
	if not OS.get_cmdline_user_args().has("--fixed-seed"):
		world_seed = SceneFlow.next_seed
	if SceneFlow.run_regions == null or SceneFlow.run_regions.seed_for("forest") != world_seed:
		SceneFlow.run_regions = preload("res://features/levels/forest/RunRegions.gd").new()
		SceneFlow.run_regions.configure(world_seed)
	regions = SceneFlow.run_regions
	region_id = regions.current_id
	region_state = regions.enter(region_id)
	world_seed = regions.seed_for(region_id)
	grid = region_state.grid
	climate = region_state.climate
	cut_cells = region_state.cut_cells
	foraging = region_state.foraging
	planting = regions.planting
	survival = regions.survival
	objectives = regions.objectives
	objectives.regional_mode = true
	presentation_elapsed = regions.elapsed

	interactions.configure(grid)
	hud = preload("res://features/levels/forest/run_hud.tscn").instantiate()
	$HUD.add_child(hud)
	hud.world = self
	$GridPlayer.cell_entered.connect(_on_cell_entered)

	farmland_container = get_node_or_null("Farmland")
	if farmland_container == null:
		farmland_container = Node3D.new()
		farmland_container.name = "Farmland"
		add_child(farmland_container)
	_create_water_splash()
	_create_wood_chips()
	_create_dirt_puff()
	if $GridPlayer.has_signal("chop_impact"):
		$GridPlayer.chop_impact.connect(_on_chop_impact)
	if $GridPlayer.has_signal("till_impact"):
		$GridPlayer.till_impact.connect(_on_till_impact)
	if $GridPlayer.has_signal("water_fill_splash"):
		$GridPlayer.water_fill_splash.connect(_on_water_fill_splash)
	if $GridPlayer.has_signal("water_pour_splash"):
		$GridPlayer.water_pour_splash.connect(_on_water_pour_splash)
	if planting != null:
		if interactions.water_ml == 0 or planting.water_ml == 0:
			interactions.water_ml = 0
			planting.water_ml = 0
		else:
			interactions.water_ml = min(interactions.water_ml, planting.water_ml)
			planting.water_ml = interactions.water_ml
		interactions.seeds = planting.seed_count
	var regional_palette: Dictionary = regions.palette_for(region_id)
	for health_bin in range(4):
		for moisture_bin in range(4):
			var mat = ShaderMaterial.new()
			mat.shader = preload("res://features/levels/forest/shader_grid.gdshader")
			var green: Color = Color("b39a50").lerp(Color("8f8b43"), float(moisture_bin)) if moisture_bin < 2 else regional_palette.dry_green.lerp(regional_palette.wet_green, float(moisture_bin - 2))
			mat.set_shader_parameter("terrain_color", regional_palette.soil.lerp(green, health_bin / 3.0))
			mat.set_shader_parameter("terrain_health", health_bin / 3.0)
			mat.set_shader_parameter("world_seed", float(posmod(world_seed, 65521)))
			mat.set_shader_parameter("variation_strength", terrain_variation_strength)
			palette.append(mat)
	var water_container = get_node_or_null("Water")
	if water_container == null:
		water_container = Node3D.new()
		water_container.name = "Water"
		add_child(water_container)
	var water_mat = StandardMaterial3D.new()
	water_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water_mat.albedo_color = Color(0.18, 0.58, 0.88, 0.72)
	water_mat.roughness = 0.1
	water_mat.metallic = 0.15
	var water_box = BoxMesh.new()
	water_box.size = Vector3(grid.CELL_SIZE * 0.96, 0.08, grid.CELL_SIZE * 0.96)
	for z in range(grid.SIZE):
		for x in range(grid.SIZE):
			var cell = Vector2i(x, z)
			var data = grid.cells[z * grid.SIZE + x]
			if data.get("water", false):
				var water_mesh = MeshInstance3D.new()
				water_mesh.mesh = water_box
				water_mesh.material_override = water_mat
				water_mesh.position = grid.world_position(cell) + Vector3(0, 0.02, 0)
				water_container.add_child(water_mesh)
				water_tiles[cell] = water_mesh
			elif data.tree:
				var tree = _vegetation_visual(data)
				if data.tree_state != "stump" and not tree.has_method("update_growth"):
					tree.variant = data.get("variant", 0) % 2
				tree.position = grid.world_position(cell)
				tree.rotation.y = data.rotation
				tree.scale = Vector3.ONE * data.scale
				$Vegetation.add_child(tree)
				trees[cell] = tree
	for i in range(grid.cells.size()):
		var data = grid.cells[i]
		if data.get("log", false):
			var cell = Vector2i(i % grid.SIZE, floori(float(i) / grid.SIZE))
			var log_visual = NatureProps.instantiate_log()
			log_visual.position = grid.world_position(cell)
			var direction: Vector2i = data.get("log_direction", Vector2i.UP)
			log_visual.rotation.y = atan2(direction.x, direction.y)
			$Vegetation.add_child(log_visual)
			logs[cell] = log_visual
	$GridPlayer.configure(grid)
	if not SceneFlow.region_arrival_from.is_empty():
		$GridPlayer.cell = regions.entry(region_id, SceneFlow.region_arrival_from)
		$GridPlayer.position = grid.world_position($GridPlayer.cell)
		$GridPlayer.require_release = true
	SceneFlow.region_arrival_from = ""
	SceneFlow.region_transitioning = false

	$CameraRig.position = grid.world_position(grid.start)
	$CameraRig.configure_targets(grid.world_position(grid.start), $GridPlayer, SceneFlow.camera_state)
	$CameraRig.mode_changed.connect(func(value): hud.notify("Camera: " + value))
	$HUD/Info.hide()
	SettingsManager.graphics_changed.connect(_apply_shadow_quality)
	_apply_shadow_quality()
	_create_landmarks()
	_update_bonfire_visuals()
	_create_kenney_props()
	water_material = StandardMaterial3D.new()
	water_material.albedo_color = Color("477c88")
	water_material.roughness = 0.5
	charred_material = palette[0].duplicate()
	charred_material.set_shader_parameter("terrain_color", Color("241f1b"))
	charred_material.set_shader_parameter("variation_strength", 0.08)
	terrain_renderer = preload("res://features/levels/forest/RendererTerrain.gd").new()
	$Terrain.add_child(terrain_renderer)
	terrain_renderer.configure(grid, palette, water_material, charred_material)
	effects = preload("res://features/levels/forest/ecosystem_effects.gd").new()
	add_child(effects)
	effects.configure(grid, world_seed, flame_material)
	ground_cover = preload("res://features/levels/forest/nature/ground_cover.gd").new()
	add_child(ground_cover)
	ground_cover.configure(grid)
	forage_visuals = preload("res://features/levels/forest/VisualForaging.gd").new()
	add_child(forage_visuals)
	forage_visuals.configure(grid)
	_create_region_markers()
	var listener = AudioListener3D.new()
	$GridPlayer.add_child(listener)
	listener.position.y = 1.0
	listener.make_current()
	SceneFlow.sounds.attach_world(self)
	_create_wet_indicator()
	hud.notify(regions.region_name(region_id) + ": " + objectives.summary())
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
	if ended or transitioning or get_tree().paused:
		return
	_advance_presentation(delta)
	_tick_context_action(delta)
	_update_interaction_marker()
	if get_tree().paused: return
	tick_accumulator += delta * simulation_time_scale
	if tick_accumulator >= 1.0:
		tick_accumulator -= 1.0
		var health_before = survival.health
		climate.tick(1.0)
		regions.advance(1.0)
		foraging.tick(1.0)
		_tick_bonfire(1.0)
		var cell = $GridPlayer.cell
		var shade = climate.shade_at(cell)
		var safe = cell.distance_to(grid.start) <= 2.2
		survival.tick(1.0, climate.temperature, shade, safe, SaveManager.has_heat_resistance(), {"camp_intensity": region_state.get("bonfire_intensity", 1.0), "weather": climate.weather, "canopy": shade, "wind": 0.5 if climate.weather in ["rain", "cool"] else 0.15, "fire_hazard": climate.fire_at(cell)})
		var hazard = climate.fire_at(cell)
		if hazard > 0 and not safe:
			survival.damage(hazard * 7.0 * SaveManager.get_fire_damage_multiplier())
			if not warned_fire:
				hud.notify("Fire nearby: retreat to wet ground or a cleared route")
				warned_fire = true
		if climate.weather != last_weather:
			last_weather = climate.weather
			audio_cue.emit("weather_" + last_weather, $GridPlayer.position)
		if climate.weather == "rain":
			_discover("climate.rainfall", "Rainfall supports recovery")
		if climate.weather == "heat" or grid.cells[cell.y * grid.SIZE + cell.x].moisture < 0.35:
			objectives.observe_problem(region_id)
			_discover("climate.drought", "Dry vegetation stores less moisture")
		hud.damage_feedback(survival.health < health_before)
		if survival.health < health_before:
			audio_cue.emit("damage", $GridPlayer.position)
		if climate.weather == "heat":
			_discover("climate.heatwave", "Heatwave: weather intensifies the warming trend")
		if shade > 0.0:
			_discover("interaction.tree_shade", "Trees reduce heat exposure")
		_refresh_visuals()
		if survival.dead:
			_end_run("death")
		_update_hud()

func _unhandled_input(event):
	if ended or transitioning or get_tree().paused:
		return
	if event.is_action_pressed("eat") and not event.is_echo():
		if survival.eat_berry():
			hud.notify("Ate berries")
			audio_cue.emit("discovery", $GridPlayer.position)
		else:
			hud.notify("No berries to eat" if survival.berry_count <= 0 else "Food and water reserves are full")
		_update_hud()
		get_viewport().set_input_as_handled()
		return
	if $GridPlayer.moving or event.is_echo():
		return
	if event.is_action_pressed("interact"):
		_try_interact("interact")
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("chop_gather"):
		_try_interact("chop_gather")
		get_viewport().set_input_as_handled()

func _try_interact(action_group: String):
	if planting != null:
		if interactions.water_ml == 0 or planting.water_ml == 0:
			interactions.water_ml = 0
			planting.water_ml = 0
		else:
			interactions.water_ml = min(interactions.water_ml, planting.water_ml)
			planting.water_ml = interactions.water_ml
		interactions.seeds = planting.seed_count
	if interactions.begin($GridPlayer.cell, $GridPlayer.facing, action_group):
		var target_pos = grid.world_position(interactions.target)
		var msg = ""
		if interactions.action_kind == "fill_water":
			msg = "Şişeye su dolduruluyor... hareket etmek iptal eder"
			$GridPlayer.start_filling_water(target_pos)
		elif interactions.action_kind == "water_soil":
			msg = "Sulanıyor... hareket etmek iptal eder"
			$GridPlayer.start_watering(target_pos)
		elif interactions.action_kind == "till_soil":
			msg = "Toprak çapalanıyor... hareket etmek iptal eder"
			$GridPlayer.start_tilling(target_pos)
		elif interactions.action_kind == "plant_sapling":
			msg = "Tohum ekiliyor... hareket etmek iptal eder"
		elif interactions.action_kind == "harvest_crop":
			msg = "Fidan/tohum çapalanıyor... hareket etmek iptal eder"
			$GridPlayer.start_tilling(target_pos)
		elif interactions.action_kind == "tree_cut":
			msg = "Ağaç kesiliyor... hareket etmek iptal eder"
			$GridPlayer.start_chopping(target_pos)
			audio_cue.emit("chop", $GridPlayer.position)
		elif interactions.action_kind == "collect_seeds":
			msg = "Tohum toplanıyor... hareket etmek iptal eder"
			$GridPlayer.start_gathering(target_pos)
		elif interactions.action_kind == "stump_removed":
			msg = "Removing stump... moving cancels the action"
			$GridPlayer.start_chopping(target_pos)
			audio_cue.emit("chop", $GridPlayer.position)
		hud.notify(msg)
	else:
		if action_group == "chop_gather":
			hud.notify("Ağaç kesmek için ağaca dönün, tohum toplamak için kalıntının üzerine gelin (Space)")
		else:
			if $GridPlayer.cell.distance_to(grid.start) <= 1.5:
				hud.show_modal("bonfire")
				return
			var front = $GridPlayer.cell + $GridPlayer.facing
			if grid.in_bounds(front) and grid.cells[front.y * grid.SIZE + front.x].get("berry_bush", false) and foraging != null:
				var amount: int = foraging.harvest(front)
				if amount > 0:
					survival.add_berries(amount)
					_discover("food.berry_bush", "Berry bushes supply food")
					_discover("food.first_harvest", "Food gathered for the journey")
					hud.notify("Harvested %d berries" % amount)
					audio_cue.emit("discovery", grid.world_position(front))
					_update_hud()
					return
			if interactions.last_error == "no_seeds":
				hud.notify("Yeterli tohumunuz yok! Ağaç kalıntısından tohum toplayabilirsiniz.")
			elif interactions.last_error == "no_water":
				hud.notify("Yeterli suyunuz yok! (%d ml gerekli) Gölden su doldurabilirsiniz." % interactions.WATER_PER_POUR)
			elif interactions.last_error == "water_full":
				hud.notify("Su şişeniz zaten tamamen dolu! (%d ml)" % interactions.MAX_WATER_ML)
			else:
				hud.notify("Bulunduğunuz yeri çapalamak/ekmek/sulamak ya da gölden su almak için (E)")

func _on_cell_entered(cell: Vector2i):
	if transitioning:
		return
	var destination: String = regions.exit_destination(region_id, cell)
	if not destination.is_empty():
		_request_region_transition(destination)
		return
	_discover("region." + region_id, regions.region_name(region_id) + " surveyed")
	climate.trample(cell)
	audio_cue.emit("footstep", grid.world_position(cell))
	var here = grid.cells[cell.y * grid.SIZE + cell.x]
	if here.get("berry_bush", false):
		_discover("food.berry_bush", "Berry bushes supply food")
	if here.moisture < 0.45 or here.get("burned", false):
		objectives.observe_problem(region_id)
	if here.get("terrain", "grass") == "water" or _near_water(cell):
		_discover("terrain.pond", "Ponds shelter wet ground")
	for near in [cell, cell + Vector2i.UP, cell + Vector2i.LEFT, cell + Vector2i.DOWN, cell + Vector2i.RIGHT]:
		if grid.in_bounds(near) and grid.cells[near.y * grid.SIZE + near.x].get("burning", false):
			objectives.observe_problem(region_id)
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
		if objectives.ready_for_clearing() and region_id == "wetlands":
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
	if $GridPlayer.has_method("stop_chopping"):
		$GridPlayer.stop_chopping()
		$GridPlayer.stop_tilling()
		$GridPlayer.stop_filling_water()
		$GridPlayer.stop_watering()
		$GridPlayer.stop_gathering()
	if event.is_empty() or not event.has("cell"):
		return
	var cell: Vector2i = event.cell
	if event.kind == "fill_water":
		_discover("interaction.fill_water", "Water filled: bottle replenished from lake")
		hud.notify("Şişeye su dolduruldu (+%d ml)! Mevcut su: %d ml" % [event.get("amount", 500), interactions.water_ml])
		if water_splash != null:
			water_splash.position = grid.world_position(cell) + Vector3(0, 0.05, 0)
			water_splash.restart()
		if planting != null:
			planting.water_ml = interactions.water_ml
	elif event.kind == "tree_cut":
		cut_cells[cell] = true
		_discover("interaction.first_tree_cut", "Tree cut: shade is lost")
		audio_cue.emit("tree_fall", grid.world_position(cell))
		hud.notify("Ağaç kesildi! Kalıntının üzerine gidip Space ile tohum toplayın.")
		if crop_indicators.has(cell):
			crop_indicators[cell].queue_free()
			crop_indicators.erase(cell)
		if trees.has(cell):
			var falling = trees[cell]
			trees.erase(cell)
			var direction = Vector3(event.direction.x, 0, event.direction.y).normalized()
			falling.rotation = Vector3.ZERO
			var fall = falling.create_tween()
			fall.tween_property(falling, "quaternion", Quaternion(Vector3.UP.cross(direction), PI * 0.5), 0.7).set_trans(Tween.TRANS_SINE)
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
	elif event.kind == "collect_seeds":
		_discover("interaction.collect_seeds", "Seeds collected: gained 3 seeds from tree remains")
		hud.notify("Ağaç kalıntısından tohumlar toplandı (+3 Tohum)!")
		if trees.has(cell):
			trees[cell].queue_free()
			trees.erase(cell)
		if crop_indicators.has(cell):
			crop_indicators[cell].queue_free()
			crop_indicators.erase(cell)
		if planting != null:
			planting.seed_count = interactions.seeds
	elif event.kind == "till_soil":
		_discover("interaction.till_soil", "Soil tilled: prepared for planting")
		hud.notify("Toprak çapalandı! Tohum ekmeye hazır.")
		if not tilled_meshes.has(cell):
			var tilled_patch = MeshInstance3D.new()
			var patch_mesh = BoxMesh.new()
			patch_mesh.size = Vector3(grid.CELL_SIZE * 0.98, 0.035, grid.CELL_SIZE * 0.98)
			var loam_mat = StandardMaterial3D.new()
			loam_mat.albedo_color = Color(0.24, 0.16, 0.10)
			loam_mat.roughness = 0.95
			patch_mesh.material = loam_mat
			tilled_patch.mesh = patch_mesh
			tilled_patch.position = grid.world_position(cell) + Vector3(0, 0.015, 0)
			farmland_container.add_child(tilled_patch)
			tilled_meshes[cell] = tilled_patch
		if dirt_puff != null:
			dirt_puff.position = grid.world_position(cell) + Vector3(0, 0.1, 0)
			dirt_puff.restart()
	elif event.kind == "water_soil":
		_discover("interaction.water_soil", "Soil revitalized: moisture and nutrients restored")
		hud.notify("Su verildi (-%d ml)! Kalan su: %d ml" % [interactions.WATER_PER_POUR, interactions.water_ml])
		if water_splash != null:
			water_splash.position = grid.world_position(cell) + Vector3(0, 0.15, 0)
			water_splash.restart()
		if planting != null:
			planting.water_ml = interactions.water_ml
	elif event.kind == "plant_sapling":
		_discover("interaction.plant_sapling", "Seed planted: will grow into a sapling")
		hud.notify("Tohum ekildi (-1 Tohum)! Büyümesi için su gerekiyor.")
		var seed_node = FOREST_SEED.instantiate()
		seed_node.position = grid.world_position(cell)
		$Vegetation.add_child(seed_node)
		trees[cell] = seed_node
		_update_or_create_crop_indicator(cell, "seed", 0.0)
		if planting != null:
			planting.seed_count = interactions.seeds
	elif event.kind == "harvest_crop":
		hud.notify("Mahsul temizlendi (+1 Tohum)")
		if trees.has(cell):
			trees[cell].queue_free()
			trees.erase(cell)
		if crop_indicators.has(cell):
			crop_indicators[cell].queue_free()
			crop_indicators.erase(cell)
		if planting != null:
			planting.seed_count = interactions.seeds
	elif event.kind == "sapling_removed":
		if trees.has(cell):
			trees[cell].queue_free()
			trees.erase(cell)
		if crop_indicators.has(cell):
			crop_indicators[cell].queue_free()
			crop_indicators.erase(cell)
		hud.notify("Sapling removed")
	elif event.kind == "log_cleared":
		if logs.has(cell):
			logs[cell].queue_free()
			logs.erase(cell)
		_discover("interaction.fallen_log", "A cleared log reopens the route")
	else:
		if trees.has(cell):
			trees[cell].queue_free()
			trees.erase(cell)
		if crop_indicators.has(cell):
			crop_indicators[cell].queue_free()
			crop_indicators.erase(cell)
		if cut_cells.has(cell) and objectives.record_mitigation(region_id):
			_discover("interaction.firebreak", "Cleared fuel breaks the fire path; shade is lost")
		hud.notify("Stump removed: fuel cleared and route open")
	_refresh_visuals()
	_update_hud()

func _refresh_visuals():
	terrain_renderer.update_state(grid)
	for i in range(grid.cells.size()):
		var data = grid.cells[i]
		var seed_cell = Vector2i(i % grid.SIZE, floori(float(i) / grid.SIZE))
		if data.get("pending_seeds", 0) > 0 and not seed_visuals.has(seed_cell):
			var drop = SEED_DROP.instantiate()
			drop.position = grid.world_position(seed_cell) + Vector3(0.55,0.05,0.55)
			drop.scale = Vector3.ONE * 2.0
			$Vegetation.add_child(drop)
			seed_visuals[seed_cell] = drop
		elif data.get("pending_seeds", 0) <= 0 and seed_visuals.has(seed_cell):
			seed_visuals[seed_cell].queue_free()
			seed_visuals.erase(seed_cell)
		var moisture_low = data.get("moisture_low", data.moisture)
		data.moisture_low = minf(moisture_low, data.moisture)
		if climate.weather == "rain" and moisture_low < 0.5 and data.moisture > moisture_low + 0.15:

			if $GridPlayer.cell.distance_to(Vector2i(i % grid.SIZE, floori(float(i) / grid.SIZE))) <= 2.5:
				objectives.observe_recovery(region_id)
		var low = data.get("recovery_low", 1.0)
		if data.health < low:
			data.recovery_low = data.health
		if low < 0.85 and data.health > low + 0.08:

			if $GridPlayer.cell.distance_to(Vector2i(i % grid.SIZE, floori(float(i) / grid.SIZE))) <= 2.5:
				objectives.observe_recovery(region_id)
			if not recovery_seen:
				recovery_seen = true
				_discover("flora.recovery", "Vegetation recovers in favorable weather")
		var cell = Vector2i(i % grid.SIZE, floori(float(i) / grid.SIZE))
		if data.tree and data.tree_state == "seed":
			var water_prog = clampf(1.0 - data.get("water_needed", 1.0), 0.0, 1.0)
			_update_or_create_crop_indicator(cell, "seed", water_prog)
		elif data.tree and data.tree_state == "sapling":
			_update_or_create_crop_indicator(cell, "sapling", clampf(data.tree_health, 0.0, 1.0))
			if trees.has(cell) and trees[cell].scene_file_path != null and trees[cell].scene_file_path.ends_with("forest_seed.tscn"):
				trees[cell].queue_free()
				trees.erase(cell)
				var sapling_node = FOREST_SAPLING.instantiate()
				sapling_node.position = grid.world_position(cell)
				$Vegetation.add_child(sapling_node)
				trees[cell] = sapling_node
		else:
			if crop_indicators.has(cell):
				crop_indicators[cell].queue_free()
				crop_indicators.erase(cell)
		if data.tree and data.get("planted", false) and data.tree_state != "stump":
			var young: bool = data.get("growth_age", 0.0) < planting.GROWTH_SECONDS
			if trees.has(cell) and trees[cell].has_method("update_growth") != young:
				trees[cell].queue_free()
				trees.erase(cell)
			if not trees.has(cell):
				register_vegetation_visual(cell, _vegetation_visual(data))
			if young:
				trees[cell].update_growth(data)
			elif not data.get("growth_discovered", false):
				data.growth_discovered = true
				_discover("flora.planted_growth", "A planted tree matured: new shade and habitat")
		if trees.has(cell) and data.tree_state in ["healthy", "dead"]:
			if trees[cell].has_method("set_health"):
				trees[cell].set_health(data.tree_health, data.tree_state == "dead", data.moisture, data.get("burned", false))
			if data.get("burned", false):
				_discover("flora.burned_tree", "Burned trees lose shade")
		if logs.has(cell) and not data.get("log", false):
			logs[cell].queue_free()
			logs.erase(cell)
	for cell in water_tiles.keys():
		var node: MeshInstance3D = water_tiles[cell]
		var data = grid.cells[cell.y * grid.SIZE + cell.x]
		var depth = float(data.get("water_depth", data.get("water_level", 0.0)))
		if depth < 0.12:
			node.visible = false
		else:
			node.visible = true
			node.scale = Vector3(clampf(0.6 + depth * 0.4, 0.6, 1.0), clampf(depth, 0.2, 1.0), clampf(0.6 + depth * 0.4, 0.6, 1.0))
			node.position.y = lerpf(-0.04, 0.02, depth)
	if effects != null:
		effects.update_state(grid, climate.weather)
	if ground_cover != null:
		ground_cover.update_state(grid)
	if forage_visuals != null:
		forage_visuals.update_state(grid)

func _update_hud():
	var safe = $GridPlayer.cell.distance_to(grid.start) <= 2.2
	hud.update_status(survival.health, survival.exposure, climate.temperature, climate.weather, climate.warming_pressure(), SaveManager.progression.knowledge, safe, interactions.target.x >= 0, interactions.seeds, interactions.water_ml)
	hud.set_environment_context(climate.fire_at($GridPlayer.cell), objectives.summary(), objectives.ready_for_clearing())
	hud.set_region(regions.region_name(region_id))
	hud.update_seeds(planting.seed_count)
	hud.update_survival(survival, climate.shade_at($GridPlayer.cell), _binding_label("eat"))
	if wet_indicator != null:
		wet_indicator.visible = survival.wetness >= 10.0
		wet_indicator.scale = Vector3.ONE * (0.8 + survival.wetness / 200.0)
	if previous_objective != objectives.summary():
		if not previous_objective.is_empty():
			hud.notify(objectives.summary())
		previous_objective = objectives.summary()
	# Keep the caption authoritative after legacy status/context updates.
	_update_interaction_marker()

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
	clearing.visible = region_id == "wetlands"
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
	landmark.visible = region_id == "wetlands"
	add_child(landmark)

# Presentation has its own clock: no changes to seeded climate or logical cells.
# The one light stays above the scene at night as cool moonlight, keeping shadows
# continuous across the cycle without a second shadow-casting light.
func _advance_presentation(delta: float):
	if not is_finite(delta) or delta <= 0.0:
		return
	presentation_elapsed += delta
	if has_node("Bonfire/Warmth"):
		$Bonfire/Warmth.light_energy = (0.45 + sin(presentation_elapsed * 6.0) * 0.06) * region_state.get("bonfire_intensity", 1.0)
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
		decorated_cells[cell] = true
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

func _request_region_transition(destination: String):
	if transitioning or get_tree().paused:
		return
	transitioning = true
	SceneFlow.region_transitioning = true
	$CameraRig._cancel_drag()
	SceneFlow.camera_state = $CameraRig.get_transition_state()
	$GridPlayer.set_process(false)
	context_action.cancel()
	if $GridPlayer/Body.has_method("stop_chopping"):
		$GridPlayer/Body.stop_chopping()
		$GridPlayer/Body.stop_farming()
	interactions.configure(grid)
	hud.notify("Trail to " + regions.region_name(destination))
	await get_tree().create_timer(0.20, false).timeout
	if is_inside_tree():
		SceneFlow.change_region(destination)

func _trail_marker(cell: Vector2i, title: String, color: Color) -> MeshInstance3D:
	var marker = MeshInstance3D.new()
	var mesh = CylinderMesh.new()
	mesh.top_radius = 0.72
	mesh.bottom_radius = 0.72
	mesh.height = 0.05
	mesh.radial_segments = 12
	marker.mesh = mesh
	var material = StandardMaterial3D.new()
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	marker.material_override = material
	marker.position = grid.world_position(cell) + Vector3(0,0.035,0)
	marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(marker)
	var label = Label3D.new()
	label.text = title
	label.font_size = 40
	label.pixel_size = 0.025
	label.position = Vector3(0,1.8,0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	marker.add_child(label)
	return marker

func _create_region_markers():
	for cell in [Vector2i(0,8),Vector2i(16,8)]:
		var destination: String = regions.exit_destination(region_id, cell)
		if not destination.is_empty():
			_trail_marker(cell, "To " + regions.region_name(destination), Color("c8b977"))
	if region_id == "wetlands":
		habitat_marker = _trail_marker(Vector2i(8,5), "Recovering habitat", Color("86c9b3"))
		var habitat_ring = TorusMesh.new()
		habitat_ring.inner_radius = 0.78
		habitat_ring.outer_radius = 0.85
		habitat_marker.mesh = habitat_ring
	interaction_marker = MeshInstance3D.new()
	var ring = TorusMesh.new()
	ring.inner_radius = 0.66
	ring.outer_radius = 0.79
	ring.rings = 16
	ring.ring_segments = 6
	interaction_ring = ring
	interaction_marker.mesh = ring
	var material = StandardMaterial3D.new()
	material.albedo_color = Color("edcf86")
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	interaction_marker.material_override = material
	interaction_marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(interaction_marker)

func _update_interaction_marker():
	var candidates = _interaction_candidates()
	selected_interaction = context_action.select(candidates, $GridPlayer.cell, $GridPlayer.facing)
	var display = selected_interaction
	var active_display = false
	if not context_action.active.is_empty():
		# Revalidate against current world descriptors, never a cached active target.
		display = {}
		for candidate in candidates:
			if candidate.id == context_action.active.id and candidate.get("available", true) and not context_action.select([candidate], $GridPlayer.cell, $GridPlayer.facing).is_empty():
				display = candidate
				active_display = true
				break
	interaction_marker.visible = not display.is_empty() and display.get("available", true) and not $GridPlayer.moving and not get_tree().paused
	if interaction_marker.visible:
		interaction_marker.position = grid.world_position(display.cell) + Vector3(0,0.12,0)
	hud.update_interaction(display, context_action.progress, active_display, _binding_label("interact"))

func _binding_label(action: String) -> String:
	var labels: PackedStringArray = []
	for code in SettingsManager.bindings.get(action, []):
		if code != 0:
			labels.append(SettingsManager.binding_text(code))
	return " / ".join(labels) if not labels.is_empty() else "Unbound"

func _descriptor(cell: Vector2i, kind: String, title: String, action: String, duration: float, available: bool = true, reason: String = "") -> Dictionary:
	return {"id": "%s:%d,%d:%s" % [region_id,cell.x,cell.y,kind], "cell": cell,
		"object_kind": kind, "name": title, "action": action, "duration": duration,
		"available": available, "reason": reason, "range": 1.0, "priority": 0}

func _interaction_candidates() -> Array:
	var candidates: Array = []
	var player = $GridPlayer.cell
	var camp = _descriptor(grid.start, "bonfire", "Bonfire", "Rest", 0.0)
	camp.range = 1.5
	camp.priority = 10
	candidates.append(camp)
	for cell in [player, player + Vector2i.UP, player + Vector2i.RIGHT, player + Vector2i.DOWN, player + Vector2i.LEFT]:
		if not grid.in_bounds(cell): continue
		var data = grid.cells[cell.y * grid.SIZE + cell.x]
		var burning: bool = data.get("burning", false)
		if data.get("pending_seeds", 0) > 0 and not (planting.seed_count >= planting.MAX_SEEDS and data.tree and data.tree_state == "stump"):
			candidates.append(_descriptor(cell, "seeds", "Seed Drop", "Collect Seeds", 0.8, not burning and planting.seed_count < planting.MAX_SEEDS, "Seed pouch full" if planting.seed_count >= planting.MAX_SEEDS else "Seeds are burning"))
		elif data.get("berry_bush", false):
			var availability: Dictionary = foraging.availability(cell)
			candidates.append(_descriptor(cell, "berries", "Berry Bush", "Harvest", 0.75, availability.available, availability.reason))
		elif data.get("terrain", "grass") == "water":
			var wet = data.get("water_level", 0.0) > 0.1
			candidates.append(_descriptor(cell, "water", "Pond", "Drink / Fill Bottle (%d/%d ml)" % [planting.water_ml, planting.MAX_WATER_ML], 0.8, wet, "Pond is dry" if not wet else ""))
		elif data.get("log", false):
			candidates.append(_descriptor(cell, "log", "Fallen Log", "Clear", 1.2 * SaveManager.get_chop_multiplier(), not burning, "Wood is burning" if burning else ""))
		elif data.tree:
			if data.tree_state == "sapling" and data.get("planted", false) and data.moisture < 0.65 and not burning:
				var water: Dictionary = planting.water_availability(grid, cell)
				candidates.append(_descriptor(cell, "water_plant", "Dry Sapling", "Water Plant (250 ml)", 0.8, water.available, water.reason))
				continue
			var juvenile: bool = interactions.is_juvenile(data)
			var title = ("Dead Sapling" if data.tree_state == "dead" else "Sapling") if juvenile else "Stump" if data.tree_state == "stump" else "Tree"
			candidates.append(_descriptor(cell, "tree", title, "Remove" if juvenile or data.tree_state == "stump" else "Chop", 1.2 * SaveManager.get_chop_multiplier(), not burning, "Tree is burning" if burning else ""))
		elif cell != player and data.terrain == "soil":
			var soil: Dictionary = planting.soil_availability(grid, cell, _planting_occupied(cell))
			if soil.available:
				if not data.get("prepared", false):
					candidates.append(_descriptor(cell, "prepare", "Bare Soil", "Prepare Soil", 0.8))
				else:
					var availability: Dictionary = planting.availability(grid, cell, _planting_occupied(cell))
					candidates.append(_descriptor(cell, "plant", "Prepared Soil", "Plant Seed", 1.0, availability.available, availability.reason))
	candidates.append_array(custom_interactables)
	return candidates

func _begin_context_action():
	if not context_action.active.is_empty(): return
	var selected: Dictionary = context_action.select(_interaction_candidates(), $GridPlayer.cell, $GridPlayer.facing)
	if selected.is_empty():
		hud.notify("No nearby interaction")
		return
	if not selected.get("available", true):
		hud.notify(selected.get("reason", "Unavailable"))
		return
	if selected.get("object_kind", "custom") in ["tree", "log"]:
		interactions.duration = selected.duration
		if not interactions.begin($GridPlayer.cell, selected.cell - $GridPlayer.cell): return
		if $GridPlayer/Body.has_method("start_chopping"):
			$GridPlayer/Body.start_chopping(to_global(grid.world_position(selected.cell)))
		audio_cue.emit("chop", $GridPlayer.position)
	if context_action.begin(selected, $GridPlayer.cell):
		var visual = $GridPlayer/Body
		var target = to_global(grid.world_position(selected.cell))
		match selected.object_kind:
			"prepare": visual.start_tilling(target)
			"water_plant": visual.start_watering(target)
			"water": visual.start_filling_water(target)
			"seeds": visual.start_gathering(target)
		_update_interaction_marker()

func _tick_context_action(delta: float):
	if context_action.active.is_empty():
		# Retain the small existing tree model API for external integrations/tests.
		var legacy = interactions.tick(delta, $GridPlayer.cell)
		if not legacy.is_empty(): _finish_interaction(legacy)
		return
	var active: Dictionary = context_action.active
	var kind: String = active.get("object_kind", "custom")
	if kind in ["prepare", "water_plant", "seeds"]:
		active.available = false
		for candidate in _interaction_candidates():
			if candidate.id == active.id:
				active.available = candidate.get("available", true)
				active.reason = candidate.get("reason", "Action no longer available")
				break
	if kind == "plant":
		var availability: Dictionary = planting.availability(grid, active.cell, _planting_occupied(active.cell))
		active.available = availability.available
		active.reason = availability.reason
	if kind in ["berries", "water", "tree", "log"]:
		var data = grid.cells[active.cell.y * grid.SIZE + active.cell.x]
		if kind == "berries":
			var availability: Dictionary = foraging.availability(active.cell)
			active.available = availability.available
			active.reason = availability.reason
		elif kind == "water":
			active.available = data.water_level > 0.1
			active.reason = "Pond is dry"
		else:
			active.available = not data.get("burning", false) and (data.tree if kind == "tree" else data.get("log", false))
			active.reason = "Wood is no longer safe to clear"
	var result: Dictionary = context_action.tick(delta, $GridPlayer.cell, get_tree().paused)
	var tree_event = interactions.tick(delta, $GridPlayer.cell) if kind in ["tree", "log"] else {}
	if result.is_empty(): return
	if $GridPlayer/Body.has_method("stop_chopping"):
		$GridPlayer/Body.stop_chopping()
		$GridPlayer/Body.stop_farming()
	if result.kind == "cancelled":
		interactions.configure(grid)
		hud.notify("Action cancelled")
		return
	if kind in ["tree", "log"]:
		if not tree_event.is_empty(): _finish_interaction(tree_event)
	elif kind == "prepare":
		if planting.prepare(grid, result.cell, _planting_occupied(result.cell)):
			hud.notify("Soil prepared: ready for a seed")
	elif kind == "water_plant":
		if planting.water_plant(grid, result.cell): hud.notify("Plant watered: bottle %d/%d ml" % [planting.water_ml,planting.MAX_WATER_ML])
	elif kind == "seeds":
		var collected: int = planting.collect_seed(grid, {"kind":"collect_seeds", "cell":result.cell})
		hud.notify("Collected %d seed" % collected)
	elif kind == "plant":
		if planting.plant(grid, result.cell, _planting_occupied(result.cell)):
			_discover("interaction.first_planting", "First seed planted: moisture and temperature support growth")
			hud.notify("Seed planted: seek moist soil for steady growth")
	elif kind == "bonfire":
		hud.show_modal("bonfire")
	elif kind == "berries":
		var amount: int = foraging.harvest(result.cell)
		survival.add_berries(amount)
		_discover("food.berry_bush", "Berry bushes supply food")
		_discover("food.first_harvest", "Food gathered for the journey")
		hud.notify("Harvested %d berries" % amount)
		audio_cue.emit("discovery", grid.world_position(result.cell))
	elif kind == "water":
		survival.drink()
		planting.fill_bottle(grid, result.cell)
		_discover("water.freshwater", "Freshwater source found")
		hud.notify("Freshwater: bottle %d/%d ml" % [planting.water_ml,planting.MAX_WATER_ML])
		audio_cue.emit("discovery", grid.world_position(result.cell))
	_refresh_visuals()
	_update_hud()

# Feature-owned extension points for additional contextual objects and visuals.
func register_interactable(descriptor: Dictionary) -> bool:
	if not descriptor.get("id") is String or descriptor.id.strip_edges().is_empty() or not descriptor.get("cell") is Vector2i or not grid.in_bounds(descriptor.cell):
		return false
	for existing in custom_interactables:
		if existing.id == descriptor.id: return false
	custom_interactables.append(descriptor)
	return true

func register_vegetation_visual(cell: Vector2i, visual: Node3D) -> bool:
	if not grid.in_bounds(cell) or visual == null or visual.get_parent() != null or trees.has(cell): return false
	visual.position = grid.world_position(cell)
	$Vegetation.add_child(visual)
	trees[cell] = visual
	return true

func _create_wet_indicator():
	wet_indicator = MeshInstance3D.new()
	wet_indicator.name = "WetIndicator"
	var ring = TorusMesh.new()
	ring.inner_radius = 0.33
	ring.outer_radius = 0.39
	ring.rings = 12
	ring.ring_segments = 4
	wet_indicator.mesh = ring
	var material = StandardMaterial3D.new()
	material.albedo_color = Color("79bcd6")
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	wet_indicator.material_override = material
	wet_indicator.position.y = 0.08
	wet_indicator.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	$GridPlayer.add_child(wet_indicator)

func _vegetation_visual(data: Dictionary) -> Node3D:
	if data.tree_state == "stump": return NatureProps.instantiate_stump()
	if data.get("planted", false) and data.get("growth_age", 0.0) < planting.GROWTH_SECONDS:
		var sprout = SAPLING.instantiate()
		return sprout
	var visual = TREE.instantiate()
	visual.variant = data.get("variant", 0) % 2
	return visual

func _planting_occupied(cell: Vector2i) -> bool:
	if cell == $GridPlayer.cell or decorated_cells.has(cell): return true
	for descriptor in custom_interactables:
		if descriptor.cell == cell: return true
	return false

func _tick_bonfire(seconds: float):
	var intensity: float = region_state.get("bonfire_intensity", 1.0)
	var exposure = 1.0 - climate.shade_at(grid.start) * 0.85
	intensity = clampf(intensity + (-0.02 * exposure if climate.weather == "rain" else 0.04) * seconds, 0.0, 1.0)
	region_state.bonfire_intensity = intensity
	_update_bonfire_visuals()

func _update_bonfire_visuals():
	var intensity: float = region_state.get("bonfire_intensity", 1.0)
	for i in range(3):
		var flame = get_node("Bonfire/Flame%d" % i)
		flame.visible = intensity > 0.0
		flame.scale = Vector3.ONE * (1.0 if i == 1 else 0.72) * lerpf(0.25, 1.0, intensity)
	$Bonfire/Smoke.emitting = intensity > 0.0
	$Bonfire/Warmth.light_energy = 0.5 * intensity


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

func _create_dirt_puff():
	dirt_puff = CPUParticles3D.new()
	dirt_puff.name = "DirtPuff"
	dirt_puff.emitting = false
	dirt_puff.one_shot = true
	dirt_puff.explosiveness = 0.95
	dirt_puff.amount = 16
	dirt_puff.lifetime = 0.4
	dirt_puff.direction = Vector3(0, 1, 0)
	dirt_puff.spread = 50.0
	dirt_puff.initial_velocity_min = 1.5
	dirt_puff.initial_velocity_max = 3.2
	dirt_puff.gravity = Vector3(0, -9.8, 0)
	var dirt_mat = StandardMaterial3D.new()
	dirt_mat.albedo_color = Color(0.24, 0.16, 0.10)
	dirt_mat.roughness = 0.95
	var lump = BoxMesh.new()
	lump.size = Vector3(0.04, 0.04, 0.04)
	lump.material = dirt_mat
	dirt_puff.mesh = lump
	add_child(dirt_puff)

func _update_or_create_crop_indicator(cell: Vector2i, type: String, progress_val: float):
	var indicator: Node3D
	if crop_indicators.has(cell):
		indicator = crop_indicators[cell]
	else:
		indicator = Node3D.new()
		indicator.set_script(CROP_INDICATOR)
		indicator.position = grid.world_position(cell) + Vector3(0, 0.85, 0)
		add_child(indicator)
		crop_indicators[cell] = indicator
	if indicator.has_method("update_state"):
		indicator.update_state(type, progress_val)

func _on_chop_impact(pos: Vector3):
	if wood_chips != null:
		wood_chips.position = pos
		wood_chips.restart()

func _on_till_impact(pos: Vector3):
	if dirt_puff != null:
		dirt_puff.position = pos
		dirt_puff.restart()

func _on_water_fill_splash(pos: Vector3):
	if water_splash != null:
		water_splash.position = pos
		water_splash.restart()

func _on_water_pour_splash(pos: Vector3):
	if water_splash != null:
		water_splash.position = pos
		water_splash.restart()
