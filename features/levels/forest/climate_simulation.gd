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
var regeneration_occupied = Vector2i(-1,-1)
var growth_occupied: Array[Vector2i] = [] # Active player footprint; not persistent state.
var _regeneration_rng = RandomNumberGenerator.new()
var _regeneration_clock = 0.0
var _tree_limit = 0
var bonfire_intensity = 0.0 # Synced from the region; affects soil only.
var recycled_trash: int = 0
var initial_tree_count: int = 0
var initial_trash_count: int = 0
var planet_health: float = 50.0
var ecosystem_demo = false # Debug weather schedule; all effects still use simulation rules.
var sapling_growth_rate = 1.0 # Debug-only acceleration affects plants, not simulation time.
var elapsed = 0.0
var temperature = 24.0
var weather: String = "clear"
# Empty uses seeded weather; named conditions are also useful for bounded scenarios.
var weather_override: String = ""
var weather_cycle: Array = WEATHER_CYCLE.duplicate()
var tick_count = 0
var _grid: RefCounted
var _weather_offset = 0
var _wind_phase = 0.0
var _fire_rng = RandomNumberGenerator.new()
var _next_ignition = 120.0

func configure(grid: RefCounted, world_seed: int, wind_seed: int = -1):
	_grid = grid
	_wind_phase = float(posmod(world_seed if wind_seed < 0 else wind_seed,10007))/10007.0*TAU
	elapsed = 0.0
	tick_count = 0
	_next_ignition = maxf(ignition_delay, 1.0)
	_fire_rng.seed = world_seed ^ 0xF13E
	_regeneration_rng.seed = world_seed ^ 0x79A13
	_regeneration_clock = 0.0
	_tree_limit = mini(int(grid.cells.size()*0.32),grid.cells.filter(func(data): return data.tree).size()+12)
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
		data.water = data.get("water", false) or data.get("terrain", "grass") == "water"
		data.water_depth = data.get("water_depth", 1.0 if data.water else 0.0)
		data.tilled = data.get("tilled", false)
		data.water_needed = data.get("water_needed", 1.0)
	initial_tree_count = _grid.cells.filter(func(data): return data.tree and data.get("tree_state", "healthy") == "healthy").size()
	recycled_trash = 0
	initial_trash_count = _grid.trash_cells.size() if "trash_cells" in _grid else 0
	planet_health = calculate_planet_health()
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
	var cycle = weather_cycle if not weather_cycle.is_empty() else WEATHER_CYCLE
	weather = cycle[(floori(elapsed / WEATHER_SECONDS) + _weather_offset) % cycle.size()]
	if weather_override in WEATHER_CYCLE:
		weather = weather_override
	var offset = {"clear": 0.0, "rain": -5.0, "cool": -7.0, "heat": 8.0}[weather]
	if weather == "heat" and planet_health >= 70.0:
		var heat_reduction = clampf((planet_health - 70.0) / 20.0, 0.0, 1.0)
		offset = lerpf(8.0, 3.0, heat_reduction)
	if ecosystem_demo:
		weather = "rain" if elapsed >= 120.0 and elapsed < 240.0 else "clear"
		offset = {"clear":0.0,"rain":-5.0}[weather]
	# Long-term warming approaches the limit; transient weather stays independent.
	temperature = baseline_temperature + warming_pressure() + offset

func warming_pressure() -> float:
	var raw = maxf(warming_limit, 0.0) * (1.0 - exp(-maxf(elapsed, 0.0) / maxf(warming_timescale, 1.0)))
	if planet_health <= 40.0:
		return raw
	var restoration = (planet_health - 40.0) / 35.0
	if restoration < 1.0:
		return raw * (1.0 - restoration)
	else:
		var extra_cooling = minf((restoration - 1.0) * 2.5, 2.5)
		return -extra_cooling

func calculate_planet_health() -> float:
	if _grid == null or _grid.cells.is_empty():
		return 30.0
	var healthy_trees = 0
	var player_planted_trees = 0
	var current_trash = 0
	var total_vegetation = 0.0
	var total_cells = _grid.cells.size()
	for data in _grid.cells:
		if data.tree:
			if data.get("tree_state", "removed") == "healthy":
				healthy_trees += 1
				if data.get("planted", false) and not data.get("natural", false):
					player_planted_trees += 1
			elif data.get("tree_state", "") == "sapling":
				total_vegetation += 0.3 * data.get("tree_health", 0.5)
		if data.get("trash", false):
			current_trash += 1
		total_vegetation += float(data.get("health", 0.0))
	var avg_veg = total_vegetation / float(total_cells)
	var score = avg_veg * 25.0
	var base_trees = maxf(float(initial_tree_count), 20.0)
	var tree_ratio = clampf(float(healthy_trees) / base_trees, 0.0, 1.0)
	score += tree_ratio * 20.0
	score += minf(float(player_planted_trees) * 6.0, 30.0)
	var cleared_trash = max(0, initial_trash_count - current_trash)
	score += float(cleared_trash) * 3.0
	score += float(recycled_trash) * 6.0
	score -= float(current_trash) * 4.0
	return clampf(score, 0.0, 100.0)

