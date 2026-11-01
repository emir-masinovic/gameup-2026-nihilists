extends SceneTree

const GridData = preload("res://features/levels/forest/grid_data.gd")
const ClimateSimulation = preload("res://features/levels/forest/climate_simulation.gd")
const EnvironmentalHazards = preload("res://features/levels/forest/environmental_hazards.gd")
const SurvivalState = preload("res://features/player/survival_state.gd")

var checks = 0
var failures = 0

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: %s" % message)
	else:
		print("PASS: %s" % message)

func _initialize() -> void:
	call_deferred("run_all_tests")

func run_all_tests() -> void:
	print("\n--- Running Micro & Macro Climate Tests ---")

	test_microclimate_trash()
	test_microclimate_tree_transpiration()
	test_macroclimate_planet_health_calculation()
	test_macroclimate_trash_recycling_impact()
	test_macroclimate_tree_planting_impact()
	test_macroclimate_global_warming_mitigation()
	test_macroclimate_heatwave_attenuation()
	test_macroclimate_hazard_mitigation()
	await test_hud_planet_health_display()

	print("\n--- Summary: %d checks passed, %d failures ---" % [checks - failures, failures])
	if failures == 0:
		print("ALL MICRO & MACRO CLIMATE TESTS PASSED!\n")
		quit(0)
	else:
		printerr("SOME TESTS FAILED!\n")
		quit(1)

func test_microclimate_trash() -> void:
	print("\n[1] Testing Microclimate Trash Impact...")
	var grid = GridData.new()
	grid.generate(2026)
	var climate = ClimateSimulation.new()
	climate.configure(grid, 2026)

	var test_cell = Vector2i(5, 5)
	while grid.cells[test_cell.y * grid.SIZE + test_cell.x].tree or grid.cells[test_cell.y * grid.SIZE + test_cell.x].water:
		test_cell += Vector2i.RIGHT

	var cell_data: Dictionary = grid.cells[test_cell.y * grid.SIZE + test_cell.x]

	# Clean cell baseline
	cell_data.trash = false
	var temp_clean = climate.temperature_at(test_cell)

	# Trash added to cell
	cell_data.trash = true
	var temp_trash = climate.temperature_at(test_cell)
	check(is_equal_approx(temp_trash, temp_clean + 2.0), "Trash cell local temperature is exactly +2.0C hotter than clean cell")

	# Clearing trash
	cell_data.trash = false
	var temp_restored = climate.temperature_at(test_cell)
	check(is_equal_approx(temp_restored, temp_clean), "Clearing trash removes the +2.0C heat penalty")

	# Soil health & drying impact comparison
	var clean_cell = test_cell
	var dirty_cell = test_cell + Vector2i.DOWN
	while grid.cells[dirty_cell.y * grid.SIZE + dirty_cell.x].tree or grid.cells[dirty_cell.y * grid.SIZE + dirty_cell.x].water:
		dirty_cell += Vector2i.DOWN

	var clean_d: Dictionary = grid.cells[clean_cell.y * grid.SIZE + clean_cell.x]
	var dirty_d: Dictionary = grid.cells[dirty_cell.y * grid.SIZE + dirty_cell.x]
	clean_d.trash = false
	dirty_d.trash = true
	clean_d.health = 0.8
	dirty_d.health = 0.8
	clean_d.moisture = 0.5
	dirty_d.moisture = 0.5

	climate.weather_override = "clear"
	climate.tick(10.0)

	check(dirty_d.health < clean_d.health, "Soil health on trash cell degrades faster due to toxicity")
	check(dirty_d.moisture < clean_d.moisture, "Trash cell dries out faster than clean cell")

func test_microclimate_tree_transpiration() -> void:
	print("\n[2] Testing Microclimate Tree Transpiration...")
	var grid = GridData.new()
	grid.generate(2026)
	var climate = ClimateSimulation.new()
	climate.configure(grid, 2026)

	var center = Vector2i(6, 6)
	var center_data: Dictionary = grid.cells[center.y * grid.SIZE + center.x]
	center_data.tree = true
	center_data.tree_state = "healthy"
	center_data.tree_health = 1.0

	var neighbor = center + Vector2i.RIGHT
	var neighbor_data: Dictionary = grid.cells[neighbor.y * grid.SIZE + neighbor.x]
	neighbor_data.tree = false
	neighbor_data.moisture = 0.4

	var isolated = Vector2i(14, 14)
	var isolated_data: Dictionary = grid.cells[isolated.y * grid.SIZE + isolated.x]
	isolated_data.tree = false
	isolated_data.moisture = 0.4
	for off in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		var adj = isolated + off
		if grid.in_bounds(adj):
			grid.cells[adj.y * grid.SIZE + adj.x].tree = false

	climate.tick(5.0)
	check(neighbor_data.moisture > isolated_data.moisture, "Healthy tree transpires and hydrates neighboring cell")

func test_macroclimate_planet_health_calculation() -> void:
	print("\n[3] Testing Planet Health Calculation...")
	var grid = GridData.new()
	grid.generate(2026)
	var climate = ClimateSimulation.new()
	climate.configure(grid, 2026)

	var initial_health = climate.planet_health
	check(initial_health >= 20.0 and initial_health <= 45.0, "Initial planet health is in reasonable baseline range (got %.1f%%)" % initial_health)

