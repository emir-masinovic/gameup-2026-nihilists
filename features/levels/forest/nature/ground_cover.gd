extends Node3D
const Visuals = preload("res://features/levels/forest/nature/nature_visuals.gd")
const GRASS_POPULATION_SCALE = 3
const GRASS_DENSITY = {"minimum":3,"maximum":11}
var occupied_cells: Dictionary = {}
var batches: Array[Dictionary] = []
var cracks: MultiMeshInstance3D
var _crack_batches: Array[Dictionary] = []
var _noise = FastNoiseLite.new()
var _appearance_seed = 0
var _patch_noise = FastNoiseLite.new()
var _detail_noise = FastNoiseLite.new()
var _grass_sites: Dictionary = {}
var generation_ms = 0.0
var update_ms = 0.0
var baseline = OS.is_debug_build() and OS.get_cmdline_user_args().has("--grass-baseline")
var lod_controller: Node
var _wind_texture: NoiseTexture2D
var grass_wind_multiplier = _debug_wind_multiplier()
var _quality = "Medium"
var _capacity_quality = "Medium"
var reconfigure_ms = 0.0
var _grid: RefCounted
var _crack_sizes: Array[float] = []
var _crack_targets: Array[float] = []

func _ready():
	var settings = get_node_or_null("/root/SettingsManager")
	if settings != null:
		_quality = settings.grass_density
		if _quality != "Off": _capacity_quality = _quality
		settings.graphics_changed.connect(_apply_density)

func _apply_density():
	var quality = get_node("/root/SettingsManager").grass_density
	if quality == _quality: return
	_quality = quality
	if _grid == null or batches.is_empty(): return
	var begin = Time.get_ticks_usec()
	if quality != "Off" and quality != _capacity_quality:
		var previous_material = batches[0].renderer.material_override
		var wind = {"direction":previous_material.get_shader_parameter("wind_direction"),"strength":previous_material.get_shader_parameter("wind_strength")/maxf(grass_wind_multiplier,0.001),"time":previous_material.get_shader_parameter("wind_time")}
		var exposure = previous_material.get_shader_parameter("wind_exposure")
		var origin = previous_material.get_shader_parameter("shelter_origin")
		if lod_controller != null:
			lod_controller.free()
			lod_controller = null
		batches.pop_front().renderer.free()
		_capacity_quality = quality
		_grass_sites.clear()
		_build(_grid,Visuals.instantiate_grass(),false)
		batches.push_front(batches.pop_back())
		update_state(_grid)
		_process(1.0)
		set_wind(wind)
		set_shelter(exposure,Vector3(origin.x,0,origin.y))
		_create_lod()
	batches[0].renderer.visible = quality != "Off"
	if lod_controller != null: lod_controller.set_process(quality != "Off")
	reconfigure_ms = (Time.get_ticks_usec()-begin)/1000.0

func _create_lod():
	if not baseline and not (OS.is_debug_build() and OS.get_cmdline_user_args().has("--grass-no-lod")):
		lod_controller = preload("res://features/levels/forest/nature/ControllerGrassLOD.gd").new()
		add_child(lod_controller)
		lod_controller.configure(self)

func configure(grid: RefCounted, occupied: Dictionary = {}):
	var begin = Time.get_ticks_usec()
	_grass_sites.clear()
	occupied_cells = occupied
	_grid = grid
	_appearance_seed = int(grid.cells[0].rotation*10000.0)
	_noise.seed = _appearance_seed
	_noise.frequency = 0.23
	_noise.fractal_octaves = 2
	_patch_noise.seed = _appearance_seed ^ 0x71A3
	_patch_noise.frequency = 0.075
	_detail_noise.seed = _appearance_seed ^ 0x3E19
	_detail_noise.frequency = 0.7
	_build(grid, Visuals.instantiate_grass(), false)
	_build(grid, Visuals.instantiate_shrub(), true)
	_build_cracks(grid)
	update_state(grid)
	_process(1.0)
	generation_ms = (Time.get_ticks_usec()-begin)/1000.0
	_create_lod()
	batches[0].renderer.visible = _quality != "Off"
	if lod_controller != null: lod_controller.set_process(_quality != "Off")

