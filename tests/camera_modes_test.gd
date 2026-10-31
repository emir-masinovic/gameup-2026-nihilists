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
	legacy.erase("chop_gather")
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
	check(settings.camera_mode == "Free Camera", "Free Camera is a supported saved mode")
	settings.save_settings()
	config.load(settings.storage_path)
	check(config.get_value("gameplay", "camera_mode") == "Free Camera", "Next save persists Free Camera")
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
	rig.configure_targets(center,player,{"mode":"Follow Player","zoom":1.0})
	check(rig.target_zoom == 5.0,"Follow mode allows twice as close orthographic zoom")
	for projection in ["Orthographic","Perspective"]:
		settings.camera_projection = projection
		rig._apply_projection()
		var camera = rig.get_node("Camera3D")
		check(camera.position.length() > 6.9 and is_equal_approx(camera.near,0.1),"Close follow camera retains safe distance and near plane in "+projection)
	rig.set_mode("Board Center")
	check(rig.target_zoom == 10.0 and rig.get_node("Camera3D").size == 10.0,"Board Center keeps its original minimum zoom")
	rig.set_mode("Follow Player")
	settings.camera_projection = "Orthographic"
	rig._apply_projection()
	check(settings.CAMERA_MODES == ["Follow Player", "Board Center", "Free Camera"], "Exactly three public camera modes")
	var cycle = InputEventKey.new()
	cycle.physical_keycode = KEY_C
	cycle.pressed = true
	rig._unhandled_input(cycle)
	check(rig.mode == "Board Center" and settings.camera_mode == "Board Center", "C synchronizes Board Center with saved mode")
	rig._unhandled_input(cycle)
	check(rig.mode == "Free Camera", "C cycles into Free Camera")
	rig._unhandled_input(cycle)
	check(rig.mode == "Follow Player", "C cycles back to Follow Player")
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
	state.mode = "InvalidMode"
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
	rig.set_mode("Free Camera")
	var position_before = rig.global_position
	var player_cell_before = player.cell
	var arrow = InputEventKey.new()
	arrow.keycode = KEY_UP
	arrow.physical_keycode = KEY_UP
	arrow.pressed = true
	Input.parse_input_event(arrow)
	rig._process(0.2)
	player._process(0.2)
	check(rig.global_position.distance_to(position_before) > 0.5 and player.cell == player_cell_before,"Free Camera arrows move the camera while suppressing player movement")
	arrow.pressed = false
	Input.parse_input_event(arrow.duplicate())
	var eye = rig.get_node("Camera3D").global_position
	rig.target_yaw += 0.3
	rig._process(1.0)
	check(rig.get_node("Camera3D").global_position.distance_to(eye) < 0.01,"Free mouse-look rotates around its viewing position")
	rig.set_mode("Follow Player")
	check(not player.camera_controlled,"Leaving Free Camera restores player control")
	check(not world.has_node("Bonfire") and world.climate.bonfire_intensity == 0.0 and world._interaction_candidates().all(func(item): return item.object_kind != "bonfire"),"No automatic bonfire, interaction or soil heat remains")
	world.survival.health = 60.0
	world.survival.wetness = 40.0
	world.climate.weather_override = "rain"
	world._process(1.0)
	check(world.survival.health == 60.0 and world.survival.wetness > 40.0 and world.climate.bonfire_intensity == 0.0,"Spawn has no invisible camp healing, drying or warmth")
	flow.open_pause()
	var saved_progress = saves.progression.duplicate(true)
	saves.save_progression({"discoveries":[],"knowledge":10,"upgrades":[]})
	flow.pause_menu.open_perks()
	check(world.hud.modal_kind == "perks" and paused,"Pause opens the existing perk panel")
	if DisplayServer.get_name() != "headless" and OS.has_environment("NIHILISTS_CAPTURE_DIR"):
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OS.get_environment("NIHILISTS_CAPTURE_DIR").path_join("pause-perks.png"))
	world.hud.get_node("Modal/Rows/QuickChop").pressed.emit()
	check(saves.has_upgrade("quick_chop") and saves.progression.knowledge == 8,"Pause perk purchase reuses existing costs")
	world.hud.close_modal()
	check(paused and flow.pause_menu.get_node("Panel").visible,"Closing perks returns to Pause without resuming")
	saves.save_progression(saved_progress)
	rig._unhandled_input(cycle)
	check(rig.mode == "Follow Player" and rig.drag_button == 0, "Pause rejects camera cycling")
	flow.pause_menu.open_options()
	await process_frame
	rig._unhandled_input(cycle)
	check(rig.mode == "Follow Player", "Options rejects camera cycling")
	var options = flow.pause_menu.options
	options.show_category("Gameplay")
	check(options.content.get_node("CameraModeRow/CameraMode").get_child_count() == 3, "Gameplay exposes three segmented choices")
	for size in [Vector2i(960,600),Vector2i(1152,720),Vector2i(1600,900)]:
		root.size = size
		root.content_scale_size = size
		await process_frame
		await process_frame
		var modes_row = options.content.get_node("CameraModeRow/CameraMode")
		check(modes_row.get_global_rect().end.x <= size.x,"Camera segments fit at "+str(size))
		if DisplayServer.get_name() != "headless" and OS.has_environment("NIHILISTS_CAPTURE_DIR"):
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(OS.get_environment("NIHILISTS_CAPTURE_DIR").path_join("camera-options-%dx%d.png" % [size.x,size.y]))
	options.content.get_node("CameraModeRow/CameraMode/Free Camera").pressed.emit()
	check(rig.mode == "Free Camera" and settings.camera_mode == "Free Camera","Gameplay segment applies Free Camera immediately")
	settings.save_settings()
	settings.camera_mode = "Follow Player"
	settings.load_settings()
	check(settings.camera_mode == "Free Camera","Free Camera setting reloads")
	settings.reset_category("Gameplay")
	check(rig.mode == "Follow Player" and settings.camera_projection == "Orthographic", "Gameplay reset restores mode and projection")
	flow.resume()
	rig._unhandled_input(cycle)
	check(rig.mode == "Board Center", "Resume restores camera input")
	for destination in ["drylands","forest","wetlands"]:
		flow.change_region(destination)
		await process_frame
		await process_frame
		var region_world = current_scene
		region_world.set_process(false)
		check(not region_world.has_node("Bonfire") and region_world.climate.bonfire_intensity == 0.0 and region_world._interaction_candidates().all(func(item): return item.object_kind != "bonfire"),"No automatic camp remains in "+destination)
	flow.main_menu()
	await process_frame
	await process_frame
	DirAccess.remove_absolute(settings.storage_path)
	if FileAccess.file_exists(saves.storage_path):
		DirAccess.remove_absolute(saves.storage_path)
	print("CAMERA MODES: ", checks, " checks, ", failures, " failures")
	quit(0 if failures == 0 else 1)
