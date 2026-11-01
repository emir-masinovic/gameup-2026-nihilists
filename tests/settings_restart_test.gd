extends SceneTree
func _initialize():
	call_deferred("run")
func run():
	var settings = root.get_node("SettingsManager")
	settings.storage_path = "user://settings_restart_test.cfg"
	if "--resolution-write" in OS.get_cmdline_user_args():
		await check_native_resolution(settings)
		return
	if "--resolution-read" in OS.get_cmdline_user_args():
		settings.load_settings()
		settings.apply_settings()
		await create_timer(0.2).timeout
		var expected = Vector2i(1280,720) if "--resolution-1280" in OS.get_cmdline_user_args() else Vector2i(1600,900)
		var valid = settings.resolution == expected and root.size == expected and DisplayServer.window_get_size() == expected
		print("NATIVE RESTART requested=",settings.resolution," root=",root.size," native=",DisplayServer.window_get_size()," PASS=",valid)
		DirAccess.remove_absolute(settings.storage_path)
		quit(0 if valid else 1)
		return
	if "--write" in OS.get_cmdline_user_args():
		settings.reset_defaults()
		settings.rebind("move_north", 0, KEY_K)
		settings.rebind("move_north", 1, KEY_I)
		settings.volumes.Music = 0.37
		settings.rebind("camera_orbit", 0, -MOUSE_BUTTON_XBUTTON1)
		settings.rebind("camera_zoom_in", 0, -MOUSE_BUTTON_WHEEL_LEFT)
		settings.camera_projection = "Perspective"
		settings.camera_mode = "Follow Player"
		settings.rebind("camera_mode_cycle", 0, KEY_V)
		settings.rebind("eat", 0, KEY_G)
		settings.mouse_sensitivity = 0.015
		settings.fps_limit = 120
		settings.resolution = Vector2i(1280, 720)
		settings.msaa_3d = Viewport.MSAA_4X
		settings.shadow_quality = 3
		if settings.save_settings() != OK:
			quit(1)
			return
		print("RESTART: wrote isolated settings")
	else:
		settings.load_settings()
		settings.apply_settings()
		var valid = settings.camera_projection == "Perspective" and settings.bindings.camera_orbit[0] == -MOUSE_BUTTON_XBUTTON1 and settings.bindings.camera_zoom_in[0] == -MOUSE_BUTTON_WHEEL_LEFT and is_equal_approx(settings.mouse_sensitivity, 0.015) and settings.bindings.move_north == [KEY_K, KEY_I] and is_equal_approx(settings.volumes.Music, 0.37) and Engine.max_fps == 120 and settings.resolution == Vector2i(1280, 720) and root.msaa_3d == Viewport.MSAA_4X and settings.shadow_quality == 3
		valid = valid and settings.camera_mode == "Follow Player" and settings.bindings.camera_mode_cycle[0] == KEY_V and settings.bindings.eat[0] == KEY_G
		DirAccess.remove_absolute(settings.storage_path)
		print("RESTART: fresh-process reload ", "PASS" if valid else "FAIL")
		quit(0 if valid else 1)
		return
	quit(0)

func check_native_resolution(settings: Node):
	settings.fullscreen = false
	settings.apply_settings()
	var options = load("res://features/menus/options_menu.tscn").instantiate()
	root.add_child(options)
	options.show_category("Video")
	await process_frame
	var failures = 0
	var test_sizes = [Vector2i(1280,720)] if "--resolution-1280" in OS.get_cmdline_user_args() else [Vector2i(1280,720),Vector2i(1600,900)]
	for size in test_sizes:
		var choice = options.content.get_node("ResolutionRow/Resolution")
		var index = -1
		for i in range(choice.item_count):
			if choice.get_item_text(i) == "%d × %d" % [size.x,size.y]: index = i
		if index < 0:
			push_error("Required test resolution is unavailable on this display")
			quit(1)
			return
		choice.select(index)
		choice.item_selected.emit(index)
		await create_timer(0.2).timeout
		var valid = settings.resolution == size and root.size == size and DisplayServer.window_get_size() == size
		print("NATIVE SELECT ",size," actual=",DisplayServer.window_get_size()," PASS=",valid)
		if not valid: failures += 1
		# Reproduce a native resize after the cached requested size was recorded.
		DisplayServer.window_set_size(Vector2i(1152,720))
		await create_timer(0.1).timeout
		choice.item_selected.emit(index)
		await create_timer(0.2).timeout
		valid = root.size == size and DisplayServer.window_get_size() == size
		print("NATIVE RESELECT ",size," actual=",DisplayServer.window_get_size()," PASS=",valid)
		if not valid: failures += 1
	quit(1 if failures > 0 else 0)
