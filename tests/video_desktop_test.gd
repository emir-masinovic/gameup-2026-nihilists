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
func measure_fps(seconds: float) -> float:
	await create_timer(0.6).timeout
	var start = Time.get_ticks_usec()
	var frames = 0
	while (Time.get_ticks_usec() - start) / 1000000.0 < seconds:
		await process_frame
		frames += 1
	return frames / ((Time.get_ticks_usec() - start) / 1000000.0)
func run():
	var settings = root.get_node("SettingsManager")
	settings.storage_path = "user://video_desktop_test.cfg"
	settings.reset_defaults()
	root.get_node("SceneFlow").main_menu()
	await process_frame
	await process_frame
	current_scene.open_options()
	await process_frame
	var options = current_scene.options
	options.show_category("Video")
	var sizes = settings.available_resolutions()
	for size_value in [Vector2i(800, 600), Vector2i(1280, 720)]:
		var index = sizes.find(size_value)
		check(index >= 0, "Standalone resolution offered")
		options.content.get_node("Resolution").item_selected.emit(index)
		await create_timer(0.3).timeout
		check(DisplayServer.window_get_size() == size_value, "UI selector resizes actual native window " + str(size_value))
		check(root.get_visible_rect().grow(1).encloses(options.back_button.get_global_rect()), "Options usable after actual resize")
	var config = ConfigFile.new()
	config.load(settings.storage_path)
	check(config.get_value("video", "resolution") == Vector2i(1280, 720), "Resolution selection saved")
	options.close()
	await process_frame
	settings.vsync = false
	for cap in [60, 120, 0]:
		settings.fps_limit = cap
		settings.apply_settings()
		check(Engine.max_fps == cap, "Selected FPS cap applied " + str(cap))
		var measured = await measure_fps(2.0)
		print("FPS selected=", cap, " vsync=off measured=", snappedf(measured, 0.1), " monitor=", Performance.get_monitor(Performance.TIME_FPS), " refresh_hz=", DisplayServer.screen_get_refresh_rate())
		check(measured > 0 and (cap == 0 or measured < cap * 1.2), "Measured FPS respects cap")
	settings.fps_limit = 120
	settings.vsync = true
	settings.apply_settings()
	var vsync_fps = await measure_fps(2.0)
	print("FPS selected=120 vsync=on measured=", snappedf(vsync_fps, 0.1), " refresh_hz=", DisplayServer.screen_get_refresh_rate())
	check(DisplayServer.window_get_vsync_mode() == DisplayServer.VSYNC_ENABLED, "VSync still applied")
	DirAccess.remove_absolute(settings.storage_path)
	print("VIDEO DESKTOP: ", checks, " checks, ", failures, " failures")
	quit(0 if failures == 0 else 1)
