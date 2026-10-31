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
	saves.storage_path = "user://gameplay_integration_test.json"
	saves.load_progression()
	var flow = root.get_node("SceneFlow")
	flow.new_game()
	await process_frame
	await process_frame
	var world = current_scene
	world.set_process(false)
	var player = world.get_node("GridPlayer")
	var seed_before = world.world_seed
	check(world.grid.traversable(world.grid.objective), "Objective reachable on clear central route")
	var found = false
	for z in range(world.grid.SIZE):
		for x in range(world.grid.SIZE - 1):
			var cell = Vector2i(x, z)
			if world.grid.traversable(cell) and world.grid.cells[z * world.grid.SIZE + x + 1].tree:
				player.cell = cell
				player.position = world.grid.world_position(cell)
				found = true
				break
		if found:
			break
	check(found, "Found adjacent tree")
	var tree_cell = player.cell + Vector2i.RIGHT
	check(world.interactions.begin(player.cell, Vector2i.RIGHT), "Start tree action")
	check(world.interactions.tick(0.5, player.cell).is_empty(), "Tree requires action duration")
	var event = world.interactions.tick(1.0, player.cell)
	check(event.direction == Vector2i.RIGHT and event.cell == tree_cell, "Fall direction away from player")
	world._finish_interaction(event)
	check(not world.grid.traversable(tree_cell), "Stump keeps original cell blocked")
	check(world.grid.cells[tree_cell.y * world.grid.SIZE + tree_cell.x].tree_state == "stump", "Cut reflected in climate data")
	check(world.interactions.begin(player.cell, Vector2i.RIGHT), "Second action targets stump")
	event = world.interactions.tick(2.0, player.cell)
	world._finish_interaction(event)
	check(world.grid.traversable(tree_cell), "Stump removal opens cell")
	var health = world.grid.cells[0].health
	world.climate.trample(Vector2i.ZERO)
	world.climate.trample(Vector2i.ZERO)
	check(world.grid.cells[0].health < health - 0.2, "Repeated trampling damages grass")
	saves.discover("test.integration")
	var knowledge = saves.progression.knowledge
	world.hud.show_modal("bonfire")
	check(paused, "Bonfire modal pauses gameplay")
	world.hud.close_modal()
	check(not paused, "Bonfire returns to gameplay")
	world.survival.health = 0
	world.survival.dead = true
	world._end_run("death")
	check(paused and world.hud.modal_kind == "death", "Death screen and pause")
	world.hud.get_node("Modal/Rows/Next").pressed.emit()
	await process_frame
	await process_frame
	check(current_scene.world_seed != seed_before and current_scene.survival.health == 100, "New seed and fresh temporary state")
	check(saves.progression.knowledge == knowledge, "Death preserves Knowledge")
	current_scene._end_run("success")
	check(current_scene.hud.modal_kind == "success", "Success offers another run")
	current_scene.hud.close_modal()
	flow.main_menu()
	await process_frame
	await process_frame
	DirAccess.remove_absolute(saves.storage_path)
	print("GAMEPLAY: ", checks, " checks, ", failures, " failures")
	quit(0 if failures == 0 else 1)