func _find_mesh(node: Node, parent_transform: Transform3D) -> Dictionary:
	var transform = parent_transform * node.transform if node is Node3D else parent_transform
	if node is MeshInstance3D:
		return {"mesh": node.mesh, "material": node.get_surface_override_material(0), "transform": transform}
	for child in node.get_children():
		var found = _find_mesh(child, transform)
		if not found.is_empty():
			return found
	return {}

func _build(grid: RefCounted, model: Node3D, shrubs: bool):
	var source = _find_mesh(model, Transform3D.IDENTITY)
	if not shrubs:
		source.mesh = _grass_tuft()
		source.transform = Transform3D.IDENTITY
	var indices: Array[int] = []
	for i in range(grid.cells.size()):
		var cell = grid.cells[i]
		if cell.get("terrain", "grass") in ["water", "soil"]:
			continue
		if not shrubs or (cell.tree and cell.shade > 0.8):
			var position = Vector2i(i%grid.SIZE,floori(float(i)/grid.SIZE))
			var cluster = (_noise.get_noise_2d(position.x,position.y)+1.0)*0.5
			for slot in range(1 if shrubs else clampi(GRASS_DENSITY.minimum+int(cluster*10.0),GRASS_DENSITY.minimum,GRASS_DENSITY.maximum)): indices.append(i)
	var placement: Array[Dictionary] = []
	if not shrubs:
		# Retain the old total capacity, not its per-tile layout.
		var budget = roundi(indices.size()*GRASS_POPULATION_SCALE * {"Low":3000.0/5298.0,"Medium":1.0,"High":8000.0/5298.0}[_capacity_quality])
		if OS.is_debug_build():
			for argument in OS.get_cmdline_user_args():
				if argument.begins_with("--grass-count="): budget = clampi(int(argument.get_slice("=",1)),1,20000)
		placement = _grass_placement(grid,budget)
		indices.clear()
		for candidate in placement: indices.append(candidate.index)
	var renderer = MultiMeshInstance3D.new()
	renderer.name = "Shrubs" if shrubs else "Grass"
	renderer.multimesh = MultiMesh.new()
	renderer.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	renderer.multimesh.use_custom_data = true
	renderer.multimesh.mesh = source.mesh
	renderer.multimesh.instance_count = indices.size()
	renderer.material_override = source.material.duplicate()
	renderer.material_override.set_shader_parameter("instance_health", true)
	renderer.material_override.set_shader_parameter("blade_grass",not shrubs)
	renderer.material_override.set_shader_parameter("sway",0.045 if shrubs else 0.24)
	renderer.material_override.set_shader_parameter("wind_height",0.3 if shrubs else 0.5)
	if not shrubs and not baseline:
		renderer.material_override.set_shader_parameter("view_thickening",0.35 if OS.is_debug_build() and OS.get_cmdline_user_args().has("--grass-thickening") and not OS.get_cmdline_user_args().has("--grass-no-thickening") else 0.0)
		if not OS.get_cmdline_user_args().has("--grass-no-perlin"):
			_wind_texture = NoiseTexture2D.new()
			_wind_texture.width = 128
			_wind_texture.height = 128
			_wind_texture.seamless = true
			var wind_noise = FastNoiseLite.new()
			wind_noise.noise_type = FastNoiseLite.TYPE_PERLIN
			wind_noise.fractal_type = FastNoiseLite.FRACTAL_NONE
			wind_noise.frequency = 0.055
			wind_noise.seed = _appearance_seed
			_wind_texture.noise = wind_noise
			renderer.material_override.set_shader_parameter("wind_field",_wind_texture)
			renderer.material_override.set_shader_parameter("spatial_wind_enabled",true)
	renderer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	renderer.extra_cull_margin = 0.7
	add_child(renderer)
	var sizes: Array[float] = []
	sizes.resize(indices.size())
	sizes.fill(0.0)
	var offsets: Array[Vector3] = []
	var rotations: Array[float] = []
	var variations: Array[float] = []
	var thresholds: Array[float] = []
	var bases: Array[Basis] = []
	var origins: Array[Vector3] = []
	var phases: Array[float] = []
	var crowding = _crowding(placement) if not shrubs else []
	var pending: Dictionary = {}
	var rng = RandomNumberGenerator.new()
	rng.seed = _appearance_seed ^ 0x48A17
	for j in range(indices.size()):
		var i = indices[j]
		var cell = Vector2i(i%grid.SIZE,floori(float(i)/grid.SIZE))
		var offset: Vector3 = placement[j].position-grid.world_position(cell) if not shrubs else Vector3.ZERO
		if shrubs:
			var key = i*37+_appearance_seed
			var anchor = Vector2(_sample(i*17)-0.5,_sample(i*29)-0.5)*0.65
			offset = Vector3(clampf(anchor.x+(_sample(key)-0.5)*1.8,-0.94,0.94),0,clampf(anchor.y+(_sample(key+13)-0.5)*1.8,-0.94,0.94))
		offsets.append(offset)
		rotations.append(_sample(i*37+_appearance_seed+31)*TAU if shrubs else rng.randf_range(0.0,TAU))
		variations.append(0.7+_sample(i*37+_appearance_seed+47)*0.65 if shrubs else rng.randf_range(0.7,1.35))
		var threshold = 0.1+(fposmod(float(i*13+j*7)*0.618034,1.0) if shrubs else rng.randf())*0.8
		if shrubs: rng.randf() # Preserve the existing seeded random stream.
		if j == 0 or indices[j-1] != i: threshold = 0.08+_sample(i+83)*0.04
		thresholds.append(threshold)
		bases.append(Basis(Vector3.UP,rotations[j])*source.transform.basis)
		origins.append(grid.world_position(cell)+offset)
		phases.append(_sample(i*37+j))
		pending[j] = true
	batches.append({"renderer": renderer, "indices": indices, "source": source.transform, "sizes":sizes, "targets":sizes.duplicate(), "vitality":sizes.duplicate(), "shrubs":shrubs,"offsets":offsets,"rotations":rotations,"variations":variations,"thresholds":thresholds,"bases":bases,"origins":origins,"phases":phases,"pending":pending,"cell_states":{},"crowding":crowding})
	model.free()

