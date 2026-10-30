extends SceneTree
var failures = 0
func check(value, message):
	if not value:
		failures += 1
		push_error(message)
func _initialize():
	call_deferred("run")
func run():
	var settings = root.get_node("SettingsManager")
	settings.storage_path = "user://mouse_bindings_test.cfg"
	settings.reset_defaults()
	check(settings.rebind("camera_orbit", 0, -MOUSE_BUTTON_RIGHT) != "", "Reject duplicate orbit slot")
	check(settings.rebind("camera_orbit", 0, -MOUSE_BUTTON_XBUTTON1) == "", "Rebind orbit")
	check(settings.rebind("interact", 0, -MOUSE_BUTTON_XBUTTON1) != "", "Cross gameplay/camera conflict")
	check(settings.rebind("camera_zoom_in", 0, -MOUSE_BUTTON_WHEEL_LEFT) == "", "Rebind zoom")
	var mouse = InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_XBUTTON1
	mouse.pressed = true
	check(mouse.is_action_pressed("camera_orbit"), "InputMap mouse binding applied")
	settings.save_settings()
	settings.bindings = settings.DEFAULT_BINDINGS.duplicate(true)
	settings.load_settings()
	check(settings.bindings.camera_orbit[0] == -MOUSE_BUTTON_XBUTTON1, "Mouse binding reload")
	root.get_node("SceneFlow").main_menu()
	await process_frame
	await process_frame
	current_scene.open_options()
	await process_frame
	var options = current_scene.options
	options.show_category("Controls")
	options.waiting_action = "camera_orbit"
	options.waiting_slot = 0
	var release = InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	options._input(release)
	check(options.waiting_action == "camera_orbit", "Opening click release not captured")
	options._input(mouse)
	check(options.waiting_action == "" and settings.bindings.camera_orbit[0] == -MOUSE_BUTTON_XBUTTON1, "Mouse capture completes")
	options.defaults_button.pressed.emit()
	check(settings.bindings == settings.DEFAULT_BINDINGS and settings.mouse_sensitivity == settings.DEFAULT_MOUSE_SENSITIVITY, "Controls resets all input")
	DirAccess.remove_absolute(settings.storage_path)
	print("MOUSE BINDINGS: 9 checks, ", failures, " failures")
	quit(0 if failures == 0 else 1)
