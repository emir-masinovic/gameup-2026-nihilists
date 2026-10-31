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
	check(settings.camera_mode == "Follow Player", "Invalid mode uses Follow Player")
	config.set_value("gameplay", "camera_mode", "Free Camera")
	config.save(settings.storage_path)
	settings.load_settings()
	check(settings.camera_mode == "Follow Player", "Removed mode migrates safely to Follow Player")
	settings.save_settings()
	config.load(settings.storage_path)
	check(config.get_value("gameplay", "camera_mode") == "Follow Player", "Next save persists the migrated mode")
	config.erase_section_key("gameplay", "camera_mode")
	config.save(settings.storage_path)
	settings.load_settings()
	check(settings.camera_mode == "Follow Player", "Missing setting uses Follow Player")
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
	check(rig.mode == "Follow Player" and rig.global_position.is_equal_approx(player.global_position), "Fresh settings follow the actual player")
	check(settings.CAMERA_MODES == ["Follow Player", "Board Center"], "Only two public modes remain")
	var cycle = InputEventKey.new()
	cycle.physical_keycode = KEY_C
	cycle.pressed = true
	rig._unhandled_input(cycle)
	check(rig.mode == "Board Center" and settings.camera_mode == "Follow Player", "C switches to Board Center without replacing saved default")
	rig._unhandled_input(cycle)
	check(rig.mode == "Follow Player", "C switches back to Follow Player")
	player.global_position += Vector3(4, 0, 0)
	var before = rig.global_position
	rig._process(0.01)
	check(rig.global_position.x > before.x and rig.global_position.x < player.global_position.x, "Follow interpolates toward actual player")
	rig._process(10.0)
	check(rig.global_position.is_equal_approx(player.global_position), "Follow reaches actual player")
	var before_orbit = rig.target_yaw
	var press = InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_MIDDLE
	press.pressed = true
	press.shift_pressed = true
	rig._unhandled_input(press)
	var motion = InputEventMouseMotion.new()
	motion.relative = Vector2(70,40)
	motion.button_mask = MOUSE_BUTTON_MASK_MIDDLE
	rig._unhandled_input(motion)
	check(rig.target_yaw != before_orbit and world.grid.cells == cells, "Shift drag remains orbit and does not mutate the grid")
	press.pressed = false
	rig._input(press)
	check(rig.drag_button == 0, "Mouse release ends orbit")
	var state = rig.get_transition_state()
	check(not state.has("free_offset") and not state.has("free_position_offset"), "Transition state has no removed pan data")
	rig.configure_targets(center + Vector3(200,0,20), player, state)
	check(rig.mode == "Follow Player" and rig.global_position.is_equal_approx(player.global_position), "Region restore follows the new actual player target")
	check(is_equal_approx(rig.pitch, state.pitch) and is_equal_approx(rig.target_zoom, state.target_zoom), "Region restore retains view state")
	state.mode = "Free Camera"
	rig.configure_targets(center, player, state)
	check(rig.mode == "Follow Player", "Removed runtime mode restores safely to Follow Player")
	rig.set_mode("Board Center")
	settings.volumes.Master = 0.5
	settings.apply_settings()
	check(rig.mode == "Board Center", "Audio changes preserve temporary runtime mode")
	settings.camera_mode = "Board Center"
	settings.apply_settings()
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
	check(options.content.get_node("CameraModeRow/CameraMode").item_count == 2, "Gameplay exposes two defaults")
	settings.reset_category("Gameplay")
	check(rig.mode == "Follow Player" and settings.camera_projection == "Orthographic", "Gameplay reset restores mode and projection")
	flow.resume()
	rig._unhandled_input(cycle)
	check(rig.mode == "Board Center", "Resume restores camera input")
	flow.main_menu()
	await process_frame
	await process_frame
	DirAccess.remove_absolute(settings.storage_path)
	if FileAccess.file_exists(saves.storage_path):
		DirAccess.remove_absolute(saves.storage_path)
	print("CAMERA MODES: ", checks, " checks, ", failures, " failures")
	quit(0 if failures == 0 else 1)
