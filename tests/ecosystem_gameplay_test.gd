extends SceneTree
var checks = 0
var failures = 0
func check(value, message):
	checks += 1
	if not value:
		failures += 1
		push_error(message)
func _initialize():
	call_deferred("run")
func run():
	var saves = root.get_node("SaveManager")
	saves.storage_path = "user://ecosystem_gameplay_test.json"
	saves.load_progression()
	var flow = root.get_node("SceneFlow")
	flow.next_seed = 2026
	flow.run_regions = preload("res://features/levels/forest/RunRegions.gd").new()
	flow.run_regions.configure(2026)
	flow.run_regions.enter("drylands")
	flow.transition(flow.playable_scene)
	await process_frame
	await process_frame
	var world = current_scene
	world.set_process(false)
	var player = world.get_node("GridPlayer")
	world._on_cell_entered(world.grid.objective)
	await process_frame
	check(not world.ended, "Clearing cannot bypass environmental sequence")
	var found = false
	for z in range(world.grid.SIZE):
		for x in range(world.grid.SIZE - 2):
			var origin = Vector2i(x,z)
			var target = origin + Vector2i.RIGHT
			var landing = target + Vector2i.RIGHT
			if origin.distance_to(world.grid.start) > 3 and world.grid.traversable(origin) and world.grid.cells[z * world.grid.SIZE + x + 1].tree and world.grid.traversable(landing):
				player.cell = origin
				player.position = world.grid.world_position(origin)
				found = true
				break
		if found: break
	check(found, "Found tree and clear landing for scenario")
	var here = world.grid.cells[player.cell.y * world.grid.SIZE + player.cell.x]
	here.moisture = 0.1
	world._on_cell_entered(player.cell)
	check(world.objectives.problem_seen, "Dry ground supplies survey evidence")
	check(world.interactions.begin(player.cell, Vector2i.RIGHT), "Timed tree action begins")
	var event = world.interactions.tick(2.0, player.cell)
	check(event.kind == "tree_cut" and event.has("landing"), "Fallen log has safe deterministic landing")
	var landing: Vector2i = event.landing
	world._finish_interaction(event)
	check(not world.grid.traversable(landing) and world.logs.has(landing), "Log blocks its visible landing")
	check(world.interactions.begin(player.cell, Vector2i.RIGHT), "Stump action begins")
	var removed = world.interactions.tick(2.0, player.cell)
	world._finish_interaction(removed)
	check(world.objectives.mitigation_done, "Stump clearing records real fuel mitigation")
	player.cell = removed.cell
	player.position = world.grid.world_position(player.cell)
	check(world.interactions.begin(player.cell, Vector2i.RIGHT), "Log can be cleared without inventory")
	world._finish_interaction(world.interactions.tick(2.0, player.cell))
	check(world.grid.traversable(landing) and not world.logs.has(landing), "Log clearing reopens route")
	here.recovery_low = 0.2
	here.health = 0.5
	world._refresh_visuals()
	check(not world.objectives.ready_for_clearing(), "Drylands regrowth cannot bypass the Wetlands observation")
	var hazard_cell = world.grid.cells[player.cell.y * world.grid.SIZE + player.cell.x]
	hazard_cell.burning = true
	hazard_cell.fire_time = 0.0
	hazard_cell.fuel = 1.0
	hazard_cell.moisture = 0.0
	world._refresh_visuals()
	check(world.effects.flames.multimesh.visible_instance_count > 0, "Wildfire visible from model state")
	var health = world.survival.health
	world._process(1.0)
	check(world.survival.health < health, "Fire damages exposed player gradually")
	check(world.survival.health > 0, "No instant unavoidable fire death")
	player.cell = world.grid.objective
	world._on_cell_entered(player.cell)
	await process_frame
	check(not world.ended, "Drylands clearing cannot bypass the regional refuge sequence")
	world.hud.close_modal()
	flow.main_menu()
	await process_frame
	await process_frame
	if FileAccess.file_exists(saves.storage_path): DirAccess.remove_absolute(saves.storage_path)
	print("ECOSYSTEM GAMEPLAY: ",checks," checks, ",failures," failures")
	quit(0 if failures == 0 else 1)
