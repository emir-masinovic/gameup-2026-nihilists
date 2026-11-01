extends SceneTree

var checks := 0
var failures := 0

func check(condition: bool, description: String) -> void:
	checks += 1
	if condition:
		print("PASS: ", description)
	else:
		failures += 1
		push_error("FAIL: " + description)

func _init() -> void:
	call_deferred("run")

func run() -> void:
	print("--- Running Spaceship Landmark Tests ---")
	
	# 1. GridData Spaceship Footprint & Cells Configuration
	var GridData = load("res://features/levels/forest/grid_data.gd")
	var grid = GridData.new()
	grid.generate(2026)
	
	check(grid.SPACESHIP_CELLS.size() >= 2, "Spaceship covers multiple cells (at least 2, currently %d)" % grid.SPACESHIP_CELLS.size())
	check(grid.SPACESHIP_CELLS == [Vector2i(9, 0), Vector2i(10, 0), Vector2i(9, 1), Vector2i(10, 1)], "Spaceship occupies 2x2 cells at northern boundary (9..10, 0..1)")
	
	# Verify every spaceship cell is at the end of the grid map (z <= 2)
	for cell in grid.SPACESHIP_CELLS:
		check(cell.y <= 2, "Spaceship cell (%d, %d) is at the north end of the forest map" % [cell.x, cell.y])
	
	# Verify spaceship cells are completely free of other entities
	for cell in grid.SPACESHIP_CELLS:
		var data: Dictionary = grid.cells[cell.y * grid.SIZE + cell.x]
		check(data.get("spaceship", false), "Cell (%d, %d) is marked as spaceship" % [cell.x, cell.y])
		check(not data.get("tree", false), "Cell (%d, %d) has no tree" % [cell.x, cell.y])
		check(not data.get("log", false), "Cell (%d, %d) has no log" % [cell.x, cell.y])
		check(not data.get("water", false), "Cell (%d, %d) has no water" % [cell.x, cell.y])
		check(data.get("terrain", "") != "water", "Cell (%d, %d) terrain is not water" % [cell.x, cell.y])
		check(float(data.get("water_level", 0.0)) == 0.0, "Cell (%d, %d) water_level is 0.0" % [cell.x, cell.y])
		check(float(data.get("water_depth", 0.0)) == 0.0, "Cell (%d, %d) water_depth is 0.0" % [cell.x, cell.y])
		check(not grid.traversable(cell), "Cell (%d, %d) is non-traversable (blocked by spaceship)" % [cell.x, cell.y])
	
	# Objective cell (8, 0) and spawn (8, 8) and central route must remain clear
	check(grid.traversable(grid.start), "Spawn cell (8, 8) is traversable")
	check(grid.traversable(grid.objective), "Objective cell (8, 0) is traversable")
	for y in range(grid.SIZE):
		check(grid.traversable(Vector2i(8, y)), "Central north-south route cell (8, %d) is traversable" % y)
	
	# 2. Foraging System: Berries cannot spawn on spaceship cells
	var Foraging = load("res://features/levels/forest/ResourceForaging.gd")
	var foraging = Foraging.new()
	foraging.configure(grid, 2026, "forest")
	for cell in grid.SPACESHIP_CELLS:
		var data: Dictionary = grid.cells[cell.y * grid.SIZE + cell.x]
		check(not data.get("berry_bush", false), "Spaceship cell (%d, %d) has no berry bush" % [cell.x, cell.y])
		check(int(data.get("berries", 0)) == 0, "Spaceship cell (%d, %d) has 0 berries" % [cell.x, cell.y])
		check(not foraging.availability(cell).available, "Foraging availability is false on spaceship cell (%d, %d)" % [cell.x, cell.y])
	
	# 3. Planting System: Cannot plant seeds or prepare soil on spaceship cells
	var Planting = load("res://features/levels/forest/StatePlanting.gd")
	var planting = Planting.new()
	for cell in grid.SPACESHIP_CELLS:
		check(not planting.soil_availability(grid, cell).available, "Soil availability rejected on spaceship cell (%d, %d)" % [cell.x, cell.y])
		check(not planting.availability(grid, cell).available, "Plant availability rejected on spaceship cell (%d, %d)" % [cell.x, cell.y])
		check(not planting.plant(grid, cell), "Planting rejected on spaceship cell (%d, %d)" % [cell.x, cell.y])
	
	# 4. Climate / Regeneration System: Natural saplings cannot regenerate on spaceship cells
	var Climate = load("res://features/levels/forest/climate_simulation.gd")
	var climate = Climate.new()
	climate.configure(grid, 2026)
	for cell in grid.SPACESHIP_CELLS:
		check(not climate._can_regenerate(cell), "Regeneration rejected on spaceship cell (%d, %d)" % [cell.x, cell.y])
	
	# 5. Forest Level Scene & 3D Spaceship Visuals
	var LevelScene = load("res://features/levels/forest/forest_level.tscn")
	var world = LevelScene.instantiate()
	root.add_child(world)
	await process_frame
	await process_frame
	
	var spaceship: Node3D = world.get_node_or_null("Spaceship")
	check(spaceship != null, "Forest level instantiates Spaceship node")
	if spaceship != null:
		check(spaceship.is_in_group("forest_props"), "Spaceship is in forest_props group")
		check(is_equal_approx(spaceship.position.x, 3.0), "Spaceship X position is centered at 3.0 (between x=9 and x=10)")
		check(is_equal_approx(spaceship.position.z, -15.0), "Spaceship Z position is centered at -15.0 (between z=0 and z=1)")
		check(is_equal_approx(spaceship.position.y, 0.0), "Spaceship stands on the ground at Y=0.0")
		check(spaceship.scale == Vector3.ONE * 2.0, "Spaceship is scaled to 2.0x (covering the 4m x 4m footprint)")
		
		# Check mesh and upright orientation
		var mesh_inst: MeshInstance3D = spaceship.get_node_or_null("rocket_classic")
		check(mesh_inst != null, "Spaceship contains rocket_classic MeshInstance3D child")
		if mesh_inst != null and mesh_inst.mesh != null:
			var aabb: AABB = mesh_inst.mesh.get_aabb()
			check(aabb.size.y > 5.0, "Spaceship mesh height is tall (> 5m unscaled, currently %.2f)" % aabb.size.y)
			check(aabb.position.y >= 0.0, "Spaceship base rests at ground level Y >= 0.0")
			var world_height = aabb.size.y * spaceship.scale.y
			check(world_height > 10.0, "World-space spaceship height is impressive (%.2fm upright)" % world_height)
		
		# Verify ground cover suppression: spaceship cells are in decorated_cells
		for cell in grid.SPACESHIP_CELLS:
			check(world.decorated_cells.has(cell), "Cell (%d, %d) is in decorated_cells to suppress grass under ship" % [cell.x, cell.y])
	
	world.free()
	
	print("\nSPACESHIP LANDMARK TEST: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