func _simulate(seconds: float):
	var shades: Array[float] = []
	for i in range(_grid.cells.size()):
		shades.append(shade_at(Vector2i(i % _grid.SIZE, floori(float(i) / _grid.SIZE))))
	for i in range(_grid.cells.size()):
		var data: Dictionary = _grid.cells[i]
		var cell = Vector2i(i % _grid.SIZE, floori(float(i) / _grid.SIZE))
		var terrain: String = data.get("terrain", "grass")
		var has_trash: bool = data.get("trash", false)
		var camp = bonfire_influence_at(cell)
		var local_temperature = temperature - shades[i] * 4.0 + camp * 3.5 + (2.0 if has_trash else 0.0)
		var exposure = 1.0 - shades[i] * 0.7
		var drying = (0.0015 + maxf(local_temperature - 20.0, 0.0) * 0.00035) * exposure + camp * 0.003 + (0.0035 if has_trash else 0.0)
		var rain = 0.015 if weather == "rain" else (0.0015 if weather == "cool" else 0.0)
		var retention = 0.65 if terrain == "soil" else 1.0
		var water_help = 0.0
		for offset in NEIGHBORS:
			var neighbor = cell + offset
			if _grid.in_bounds(neighbor):
				var adjacent: Dictionary = _grid.cells[neighbor.y * _grid.SIZE + neighbor.x]
				water_help = maxf(water_help, adjacent.get("water_level", 0.0) * 0.0025)
		if terrain == "water" or data.get("water", false):
			var cur_water = float(data.water_depth if data.get("water", false) else data.get("water_level", 1.0))
			cur_water = clampf(cur_water + (rain * 0.12 - drying * 0.045) * seconds, 0.0, 1.0)
			data.water_level = cur_water
			data.water_depth = cur_water
			data.moisture = maxf(cur_water, clampf(data.moisture + (rain - drying * 0.2) * seconds, 0.0, 1.0))
		else:
			data.moisture = clampf(data.moisture + (rain + water_help - drying / retention) * seconds, 0.0, 1.0)
		data.trampled = maxf(0.0, data.get("trampled", 0.0) - 0.001 * seconds)
		if has_trash:
			data.health = maxf(0.0, data.health - 0.015 * seconds)
		var stress = maxf(0.28 - data.moisture, 0.0) * 0.022 + maxf(local_temperature - 36.0, 0.0) * 0.0006 * exposure
		var recovery = 0.006 if data.moisture > 0.35 and local_temperature < 35.0 and not has_trash else 0.0
		if data.get("burned", false):
			# Char persists through drought. Moist conditions slowly establish new ground cover;
			# exhausted fuel and dead trees remain exhausted/dead.
			data.burn_recovery = clampf(data.get("burn_recovery", 0.0) + (0.002 if recovery > 0.0 else -0.001) * seconds, 0.0, 1.0)
			recovery *= 0.35
		data.health = clampf(data.health + (recovery * (1.0 - data.trampled) - stress) * seconds, 0.0, 1.0)
		if data.get("burned", false):
			data.health = minf(data.health, data.burn_recovery)
		if data.tree and data.tree_state == "seed":
			if data.moisture > 0.35 and local_temperature >= 8.0 and local_temperature <= 34.0 and not data.burning and not data.burned:
				var hydration = (0.15 if weather == "rain" else maxf(data.moisture-0.3,0.0)*0.14)*seconds
				data.water_needed = maxf(0.0,data.get("water_needed",1.0)-hydration)
				if data.water_needed <= 0.0:
					data.tree_state = "sapling"
					data.tree_health = 0.25
					data.growth_age = 0.0
			else:
				data.tree_health = maxf(0.0,data.tree_health-stress*seconds)
				if data.tree_health <= 0.0: data.tree_state = "dead"
		elif data.tree and data.tree_state == "sapling":
			var favorable = data.moisture > 0.35 and local_temperature >= 8.0 and local_temperature <= 34.0 and not data.get("burning", false) and not data.get("burned", false)
			if favorable:
				data.growth_age += seconds * sapling_growth_rate
				data.tree_health = minf(1.0, data.tree_health + (0.48 / preload("res://features/levels/forest/StatePlanting.gd").GROWTH_SECONDS) * seconds * sapling_growth_rate)
			else:
				data.tree_health = maxf(0.0, data.tree_health - (stress + (0.003 if local_temperature < 3.0 else 0.0)) * seconds)
			if data.tree_health <= 0.0:
				if not growth_occupied.has(cell): data.tree_state = "dead"
			elif data.get("growth_age", 0.0) >= preload("res://features/levels/forest/StatePlanting.gd").GROWTH_SECONDS and not growth_occupied.has(cell):
				data.tree_state = "healthy"
				data.fuel = 1.0
		if data.tree and data.tree_state == "healthy":
			data.tree_health = clampf(data.tree_health + (recovery * 0.6 - stress * 0.6) * seconds, 0.0, 1.0)
			if data.tree_health <= 0.0:
				data.tree_state = "dead"
			elif data.tree_health > 0.5:
				for offset in NEIGHBORS:
					var neighbor = cell + offset
					if _grid.in_bounds(neighbor):
						var adj_data: Dictionary = _grid.cells[neighbor.y * _grid.SIZE + neighbor.x]
						adj_data.moisture = minf(1.0, adj_data.moisture + 0.0006 * seconds)
		if data.tree and data.tree_state == "healthy" and data.tree_health > 0.75 and data.moisture > 0.5 and local_temperature >= 8.0 and local_temperature <= 32.0 and not data.burning:
			data.regeneration_credit = minf(180.0,data.get("regeneration_credit",0.0)+seconds)
		else:
			data.regeneration_credit = maxf(0.0,data.get("regeneration_credit",0.0)-seconds*0.5)
	_regeneration_clock += seconds
	if _regeneration_clock >= 30.0:
		_regeneration_clock -= 30.0
		_reproduce_tree()
	_simulate_fire(seconds)
	planet_health = calculate_planet_health()

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
				if data.tree and data.get("planted", false):
					data.tree_health = 0.0
					data.tree_state = "dead"
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
			if (data.get("water", false) or data.get("terrain", "") == "water") and maxf(float(data.get("water_depth", 0.0)), float(data.get("water_level", 0.0))) > 0.15:
				var dist = cell.distance_to(neighbor)
				if dist <= 2.2:
					var depth = maxf(float(data.get("water_depth", 1.0)), float(data.get("water_level", 1.0)))
					cooling = maxf(cooling, depth * (1.0 - dist / 2.5))
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

