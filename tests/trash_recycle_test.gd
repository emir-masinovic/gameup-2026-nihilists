extends SceneTree

var checks := 0
var failures := 0

func check(condition: bool, description: String) -> void:
	checks += 1
	if condition:
		print("PASS: ", description)
	else:
		failures += 1
		push_error("FAIL: " + description)

func _init() -> void:
	call_deferred("run")

func run() -> void:
	print("--- Running Trash and Recycle Bin Tests ---")

	var GridData = load("res://features/levels/forest/grid_data.gd")
	var RunRegions = load("res://features/levels/forest/RunRegions.gd")
	var Foraging = load("res://features/levels/forest/ResourceForaging.gd")
	var Planting = load("res://features/levels/forest/StatePlanting.gd")
	var SurvivalState = load("res://features/player/survival_state.gd")

	# Test all 3 regions/maps: forest, wetlands, drylands
	var regions = RunRegions.new()
	regions.configure(4242)

	for region_id in ["forest", "wetlands", "drylands"]:
		print("Checking region: ", region_id)
		var grid = GridData.new()
		var seed_val: int = regions.seed_for(region_id)
		grid.generate(seed_val)

		var foraging = Foraging.new()
		foraging.configure(grid, seed_val, region_id)

		# 1. Exactly 1 recycle bin per map
		check(grid.in_bounds(grid.recycle_bin_cell), "[%s] Recycle bin is within grid bounds: %s" % [region_id, grid.recycle_bin_cell])
		var bin_cell = grid.recycle_bin_cell
		var bin_data: Dictionary = grid.cells[bin_cell.y * grid.SIZE + bin_cell.x]
		check(bin_data.get("recycle_bin", false), "[%s] Recycle bin cell is marked recycle_bin" % region_id)
		check(not bin_data.get("water", false), "[%s] Recycle bin does not overlap water" % region_id)
		check(bin_data.get("terrain", "") != "water", "[%s] Recycle bin terrain is not water" % region_id)
		check(not bin_data.get("tree", false), "[%s] Recycle bin does not overlap trees" % region_id)
		check(not bin_data.get("log", false), "[%s] Recycle bin does not overlap logs" % region_id)
		check(not bin_data.get("berry_bush", false), "[%s] Recycle bin does not overlap berry bush" % region_id)
		check(int(bin_data.get("berries", 0)) == 0, "[%s] Recycle bin has 0 berries" % region_id)
		check(not bin_data.get("spaceship", false), "[%s] Recycle bin does not overlap spaceship" % region_id)
		check(bin_cell != grid.start, "[%s] Recycle bin is not on player start" % region_id)
		check(bin_cell != grid.objective, "[%s] Recycle bin is not on objective" % region_id)

		# 7. Player CANNOT walk on recycle bin cell (blocked just like trees)
		check(not grid.traversable(bin_cell), "[%s] Recycle bin cell is non-traversable (blocked)" % region_id)

		# 2. Trash clutter placement
		check(grid.trash_cells.size() > 0, "[%s] Grid has trash clutter cells (found %d)" % [region_id, grid.trash_cells.size()])
		for t_cell in grid.trash_cells:
			check(grid.in_bounds(t_cell), "[%s] Trash cell %s in bounds" % [region_id, t_cell])
			var t_data: Dictionary = grid.cells[t_cell.y * grid.SIZE + t_cell.x]
			check(t_data.get("trash", false), "[%s] Trash cell %s is marked trash" % [region_id, t_cell])
			check(not t_data.get("water", false), "[%s] Trash cell %s does not overlap water" % [region_id, t_cell])
			check(t_data.get("terrain", "") != "water", "[%s] Trash cell %s terrain is not water" % [region_id, t_cell])
			check(not t_data.get("berry_bush", false), "[%s] Trash cell %s does not overlap berry bush" % [region_id, t_cell])
			check(t_cell != bin_cell, "[%s] Trash cell %s does not overlap recycle bin" % [region_id, t_cell])
			check(not t_data.get("spaceship", false), "[%s] Trash cell %s does not overlap spaceship" % [region_id, t_cell])
			# Trash cells MUST be traversable so the player can stand on them to pick trash
			check(grid.traversable(t_cell), "[%s] Trash cell %s is traversable" % [region_id, t_cell])

	# 2 & Planting Constraint: Player must pick trash before planting
	var forest_grid = GridData.new()
	forest_grid.generate(1337)
	var planting = Planting.new()
	var test_trash_cell = forest_grid.trash_cells[0]
	var test_trash_data: Dictionary = forest_grid.cells[test_trash_cell.y * forest_grid.SIZE + test_trash_cell.x]
	test_trash_data.terrain = "soil"
	test_trash_data.prepared = true

	var avail = planting.soil_availability(forest_grid, test_trash_cell)
	check(not avail.available, "Soil availability blocked on trash cell before pickup")
	check(avail.reason == "Clear trash first", "Soil availability reason is 'Clear trash first' (got '%s')" % avail.reason)
	check(not planting.plant(forest_grid, test_trash_cell), "Planting fails on trash cell")

	# Now pick up trash
	test_trash_data.trash = false
	var avail_cleared = planting.soil_availability(forest_grid, test_trash_cell)
	check(avail_cleared.available, "Soil availability allowed after trash pickup")
	check(planting.plant(forest_grid, test_trash_cell), "Planting succeeds after trash pickup")

	# 4 & 5. Trash Inventory, Capacity, HUD indicator logic
	var survival = SurvivalState.new()
	check(survival.MAX_TRASH == 3, "MAX_TRASH is 3")
	check(survival.trash_count == 0, "Initial trash_count is 0")
	check(survival.can_pick_trash(), "Can pick trash when inventory is 0/3")

	check(survival.add_trash(1), "Add 1 trash succeeds")
	check(survival.trash_count == 1, "Trash count is 1/3")
	check(survival.can_pick_trash(), "Can pick trash when inventory is 1/3")

	check(survival.add_trash(1), "Add second trash succeeds")
	check(survival.trash_count == 2, "Trash count is 2/3")
	check(survival.can_pick_trash(), "Can pick trash when inventory is 2/3")

	check(survival.add_trash(1), "Add third trash succeeds")
	check(survival.trash_count == 3, "Trash count is 3/3")
	check(not survival.can_pick_trash(), "Cannot pick trash when inventory is 3/3")
	check(not survival.add_trash(1), "Adding 4th trash fails at capacity")
	check(survival.trash_count == 3, "Trash count remains 3/3")

	# 6. Dumping trash into recycle bin
	var dumped_count = survival.dump_trash()
	check(dumped_count == 3, "dump_trash returns 3")
	check(survival.trash_count == 0, "Trash count reset to 0/3 after dumping")
	check(survival.can_pick_trash(), "Can pick trash again after dumping")

	# 4. HUD Visuals & Modulate
	var RunHud = load("res://features/levels/forest/run_hud.tscn")
	var hud_instance = RunHud.instantiate()
	var supplies = hud_instance.get_node("PlayerStatus/Rows/Supplies")
	check(supplies.has_node("Trash"), "HUD has Supplies/Trash label")
	check(supplies.has_node("TrashIcon"), "HUD has Supplies/TrashIcon")

	var trash_label: Label = supplies.get_node("Trash")
	survival.trash_count = 0
	hud_instance.update_survival(survival, 0.0, "E")
	check(trash_label.text == "0/3", "HUD shows '0/3' (got '%s')" % trash_label.text)
	check(trash_label.modulate == Color.WHITE, "HUD trash text is WHITE at 0/3")

	survival.trash_count = 2
	hud_instance.update_survival(survival, 0.0, "E")
	check(trash_label.text == "2/3", "HUD shows '2/3' (got '%s')" % trash_label.text)
	check(trash_label.modulate == Color.WHITE, "HUD trash text is WHITE at 2/3")

	survival.trash_count = 3
	hud_instance.update_survival(survival, 0.0, "E")
	check(trash_label.text == "3/3", "HUD shows '3/3' (got '%s')" % trash_label.text)
	check(trash_label.modulate == Color("e05353"), "HUD trash text turns RED at 3/3")

	hud_instance.free()

	# 3D Level Props & Interaction Simulation
	var ForestLevel = load("res://features/levels/forest/forest_level.tscn")
	var level = ForestLevel.instantiate()
	root.add_child(level)
	await process_frame

	check(level.recycle_bin_visual != null, "ForestLevel instantiated recycle_bin_visual")
	check(level.recycle_bin_visual.is_in_group("forest_props"), "Recycle bin is in forest_props group")
	check(level.recycle_bin_visual.position == level.grid.world_position(level.grid.recycle_bin_cell), "Recycle bin position matches grid cell")

	check(level.trash_visuals.size() == level.grid.trash_cells.size(), "ForestLevel created trash visuals for all trash cells (count: %d)" % level.trash_visuals.size())
	for tc in level.grid.trash_cells:
		check(level.trash_visuals.has(tc), "Trash visual exists for cell %s" % tc)

	# Verify adjacency detection for dumping
	var bin_pos = level.grid.recycle_bin_cell
	var adj_cell = bin_pos + Vector2i.UP
	check(level._near_recycle_bin(adj_cell), "Cell %s adjacent to recycle bin is detected" % adj_cell)
	var far_cell = bin_pos + Vector2i(5, 5)
	check(not level._near_recycle_bin(far_cell), "Far cell %s is not detected as adjacent" % far_cell)

	# Verify facing detection for dumping
	var to_bin = bin_pos - adj_cell
	check(level._facing_recycle_bin(adj_cell, to_bin), "Player facing recycle bin from adjacent cell is detected")
	var away_from_bin = -to_bin
	check(not level._facing_recycle_bin(adj_cell, away_from_bin), "Player facing away from recycle bin is NOT facing it")

	# Test interaction while facing away: trash must NOT be dumped
	level.get_node("GridPlayer").cell = adj_cell
	level.get_node("GridPlayer").facing = away_from_bin
	level.survival.trash_count = 2
	level._try_interact("interact")
	check(level.survival.trash_count == 2, "Trash is NOT dumped when facing away from recycle bin")

	# Test interaction while facing the bin: trash MUST be dumped
	level.get_node("GridPlayer").facing = to_bin
	level._try_interact("interact")
	check(level.survival.trash_count == 0, "Trash IS dumped when facing the recycle bin")

	level.free()

	print("\n==========================================")
	print("TRASH & RECYCLE BIN TEST: %d checks, %d failures" % [checks, failures])
	print("==========================================")
	if failures > 0:
		quit(1)
	else:
		quit(0)