func test_macroclimate_trash_recycling_impact() -> void:
	print("\n[4] Testing Trash & Recycling Impact on Planet Health...")
	var grid = GridData.new()
	grid.generate(2026)
	var climate = ClimateSimulation.new()
	climate.configure(grid, 2026)

	var base_health = climate.planet_health

	if not grid.trash_cells.is_empty():
		var t_cell = grid.trash_cells[0]
		grid.cells[t_cell.y * grid.SIZE + t_cell.x].trash = false
		var health_after_pick = climate.calculate_planet_health()
		check(health_after_pick > base_health, "Picking up/clearing trash from cell increases Planet Health")

		climate.recycled_trash += 1
		var health_after_recycle = climate.calculate_planet_health()
		check(health_after_recycle > health_after_pick, "Dumping trash into recycle bin increases Planet Health")
		check(health_after_recycle >= base_health + 10.0, "Combined pick + recycle yields strong Planet Health gain (got +%.1f%%)" % (health_after_recycle - base_health))

func test_macroclimate_tree_planting_impact() -> void:
	print("\n[5] Testing Tree Planting & Maturation on Planet Health...")
	var grid = GridData.new()
	grid.generate(2026)
	var climate = ClimateSimulation.new()
	climate.configure(grid, 2026)

	var before = climate.calculate_planet_health()

	var cell1 = Vector2i(3, 3)
	var d1: Dictionary = grid.cells[cell1.y * grid.SIZE + cell1.x]
	d1.tree = true
	d1.tree_state = "healthy"
	d1.tree_health = 1.0
	d1.planted = true

	var cell2 = Vector2i(3, 4)
	var d2: Dictionary = grid.cells[cell2.y * grid.SIZE + cell2.x]
	d2.tree = true
	d2.tree_state = "healthy"
	d2.tree_health = 1.0
	d2.planted = true

	var after = climate.calculate_planet_health()
	check(after > before + 8.0, "Planted mature trees substantially raise Planet Health (got +%.1f%%)" % (after - before))

func test_macroclimate_global_warming_mitigation() -> void:
	print("\n[6] Testing Global Warming Mitigation from Planet Health...")
	var grid = GridData.new()
	grid.generate(2026)
	var climate = ClimateSimulation.new()
	climate.configure(grid, 2026)

	climate.elapsed = 300.0

	climate.planet_health = 50.0
	var warm_base = climate.warming_pressure()

	climate.planet_health = 68.0
	var warm_restored = climate.warming_pressure()
	check(warm_restored < warm_base, "Higher Planet Health slows down warming pressure (%.2f < %.2f)" % [warm_restored, warm_base])

	climate.planet_health = 80.0
	var warm_halted = climate.warming_pressure()
	check(warm_halted <= 0.0, "High Planet Health (80%%) halts global warming (got %.2f C)" % warm_halted)

func test_macroclimate_heatwave_attenuation() -> void:
	print("\n[7] Testing Heatwave Attenuation at High Planet Health...")
	var grid = GridData.new()
	grid.generate(2026)
	var climate = ClimateSimulation.new()
	climate.configure(grid, 2026)
	climate.weather_override = "heat"
	climate.elapsed = 100.0

	climate.planet_health = 40.0
	climate._update_weather()
	var temp_unmitigated = climate.temperature

	climate.planet_health = 85.0
	climate._update_weather()
	var temp_mitigated = climate.temperature

	check(temp_mitigated < temp_unmitigated - 3.0, "Restored planet health significantly softens scorching heat wave (%.1fC vs %.1fC)" % [temp_mitigated, temp_unmitigated])

func test_macroclimate_hazard_mitigation() -> void:
	print("\n[8] Testing Environmental Hazard Mitigation...")
	var grid = GridData.new()
	grid.generate(2026)

	var hazards = EnvironmentalHazards.new()
	hazards.configure("drylands", grid, 2026)
	check(hazards.hazards.size() > 0, "Hazards spawned in drylands")

	var base_interval = hazards.hazards[0].move_interval

	hazards.update_planet_health(85.0)
	var slow_interval = hazards.hazards[0].move_interval

	check(slow_interval > base_interval, "Restored planet health calms and slows wandering hazards (%.2fs -> %.2fs interval)" % [base_interval, slow_interval])

	hazards.queue_free()

func test_hud_planet_health_display() -> void:
	print("\n[9] Testing HUD Planet Health Display via Game World...")
	var saves = root.get_node("SaveManager")
	saves.storage_path = "user://test_micro_macro_hud_save.json"
	saves.load_progression()
	var flow = root.get_node("SceneFlow")
	flow.new_game()
	await process_frame
	await process_frame

	var world = current_scene
	check(world != null, "World scene loaded via SceneFlow")
	var hud = world.hud
	check(hud != null, "World has HUD instance")

	check(hud.has_node("WorldStatus/Rows/Planet"), "WorldStatus contains Planet row")
	check(hud.has_node("WorldStatus/Rows/Planet/Label"), "Planet row contains Label")
	check(hud.has_node("WorldStatus/Rows/Planet/Bar"), "Planet row contains ProgressBar")
	check(hud.has_node("WorldStatus/Rows/Planet/Icon"), "Planet row contains Icon")

	# Test update
	hud.update_planet_health(75.0)
	check(hud.get_node("WorldStatus/Rows/Planet/Label").text == "Planet 75%", "Planet Label displays formatted percentage")
	check(hud.get_node("WorldStatus/Rows/Planet/Bar").value == 75.0, "Planet ProgressBar reflects value")

	# Clean up save file
	if FileAccess.file_exists(saves.storage_path):
		DirAccess.remove_absolute(saves.storage_path)
