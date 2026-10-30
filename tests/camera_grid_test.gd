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
	var flow = root.get_node("SceneFlow")
	var settings = root.get_node("SettingsManager")
	flow.new_game()
	await process_frame
	await process_frame
	var world = current_scene
	var rig = world.get_node("CameraRig")
	var camera = rig.get_node("Camera3D")
	var grid_snapshot = world.grid.cells.duplicate(true)
	var center = world.grid.world_position(world.grid.start)
	check(rig.global_position.is_equal_approx(center), "Camera anchored to grid center")
	var player = world.get_node("GridPlayer")
	player.try_move(Vector2i.UP)
	await create_timer(0.25).timeout
	check(rig.global_position.is_equal_approx(center), "Player movement does not move camera target")
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
	var material = world.get_node("Terrain").get_child(0).material_override
	check(material is ShaderMaterial and material.shader.code.contains("fwidth"), "Derivative-antialiased grid material")
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
	flow.resume()
	flow.main_menu()
	await process_frame
	await process_frame
	print("CAMERA GRID: ", checks, " checks, ", failures, " failures")
	quit(0 if failures == 0 else 1)
