extends SceneTree
## Full scene regression; no default settings or progression files are written.
const Regions = preload("res://features/levels/forest/RunRegions.gd")
const DIRECTIONS = [Vector2i.LEFT, Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN]
const TEST_SAVE = "user://survival_gameplay_v3_test.json"
const TEST_SETTINGS = "user://survival_gameplay_v3_settings.cfg"
var checks := 0
var failures := 0
var flow: Node

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func _clean() -> void:
	for path in [TEST_SAVE, TEST_SAVE + ".tmp", TEST_SETTINGS]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)

func _shore(grid: RefCounted) -> Dictionary:
	var queue: Array[Vector2i] = [grid.start]
	var distance := {grid.start: 0}
	var cursor := 0
	while cursor < queue.size():
		var cell: Vector2i = queue[cursor]
		cursor += 1
		for offset in DIRECTIONS:
			var next: Vector2i = cell + offset
			if not grid.in_bounds(next): continue
			var data: Dictionary = grid.cells[next.y * grid.SIZE + next.x]
			if data.terrain == "water" and data.water_level > 0.1 and not grid.cells[cell.y * grid.SIZE + cell.x].get("berry_bush", false):
				return {"cell": cell, "pond": next, "steps": distance[cell]}
			if grid.traversable(next) and not distance.has(next):
				distance[next] = distance[cell] + 1
				queue.append(next)
	return {}

func _place(world: Node, cell: Vector2i, facing: Vector2i = Vector2i.UP) -> void:
	var player = world.get_node("GridPlayer")
	player.cell = cell
	player.position = world.grid.world_position(cell)
	player.facing = facing
	player.moving = false
	world._update_interaction_marker()

func _freeze(world: Node) -> void:
	world.set_process(false)
	world.get_node("GridPlayer").set_process(false)
	world.get_node("CameraRig").set_process(false)

func _seconds(world: Node, count: int) -> void:
	for i in range(count):
		world._process(1.0)

func _reset_survival(world: Node) -> void:
	world.survival.health = 100.0
	world.survival.hunger = 10.0
	world.survival.thirst = 10.0
	world.survival.body_temperature = 37.0
	world.survival.wetness = 0.0
	world.survival.dead = false
	world.tick_accumulator = 0.0

func _travel(destination: String) -> Node:
	check(flow.change_region(destination) == OK, "Connected regional transition succeeds")
	await process_frame
	await process_frame
	_freeze(current_scene)
	return current_scene

func run() -> void:
	_clean()
	var saves = root.get_node("SaveManager")
	var settings = root.get_node("SettingsManager")
	saves.storage_path = TEST_SAVE
	saves.load_progression()
	settings.storage_path = TEST_SETTINGS
	settings.bindings = settings.DEFAULT_BINDINGS.duplicate(true)
	settings.apply_settings()
	for seed_value in range(80):
		var models := Regions.new()
		models.configure(seed_value)
		var state: Dictionary = models.get_region("forest")
		var shore := _shore(state.grid)
		check(not shore.is_empty(), "Seed %d has a reachable freshwater shore" % seed_value)
		if not shore.is_empty():
			check(shore.steps < 30, "Seed %d reaches freshwater within early survival window" % seed_value)
		check(state.grid.traversable(Vector2i(6,8)) and state.grid.cells[8 * state.grid.SIZE + 6].berry_bush, "Seed %d guarantees early food two steps from spawn" % seed_value)
	flow = root.get_node("SceneFlow")
	flow.next_seed = 2026
	flow.run_regions = null
	flow.region_arrival_from = ""
	flow.camera_state.clear()
	check(flow.transition(flow.playable_scene) == OK, "Playable forest scene loads")
	await process_frame
	await process_frame
	var world = current_scene
	_freeze(world)
	var berry := Vector2i(6,8)
	_place(world, berry)
	check(world.selected_interaction.object_kind == "berries" and world.selected_interaction.cell == berry, "Marker and prompt select guaranteed berry bush")
	check(world.hud.get_node("Context").text.contains("Harvest"), "Selected bush names its harvest action")
	check(settings.rebind("interact", 0, KEY_K) == "", "Interact can be rebound in isolated settings")
	world._update_interaction_marker()
	check(world.hud.get_node("Context").text.contains("K"), "Context prompt reflects actual Interact binding")
	world._begin_context_action()
	world._tick_context_action(0.2)
	check(is_equal_approx(world.context_action.progress, 0.2), "Timed harvest accumulates progress")
	paused = true
	world._tick_context_action(1.0)
	check(is_equal_approx(world.context_action.progress, 0.2) and world.survival.berry_count == 0, "Pause freezes harvest and prevents rewards")
	paused = false
	_place(world, Vector2i(7,8))
	world._tick_context_action(1.0)
	check(world.context_action.active.is_empty() and world.survival.berry_count == 0, "Movement cancels common harvest without rewards")
	_place(world, berry)
	world._begin_context_action()
	world._tick_context_action(1.0)
	check(world.survival.berry_count == 2 and world.grid.cells[8 * world.grid.SIZE + 6].berries == 0, "Common action harvests exactly two berries and depletes source")
	check(saves.progression.discoveries.has("food.berry_bush") and saves.progression.discoveries.has("food.first_harvest"), "First harvest and food source award stable discoveries")
	world.survival.hunger = 4.0
	world.survival.thirst = 4.0
	var eat := InputEventAction.new()
	eat.action = "eat"
	eat.pressed = true
	world._unhandled_input(eat)
	check(world.survival.berry_count == 1 and world.survival.hunger == 7.0 and world.survival.thirst == 4.0, "Eat input consumes one berry and restores food")
	check(world.hud.get_node("PlayerStatus/Rows/Food").text.contains("Berries 1"), "Food HUD reflects actual carried berries")
	var forest_grid: RefCounted = world.grid
	var forage: RefCounted = world.foraging
	world = await _travel("wetlands")
	world = await _travel("forest")
	check(world.grid == forest_grid and world.foraging == forage and forest_grid.cells[8 * forest_grid.SIZE + 6].berries == 0, "Regional round trip preserves forage model and depletion")
	var data: Dictionary = forest_grid.cells[8 * forest_grid.SIZE + 6]
	data.moisture = 0.8
	data.health = 0.8
	forage.tick(179.0)
	check(data.berries == 0, "Favorable growth still requires its full duration")
	forage.tick(1.0)
	check(data.berries == 2, "180 favorable model seconds replenish fruit")
	_place(world, berry)
	var knowledge_before: int = saves.progression.knowledge
	world._begin_context_action()
	world._tick_context_action(1.0)
	check(saves.progression.knowledge == knowledge_before, "Repeated harvest does not repeat permanent discoveries")
	world = await _travel("wetlands")
	world = await _travel("forest")
	check(data.berries == 0, "Reharvest depletion also persists through regional round trip")
	var shore := _shore(world.grid)
	check(not shore.is_empty(), "Live forest retains reachable freshwater")
	if not shore.is_empty():
		_place(world, shore.cell, shore.pond - shore.cell)
		check(world.selected_interaction.object_kind == "water", "Facing reachable shore selects pond for drinking")
		var pond: Dictionary = world.grid.cells[shore.pond.y * world.grid.SIZE + shore.pond.x]
		var level_before: float = pond.water_level
		world.survival.thirst = 2.0
		world._begin_context_action()
		world._tick_context_action(1.0)
		check(world.survival.thirst == 5.0 and pond.water_level == level_before, "Drinking restores thirst without draining pond volume")
		check(saves.progression.discoveries.has("water.freshwater"), "Freshwater discovery recorded once")
		var water_knowledge: int = saves.progression.knowledge
		world._begin_context_action()
		world._tick_context_action(1.0)
		check(saves.progression.knowledge == water_knowledge, "Repeated drinking gives no duplicate Knowledge")
		pond.water_level = 0.0
		_place(world, shore.pond)
		check(not world.selected_interaction.available and world.hud.get_node("Context").text.contains("dry"), "Dry pond exposes clear unavailable reason")
		world._begin_context_action()
		check(world.context_action.active.is_empty(), "Dry pond cannot begin drinking")
		pond.water_level = level_before
	_test_climate_context(world)
	var stored: Variant = JSON.parse_string(FileAccess.get_file_as_string(TEST_SAVE))
	check(stored is Dictionary and stored.version == 1, "Discovery persistence retains version-one save schema")
	var knowledge_saved: int = saves.progression.knowledge
	check(saves.load_progression() and saves.progression.knowledge == knowledge_saved, "New discoveries survive progression reload")
	flow.main_menu()
	await process_frame
	await process_frame
	_clean()
	print("SURVIVAL GAMEPLAY: ", checks, " checks, ", failures, " failures")
	quit(0 if failures == 0 else 1)