func update_state(grid: RefCounted):
	var begin = Time.get_ticks_usec()
	for batch in batches:
		var last_cell = -1
		var vitality = 0.0
		var visible_patch = false
		var changed = false
		for j in range(batch.indices.size()):
			var i = batch.indices[j]
			if i != last_cell:
				last_cell = i
				var data = grid.cells[i]
				vitality = minf(data.get("health",1.0),data.get("moisture",1.0)*1.65)
				var cell = Vector2i(i%grid.SIZE,i/grid.SIZE)
				var occupied = occupied_cells.has(cell) or cell == grid.start or data.tree or data.get("log",false) or data.get("berry_bush",false) or data.get("spaceship", false) or data.get("recycle_bin", false) or data.get("trash", false)
				var allowed = (data.tree and data.get("tree_state","healthy") != "stump" and not data.get("log",false)) if batch.shrubs else not occupied
				visible_patch = allowed and data.terrain == "grass" and not data.get("burning",false) and (not data.get("burned",false) or data.get("burn_recovery",0.0) >= 0.2)
				var signature = Vector2(vitality,1.0 if visible_patch else 0.0)
				changed = batch.cell_states.get(i,Vector2(-1,-1)) != signature
				batch.cell_states[i] = signature
			if not changed: continue
			var threshold: float = batch.thresholds[j]
			var coverage = smoothstep(threshold-0.08,threshold+0.08,vitality*vitality)
			batch.targets[j] = (0.65+vitality*0.65)*coverage*batch.variations[j] if visible_patch else 0.0
			if batch.sizes[j] != batch.targets[j]: batch.pending[j] = true
			if batch.vitality[j] != vitality:
				batch.vitality[j] = vitality
				batch.renderer.multimesh.set_instance_custom_data(j,Color(vitality,batch.phases[j],0.0 if batch.shrubs else batch.crowding[j]*vitality*vitality,1))
	for i in range(grid.cells.size()):
		var data = grid.cells[i]
		var bare_ground: bool = data.terrain == "grass" and not data.get("burned", false)
		# Dry cracks persist into early recovery, fading as real ground health returns.
		_crack_targets[i] = clampf((0.72-data.health)/0.45,0.0,1.0) * clampf((0.72-data.moisture)/0.45,0.0,1.0) if bare_ground else 0.0
	set_process(true)

	update_ms = (Time.get_ticks_usec()-begin)/1000.0

