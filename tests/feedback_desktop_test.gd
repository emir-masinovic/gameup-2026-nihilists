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
func capture(name: String) -> Image:
	await create_timer(0.25).timeout
	await RenderingServer.frame_post_draw
	var image = root.get_texture().get_image()
	if OS.has_environment("NIHILISTS_CAPTURE_DIR"):
		image.save_png(OS.get_environment("NIHILISTS_CAPTURE_DIR").path_join(name + ".png"))
	return image
func in_view(control: Control) -> bool:
	return root.get_visible_rect().grow(1).encloses(control.get_global_rect())
func run():
	var settings = root.get_node("SettingsManager")
	settings.storage_path = "user://feedback_desktop_settings.cfg"
	settings.reset_defaults()
	var flow = root.get_node("SceneFlow")
	for size_value in [Vector2i(800, 600), Vector2i(1152, 720), Vector2i(1600, 900)]:
		settings.resolution = size_value
		settings.apply_settings()
		await create_timer(0.3).timeout
		check(DisplayServer.window_get_size() == size_value, "Actual window resolution " + str(size_value))
		check(settings.available_resolutions().has(DisplayServer.window_get_size()), "Current resolution included")
		flow.main_menu()
		await process_frame
		await process_frame
		await capture("menu_%d" % size_value.x)
		check(in_view(current_scene.get_node("Panel/Rows")), "Main menu within viewport")
		current_scene.open_options()
		await process_frame
		var options = current_scene.options
		var footer_y = -1.0
		for category in ["Gameplay", "Video", "Audio", "Controls"]:
			options.show_category(category)
			await process_frame
			await capture("options_%s_%d" % [category.to_lower(), size_value.x])
			check(in_view(options.back_button) and in_view(options.defaults_button), "Footer fits " + category)
			check(options.back_button.position.y == options.defaults_button.position.y, "Footer baseline " + category)
			check(footer_y < 0 or is_equal_approx(options.back_button.global_position.y, footer_y), "Footer fixed while switching " + category)
			footer_y = options.back_button.global_position.y
		options.close()
		await process_frame
		flow.new_game()
		await process_frame
		await process_frame
		check(in_view(current_scene.get_node("HUD/Info")), "HUD fits viewport")
		flow.open_pause()
		await process_frame
		await capture("pause_%d" % size_value.x)
		check(in_view(flow.pause_menu.get_node("Panel/Rows")), "Pause menu fits viewport")
		flow.pause_menu.open_options()
		await process_frame
		flow.pause_menu.options.show_category("Video")
		await capture("pause_options_%d" % size_value.x)
		check(paused, "Options from Pause remains paused")
		flow.resume()
		await process_frame
	# Fullscreen uses the desktop size, preserving chosen windowed resolution.
	settings.resolution = Vector2i(1024, 768)
	settings.fullscreen = true
	settings.apply_settings()
	await create_timer(0.3).timeout
	check(DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN, "Fullscreen mode")
	flow.open_pause()
	flow.pause_menu.open_options()
	await process_frame
	flow.pause_menu.options.show_category("Video")
	check(flow.pause_menu.options.content.get_node("Resolution").disabled, "Resolution disabled in fullscreen")
	flow.resume()
	settings.fullscreen = false
	settings.apply_settings()
	await create_timer(0.3).timeout
	check(DisplayServer.window_get_size() == Vector2i(1024, 768), "Windowed resolution restored after fullscreen")
	settings.resolution = Vector2i(1152, 720)
	settings.apply_settings()
	await create_timer(0.2).timeout
	var shadow_images: Array[Image] = []
	settings.msaa_3d = Viewport.MSAA_DISABLED
	for quality in range(4):
		settings.shadow_quality = quality
		settings.apply_settings()
		shadow_images.append(await capture("shadow_%d" % quality))
	for index in range(3):
		check(shadow_images[index].get_data() != shadow_images[index + 1].get_data(), "Rendered shadow presets differ " + str(index))
	settings.shadow_quality = 2
	var aa_images: Array[Image] = []
	for aa in range(3):
		settings.msaa_3d = aa
		settings.apply_settings()
		check(root.msaa_3d == aa, "Actual MSAA viewport value " + str(aa))
		aa_images.append(await capture("msaa_%d" % aa))
	check(aa_images[0].get_data() != aa_images[1].get_data(), "Rendered Disabled vs 2x differ")
	check(aa_images[1].get_data() != aa_images[2].get_data(), "Rendered 2x vs 4x differ")
	# Applying unrelated settings must not undo a manually resized window.
	DisplayServer.window_set_size(Vector2i(1000, 700))
	await create_timer(0.2).timeout
	settings.apply_settings()
	check(DisplayServer.window_get_size() == Vector2i(1000, 700), "Unrelated settings preserve manual resize")
	flow.main_menu()
	await process_frame
	await process_frame
	if FileAccess.file_exists(settings.storage_path):
		DirAccess.remove_absolute(settings.storage_path)
	print("FEEDBACK DESKTOP: ", checks, " checks, ", failures, " failures")
	quit(0 if failures == 0 else 1)
