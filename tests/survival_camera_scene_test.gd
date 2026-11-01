extends SceneTree

const ACTIONS = {"move_north": Vector2i.UP, "move_south": Vector2i.DOWN, "move_west": Vector2i.LEFT, "move_east": Vector2i.RIGHT}
var checks = 0
var failures = 0
var flow: Node
var settings: Node

func check(value: bool, message: String):
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func _initialize():
	call_deferred("run")

func wait_for_movement(player: Node3D):
	# Native resize/render stalls can delay the tween past a short timer.
	# Wait on the gameplay completion flag, while keeping a bounded failure.
	for frame in range(180):
		await process_frame
		if not player.moving:
			return

func step(player: Node3D, direction: Vector2i):
	check(player.try_move(direction), "World-cardinal API accepts protected route step")
	await wait_for_movement(player)
	check(not player.moving, "Real movement tween completes")

func blocked_camera(rig: Node3D, world: Node, context: String):
	var state: Dictionary = rig.get_transition_state()
	var cells: Array = world.grid.cells.duplicate(true)
	var cycle = InputEventKey.new()
	cycle.physical_keycode = KEY_C
	cycle.pressed = true
	var button = InputEventMouseButton.new()
	button.button_index = MOUSE_BUTTON_MIDDLE
	button.pressed = true
	button.shift_pressed = true
	var motion = InputEventMouseMotion.new()
	motion.relative = Vector2(100, 100)
	motion.button_mask = MOUSE_BUTTON_MASK_MIDDLE
	rig._unhandled_input(cycle)
	rig._unhandled_input(button)
	rig._unhandled_input(motion)
	check(rig.get_transition_state() == state and rig.drag_button == 0 and world.grid.cells == cells, context + " rejects cycle/orbit/pan without world changes")

func capture(name: String):
	if DisplayServer.get_name() == "headless" or not OS.has_environment("NIHILISTS_CAPTURE_DIR"):
		return
	await create_timer(0.12, true).timeout
	await RenderingServer.frame_post_draw
	var path = OS.get_environment("NIHILISTS_CAPTURE_DIR").path_join(name + ".png")
	check(root.get_texture().get_image().save_png(path) == OK, "Desktop snapshot saved: " + name)

func resize_view(size_value: Vector2i):
	root.size = size_value
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(size_value)
	await process_frame
	await process_frame

