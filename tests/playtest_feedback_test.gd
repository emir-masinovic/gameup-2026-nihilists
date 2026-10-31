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
	settings.storage_path = "user://feedback_test_settings.cfg"
	settings.reset_defaults()
	settings.volumes.Music = 0.21
	settings.bindings.move_north[0] = KEY_K
	settings.fps_limit = 120
	settings.msaa_3d = Viewport.MSAA_4X
	settings.shadow_quality = 3
	settings.resolution = Vector2i(1280, 720)
	check(settings.reset_category("Audio") == OK, "Audio reset saves")
	check(settings.volumes.Music == 0.8, "Audio defaults")
	check(settings.fps_limit == 120 and settings.msaa_3d == Viewport.MSAA_4X and settings.bindings.move_north[0] == KEY_K, "Audio reset preserves Video and Controls")
	settings.volumes.Music = 0.21
	check(settings.reset_category("Controls") == OK, "Controls reset saves")
	check(settings.bindings == settings.DEFAULT_BINDINGS, "Controls defaults")
	check(settings.volumes.Music == 0.21 and settings.fps_limit == 120, "Controls reset preserves Audio and Video")
	settings.bindings.move_north[0] = KEY_K
	check(settings.reset_category("Video") == OK, "Video reset saves")
	check(settings.resolution == Vector2i(1152, 720) and settings.fps_limit == 60 and settings.msaa_3d == Viewport.MSAA_2X and settings.shadow_quality == 2, "Video defaults")
	check(settings.volumes.Music == 0.21 and settings.bindings.move_north[0] == KEY_K, "Video reset preserves Audio and Controls")
	check(settings.reset_category("Gameplay") == OK, "Gameplay restores projection")
	var legacy = ConfigFile.new()
	legacy.set_value("audio", "Music", 0.42)
	legacy.set_value("video", "fps_limit", 30)
	legacy.set_value("controls", "bindings", settings.DEFAULT_BINDINGS)
	legacy.save(settings.storage_path)
	var old = load("res://features/settings/settings_manager.gd").new()
	old.storage_path = settings.storage_path
	root.add_child(old)
	check(old.volumes.Music == 0.42 and old.fps_limit == 30, "Legacy settings preserved")
	check(old.resolution == Vector2i(1152, 720) and old.msaa_3d == Viewport.MSAA_2X and old.shadow_quality == 2, "New graphics fields default in legacy config")
	old.queue_free()
	settings.resolution = Vector2i(1280, 720)
	settings.msaa_3d = Viewport.MSAA_4X
	settings.shadow_quality = 3
	settings.save_settings()
	var reloaded = load("res://features/settings/settings_manager.gd").new()
	reloaded.storage_path = settings.storage_path
	root.add_child(reloaded)
	check(reloaded.resolution == Vector2i(1280, 720) and reloaded.msaa_3d == Viewport.MSAA_4X and reloaded.shadow_quality == 3, "New graphics fields reload")
	reloaded.queue_free()
	settings.apply_settings()
	check(root.msaa_3d == Viewport.MSAA_4X, "MSAA actually applied to viewport")
	var invalid = ConfigFile.new()
	invalid.set_value("video", "resolution", Vector2i(-1, 0))
	invalid.set_value("video", "msaa_3d", 99)
	invalid.set_value("video", "shadow_quality", "bad")
	invalid.save(settings.storage_path)
	var bad = load("res://features/settings/settings_manager.gd").new()
	bad.storage_path = settings.storage_path
	root.add_child(bad)
	check(bad.resolution == Vector2i(1152, 720) and bad.msaa_3d == Viewport.MSAA_2X and bad.shadow_quality == 2, "Malformed graphics values default safely")
	bad.queue_free()
	settings.reset_defaults()
	var flow = root.get_node("SceneFlow")
	flow.main_menu()
	await process_frame
	await process_frame
	check(not current_scene.has_node("Panel/Rows/Title"), "No invented game title")
	check(current_scene.get_node("Panel") is CenterContainer, "Main menu has no visible oversized panel")
	current_scene.open_options()
	await process_frame
	var options = current_scene.options
	for category in ["Gameplay", "Video", "Audio", "Controls"]:
		options.show_category(category)
		check(not options.defaults_button.disabled, "Category reset availability " + category)
		check(options.back_button.get_parent() == options.defaults_button.get_parent(), "Shared footer " + category)
		check(options.back_button.size.x < options.size.x * 0.5 and options.defaults_button.size.x < options.size.x * 0.5, "Compact footer " + category)
	options.show_category("Video")
	check(options.content.has_node("ResolutionRow/Resolution") and options.content.has_node("MSAARow/MSAA") and options.content.has_node("ShadowsRow/Shadows"), "Real graphics selectors")
	check(options.content.get_node("ResolutionRow/Resolution").disabled == not settings.desktop_display_supported(), "Resolution backend support")
	options.content.get_node("MSAARow/MSAA/4x").pressed.emit()
	check(root.msaa_3d == Viewport.MSAA_4X, "MSAA UI applies")
	options.show_category("Controls")
	check(options.content.has_node("MouseSensitivity"), "Controls includes camera sensitivity")
	options.close()
	await process_frame
	flow.new_game()
	await process_frame
	await process_frame
	var world = current_scene
	var hud = world.get_node("HUD/Info")
	check(hud.text == "FOREST" and hud.anchor_right == 1.0 and hud.horizontal_alignment == HORIZONTAL_ALIGNMENT_RIGHT, "Only FOREST at upper right")
	var ground = world.get_node("Terrain").get_child(0)
	check(ground.mesh.size.x == world.grid.CELL_SIZE and ground.mesh.size.z == world.grid.CELL_SIZE, "No subpixel tile gaps; same grid spacing")
	for quality in [0, 1, 2, 3]:
		settings.shadow_quality = quality
		settings.apply_settings()
		check(world.get_node("Sun").shadow_enabled == (quality > 0), "Shadow enabled state " + str(quality))
		check(settings.shadow_atlas_size() == [512, 512, 1024, 2048][quality], "Directional atlas preset " + str(quality))
	flow.open_pause()
	await process_frame
	check(flow.pause_menu.get_node("Panel") is CenterContainer, "Compact pause menu")
	flow.pause_menu.open_options()
	await process_frame
	options = flow.pause_menu.options
	check(flow.pause_layer.layer > world.get_node("HUD").layer and options.get_canvas_layer_node() == flow.pause_layer, "Options draws above HUD")
	check(options.get_theme_stylebox("panel").bg_color.a == 1.0, "Options background opaque")
	options.back_button.pressed.emit()
	await process_frame
	check(paused and not is_instance_valid(flow.pause_menu.options), "Back returns to Pause")
	flow.pause_menu.get_node("Panel/Rows/Resume").pressed.emit()
	await process_frame
	check(not paused and flow.pause_layer == null, "Resume clears overlay layer")
	flow.main_menu()
	await process_frame
	await process_frame
	DirAccess.remove_absolute(settings.storage_path)
	print("FEEDBACK: ", checks, " checks, ", failures, " failures")
	quit(0 if failures == 0 else 1)
