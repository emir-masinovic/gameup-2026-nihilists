extends Node3D
const Visuals = preload("res://features/levels/forest/nature/nature_visuals.gd")
var batches: Array[Dictionary] = []
var cracks: MultiMeshInstance3D
var _grid: RefCounted
var _crack_sizes: Array[float] = []
var _crack_targets: Array[float] = []

func configure(grid: RefCounted):
	_grid = grid
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
	var indices: Array[int] = []
	for i in range(grid.cells.size()):
		var cell = grid.cells[i]
		if cell.get("terrain", "grass") in ["water", "soil"]:
			continue
		if not shrubs or (cell.tree and cell.shade > 0.8):
			for slot in range(1 if shrubs else 4): indices.append(i)
	var renderer = MultiMeshInstance3D.new()
	renderer.name = "Shrubs" if shrubs else "Grass"
	renderer.multimesh = MultiMesh.new()
	renderer.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	renderer.multimesh.use_custom_data = true
	renderer.multimesh.mesh = source.mesh
	renderer.multimesh.instance_count = indices.size()
	renderer.material_override = source.material.duplicate()
	renderer.material_override.set_shader_parameter("instance_health", true)
	renderer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(renderer)
	var sizes: Array[float] = []
	sizes.resize(indices.size())
	sizes.fill(0.0)
	batches.append({"renderer": renderer, "indices": indices, "source": source.transform, "sizes":sizes, "targets":sizes.duplicate(), "vitality":sizes.duplicate(), "shrubs":shrubs})
	model.free()

func update_state(grid: RefCounted):
	for batch in batches:
		for j in range(batch.indices.size()):
			var i = batch.indices[j]
			var data = grid.cells[i]
			var vitality = minf(data.get("health", 1.0), data.get("moisture", 1.0) * 1.65)
			var visible_patch = data.terrain == "grass" and not data.get("burning", false) and (not data.get("burned", false) or data.get("burn_recovery", 0.0) >= 0.2)
			var threshold = 0.12 + fposmod(float(i*13+j*7)*0.618034,1.0)*0.62
			var coverage = smoothstep(threshold-0.12,threshold+0.12,vitality)
			batch.targets[j] = (0.65+vitality*0.65)*coverage if visible_patch else 0.0
			batch.vitality[j] = vitality
			batch.renderer.multimesh.set_instance_custom_data(j, Color(vitality, 0, 0, 1))
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
			var slot = j%4
			var offset = Vector3([-0.5,0.45,-0.4,0.48][slot],0.0,[-0.45,-0.4,0.48,0.5][slot])
			var base: Transform3D = batch.source
			base.basis = Basis(Vector3.UP,data.rotation+slot*1.7)*base.basis.scaled(Vector3.ONE*batch.sizes[j])
			base.origin = base.origin*batch.sizes[j] + _grid.world_position(cell)+offset
			batch.renderer.multimesh.set_instance_transform(j,base)
	for i in range(_grid.cells.size()):
		_crack_sizes[i] = lerpf(_crack_sizes[i],_crack_targets[i],blend)
		changing = changing or absf(_crack_sizes[i]-_crack_targets[i]) > 0.002
		var cell = Vector2i(i%_grid.SIZE,floori(float(i)/_grid.SIZE))
		var basis = Basis(Vector3.UP,_grid.cells[i].rotation).scaled(Vector3.ONE*_crack_sizes[i])
		cracks.multimesh.set_instance_transform(i,Transform3D(basis,_grid.world_position(cell)+Vector3(0,0.016,0)))
	if not changing: set_process(false)

func _build_cracks(grid: RefCounted):
	var mesh = ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var lines = [[Vector3(-0.8,0,-0.45),Vector3(-0.2,0,-0.12)],[Vector3(-0.2,0,-0.12),Vector3(0.05,0,0.28)],[Vector3(0.05,0,0.28),Vector3(0.7,0,0.65)],[Vector3(-0.2,0,-0.12),Vector3(0.42,0,-0.65)],[Vector3(0.05,0,0.28),Vector3(-0.5,0,0.7)]]
	for line in lines:
		var side = (line[1]-line[0]).cross(Vector3.UP).normalized()*0.035
		for point in [line[0]-side,line[0]+side,line[1]+side,line[0]-side,line[1]+side,line[1]-side]:
			mesh.surface_set_normal(Vector3.UP)
			mesh.surface_add_vertex(point)
	mesh.surface_end()
	cracks = MultiMeshInstance3D.new()
	cracks.name = "DryEarthCracks"
	cracks.multimesh = MultiMesh.new()
	cracks.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	cracks.multimesh.mesh = mesh
	cracks.multimesh.instance_count = grid.cells.size()
	var material = StandardMaterial3D.new()
	material.albedo_color = Color("30251c")
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	cracks.material_override = material
	cracks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(cracks)
	_crack_sizes.resize(grid.cells.size())
	_crack_targets.resize(grid.cells.size())
	_crack_sizes.fill(0.0)
	_crack_targets.fill(0.0)
