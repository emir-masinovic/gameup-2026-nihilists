extends SceneTree

var checks = 0
var failures = 0

func check(value: bool, message: String):
	checks += 1
	if not value:
		failures += 1
		push_error("FAIL: " + message)

func _initialize():
	call_deferred("run")

func run():
	var LevelScene = load("res://features/levels/forest/forest_level.tscn")
	var level = LevelScene.instantiate()
	root.add_child(level)
	
	var grid = level.grid
	var player = level.get_node("GridPlayer")
	var interactions = level.interactions
	var survival = level.survival
	
	# -------------------------------------------------------------
	# Test 1: Stump Traversal and Seed Gathering with Space
	# -------------------------------------------------------------
	var tree_cell = Vector2i(8, 9)
	var stand_cell = Vector2i(8, 8)
	grid.cells[tree_cell.y * grid.SIZE + tree_cell.x].tree = true
	grid.cells[tree_cell.y * grid.SIZE + tree_cell.x].tree_state = "healthy"
	grid.cells[tree_cell.y * grid.SIZE + tree_cell.x].tree_health = 1.0
	grid.cells[tree_cell.y * grid.SIZE + tree_cell.x].log = false
	grid.cells[tree_cell.y * grid.SIZE + tree_cell.x].water = false
	grid.cells[tree_cell.y * grid.SIZE + tree_cell.x].terrain = "grass"
	
	player.cell = stand_cell
	player.facing = Vector2i.DOWN
	check(not grid.traversable(tree_cell), "Healthy tree blocks traversal")
	
	# Cut tree with Space
	var ok = level._try_interact("chop_gather")
	check(interactions.action_kind == "tree_cut", "Begins tree_cut on Space")
	var cut_evt = interactions.tick(2.0, stand_cell)
	check(cut_evt.kind == "tree_cut", "tree_cut finished")
	level._finish_interaction(cut_evt)
	
	check(grid.cells[tree_cell.y * grid.SIZE + tree_cell.x].tree_state == "stump", "Tree becomes stump")
	check(grid.traversable(tree_cell), "Ağaç kalıntısının olduğu hücreye gidilebilmeli (Stump is traversable)")
	
	# Player steps onto stump cell
	var moved = player.try_move(Vector2i.DOWN)
	player.moving = false
	check(moved, "Player can walk onto the cut tree remains cell")
	check(player.cell == tree_cell, "Player cell is now the stump cell")
	
	# Collect seeds from stump with Space while standing on it
	var prev_seeds = interactions.seeds
	ok = level._try_interact("chop_gather")
	check(interactions.action_kind == "collect_seeds", "Standing on stump triggers collect_seeds on Space")
	var gather_evt = interactions.tick(1.0, tree_cell)
	check(gather_evt.kind == "collect_seeds", "collect_seeds finished")
	level._finish_interaction(gather_evt)
	
	check(interactions.seeds == prev_seeds + 3, "Seeds increased by 3 after collecting")
	check(not level.trees.has(tree_cell), "Tree remains visually removed after seed collection")
	check(grid.cells[tree_cell.y * grid.SIZE + tree_cell.x].tree_state == "removed", "Tree state marked removed")
	
	# -------------------------------------------------------------
	# Test 2: Lake / Puddle: Space drinks water, E fills water bottle
	# -------------------------------------------------------------
	var water_cell = Vector2i(8, 10)
	grid.cells[water_cell.y * grid.SIZE + water_cell.x].water = true
	grid.cells[water_cell.y * grid.SIZE + water_cell.x].water_depth = 1.0
	grid.cells[water_cell.y * grid.SIZE + water_cell.x].water_level = 1.0
	grid.cells[water_cell.y * grid.SIZE + water_cell.x].terrain = "water"
	grid.cells[water_cell.y * grid.SIZE + water_cell.x].tree = false
	grid.cells[water_cell.y * grid.SIZE + water_cell.x].berry_bush = false
	
	# Player is at (8, 9), facing DOWN toward water at (8, 10)
	player.facing = Vector2i.DOWN
	survival.thirst = 30.0 # Make player thirsty
	interactions.water_ml = 200 # Bottle has low water
	if level.planting != null:
		level.planting.water_ml = 200
	
	# Press SPACE (chop_gather) -> DRINKS WATER
	ok = level._try_interact("chop_gather")
	check(interactions.action_kind == "drink_water", "Space next to water starts drinking water")
	check(player.is_drinking, "Player enters drinking animation state")
	var drink_evt = interactions.tick(1.5, player.cell)
	check(drink_evt.kind == "drink_water", "Drinking water event generated")
	level._finish_interaction(drink_evt)
	
	check(not player.is_drinking, "Drinking animation finishes")
	check(survival.thirst == 75.0, "Player thirst replenished by 45 (30 -> 75)")
	check(interactions.water_ml == 200, "Bottle water remains untouched when drinking directly with Space")
	
	# Press E (interact) -> FILLS BOTTLE
	ok = level._try_interact("interact")
	check(interactions.action_kind == "fill_water", "E next to water starts filling water bottle")
	check(player.is_filling_water, "Player enters filling water animation state")
	var fill_evt = interactions.tick(3.0, player.cell)
	check(fill_evt.kind == "fill_water", "Filling bottle event generated")
	level._finish_interaction(fill_evt)
	
	check(not player.is_filling_water, "Filling water animation finishes")
	check(interactions.water_ml == 700, "Bottle water replenished (+500 ml -> 700 ml)")
	check(survival.thirst == 75.0, "Player thirst remains unchanged when filling bottle with E")
	
	print("DRINK AND STUMP TEST: ", checks, " checks, ", failures, " failures")
	level.free()
	quit(0 if failures == 0 else 1)
