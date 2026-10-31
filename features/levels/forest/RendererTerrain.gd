extends Node3D
# Group tiles by their shared climate material: logical cells remain authoritative.
var batches: Array[MultiMeshInstance3D] = []
var tile_mesh: BoxMesh

func configure(grid: RefCounted, palette: Array[ShaderMaterial], water: Material, charred: Material):
	tile_mesh = BoxMesh.new()
	tile_mesh.size = Vector3(grid.CELL_SIZE, 0.3, grid.CELL_SIZE)
	var materials: Array[Material] = []
	materials.assign(palette)
	materials.append(water)
	materials.append(charred)
	for material in materials:
		var batch = MultiMeshInstance3D.new()
		batch.multimesh = MultiMesh.new()
		batch.multimesh.transform_format = MultiMesh.TRANSFORM_3D
		batch.multimesh.mesh = tile_mesh
		batch.multimesh.instance_count = grid.cells.size()
		batch.multimesh.visible_instance_count = 0
		batch.material_override = material
		add_child(batch)
		batches.append(batch)
	update_state(grid)

func update_state(grid: RefCounted):
	var counts: Array[int] = []
	counts.resize(batches.size())
	counts.fill(0)
	for i in range(grid.cells.size()):
		var data = grid.cells[i]
		var group = clampi(int(data.health * 3.99), 0, 3) * 4 + clampi(int(data.moisture * 3.99), 0, 3)
		if data.get("terrain", "grass") == "water" and data.get("water_level", 0.0) > 0.1:
			group = 16
		elif data.get("burned", false):
			group = 17
		var cell = Vector2i(i % grid.SIZE, floori(float(i) / grid.SIZE))
		var transform = Transform3D(Basis.IDENTITY, grid.world_position(cell) + Vector3(0,-0.15,0))
		batches[group].multimesh.set_instance_transform(counts[group], transform)
		counts[group] += 1
	for i in range(batches.size()):
		batches[i].multimesh.visible_instance_count = counts[i]

func rendered_cell_count() -> int:
	var total = 0
	for batch in batches:
		total += batch.multimesh.visible_instance_count
	return total
