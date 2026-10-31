extends RefCounted

# Bounded one-second steps preserve snapshot fire spread and catch-up costs.
const MAX_TICK_SECONDS = 30.0
const WEATHER_SECONDS = 60.0
const WEATHER_CYCLE = ["clear", "rain", "cool", "heat"]
const NEIGHBORS = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
var baseline_temperature = 24.0
var warming_limit = 12.0
var warming_timescale = 600.0
var ignition_delay = 120.0
var ignition_interval = 30.0
var ignition_chance = 0.65
var spread_chance = 0.025
var fuel_consumption = 0.055
var elapsed = 0.0
var temperature = 24.0
var weather: String = "clear"
# Empty uses seeded weather; named conditions are also useful for bounded scenarios.
var weather_override: String = ""
var tick_count = 0
var _grid: RefCounted
var _weather_offset = 0
var _fire_rng = RandomNumberGenerator.new()
var _next_ignition = 120.0

func configure(grid: RefCounted, world_seed: int):
	_grid = grid
	elapsed = 0.0
	tick_count = 0
	_next_ignition = maxf(ignition_delay, 1.0)
	_fire_rng.seed = world_seed ^ 0xF13E
	var rng = RandomNumberGenerator.new()
	rng.seed = world_seed
	_weather_offset = rng.randi_range(0, 3)
	for data in _grid.cells:
		data.moisture = 1.0 if data.get("terrain", "grass") == "water" else rng.randf_range(0.55, 0.8)
		data.health = 1.0
		data.tree_health = 1.0 if data.tree else 0.0
		data.tree_state = "healthy" if data.tree else "removed"
		data.trampled = 0.0
		data.log = data.get("log", false)
		data.burning = false
		data.burned = false
		data.fire_time = 0.0
		data.burn_recovery = 0.0
		data.fuel = 0.0 if data.get("terrain", "grass") == "water" else (1.0 if data.tree else 0.45)
	_update_weather()

func tick(seconds: float = 1.0):
	if _grid == null or not is_finite(seconds) or seconds <= 0.0:
		return
	var remaining = minf(seconds, MAX_TICK_SECONDS)
	while remaining > 0.000001:
		var step = minf(remaining, 1.0)
		elapsed += step
		_update_weather()
		_simulate(step)
		remaining -= step
	tick_count += 1

func _update_weather():
	weather = WEATHER_CYCLE[(floori(elapsed / WEATHER_SECONDS) + _weather_offset) % WEATHER_CYCLE.size()]
	if weather_override in WEATHER_CYCLE:
		weather = weather_override
	var offset = {"clear": 0.0, "rain": -5.0, "cool": -7.0, "heat": 8.0}[weather]
	# Long-term warming approaches the limit; transient weather stays independent.
	temperature = baseline_temperature + warming_pressure() + offset

func warming_pressure() -> float:
	return maxf(warming_limit, 0.0) * (1.0 - exp(-maxf(elapsed, 0.0) / maxf(warming_timescale, 1.0)))

func _simulate(seconds: float):
	var shades: Array[float] = []
	for i in range(_grid.cells.size()):
		shades.append(shade_at(Vector2i(i % _grid.SIZE, floori(float(i) / _grid.SIZE))))
	for i in range(_grid.cells.size()):
		var data: Dictionary = _grid.cells[i]
		var cell = Vector2i(i % _grid.SIZE, floori(float(i) / _grid.SIZE))
		var terrain: String = data.get("terrain", "grass")
		var exposure = 1.0 - shades[i] * 0.7
		var drying = (0.0015 + maxf(temperature - 20.0, 0.0) * 0.00035) * exposure
		var rain = 0.015 if weather == "rain" else (0.0015 if weather == "cool" else 0.0)
		var retention = 0.65 if terrain == "soil" else 1.0
		var water_help = 0.0
		for offset in NEIGHBORS:
			var neighbor = cell + offset
			if _grid.in_bounds(neighbor):
				var adjacent: Dictionary = _grid.cells[neighbor.y * _grid.SIZE + neighbor.x]
				water_help = maxf(water_help, adjacent.get("water_level", 0.0) * 0.0025)
		if terrain == "water":
			data.water_level = clampf(data.water_level + (rain * 0.12 - drying * 0.045) * seconds, 0.0, 1.0)
			data.moisture = maxf(data.water_level, clampf(data.moisture + (rain - drying * 0.2) * seconds, 0.0, 1.0))
		else:
			data.moisture = clampf(data.moisture + (rain + water_help - drying / retention) * seconds, 0.0, 1.0)
		data.trampled = maxf(0.0, data.get("trampled", 0.0) - 0.001 * seconds)
		var stress = maxf(0.28 - data.moisture, 0.0) * 0.022 + maxf(temperature - 36.0, 0.0) * 0.0006 * exposure
		var recovery = 0.006 if data.moisture > 0.35 and temperature < 35.0 else 0.0
		if data.get("burned", false):
			# Char persists through drought. Moist conditions slowly establish new ground cover;
			# exhausted fuel and dead trees remain exhausted/dead.
			data.burn_recovery = clampf(data.get("burn_recovery", 0.0) + (0.002 if recovery > 0.0 else -0.001) * seconds, 0.0, 1.0)
			recovery *= 0.35
		data.health = clampf(data.health + (recovery * (1.0 - data.trampled) - stress) * seconds, 0.0, 1.0)
		if data.get("burned", false):
			data.health = minf(data.health, data.burn_recovery)
		if data.tree and data.tree_state == "healthy":
			data.tree_health = clampf(data.tree_health + (recovery * 0.6 - stress * 0.6) * seconds, 0.0, 1.0)
			if data.tree_health <= 0.0:
				data.tree_state = "dead"
	_simulate_fire(seconds)

