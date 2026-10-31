extends SceneTree
var checks = 0
var failures = 0
func check(value: bool, message: String):
	checks += 1
	if not value:
		failures += 1
		push_error(message)
func _initialize():
	call_deferred("run")
func capture(name: String):
	if DisplayServer.get_name() != "headless" and OS.has_environment("NIHILISTS_CAPTURE_DIR"):
		await create_timer(0.3).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OS.get_environment("NIHILISTS_CAPTURE_DIR").path_join(name + ".png"))
func run():
	var test_saves = root.get_node("SaveManager")
	test_saves.storage_path = "user://camera_grid_test_progression.json"
	test_saves.load_progression()
	var flow = root.get_node("SceneFlow")
	var settings = root.get_node("SettingsManager")
	flow.new_game()
	await process_frame
	await process_frame
	var world = current_scene
	world.set_process(false)
	var rig = world.get_node("CameraRig")
	var camera = rig.get_node("Camera3D")
	var grid_snapshot = world.grid.cells.duplicate(true)
	var center = world.grid.world_position(world.grid.start)
	check(rig.global_position.is_equal_approx(center), "Camera anchored to grid center")
	var player = world.get_node("GridPlayer")
	player.try_move(Vector2i.UP)
	await create_timer(0.25).timeout
	check(rig.global_position.is_equal_approx(center), "Player movement does not move camera target")
	grid_snapshot = world.grid.cells.duplicate(true)
	var wheel = InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	var old_size = camera.size
	rig._unhandled_input(wheel)
	check(rig.target_zoom < old_size and camera.size == old_size, "Zoom input sets smooth target")
	await create_timer(0.5).timeout
	check(camera.size < old_size and camera.size > rig.target_zoom - 0.01, "Zoom interpolates")
	for index in range(50):
		rig._unhandled_input(wheel)
	check(rig.target_zoom == rig.MIN_ZOOM, "Minimum zoom clamp")
	await create_timer(0.5).timeout
	for aa in [Viewport.MSAA_DISABLED, Viewport.MSAA_4X]:
		settings.msaa_3d = aa
		settings.apply_settings()
		await capture("grid_near_msaa_" + str(aa))
	wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
	for index in range(50):
		rig._unhandled_input(wheel)
	check(rig.target_zoom == rig.MAX_ZOOM, "Maximum zoom clamp")
	await create_timer(0.5).timeout
	for aa in [Viewport.MSAA_DISABLED, Viewport.MSAA_4X]:
		settings.msaa_3d = aa
		settings.apply_settings()
		await capture("grid_far_msaa_" + str(aa))
	var motion = InputEventMouseMotion.new()
	motion.relative = Vector2(180, 0)
	motion.button_mask = MOUSE_BUTTON_MASK_RIGHT
	var press = InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_RIGHT
	press.pressed = true
	rig._unhandled_input(press)
	var old_yaw = rig.rotation.y
	rig._unhandled_input(motion)
	check(not is_equal_approx(rig.target_yaw, old_yaw), "Right drag sets orbit target")
	await create_timer(0.5).timeout
	check(absf(angle_difference(rig.rotation.y, rig.target_yaw)) < 0.02, "Orbit interpolates")
	check(rig.global_position.is_equal_approx(center) and world.grid.cells == grid_snapshot, "Orbit preserves grid and center")
	check(camera.global_transform.basis.z.normalized().dot((camera.global_position - center).normalized()) > 0.999, "Orbit camera still looks at center")
	var target_yaw = rig.target_yaw
	motion.button_mask = 0
	rig._unhandled_input(motion)
	check(rig.target_yaw == target_yaw, "No orbit without right button")
	var material = world.palette[0]
	check(material is ShaderMaterial and material.shader.code.contains("fwidth"), "Derivative-antialiased grid material")
	settings.storage_path = "user://camera_controls_test.cfg"
	for button in [MOUSE_BUTTON_MIDDLE, MOUSE_BUTTON_RIGHT]:
		press.button_index = button
		press.pressed = true
		rig._unhandled_input(press)
		var before_pitch = rig.target_pitch
		var before_yaw = rig.target_yaw
		motion.button_mask = MOUSE_BUTTON_MASK_MIDDLE if button == MOUSE_BUTTON_MIDDLE else MOUSE_BUTTON_MASK_RIGHT
		motion.relative = Vector2(12, 12)
		rig._unhandled_input(motion)
		check(rig.target_pitch > before_pitch and rig.target_yaw != before_yaw, "Both axes for mouse button " + str(button))
		press.pressed = false
		rig._input(press)
		var released_yaw = rig.target_yaw
		rig._unhandled_input(motion)
		check(rig.target_yaw == released_yaw, "Release ends drag")
	press.pressed = true
	rig._unhandled_input(press)
	motion.relative.y = 100000
	rig._unhandled_input(motion)
	check(rig.target_pitch > TAU, "Free orbit beyond upper pole")
	motion.relative.y = -100000
	rig._unhandled_input(motion)
	check(rig.target_pitch < TAU, "Free orbit returns across poles")
	rig._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(rig.drag_button == 0, "Focus loss cancels drag")
	rig._unhandled_input(press)
	settings.mouse_sensitivity = 0.015
	motion.relative = Vector2(1, 0)
	var sensitive_yaw = rig.target_yaw
	rig._unhandled_input(motion)
	check(is_equal_approx(absf(angle_difference(sensitive_yaw, rig.target_yaw)), 0.015), "Sensitivity applies immediately")
	settings.save_settings()
	settings.mouse_sensitivity = 0.008
	settings.load_settings()
	check(is_equal_approx(settings.mouse_sensitivity, 0.015), "Sensitivity reload")
	settings.reset_category("Controls")
	check(settings.mouse_sensitivity == settings.DEFAULT_MOUSE_SENSITIVITY, "Controls resets sensitivity")
	DirAccess.remove_absolute(settings.storage_path)
	check(world.grid.cells == grid_snapshot, "Two axis orbit preserves logical world")
	for angle in [PI * 0.5, PI, PI * 1.5, TAU, -PI * 0.5]:
		rig.pitch = angle
		rig._update_camera()
		check(camera.transform.basis.is_finite() and is_equal_approx(camera.transform.basis.determinant(), 1.0), "Finite orthonormal camera at pole/underside")
		check(camera.global_transform.basis.z.normalized().dot((camera.global_position - center).normalized()) > 0.999, "Free orbit looks at pivot")
	rig.target_pitch = PI * 0.25
	rig.target_zoom = 42.0
	rig.target_yaw = PI * 0.25
	await create_timer(0.6).timeout
	await capture("grid_centered_default")
	flow.open_pause()
	var paused_yaw = rig.rotation.y
	var paused_size = camera.size
	var input_wheel = InputEventMouseButton.new()
	input_wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	input_wheel.pressed = true
	Input.parse_input_event(input_wheel)
	await create_timer(0.25).timeout
	check(is_equal_approx(rig.rotation.y, paused_yaw) and is_equal_approx(camera.size, paused_size), "Camera pauses with game")
	var paused_target = rig.target_yaw
	rig._unhandled_input(press)
	rig._unhandled_input(motion)
	check(rig.target_yaw == paused_target and rig.drag_button == 0, "Pause rejects drag input")
	flow.pause_menu.open_options()
	await process_frame
	var options = flow.pause_menu.options
	options.show_category("Controls")
	options.content.get_node("MouseSensitivity").value = 0.012
	check(is_equal_approx(settings.mouse_sensitivity, 0.012), "Sensitivity slider applies immediately")
	rig._unhandled_input(press)
	check(rig.drag_button == 0, "Options rejects camera input")
	options.back_button.pressed.emit()
	await process_frame
	check(paused, "Options Back retains pause")
	flow.resume()
	await process_frame
	rig._unhandled_input(press)
	check(rig.drag_button != 0, "Resume restores drag")
	if FileAccess.file_exists(settings.storage_path):
		DirAccess.remove_absolute(settings.storage_path)
	flow.main_menu()
	await process_frame
	await process_frame
	print("CAMERA GRID: ", checks, " checks, ", failures, " failures")
	if FileAccess.file_exists(test_saves.storage_path):
		DirAccess.remove_absolute(test_saves.storage_path)
	quit(0 if failures == 0 else 1)
