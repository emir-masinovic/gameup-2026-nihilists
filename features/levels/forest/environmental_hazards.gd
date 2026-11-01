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
const TORNADO_HAZARD_RADIUS = 2.85

var region_id: String = "forest"
var grid: RefCounted
var hazards: Array[Hazard] = []
var rng: RandomNumberGenerator
var anim_time: float = 0.0

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

func update_planet_health(p_health: float) -> void:
	for h in hazards:
		var slow_factor = lerpf(1.0, 2.0, clampf((p_health - 50.0) / 40.0, 0.0, 1.0))
		h.move_interval = WANDER_INTERVAL * slow_factor

func _process(delta: float) -> void:
	if hazards.is_empty() or grid == null:
		return
	anim_time += delta
	for h in hazards:
		h.move_timer += delta
		if h.move_timer >= h.move_interval:
			h.move_timer = 0.0
			_step_hazard(h)
		if h.type == "sandstorm" and is_instance_valid(h.visual):
			_animate_tornado(h.visual, delta, h.id)

func _animate_tornado(visual: Node3D, delta: float, id: int) -> void:
	var funnel = visual.get_node_or_null("TornadoFunnel")
	if funnel == null:
		return
	var outer = funnel.get_node_or_null("OuterFunnel")
	if outer != null:
		outer.rotate_y(delta * 4.2)
	var inner = funnel.get_node_or_null("InnerFunnel")
	if inner != null:
		inner.rotate_y(delta * -6.5)
	var rings = funnel.get_node_or_null("SpiralRings")
	if rings != null:
		rings.rotate_y(delta * 3.0)
	var debris = funnel.get_node_or_null("DebrisSwirl")
	if debris != null:
		debris.rotate_y(delta * 4.8)
	# Continuous organic sway / precession
	var phase = anim_time * 2.4 + float(id) * 1.7
	funnel.rotation.x = sin(phase) * 0.07
	funnel.rotation.z = cos(phase * 0.85) * 0.07

func _step_hazard(h: Hazard) -> void:
	# Roam slowly between orthogonal adjacent cells (UP, DOWN, LEFT, RIGHT)
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
	if grid != null and not grid.in_bounds(c):
		return false
	for h in hazards:
		if h.type == "sandstorm":
			# Large tornado: affects center and all adjacent surrounding cells (3x3 footprint)
			var diff = (c - h.cell).abs()
			if diff.x <= 1 and diff.y <= 1:
				return true
		else:
			# Winter storm / cold air: single cell
			if h.cell == c:
				return true
	return false

func is_pos_in_hazard(global_pos: Vector3) -> bool:
	for h in hazards:
		var radius = TORNADO_HAZARD_RADIUS if h.type == "sandstorm" else HAZARD_RADIUS
		if is_instance_valid(h.visual):
			var vpos = h.visual.global_position
			var dist_xz = Vector2(global_pos.x - vpos.x, global_pos.z - vpos.z).length()
			if dist_xz <= radius:
				return true
		if grid != null:
			var cpos = grid.world_position(h.cell)
			var dist_cell = Vector2(global_pos.x - cpos.x, global_pos.z - cpos.z).length()
			if dist_cell <= radius:
				return true
	return false