# Read-only conditions for interaction/vegetation integrations. Returned values
# are a snapshot; authoritative cell state stays in GridData.
func cell_conditions(cell: Vector2i) -> Dictionary:
	if _grid == null or not _grid.in_bounds(cell):
		return {}
	var data = _grid.cells[cell.y * _grid.SIZE + cell.x]
	return {"temperature": temperature_at(cell), "regional_temperature": temperature, "weather": weather, "moisture": data.moisture,
		"health": data.health, "tree_health": data.tree_health, "tree_state": data.tree_state, "burning": data.burning,
		"terrain": data.terrain, "water_level": data.water_level,
		"canopy": shade_at(cell), "fire_hazard": fire_at(cell)}

func temperature_at(cell: Vector2i) -> float:
	var trash_heat = 2.0 if (_grid != null and _grid.in_bounds(cell) and _grid.cells[cell.y * _grid.SIZE + cell.x].get("trash", false)) else 0.0
	return temperature - shade_at(cell) * 4.0 + bonfire_influence_at(cell) * 3.5 + trash_heat

# The rendered fire is offset within the camp tile. No ignition or player damage.
func bonfire_influence_at(cell: Vector2i) -> float:
	if not _grid.in_bounds(cell): return 0.0
	if _grid.cells[cell.y*_grid.SIZE+cell.x].terrain == "water": return 0.0
	var fire = _grid.world_position(_grid.start) + Vector3(0.6,0,0.6)
	var distance = _grid.world_position(cell).distance_to(fire)
	return (1.0-smoothstep(0.3,3.2,distance))*clampf(bonfire_intensity,0.0,1.0)

# Stable presentation API for future hazards. Direction means travel TOWARDS,
# world X east / Z south. Strength is normalized, not calibrated metres/second.
# Pure sampling: no RNG consumption, moisture, survival or hazard side effects.
func wind_state(fractional_seconds: float = 0.0, run_seconds: float = -1.0) -> Dictionary:
	var time = (elapsed if run_seconds < 0.0 else run_seconds) + clampf(fractional_seconds,0.0,1.0)
	var angle = _wind_phase + 0.55*sin(time*0.009+_wind_phase)
	var strength = 0.55 + 0.17*sin(time*0.055+_wind_phase) + 0.08*sin(time*0.17+_wind_phase)
	return {"direction":Vector2(cos(angle),sin(angle)),"strength":strength,"time":time}


