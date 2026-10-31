extends SceneTree
var failures = 0
func check(value, message):
	if not value:
		failures += 1
		push_error(message)
func _initialize():
	call_deferred("run")
func capture(name):
	await create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	var image = root.get_texture().get_image()
	if OS.has_environment("NIHILISTS_CAPTURE_DIR"):
		image.save_png(OS.get_environment("NIHILISTS_CAPTURE_DIR").path_join(name + ".png"))
	return image
func run():
	var saves = root.get_node("SaveManager")
	saves.storage_path = "user://polish_desktop_test.json"
	saves.load_progression()
	var flow = root.get_node("SceneFlow")
	flow.next_seed = 2026
	flow.transition(flow.playable_scene)
	await process_frame
	await process_frame
	var world = current_scene
	world.set_process(false)
	var snapshot = world.grid.cells.duplicate(true)
	var props = get_nodes_in_group("forest_props")
	check(props.size() > 0 and props.size() < 25, "Small decorative prop set")
	for prop in props:
		check(prop is Node3D and prop.get_child_count() > 0, "Imported GLB instantiates")
	check(world.grid.cells == snapshot, "Props leave simulation data unchanged")
	var settings = root.get_node("SettingsManager")
	settings.shadow_quality = 3
	settings.apply_settings()
	world.presentation_elapsed = 0
	world._update_lighting()
	var direction = world.get_node("Sun").rotation
	await capture("polish_day_shadows_high")
	world.presentation_elapsed = world.day_night_duration * 0.25
	world._update_lighting()
	check(world.get_node("Sun").rotation != direction, "Sun direction moves")
	await capture("polish_late_day_shadows_high")
	world.presentation_elapsed = world.day_night_duration * 0.55
	world._update_lighting()
	check(world.get_node("Environment").environment.ambient_light_energy >= world.night_ambient_energy, "Night readable")
	await capture("polish_night_shadows_high")
	settings.shadow_quality = 0
	settings.apply_settings()
	check(not world.get_node("Sun").shadow_enabled, "Shadows Off")
	await capture("polish_night_shadows_off")
	world.get_node("CameraRig").target_zoom = 10.0
	await create_timer(0.6).timeout
	world._advance_presentation(0.1)
	var fire_before = await capture("polish_fire_a")
	world._advance_presentation(0.4)
	var fire_after = await capture("polish_fire_b")
	check(fire_before.get_data() != fire_after.get_data(), "Flame geometry visibly animates")
	flow.main_menu()
	await process_frame
	await process_frame
	if FileAccess.file_exists(saves.storage_path):
		DirAccess.remove_absolute(saves.storage_path)
	print("POLISH DESKTOP: ", failures, " failures; props=", props.size())
	quit(0 if failures == 0 else 1)
