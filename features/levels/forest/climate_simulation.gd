extends RefCounted

# One call consumes at most 30 simulation seconds; excess time is discarded so a
# stalled frame or malformed caller cannot create an unbounded catch-up workload.
const MAX_TICK_SECONDS = 30.0
const WEATHER_SECONDS = 60.0
const WEATHER_CYCLE = ["clear", "rain", "cool", "heat"]
var elapsed = 0.0
var temperature = 24.0
var weather: String = "clear"
var tick_count = 0
var _grid: RefCounted
var _weather_offset = 0

func configure(grid: RefCounted, world_seed: int):
	_grid = grid
	elapsed = 0.0
	tick_count = 0
	var rng = RandomNumberGenerator.new()
	rng.seed = world_seed
	_weather_offset = rng.randi_range(0, 3)
	for data in _grid.cells:
		data.moisture = 1.0 if data.get("water", false) else rng.randf_range(0.55, 0.8)
		data.health = 1.0
		data.tree_health = 1.0 if data.tree else 0.0
		data.tree_state = "healthy" if data.tree else "removed"
		data.trampled = 0.0
		data.water = data.get("water", false)
		data.water_depth = data.get("water_depth", (1.0 if data.water else 0.0))
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
	var offset = {"clear": 0.0, "rain": -5.0, "cool": -7.0, "heat": 8.0}[weather]
	temperature = clampf(24.0 + elapsed * 0.025 + offset, 0.0, 60.0)

func _simulate(seconds: float):
	# Snapshot shade first so vegetation updates do not depend on traversal order.
	var shades: Array[float] = []
	for i in range(_grid.cells.size()):
		shades.append(shade_at(Vector2i(i % _grid.SIZE, floori(float(i) / _grid.SIZE))))
	for i in range(_grid.cells.size()):
		var data: Dictionary = _grid.cells[i]
		if data.get("water", false):
			var rain_inflow = 0.05 if weather == "rain" else (0.008 if weather == "cool" else 0.0)
			var evaporation = (0.0035 + maxf(temperature - 26.0, 0.0) * 0.0014) * (1.6 if weather == "heat" else 0.8)
			data.water_depth = clampf(data.get("water_depth", 1.0) + (rain_inflow - evaporation) * seconds, 0.0, 1.0)
			data.moisture = clampf(data.water_depth, 0.1, 1.0)
			data.health = 1.0
			continue
		var exposure = 1.0 - shades[i] * 0.7
		var drying = (0.0015 + maxf(temperature - 20.0, 0.0) * 0.00035) * exposure
		var rain = 0.015 if weather == "rain" else (0.001 if weather == "cool" else 0.0)
		data.moisture = clampf(data.moisture + (rain - drying) * seconds, 0.0, 1.0)
		data.trampled = maxf(0.0, data.get("trampled", 0.0) - 0.001 * seconds)
		var stress = maxf(0.28 - data.moisture, 0.0) * 0.022 + maxf(temperature - 34.0, 0.0) * 0.0008 * exposure
		var recovery = 0.006 if data.moisture > 0.35 and temperature < 33.0 else 0.0
		data.health = clampf(data.health + (recovery * (1.0 - data.trampled) - stress) * seconds, 0.0, 1.0)
		if data.tree:
			if data.tree_state == "healthy":
				data.tree_health = clampf(data.tree_health + (recovery * 0.6 - stress * 0.6) * seconds, 0.0, 1.0)
				if data.tree_health <= 0.0:
					data.tree_state = "dead"
			elif data.tree_state == "sapling":
				if data.moisture > 0.35 and temperature < 34.0:
					data.tree_health = minf(data.tree_health + 0.03 * seconds, 1.0)
					if data.tree_health >= 0.95:
						data.tree_state = "healthy"
				else:
					data.tree_health = maxf(data.tree_health - stress * 0.8 * seconds, 0.0)
					if data.tree_health <= 0.0:
						data.tree_state = "dead"

func water_proximity(cell: Vector2i) -> float:
	if _grid == null or not _grid.in_bounds(cell):
		return 0.0
	var cooling = 0.0
	for dy in range(-2, 3):
		for dx in range(-2, 3):
			var neighbor = cell + Vector2i(dx, dy)
			if not _grid.in_bounds(neighbor):
				continue
			var data: Dictionary = _grid.cells[neighbor.y * _grid.SIZE + neighbor.x]
			if data.get("water", false) and data.get("water_depth", 0.0) > 0.15:
				var dist = cell.distance_to(neighbor)
				if dist <= 2.2:
					cooling = maxf(cooling, data.water_depth * (1.0 - dist / 2.5))
	return clampf(cooling, 0.0, 0.85)

func shade_at(cell: Vector2i) -> float:
	if _grid == null or not _grid.in_bounds(cell):
		return 0.0
	var shade = 0.0
	for offset in [Vector2i.ZERO, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		var neighbor = cell + offset
		if not _grid.in_bounds(neighbor):
			continue
		var data: Dictionary = _grid.cells[neighbor.y * _grid.SIZE + neighbor.x]
		if data.tree:
			var state = data.get("tree_state", "removed")
			if state == "healthy":
				shade += data.get("tree_health", 0.0) * (0.8 if offset == Vector2i.ZERO else 0.3)
			elif state == "sapling":
				shade += data.get("tree_health", 0.0) * 0.4 * (0.8 if offset == Vector2i.ZERO else 0.3)
	var cooling = water_proximity(cell) * 0.4
	return clampf(shade + cooling, 0.0, 0.9)

func trample(cell: Vector2i, amount: float = 0.12):
	if _grid == null or not _grid.in_bounds(cell) or not is_finite(amount) or amount <= 0.0:
		return
	var data: Dictionary = _grid.cells[cell.y * _grid.SIZE + cell.x]
	var damage = clampf(amount, 0.0, 1.0)
	data.trampled = clampf(data.get("trampled", 0.0) + damage, 0.0, 1.0)
	data.health = clampf(data.health - damage, 0.0, 1.0)
