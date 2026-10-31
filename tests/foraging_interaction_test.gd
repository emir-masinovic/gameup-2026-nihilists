extends SceneTree
const Grid = preload("res://features/levels/forest/grid_data.gd")
const Climate = preload("res://features/levels/forest/climate_simulation.gd")
const Foraging = preload("res://features/levels/forest/ResourceForaging.gd")
const Context = preload("res://features/levels/forest/InteractionContext.gd")
const Visual = preload("res://features/levels/forest/VisualForaging.gd")
var completed := 0
var cancelled := 0

func _initialize() -> void:
	for seed_value in [1, 47, 2026, 98765]:
		for region in ["forest", "wetlands", "drylands"]:
			_check_foraging(seed_value, region)
	_check_interactions()
	print("FORAGING INTERACTION: seeded placement, preservation, depletion, climate regrowth, visuals and action contract passed")
	quit()

func _check_foraging(seed_value: int, region: String) -> void:
	var grid := Grid.new()
	grid.generate(seed_value)
	var climate := Climate.new()
	climate.configure(grid, seed_value)
	var before: Array = grid.cells.duplicate(true)
	var forage := Foraging.new()
	forage.configure(grid, seed_value, region)
	var count := 0
	var bushes: Array[Vector2i] = []
	for i in range(grid.cells.size()):
		var data: Dictionary = grid.cells[i]
		for key in before[i]:
			assert(data[key] == before[i][key], "Forage must preserve generation and climate")
		if data.berry_bush:
			count += 1
			var cell := Vector2i(i % grid.SIZE, floori(float(i) / grid.SIZE))
			assert(grid.traversable(cell))
			assert(_reachable(grid, cell))
			bushes.append(cell)
	assert(count == {"forest": 4, "wetlands": 3, "drylands": 1}[region])
	if region == "forest":
		assert(grid.cells[8 * grid.SIZE + 6].berry_bush)
	var clone := Grid.new()
	clone.generate(seed_value)
	Climate.new().configure(clone, seed_value)
	Foraging.new().configure(clone, seed_value, region)
	assert(clone.cells == grid.cells, "Forage must be deterministic")
	var cell: Vector2i = bushes[0]
	var data: Dictionary = grid.cells[cell.y * grid.SIZE + cell.x]
	assert(forage.harvest(cell) == 2)
	assert(forage.harvest(cell) == 0)
	Foraging.new().configure(grid, seed_value, region)
	assert(data.berries == 0, "Region re-entry must retain depletion")
	data.moisture = 0.0
	forage.tick(500.0)
	assert(data.berries == 0 and data.berry_regrowth == 0.0)
	data.moisture = 0.8
	data.health = 0.8
	forage.tick(179.0)
	assert(data.berries == 0)
	forage.tick(1.0)
	assert(data.berries == 2)
	if seed_value == 2026 and region == "forest":
		var visual := Visual.new()
		visual.configure(grid)
		assert(visual.bushes.size() == 4)
		var bush: Dictionary = visual.bushes[0]
		var visual_data: Dictionary = grid.cells[bush.index]
		assert(bush.berries.visible)
		visual_data.berries = 0
		visual.update_state(grid)
		assert(not bush.berries.visible)
		visual.free()
	data.burning = true
	assert(not forage.availability(cell).available)
	forage.tick(1.0)
	assert(data.berries == 0)

func _reachable(grid: RefCounted, goal: Vector2i) -> bool:
	var queue: Array[Vector2i] = [grid.start]
	var seen := {grid.start: true}
	while not queue.is_empty():
		var cell: Vector2i = queue.pop_front()
		if cell == goal:
			return true
		for offset in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var next: Vector2i = cell + offset
			if not seen.has(next) and grid.traversable(next):
				seen[next] = true
				queue.append(next)
	return false

func _check_interactions() -> void:
	var context := Context.new()
	var origin := Vector2i(8, 8)
	var left := {"id": "b", "cell": origin + Vector2i.LEFT, "priority": 1, "duration": 1.0, "available": true}
	var right := {"id": "a", "cell": origin + Vector2i.RIGHT, "priority": 0, "duration": 1.0, "available": true}
	var far := {"id": "far", "cell": origin + Vector2i.RIGHT * 2, "priority": 100}
	assert(context.select([far], origin, Vector2i.RIGHT).is_empty())
	assert(context.select([left, right], origin, Vector2i.RIGHT).id == "a")
	assert(context.select([left, right], origin, Vector2i.UP).id == "b")
	left.priority = 0
	assert(context.select([left, right], origin, Vector2i.UP).id == "a")
	far.range = 3.0
	assert(context.select([far, right], origin, Vector2i.RIGHT).id == "a")
	right.complete = func(): completed += 1
	right.cancel = func(): cancelled += 1
	assert(context.begin(right, origin))
	assert(not context.begin(left, origin))
	assert(context.tick(2.0, origin, true).is_empty() and context.progress == 0.0)
	assert(context.tick(0.4, origin).is_empty())
	assert(context.tick(0.1, origin + Vector2i.UP).kind == "cancelled")
	assert(cancelled == 1 and completed == 0)
	assert(context.begin(right, origin))
	assert(context.tick(1.0, origin).kind == "completed")
	assert(completed == 1 and context.active.is_empty())
	right.available = false
	assert(not context.begin(right, origin))
	right.available = true
	assert(context.begin(right, origin))
	right.available = false
	assert(context.tick(1.0, origin).kind == "cancelled")
	assert(cancelled == 2)
