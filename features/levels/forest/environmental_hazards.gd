extends Node3D

class Hazard:
	var id: int
	var type: String # "sandstorm" or "cold_air"
	var cell: Vector2i
	var visual: Node3D
	var move_timer: float = 0.0
	var move_interval: float = 4.0
	var tween: Tween = null

const HAZARD_COUNT = 3
const WANDER_INTERVAL = 4.0
const MOVE_DURATION = 2.5
const HAZARD_RADIUS = 1.1

var region_id: String = "forest"
var grid: RefCounted
var hazards: Array[Hazard] = []
var rng: RandomNumberGenerator

func configure(p_region_id: String, p_grid: RefCounted, p_world_seed: int) -> void:
	region_id = p_region_id
	grid = p_grid
	for h in hazards:
		if is_instance_valid(h.visual):
			h.visual.queue_free()
	hazards.clear()

	# Requirement 1: "İlk bölge forest bölgesi, burada kum fırtınası ya da çığ fırtınası oluşturma."
	if region_id == "forest" or (region_id != "drylands" and region_id != "wetlands"):
		return

	# Only drylands (sandstorm) and wetlands (cold_air) have roaming hazards
	var hazard_type = "sandstorm" if region_id == "drylands" else "cold_air"

	rng = RandomNumberGenerator.new()
	rng.seed = p_world_seed ^ 0x5A4D5

	# Pick random cells away from start, objective, recycle bin, and spaceship
	var candidates: Array[Vector2i] = []
	for z in range(2, grid.SIZE - 2):
		for x in range(2, grid.SIZE - 2):
			var c = Vector2i(x, z)
			if c.distance_to(grid.start) < 3.0 or c == grid.objective:
				continue
			if grid.SPACESHIP_CELLS.has(c) or c == grid.recycle_bin_cell:
				continue
			var data: Dictionary = grid.cells[z * grid.SIZE + x]
			if data.get("water", false) or data.get("terrain", "") == "water":
				continue
			candidates.append(c)

	# Shuffle candidates
	for i in range(candidates.size() - 1, 0, -1):
		var j = rng.randi_range(0, i)
		var tmp = candidates[i]
		candidates[i] = candidates[j]
		candidates[j] = tmp

	var spawn_count = mini(HAZARD_COUNT, candidates.size())
	for i in range(spawn_count):
		var spawn_cell = candidates[i]
		var h = Hazard.new()
		h.id = i
		h.type = hazard_type
		h.cell = spawn_cell
		h.move_interval = WANDER_INTERVAL + rng.randf_range(-0.5, 0.5)
		h.move_timer = rng.randf_range(0.0, 2.0) # Desynchronize movement
		h.visual = _create_visual(hazard_type, i)
		h.visual.position = grid.world_position(spawn_cell)
		add_child(h.visual)
		hazards.append(h)

func _process(delta: float) -> void:
	if hazards.is_empty() or grid == null:
		return
	for h in hazards:
		h.move_timer += delta
		if h.move_timer >= h.move_interval:
			h.move_timer = 0.0
			_step_hazard(h)

func _step_hazard(h: Hazard) -> void:
	# "Bu efektler, random bir şekilde yavaşça celler arasında gezsin ama sadece bitişiğinde olan cellere geçebilsin yavaşça(yukarısındaki, altındaki, sağındaki ya da solundaki cellere)"
	var neighbors: Array[Vector2i] = []
	for offset in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		var next = h.cell + offset
		if not grid.in_bounds(next):
			continue
		if next == grid.recycle_bin_cell or grid.SPACESHIP_CELLS.has(next):
			continue
		neighbors.append(next)

	if neighbors.is_empty():
		return

	var next_cell = neighbors[rng.randi_range(0, neighbors.size() - 1)] if rng != null else neighbors[0]
	h.cell = next_cell
	if is_inside_tree():
		if h.tween != null and h.tween.is_valid():
			h.tween.kill()
		h.tween = create_tween()
		var target_pos = grid.world_position(next_cell)
		h.tween.tween_property(h.visual, "position", target_pos, MOVE_DURATION).set_trans(Tween.TRANS_SINE)
	else:
		h.visual.position = grid.world_position(next_cell)

func is_cell_in_hazard(c: Vector2i) -> bool:
	for h in hazards:
		if h.cell == c:
			return true
	return false

func is_pos_in_hazard(global_pos: Vector3) -> bool:
	for h in hazards:
		if is_instance_valid(h.visual):
			var vpos = h.visual.global_position
			var dist_xz = Vector2(global_pos.x - vpos.x, global_pos.z - vpos.z).length()
			if dist_xz <= HAZARD_RADIUS:
				return true
		if grid != null:
			var cpos = grid.world_position(h.cell)
			var dist_cell = Vector2(global_pos.x - cpos.x, global_pos.z - cpos.z).length()
			if dist_cell <= HAZARD_RADIUS:
				return true
	return false

func get_hazard_cells() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for h in hazards:
		result.append(h.cell)
	return result

