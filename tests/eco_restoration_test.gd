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
	var grid = GridData.new()
	grid.generate(2026)
	
	var climate = load("res://features/levels/forest/climate_simulation.gd").new()
	climate.configure(grid, 2026)
	
	var interactions = load("res://features/levels/forest/forest_interactions.gd").new()
	interactions.configure(grid)
	
	# Use eligible ground away from protected spawn routes.
	var target = Vector2i(5,5)

	var player = target
	var data = grid.cells[target.y * grid.SIZE + target.x]
	
	data.merge({"tree":false,"tree_state":"removed","terrain":"grass","log":false,"berry_bush":false,"burning":false,"burned":false,"water":false,"water_depth":0.0,"water_level":0.0},true)
	# 1. Test that untilled ground is tilled (cannot be watered directly per rule)
	data.moisture = 0.2
	data.health = 0.5
	data.trampled = 0.3
	data.tilled = false
	check(interactions.begin(player, Vector2i.RIGHT, "interact"), "Begin interaction on untilled ground")
	check(interactions.action_kind == "till_soil", "Untilled ground is tilled with hoe, NOT watered")
	var event = interactions.tick(1.0, player)
	check(event.kind == "till_soil", "Till event completed")
	check(data.tilled, "Cell is tilled")
	
	# 2. Player steps onto tilled ground to plant seed on the cell they stand on
	var on_target = target
	check(interactions.begin(on_target, Vector2i.RIGHT, "interact"), "Begin planting on tilled cell where player stands")
	check(interactions.action_kind == "plant_sapling", "Action identified as plant_sapling")
	event = interactions.tick(1.5, on_target)
	check(event.kind == "plant_sapling", "Seed planted event completed")
	check(data.tree and data.tree_state == "seed", "Seed established on cell")
	
	# 3. Player waters the growing seed while standing on its grid cell
	check(interactions.begin(on_target, Vector2i.RIGHT, "interact"), "Begin watering seed while standing on it")
	check(interactions.action_kind == "water_soil", "Action identified as water_soil")
	event = interactions.tick(1.0, on_target)
	check(event.kind == "water_soil", "Water event completed")
	
	# 4. Test seed germination and sapling growth into a full tree
	data.water_needed = 0.0
	data.tree_state = "sapling"
	data.tree_health = 0.92
	data.growth_age = preload("res://features/levels/forest/StatePlanting.gd").GROWTH_SECONDS - 1.0
	
	var initial_shade = climate.shade_at(target)
	check(initial_shade > 0.0, "Sapling provides initial partial shade")
	
	# Simulate favorable conditions for sapling to mature into a full tree
	climate.temperature = 26.0
	data.moisture = 0.8
	for i in range(40):
		climate.tick(1.0)
	
	check(data.tree_state == "healthy", "Sapling matured into full healthy tree under favorable weather")
	check(data.tree_health >= 0.95, "Mature tree has high health")
	check(climate.shade_at(target) > initial_shade, "Mature tree provides greater shade than sapling")
	
	print("ECO RESTORATION: ", checks, " checks, ", failures, " failures")
	quit(0 if failures == 0 else 1)
