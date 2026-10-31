extends Node3D
const Visuals = preload("res://features/levels/forest/nature/nature_visuals.gd")
var batches: Array[Dictionary] = []

func configure(grid: RefCounted):
	_build(grid, Visuals.instantiate_grass(), false)
	_build(grid, Visuals.instantiate_shrub(), true)
	update_state(grid)

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
		if cell.get("terrain", "grass") == "water":
			continue
		if (shrubs and cell.tree and cell.shade > 0.8) or (not shrubs and not cell.tree and cell.shade > 0.5 and cell.shade < 0.6):
			indices.append(i)
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
	batches.append({"renderer": renderer, "indices": indices, "source": source.transform})
	model.free()

func update_state(grid: RefCounted):
	for batch in batches:
		for j in range(batch.indices.size()):
			var i = batch.indices[j]
			var data = grid.cells[i]
			var cell = Vector2i(i % grid.SIZE, floori(float(i) / grid.SIZE))
			var vitality = minf(data.get("health", 1.0), 0.25 + data.get("moisture", 1.0) * 1.1)
			var visible_patch = not data.get("burning", false) and (not data.get("burned", false) or data.get("burn_recovery", 0.0) >= 0.2)
			# Stable thinning follows actual condition, and reverses as ground recovers.
			visible_patch = visible_patch and fmod(float(i) * 0.618034, 1.0) < vitality
			var size_value = (0.3 + 0.7 * vitality) if visible_patch else 0.0
			batch.renderer.multimesh.set_instance_custom_data(j, Color(vitality, 0, 0, 1))
			var base: Transform3D = batch.source
			base.basis = Basis(Vector3.UP, data.rotation) * base.basis.scaled(Vector3.ONE * size_value)
			base.origin += grid.world_position(cell) + Vector3(0.5,0,-0.45)
			batch.renderer.multimesh.set_instance_transform(j, base)
