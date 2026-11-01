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
	
	var grid = GridData.new()
	grid.generate(2026)
	var interactions = ForestInteractions.new()
	interactions.configure(grid)
	
	# 1. Initial water stats
	check(interactions.water_ml == 500, "Starting water is 500 ml")
	check(interactions.MAX_WATER_ML == 1000, "Maximum water capacity is 1000 ml")
	check(interactions.WATER_PER_POUR == 250, "Water consumed per pour is 250 ml")
	check(interactions.WATER_PER_FILL == 500, "Water filled per action is 500 ml")
	
	# 2. Lake water filling interaction
	# Find a lake cell
	var lake_pos = Vector2i(-1, -1)
	for z in range(grid.SIZE):
		for x in range(grid.SIZE):
			var c = grid.cells[z * grid.SIZE + x]
			if c.get("water", false) and c.get("water_depth", 0.0) > 0.5:
				lake_pos = Vector2i(x, z)
				break
		if lake_pos.x >= 0:
			break
	
	check(lake_pos.x >= 0, "Found a lake cell on map")
	
	# Set player adjacent to lake and facing it
	var player_pos = lake_pos + Vector2i.LEFT
	grid.cells[player_pos.y * grid.SIZE + player_pos.x].tree = false
	grid.cells[player_pos.y * grid.SIZE + player_pos.x].water = false
	grid.cells[player_pos.y * grid.SIZE + player_pos.x].tilled = false
	
	check(interactions.begin(player_pos, Vector2i.RIGHT), "Begin water filling when facing lake")
	check(interactions.action_kind == "fill_water", "Action kind is fill_water")
	check(interactions.duration >= 2.0 and interactions.duration <= 3.0, "Duration is ~2-3 seconds (2.4s)")
	
	var fill_event = interactions.tick(2.5, player_pos)
	check(fill_event.kind == "fill_water", "Fill water event finished")
	check(interactions.water_ml == 1000, "Bottle filled to 1000 ml (+500 ml)")
	
	# 3. Bottle full behavior
	check(not interactions.begin(player_pos, Vector2i.RIGHT), "Cannot fill water when bottle is full (1000 ml)")
	check(interactions.last_error == "water_full", "Error reason is water_full")
	
	# 4. Untilled ground and empty tilled ground cannot be watered
	var empty_pos = player_pos + Vector2i.UP
	grid.cells[empty_pos.y * grid.SIZE + empty_pos.x].tree = false
	grid.cells[empty_pos.y * grid.SIZE + empty_pos.x].tilled = false
	interactions.cancel()
	interactions.begin(empty_pos, Vector2i.UP)
	check(interactions.action_kind != "water_soil", "Untilled ground cannot be watered")
	interactions.cancel()
	
	grid.cells[empty_pos.y * grid.SIZE + empty_pos.x].tilled = true
	interactions.begin(empty_pos, Vector2i.UP)
	check(interactions.action_kind != "water_soil", "Empty tilled ground cannot be watered")
	interactions.cancel()
	
	# 5. Water consumption on growing crop when standing ON it
	var crop_pos = empty_pos
	var crop_cell = grid.cells[crop_pos.y * grid.SIZE + crop_pos.x]
	crop_cell.tree = true
	crop_cell.tree_state = "seed"
	crop_cell.water_needed = 1.0
	crop_cell.moisture = 0.2
	
	# Pour 1: 1000 ml -> 750 ml
	check(interactions.begin(crop_pos, Vector2i.UP), "Begin watering thirsty seed under feet")
	check(interactions.action_kind == "water_soil", "Action kind is water_soil")
	var pour_event = interactions.tick(1.0, crop_pos)
	check(pour_event.kind == "water_soil", "Pour finished")
	check(interactions.water_ml == 750, "Water decreased by 250 ml (1000 -> 750 ml)")
	
	# Pour 2: 750 ml -> 500 ml
	interactions.begin(crop_pos, Vector2i.UP)
	interactions.tick(1.0, crop_pos)
	check(interactions.water_ml == 500, "Water decreased by 250 ml (750 -> 500 ml)")
	
	# Pour 3: 500 ml -> 250 ml
	crop_cell.water_needed = 0.5
	crop_cell.moisture = 0.2
	interactions.begin(crop_pos, Vector2i.UP)
	interactions.tick(1.0, crop_pos)
	check(interactions.water_ml == 250, "Water decreased by 250 ml (500 -> 250 ml)")
	
	# Pour 4: 250 ml -> 0 ml
	crop_cell.water_needed = 0.5
	crop_cell.moisture = 0.2
	interactions.begin(crop_pos, Vector2i.UP)
	interactions.tick(1.0, crop_pos)
	check(interactions.water_ml == 0, "Water decreased by 250 ml (250 -> 0 ml)")
	
	# Out of water behavior
	crop_cell.water_needed = 0.5
	crop_cell.moisture = 0.2
	check(not interactions.begin(crop_pos, Vector2i.UP), "Cannot water when water_ml == 0")
	check(interactions.last_error == "no_water", "Error reason is no_water")
	
	# 6. Full ForestLevel & HUD Integration
	var flow = root.get_node("SceneFlow")
	flow.next_seed = 2026
	var world = load("res://features/levels/forest/forest_level.tscn").instantiate()
	root.add_child(world)
	world.set_process(false)
	
	var water_row = world.hud.get_node_or_null("PlayerStatus/Rows/Water")
	check(water_row != null, "HUD contains Water row in PlayerStatus")
	
	var water_icon = world.hud.get_node_or_null("PlayerStatus/Rows/Water/Icon")
	check(water_icon != null and water_icon.kind == "drop", "Water row has drop icon")
	
	var water_bar = world.hud.get_node_or_null("PlayerStatus/Rows/Water/Bar")
	check(water_bar != null and water_bar.max_value == 1000.0 and water_bar.value == 500.0, "Water bar starts at 500/1000")
	
	var water_val = world.hud.get_node_or_null("PlayerStatus/Rows/Water/Value")
	check(water_val != null and water_val.text == "500 ml", "Water value displays 500 ml")
	
	# Test GridPlayer bottle node
	var player_node = world.get_node("GridPlayer")
	var bottle_node = player_node.get_node("Body/ArmRight/Bottle")
	check(bottle_node != null, "GridPlayer has Bottle node")
	check(not bottle_node.visible, "Bottle is initially hidden")
	
	player_node.start_filling_water(Vector3(1, 0, 0))
	check(player_node.is_filling_water and bottle_node.visible, "Bottle is visible during water filling")
	player_node.stop_filling_water()
	check(not bottle_node.visible, "Bottle is hidden after water filling")
	
	player_node.start_watering(Vector3(1, 0, 0))
	check(player_node.is_watering and bottle_node.visible, "Bottle is visible during watering")
	player_node.stop_watering()
	check(not bottle_node.visible, "Bottle is hidden after watering")
	
	# Simulate lake fill in world and verify HUD updates
	var world_lake_pos = lake_pos
	var world_player_pos = world_lake_pos + Vector2i.LEFT
	world.grid.cells[world_player_pos.y * world.grid.SIZE + world_player_pos.x].tree = false
	world.grid.cells[world_player_pos.y * world.grid.SIZE + world_player_pos.x].water = false
	world.grid.cells[world_player_pos.y * world.grid.SIZE + world_player_pos.x].tilled = false
	player_node.cell = world_player_pos
	player_node.facing = Vector2i.RIGHT
	
	world.interactions.begin(world_player_pos, Vector2i.RIGHT)
	var fill_evt = world.interactions.tick(2.5, world_player_pos)
	world._finish_interaction(fill_evt)
	check(water_val.text == "1000 ml" and water_bar.value == 1000.0, "HUD updates to 1000 ml after filling")
	
	# Simulate watering in world while standing on crop cell
	var world_crop_pos = world_player_pos + Vector2i.UP
	var world_crop_data = world.grid.cells[world_crop_pos.y * world.grid.SIZE + world_crop_pos.x]
	world_crop_data.tree = true
	world_crop_data.tree_state = "seed"
	world_crop_data.water_needed = 1.0
	player_node.cell = world_crop_pos
	player_node.facing = Vector2i.UP
	
	world.interactions.begin(world_crop_pos, Vector2i.UP)
	var pour_evt = world.interactions.tick(1.0, world_crop_pos)
	world._finish_interaction(pour_evt)
	check(water_val.text == "750 ml" and water_bar.value == 750.0, "HUD updates to 750 ml after watering")
	
	# Exhaust water and verify warning toast
	world.interactions.water_ml = 0
	world._update_hud()
	check(water_val.text == "0 ml" and water_bar.value == 0.0, "HUD updates to 0 ml when exhausted")
	
	var interact_key = InputEventAction.new()
	interact_key.action = "interact"
	interact_key.pressed = true
	world._unhandled_input(interact_key)
	
	var toast = world.hud.get_node("Toast")
	check(toast.text.contains("Not enough water"), "HUD alerts player when trying to water without water")
	
	world.free()
	
	print("WATER BOTTLE SYSTEM TEST: ", checks, " checks, ", failures, " failures")
	quit(0 if failures == 0 else 1)
