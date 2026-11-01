extends SceneTree

var checks = 0
var failures = 0

func check(value: bool, message: String):
	checks += 1
	if not value:
		failures += 1
		push_error("FAIL: " + message)
	else:
		print("PASS: " + message)

func _initialize():
	call_deferred("run")

func run():
	print("--- Running Soil Tilling and Clearing Tests ---")
	var GridData = load("res://features/levels/forest/grid_data.gd")
	var ForestInteractions = load("res://features/levels/forest/forest_interactions.gd")
	var StatePlanting = load("res://features/levels/forest/StatePlanting.gd")
	var ForestLevel = load("res://features/levels/forest/forest_level.tscn")

	var grid = GridData.new()
	grid.generate(2026)
	var planting = StatePlanting.new()
	var interactions = ForestInteractions.new()
	interactions.configure(grid, planting)

	# 1. Test tilling on previously blocked cells (along x=8, y=8, near start)
	# Cell on y = 8 (y == start.y): (6, 8) without berry/tree/trash
	var cell_on_axis = Vector2i(6, 8)
	var data_axis = grid.cells[cell_on_axis.y * grid.SIZE + cell_on_axis.x]
	data_axis.tree = false
	data_axis.log = false
	data_axis.trash = false
	data_axis.berry_bush = false
	data_axis.berries = 0
	data_axis.tilled = false
	data_axis.burning = false
	check(interactions.begin(cell_on_axis, Vector2i.UP, "interact"), "Can begin tilling on axis cell (6, 8)")
	check(interactions.action_kind == "till_soil", "Action kind is till_soil on (6, 8)")
	var till_evt = interactions.tick(1.0, cell_on_axis)
	check(till_evt.kind == "till_soil", "Tilling completed on (6, 8)")
	check(data_axis.tilled, "Cell (6, 8) is marked tilled")
	check(data_axis.prepared, "Cell (6, 8) is marked prepared")

	# Cell near start (distance < 2.5): (8, 7) (x == start.x, distance == 1.0)
	var cell_near_start = Vector2i(8, 7)
	var data_near = grid.cells[cell_near_start.y * grid.SIZE + cell_near_start.x]
	data_near.tree = false
	data_near.log = false
	data_near.trash = false
	data_near.berry_bush = false
	data_near.berries = 0
	data_near.tilled = false
	data_near.burning = false
	check(interactions.begin(cell_near_start, Vector2i.UP, "interact"), "Can begin tilling on cell near start (8, 7)")
	check(interactions.action_kind == "till_soil", "Action kind is till_soil on (8, 7)")
	till_evt = interactions.tick(1.0, cell_near_start)
	check(till_evt.kind == "till_soil", "Tilling completed on (8, 7)")
	check(data_near.tilled, "Cell (8, 7) is marked tilled")

	# Test that planting seed is allowed on this tilled cell near start
	check(interactions.begin(cell_near_start, Vector2i.UP, "interact"), "Can begin planting on tilled cell (8, 7)")
	check(interactions.action_kind == "plant_sapling", "Action kind is plant_sapling on tilled (8, 7)")
	var plant_evt = interactions.tick(1.5, cell_near_start)
	check(plant_evt.kind == "plant_sapling", "Planting completed on (8, 7)")
	check(data_near.tree and data_near.tree_state == "seed", "Seed established on (8, 7)")

	# 2. Test trash tilling restriction and post-pickup tilling
	var trash_cell = Vector2i(3, 4)
	var trash_data = grid.cells[trash_cell.y * grid.SIZE + trash_cell.x]
	trash_data.tree = false
	trash_data.log = false
	trash_data.trash = true
	trash_data.berry_bush = false
	trash_data.berries = 0
	trash_data.tilled = false
	trash_data.burning = false

	# While trash is present: cannot till!
	check(not interactions.begin(trash_cell, Vector2i.UP, "interact"), "Cannot till soil while trash is on the cell")

	# Collect trash
	trash_data.trash = false
	check(interactions.begin(trash_cell, Vector2i.UP, "interact"), "Can till soil after trash is cleared")
	check(interactions.action_kind == "till_soil", "Action kind is till_soil after trash pickup")
	till_evt = interactions.tick(1.0, trash_cell)
	check(till_evt.kind == "till_soil", "Tilling completed on cleared trash cell")
	check(trash_data.tilled, "Cleared trash cell is marked tilled")

	# 3. Test berry tilling restriction and post-harvest tilling
	var berry_cell = Vector2i(5, 6)
	var berry_data = grid.cells[berry_cell.y * grid.SIZE + berry_cell.x]
	berry_data.tree = false
	berry_data.log = false
	berry_data.trash = false
	berry_data.berry_bush = true
	berry_data.berries = 2
	berry_data.tilled = false
	berry_data.burning = false

	# While berries are present: cannot till!
	check(not interactions.begin(berry_cell, Vector2i.UP, "interact"), "Cannot till soil while uncollected berries are on the cell")

	# Collect berries
	berry_data.berries = 0
	check(interactions.begin(berry_cell, Vector2i.UP, "interact"), "Can till soil after berries are harvested")
	check(interactions.action_kind == "till_soil", "Action kind is till_soil after berry harvest")
	till_evt = interactions.tick(1.0, berry_cell)
	check(till_evt.kind == "till_soil", "Tilling completed on harvested berry cell")
	check(berry_data.tilled, "Harvested berry cell is marked tilled")
	check(not berry_data.berry_bush, "Berry bush flag is cleared after tilling")
	check(berry_data.terrain == "soil", "Terrain converted to soil")

	# 4. Full World Integration (forest_level scene)
	var world = ForestLevel.instantiate()
	root.add_child(world)
	await process_frame
	await process_frame

	var player = world.get_node("GridPlayer")

	# Test 4A: Step onto a cell with berries in live world
	var live_berry_cell = Vector2i(6, 8)
	var live_bdata = world.grid.cells[live_berry_cell.y * world.grid.SIZE + live_berry_cell.x]
	live_bdata.tree = false
	live_bdata.log = false
	live_bdata.trash = false
	live_bdata.berry_bush = true
	live_bdata.berries = 2
	live_bdata.tilled = false
	live_bdata.water = false
	live_bdata.terrain = "grass"
	world.forage_visuals.update_state(world.grid)

	player.cell = live_berry_cell
	player.position = world.grid.world_position(live_berry_cell)

	# Preview should show Berry Bush harvest
	var prev = world._action_preview("interact")
	check(prev.get("object_kind", "") == "berries", "Action preview on berry cell with berries is 'berries'")

	# Harvest berries
	var berries_before = world.survival.berry_count
	world._try_interact("interact")
	check(world.survival.berry_count == berries_before + 2, "Interacting on berry cell harvests berries")
	check(live_bdata.berries == 0, "Cell berries are now 0")

	# Now player is still on the cell; preview must show Till Soil!
	prev = world._action_preview("interact")
	check(prev.get("object_kind", "") == "till_soil", "Action preview on harvested berry cell is now 'till_soil'")

	# Interact to till soil
	world._try_interact("interact")
	check(world.interactions.action_kind == "till_soil", "World interactions started till_soil")
	var world_till_evt = world.interactions.tick(1.0, live_berry_cell)
	world._finish_interaction(world_till_evt)
	check(live_bdata.tilled, "Live world cell is now tilled")
	check(not live_bdata.berry_bush, "Live world berry bush flag removed after tilling")
	check(world.tilled_meshes.has(live_berry_cell), "Tilled mesh instance created in world")

	# Next interact on this cell should plant a sapling
	prev = world._action_preview("interact")
	check(prev.get("object_kind", "") == "plant_sapling", "Action preview on tilled cell is 'plant_sapling'")

	# Test 4B: Step onto a trash cell in live world
	var live_trash_cell = world.grid.trash_cells[0]
	player.cell = live_trash_cell
	player.position = world.grid.world_position(live_trash_cell)
	var live_tdata = world.grid.cells[live_trash_cell.y * world.grid.SIZE + live_trash_cell.x]

	prev = world._action_preview("interact")
	check(prev.get("object_kind", "") == "trash", "Action preview on trash cell is 'trash'")

	# Pick trash
	world.survival.trash_count = 0
	world._try_interact("interact")
	check(not live_tdata.trash, "Trash collected from cell")
	check(world.survival.trash_count == 1, "Player inventory trash count is 1")

	# Now preview must show Till Soil
	prev = world._action_preview("interact")
	check(prev.get("object_kind", "") == "till_soil", "Action preview on cleared trash cell is 'till_soil'")

	world._try_interact("interact")
	check(world.interactions.action_kind == "till_soil", "World interactions started till_soil on cleared trash cell")
	var trash_till_evt = world.interactions.tick(1.0, live_trash_cell)
	world._finish_interaction(trash_till_evt)
	check(live_tdata.tilled, "Live world cleared trash cell is now tilled")
	check(world.tilled_meshes.has(live_trash_cell), "Tilled mesh created on cleared trash cell")

	world.free()

	print("\n==========================================")
	print("SOIL TILLING & CLEARING TEST: %d checks, %d failures" % [checks, failures])
	print("==========================================")
	if failures > 0:
		quit(1)
	else:
		quit(0)
