extends SceneTree
var failures = 0
func check(value: bool, message: String):
	if not value:
		failures += 1
		push_error(message)
func _initialize():
	call_deferred("run")
func run():
	var settings = root.get_node("SettingsManager")
	settings.fullscreen = true
	settings.apply_settings()
	await create_timer(0.4).timeout
	check(DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN, "Desktop fullscreen")
	settings.fullscreen = false
	settings.vsync = false
	settings.apply_settings()
	await create_timer(0.4).timeout
	check(DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_WINDOWED, "Desktop windowed")
	check(DisplayServer.window_get_vsync_mode() == DisplayServer.VSYNC_DISABLED, "Desktop VSync off")
	settings.vsync = true
	settings.apply_settings()
	await create_timer(0.4).timeout
	check(DisplayServer.window_get_vsync_mode() == DisplayServer.VSYNC_ENABLED, "Desktop VSync on")
	root.get_node("SceneFlow").main_menu()
	await process_frame
	await create_timer(0.4).timeout
	await RenderingServer.frame_post_draw
	if OS.has_environment("NIHILISTS_CAPTURE_DIR"):
		root.get_texture().get_image().save_png(OS.get_environment("NIHILISTS_CAPTURE_DIR").path_join("main_menu.png"))
	current_scene.open_options()
	await process_frame
	current_scene.options.show_category("Controls")
	await create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	if OS.has_environment("NIHILISTS_CAPTURE_DIR"):
		root.get_texture().get_image().save_png(OS.get_environment("NIHILISTS_CAPTURE_DIR").path_join("options_menu.png"))
	print("DESKTOP: 4 checks, ", failures, " failures")
	quit(0 if failures == 0 else 1)
