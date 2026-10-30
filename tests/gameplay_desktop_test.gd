extends SceneTree
func _initialize():
	call_deferred("run")
func capture(name):
	await create_timer(0.4).timeout
	await RenderingServer.frame_post_draw
	if OS.has_environment("NIHILISTS_CAPTURE_DIR"):
		root.get_texture().get_image().save_png(OS.get_environment("NIHILISTS_CAPTURE_DIR").path_join(name + ".png"))
func run():
	var saves = root.get_node("SaveManager")
	saves.storage_path = "user://gameplay_desktop_test.json"
	saves.load_progression()
	var flow = root.get_node("SceneFlow")
	flow.next_seed = 2026
	flow.transition(flow.playable_scene)
	await process_frame
	await process_frame
	var world = current_scene
	await create_timer(3.0).timeout
	print("WORLD DESKTOP fps=", Performance.get_monitor(Performance.TIME_FPS), " draw_calls=", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), " nodes=", get_node_count())
	await capture("living_forest_initial")
	world.set_process(false)
	var started = Time.get_ticks_usec()
	for index in range(360):
		world.climate.tick(1.0)
	world._refresh_visuals()
	world._update_hud()
	print("SIMULATION: 360 one-second ticks ms=", (Time.get_ticks_usec() - started) / 1000.0)
	await capture("living_forest_warmed")
	world.hud.show_modal("bonfire")
	await capture("bonfire_progression")
	world.hud.close_modal()
	flow.open_pause()
	flow.pause_menu.open_options()
	await process_frame
	flow.pause_menu.options.show_category("Gameplay")
	await capture("gameplay_projection_options")
	flow.resume()
	world._end_run("death")
	await capture("forest_death")
	world.hud.close_modal()
	flow.main_menu()
	await process_frame
	await process_frame
	await capture("forest_theme_menu")
	if FileAccess.file_exists(saves.storage_path):
		DirAccess.remove_absolute(saves.storage_path)
	print("GAMEPLAY DESKTOP: rendered world, climate transition, bonfire, options, death and main menu")
	quit()
