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
	var began = Time.get_ticks_usec()
	for world_seed in range(80):
		var grid = Data.new()
		var twin = Data.new()
		grid.generate(world_seed)
		twin.generate(world_seed)
		check(grid.cells == twin.cells, "Generation is reproducible")
		var ponds = 0
		for y in range(grid.SIZE):
			for x in range(grid.SIZE):
				var cell = Vector2i(x, y)
				var data: Dictionary = grid.cells[y * grid.SIZE + x]
				if x == 8 or y == 8:
					check(grid.traversable(cell) and data.terrain != "water", "Guaranteed dry traversable cross")
				if data.terrain == "water":
					ponds += 1
					check(not grid.traversable(cell) and not data.tree, "Pond blocks movement and has no trees")
		check(ponds >= 2 and ponds <= 5, "Ponds stay small")
		check(grid.traversable(grid.start) and grid.traversable(grid.objective), "Spawn and objective accessible")
	var grid = Data.new()
	var twin = Data.new()
	grid.generate(2026)
	twin.generate(2026)
	var climate = Climate.new()
	var other = Climate.new()
	climate.configure(grid, 2026)
	other.configure(twin, 2026)
	for i in range(40):
		climate.tick(30.0)
		other.tick(30.0)
	check(grid.cells == twin.cells and climate.temperature == other.temperature, "Climate and wildfire evolution deterministic")
	climate.elapsed = 100000.0
	climate._update_weather()
	var weather_offset: float = {"clear": 0.0, "rain": -5.0, "cool": -7.0, "heat": 8.0}[climate.weather]
	check(is_equal_approx(climate.temperature - weather_offset, 36.0), "Warming saturates at twelve degrees")
	for data in grid.cells:
		check(data.fuel >= 0.0 and data.fuel <= 1.0 and data.moisture >= 0.0 and data.moisture <= 1.0, "Fuel and moisture bounded")
	# Isolate fire rules from the changing weather clock.
	grid.generate(99)
	climate.configure(grid, 99)
	climate.ignition_delay = 1.0e9
	climate.weather = "heat"
	climate.temperature = 40.0
	climate.spread_chance = 1.0
	for data in grid.cells:
		data.terrain = "grass"
		data.moisture = 0.0
		data.fuel = 1.0
		data.tree = false
	var source = Vector2i(2, 2)
	grid.cells[2 * grid.SIZE + 2].burning = true
	climate._simulate_fire(1.0)
	check(grid.cells[2 * grid.SIZE + 3].burning, "Fire spreads to adjacent dry fuel")
	check(not grid.cells[2 * grid.SIZE + 4].burning, "Snapshot prevents same-step fire cascade")
	check(climate.fire_at(source) == 1.0 and climate.fire_at(Vector2i(4, 2)) == 0.5, "Own and neighboring fire hazards exposed")
	var safe = grid.cells[8 * grid.SIZE + 8]
	safe.burning = true
	climate._simulate_fire(1.0)
	check(not safe.burning and climate.fire_at(grid.start) == 0.0, "Bonfire protected from flames and adjacent heat")
	var water = grid.cells[2 * grid.SIZE + 4]
	water.terrain = "water"
	water.water_level = 1.0
	climate._simulate_fire(1.0)
	check(not water.burning, "Fire never crosses onto water terrain")
	climate.weather = "rain"
	for i in range(4):
		climate._simulate_fire(1.0)
	check(climate.fire_at(source) == 0.0, "Rain extinguishes flames")
	climate.weather = "heat"
	climate.spread_chance = 0.0
	var burned = grid.cells[2 * grid.SIZE + 2]
	burned.burning = true
	burned.fuel = 0.06
	burned.log = true
	climate._simulate_fire(1.0)
	check(burned.burned and not burned.burning and burned.fuel == 0.0, "Exhausted fuel becomes burned")
	check(not burned.log and grid.traversable(source), "Consumed log releases its blocked cell")
	check(not climate._can_burn(source), "Burned exhausted cells cannot reignite")
	var recovery = grid.cells[3 * grid.SIZE + 3]
	recovery.health = 0.3
	recovery.moisture = 0.6
	climate.weather = "cool"
	climate.temperature = 27.0
	climate._simulate(1.0)
	check(recovery.health > 0.3, "Favorable natural weather recovers damaged grass")
	var pond = grid.cells[2 * grid.SIZE + 4]
	pond.water_level = 1.0
	climate.weather = "heat"
	climate.temperature = 44.0
	climate._simulate(1.0)
	check(pond.water_level < 1.0 and pond.water_level > 0.99, "Heat slowly draws pond down")
	pond.water_level = 0.1
	pond.tree = false
	check(grid.traversable(Vector2i(4, 2)), "Dried shallow water becomes traversable")
	pond.log = true
	check(not grid.traversable(Vector2i(4, 2)), "Logs block movement")
	grid.generate(11)
	climate.ignition_delay = 120.0
	climate.configure(grid, 11)
	for i in range(119):
		climate.tick(1.0)
	for data in grid.cells:
		check(not data.burning, "Initial warning interval has no wildfire")
	var elapsed_before = climate.elapsed
	climate.tick(NAN)
	climate.tick(INF)
	climate.tick(-1.0)
	check(climate.elapsed == elapsed_before, "Invalid elapsed deltas are ignored")
	var extreme_began = Time.get_ticks_usec()
	climate.tick(1.0e20)
	check(Time.get_ticks_usec() - extreme_began < 2000000, "Extreme delta work stays under two seconds")
	check(climate.elapsed == elapsed_before + 30.0, "Extreme deltas are bounded")
	check(climate.fire_at(Vector2i(-1, 0)) == 0.0, "Out of bounds fire query safe")
	var duration_ms = (Time.get_ticks_usec() - began) / 1000.0
	check(duration_ms < 60000.0, "Many-seed simulation workload stays bounded")
	print("ECOSYSTEM: ", checks, " checks, ", failures, " failures; ", duration_ms, " ms")
	quit(0 if failures == 0 else 1)
