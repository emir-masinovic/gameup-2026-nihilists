extends SceneTree
# Captures genuine consecutive simulation states; no fabricated cell moisture/health.
var failures = 0
func _initialize():
	call_deferred("run")
func capture(world, label):
	world._refresh_visuals()
	world._update_hud()
	# MultiMesh visibility/AABB changes need a complete render submission before capture.
	await process_frame
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	if OS.has_environment("NIHILISTS_CAPTURE_DIR"):
		root.get_texture().get_image().save_png(OS.get_environment("NIHILISTS_CAPTURE_DIR").path_join(label + ".png"))
func run():
	var saves = root.get_node("SaveManager")
	saves.storage_path = "user://climate_stages_test.json"
	saves.load_progression()
	root.get_node("SceneFlow").next_seed = 2026
	var world = load("res://features/levels/forest/forest_level.tscn").instantiate()
	root.add_child(world)
	world.set_process(false)
	await capture(world, "climate_healthy")
	var shadows_enabled = world.get_node("Sun").shadow_enabled
	world.get_node("Sun").shadow_enabled = false
	await capture(world, "climate_healthy_shadows_off")
	world.get_node("Sun").shadow_enabled = shadows_enabled
	world.climate.weather_override = "heat"
	world.climate.baseline_temperature = 42.0
	world.climate.ignition_chance = 0.0
	for i in range(100):
		world.climate.tick(30.0)
	await capture(world, "climate_drought")
	world.climate.ignition_chance = 1.0
	world.climate.ignition_delay = 0.0
	world.climate.ignition_interval = 1.0
	world.climate.spread_chance = 0.35
	for i in range(8):
		world.climate.tick(30.0)
	await capture(world, "climate_charred")
	if world.terrain_renderer.batches[17].multimesh.visible_instance_count < 200:
		failures += 1
		push_error("Actual fire did not leave a visible charred landscape")
	world.climate.weather_override = "rain"
	world.climate.baseline_temperature = 20.0
	world.climate.warming_limit = 0.0
	for i in range(50):
		world.climate.tick(30.0)
	await capture(world, "climate_recovered")
	world.free()
	if FileAccess.file_exists(saves.storage_path):
		DirAccess.remove_absolute(saves.storage_path)
	print("CLIMATE STAGES DESKTOP: captured four actual consecutive states")
	quit(failures)