func run():
	settings = root.get_node("SettingsManager")
	settings.storage_path = "user://survival_camera_scene_settings.cfg"
	settings.reset_defaults()
	var saves = root.get_node("SaveManager")
	saves.storage_path = "user://survival_camera_scene_progression.json"
	if FileAccess.file_exists(saves.storage_path):
		DirAccess.remove_absolute(saves.storage_path)
	saves.load_progression()
	flow = root.get_node("SceneFlow")
	flow.next_seed = 2026
	flow.run_regions = null
	flow.camera_state.clear()
	flow.region_arrival_from = ""
	flow.transition(flow.playable_scene)
	await process_frame
	await process_frame
	var world = current_scene
	world.set_process(false)
	var player = world.get_node("GridPlayer")
	var rig = world.get_node("CameraRig")
	var center: Vector3 = world.grid.world_position(world.grid.start)
	var camera = rig.get_node("Camera3D")
	for projection in ["Orthographic", "Perspective"]:
		settings.camera_projection = projection
		settings.apply_settings()
		for mode in settings.CAMERA_MODES:
			player.configure(world.grid)
			rig.set_mode(mode)
			rig.target_yaw = -0.6
			rig.target_pitch = 0.7
			rig._process(10.0)
			rig.configure_targets(center, player)
			for action in ACTIONS:
				player.configure(world.grid)
				player.require_release = false
				var expected: Vector2i = player.screen_direction_to_grid(ACTIONS[action])
				check(InputMap.has_action(action) and not InputMap.action_get_events(action).is_empty(), "Movement action has actual InputMap bindings")
				Input.action_press(action)
				player._process(0.0)
				Input.action_release(action)
				check(player.cell == world.grid.start + expected and player.moving, projection + " / " + mode + " maps " + action + " through the actual camera")
				await wait_for_movement(player)
				check(not player.moving and player.position.is_equal_approx(world.grid.world_position(player.cell)), "Mapped move reaches authoritative grid position")
			if mode == "Board Center":
				check(rig.global_position.is_equal_approx(center), "Board Center remains fixed after real movement")
			elif mode == "Follow Player":
				rig._process(10.0)
				check(rig.global_position.is_equal_approx(player.global_position), "Follow tracks real movement tween result")
			var yaw: float = rig.target_yaw
			var pitch_value: float = rig.target_pitch
			var zoom: float = rig.target_zoom
			flow.open_pause()
			blocked_camera(rig, world, projection + " / " + mode + " Pause")
			flow.pause_menu.open_options()
			await process_frame
			blocked_camera(rig, world, projection + " / " + mode + " Options")
			flow.pause_menu.options.back_button.pressed.emit()
			await process_frame
			check(paused, "Options Back retains Pause")
			flow.resume()
			await process_frame
			world.hud.show_modal("bonfire")
			blocked_camera(rig, world, projection + " / " + mode + " bonfire modal")
			world.hud.close_modal()
			check(not paused and rig.mode == mode and rig.target_yaw == yaw and rig.target_pitch == pitch_value and rig.target_zoom == zoom, "Resume retains targeting and orbit parameters")
	# Produce genuine food/water/wetness HUD values through level actions/ticks.
	player.configure(world.grid)
	await step(player, Vector2i.LEFT)
	await step(player, Vector2i.LEFT)
	world._begin_context_action()
	world._process(0.8)
	check(world.survival.berry_count == 2, "Actual context harvest supplies berries for HUD")
	await step(player, Vector2i.LEFT)
	world.climate.weather_override = "rain"
	var elapsed_before: float = world.climate.elapsed
	for second in range(60):
		world._process(1.0)
	check(world.climate.elapsed >= elapsed_before + 60.0 and world.survival.wetness > 1.0, "Sixty real rainy level ticks wet the player outside camp")
	check(world.survival.hunger < 10.0 and world.survival.thirst < 10.0, "Real ticks deplete food and water reserves")
	var wet_before: float = world.survival.wetness
	world._update_hud()
	check(world.hud.get_node("PlayerStatus/Rows/Wetness").visible, "Real wetness is visible in HUD")
	check(world.hud.get_node("PlayerStatus/Rows/Food").text.contains("Berries 2"), "Harvested supply appears in HUD")
	rig.set_mode("Board Center")
	rig.target_yaw = PI * 0.25
	rig.target_pitch = PI * 0.25
	rig.target_zoom = 42.0
	rig._process(10.0)
	settings.camera_projection = "Orthographic"
	settings.apply_settings()
	for size_value in [Vector2i(800,600), Vector2i(1152,720), Vector2i(1600,900)]:
		await resize_view(size_value)
		var bounds = root.get_visible_rect().grow(1)
		for panel in ["PlayerStatus", "WorldStatus"]:
			check(bounds.encloses(world.hud.get_node(panel).get_global_rect()), "Survival HUD panel fits " + str(size_value))
		check(not world.hud.get_node("PlayerStatus").get_global_rect().intersects(world.hud.get_node("WorldStatus").get_global_rect()), "Survival panels do not overlap")
		await capture("survival_hud_" + str(size_value.x))
		flow.open_pause()
		flow.pause_menu.open_options()
		await process_frame
		var options = flow.pause_menu.options
		options.show_category("Gameplay")
		await process_frame
		await process_frame
		var picker = options.content.get_node("CameraModeRow/CameraMode")
		check(picker.item_count == 2 and bounds.encloses(picker.get_global_rect()), "Gameplay camera picker fits " + str(size_value))
		await capture("survival_options_" + str(size_value.x))
		flow.resume()
		await process_frame
	# Camp drying is driven by the same level loop and does not refill reserves.
	await step(player, Vector2i.RIGHT)
	await step(player, Vector2i.RIGHT)
	await step(player, Vector2i.RIGHT)
	var hunger_before: float = world.survival.hunger
	for second in range(30):
		world._process(1.0)
	check(world.survival.wetness < wet_before and world.survival.hunger < hunger_before, "Thirty actual camp ticks dry clothes without refilling food")
	# Actual trail entry captures camera state and reconstructs a different scene.
	rig.set_mode("Follow Player")
	settings.camera_projection = "Perspective"
	settings.apply_settings()
	rig.target_yaw = -0.43
	rig.target_pitch = 0.61
	rig.target_zoom = 35.0
	rig._process(10.0)
	for index in range(7):
		await step(player, Vector2i.LEFT)
	var state: Dictionary = rig.get_transition_state()
	check(player.try_move(Vector2i.LEFT), "Actual player steps onto western region exit")
	for frame in range(180):
		await process_frame
		if is_instance_valid(current_scene) and current_scene != world:
			break
	check(is_instance_valid(current_scene) and current_scene != world, "Trail produces actual region scene transition")
	if is_instance_valid(current_scene) and current_scene != world:
		world = current_scene
		world.set_process(false)
		rig = world.get_node("CameraRig")
		player = world.get_node("GridPlayer")
		check(world.region_id == "drylands" and player.cell == Vector2i(15,8), "New scene arrives at actual Drylands entrance")
		check(rig.mode == "Follow Player" and camera_projection(rig) == Camera3D.PROJECTION_PERSPECTIVE, "Region preserves Follow Player and projection")
		check(rig.player_target == player and rig.global_position.is_equal_approx(player.global_position), "Follow targets actual arriving player immediately without old-board flyover")
		check(is_equal_approx(rig.target_yaw, state.target_yaw) and is_equal_approx(rig.target_pitch, state.target_pitch) and is_equal_approx(rig.target_zoom, state.target_zoom), "Region preserves orbit and zoom independently")
	flow.main_menu()
	await process_frame
	await process_frame
	for path in [settings.storage_path, saves.storage_path, saves.storage_path + ".tmp"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	print("SURVIVAL CAMERA SCENE: ", checks, " checks, ", failures, " failures")
	quit(0 if failures == 0 else 1)

func camera_projection(rig: Node3D) -> int:
	return rig.get_node("Camera3D").projection
