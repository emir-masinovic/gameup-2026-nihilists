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
	
	# 1. Initial seed count
	check(interactions.seeds == 3, "Initial seed count is 3")
	
	# 2. Tree chop gives 3 seeds
	var player_pos = grid.start
	var tree_cell = player_pos + Vector2i.RIGHT
	grid.cells[tree_cell.y * grid.SIZE + tree_cell.x].tree = true
	grid.cells[tree_cell.y * grid.SIZE + tree_cell.x].tree_state = "healthy"
	
	check(interactions.begin(player_pos, Vector2i.RIGHT), "Begin chopping tree")
	var cut_event = interactions.tick(2.0, player_pos)
	check(cut_event.kind == "tree_cut", "Tree cut successfully")
	check(interactions.seeds == 6, "Chopping tree yields +3 seeds (3 -> 6)")
	
	# 3. Planting sapling consumes 1 seed
	var plant_cell = player_pos + Vector2i.UP
	var plant_data = grid.cells[plant_cell.y * grid.SIZE + plant_cell.x]
	plant_data.tree = false
	plant_data.moisture = 0.8
	plant_data.health = 1.0
	
	check(interactions.begin(player_pos, Vector2i.UP), "Begin planting sapling")
	check(interactions.action_kind == "plant_sapling", "Action is plant_sapling")
	var plant_event = interactions.tick(2.0, player_pos)
	check(plant_event.kind == "plant_sapling", "Sapling planted event")
	check(interactions.seeds == 5, "Planting consumes 1 seed (6 -> 5)")
	
	# 4. Exhaust seeds down to 0
	interactions.seeds = 0
	plant_data.tree = false
	check(not interactions.begin(player_pos, Vector2i.UP), "Cannot plant sapling when seeds == 0")
	check(interactions.last_error == "no_seeds", "Failure reason recorded as no_seeds")
	
	# 5. Full world HUD integration
	var flow = root.get_node("SceneFlow")
	flow.next_seed = 2026
	var world = load("res://features/levels/forest/forest_level.tscn").instantiate()
	root.add_child(world)
	world.set_process(false)
	
	var seeds_node = world.hud.get_node_or_null("PlayerStatus/Rows/Seeds")
	check(seeds_node != null, "HUD contains Seeds indicator in PlayerStatus")
	
	var seeds_val = world.hud.get_node_or_null("PlayerStatus/Rows/Seeds/Value")
	check(seeds_val != null and seeds_val.text == "3", "HUD seeds value starts at 3")
	
	# Set a tree directly next to player and run world interaction to verify HUD updates
	var test_pos = world.grid.start + Vector2i(0, 3)
	var target_tree = test_pos + Vector2i.RIGHT
	world.grid.cells[target_tree.y * world.grid.SIZE + target_tree.x].tree = true
	world.grid.cells[target_tree.y * world.grid.SIZE + target_tree.x].tree_state = "healthy"
	world.get_node("GridPlayer").cell = test_pos
	world.get_node("GridPlayer").facing = Vector2i.RIGHT
	
	world.interactions.begin(test_pos, Vector2i.RIGHT)
	var event = world.interactions.tick(2.0, test_pos)
	world._finish_interaction(event)
	check(seeds_val.text == "6", "HUD updates seed count to 6 after tree cut")
	
	# Exhaust seeds in world and simulate pressing interact on fertile ground outside bonfire
	world.interactions.seeds = 0
	var empty_front = test_pos + Vector2i.UP
	world.grid.cells[empty_front.y * world.grid.SIZE + empty_front.x].tree = false
	world.grid.cells[empty_front.y * world.grid.SIZE + empty_front.x].moisture = 0.8
	world.grid.cells[empty_front.y * world.grid.SIZE + empty_front.x].health = 1.0
	world.get_node("GridPlayer").facing = Vector2i.UP
	
	var key_event = InputEventAction.new()
	key_event.action = "interact"
	key_event.pressed = true
	world._unhandled_input(key_event)
	
	var toast = world.hud.get_node("Toast")
	check(toast.text.contains("Yeterli tohumunuz yok"), "HUD alerts player when trying to plant without seeds")
	
	world.free()
	
	print("SEED SYSTEM TEST: ", checks, " checks, ", failures, " failures")
	quit(0 if failures == 0 else 1)
