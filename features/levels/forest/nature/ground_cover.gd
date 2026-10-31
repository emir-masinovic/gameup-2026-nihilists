extends Node3D
const Visuals = preload("res://features/levels/forest/nature/nature_visuals.gd")
const GRASS_DENSITY = {"minimum":3,"maximum":11}
var occupied_cells: Dictionary = {}
var batches: Array[Dictionary] = []
var cracks: MultiMeshInstance3D
var _crack_batches: Array[Dictionary] = []
var _noise = FastNoiseLite.new()
var _appearance_seed = 0
var _grid: RefCounted
var _crack_sizes: Array[float] = []
var _crack_targets: Array[float] = []

func configure(grid: RefCounted, occupied: Dictionary = {}):
	occupied_cells = occupied
	_grid = grid
	_appearance_seed = int(grid.cells[0].rotation*10000.0)
	_noise.seed = _appearance_seed
	_noise.frequency = 0.23
	_noise.fractal_octaves = 2
	_build(grid, Visuals.instantiate_grass(), false)
	_build(grid, Visuals.instantiate_shrub(), true)
	_build_cracks(grid)
	update_state(grid)
	_process(1.0)

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
	var renderer = MultiMeshInstance3D.new()
	renderer.name = "Shrubs" if shrubs else "Grass"
	renderer.multimesh = MultiMesh.new()
	renderer.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	renderer.multimesh.use_custom_data = true
	renderer.multimesh.mesh = source.mesh
	renderer.multimesh.instance_count = indices.size()
	renderer.material_override = source.material.duplicate()
	renderer.material_override.set_shader_parameter("instance_health", true)
	renderer.material_override.set_shader_parameter("sway",0.045 if shrubs else 0.24)
	renderer.material_override.set_shader_parameter("wind_height",0.3 if shrubs else 0.5)
	renderer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(renderer)
	var sizes: Array[float] = []
	sizes.resize(indices.size())
	sizes.fill(0.0)
	var offsets: Array[Vector3] = []
	var rotations: Array[float] = []
	var variations: Array[float] = []
	var last_cell = -1
	var slot = 0
	for i in indices:
		slot = slot+1 if i == last_cell else 0
		last_cell = i
		var key = i*37+slot*101+_appearance_seed
		var anchor = Vector2(_sample(i*17)-0.5,_sample(i*29)-0.5)*0.65
		offsets.append(Vector3(clampf(anchor.x+(_sample(key)-0.5)*1.8,-0.94,0.94),0,clampf(anchor.y+(_sample(key+13)-0.5)*1.8,-0.94,0.94)))
		rotations.append(_sample(key+31)*TAU)
		variations.append(0.7+_sample(key+47)*0.65)
	batches.append({"renderer": renderer, "indices": indices, "source": source.transform, "sizes":sizes, "targets":sizes.duplicate(), "vitality":sizes.duplicate(), "shrubs":shrubs,"offsets":offsets,"rotations":rotations,"variations":variations})
	model.free()

func update_state(grid: RefCounted):
	for batch in batches:
		for j in range(batch.indices.size()):
			var i = batch.indices[j]
			var data = grid.cells[i]
			var vitality = minf(data.get("health", 1.0), data.get("moisture", 1.0) * 1.65)
			var cell = Vector2i(i%grid.SIZE,floori(float(i)/grid.SIZE))
			var occupied = occupied_cells.has(cell) or cell == grid.start or data.tree or data.get("log",false) or data.get("berry_bush",false)
			var allowed = (data.tree and data.get("tree_state","healthy") != "stump" and not data.get("log",false)) if batch.shrubs else not occupied
			var visible_patch = allowed and data.terrain == "grass" and not data.get("burning", false) and (not data.get("burned", false) or data.get("burn_recovery", 0.0) >= 0.2)
			var threshold = 0.1 + fposmod(float(i*13+j*7)*0.618034,1.0)*0.8
			# A small founding shoot precedes the denser surrounding cluster.
			if j == 0 or batch.indices[j-1] != i: threshold = 0.08 + _sample(i+83)*0.04
			var coverage = smoothstep(threshold-0.08,threshold+0.08,vitality*vitality)
			batch.targets[j] = (0.65+vitality*0.65)*coverage*batch.variations[j] if visible_patch else 0.0
			batch.vitality[j] = vitality
			batch.renderer.multimesh.set_instance_custom_data(j, Color(vitality, _sample(i*37+j), vitality, 1))
	for i in range(grid.cells.size()):
		var data = grid.cells[i]
		var bare_ground: bool = data.terrain == "grass" and not data.get("burned", false)
		# Dry cracks persist into early recovery, fading as real ground health returns.
		_crack_targets[i] = clampf((0.72-data.health)/0.45,0.0,1.0) * clampf((0.72-data.moisture)/0.45,0.0,1.0) if bare_ground else 0.0
	set_process(true)

func _process(delta: float):
	if _grid == null: return
	var blend = 1.0-exp(-delta*7.0)
	var changing = false
	for batch in batches:
		for j in range(batch.indices.size()):
			var i = batch.indices[j]
			batch.sizes[j] = lerpf(batch.sizes[j],batch.targets[j],blend)
			changing = changing or absf(batch.sizes[j]-batch.targets[j]) > 0.002
			var data = _grid.cells[i]
			var cell = Vector2i(i%_grid.SIZE,floori(float(i)/_grid.SIZE))
			var offset: Vector3 = batch.offsets[j]
			var base: Transform3D = batch.source
			base.basis = Basis(Vector3.UP,batch.rotations[j])*base.basis.scaled(Vector3.ONE*batch.sizes[j])
			base.origin = base.origin*batch.sizes[j] + _grid.world_position(cell)+offset
			batch.renderer.multimesh.set_instance_transform(j,base)
	for batch in _crack_batches:
		for j in range(batch.indices.size()):
			var i: int = batch.indices[j]
			_crack_sizes[i] = lerpf(_crack_sizes[i],_crack_targets[i],blend)
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
func _grass_tuft() -> ArrayMesh:
	var mesh = SurfaceTool.new()
	mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
	for blade in range(3):
		var direction = Vector3(cos(blade*2.094),0,sin(blade*2.094))
		var side = direction.cross(Vector3.UP)
		for segment in range(3):
			var t0 = float(segment)/3.0
			var t1 = float(segment+1)/3.0
			var start = Vector3.UP*t0*0.5+direction*t0*t0*0.13
			var end = Vector3.UP*t1*0.5+direction*t1*t1*0.13
			var a = side*(1.0-t0)*0.045
			var b = side*(1.0-t1)*0.045
			for point in [start-a,start+a,end+b,start-a,end+b,end-b]:
				mesh.set_normal(direction)
				mesh.add_vertex(point)
	return mesh.commit()

func set_wind(state: Dictionary):
	for batch in batches:
		var material = batch.renderer.material_override
		material.set_shader_parameter("wind_direction",state.direction)
		material.set_shader_parameter("wind_strength",state.strength)
		material.set_shader_parameter("wind_time",state.time)
