extends SceneTree

const Data = preload("res://features/levels/forest/grid_data.gd")
const Climate = preload("res://features/levels/forest/climate_simulation.gd")
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
	var grid = Data.new()
	var twin = Data.new()
	grid.generate(2026)
	twin.generate(2026)
	var climate = Climate.new()
	var other = Climate.new()
	climate.configure(grid, 2026)
	other.configure(twin, 2026)
	check(grid.cells == twin.cells, "Seeded climate initialization is reproducible")
	var original = grid.cells.duplicate(true)
	for i in range(40):
		climate.tick(30.0)
		other.tick(30.0)
	check(grid.cells == twin.cells and climate.temperature == other.temperature, "Seeded evolution is deterministic")
	check(climate.elapsed == 1200.0 and climate.tick_count == 40, "Elapsed time and tick calls accounted")
	check(climate.temperature > 40.0, "Long-term warming increases temperature")
	var declined = false
	for i in range(grid.cells.size()):
		var data: Dictionary = grid.cells[i]
		check(data.moisture >= 0.0 and data.moisture <= 1.0, "Moisture remains bounded")
		check(data.health >= 0.0 and data.health <= 1.0, "Grass health remains bounded")
		check(data.tree_health >= 0.0 and data.tree_health <= 1.0, "Tree health remains bounded")
		declined = declined or data.health < original[i].health
	check(declined, "Prolonged heat causes visible vegetation decline")
	grid.generate(2026)
	climate.configure(grid, 2026)
	while climate.weather != "rain":
		climate.tick(1.0)
	var target = grid.start
	var index = target.y * grid.SIZE + target.x
	var data: Dictionary = grid.cells[index]
	data.moisture = 0.5
	data.health = 0.4
	data.tree = true
	data.tree_state = "healthy"
	data.tree_health = 0.4
	climate.tick(10.0)
	check(data.moisture > 0.5 and data.health > 0.4 and data.tree_health > 0.4, "Rain recovers grass and surviving trees")
	check(climate.shade_at(target) > 0.0, "Healthy trees cast shade")
	check(climate.shade_at(target + Vector2i.RIGHT) > 0.0, "Adjacent trees provide shade")
	data.tree_state = "dead"
	data.tree_health = 0.0
	climate.tick(10.0)
	check(data.tree_state == "dead" and data.tree_health == 0.0, "Rain does not instantly revive dead trees")
	for neighbor in [target, target + Vector2i.LEFT, target + Vector2i.RIGHT, target + Vector2i.UP, target + Vector2i.DOWN]:
		grid.cells[neighbor.y * grid.SIZE + neighbor.x].tree_state = "stump"
	check(climate.shade_at(target) == 0.0, "Stumps provide no shade")
	data.tree_state = "removed"
	check(climate.shade_at(target) == 0.0, "Removed trees provide no shade")
	var before_health: float = data.health
	climate.trample(target)
	check(data.health < before_health and data.trampled > 0.0, "Trampling damages ground vegetation")
	climate.trample(target, 100.0)
	check(data.health == 0.0 and data.trampled == 1.0, "Trampling clamps damage")
	var before_elapsed = climate.elapsed
	climate.tick(-1.0)
	climate.tick(NAN)
	climate.tick(INF)
	check(climate.elapsed == before_elapsed, "Invalid deltas do not corrupt simulation")
	var began = Time.get_ticks_usec()
	climate.tick(1.0e20)
	var duration_ms = (Time.get_ticks_usec() - began) / 1000.0
	check(is_equal_approx(climate.elapsed - before_elapsed, 30.0), "Extreme delta consumes only bounded simulation time")
	check(duration_ms < 2000.0, "Extreme delta finishes within two seconds")
	check(climate.shade_at(Vector2i(-1, -1)) == 0.0, "Out-of-bounds shade is safe")
	climate.trample(Vector2i(-1, -1))
	print("CLIMATE: ", checks, " checks, ", failures, " failures; extreme-delta time ", duration_ms, " ms")
	quit(0 if failures == 0 else 1)
