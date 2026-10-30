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
		var valid = settings.bindings.move_north == [KEY_K, KEY_I] and is_equal_approx(settings.volumes.Music, 0.37) and Engine.max_fps == 120 and settings.resolution == Vector2i(1280, 720) and root.msaa_3d == Viewport.MSAA_4X and settings.shadow_quality == 3
		DirAccess.remove_absolute(settings.storage_path)
		print("RESTART: fresh-process reload ", "PASS" if valid else "FAIL")
		quit(0 if valid else 1)
		return
	quit(0)
