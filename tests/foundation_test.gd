extends SceneTree
var failures = 0
var checks = 0
func check(value: bool, message: String):
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func _initialize():
	call_deferred("run")

func run():
	var settings = root.get_node("SettingsManager")
	var saves = root.get_node("SaveManager")
	var flow = root.get_node("SceneFlow")
	settings.storage_path = "user://foundation_test_settings.cfg"
	saves.storage_path = "user://foundation_test_progression.json"
	saves.run_path = "user://foundation_test_run.json"
	for path in [settings.storage_path, saves.storage_path, saves.run_path]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	check(not saves.load_progression(), "Missing progression must return defaults")
	check(saves.progression.knowledge == 0, "Default knowledge")
	check(not saves.has_resumable_run(), "No fake resumable run")
	check(saves.save_progression({"discoveries": ["test.discovery"], "knowledge": 3, "upgrades": []}) == OK, "Save progression")
	saves.progression = {}
	check(saves.load_progression() and saves.progression.knowledge == 3, "Reload progression")
	check(saves.save_progression({"discoveries": ["test.discovery"], "knowledge": 5, "upgrades": []}) == OK and saves.load_progression() and saves.progression.knowledge == 5, "Atomic replacement of existing progression")
	check(saves.save_progression({"knowledge": -1}) == ERR_INVALID_DATA, "Reject invalid progression")
	var invalid = FileAccess.open(saves.storage_path, FileAccess.WRITE)
	invalid.store_string("not json")
	invalid.close()
	check(not saves.load_progression() and saves.progression.knowledge == 0, "Malformed progression defaults")
	var wrong = FileAccess.open(saves.storage_path, FileAccess.WRITE)
	wrong.store_string('{"version": 99, "progression": {}}')
	wrong.close()
	check(not saves.load_progression(), "Unsupported version rejected")
	check(settings.reset_defaults() == OK, "Save defaults")
	check(settings.rebind("move_north", 0, KEY_K) == "", "Rebind primary")
	check(settings.rebind("move_north", 1, KEY_I) == "", "Rebind secondary")
	check(settings.rebind("move_south", 0, KEY_K) != "", "Reject conflict")
	settings.volumes = {"Master": 0.4, "Music": 0.25, "SFX": 0.6}
	settings.fps_limit = 30
	settings.apply_settings()
	check(is_equal_approx(AudioServer.get_bus_volume_linear(AudioServer.get_bus_index("Music")), 0.25), "Music bus volume")
	check(is_equal_approx(AudioServer.get_bus_volume_linear(AudioServer.get_bus_index("SFX")), 0.6), "SFX bus volume")
	check(is_equal_approx(AudioServer.get_bus_volume_linear(0), 0.4), "Master bus volume")
	check(Engine.max_fps == 30, "FPS applied")
	check(settings.save_settings() == OK, "Save settings")
	var second = load("res://features/settings/settings_manager.gd").new()
	second.storage_path = settings.storage_path
	root.add_child(second)
	check(second.bindings.move_north == [KEY_K, KEY_I] and second.fps_limit == 30, "Fresh instance reloads settings and both bindings")
	check(is_equal_approx(second.volumes.Music, 0.25), "Fresh instance audio reload")
	var corrupt = ConfigFile.new()
	corrupt.set_value("video", "fps_limit", "bad")
	corrupt.set_value("audio", "Music", "bad")
	corrupt.set_value("controls", "bindings", {"move_north": [KEY_K]})
	corrupt.save(settings.storage_path)
	var bad_settings = load("res://features/settings/settings_manager.gd").new()
	bad_settings.storage_path = settings.storage_path
	root.add_child(bad_settings)
	check(bad_settings.fps_limit == 60 and bad_settings.bindings == bad_settings.DEFAULT_BINDINGS, "Malformed setting values safely default")
	second.queue_free()
	bad_settings.queue_free()
	settings.reset_defaults()
	check(settings.bindings == settings.DEFAULT_BINDINGS and settings.fps_limit == 60, "Reset settings")
	check(InputMap.has_action("interact") and InputMap.has_action("pause"), "Central actions exist")
	check(InputMap.action_get_events("ui_accept").size() > 0, "Menu actions retained")
	check(flow.transition(flow.MAIN_MENU) == OK, "Load main menu")
	await process_frame
	await process_frame
	var menu = current_scene
	check(menu != null and menu.get_node("Panel/Rows/Continue").disabled, "Continue disabled")
	menu.get_node("Panel/Rows/Options").pressed.emit()
	await process_frame
	check(is_instance_valid(menu.options), "Main menu Options")
	var options = menu.options
	for category in ["Gameplay", "Video", "Audio", "Controls"]:
		options.show_category(category)
		check(options.content.get_child_count() > 0, "Options category " + category)
		check(options.category_buttons[category].button_pressed, "Active sidebar category " + category)
		var selected = 0
		for button in options.category_buttons.values():
			selected += int(button.button_pressed)
		check(selected == 1, "Only one active sidebar category")
		check(not (options.content.get_child(0) is Label and options.content.get_child(0).text == category), "No duplicate category heading")
	options.show_category("Audio")
	options.content.get_child(1).value = 0.33
	check(is_equal_approx(AudioServer.get_bus_volume_linear(0), 0.33), "Audio UI slider drives Master bus")
	options.show_category("Controls")
	options.content.get_child(0).get_child(1).pressed.emit()
	var bind_key = InputEventKey.new()
	bind_key.physical_keycode = KEY_K
	bind_key.pressed = true
	options._input(bind_key)
	check(settings.bindings.move_north[0] == KEY_K, "Controls UI captures key")
	options.defaults_button.pressed.emit()
	check(settings.bindings == settings.DEFAULT_BINDINGS, "Controls UI restores defaults")
	options.close()
	await process_frame
	menu.get_node("Panel/Rows/NewGame").pressed.emit()
	await process_frame
	await process_frame
	check(current_scene.scene_file_path == flow.playable_scene, "New Game transitions")
	var pause_event = InputEventKey.new()
	pause_event.physical_keycode = KEY_ESCAPE
	pause_event.pressed = true
	flow._unhandled_key_input(pause_event)
	await process_frame
	check(paused and is_instance_valid(flow.pause_menu), "Pause via input")
	flow.pause_menu.get_node("Panel/Rows/Options").pressed.emit()
	await process_frame
	check(is_instance_valid(flow.pause_menu.options), "Shared Options from pause")
	flow.pause_menu.close_top_panel()
	await process_frame
	check(paused and not is_instance_valid(flow.pause_menu.options), "Close nested Options remains paused")
	flow.pause_menu.get_node("Panel/Rows/Resume").pressed.emit()
	await process_frame
	check(not paused and flow.pause_menu == null, "Resume button")
	flow.open_pause()
	flow.pause_menu.get_node("Panel/Rows/MainMenu").pressed.emit()
	await process_frame
	await process_frame
	check(not paused and current_scene.scene_file_path == flow.MAIN_MENU, "Return to main menu resets pause")
	for path in [settings.storage_path, saves.storage_path, saves.run_path]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	print("FOUNDATION: ", checks, " checks, ", failures, " failures")
	quit(0 if failures == 0 else 1)
