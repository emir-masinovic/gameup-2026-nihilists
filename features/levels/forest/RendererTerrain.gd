extends Node3D
# Shared climate beds, persistent authored soil and shrinking pond surfaces.
var batches: Array[MultiMeshInstance3D] = []
var tile_mesh: BoxMesh

func configure(grid: RefCounted, palette: Array[ShaderMaterial], water: Material, charred: Material):
	tile_mesh = BoxMesh.new()
	tile_mesh.size = Vector3(grid.CELL_SIZE, 0.3, grid.CELL_SIZE)
	var water_mesh = PlaneMesh.new()
	water_mesh.size = Vector2.ONE * grid.CELL_SIZE
	var materials: Array[Material] = []
	materials.assign(palette)
	materials.append(water)
	materials.append(charred)
	# Generated soil cells retain brown earth even when climate health is high.
	# This is terrain presentation, independent of selection, inventory and player.
	var soil = palette[0].duplicate()
	soil.set_shader_parameter("terrain_color", Color("554636"))
	soil.set_shader_parameter("terrain_health", 0.0)
	materials.append(soil)
	for i in range(materials.size()):
		var batch = MultiMeshInstance3D.new()
		batch.multimesh = MultiMesh.new()
		batch.multimesh.transform_format = MultiMesh.TRANSFORM_3D
		batch.multimesh.mesh = water_mesh if i == 16 else tile_mesh
		batch.multimesh.instance_count = grid.cells.size()
		batch.multimesh.visible_instance_count = 0
		batch.material_override = materials[i]
		# Coplanar ground must receive tree shadows without casting self-shadow acne.
		batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# Empty climate groups can become visible far from the origin later. A fixed
		# bounded world box avoids stale empty MultiMesh culling bounds on that tick.
		var first: Vector3 = grid.world_position(Vector2i.ZERO)
		batch.custom_aabb = AABB(first + Vector3(-grid.CELL_SIZE * 0.5, -0.4, -grid.CELL_SIZE * 0.5), Vector3(grid.SIZE * grid.CELL_SIZE, 0.7, grid.SIZE * grid.CELL_SIZE))
		add_child(batch)
		batches.append(batch)
	update_state(grid)

static func water_surface_scale(level: float) -> float:
	# Surface area follows remaining water above the same .1 movement threshold.
	return sqrt(clampf((level - 0.1) / 0.9, 0.0, 1.0))

func update_state(grid: RefCounted):
	var counts: Array[int] = []
	counts.resize(batches.size())
	counts.fill(0)
	for i in range(grid.cells.size()):
		var data = grid.cells[i]
		var health: float = data.health
		var moisture: float = data.moisture
		var pond: bool = data.get("terrain", "grass") == "water"
		if pond:
			# Every pond has a visible exposed soil bed, including when fully dry.
			health = 0.0
			moisture = minf(moisture, 0.49)
		var group = clampi(int(health * 3.99), 0, 3) * 4 + clampi(int(moisture * 3.99), 0, 3)
		var cell = Vector2i(i % grid.SIZE, floori(float(i) / grid.SIZE))
		if data.get("terrain", "grass") == "soil" and cell.distance_to(grid.start) >= 2.5 and cell.x != grid.start.x and cell.y != grid.start.y:
			group = 18
		if data.get("burned", false) and data.get("burn_recovery", 0.0) < 0.2:
			group = 17
		var at: Vector3 = grid.world_position(cell)
		batches[group].multimesh.set_instance_transform(counts[group], Transform3D(Basis.IDENTITY, at + Vector3(0,-0.15,0)))
		counts[group] += 1
		var water_scale = water_surface_scale(data.get("water_level", 0.0)) if pond else 0.0
		if water_scale > 0.0:
			batches[16].multimesh.set_instance_transform(counts[16], Transform3D(Basis.IDENTITY.scaled(Vector3(water_scale, 1.0, water_scale)), at + Vector3(0,0.012,0)))
			counts[16] += 1
	for i in range(batches.size()):
		batches[i].multimesh.visible_instance_count = counts[i]

func rendered_cell_count() -> int:
	var total = 0
	for i in range(batches.size()):
		if i != 16:
			total += batches[i].multimesh.visible_instance_count
	return total
