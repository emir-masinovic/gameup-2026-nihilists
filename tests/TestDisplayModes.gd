extends SceneTree
var failures = 0
func _initialize(): call_deferred("run")
func check(ok: bool, label: String):
	print("DISPLAY ", label, " PASS=", ok, " root=", root.size, " native=", DisplayServer.window_get_size(), " mode=", root.mode)
	if not ok: failures += 1
func run():
	# Never permit this persistence probe to write into the real game's user data.
	if not ProjectSettings.globalize_path("user://").contains("NihilistsDisplayValidation"):
		push_error("Requires isolated NihilistsDisplayValidation user directory")
		quit(2)
		return
	var settings = root.get_node("SettingsManager")
	await create_timer(0.2).timeout
	if "--display-restart" in OS.get_cmdline_user_args():
		check(settings.resolution == Vector2i(1600,900) and not settings.fullscreen, "restart preferences")
		check(root.size == Vector2i(1600,900) and DisplayServer.window_get_size() == root.size and settings.display_applied, "restart native dimensions")
		quit(failures)
		return
	var options = load("res://features/menus/options_menu.tscn").instantiate()
	root.add_child(options)
	options.show_category("Video")
	if Engine.is_embedded_in_editor():
		var original = settings.fullscreen
		settings.fullscreen = true
		settings.apply_settings()
		options.show_category("Video")
		await process_frame
		check(not settings.display_applied and not settings.actual_fullscreen() and not settings.window_controls_supported(), "embedded rejection")
		check(options.content.get_node("FullscreenRow/Fullscreen").disabled and not options.content.get_node("FullscreenRow/Fullscreen").button_pressed and options.content.get_node("ResolutionRow/Resolution").disabled, "embedded honest UI")
		check(settings.fullscreen and not settings.display_message.is_empty(), "embedded preference retained with explanation")
		settings.fullscreen = original
	else:
		settings.fullscreen = false
		settings.apply_settings()
		options.show_category("Video")
		await process_frame
		for size in [Vector2i(1280,720),Vector2i(1600,900)]:
			var choice = options.content.get_node("ResolutionRow/Resolution")
			for i in range(choice.item_count):
				if choice.get_item_text(i) == "%d × %d" % [size.x,size.y]:
					choice.select(i)
					choice.item_selected.emit(i)
			await create_timer(0.2).timeout
			check(settings.resolution == size and root.size == size and DisplayServer.window_get_size() == size and settings.display_applied, "resolution callback " + str(size))
		settings.fullscreen = true
		settings.apply_settings()
		await create_timer(0.2).timeout
		check(settings.actual_fullscreen() and settings.display_applied, "fullscreen confirmed")
		settings.fullscreen = false
		settings.apply_settings()
		await create_timer(0.2).timeout
		check(root.mode == Window.MODE_WINDOWED and root.size == Vector2i(1600,900) and DisplayServer.window_get_size() == root.size and settings.display_applied, "fullscreen return resolution")
		check(settings.save_settings() == OK, "isolated save")
	quit(failures)
