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
	print("--- Running Environmental Hazards Test ---")

	var GridData = load("res://features/levels/forest/grid_data.gd")
	var RunRegions = load("res://features/levels/forest/RunRegions.gd")
	var EnvironmentalHazards = load("res://features/levels/forest/environmental_hazards.gd")
	var ForestLevelScene = load("res://features/levels/forest/forest_level.tscn")

	var regions = RunRegions.new()
	regions.configure(2026)

	# 1. Forest region: Must have 0 sandstorms and 0 cold air masses
	print("\n[1] Testing Forest region (Hazards must be absent)...")
	var forest_grid = GridData.new()
	forest_grid.generate(regions.seed_for("forest"))
	var forest_hazards = EnvironmentalHazards.new()
	root.add_child(forest_hazards)
	forest_hazards.configure("forest", forest_grid, regions.seed_for("forest"))
	check(forest_hazards.hazards.size() == 0, "Forest region has exactly 0 hazards")
	check(not forest_hazards.is_cell_in_hazard(forest_grid.start), "Start cell is not in hazard in forest")
	check(forest_hazards.get_hazard_cells().is_empty(), "Hazard cell list is empty in forest")
	forest_hazards.queue_free()

	# 2. Drylands region: Random sandstorm hazards
	print("\n[2] Testing Drylands region (Sandstorms)...")
	var dry_grid = GridData.new()
	dry_grid.generate(regions.seed_for("drylands"))
	var dry_hazards = EnvironmentalHazards.new()
	root.add_child(dry_hazards)
	dry_hazards.configure("drylands", dry_grid, regions.seed_for("drylands"))
	check(dry_hazards.hazards.size() == 3, "Drylands has 3 roaming sandstorm hazards")
	for i in range(dry_hazards.hazards.size()):
		var h = dry_hazards.hazards[i]
		check(h.type == "sandstorm", "Hazard %d is type sandstorm" % i)
		check(dry_grid.in_bounds(h.cell), "Hazard %d cell %s is in bounds" % [i, h.cell])
		check(h.cell != dry_grid.recycle_bin_cell, "Hazard %d cell does not overlap recycle bin" % i)
		check(not dry_grid.SPACESHIP_CELLS.has(h.cell), "Hazard %d cell does not overlap spaceship" % i)
		check(is_instance_valid(h.visual), "Hazard %d has valid visual node" % i)
		check(h.visual.has_node("SandVortex"), "Hazard %d has SandVortex particle node" % i)
		check(h.visual.has_node("DustSkirt"), "Hazard %d has DustSkirt particle node" % i)
		check(h.visual.has_node("DustGlow"), "Hazard %d has DustGlow light node" % i)
		var vortex = h.visual.get_node("SandVortex")
		check(vortex is CPUParticles3D, "SandVortex is CPUParticles3D")

	# 3. Wetlands region: Random cold air mass hazards
	print("\n[3] Testing Wetlands region (Cold air masses)...")
	var wet_grid = GridData.new()
	wet_grid.generate(regions.seed_for("wetlands"))
	var wet_hazards = EnvironmentalHazards.new()
	root.add_child(wet_hazards)
	wet_hazards.configure("wetlands", wet_grid, regions.seed_for("wetlands"))
	check(wet_hazards.hazards.size() == 3, "Wetlands has 3 roaming cold air mass hazards")
	for i in range(wet_hazards.hazards.size()):
		var h = wet_hazards.hazards[i]
		check(h.type == "cold_air", "Hazard %d is type cold_air" % i)
		check(wet_grid.in_bounds(h.cell), "Hazard %d cell %s is in bounds" % [i, h.cell])
		check(h.cell != wet_grid.recycle_bin_cell, "Hazard %d cell does not overlap recycle bin" % i)
		check(not wet_grid.SPACESHIP_CELLS.has(h.cell), "Hazard %d cell does not overlap spaceship" % i)
		check(is_instance_valid(h.visual), "Hazard %d has valid visual node" % i)
		check(h.visual.has_node("ColdMist"), "Hazard %d has ColdMist particle node" % i)
		check(h.visual.has_node("IceFlecks"), "Hazard %d has IceFlecks particle node" % i)
		check(h.visual.has_node("FrostGlow"), "Hazard %d has FrostGlow light node" % i)
		var mist = h.visual.get_node("ColdMist")
		check(mist is CPUParticles3D, "ColdMist is CPUParticles3D")

	# 4. Roaming behavior: Must only move to orthogonal adjacent cells (UP, DOWN, LEFT, RIGHT)
	print("\n[4] Testing Roaming behavior (Step to orthogonal adjacent cells)...")
	var test_h = dry_hazards.hazards[0]
	for step in range(10):
		var prev_cell = test_h.cell
		dry_hazards._step_hazard(test_h)
		var new_cell = test_h.cell
		var diff = (new_cell - prev_cell).abs()
		var is_orthogonal = (diff.x == 1 and diff.y == 0) or (diff.x == 0 and diff.y == 1)
		check(is_orthogonal, "Step %d: Hazard moved from %s to adjacent orthogonal cell %s" % [step, prev_cell, new_cell])
		check(dry_grid.in_bounds(new_cell), "Step %d: Hazard remained in bounds" % step)
		check(new_cell != dry_grid.recycle_bin_cell, "Step %d: Hazard did not land on recycle bin" % step)

	# 5. In-hazard detection
	print("\n[5] Testing Hazard detection methods...")
	var active_cell = dry_hazards.hazards[0].cell
	check(dry_hazards.is_cell_in_hazard(active_cell), "is_cell_in_hazard returns true for active hazard cell")
	var world_pos = dry_grid.world_position(active_cell)
	check(dry_hazards.is_pos_in_hazard(world_pos), "is_pos_in_hazard returns true for active hazard world position")
	check(not dry_hazards.is_cell_in_hazard(Vector2i(-50, -50)), "is_cell_in_hazard returns false for out-of-bounds cell")
	check(not dry_hazards.is_pos_in_hazard(Vector3(999, 0, 999)), "is_pos_in_hazard returns false for far away position")

	# 6. Damage & Health popup indicators with full ForestLevel scene
	print("\n[6] Testing Damage & Health popups in ForestLevel...")
	var world = ForestLevelScene.instantiate()
	root.add_child(world)
	await process_frame

	# Test floating damage popup
	var dmg_popup = world._spawn_health_popup("-5", Color("e05353"), "damage")
	check(dmg_popup != null, "Damage popup successfully spawned")
	check(dmg_popup.has_node("Icon"), "Damage popup has Icon sprite")
	check(dmg_popup.has_node("Amount"), "Damage popup has Amount label")
	var dmg_label: Label3D = dmg_popup.get_node("Amount")
	check(dmg_label.text == "-5", "Damage popup text is -5")
	check(dmg_label.modulate == Color("e05353"), "Damage popup text is red")

	# Test floating heal popup
	var heal_popup = world._spawn_health_popup("+5", Color("4ebd5f"), "heal")
	check(heal_popup != null, "Heal popup successfully spawned")
	check(heal_popup.has_node("Icon"), "Heal popup has Icon sprite")
	check(heal_popup.has_node("Amount"), "Heal popup has Amount label")
	var heal_label: Label3D = heal_popup.get_node("Amount")
	check(heal_label.text == "+5", "Heal popup text is +5")
	check(heal_label.modulate == Color("4ebd5f"), "Heal popup text is green")

	# Test hazard damage accumulation in world
	world.hazard_system = dry_hazards
	var player = world.get_node("GridPlayer")
	player.cell = dry_hazards.hazards[0].cell
	player.position = dry_grid.world_position(player.cell)
	world.survival.health = 100.0
	var initial_health = world.survival.health

	# Tick hazard damage by 0.5s (should not deal damage yet)
	world._tick_hazard_damage(0.5)
	check(world.survival.health == initial_health, "0.5s in hazard does not trigger damage yet")
	# Tick hazard damage another 0.5s (total 1.0s, should deal exactly 5 damage)
	world._tick_hazard_damage(0.5)
	check(world.survival.health == initial_health - 5.0, "1.0s in hazard deals exactly 5 damage (new health: %f)" % world.survival.health)

	# Clean up
	dry_hazards.queue_free()
	wet_hazards.queue_free()
	world.queue_free()

	print("\n--- Summary: %d checks passed, %d failures ---" % [checks - failures, failures])
	if failures > 0:
		print("FAILED with %d errors" % failures)
		quit(1)
	else:
		print("ALL HAZARDS TESTS PASSED!")
		quit(0)