func _create_visual(type: String, idx: int) -> Node3D:
	var root_node = Node3D.new()
	root_node.name = "%s_%d" % [type.capitalize(), idx]
	root_node.add_to_group("environmental_hazards")

	if type == "sandstorm":
		_build_sandstorm_fx(root_node)
	else:
		_build_cold_air_fx(root_node)

	return root_node

func _build_sandstorm_fx(parent: Node3D) -> void:
	# Main swirling sand column
	var vortex = CPUParticles3D.new()
	vortex.name = "SandVortex"
	vortex.amount = 45
	vortex.lifetime = 2.4
	vortex.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	vortex.emission_box_extents = Vector3(0.7, 1.1, 0.7)
	vortex.direction = Vector3(0.4, 0.8, 0.2)
	vortex.spread = 45.0
	vortex.initial_velocity_min = 1.0
	vortex.initial_velocity_max = 2.2
	vortex.angular_velocity_min = 90.0
	vortex.angular_velocity_max = 240.0
	vortex.radial_accel_min = -0.4
	vortex.radial_accel_max = 1.2
	vortex.color = Color(0.88, 0.68, 0.38, 0.65)

	var puff_mesh = SphereMesh.new()
	puff_mesh.radius = 0.14
	puff_mesh.height = 0.28
	puff_mesh.radial_segments = 6
	puff_mesh.rings = 3
	var mat = StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.85, 0.62, 0.32, 0.55)
	puff_mesh.material = mat
	vortex.mesh = puff_mesh
	vortex.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	vortex.position = Vector3(0, 0.6, 0)
	parent.add_child(vortex)

	# Low swirling dust skirt
	var skirt = CPUParticles3D.new()
	skirt.name = "DustSkirt"
	skirt.amount = 20
	skirt.lifetime = 1.8
	skirt.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	skirt.emission_sphere_radius = 0.95
	skirt.gravity = Vector3(0.2, 0.1, 0.1)
	skirt.color = Color(0.78, 0.54, 0.26, 0.45)
	var skirt_mesh = SphereMesh.new()
	skirt_mesh.radius = 0.18
	skirt_mesh.height = 0.32
	skirt_mesh.radial_segments = 6
	skirt_mesh.rings = 3
	var skirt_mat = StandardMaterial3D.new()
	skirt_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	skirt_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	skirt_mat.albedo_color = Color(0.78, 0.54, 0.26, 0.4)
	skirt_mesh.material = skirt_mat
	skirt.mesh = skirt_mesh
	skirt.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	skirt.position = Vector3(0, 0.2, 0)
	parent.add_child(skirt)

	# Warm ambient dust light
	var light = OmniLight3D.new()
	light.name = "DustGlow"
	light.light_color = Color(0.95, 0.72, 0.35)
	light.light_energy = 0.4
	light.omni_range = 3.0
	light.shadow_enabled = false
	light.position = Vector3(0, 1.0, 0)
	parent.add_child(light)

func _build_cold_air_fx(parent: Node3D) -> void:
	# Cold air sinking mist vortex
	var mist = CPUParticles3D.new()
	mist.name = "ColdMist"
	mist.amount = 45
	mist.lifetime = 2.5
	mist.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	mist.emission_box_extents = Vector3(0.75, 1.0, 0.75)
	mist.direction = Vector3(0.1, -0.4, 0.1)
	mist.spread = 50.0
	mist.initial_velocity_min = 0.8
	mist.initial_velocity_max = 1.8
	mist.angular_velocity_min = 50.0
	mist.angular_velocity_max = 160.0
	mist.color = Color(0.78, 0.92, 1.0, 0.65)

	var puff_mesh = SphereMesh.new()
	puff_mesh.radius = 0.14
	puff_mesh.height = 0.28
	puff_mesh.radial_segments = 6
	puff_mesh.rings = 3
	var mat = StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.78, 0.92, 1.0, 0.5)
	puff_mesh.material = mat
	mist.mesh = puff_mesh
	mist.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mist.position = Vector3(0, 0.8, 0)
	parent.add_child(mist)

	# Floating ice flecks / snowflakes
	var snow = CPUParticles3D.new()
	snow.name = "IceFlecks"
	snow.amount = 25
	snow.lifetime = 2.2
	snow.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	snow.emission_box_extents = Vector3(0.8, 1.0, 0.8)
	snow.gravity = Vector3(0.05, -0.7, 0.05)
	snow.color = Color(0.95, 0.98, 1.0, 0.85)

	var snow_mesh = BoxMesh.new()
	snow_mesh.size = Vector3(0.045, 0.045, 0.045)
	var snow_mat = StandardMaterial3D.new()
	snow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	snow_mat.albedo_color = Color(0.95, 0.98, 1.0, 0.85)
	snow_mesh.material = snow_mat
	snow.mesh = snow_mesh
	snow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	snow.position = Vector3(0, 1.0, 0)
	parent.add_child(snow)

	# Frosty cyan light
	var light = OmniLight3D.new()
	light.name = "FrostGlow"
	light.light_color = Color(0.65, 0.88, 1.0)
	light.light_energy = 0.4
	light.omni_range = 3.0
	light.shadow_enabled = false
	light.position = Vector3(0, 1.0, 0)
	parent.add_child(light)
