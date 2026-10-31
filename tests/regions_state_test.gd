extends SceneTree

const Regions = preload("res://features/levels/forest/RunRegions.gd")
const GridData = preload("res://features/levels/forest/grid_data.gd")
const Climate = preload("res://features/levels/forest/climate_simulation.gd")
const Interactions = preload("res://features/levels/forest/forest_interactions.gd")
var checks = 0
var failures = 0

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func reachable(grid: RefCounted, target: Vector2i) -> bool:
	var frontier: Array[Vector2i] = [grid.start]
	var seen = {grid.start: true}
	var cursor = 0
	while cursor < frontier.size():
		var cell = frontier[cursor]
		cursor += 1
		if cell == target:
			return true
		for direction in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var neighbor = cell + direction
			if not seen.has(neighbor) and grid.traversable(neighbor):
				seen[neighbor] = true
				frontier.append(neighbor)
	return false

func run() -> void:
	for seed_value in range(80):
		var regions = Regions.new()
		var twin = Regions.new()
		regions.configure(seed_value)
		twin.configure(seed_value)
		check(regions.current_id == "forest" and regions.states.is_empty(), "Fresh runs lazily begin in forest")
		check(regions.seed_for("forest") == seed_value and regions.seed_for("drylands") == seed_value + 104729 and regions.seed_for("wetlands") == seed_value + 209458, "Stable regional seed mapping")
		for id in Regions.IDS:
			var state = regions.get_region(id)
			var second = twin.get_region(id)
			check(state.grid.cells == second.grid.cells and state.climate.temperature == second.climate.temperature, "Regional generation is deterministic: " + id)
			check(not state.visited and state.last_updated == 0.0, "Inspection does not visit a region")
			check(state.grid.cells.size() == 289 and reachable(state.grid, Vector2i(0, 8)) and reachable(state.grid, Vector2i(16, 8)), "Protected central routes reach both regional edges: " + id)
			for from_id in Regions.IDS:
				var arrival = regions.entry(id, from_id)
				check(state.grid.traversable(arrival) and reachable(state.grid, arrival), "Arrival reachable and clear: " + id)
				check(regions.exit_destination(id, arrival).is_empty(), "Arrival cannot immediately bounce: " + id)
			check(regions.get_region(id).grid == state.grid and regions.get_region(id).climate == state.climate, "Cached region preserves model identity")
		check(regions.states.size() == 3 and regions.get_region("ocean").is_empty() and regions.enter("ocean").is_empty() and regions.states.size() == 3, "Only three known ids can be cached")
		check(regions.exit_destination("forest", Vector2i(0, 8)) == "drylands" and regions.exit_destination("forest", Vector2i(16, 8)) == "wetlands", "Forest exits map west and east")
		check(regions.exit_destination("drylands", Vector2i(16, 8)) == "forest" and regions.exit_destination("wetlands", Vector2i(0, 8)) == "forest", "Side regions return through their near edges")
		check(regions.exit_destination("drylands", Vector2i(0, 8)).is_empty() and regions.exit_destination("wetlands", Vector2i(16, 8)).is_empty() and regions.exit_destination("forest", Vector2i(0, 7)).is_empty(), "Other boundary cells do not transition")
		check(regions.entry("drylands", "forest") == Vector2i(15, 8) and regions.entry("wetlands", "forest") == Vector2i(1, 8) and regions.entry("forest", "drylands") == Vector2i(1, 8) and regions.entry("forest", "wetlands") == Vector2i(15, 8), "Round-trip arrivals use the connected edge interior")

	var profiles = Regions.new()
	profiles.configure(2026)
	for id in Regions.IDS:
		var state = profiles.get_region(id)
		var raw_grid = GridData.new()
		raw_grid.generate(profiles.seed_for(id))
		var raw_climate = Climate.new()
		raw_climate.weather_cycle = state.climate.weather_cycle.duplicate()
		raw_climate.configure(raw_grid, profiles.seed_for(id))
		var temperature_offset = 3.0 if id == "drylands" else -2.0 if id == "wetlands" else 0.0
		check(is_equal_approx(state.climate.temperature, raw_climate.temperature + temperature_offset), "Regional temperature offset is active immediately: " + id)
		for index in range(raw_grid.cells.size()):
			var actual: Dictionary = state.grid.cells[index]
			var raw: Dictionary = raw_grid.cells[index]
			var moisture: float = raw.moisture * 0.55 if id == "drylands" else minf(1.0, raw.moisture + 0.15) if id == "wetlands" else raw.moisture
			var health: float = raw.health * 0.6 if id == "drylands" else raw.health
			var tree_health: float = raw.tree_health * 0.8 if id == "drylands" else raw.tree_health
			if raw.tree and not actual.tree:
				tree_health = 0.0
				check(actual.tree_state == "removed", "Drinking approach removes its tree canopy consistently")
			if id == "wetlands" and index == 5 * 17 + 8:
				health = 0.45
				moisture = maxf(moisture, 0.7)
			check(is_equal_approx(actual.moisture, moisture) and is_equal_approx(actual.health, health) and is_equal_approx(actual.tree_health, tree_health), "Regional appearance follows actual initialized vegetation/soil state")
		check(raw_climate.baseline_temperature == 24.0, "Regional profiles do not mutate global climate defaults")
	check(profiles.palette_for("forest") != profiles.palette_for("drylands") and profiles.palette_for("forest") != profiles.palette_for("wetlands"), "Regional terrain palettes are distinct")
	var habitat_state = profiles.get_region("wetlands")
	var habitat: Dictionary = habitat_state.grid.cells[5 * 17 + 8]
	check(habitat.health == 0.45 and habitat.recovery_low == 0.45 and habitat.moisture >= 0.7 and habitat_state.grid.traversable(Vector2i(8, 5)), "Wetlands habitat starts visibly stressed and reachable")
	habitat_state.climate.tick(15.0)
	check(habitat.health > habitat.recovery_low + 0.08, "Wet habitat genuinely recovers through fifteen simulation seconds")
	for seed_value in [-9223372036854775807, -7, 0, 2147483646, 9223372036854775807]:
		profiles.configure(seed_value)
		check(profiles.seed_for("forest") == seed_value and profiles.seed_for("drylands") >= 0 and profiles.seed_for("wetlands") >= 0 and profiles.seed_for("wetlands") < Regions.SEED_MODULUS, "Extreme and negative run seeds keep stable positive derived seeds")

	var regions = Regions.new()
	regions.configure(456)
	var forest = regions.enter("forest")
	var original_grid: RefCounted = forest.grid
	var original_climate: RefCounted = forest.climate
	var survival: RefCounted = regions.survival
	var objectives: RefCounted = regions.objectives
	regions.survival.health = 73.0
	regions.survival.exposure = 42.0
	regions.objectives.observe_problem()
	# Exercise real interaction mutations rather than a second region snapshot.
	var player = Vector2i(2, 3)
	var stump = Vector2i(3, 3)
	var landing = Vector2i(4, 3)
	for position in [player, stump, landing]:
		var data: Dictionary = forest.grid.cells[position.y * 17 + position.x]
		data.tree = false
		data.tree_state = "removed"
		data.log = false
		data.terrain = "grass"
		data.water_level = 0.0
		data.burning = false
	var tree_data: Dictionary = forest.grid.cells[stump.y * 17 + stump.x]
	tree_data.tree = true
	tree_data.tree_state = "healthy"
	tree_data.tree_health = 1.0
	var interactions = Interactions.new()
	interactions.configure(forest.grid)
	check(interactions.begin(player, Vector2i.RIGHT) and interactions.tick(2.0, player).get("kind") == "tree_cut", "Real tree cut produces regional stump and log")
	forest.cut_cells[stump] = true
	var water: Dictionary = forest.grid.cells[1 * 17 + 1]
	water.terrain = "water"
	water.water_level = 0.47
	var saved_cells: Array = forest.grid.cells.duplicate(true)
	regions.enter("drylands")
	var returned = regions.enter("forest")
	check(returned.grid == original_grid and returned.climate == original_climate and returned.grid.cells == saved_cells, "Immediate round-trip retains original models and every cell value")
	check(returned.cut_cells.has(stump) and tree_data.tree_state == "stump" and returned.grid.cells[landing.y * 17 + landing.x].log and water.water_level == 0.47, "Stump/log/cut-history/water survive region reload")
	check(regions.survival == survival and survival.health == 73.0 and survival.exposure == 42.0 and regions.objectives == objectives and objectives.problem_seen, "Run survival and objective models are shared across regions")
	check(interactions.begin(player, Vector2i.RIGHT) and interactions.tick(2.0, player).get("kind") == "stump_removed", "Returned stump remains interactable")
	regions.enter("wetlands")
	regions.enter("forest")
	check(not tree_data.tree and tree_data.tree_state == "removed" and forest.grid.traversable(stump), "Cleared stump stays removed on another return")

	# A twin advances the same live climate in exactly the bounded one-second steps.
	var reference_grid = GridData.new()
	reference_grid.cells = forest.grid.cells.duplicate(true)
	var reference_climate = Climate.new()
	reference_climate.configure(reference_grid, regions.seed_for("forest"))
	reference_grid.cells = forest.grid.cells.duplicate(true)
	regions.enter("drylands")
	regions.advance(200.5)
	check(forest.climate.elapsed == 0.0 and forest.last_updated == 0.0, "Inactive regions receive no background tick")
	check(regions.elapsed == 200.5 and regions.get_region("drylands").last_updated == 200.5, "Active run clock marks only the active region")
	for index in range(30):
		reference_climate.tick(1.0)
	var began = Time.get_ticks_usec()
	regions.enter("forest")
	var catchup_ms = (Time.get_ticks_usec() - began) / 1000.0
	check(forest.climate.elapsed == 30.0 and forest.climate.tick_count == 30 and forest.last_updated == 200.5, "Inactive catch-up consumes at most thirty one-second steps")
	check(forest.grid.cells == reference_grid.cells and forest.climate.temperature == reference_climate.temperature, "Catch-up uses live seeded climate state and deterministic one-second evolution")
	check(catchup_ms < 2000.0, "Bounded regional catch-up finishes within two seconds")
	regions.enter("drylands")
	regions.enter("forest")
	check(forest.climate.elapsed == 30.0, "Repeated transition cannot charge discarded catch-up backlog")
	regions.enter("wetlands")
	regions.advance(2.5)
	regions.enter("forest")
	check(forest.climate.elapsed == 32.5 and forest.climate.tick_count == 33, "Fractional inactivity is integrated without rounding")
	check(regions.survival.health == 73.0 and regions.survival.exposure == 42.0, "Inactive catch-up cannot apply offscreen player damage")
	var before: Array = forest.grid.cells.duplicate(true)
	var before_elapsed: float = regions.elapsed
	var climate_elapsed: float = forest.climate.elapsed
	await process_frame
	await process_frame
	check(regions.elapsed == before_elapsed and forest.climate.elapsed == climate_elapsed and forest.grid.cells == before, "No wall clock or process callback advances a paused run")
	for seconds in [-1.0, 0.0, NAN, INF]:
		regions.advance(seconds)
	check(regions.elapsed == before_elapsed, "Invalid advance values cannot corrupt the run clock")
	# Compare a fire-capable live RNG before and after leaving/re-entering.
	var fire_run = Regions.new()
	var fire_twin = Regions.new()
	fire_run.configure(2026)
	fire_twin.configure(2026)
	var fire_forest = fire_run.enter("forest")
	var fire_reference = fire_twin.enter("forest")
	for state in [fire_forest, fire_reference]:
		state.climate.baseline_temperature = 45.0
		state.climate.ignition_delay = 1.0
		state.climate.ignition_interval = 1.0
		state.climate.ignition_chance = 1.0
		state.climate.spread_chance = 0.5
		state.climate.configure(state.grid, 2026)
	while fire_forest.climate.weather in ["rain", "cool"]:
		fire_forest.climate.tick(30.0)
		fire_reference.climate.tick(30.0)
		fire_run.advance(30.0)
	for state in [fire_forest, fire_reference]:
		for data in state.grid.cells:
			data.moisture = 0.05
	fire_forest.climate.tick(1.0)
	fire_reference.climate.tick(1.0)
	fire_run.advance(1.0)
	var flames = 0
	for data in fire_forest.grid.cells:
		flames += 1 if data.burning else 0
	check(flames > 0, "RNG preservation scenario exercises actual ignition")
	fire_run.enter("drylands")
	fire_run.advance(30.0)
	for index in range(30):
		fire_reference.climate.tick(1.0)
	fire_run.enter("forest")
	check(fire_forest.grid.cells == fire_reference.grid.cells, "Fire spread/ignition RNG remains deterministic through inactive catch-up")
	for index in range(10):
		fire_forest.climate.tick(1.0)
		fire_reference.climate.tick(1.0)
	check(fire_forest.grid.cells == fire_reference.grid.cells, "Fire RNG continues from its retained state after returning")
	var old_survival: RefCounted = regions.survival
	var old_objectives: RefCounted = regions.objectives
	regions.configure(999)
	check(regions.states.is_empty() and regions.current_id == "forest" and regions.elapsed == 0.0 and regions.survival != old_survival and regions.objectives != old_objectives and regions.survival.health == 100.0 and not regions.objectives.problem_seen, "New attempts reset temporary regional and run state")
	print("REGIONS_STATE: ", checks, " checks, ", failures, " failures; catch-up ", catchup_ms, " ms")
	quit(0 if failures == 0 else 1)