func _test_climate_context(world: Node) -> void:
	var open := Vector2i(8,3)
	var canopy := Vector2i(-1,-1)
	for i in range(world.grid.cells.size()):
		var cell := Vector2i(i % world.grid.SIZE, floori(float(i) / world.grid.SIZE))
		if world.grid.traversable(cell) and cell.distance_to(world.grid.start) > 2.2 and world.climate.shade_at(cell) >= 0.3:
			canopy = cell
			break
	check(canopy.x >= 0, "Seeded live forest provides traversable canopy shelter")
	# Choose an existing open central cell; do not invent canopy for the test.
	for z in range(2,7):
		var cell := Vector2i(8,z)
		if world.climate.shade_at(cell) == 0.0:
			open = cell
			break
	world.climate.weather_override = "rain"
	world.climate.ignition_chance = 0.0
	_reset_survival(world)
	_place(world, open)
	_seconds(world, 30)
	var open_wet: float = world.survival.wetness
	check(open_wet > 35.0, "Actual level rain ticks wet an unsheltered resting player")
	if canopy.x >= 0:
		_reset_survival(world)
		_place(world, canopy)
		_seconds(world, 30)
		check(world.survival.wetness < open_wet, "Actual climate canopy context reduces rain wetting")
	_reset_survival(world)
	_place(world, open)
	for i in range(30):
		_place(world, open + Vector2i.DOWN * (i % 2))
		world._process(1.0)
	check(world.survival.wetness > 10.0, "Moving outdoors still receives actual rain context")
	world.climate.weather_override = "cool"
	world.climate.baseline_temperature = 2.0
	_reset_survival(world)
	world.survival.wetness = 100.0
	_place(world, open)
	_seconds(world, 60)
	check(world.survival.body_temperature < 36.0 and not world.survival.dead, "Cold wet outdoor context cools the body during bounded exploration")
	world._update_hud()
	check(world.wet_indicator.visible and world.hud.get_node("PlayerStatus/Rows/Wetness").visible, "Wetness has both player and HUD feedback")
	check(world.hud.get_node("PlayerStatus/Rows/Supplies/Food").text == ("%d/10" % roundi(world.survival.hunger)) and world.hud.get_node("PlayerStatus/Rows/Heat/Value").text.contains("°C"), "HUD reports reserves and body Celsius")
	var body_before: float = world.survival.body_temperature
	var wet_before: float = world.survival.wetness
	world.survival.health = 80.0
	_place(world, world.grid.start)
	_seconds(world, 10)
	check(world.survival.body_temperature > body_before and world.survival.wetness < wet_before and world.survival.health > 80.0, "Actual camp context warms, dries and heals a cold wet player")
