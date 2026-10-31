extends SceneTree

var checks = 0
var failures = 0

func check(value: bool, message: String):
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func _initialize():
	call_deferred("run")

func run():
	var GridData = load("res://features/levels/forest/grid_data.gd")
	var ClimateSimulation = load("res://features/levels/forest/climate_simulation.gd")
	
	# 1. Grid water generation tests
	var grid = GridData.new()
	grid.generate(2026)
	
	var water_cells: Array[Vector2i] = []
	for z in range(grid.SIZE):
		for x in range(grid.SIZE):
			var cell = Vector2i(x, z)
			var data = grid.cells[z * grid.SIZE + x]
			if data.get("water", false):
				water_cells.append(cell)
	
	check(water_cells.size() > 0, "Water / lake cells generated in grid")
	check(not grid.cells[grid.start.y * grid.SIZE + grid.start.x].get("water", false), "Spawn is not water")
	check(not grid.cells[grid.objective.y * grid.SIZE + grid.objective.x].get("water", false), "Objective is not water")
	check(grid.traversable(grid.start), "Spawn cell is traversable")
	check(grid.traversable(grid.objective), "Objective cell is traversable")
	
	var sample_water = water_cells[0]
	check(not grid.traversable(sample_water), "Full water cell is impassable")
	
	# 2. Climate & lakebed dynamics
	var climate = ClimateSimulation.new()
	climate.configure(grid, 2026)
	
	check(climate.water_proximity(sample_water) > 0.5, "High water proximity inside lake")
	
	# Proximity cooling
	var neighbor_tested = false
	for offset in [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]:
		var neighbor = sample_water + offset
		if grid.in_bounds(neighbor) and not grid.cells[neighbor.y * grid.SIZE + neighbor.x].get("water", false):
			var prox = climate.water_proximity(neighbor)
			check(prox > 0.0, "Lake provides evaporative cooling to adjacent land")
			check(climate.shade_at(neighbor) >= prox * 0.4, "Water cooling integrates into shade calculation")
			neighbor_tested = true
			break
	check(neighbor_tested, "Adjacent land tile tested for lake proximity")
	
	# Evaporation & dried lakebed passability
	var sample_data = grid.cells[sample_water.y * grid.SIZE + sample_water.x]
	sample_data.water_depth = 0.20
	check(grid.traversable(sample_water), "Dried lakebed (depth <= 0.25) becomes traversable")
	
	# Refill & restored barrier
	sample_data.water_depth = 0.85
	check(not grid.traversable(sample_water), "Refilled lake (depth > 0.25) acts as impassable barrier")
	
	# 3. Dynamic simulation ticks (evaporation vs rain refill)
	while climate.weather != "heat":
		climate.tick(1.0)
	var depth_before = sample_data.water_depth
	for i in range(15):
		climate.tick(1.0)
	check(sample_data.water_depth < depth_before, "Heatwave causes water to evaporate and water level to drop")
	
	while climate.weather != "rain":
		climate.tick(1.0)
	depth_before = sample_data.water_depth
	for i in range(15):
		climate.tick(1.0)
	check(sample_data.water_depth > depth_before, "Rain refills water level")
	
	# 4. Presentation & visual mesh updates
	var flow = root.get_node("SceneFlow")
	flow.next_seed = 2026
	var world = load("res://features/levels/forest/forest_level.tscn").instantiate()
	root.add_child(world)
	world.set_process(false)
	
	var water_container = world.get_node_or_null("Water")
	check(water_container != null, "ForestLevel contains dedicated Water node container")
	check(world.water_tiles.size() == water_cells.size(), "Water tiles dictionary matches generated lake cells")
	
	var water_mesh: MeshInstance3D = world.water_tiles[sample_water]
	check(water_mesh.visible, "Water mesh is initially visible")
	
	# Test visual drying
	sample_data = world.grid.cells[sample_water.y * world.grid.SIZE + sample_water.x]
	sample_data.water_depth = 0.05
	world._refresh_visuals()
	check(not water_mesh.visible, "Drying hides water mesh to reveal dried lakebed ground")
	
	sample_data.water_depth = 1.0
	world._refresh_visuals()
	check(water_mesh.visible, "Refilling restores water mesh visibility")
	
	world.free()
	
	print("WATER CLIMATE TEST: ", checks, " checks, ", failures, " failures")
	quit(0 if failures == 0 else 1)