func _can_burn(cell: Vector2i) -> bool:
	if not _grid.in_bounds(cell) or cell.distance_to(_grid.start) < 2.5:
		return false
	var data: Dictionary = _grid.cells[cell.y * _grid.SIZE + cell.x]
	return data.get("terrain", "grass") != "water" and not data.burned and data.fuel > 0.05 and data.moisture < 0.32

func _simulate_fire(seconds: float):
	# Read previous flames only: newly lit cells cannot cascade across the map.
	var burning: Array[Vector2i] = []
	for i in range(_grid.cells.size()):
		if _grid.cells[i].burning:
			burning.append(Vector2i(i % _grid.SIZE, floori(float(i) / _grid.SIZE)))
	var spreading: Array[Vector2i] = []
	for cell in burning:
		var data: Dictionary = _grid.cells[cell.y * _grid.SIZE + cell.x]
		if cell.distance_to(_grid.start) < 2.5 or data.terrain == "water" or data.moisture > 0.65:
			data.burning = false
			continue
		data.fire_time += seconds
		data.fuel = maxf(0.0, data.fuel - fuel_consumption * seconds * (2.0 if weather == "rain" else 1.0))
		data.health = maxf(0.0, data.health - 0.12 * seconds)
		if data.tree:
			data.tree_health = maxf(0.0, data.tree_health - 0.09 * seconds)
			if data.tree_health <= 0.0:
				data.tree_state = "dead"
		if data.fuel <= 0.05 or (weather == "rain" and data.fire_time >= 3.0):
			data.burning = false
			# Exhausted fuel never reignites; rain-quenched living ground may recover.
			if data.fuel <= 0.05:
				data.fuel = 0.0
				data.burned = true
				data.health = 0.0
				data.burn_recovery = 0.0
				data.log = false
			continue
		if weather == "rain":
			continue
		for offset in NEIGHBORS:
			var neighbor = cell + offset
			if _can_burn(neighbor) and _fire_rng.randf() < spread_chance * seconds:
				spreading.append(neighbor)
	for cell in spreading:
		_ignite(cell)
	if elapsed >= _next_ignition:
		_next_ignition = elapsed + maxf(ignition_interval, 1.0)
		if elapsed >= ignition_delay and weather in ["clear", "heat"] and temperature >= 32.0 and _fire_rng.randf() < ignition_chance:
			var candidates: Array[Vector2i] = []
			for i in range(_grid.cells.size()):
				var cell = Vector2i(i % _grid.SIZE, floori(float(i) / _grid.SIZE))
				if _can_burn(cell) and not _grid.cells[i].burning:
					candidates.append(cell)
			if not candidates.is_empty():
				_ignite(candidates[_fire_rng.randi_range(0, candidates.size() - 1)])

func _ignite(cell: Vector2i):
	var data: Dictionary = _grid.cells[cell.y * _grid.SIZE + cell.x]
	if not data.burning:
		data.burning = true
		data.fire_time = 0.0

func fire_at(cell: Vector2i) -> float:
	if _grid == null or not _grid.in_bounds(cell) or cell.distance_to(_grid.start) < 2.5:
		return 0.0
	var hazard = 0.0
	for offset in [Vector2i.ZERO, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		var neighbor = cell + offset
		if _grid.in_bounds(neighbor) and _grid.cells[neighbor.y * _grid.SIZE + neighbor.x].burning:
			hazard = maxf(hazard, 1.0 if offset == Vector2i.ZERO else 0.5)
	return hazard

func shade_at(cell: Vector2i) -> float:
	if _grid == null or not _grid.in_bounds(cell):
		return 0.0
	var shade = 0.0
	for offset in [Vector2i.ZERO, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		var neighbor = cell + offset
		if not _grid.in_bounds(neighbor):
			continue
		var data: Dictionary = _grid.cells[neighbor.y * _grid.SIZE + neighbor.x]
		if data.tree and data.get("tree_state", "removed") == "healthy":
			shade += data.get("tree_health", 0.0) * (0.8 if offset == Vector2i.ZERO else 0.3)
	return clampf(shade, 0.0, 0.9)

func trample(cell: Vector2i, amount: float = 0.12):
	if _grid == null or not _grid.in_bounds(cell) or not is_finite(amount) or amount <= 0.0:
		return
	var data: Dictionary = _grid.cells[cell.y * _grid.SIZE + cell.x]
	var damage = clampf(amount, 0.0, 1.0)
	data.trampled = clampf(data.get("trampled", 0.0) + damage, 0.0, 1.0)
	data.health = clampf(data.health - damage, 0.0, 1.0)
