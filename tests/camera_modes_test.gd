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
func run():
	var settings = root.get_node("SettingsManager")
	settings.storage_path = "user://camera_modes_test.cfg"
	settings.reset_defaults()
	check(settings.bindings.camera_mode_cycle == [KEY_C, 0] and settings.bindings.eat == [KEY_F, 0], "New action defaults")
	check(settings.valid_code("camera_mode_cycle", KEY_C) and not settings.valid_code("camera_orbit", KEY_C), "Cycle accepts keyboard; orbit remains a drag button")
	check(settings.rebind("camera_mode_cycle", 0, KEY_V) == "", "Cycle can be rebound")
	check(settings.rebind("eat", 0, KEY_V) != "", "Cycle still participates in conflicts")
	settings.camera_mode = "Follow Player"
	settings.save_settings()
	settings.camera_mode = "Board Center"
	settings.bindings = settings.DEFAULT_BINDINGS.duplicate(true)
	settings.load_settings()
	settings.apply_settings()
	check(settings.camera_mode == "Follow Player" and settings.bindings.camera_mode_cycle[0] == KEY_V, "Mode and cycle binding persist")
	var legacy = settings.DEFAULT_BINDINGS.duplicate(true)
	legacy.erase("camera_mode_cycle")
	legacy.erase("eat")
	legacy.move_north = [KEY_C, KEY_UP]
	legacy.interact = [KEY_F, KEY_SPACE]
	var config = ConfigFile.new()
	config.set_value("controls", "bindings", legacy)
	config.set_value("gameplay", "camera_mode", "invalid mode")
	config.save(settings.storage_path)
	settings.load_settings()
	check(settings.bindings.move_north == [KEY_C, KEY_UP] and settings.bindings.interact == [KEY_F, KEY_SPACE], "Legacy player bindings are preserved")
	check(settings.bindings.camera_mode_cycle == [0, 0] and settings.bindings.eat == [0, 0], "Conflicting newly added defaults are unbound")
	check(settings.camera_mode == "Board Center", "Invalid mode uses Board Center")
	settings.reset_defaults()
	var saves = root.get_node("SaveManager")
	saves.storage_path = "user://camera_modes_progression.json"
	var flow = root.get_node("SceneFlow")
	flow.new_game()
	await process_frame
	await process_frame
	var world = current_scene
	world.set_process(false)
	var rig = world.get_node("CameraRig")
	var player = world.get_node("GridPlayer")
	var center = world.grid.world_position(world.grid.start)
	rig.configure_targets(center, player)
	var cells = world.grid.cells.duplicate(true)
	check(rig.mode == "Board Center" and rig.global_position.is_equal_approx(center), "Board Center starts at existing pivot")
	var cycle = InputEventKey.new()
	cycle.physical_keycode = KEY_C
	cycle.pressed = true
	rig._unhandled_input(cycle)
	check(rig.mode == "Follow Player" and settings.camera_mode == "Board Center", "C cycles temporarily without replacing saved default")
	player.global_position += Vector3(4, 0, 0)
	var before = rig.global_position
	rig._process(0.01)
	check(rig.global_position.x > before.x and rig.global_position.x < player.global_position.x, "Follow interpolates toward actual player")
	rig._process(10.0)
	check(rig.global_position.is_equal_approx(player.global_position), "Follow reaches actual player")
	var before_orbit = rig.target_yaw
	rig._unhandled_input(cycle)
	check(rig.mode == "Free Camera", "C reaches Free Camera")
	var press = InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_MIDDLE
	press.pressed = true
	press.shift_pressed = true
	rig._unhandled_input(press)
	var motion = InputEventMouseMotion.new()
	motion.relative = Vector2(70, 40)
	motion.button_mask = MOUSE_BUTTON_MASK_MIDDLE
	var free_before = rig.free_target
	rig._unhandled_input(motion)
	check(not rig.free_target.is_equal_approx(free_before) and is_equal_approx(rig.target_yaw, before_orbit), "Shift orbit binding pans free target without orbit")
	check(world.grid.cells == cells, "Free pan does not mutate logical grid")
	rig._process(0.01)
	check(not rig.global_position.is_equal_approx(rig.free_target), "Free pan interpolates")
	motion.relative = Vector2(100000, 100000)
	rig._unhandled_input(motion)
	check(rig.free_target.distance_to(center) <= rig.MAX_FREE_OFFSET + 0.01, "Inspection range is bounded")
	press.pressed = false
	rig._input(press)
	check(rig.drag_button == 0, "Mouse release ends pan")
	var state = rig.get_transition_state()
	var next_center = center + Vector3(200, 0, 20)
	rig.configure_targets(next_center, player, state)
	check(rig.mode == "Free Camera" and rig.global_position.is_equal_approx(next_center + state.free_position_offset) and rig.free_target.is_equal_approx(next_center + state.free_offset), "Region restore remaps free target immediately")
	check(is_equal_approx(rig.pitch, state.pitch) and is_equal_approx(rig.target_zoom, state.target_zoom), "Region restore retains view state")
	settings.volumes.Master = 0.5
	settings.apply_settings()
	check(rig.mode == "Free Camera", "Audio changes preserve temporary runtime mode")
	settings.camera_mode = "Follow Player"
	settings.apply_settings()
	check(rig.mode == "Follow Player", "Changing saved Gameplay default applies immediately")
	settings.camera_projection = "Perspective"
	settings.apply_settings()
	check(rig.mode == "Follow Player", "Projection is independent of targeting mode")
	rig.configure_targets(center, player, rig.get_transition_state())
	check(rig.global_position.is_equal_approx(player.global_position), "Follow region arrival snaps to player rather than old board")
	flow.open_pause()
	rig._unhandled_input(cycle)
	check(rig.mode == "Follow Player" and rig.drag_button == 0, "Pause rejects camera cycling")
	flow.pause_menu.open_options()
	await process_frame
	rig._unhandled_input(cycle)
	check(rig.mode == "Follow Player", "Options rejects camera cycling")
	var options = flow.pause_menu.options
	options.show_category("Gameplay")
	check(options.content.get_node("CameraModeRow/CameraMode").item_count == 3, "Gameplay exposes three defaults")
	settings.reset_category("Gameplay")
	check(rig.mode == "Board Center" and settings.camera_projection == "Orthographic", "Gameplay reset restores mode and projection")
	flow.resume()
	rig._unhandled_input(cycle)
	check(rig.mode == "Follow Player", "Resume restores camera input")
	flow.main_menu()
	await process_frame
	await process_frame
	DirAccess.remove_absolute(settings.storage_path)
	if FileAccess.file_exists(saves.storage_path):
		DirAccess.remove_absolute(saves.storage_path)
	print("CAMERA MODES: ", checks, " checks, ", failures, " failures")
	quit(0 if failures == 0 else 1)