func _process(delta: float):
	if _grid == null: return
	var blend = 1.0-exp(-delta*7.0)
	var changing = false
	for batch in batches:
		for j in batch.pending.keys():
			var size = lerpf(batch.sizes[j],batch.targets[j],blend)
			if absf(size-batch.targets[j]) <= 0.002:
				size = batch.targets[j]
				batch.pending.erase(j)
			batch.sizes[j] = size
			var base = Transform3D(batch.bases[j].scaled(Vector3.ONE*size),batch.origins[j]+batch.source.origin*size)
			batch.renderer.multimesh.set_instance_transform(j,base)
		changing = changing or not batch.pending.is_empty()
	for batch in _crack_batches:
		for j in range(batch.indices.size()):
			var i: int = batch.indices[j]
			if _crack_sizes[i] == _crack_targets[i]: continue
			_crack_sizes[i] = lerpf(_crack_sizes[i],_crack_targets[i],blend)
			if absf(_crack_sizes[i]-_crack_targets[i]) <= 0.002: _crack_sizes[i] = _crack_targets[i]
			changing = changing or absf(_crack_sizes[i]-_crack_targets[i]) > 0.002
			var cell = Vector2i(i%_grid.SIZE,floori(float(i)/_grid.SIZE))
			var size = _crack_sizes[i]
			var basis = Basis(Vector3.UP,_grid.cells[i].rotation).scaled(Vector3(0.8+_sample(i+71)*0.2,1,0.7+_sample(i+93)*0.25)*size)
			var offset = Vector3((_sample(i+3)-0.5)*0.16,0.016,(_sample(i+7)-0.5)*0.16)
			batch.renderer.multimesh.set_instance_transform(j,Transform3D(basis,_grid.world_position(cell)+offset))
	if not changing: set_process(false)

func _sample(value: int) -> float:
	var n = (value+_appearance_seed)&0x7fffffff
	n = ((n^(n>>16))*0x45d9f3b)&0x7fffffff
	return float(n^(n>>16))/2147483647.0

func _build_cracks(grid: RefCounted):
	var patterns = [
		[Vector2(-0.8,-0.45),Vector2(-0.2,-0.12),Vector2(0.05,0.28),Vector2(0.7,0.65),Vector2(0.42,-0.65),Vector2(-0.5,0.7)],
		[Vector2(-0.7,0.5),Vector2(-0.25,0.15),Vector2(0.35,0.08),Vector2(0.8,-0.45),Vector2(-0.1,-0.75),Vector2(0.35,0.75)],
		[Vector2(-0.75,-0.15),Vector2(-0.1,0.1),Vector2(0.2,-0.3),Vector2(0.65,-0.75),Vector2(0.5,0.7),Vector2(-0.55,0.6)]]
	var material = StandardMaterial3D.new()
	material.albedo_color = Color("30251c")
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	for variant in range(3):
		var mesh = ImmediateMesh.new()
		mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
		var points = patterns[variant]
		for pair in [[0,1],[1,2],[2,3],[1,4],[2,5]]:
			var start = Vector3(points[pair[0]].x,0,points[pair[0]].y)
			var end = Vector3(points[pair[1]].x,0,points[pair[1]].y)
			var side = (end-start).cross(Vector3.UP).normalized()*(0.025+variant*0.008)
			for point in [start-side,start+side,end+side,start-side,end+side,end-side]:
				mesh.surface_set_normal(Vector3.UP)
				mesh.surface_add_vertex(point)
		mesh.surface_end()
		var renderer = MultiMeshInstance3D.new()
		renderer.name = "DryEarthCracks%d" % variant
		renderer.multimesh = MultiMesh.new()
		renderer.multimesh.transform_format = MultiMesh.TRANSFORM_3D
		renderer.multimesh.mesh = mesh
		var indices: Array[int] = []
		for i in range(grid.cells.size()):
			if mini(2,int(_sample(i+137)*3.0)) == variant: indices.append(i)
		renderer.multimesh.instance_count = indices.size()
		renderer.material_override = material
		renderer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(renderer)
		_crack_batches.append({"renderer":renderer,"indices":indices})
		if variant == 0: cracks = renderer
	_crack_sizes.resize(grid.cells.size())
	_crack_targets.resize(grid.cells.size())
	_crack_sizes.fill(0.0)
	_crack_targets.fill(0.0)

