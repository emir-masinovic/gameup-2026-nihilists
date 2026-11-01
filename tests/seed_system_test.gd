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
	var player_pos = Vector2i(4,5)
	var tree_cell = player_pos + Vector2i.RIGHT
	grid.cells[tree_cell.y * grid.SIZE + tree_cell.x].tree = true
	grid.cells[tree_cell.y * grid.SIZE + tree_cell.x].tree_state = "healthy"
	grid.cells[tree_cell.y * grid.SIZE + tree_cell.x].tree_health = 1.0
	
	check(interactions.begin(player_pos, Vector2i.RIGHT, "chop_gather"), "Begin chopping tree")
	var cut_event = interactions.tick(2.0, player_pos)
	check(cut_event.kind == "tree_cut", "Tree cut successfully")
	check(interactions.seeds == 3, "Chopping tree leaves seeds unchanged (3 -> 3, remains on ground)")
	check(not grid.traversable(tree_cell), "Stump blocks occupancy")
	
	# Step onto cut tree remains cell and collect seeds
	check(interactions.begin(player_pos, Vector2i.RIGHT, "chop_gather"), "Begin collecting seeds from cut tree remains")
	var gather_event = interactions.tick(1.0, player_pos)
	check(gather_event.kind == "collect_seeds", "Seed collection event finished")
	check(interactions.seeds == 6, "Collecting seeds from remains yields +3 seeds (3 -> 6)")
	check(grid.cells[tree_cell.y * grid.SIZE + tree_cell.x].tree, "Collecting seeds preserves stump")
	
	interactions.seeds = 8
	var remaining = grid.cells[tree_cell.y*grid.SIZE+tree_cell.x]
	remaining.merge({"tree":true,"tree_state":"stump","pending_seeds":3},true)
	interactions.begin(player_pos,Vector2i.RIGHT,"chop_gather")
	interactions.tick(1.0,player_pos)
	check(interactions.seeds == 9 and remaining.pending_seeds == 2 and remaining.tree,"Partial collection preserves uncollected seeds at the cap")
	interactions.seeds = 7
	interactions.begin(player_pos,Vector2i.RIGHT,"chop_gather")
	interactions.tick(1.0,player_pos)
	check(interactions.seeds == 9 and remaining.tree and remaining.pending_seeds == 0,"Remaining seeds collect once while stump remains")
	check(interactions.tick(1.0,player_pos).is_empty(),"Completed collection cannot execute twice")
	remaining.pending_seeds = 3
	check(not interactions.begin(player_pos,Vector2i.RIGHT,"chop_gather"),"Full inventory cannot collect or destroy seeds")
	check(interactions.begin(player_pos,Vector2i.RIGHT,"interact") and interactions.action_kind == "stump_removed","Full inventory retains explicit stump escape action")
	var removed = interactions.tick(1.0,player_pos)
	check(removed.kind == "stump_removed" and interactions.seeds == 9 and remaining.pending_seeds == 3 and not remaining.tree and grid.traversable(tree_cell),"Removal opens route, preserves seeds and gives no reward")
	check(interactions.tick(1.0,player_pos).is_empty(),"Repeated completion cannot duplicate removal")
	interactions.seeds = 8
	interactions.begin(player_pos,Vector2i.RIGHT,"chop_gather")
	interactions.tick(1.0,player_pos)
	check(interactions.seeds == 9 and remaining.pending_seeds == 2 and grid.traversable(tree_cell),"Loose pickup supports capped partial collection without blocking")
	interactions.seeds = 7
	interactions.begin(tree_cell,Vector2i.UP,"chop_gather")
	interactions.tick(1.0,tree_cell)
	check(interactions.seeds == 9 and remaining.pending_seeds == 0,"Loose seeds collect from the current tile exactly once")
	var trapped = Vector2i(12,4)
	interactions.seeds = 9
	grid.cells[trapped.y*grid.SIZE+trapped.x].merge({"tree":true,"tree_state":"sapling"},true)
	for direction in [Vector2i.UP,Vector2i.RIGHT,Vector2i.DOWN,Vector2i.LEFT]:
		var cell = trapped+direction
		grid.cells[cell.y*grid.SIZE+cell.x].merge({"tree":true,"tree_state":"stump","pending_seeds":3,"log":false,"burning":false},true)
		check(not grid.traversable(cell),"Surrounding stump really blocks the trapped player")
	check(interactions.begin(trapped,Vector2i.RIGHT,"interact") and interactions.action_kind == "stump_removed","E escape outranks underfoot sapling watering with a full inventory")
	interactions.tick(1.0,trapped)
	check(grid.traversable(trapped+Vector2i.RIGHT) and interactions.seeds == 9,"Full-inventory surrounded player gains an escape route without teleporting")
	var loose = grid.cells[trapped.y*grid.SIZE+trapped.x+1]
	loose.log = true
	check(interactions.begin(trapped,Vector2i.RIGHT,"chop_gather") and interactions.action_kind == "log_cleared","Loose seeds at capacity cannot softlock clearing an overlapping log")
	interactions.tick(1.0,trapped)
	check(loose.pending_seeds == 3 and not loose.log,"Log clearing preserves loose seed stack")
	interactions.seeds = 6
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
	
	var seeds_node = world.hud.get_node_or_null("PlayerStatus/Rows/Supplies/Seeds")
	check(seeds_node != null, "HUD contains Seeds indicator in PlayerStatus")
	
	var seeds_val = world.hud.get_node_or_null("PlayerStatus/Rows/Supplies/Seeds")
	check(seeds_val != null and seeds_val.text == "3", "HUD seeds value starts at 3")
	
	# Set a tree directly next to player and run world interaction to verify HUD updates
	var test_pos = Vector2i(4,5)
	var target_tree = test_pos + Vector2i.RIGHT
	world.grid.cells[target_tree.y * world.grid.SIZE + target_tree.x].tree = true
	world.grid.cells[target_tree.y * world.grid.SIZE + target_tree.x].tree_state = "healthy"
	world.grid.cells[target_tree.y * world.grid.SIZE + target_tree.x].tree_health = 1.0
	world.grid.cells[target_tree.y * world.grid.SIZE + target_tree.x].planted = false
	world.get_node("GridPlayer").cell = test_pos
	world.get_node("GridPlayer").facing = Vector2i.RIGHT
	
	world.interactions.begin(test_pos, Vector2i.RIGHT, "chop_gather")
	var event = world.interactions.tick(2.0, test_pos)
	world._finish_interaction(event)
	check(seeds_val.text == "3", "HUD seed count remains 3 after cutting tree (remains on ground)")
	
	# Player walks onto cut tree remains cell to collect seeds
	world.get_node("GridPlayer").cell = test_pos
	world.interactions.begin(test_pos, Vector2i.RIGHT, "chop_gather")
	var gather_evt = world.interactions.tick(1.0, test_pos)
	world._finish_interaction(gather_evt)
	check(seeds_val.text == "6", "HUD updates seed count to 6 after collecting seeds from tree remains")
	check(world.trees.has(target_tree), "Stump remains visible after seed collection")
	
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
	check(world.hud.notification_queue.any(func(item): return item.text.contains("No seeds")) or world.hud.notification_active.any(func(item): return item.text.contains("No seeds")), "HUD alerts player when trying to plant without seeds")
	
	var authoritative = world.planting.seed_count
	world.interactions.seeds = 99
	check(world.planting.seed_count == 9,"Interaction alias enforces the authoritative nine-seed cap")
	world.planting.seed_count = authoritative
	var settings = root.get_node("SettingsManager")
	var old_map = settings.bindings.duplicate(true)
	settings.bindings.interact = [KEY_J,0]
	settings.bindings.chop_gather = [KEY_K,0]
	settings.apply_settings()
	world._update_interaction_marker()
	check(world._binding_label("interact") == "J" and world._binding_label("chop_gather") == "K","Context prompts derive both actions from saved remaps")
	settings.bindings = old_map
	settings.apply_settings()
	world.free()
	
	print("SEED SYSTEM TEST: ", checks, " checks, ", failures, " failures")
	quit(0 if failures == 0 else 1)
