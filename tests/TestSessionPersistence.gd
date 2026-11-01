extends SceneTree
var failures = 0
var checks = 0
func check(value, message):
	checks += 1
	if not value: failures += 1; push_error(message)
func _initialize(): call_deferred("run")
func run():
	var save = root.get_node("SaveManager")
	save.run_path = "user://session_regression.bin"
	save.storage_path = "user://session_regression_progression.json"
	var flow = root.get_node("SceneFlow")
	root.get_node("SettingsManager").shadow_quality = 2
	flow.next_seed = 2026
	flow.transition(flow.playable_scene)
	await process_frame
	await process_frame
	var world = current_scene
	world.set_process(false)
	world.get_node("GridPlayer").set_process(false)
	world.get_node("GridPlayer").cell = Vector2i(8,7)
	world.get_node("GridPlayer").facing = Vector2i.LEFT
	world.get_node("GridPlayer").position = world.grid.world_position(Vector2i(8,7))
	world.survival.body_temperature = 35.8
	world.survival.health = 82.0
	world.survival.berry_count = 4
	world.planting.seed_count = 8
	world.planting.water_ml = 250
	world.presentation_elapsed = 371.25
	var cell = world.grid.cells[5*17+5]
	cell.merge({"tree":true,"tree_state":"stump","pending_seeds":2,"tilled":true,"prepared":true,"moisture":0.73},true)
	var wetlands = world.regions.get_region("wetlands")
	wetlands.grid.cells[3*17+3].merge({"tree":true,"tree_state":"sapling","planted":true,"growth_age":77.0,"moisture":0.8},true)
	world.regions.get_region("drylands").grid.cells[4*17+4].log = true
	save.progression = {"knowledge":4,"discoveries":["test.persisted"],"upgrades":["quick_chop"]}
	var data = save.RunSave.capture(world,save.progression)
	var model = save.RunSave.restore(data)
	check(model != null,"Snapshot validates and reconstructs models")
	if model == null: quit(1); return
	check(is_equal_approx(model.survival.body_temperature,35.8),"Derived exposure does not overwrite cold temperature")
	check(model.states.forest.grid.cells == world.grid.cells,"Entire authoritative cell data retained")
	check(model.states.wetlands.grid.cells[3*17+3].growth_age == 77.0 and model.states.drylands.grid.cells[4*17+4].log,"Inactive regions, growth and logs retained")
	check(model.states.forest.climate._fire_rng.state == world.climate._fire_rng.state,"RNG state retained exactly")
	flow.open_pause()
	flow.main_menu()
	await process_frame
	await process_frame
	check(current_scene.scene_file_path == flow.MAIN_MENU,"Successful save precedes menu")
	check(save.has_resumable_run() and not current_scene.get_node("Panel/Rows/Continue").disabled,"Continue enabled for valid slot")
	check(flow.continue_game() == OK,"Continue starts saved session")
	await process_frame
	await process_frame
	world = current_scene
	world.set_process(false)
	world.get_node("GridPlayer").set_process(false)
	check(world.get_node("GridPlayer").cell == Vector2i(8,7) and world.get_node("GridPlayer").facing == Vector2i.LEFT,"Position and facing restored")
	check(world.planting.seed_count == 8 and world.planting.water_ml == 250 and world.survival.berry_count == 4,"Inventory restored")
	check(save.progression.knowledge == 4 and save.has_upgrade("quick_chop"),"Knowledge/perks restored without discovery replay")
	check(absf(world.presentation_elapsed-371.25) < 0.2,"Lighting clock restored")
	var hud = world.hud
	hud.notification_queue.clear(); hud.notification_active.clear()
	for i in range(6): hud.notify("Discovery: example "+str(i),"important")
	for i in range(3): hud._process(0.7)
	check(hud.notification_active.size() == 3 and hud.notification_queue.size() == 3,"Feed bounded display retains queued burst")
	hud.notify("Weather: rain"); hud.notify("Weather: rain")
	check(hud.notification_queue.size() == 4,"Repeated queued message coalesces")
	var age = hud.notification_active[0].age
	paused = true; hud._process(2); paused = false
	check(hud.notification_active[0].age == age,"Feed pauses")
	for size_value in [Vector2i(960,600),Vector2i(1152,720),Vector2i(1600,900)]:
		root.content_scale_size = size_value
		root.size = size_value
		await process_frame
		await process_frame
		hud._process(0)
		check(hud.notification_labels[2].position.y+48 < size_value.y-62,"Feed above contextual caption")
	hud._process(0.35)
	if DisplayServer.get_name() != "headless" and OS.has_environment("NIHILISTS_CAPTURE_DIR"):
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OS.get_environment("NIHILISTS_CAPTURE_DIR").path_join("notification-feed.png"))
	hud.notification_queue.clear(); hud.notification_active.clear()
	for label in hud.notification_labels: label.hide()
	var directions = []
	for phase in [0.02,0.25,0.48,0.75]:
		world.presentation_elapsed = (phase-world.starting_day_phase+1.0)*world.day_night_duration
		world._update_lighting()
		directions.append(world.get_node("Sun").global_basis.z)
		var disc = world.get_node("SunDisc" if phase < 0.5 else "MoonDisc")
		check(disc.visible and disc.position.normalized().dot(world.get_node("Sun").global_basis.z) > 0.999,"Visible body and light direction agree")
		if DisplayServer.get_name() != "headless" and OS.has_environment("NIHILISTS_CAPTURE_DIR"):
			await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(OS.get_environment("NIHILISTS_CAPTURE_DIR").path_join("sky-"+str(phase)+".png"))
	check(directions[0].distance_to(directions[2]) > 1.0,"Sun direction moves from morning to sunset")
	var corrupted = data.duplicate(true)
	corrupted.states.forest.cells[0].tree = "invalid"
	check(save.RunSave.restore(corrupted) == null,"Wrong cell field types rejected")
	corrupted = data.duplicate(true)
	corrupted.planting.seed_count = 99
	check(save.RunSave.restore(corrupted) == null,"Out-of-range inventory rejected")
	var original_read = save.run_path
	save.run_path = "user://missing-folder/session-test.bin"
	check(save.save_run(world) != OK,"Write failure reported without replacing prior slot")
	save.run_path = original_read
	check(save.has_resumable_run(),"Prior valid slot survives write failure")
	var truncated = FileAccess.open(save.run_path+".tmp",FileAccess.WRITE)
	truncated.store_buffer(PackedByteArray([1,2,3])); truncated.close()
	check(save.has_resumable_run(),"Interrupted temporary write does not hide valid slot")
	var bad = FileAccess.open(save.run_path,FileAccess.WRITE);bad.store_var({"version":999},false);bad.close()
	check(not save.has_resumable_run(),"Invalid schema disables Continue")
	# Fresh session leaves the old slot intact until a new session is initialized
	# and explicitly saved on the next menu return.
	check(save.save_run(world) == OK,"Can stage a valid previous playthrough")
	var old_seed = save.read_run().seed
	check(flow.new_game() == OK,"New Game initializes clean session")
	await process_frame
	await process_frame
	world = current_scene
	world.set_process(false)
	check(world.planting.seed_count == 3 and world.survival.health == 100.0 and save.progression.knowledge == 0 and save.progression.upgrades.is_empty(),"New Game resets run and permanent progression")
	check(save.read_run().seed == old_seed,"Old slot preserved until new session is saved")
	var new_seed = world.regions.seed_for("forest")
	flow.main_menu()
	await process_frame
	await process_frame
	check(save.read_run().seed == new_seed,"New session atomically replaces slot on menu return")
	for path in [save.run_path,save.run_path+".tmp",save.storage_path,save.storage_path+".tmp"]:
		if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
	print("SESSION/FEED/SKY: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
