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
	
	# 2. Tree chop leaves remains, player walks onto remains and presses Space to collect 3 seeds
	var player_pos = grid.start + Vector2i(0, 3)
	var tree_cell = player_pos + Vector2i.RIGHT
	grid.cells[tree_cell.y * grid.SIZE + tree_cell.x].tree = true
	grid.cells[tree_cell.y * grid.SIZE + tree_cell.x].tree_state = "healthy"
	
	check(interactions.begin(player_pos, Vector2i.RIGHT, "chop_gather"), "Begin chopping tree")
	var cut_event = interactions.tick(2.0, player_pos)
	check(cut_event.kind == "tree_cut", "Tree cut successfully")
	check(interactions.seeds == 3, "Chopping tree leaves seeds unchanged (3 -> 3, remains on ground)")
	check(grid.traversable(tree_cell), "Player can walk onto the cut tree remains cell")
	
	# Step onto cut tree remains cell and collect seeds
	check(interactions.begin(tree_cell, Vector2i.UP, "chop_gather"), "Begin collecting seeds from cut tree remains")
	var gather_event = interactions.tick(1.0, tree_cell)
	check(gather_event.kind == "collect_seeds", "Seed collection event finished")
	check(interactions.seeds == 6, "Collecting seeds from remains yields +3 seeds (3 -> 6)")
	check(not grid.cells[tree_cell.y * grid.SIZE + tree_cell.x].tree, "Tree remains removed after collecting seeds")
	
	# 3. Tilling ground under feet, then planting sapling consumes 1 seed
	var plant_cell = player_pos + Vector2i.UP
	var plant_data = grid.cells[plant_cell.y * grid.SIZE + plant_cell.x]
	plant_data.tree = false
	plant_data.tilled = false
	plant_data.moisture = 0.8
	plant_data.health = 1.0
	
	check(interactions.begin(plant_cell, Vector2i.UP, "interact"), "Begin tilling soil under feet")
	check(interactions.action_kind == "till_soil", "Action is till_soil")
	var till_event = interactions.tick(2.0, plant_cell)
	check(till_event.kind == "till_soil", "Soil tilled event")
	check(plant_data.tilled, "Cell is marked tilled")
	
	# Planting on tilled cell where player stands
	var on_cell = plant_cell
	check(interactions.begin(on_cell, Vector2i.UP, "interact"), "Begin planting sapling on current tilled cell")
	check(interactions.action_kind == "plant_sapling", "Action is plant_sapling")
	var plant_event = interactions.tick(2.0, on_cell)
	check(plant_event.kind == "plant_sapling", "Sapling planted event")
	check(interactions.seeds == 5, "Planting consumes 1 seed (6 -> 5)")
	
	# 4. Exhaust seeds down to 0
	interactions.seeds = 0
	plant_data.tree = false
	check(not interactions.begin(on_cell, Vector2i.UP, "interact"), "Cannot plant sapling when seeds == 0")
	check(interactions.last_error == "no_seeds", "Failure reason recorded as no_seeds")
	
	# 5. Full world HUD integration
	var flow = root.get_node("SceneFlow")
	flow.next_seed = 2026
	var world = load("res://features/levels/forest/forest_level.tscn").instantiate()
	root.add_child(world)
	world.set_process(false)
	
	var seeds_node = world.hud.get_node_or_null("PlayerStatus/Rows/Seeds")
	if seeds_node == null:
		seeds_node = world.hud.get_node_or_null("PlayerStatus/Rows/Supplies/Seeds")
	check(seeds_node != null, "HUD contains Seeds indicator in PlayerStatus")
	
	var seeds_val = world.hud.get_node_or_null("PlayerStatus/Rows/Seeds/Value")
	if seeds_val == null:
		seeds_val = world.hud.get_node_or_null("PlayerStatus/Rows/Supplies/Seeds")
	check(seeds_val != null and seeds_val.text == "3", "HUD seeds value starts at 3")
	
	# Set a tree directly next to player and run world interaction to verify HUD updates
	var test_pos = world.grid.start + Vector2i(0, 3)
	var target_tree = test_pos + Vector2i.RIGHT
	world.grid.cells[target_tree.y * world.grid.SIZE + target_tree.x].tree = true
	world.grid.cells[target_tree.y * world.grid.SIZE + target_tree.x].tree_state = "healthy"
	world.get_node("GridPlayer").cell = test_pos
	world.get_node("GridPlayer").facing = Vector2i.RIGHT
	
	world.interactions.begin(test_pos, Vector2i.RIGHT, "chop_gather")
	var event = world.interactions.tick(2.0, test_pos)
	world._finish_interaction(event)
	check(seeds_val.text == "3", "HUD seed count remains 3 after cutting tree (remains on ground)")
	
	# Player walks onto cut tree remains cell to collect seeds
	world.get_node("GridPlayer").cell = target_tree
	world.interactions.begin(target_tree, Vector2i.UP, "chop_gather")
	var gather_evt = world.interactions.tick(1.0, target_tree)
	world._finish_interaction(gather_evt)
	check(seeds_val.text == "6", "HUD updates seed count to 6 after collecting seeds from tree remains")
	check(not world.trees.has(target_tree), "Tree remains removed from scene")
	
	# Exhaust seeds in world and simulate pressing interact on tilled ground where player stands
	world.interactions.seeds = 0
	if world.planting != null:
		world.planting.seed_count = 0
	var empty_tilled = test_pos + Vector2i.UP
	world.grid.cells[empty_tilled.y * world.grid.SIZE + empty_tilled.x].tree = false
	world.grid.cells[empty_tilled.y * world.grid.SIZE + empty_tilled.x].moisture = 0.8
	world.grid.cells[empty_tilled.y * world.grid.SIZE + empty_tilled.x].health = 1.0
	world.grid.cells[empty_tilled.y * world.grid.SIZE + empty_tilled.x].tilled = true
	world.get_node("GridPlayer").cell = empty_tilled
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