func _reproduce_tree():
	var living = _grid.cells.filter(func(data): return data.tree)
	if living.size() >= _tree_limit or living.filter(func(data): return data.get("natural",false)).size() >= 12: return
	var parents: Array[int] = []
	for i in range(_grid.cells.size()):
		var data: Dictionary = _grid.cells[i]
		if data.tree and data.tree_state == "healthy" and data.tree_health > 0.75 and data.moisture > 0.5 and not data.burning and data.get("regeneration_credit",0.0) >= 90.0: parents.append(i)
	while not parents.is_empty():
		var pick = _regeneration_rng.randi_range(0,parents.size()-1)
		var i = parents.pop_at(pick)
		var parent = Vector2i(i%_grid.SIZE,i/_grid.SIZE)
		var offsets = [Vector2i(-2,0),Vector2i(2,0),Vector2i(0,-2),Vector2i(0,2),Vector2i(-1,-1),Vector2i(1,-1),Vector2i(-1,1),Vector2i(1,1),Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]
		while not offsets.is_empty():
			var cell = parent+offsets.pop_at(_regeneration_rng.randi_range(0,offsets.size()-1))
			if not _can_regenerate(cell): continue
			var data: Dictionary = _grid.cells[cell.y*_grid.SIZE+cell.x]
			data.merge({"tree":true,"tree_state":"sapling","tree_health":0.35,"planted":true,"natural":true,"growth_age":0.0,"growth_discovered":true,"seed_yield_claimed":true,"fuel":0.15},true)
			_grid.cells[i].regeneration_credit = 0.0
			return # At most one new seedling per region per thirty seconds.

func _can_regenerate(cell: Vector2i) -> bool:
	if not _grid.in_bounds(cell) or _grid._protected_route(cell) or cell == _grid.objective or cell == regeneration_occupied: return false
	var data: Dictionary = _grid.cells[cell.y*_grid.SIZE+cell.x]
	if data.get("spaceship", false) or _grid.SPACESHIP_CELLS.has(cell) or data.get("recycle_bin", false) or data.get("trash", false) or cell == _grid.recycle_bin_cell: return false
	if data.tree or data.get("log",false) or data.get("prepared",false) or data.get("berry_bush",false) or data.get("protected_route",false) or data.get("pending_seeds",0)>0: return false
	if data.terrain == "water" or data.burning or data.burned or data.health < 0.55 or data.moisture <= 0.5: return false
	# Matches the existing decorative-rock reservation, including inactive regions.
	if data.shade >= 0.32 and data.shade <= 0.36: return false
	var local_temperature = temperature_at(cell)
	if local_temperature < 8.0 or local_temperature > 32.0: return false
	var neighbors = 0
	for offset in NEIGHBORS:
		var next = cell+offset
		if _grid.in_bounds(next) and _grid.cells[next.y*_grid.SIZE+next.x].tree: neighbors += 1
	if neighbors > 2: return false
	# Do not cut off any previously reachable walkable tile, including pond access.
	var before = _reachable_count(Vector2i(-1,-1))
	return _reachable_count(cell) == before-1

func _reachable_count(blocked: Vector2i) -> int:
	var queue = [_grid.start]
	var visited = {_grid.start:true}
	while not queue.is_empty():
		var cell = queue.pop_back()
		for offset in NEIGHBORS:
			var next = cell+offset
			if next != blocked and not visited.has(next) and _grid.traversable(next):
				visited[next] = true
				queue.append(next)
	return visited.size()

# Small upwind stencil; shelter modifies vegetation exposure only, not weather.
func wind_exposure_at(cell: Vector2i, direction: Vector2) -> float:
	var exposure = 1.0
	for z in range(-2,3):
		for x in range(-2,3):
			var offset = Vector2i(x,z)
			var source = cell+offset
			if offset == Vector2i.ZERO or not _grid.in_bounds(source): continue
			var along = -Vector2(offset).dot(direction)
			var across = absf(Vector2(offset).cross(direction))
			if along <= 0.0 or across > 0.55+along*0.25: continue
			var data: Dictionary = _grid.cells[source.y*_grid.SIZE+source.x]
			if not data.tree or data.tree_state == "stump" or data.burning: continue
			var maturity = clampf(data.get("growth_age",120.0)/120.0,0.0,1.0)
			var canopy = 0.08 if data.tree_state == "dead" else data.tree_health*maturity*maturity
			exposure *= 1.0-canopy*0.6/(1.0+(along-1.0)*0.5)
	return clampf(exposure,0.25,1.0)

func wind_exposure_map(run_seconds: float) -> PackedVector4Array:
	var direction: Vector2 = wind_state(0.0,run_seconds).direction
	var values = PackedVector4Array()
	var group = Vector4.ONE
	for i in range(_grid.cells.size()):
		group[i%4] = wind_exposure_at(Vector2i(i%_grid.SIZE,i/_grid.SIZE),direction)
		if i%4 == 3 or i == _grid.cells.size()-1:
			values.append(group)
			group = Vector4.ONE
	return values
