extends SceneTree
var failures = 0
var checks = 0
func check(value: bool, message: String):
	checks += 1
	if not value:
		failures += 1
		push_error(message)
func _initialize():
	call_deferred("run")
func run():
	var test_saves = root.get_node("SaveManager")
	test_saves.storage_path = "user://grid_world_test_progression.json"
	test_saves.load_progression()
	var Data = load("res://features/levels/forest/grid_data.gd")
	var first = Data.new()
	var second = Data.new()
	first.generate(2026)
	second.generate(2026)
	check(first.cells == second.cells, "Same seed identical initial world")
	second.generate(2027)
	check(first.cells != second.cells, "Different seed changes world")
	for seed_value in range(100):
		second.generate(seed_value)
		check(second.traversable(second.start), "Valid spawn seed " + str(seed_value))
	check(not first.traversable(Vector2i(-1, 0)), "West boundary")
	check(not first.traversable(Vector2i(0, -1)), "North boundary")
	check(not first.traversable(Vector2i(first.SIZE, 0)), "East boundary")
	check(not first.traversable(Vector2i(0, first.SIZE)), "South boundary")
	var flow = root.get_node("SceneFlow")
	flow.new_game()
	await process_frame
	await process_frame
	var world = current_scene
	var player = world.get_node("GridPlayer")
	check(player.cell == world.grid.start and world.grid.traversable(player.cell), "Actual player spawn")
	check(world.terrain_renderer.rendered_cell_count() == 289, "Bounded rendered map")
	check(world.get_node("Vegetation").get_child_count() > 0, "Forest populated")
	check(world.get_node("CameraRig/Camera3D").projection == (Camera3D.PROJECTION_ORTHOGONAL if root.get_node("SettingsManager").camera_projection == "Orthographic" else Camera3D.PROJECTION_PERSPECTIVE), "Configured camera projection")
	check(not player.try_move(Vector2i(1, 1)), "Reject diagonal movement")
	var start = player.cell
	var mapped_north = player.screen_direction_to_grid(Vector2i.UP)
	Input.action_press("move_north")
	await process_frame
	await process_frame
	Input.action_release("move_north")
	check(player.cell == start + mapped_north, "InputMap action moves player relative to camera")
	check(not player.try_move(Vector2i.RIGHT), "Reject overlapping step")
	flow.open_pause()
	var paused_position = player.position
	await create_timer(0.25).timeout
	check(player.position == paused_position, "Paused movement tween frozen")
	flow.resume()
	await create_timer(0.25).timeout
	check(not player.moving and player.position.is_equal_approx(world.grid.world_position(player.cell)), "Smooth movement completes on cell after resume")
	player.cell = Vector2i(world.grid.start.x, 0)
	player.position = world.grid.world_position(player.cell)
	check(not player.try_move(Vector2i.UP), "Player cannot leave map")
	var found = false
	for z in range(world.grid.SIZE):
		for x in range(world.grid.SIZE - 1):
			var origin = Vector2i(x, z)
			if world.grid.traversable(origin) and not world.grid.traversable(origin + Vector2i.RIGHT):
				player.cell = origin
				player.position = world.grid.world_position(origin)
				check(not player.try_move(Vector2i.RIGHT), "Tree blocks player")
				found = true
				break
		if found:
			break
	check(found, "Obstacle test exercised")
	# Exercise a remapped physical key through InputMap, preserving user configuration.
	var settings = root.get_node("SettingsManager")
	var old_bindings = settings.bindings.duplicate(true)
	settings.bindings.move_south[0] = KEY_K
	settings.apply_settings()
	player.cell = world.grid.start
	player.position = world.grid.world_position(player.cell)
	var mapped_south = player.screen_direction_to_grid(Vector2i.DOWN)
	var key = InputEventKey.new()
	key.physical_keycode = KEY_K
	key.pressed = true
	Input.parse_input_event(key)
	await process_frame
	await process_frame
	key.pressed = false
	Input.parse_input_event(key)
	check(player.cell == world.grid.start + mapped_south, "Remapped physical key moves player relative to camera")
	await create_timer(0.25).timeout
	settings.bindings = old_bindings
	settings.apply_settings()
	if DisplayServer.get_name() != "headless" and OS.has_environment("NIHILISTS_CAPTURE_DIR"):
		await create_timer(0.5).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OS.get_environment("NIHILISTS_CAPTURE_DIR").path_join("forest_world.png"))
	flow.open_pause()
	flow.pause_menu.open_options()
	await process_frame
	check(paused and is_instance_valid(flow.pause_menu.options), "Options inside world pause")
	flow.main_menu()
	await process_frame
	await process_frame
	check(not paused and current_scene.scene_file_path == flow.MAIN_MENU, "World returns to menu")
	print("GRID WORLD: ", checks, " checks, ", failures, " failures")
	if FileAccess.file_exists(test_saves.storage_path):
		DirAccess.remove_absolute(test_saves.storage_path)
	quit(0 if failures == 0 else 1)
