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
	settings.storage_path = "user://settings_layout_test.cfg"
	settings.reset_defaults()
	var menu = load("res://features/menus/options_menu.tscn").instantiate()
	root.add_child(menu)
	menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await process_frame
	var projection = menu.content.get_node("CameraProjectionRow/CameraProjection")
	check(projection.get_theme_constant("separation") == 12, "Projection spacing")
	check(projection.get_child_count() == 2, "Projection has two segments")
	projection.get_node("Perspective").button_pressed = true
	projection.get_node("Perspective").pressed.emit()
	check(settings.camera_projection == "Perspective" and not projection.get_node("Orthographic").button_pressed, "Projection exclusive and applies")
	menu.restore_category()
	check(settings.camera_projection == "Orthographic", "Gameplay defaults select Orthographic")
	menu.show_category("Video")
	await process_frame
	await process_frame
	var resolution = menu.content.get_node("ResolutionRow/Resolution")
	var cap_input = menu.content.get_node("FPSLimitRow/FPSLimit")
	check(resolution.size.x >= 180 and resolution.size.x <= 220, "Resolution compact width")
	check(cap_input.size.x >= 100 and cap_input.size.x <= 120, "FPS compact width")
	check(cap_input.tooltip_text == "0 = Unlimited", "Exact FPS tooltip")
	for child in menu.content.get_children():
		check(not (child is Label and child.text.begins_with("0 = Unlimited")), "No permanent FPS helper")
	for name in ["Fullscreen", "VSync"]:
		var checkbox = menu.content.get_node(name + "Row/" + name)
		check(checkbox.get_theme_icon("unchecked").resource_path.ends_with("checkbox_unchecked.svg"), "Visible unchecked icon")
		check(checkbox.get_theme_icon("checked").resource_path.ends_with("checkbox_checked.svg"), "Visible checked icon")
	if DisplayServer.get_name() != "headless":
		var sync = menu.content.get_node("VSyncRow/VSync")
		var was_enabled = sync.button_pressed
		var mouse = InputEventMouseButton.new()
		mouse.button_index = MOUSE_BUTTON_LEFT
		mouse.position = sync.get_global_rect().get_center()
		mouse.pressed = true
		Input.parse_input_event(mouse)
		await process_frame
		mouse.pressed = false
		Input.parse_input_event(mouse)
		await process_frame
		check(sync.button_pressed != was_enabled and settings.vsync == sync.button_pressed, "Mouse checkbox click applies setting")
	var x = menu.content.get_node("ResolutionRow/Resolution").global_position.x
	for name in ["Fullscreen", "VSync", "Resolution", "MSAA", "Shadows", "FPSLimit"]:
		var control = menu.content.get_node(name + "Row/" + name)
		check(is_equal_approx(control.global_position.x, x), "Aligned control column: " + name)
	check(menu.content.get_node("FullscreenRow/Fullscreen") is CheckBox, "Compact fullscreen checkbox")
	check(menu.content.get_node("VSyncRow/VSync") is CheckBox, "Compact VSync checkbox")
	for name in ["MSAA", "Shadows"]:
		var segments = menu.content.get_node(name + "Row/" + name)
		var active = 0
		for button in segments.get_children():
			active += int(button.button_pressed)
			check(absf(button.size.x - segments.get_child(0).size.x) <= 1, "Equal segment widths: " + name)
		check(active == 1, "Exactly one active segment: " + name)
	var fps = menu.content.get_node("FPSLimitRow/FPSLimit")
	fps.text = "144"
	check(settings.fps_limit == 60, "Typing does not apply cap")
	fps.text_submitted.emit(fps.text)
	check(settings.fps_limit == 144 and Engine.max_fps == 144, "Confirmation applies arbitrary integer cap")
	settings.load_settings()
	check(settings.fps_limit == 144, "Arbitrary integer cap persists")
	for invalid in ["", "oops", "1.5", "-1", "1001", "+60"]:
		fps.text = invalid
		fps.focus_exited.emit()
		check(settings.fps_limit == 144 and fps.text == "144", "Reject and revert invalid cap: " + invalid)
	for cap in [0, 1000, 237]:
		fps.text = str(cap)
		fps.focus_exited.emit()
		check(settings.fps_limit == cap, "Focus loss commits valid cap: " + str(cap))
		settings.load_settings()
		check(settings.fps_limit == cap, "Cap reloads: " + str(cap))
	var config = ConfigFile.new()
	for invalid in [-1, 1001, "144", 1.5]:
		config.set_value("video", "fps_limit", invalid)
		config.save(settings.storage_path)
		settings.load_settings()
		check(settings.fps_limit == 60, "Malformed persisted cap defaults safely")
	menu.restore_category()
	check(settings.fps_limit == 60 and settings.msaa_3d == 1 and settings.shadow_quality == 2, "Video defaults restored")
	menu.show_category("Controls")
	check(menu.content.get_parent().get_theme_constant("margin_right") == 12, "Controls scrollbar padding")
	await process_frame
	await process_frame
	var primary_x = menu.content.get_node("Bindingmove_north/Primary").global_position.x
	var secondary_x = menu.content.get_node("Bindingmove_north/Secondary").global_position.x
	for action in settings.bindings:
		var row = menu.content.get_node("Binding" + action)
		check(is_equal_approx(row.get_node("Primary").global_position.x, primary_x) and is_equal_approx(row.get_node("Secondary").global_position.x, secondary_x), "Binding columns aligned: " + action)
		for button in [row.get_node("Primary"), row.get_node("Secondary")]:
			var text_width = button.get_theme_font("font").get_string_size(button.text, HORIZONTAL_ALIGNMENT_LEFT, -1, button.get_theme_font_size("font_size")).x
			check(button.size.x >= text_width + 28, "Binding text fits: " + button.text)
	check(menu.content.get_node("MouseSensitivity").get_index() > menu.content.get_node("Bindingcamera_zoom_out").get_index(), "Sensitivity follows bindings")
	menu.queue_free()
	DirAccess.remove_absolute(settings.storage_path)
	menu.queue_free()
	await process_frame
	var flow = root.get_node("SceneFlow")
	flow.main_menu()
	await process_frame
	await process_frame
	check(root.gui_get_focus_owner() == null, "Main menu initially unfocused")
	var key = InputEventKey.new()
	key.keycode = KEY_TAB
	key.physical_keycode = KEY_TAB
	key.pressed = true
	Input.parse_input_event(key)
	await process_frame
	await process_frame
	check(root.gui_get_focus_owner() != null, "Tab enters visible keyboard focus")
	root.gui_release_focus()
	key.keycode = KEY_DOWN
	key.physical_keycode = KEY_DOWN
	Input.parse_input_event(key)
	await process_frame
	check(root.gui_get_focus_owner() != null, "Arrow enters keyboard focus")
	print("SETTINGS LAYOUT: ", checks, " checks, ", failures, " failures")
	quit(0 if failures == 0 else 1)
