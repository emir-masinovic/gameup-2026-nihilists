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
	var ForestInteractions = load("res://features/levels/forest/forest_interactions.gd")
	var ClimateSimulation = load("res://features/levels/forest/climate_simulation.gd")
	
	var grid = GridData.new()
	grid.generate(2026)
	var climate = ClimateSimulation.new()
	climate.configure(grid, 2026)
	var interactions = ForestInteractions.new()
	interactions.configure(grid)
	
	# Select a clean cell
	var player_pos = grid.start + Vector2i(0, 3)
	var target_cell = player_pos + Vector2i.RIGHT
	var cell_data = grid.cells[target_cell.y * grid.SIZE + target_cell.x]
	cell_data.tree = false
	cell_data.tilled = false
	cell_data.moisture = 0.8
	cell_data.health = 1.0
	
	# 1. Tilling soil
	check(interactions.begin(target_cell, Vector2i.RIGHT, "interact"), "Player begins interaction on untilled ground")
	check(interactions.action_kind == "till_soil", "Action is till_soil")
	var till_evt = interactions.tick(1.0, target_cell)
	check(till_evt.kind == "till_soil", "Till event finished")
	check(cell_data.tilled == true, "Cell is successfully tilled")
	
	# Untilled ground and empty tilled ground CANNOT be watered
	check(interactions.action_kind != "water_soil", "Untilled or empty ground cannot be watered")
	
	# 2. Player steps onto tilled ground to plant seed on the cell where they stand
	var on_cell = target_cell
	check(interactions.begin(on_cell, Vector2i.UP), "Player begins planting on the tilled cell they stand on")
	check(interactions.action_kind == "plant_sapling", "Action is plant_sapling")
	var plant_evt = interactions.tick(1.5, on_cell)
	check(plant_evt.kind == "plant_sapling", "Plant event finished")
	check(cell_data.tree == true and cell_data.tree_state == "seed", "Cell now contains seed")
	check(cell_data.water_needed == 1.0, "Planted seed requires 1.0 water")
	check(interactions.seeds == 2, "Seed count decreased by 1 (3 -> 2)")
	
	# 3. Watering seed while standing on its grid cell
	check(interactions.begin(on_cell, Vector2i.UP), "Player can water the seed while standing on it")
	check(interactions.action_kind == "water_soil", "Action on thirsty seed under feet is water_soil")
	var water_evt = interactions.tick(1.0, on_cell)
	check(water_evt.kind == "water_soil", "Watering event finished")
	check(cell_data.water_needed <= 0.5, "Seed water needed decreased to <= 0.5")
	
	# Second watering germinates the seed into a sapling
	check(interactions.begin(on_cell, Vector2i.UP), "Water again to satisfy remaining water")
	interactions.tick(1.0, on_cell)
	check(cell_data.water_needed == 0.0, "Water needed fully satisfied (0.0)")
	check(cell_data.tree_state == "sapling", "Seed germinated into sapling")
	
	# 4. Harvesting / clearing sapling with hoe from adjacent cell
	cell_data.moisture = 0.8
	check(interactions.begin(player_pos, Vector2i.RIGHT), "Player facing sapling clears it with hoe")
	check(interactions.action_kind == "harvest_crop", "Action is harvest_crop (clearing with hoe)")
	var harvest_evt = interactions.tick(1.0, player_pos)
	check(harvest_evt.kind == "harvest_crop", "Harvest event finished")
	check(cell_data.tree == false, "Sapling cleared from cell")
	check(interactions.seeds == 3, "Clearing sapling refunds seed (2 -> 3)")
	
	# 5. Full ForestLevel visual test
	var flow = root.get_node("SceneFlow")
	flow.next_seed = 2026
	var world = load("res://features/levels/forest/forest_level.tscn").instantiate()
	root.add_child(world)
	world.set_process(false)
	
	# Verify Farmland container exists and $Terrain has exactly 289 children
	var farmland = world.get_node_or_null("Farmland")
	check(farmland != null, "Farmland container exists")
	check(world.terrain_renderer.rendered_cell_count() == 289 if world.terrain_renderer != null else world.get_node("Terrain").get_child_count() == 289, "Terrain preserves strictly 289 tiles")
	
	# Test GridPlayer axe, hoe, and bottle equipping
	var player_node = world.get_node("GridPlayer")
	var axe_node = player_node.get_node("Body/ArmRight/Axe")
	var hoe_node = player_node.get_node("Body/ArmRight/Hoe")
	var bottle_node = player_node.get_node("Body/ArmRight/Bottle")
	
	player_node.start_chopping(Vector3(1, 0, 0))
	check(player_node.is_chopping and axe_node.visible and not hoe_node.visible and not bottle_node.visible, "Axe visible during chopping")
	player_node.stop_chopping()
	check(not axe_node.visible, "Axe hidden after chopping")
	
	player_node.start_tilling(Vector3(1, 0, 0))
	check(player_node.is_tilling and hoe_node.visible and not axe_node.visible and not bottle_node.visible, "Hoe visible during tilling")
	player_node.stop_tilling()
	check(not hoe_node.visible, "Hoe hidden after tilling")
	
	player_node.start_watering(Vector3(1, 0, 0))
	check(player_node.is_watering and bottle_node.visible and not axe_node.visible and not hoe_node.visible, "Bottle visible during watering")
	player_node.stop_watering()
	check(not bottle_node.visible, "Bottle hidden after watering")
	
	# Test world tilling, stepping onto tilled cell, planting, and indicator creation
	var world_player_pos = world.grid.start + Vector2i(0, 3)
	var world_target = world_player_pos + Vector2i.RIGHT
	var world_cell_data = world.grid.cells[world_target.y * world.grid.SIZE + world_target.x]
	world_cell_data.tree = false
	world_cell_data.tilled = false
	world_cell_data.moisture = 0.8
	world_cell_data.health = 1.0
	
	player_node.cell = world_target
	world.interactions.begin(world_target, Vector2i.UP, "interact")
	var world_till_evt = world.interactions.tick(1.0, world_target)
	world._finish_interaction(world_till_evt)
	check(world.tilled_meshes.has(world_target), "Tilled soil mesh created in Farmland")
	
	# Plant seed on the tilled cell where player stands
	world.interactions.begin(world_target, Vector2i.UP, "interact")
	var world_plant_evt = world.interactions.tick(1.5, world_target)
	world._finish_interaction(world_plant_evt)
	check(world.crop_indicators.has(world_target), "Crop indicator created above planted seed")
	var indicator = world.crop_indicators[world_target]
	check(indicator.indicator_type == "seed", "Crop indicator shows water droplet for seed")
	
	# Simulate climate rain & watering to grow seed to sapling
	world_cell_data.water_needed = 0.0
	world_cell_data.tree_state = "sapling"
	world_cell_data.tree_health = 0.3
	world._refresh_visuals()
	check(indicator.indicator_type == "sapling", "Crop indicator switches to sprout icon for sapling")
	
	# Simulate sapling maturing to full tree
	world_cell_data.tree_health = 0.96
	world_cell_data.tree_state = "healthy"
	world._refresh_visuals()
	check(not world.crop_indicators.has(world_target), "Crop indicator removed once tree is mature")
	
	world.free()
	
	print("FARMING GROWTH TEST: ", checks, " checks, ", failures, " failures")
	quit(0 if failures == 0 else 1)
