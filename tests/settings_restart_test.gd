extends SceneTree
func _initialize():
	call_deferred("run")
func run():
	var settings = root.get_node("SettingsManager")
	settings.storage_path = "user://settings_restart_test.cfg"
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
