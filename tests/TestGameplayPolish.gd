extends SceneTree
const Survival = preload("res://features/player/survival_state.gd")
var checks = 0
var failures = 0
func check(value: bool, message: String):
	checks += 1
	if not value:
		failures += 1
		push_error(message)
func _initialize(): call_deferred("run")
func run():
	var exposed = Survival.new()
	var strong = Survival.new()
	var weak = Survival.new()
	var canopy = Survival.new()
	for state in [exposed,strong,weak,canopy]: state.body_temperature = 34.0
	exposed.tick(20.0,18.0,0.0,false,false,{"weather":"rain"})
	strong.tick(20.0,18.0,0.0,true,false,{"weather":"rain","camp_intensity":1.0})
	weak.tick(20.0,18.0,0.0,true,false,{"weather":"rain","camp_intensity":0.25})
	canopy.tick(20.0,18.0,0.9,true,false,{"weather":"rain","canopy":0.9,"camp_intensity":1.0})
	check(strong.wetness > 0.0 and strong.wetness < exposed.wetness, "Exposed camp reduces rain wetting without immunity")
	check(weak.wetness > strong.wetness and weak.body_temperature < strong.body_temperature, "Fire intensity scales drying and warmth")
	check(canopy.wetness < strong.wetness, "Canopy continues intercepting rain near camp")
	var dry = Survival.new()
	dry.wetness = 40.0
	dry.tick(10.0,18.0,0.0,true,false)
	check(is_equal_approx(dry.wetness,15.0), "Dry-weather strong camp preserves original drying")
	var save = root.get_node("SaveManager")
	save.storage_path = "user://gameplay_polish_test.json"
	var original_progression = save.progression
	save.progression = original_progression.duplicate(true)
	var flow = root.get_node("SceneFlow")
	flow.run_regions = null
	flow.next_seed = 2026
	change_scene_to_file("res://features/levels/forest/forest_level.tscn")
	await process_frame
	await process_frame
	var world = current_scene
	world.set_process(false)
	world.get_node("GridPlayer").set_process(false)
	world.climate.weather_override = "rain"
	world.climate.tick(1.0)
	world._tick_bonfire(25.0)
	check(is_equal_approx(world.region_state.bonfire_intensity,0.5) and world.get_node("Bonfire/Flame1").scale.y < 1.0, "Sustained rain visibly weakens exposed fire")
	world._tick_bonfire(30.0)
	check(world.region_state.bonfire_intensity == 0.0 and not world.get_node("Bonfire/Flame1").visible and world.get_node("Bonfire/Warmth").light_energy == 0.0, "Long rain extinguishes flames and light")
	world._begin_context_action()
	world._tick_context_action(0.1)
	check(world.hud.modal_kind == "bonfire" and paused and world.hud.get_node("Modal/Rows/Upgrade").visible, "Extinguished camp retains Rest and permanent upgrade access")
	world.hud.close_modal()
	world.climate.weather_override = "clear"
	world.climate.tick(1.0)
	world._tick_bonfire(25.0)
	check(world.region_state.bonfire_intensity == 1.0 and world.get_node("Bonfire/Flame1").visible, "Dry weather automatically restores original fire")
	var target = Vector2i(7,5)
	var data: Dictionary = world.grid.cells[target.y*world.grid.SIZE+target.x]
	data.tree = false
	data.log = false
	data.berry_bush = false
	data.burning = false
	data.burned = false
	data.terrain = "soil"
	data.prepared = true
	world.decorated_cells.erase(target)
	var player = world.get_node("GridPlayer")
	player.cell = Vector2i(8,5)
	player.position = world.grid.world_position(player.cell)
	player.facing = Vector2i.RIGHT
	world._update_interaction_marker()
	# A custom candidate list is unnecessary: the existing selector owns its tie-breaks.
	player.facing = Vector2i.LEFT
	world._update_interaction_marker()
	check(world.selected_interaction.cell == target and world.interaction_marker.mesh is TorusMesh and world.interaction_marker.visible, "Selected planting soil uses the shared readable interaction ring")
	if DisplayServer.get_name() != "headless" and OS.has_environment("NIHILISTS_CAPTURE_DIR"):
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OS.get_environment("NIHILISTS_CAPTURE_DIR").path_join("planting-ring.png"))
	world.terrain_renderer.update_state(world.grid)
	check(world.terrain_renderer.batches[18].multimesh.visible_instance_count > 0 and world.terrain_renderer.batches[18].material_override.get_shader_parameter("terrain_color") == Color("554636"), "Generated soil has a shared brown terrain material independent of highlighting")
	check(world.hud.get_node("Context").get_theme_stylebox("normal") is StyleBoxFlat, "Interaction caption has a dark padded background")
	for batch in world.ground_cover.batches:
		for index in batch.indices:
			check(world.grid.cells[index].terrain != "soil", "Grass/shrub decoration leaves soil patches bare")
	data.burning = true
	world._update_interaction_marker()
	check(not world.interaction_marker.visible or not world.interaction_marker.position.is_equal_approx(world.grid.world_position(target) + Vector3(0,0.12,0)), "Invalid planting clears its ring immediately")
	data.burning = false
	world._begin_context_action()
	world._tick_context_action(1.1)
	world._update_interaction_marker()
	check(world.interaction_marker.mesh is TorusMesh, "Plant completion retains sapling removal ring")
	world.survival.hunger = 64.0
	world.survival.thirst = 72.0
	world.survival.wetness = 25.0
	world._update_hud()
	for size_value in [Vector2i(800,600),Vector2i(1152,720),Vector2i(1600,900)]:
		root.content_scale_size = size_value
		root.size = size_value
		if DisplayServer.get_name() != "headless": DisplayServer.window_set_size(size_value)
		await process_frame
		await process_frame
		var panel = world.hud.get_node("PlayerStatus")
		var supplies = world.hud.get_node("PlayerStatus/Rows/Supplies")
		var caption = world.hud.get_node("Context")
		check(caption.visible and caption.get_global_rect().position.y >= 0.0 and caption.get_global_rect().end.y <= size_value.y and caption.size.y < 64.0, "Padded interaction caption stays readable inside viewport at " + str(size_value))
		check(panel.get_global_rect().end.x < size_value.x and panel.size.y < 200.0 and supplies.get_global_rect().end.x <= panel.get_global_rect().end.x, "Compact resources fit HUD at " + str(size_value))
		check(supplies.get_node("Food").text == "64" and supplies.get_node("Water").text == "72" and supplies.get_node("Seeds").text == str(world.planting.seed_count), "Numeric resource values update")
		if DisplayServer.get_name() != "headless" and OS.has_environment("NIHILISTS_CAPTURE_DIR"):
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(OS.get_environment("NIHILISTS_CAPTURE_DIR").path_join("polish-%dx%d.png" % [size_value.x,size_value.y]))
	world.region_state.bonfire_intensity = 0.25
	flow.change_region("wetlands")
	await process_frame
	await process_frame
	flow.change_region("forest")
	await process_frame
	await process_frame
	check(current_scene.region_state.bonfire_intensity == 0.25 and current_scene.get_node("Bonfire/Flame1").scale.y < 1.0, "Region return preserves weak bonfire visual/state")
	current_scene.queue_free()
	await process_frame
	save.progression = original_progression
	for path in [save.storage_path,save.storage_path+".tmp"]:
		if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
	print("GAMEPLAY POLISH: ",checks," checks, ",failures," failures")
	quit(failures)
