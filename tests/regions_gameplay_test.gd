extends SceneTree

const TEST_PATH = "user://regions_gameplay_test.json"
const DIRECTIONS = [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
var checks = 0
var failures = 0
var flow: Node

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func path_to(world: Node, origin: Vector2i, target: Vector2i) -> Array[Vector2i]:
	var frontier: Array[Vector2i] = [origin]
	var previous = {origin: origin}
	var cursor = 0
	while cursor < frontier.size():
		var cell = frontier[cursor]
		cursor += 1
		if cell == target:
			var path: Array[Vector2i] = []
			while cell != origin:
				path.push_front(cell)
				cell = previous[cell]
			return path
		for direction in DIRECTIONS:
			var neighbor = cell + direction
			if previous.has(neighbor) or not world.grid.traversable(neighbor):
				continue
			if neighbor != target and not world.regions.exit_destination(world.region_id, neighbor).is_empty():
				continue
			previous[neighbor] = cell
			frontier.append(neighbor)
	return []

func walk_to(target: Vector2i) -> bool:
	var world = current_scene
	var player = world.get_node("GridPlayer")
	if player.cell == target:
		return true
	var path = path_to(world, player.cell, target)
	if path.is_empty():
		check(false, "Navigable route exists to " + str(target) + " in " + world.region_id)
		return false
	for next in path:
		var step: Vector2i = next - player.cell
		if not player.try_move(step):
			check(false, "Actual player accepts cardinal route step " + str(step))
			return false
		for frame in range(180):
			await process_frame
			if not is_instance_valid(world) or current_scene != world or not player.moving or world.ended:
				break
		if not is_instance_valid(world) or current_scene != world:
			check(false, "Navigation cannot unexpectedly transition before target")
			return false
		if world.ended:
			return player.cell == target
	return player.cell == target and not player.moving

func graphical_world_count(node: Node) -> int:
	var count = 1 if node.scene_file_path == flow.playable_scene else 0
	for child in node.get_children():
		count += graphical_world_count(child)
	return count

func take_exit(exit_cell: Vector2i, destination: String, arrival: Vector2i, hold_action: bool = false) -> Node:
	var before = current_scene
	var origin = exit_cell + (Vector2i.RIGHT if exit_cell.x == 0 else Vector2i.LEFT)
	if not await walk_to(origin):
		return null
	var camera = before.get_node("CameraRig")
	var expected_camera = Vector3(camera.target_yaw, camera.target_pitch, camera.target_zoom)
	var player = before.get_node("GridPlayer")
	if hold_action:
		Input.action_press("move_north")
	check(player.try_move(exit_cell - player.cell), "Player steps onto actual region trail")
	check(before.transitioning and flow.region_transitioning, "Trail schedules one guarded transition")
	for index in range(180):
		await process_frame
		if is_instance_valid(current_scene) and current_scene != before:
			break
	if not is_instance_valid(current_scene) or current_scene == before:
		Input.action_release("move_north")
		check(false, "Region scene finishes transition")
		return null
	var world = current_scene
	world.set_process(false)
	await process_frame
	await process_frame
	check(world.region_id == destination and world.get_node("GridPlayer").cell == arrival, "Trail enters corresponding region edge interior")
	check(world.grid.traversable(arrival), "Arrival is traversable")
	check(graphical_world_count(root) == 1, "Only the current region has a graphical level scene")
	var restored = world.get_node("CameraRig")
	check(is_equal_approx(restored.target_yaw, expected_camera.x) and is_equal_approx(restored.target_pitch, expected_camera.y) and is_equal_approx(restored.target_zoom, expected_camera.z), "Camera yaw/pitch/zoom targets survive trail travel")
	check(is_equal_approx(restored.rotation.y, expected_camera.x) and is_equal_approx(restored.pitch, expected_camera.y) and is_equal_approx(restored.get_node("Camera3D").size, expected_camera.z), "Camera actual orientation and zoom are restored immediately")
	if hold_action:
		await create_timer(0.5, false).timeout
		check(world.get_node("GridPlayer").require_release and world.get_node("GridPlayer").cell == arrival, "Held movement stays gated after entering a region")
		Input.action_release("move_north")
		await process_frame
		await process_frame
		check(not world.get_node("GridPlayer").require_release, "Releasing held movement re-enables normal input")
	return world

func tree_scenario(world: Node) -> Dictionary:
	for z in range(world.grid.SIZE):
		for x in range(world.grid.SIZE):
			var origin = Vector2i(x, z)
			if not world.grid.traversable(origin) or not world.regions.exit_destination(world.region_id, origin).is_empty():
				continue
			if path_to(world, world.get_node("GridPlayer").cell, origin).is_empty() and world.get_node("GridPlayer").cell != origin:
				continue
			for direction in DIRECTIONS:
				var tree = origin + direction
				var landing = tree + direction
				if not world.grid.in_bounds(tree) or not world.grid.traversable(landing) or landing.distance_to(world.grid.start) <= 2.5:
					continue
				if world.grid.cells[tree.y * world.grid.SIZE + tree.x].tree and world.regions.exit_destination(world.region_id, landing).is_empty():
					return {"origin": origin, "tree": tree, "landing": landing, "direction": direction}
	return {}

func clean_test_files() -> void:
	for path in [TEST_PATH, TEST_PATH + ".tmp"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)

func run() -> void:
	var original_time_scale = Engine.time_scale
	Engine.time_scale = 8.0
	var saves = root.get_node("SaveManager")
	saves.storage_path = TEST_PATH
	clean_test_files()
	saves.load_progression()
	flow = root.get_node("SceneFlow")
	flow.next_seed = 2026
	flow.run_regions = null
	flow.region_arrival_from = ""
	flow.camera_state.clear()
	check(flow.transition(flow.playable_scene) == OK, "Actual playable scene starts with fixed seed")
	await process_frame
	await process_frame
	var world = current_scene
	world.set_process(false)
	check(world.region_id == "forest" and world.grid.cells.size() == 289 and world.objectives.regional_mode, "Actual run starts in bounded Forest with regional objectives")
	var run_models: RefCounted = world.regions
	var survival: RefCounted = world.survival
	var objectives: RefCounted = world.objectives
	var forest_grid: RefCounted = world.grid
	var camera = world.get_node("CameraRig")
	camera.target_yaw = -0.43
	camera.rotation.y = camera.target_yaw
	camera.target_pitch = 0.61
	camera.pitch = camera.target_pitch
	camera.target_zoom = 35.0
	camera.get_node("Camera3D").size = camera.target_zoom
	camera._update_camera()
	flow.open_pause()
	flow.pause_menu.open_options()
	await process_frame
	check(paused and is_instance_valid(flow.pause_menu.options), "Options opens while gameplay is paused")
	var elapsed_before: float = run_models.elapsed
	check(flow.change_region("drylands") == ERR_UNAVAILABLE, "Paused Options rejects region changes")
	world._request_region_transition("drylands")
	await create_timer(0.4, true).timeout
	check(current_scene == world and world.region_id == "forest" and not world.transitioning and run_models.elapsed == elapsed_before, "Paused trail request cannot transition or advance the run")
	flow.resume()
	await process_frame
	check(await walk_to(world.grid.objective), "Forest clearing is reached through actual cardinal movement")
	check(not world.ended and not objectives.ready_for_clearing(), "Walking straight to clearing cannot bypass regional fieldwork")
	world = await take_exit(Vector2i(0, 8), "drylands", Vector2i(15, 8), true)
	if world == null:
		finish(original_time_scale)
		return
	check(world.regions == run_models and world.survival == survival and world.objectives == objectives, "Trail travel shares run and survival/objective models")
	var dry_grid: RefCounted = world.grid
	var dry_climate: RefCounted = world.climate
	var scenario = tree_scenario(world)
	check(not scenario.is_empty(), "Drylands has reachable actual tree and safe fallen-log landing")
	if scenario.is_empty():
		finish(original_time_scale)
		return
	check(await walk_to(scenario.origin), "Player walks to actual Drylands interaction site")
	check(objectives.problem_seen and not objectives.mitigation_done, "Walking genuinely dry ground records regional survey without granting mitigation")
	check(world.interactions.begin(scenario.origin, scenario.direction), "Actual timed tree interaction begins")
	var cut: Dictionary = world.interactions.tick(2.0, scenario.origin)
	check(cut.get("kind") == "tree_cut" and cut.get("landing") == scenario.landing, "Actual cut produces expected stump and log")
	world._finish_interaction(cut)
	check(world.cut_cells.has(scenario.tree) and world.trees.has(scenario.tree) and world.logs.has(scenario.landing), "Authoritative cut history has matching stump/log graphics")
	check(not world.grid.traversable(scenario.tree) and not world.grid.traversable(scenario.landing), "Stump and fallen log both block their actual cells")
	var old_stump_id = world.trees[scenario.tree].get_instance_id()
	var old_log_id = world.logs[scenario.landing].get_instance_id()
	var dry_cells: Array = dry_grid.cells.duplicate(true)
	world = await take_exit(Vector2i(16, 8), "forest", Vector2i(1, 8))
	if world == null:
		finish(original_time_scale)
		return
	check(world.grid == forest_grid, "Returning Forest reuses original grid model")
	world = await take_exit(Vector2i(0, 8), "drylands", Vector2i(15, 8))
	if world == null:
		finish(original_time_scale)
		return
	check(world.grid == dry_grid and world.climate == dry_climate and world.cut_cells.has(scenario.tree), "Drylands revisit retains grid/climate identity and cut-cell history")
	check(world.grid.cells[scenario.tree.y * 17 + scenario.tree.x].tree_state == "stump" and world.grid.cells[scenario.landing.y * 17 + scenario.landing.x].log, "Actual stump/log state survives round-trip without regeneration")
	check(world.trees.has(scenario.tree) and world.logs.has(scenario.landing) and world.trees[scenario.tree].get_instance_id() != old_stump_id and world.logs[scenario.landing].get_instance_id() != old_log_id, "Only active stump/log graphics are reconstructed from retained state")
	check(world.grid.cells[scenario.tree.y * 17 + scenario.tree.x].rotation == dry_cells[scenario.tree.y * 17 + scenario.tree.x].rotation, "Retained cell generation data is unchanged")
	check(await walk_to(scenario.origin), "Player walks back to retained stump")
	check(world.interactions.begin(scenario.origin, scenario.direction), "Retained stump begins its real second action")
	var removed: Dictionary = world.interactions.tick(2.0, scenario.origin)
	check(removed.get("kind") == "stump_removed", "Second real interaction clears stump")
	world._finish_interaction(removed)
	check(objectives.mitigation_done and not objectives.recovery_seen and world.grid.traversable(scenario.tree) and not world.trees.has(scenario.tree), "Drylands fuel mitigation requires actual stump removal")
	world = await take_exit(Vector2i(16, 8), "forest", Vector2i(1, 8))
	if world == null:
		finish(original_time_scale)
		return
	world = await take_exit(Vector2i(16, 8), "wetlands", Vector2i(1, 8))
	if world == null:
		finish(original_time_scale)
		return
	check(world.regions == run_models and world.survival == survival and world.objectives == objectives, "Wetlands keeps shared run evidence and survival model")
	check(world.habitat_marker != null and world.habitat_marker.visible, "Wetlands exposes the actual recovery habitat landmark")
	check(await walk_to(Vector2i(8, 6)), "Player navigates beside recovering habitat without teleportation")
	var habitat: Dictionary = world.grid.cells[5 * 17 + 8]
	var before_health: float = habitat.health
	check(not objectives.recovery_seen, "Travelling to wet habitat alone does not fabricate recovery")
	for index in range(15):
		world._process(1.0)
	check(habitat.health > before_health + 0.08 and objectives.recovery_seen and objectives.ready_for_clearing(), "Fifteen actual climate ticks produce witnessed recovery near habitat")
	check(run_models.elapsed >= 15.0 and world.climate.elapsed >= 15.0, "Observed habitat recovery advances real regional climate and run clocks")
	check(await walk_to(world.grid.objective), "Player walks the protected route to Wetlands refuge")
	await process_frame
	check(world.ended and world.hud.modal_kind == "success" and paused, "Regional evidence plus actual refuge entry ends the attempt successfully")
	check(saves.progression.discoveries.has("landmark.refuge") and saves.progression.discoveries.has("interaction.firebreak"), "Actual fieldwork and refuge discoveries persist in isolated test save")
	world.hud.close_modal()
	flow.main_menu()
	await process_frame
	await process_frame
	check(flow.run_regions == null and current_scene.scene_file_path == flow.MAIN_MENU and not paused, "Menu exit disposes active run and resumes tree")
	finish(original_time_scale)

func finish(original_time_scale: float) -> void:
	Input.action_release("move_north")
	Engine.time_scale = original_time_scale
	paused = false
	clean_test_files()
	print("REGIONS_GAMEPLAY: ", checks, " checks, ", failures, " failures")
	quit(0 if failures == 0 else 1)