# Three tapered, segmented blades: shared by the existing clustered MultiMesh.
func _grass_tuft(segments: int = 3) -> ArrayMesh:
	var mesh = SurfaceTool.new()
	mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
	for blade in range(3):
		var angle = [0.12,2.2,4.48][blade]
		var direction = Vector3(cos(angle),0,sin(angle))
		var side = direction.cross(Vector3.UP)
		mesh.set_color(Color(direction.x*0.5+0.5,direction.z*0.5+0.5,float(blade)/2.0,1))
		var bend = [0.24,0.18,0.29][blade]
		var width = [0.045,0.04,0.05][blade]
		mesh.set_uv2(Vector2(width,bend))
		for segment in range(segments):
			var t0 = float(segment)/segments
			var t1 = float(segment+1)/segments
			var vertices = [Vector2(t0,-1),Vector2(t0,1),Vector2(t1,1)]
			if segment < segments-1: vertices.append_array([Vector2(t0,-1),Vector2(t1,1),Vector2(t1,-1)])
			for vertex in vertices:
				var t: float = vertex.x
				var center = Vector3.UP*t*0.5+direction*(0.03*t+bend*t*t)
				var tangent = (Vector3.UP*0.5+direction*(0.03+2.0*bend*t)).normalized()
				var face = side.cross(tangent).normalized()
				# Rounded cross-blade normals with an upward sky-light bias.
				mesh.set_normal((face*0.45+Vector3.UP*0.7+side*vertex.y*0.35).normalized())
				mesh.set_uv(Vector2((vertex.y+1.0)*0.5,t))
				mesh.add_vertex(center+side*vertex.y*pow(1.0-t,0.9)*width)
	if not baseline: mesh.index()
	return mesh.commit()

func set_wind(state: Dictionary):
	var direction: Vector2 = state.direction
	if direction.length_squared() < 0.000001: direction = Vector2.RIGHT
	for batch in batches:
		var material = batch.renderer.material_override
		material.set_shader_parameter("wind_direction",direction)
		material.set_shader_parameter("wind_strength",state.strength * grass_wind_multiplier if batch.renderer.name == "Grass" else state.strength)
		material.set_shader_parameter("wind_time",state.time)