func get_hazard_cells() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for h in hazards:
		if h.type == "sandstorm":
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					var nc = h.cell + Vector2i(dx, dy)
					if grid == null or grid.in_bounds(nc):
						if not result.has(nc):
							result.append(nc)
		else:
			if not result.has(h.cell):
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
	# Container for animated tornado funnel and rings
	var funnel_container = Node3D.new()
	funnel_container.name = "TornadoFunnel"
	parent.add_child(funnel_container)

	# 1. Outer funnel mesh (inverted truncated cone)
	var outer_mesh = CylinderMesh.new()
	outer_mesh.bottom_radius = 0.65
	outer_mesh.top_radius = 2.5
	outer_mesh.height = 5.4
	outer_mesh.radial_segments = 16
	outer_mesh.rings = 4
	outer_mesh.cap_top = false
	outer_mesh.cap_bottom = false
	var outer_mat = StandardMaterial3D.new()
	outer_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	outer_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	outer_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	outer_mat.albedo_color = Color(0.88, 0.67, 0.36, 0.32)
	outer_mesh.material = outer_mat

	var outer_instance = MeshInstance3D.new()
	outer_instance.name = "OuterFunnel"
	outer_instance.mesh = outer_mesh
	outer_instance.position = Vector3(0, 2.7, 0)
	outer_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	funnel_container.add_child(outer_instance)

	# 2. Inner core funnel (denser sand vortex column)
	var inner_mesh = CylinderMesh.new()
	inner_mesh.bottom_radius = 0.35
	inner_mesh.top_radius = 1.45
	inner_mesh.height = 5.0
	inner_mesh.radial_segments = 12
	inner_mesh.rings = 3
	inner_mesh.cap_top = false
	inner_mesh.cap_bottom = false
	var inner_mat = StandardMaterial3D.new()
	inner_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	inner_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	inner_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	inner_mat.albedo_color = Color(0.76, 0.52, 0.22, 0.44)
	inner_mesh.material = inner_mat

	var inner_instance = MeshInstance3D.new()
	inner_instance.name = "InnerFunnel"
	inner_instance.mesh = inner_mesh
	inner_instance.position = Vector3(0, 2.5, 0)
	inner_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	funnel_container.add_child(inner_instance)

	# 3. Spiral rings encircling the funnel at varying heights
	var rings_node = Node3D.new()
	rings_node.name = "SpiralRings"
	funnel_container.add_child(rings_node)

	var ring_data = [
		{"y": 0.6, "r": 0.90, "w": 0.10},
		{"y": 1.7, "r": 1.35, "w": 0.12},
		{"y": 2.9, "r": 1.80, "w": 0.14},
		{"y": 4.1, "r": 2.25, "w": 0.16},
		{"y": 5.1, "r": 2.60, "w": 0.18}
	]
	for idx in range(ring_data.size()):
		var rd = ring_data[idx]
		var torus = TorusMesh.new()
		torus.inner_radius = rd.r - rd.w
		torus.outer_radius = rd.r
		torus.rings = 16
		torus.ring_segments = 6
		var r_mat = StandardMaterial3D.new()
		r_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		r_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		r_mat.albedo_color = Color(0.92, 0.74, 0.44, 0.5)
		torus.material = r_mat

		var r_instance = MeshInstance3D.new()
		r_instance.name = "Ring_%d" % idx
		r_instance.mesh = torus
		r_instance.position = Vector3(0, rd.y, 0)
		r_instance.rotation.x = deg_to_rad(6.0 * (1 if idx % 2 == 0 else -1))
		r_instance.rotation.z = deg_to_rad(4.0 * (1 if idx % 2 == 1 else -1))
		r_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		rings_node.add_child(r_instance)

	# 4. Debris particles swirling around the tornado
	var debris = CPUParticles3D.new()
	debris.name = "DebrisSwirl"
	debris.amount = 25
	debris.lifetime = 1.9
	debris.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	debris.emission_box_extents = Vector3(1.4, 2.0, 1.4)
	debris.direction = Vector3(0.0, 1.0, 0.0)
	debris.spread = 35.0
	debris.initial_velocity_min = 2.0
	debris.initial_velocity_max = 4.5
	debris.tangential_accel_min = 5.0
	debris.tangential_accel_max = 9.0
	debris.color = Color(0.55, 0.38, 0.20, 0.75)
	var debris_mesh = BoxMesh.new()
	debris_mesh.size = Vector3(0.08, 0.08, 0.08)
	var debris_mat = StandardMaterial3D.new()
	debris_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	debris_mat.albedo_color = Color(0.55, 0.38, 0.20, 0.75)
	debris_mesh.material = debris_mat
	debris.mesh = debris_mesh
	debris.position = Vector3(0, 2.2, 0)
	debris.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	funnel_container.add_child(debris)

	# 5. Main swirling sand particle column (SandVortex)
	var vortex = CPUParticles3D.new()
	vortex.name = "SandVortex"
	vortex.amount = 65
	vortex.lifetime = 2.2
	vortex.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	vortex.emission_box_extents = Vector3(1.3, 2.2, 1.3)
	vortex.direction = Vector3(0.2, 1.0, 0.2)
	vortex.spread = 45.0
	vortex.initial_velocity_min = 2.0
	vortex.initial_velocity_max = 4.2
	vortex.angular_velocity_min = 120.0
	vortex.angular_velocity_max = 300.0
	vortex.radial_accel_min = 1.0
	vortex.radial_accel_max = 2.5
	vortex.tangential_accel_min = 4.0
	vortex.tangential_accel_max = 7.5
	vortex.color = Color(0.88, 0.68, 0.38, 0.68)

	var puff_mesh = SphereMesh.new()
	puff_mesh.radius = 0.16
	puff_mesh.height = 0.32
	puff_mesh.radial_segments = 6
	puff_mesh.rings = 3
	var mat = StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.85, 0.62, 0.32, 0.58)
	puff_mesh.material = mat
	vortex.mesh = puff_mesh
	vortex.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	vortex.position = Vector3(0, 2.2, 0)
	parent.add_child(vortex)

	# 6. Low wide swirling dust skirt covering multiple cells at ground level (DustSkirt)
	var skirt = CPUParticles3D.new()
	skirt.name = "DustSkirt"
	skirt.amount = 40
	skirt.lifetime = 2.0
	skirt.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	skirt.emission_sphere_radius = 2.4
	skirt.gravity = Vector3(0.1, 0.15, 0.1)
	skirt.initial_velocity_min = 0.7
	skirt.initial_velocity_max = 2.0
	skirt.tangential_accel_min = 3.0
	skirt.tangential_accel_max = 6.0
	skirt.color = Color(0.78, 0.54, 0.26, 0.48)
	var skirt_mesh = SphereMesh.new()
	skirt_mesh.radius = 0.22
	skirt_mesh.height = 0.42
	skirt_mesh.radial_segments = 6
	skirt_mesh.rings = 3
	var skirt_mat = StandardMaterial3D.new()
	skirt_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	skirt_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	skirt_mat.albedo_color = Color(0.78, 0.54, 0.26, 0.42)
	skirt_mesh.material = skirt_mat
	skirt.mesh = skirt_mesh
	skirt.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	skirt.position = Vector3(0, 0.25, 0)
	parent.add_child(skirt)

	# 7. Warm ambient dust light (DustGlow)
	var light = OmniLight3D.new()
	light.name = "DustGlow"
	light.light_color = Color(0.95, 0.72, 0.35)
	light.light_energy = 0.6
	light.omni_range = 5.0
	light.shadow_enabled = false
	light.position = Vector3(0, 1.5, 0)
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
