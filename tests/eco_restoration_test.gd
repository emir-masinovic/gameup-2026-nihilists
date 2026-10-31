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
	
	# Select an open traversable cell adjacent to spawn
	var target = grid.start + Vector2i.RIGHT
	while grid.cells[target.y * grid.SIZE + target.x].tree:
		target += Vector2i.RIGHT
	
	var player = target + Vector2i.LEFT
	var data = grid.cells[target.y * grid.SIZE + target.x]
	
	# 1. Test watering dry soil
	data.moisture = 0.2
	data.health = 0.5
	data.trampled = 0.3
	check(interactions.begin(player, Vector2i.RIGHT), "Begin interaction on dry ground")
	check(interactions.action_kind == "water_soil", "Action identified as water_soil")
	var event = interactions.tick(1.0, player)
	check(event.kind == "water_soil", "Water event completed")
	check(data.moisture >= 0.99 and data.health >= 0.99 and data.trampled == 0.0, "Soil revitalized with full moisture and health")
	
	# 2. Test planting sapling on revitalized fertile ground
	check(interactions.begin(player, Vector2i.RIGHT), "Begin interaction on fertile open ground")
	check(interactions.action_kind == "plant_sapling", "Action identified as plant_sapling")
	event = interactions.tick(1.5, player)
	check(event.kind == "plant_sapling", "Sapling planted event completed")
	check(data.tree and data.tree_state == "sapling" and data.tree_health > 0.3, "Sapling established on cell")
	
	# 3. Test sapling growth and shade simulation
	var initial_shade = climate.shade_at(target)
	check(initial_shade > 0.0, "Sapling provides initial partial shade")
	
	# Simulate favorable conditions for 30 seconds
	climate.temperature = 26.0
	data.moisture = 0.8
	for i in range(25):
		climate.tick(1.0)
	
	check(data.tree_state == "healthy", "Sapling matured into full healthy tree under favorable weather")
	check(data.tree_health >= 0.95, "Mature tree has high health")
	check(climate.shade_at(target) > initial_shade, "Mature tree provides greater shade than sapling")
	
	print("ECO RESTORATION: ", checks, " checks, ", failures, " failures")
	quit(0 if failures == 0 else 1)