# Generation-only, continuous world-space density. One jittered candidate per
# fine stratum; weighted sampling keeps the budget fixed without tile quotas.
func _grass_placement(grid: RefCounted, budget: int) -> Array[Dictionary]:
	var rng = RandomNumberGenerator.new()
	rng.seed = _appearance_seed ^ 0x597B
	var first: Vector3 = grid.world_position(Vector2i.ZERO)
	var edge = Vector2(first.x,first.z)-Vector2.ONE*grid.CELL_SIZE*0.5
	var extent = grid.SIZE*grid.CELL_SIZE
	var steps = maxi(ceili(extent/(0.45/sqrt(float(GRASS_POPULATION_SCALE)))),ceili(sqrt(float(budget)*2.0)))
	var spacing = extent/steps
	var candidates: Array[Dictionary] = []
	for z in range(steps):
		for x in range(steps):
			var point = edge+Vector2(x+rng.randf(),z+rng.randf())*spacing
			var cell = Vector2i(floori((point.x-edge.x)/grid.CELL_SIZE),floori((point.y-edge.y)/grid.CELL_SIZE))
			var index = cell.y*grid.SIZE+cell.x
			if grid.cells[index].terrain != "grass": continue
			var density = grass_density_at(point)
			var priority = -log(maxf(rng.randf(),0.000001))/density
			candidates.append({"position":Vector3(point.x,0,point.y),"index":index,"priority":priority})
	candidates.sort_custom(func(a,b): return a.priority < b.priority)
	candidates.resize(mini(budget,candidates.size()))
	candidates.sort_custom(func(a,b): return a.index < b.index or (a.index == b.index and a.priority < b.priority))
	return candidates

func grass_density_at(point: Vector2) -> float:
	const PATCH_SIZE = 4.2
	var lattice = Vector2i(floori(point.x/PATCH_SIZE),floori(point.y/PATCH_SIZE))
	var nearest = INF
	for z in range(-1,2):
		for x in range(-1,2):
			var key = lattice+Vector2i(x,z)
			if not _grass_sites.has(key):
				var rng = RandomNumberGenerator.new()
				rng.seed = hash(key) ^ _appearance_seed ^ 0x63B21
				_grass_sites[key] = (Vector2(key)+Vector2(rng.randf(),rng.randf()))*PATCH_SIZE
			nearest = minf(nearest,point.distance_to(_grass_sites[key]))
	var cellular = 1.0-smoothstep(0.25,0.9,nearest/PATCH_SIZE)
	var broad = smoothstep(-0.35,0.35,_patch_noise.get_noise_2d(point.x,point.y))
	var detail = 0.8+0.2*_detail_noise.get_noise_2d(point.x,point.y)
	return 0.02+pow(lerpf(broad,cellular,0.65),2.0)*detail

func set_shelter(values: PackedVector4Array, origin: Vector3):
	for batch in batches:
		var material = batch.renderer.material_override
		material.set_shader_parameter("wind_exposure",values)
		material.set_shader_parameter("shelter_origin",Vector2(origin.x,origin.z))
		material.set_shader_parameter("shelter_enabled",true)

# Generation-only spatial bins: approximate overlapping-tuft ambient occlusion.
# Fixed placements remain cached; climate thinning scales this proxy at refresh.
func _crowding(placement: Array[Dictionary]) -> Array[float]:
	var bins: Dictionary = {}
	for candidate in placement:
		var key = Vector2i(floori(candidate.position.x/0.65),floori(candidate.position.z/0.65))
		if not bins.has(key): bins[key] = []
		bins[key].append(candidate.position)
	var values: Array[float] = []
	for candidate in placement:
		var point: Vector3 = candidate.position
		var key = Vector2i(floori(point.x/0.65),floori(point.z/0.65))
		var overlap = 0.0
		for z in range(-1,2):
			for x in range(-1,2):
				for other in bins.get(key+Vector2i(x,z),[]):
					var distance = point.distance_to(other)
					if distance > 0.001: overlap += maxf(0.0,1.0-distance/0.65)
		values.append(clampf(overlap/3.0,0.0,1.0))
	return values

# Rendering-only diagnostic. Never alters the shared climate/wind state.
static func _debug_wind_multiplier() -> float:
	if OS.is_debug_build():
		for argument in OS.get_cmdline_user_args():
			if argument.begins_with("--grass-wind-multiplier="):
				var value = argument.get_slice("=",1)
				return _parse_wind_multiplier(value)
	return 1.0

static func _parse_wind_multiplier(value: String) -> float:
	return clampf(float(value),0.0,3.0) if value.is_valid_float() and is_finite(float(value)) else 1.0
