extends SceneTree
const Regions = preload("res://features/levels/forest/RunRegions.gd")
var checks = 0
var failures = 0
func check(value: bool, message: String):
	checks += 1
	if not value:
		failures += 1
		push_error(message)
func _initialize(): call_deferred("run")
func soil(grid: RefCounted, cell: Vector2i) -> Dictionary:
	var data: Dictionary = grid.cells[cell.y*grid.SIZE+cell.x]
	data.terrain = "soil"
	data.tree = false
	data.tree_state = "removed"
	data.tree_health = 0.0
	data.log = false
	data.berry_bush = false
	data.burned = false
	data.burning = false
	data.prepared = false
	return data
func run():
	var run = Regions.new()
	run.configure(2026)
	var state = run.enter("forest")
	var grid = state.grid
	var farm = run.planting
	var cell = Vector2i(5,5)
	var data = soil(grid,cell)
	check(not farm.plant(grid,cell), "Bare soil requires preparation")
	for key in ["tree","log","berry_bush","burning","burned"]:
		data[key] = true
		check(not farm.prepare(grid,cell), "Preparation preserves exclusion: "+key)
		data[key] = false
	check(not farm.prepare(grid,cell,true) and not farm.prepare(grid,grid.start), "Props, players and protected camp remain excluded")
	data.terrain = "water"
	check(not farm.prepare(grid,cell), "Cannot till ponds")
	data.terrain = "soil"
	check(farm.prepare(grid,cell) and not farm.prepare(grid,cell), "Prepare Soil changes authoritative state once")
	check(farm.plant(grid,cell) and farm.seed_count == 2, "Prepared soil consumes one seed")
	data.moisture = 0.0
	check(farm.water_plant(grid,cell) and farm.water_ml == 250 and data.moisture == 0.5, "Watering spends 250 ml and raises real soil moisture")
	check(data.growth_age == 0.0, "Watering never grants instant growth")
	var climate = state.climate
	climate.warming_limit = 0.0
	climate.baseline_temperature = 22.0
	climate.weather_override = "heat"
	climate.ignition_chance = 0.0
	for i in range(20): climate.tick(1.0)
	check(data.growth_age > 0.0, "Manual watering permits growth during a warm dry period")
	var rain_cell = Vector2i(4,5)
	var rain_data = soil(grid,rain_cell)
	farm.prepare(grid,rain_cell)
	farm.plant(grid,rain_cell)
	rain_data.moisture = 0.0
	climate.weather_override = "rain"
	var water_before: int = farm.water_ml
	for i in range(50): climate.tick(1.0)
	check(rain_data.growth_age > 0.0 and farm.water_ml == water_before, "Rain naturally waters plants and enables growth without bottle use")
	rain_data.tree_state = "dead"
	check(not farm.water_plant(grid,rain_cell), "Watering cannot resurrect dead vegetation")
	# Supported edge cases retained from Onur's historical bottle tests.
	var edge_cell = Vector2i(6,5)
	var edge_data = soil(grid,edge_cell)
	edge_data.moisture = 0.0
	var bottle_before: int = farm.water_ml
	check(not farm.water_plant(grid,edge_cell) and farm.water_ml == bottle_before, "Empty untilled soil cannot consume watering inventory")
	farm.prepare(grid,edge_cell)
	check(not farm.water_plant(grid,edge_cell) and farm.water_ml == bottle_before, "Empty prepared soil cannot be watered")
	farm.plant(grid,edge_cell)
	farm.water_ml = 249
	check(not farm.water_plant(grid,edge_cell) and farm.water_ml == 249 and edge_data.moisture == 0.0, "Insufficient partial bottle rejects pour without changing soil or inventory")
	farm.water_ml = 1000
	for pour in range(4):
		edge_data.moisture = 0.0 # A thirsty target at each simulated visit.
		check(farm.water_plant(grid,edge_cell) and farm.water_ml == 1000-(pour+1)*250, "Each successful pour spends exactly 250 ml")
	edge_data.moisture = 0.0
	check(not farm.water_plant(grid,edge_cell) and farm.water_ml == 0 and edge_data.moisture == 0.0, "Empty bottle cannot pour or become negative")
	farm.water_ml = bottle_before
	var pond = Vector2i(2,2)
	var pond_data = soil(grid,pond)
	pond_data.terrain = "water"
	pond_data.water_level = 0.0
	check(farm.fill_bottle(grid,pond) == 0, "Dry ponds cannot fill bottle")
	pond_data.water_level = 1.0
	check(farm.fill_bottle(grid,pond) == 500 and farm.fill_bottle(grid,pond) == 250 and farm.water_ml == 1000, "Pond fill is bounded at 1000 ml")
	check(farm.fill_bottle(grid,pond) == 0 and farm.water_ml == 1000 and pond_data.water_level == 1.0, "Full bottle refill is a no-op and never drains the pond")
	pond_data.water_level = 0.1
	check(grid.traversable(pond), "Current shallow-water threshold permits dry pond traversal")
	climate.weather_override = "rain"
	climate.tick(1.0)
	check(pond_data.water_level > 0.1 and not grid.traversable(pond), "Rain refills a shallow pond and restores its traversal barrier")
	var tree = Vector2i(3,5)
	soil(grid,tree)
	var event = {"kind":"tree_cut","cell":tree,"seed_eligible":true}
	var seeds_before: int = farm.seed_count
	check(farm.record_seed_drop(grid,event) == 1 and farm.seed_count == seeds_before, "Chopping creates pending drop instead of auto-awarding inventory")
	farm.seed_count = 9
	check(farm.collect_seed(grid,{"kind":"collect_seeds","cell":tree}) == 0 and grid.cells[tree.y*grid.SIZE+tree.x].pending_seeds == 1, "Full pouch retains collectible drop")
	farm.seed_count = 8
	check(farm.collect_seed(grid,{"kind":"collect_seeds","cell":tree}) == 1 and farm.seed_count == 9, "Collection respects nine-seed cap")
	check(farm.record_seed_drop(grid,event) == 0 and farm.collect_seed(grid,{"kind":"collect_seeds","cell":tree}) == 0, "Repeated cut/collection cannot duplicate seeds")
	check(farm.record_seed_drop(grid,{"kind":"tree_cut","cell":cell,"seed_eligible":true}) == 0, "Planted trees never produce renewable seeds")
	check(farm.record_seed_drop(grid,{"kind":"tree_cut","cell":pond,"seed_eligible":false}) == 0, "Dead or ineligible cut produces no seed")
	run.enter("wetlands")
	run.enter("forest")
	check(data.prepared and data.planted and run.planting.water_ml == 1000, "Region return retains preparation, planted state and shared water")
	run.configure(2026)
	check(run.planting.water_ml == 500 and run.planting.seed_count == 3, "New run resets only temporary inventories")
	await scene_checks()
	print("FARMING INTEGRATION: ",checks," checks, ",failures," failures")
	quit(failures)
func scene_checks():
	var save = root.get_node("SaveManager")
	save.storage_path = "user://farming_integration_test.json"
	var old_progression = save.progression
	save.progression = old_progression.duplicate(true)
	var flow = root.get_node("SceneFlow")
	flow.next_seed = 2026
	flow.run_regions = null
	change_scene_to_file("res://features/levels/forest/forest_level.tscn")
	await process_frame
	await process_frame
	var world = current_scene
	world.set_process(false)
	var player = world.get_node("GridPlayer")
	player.set_process(false)
	var target = Vector2i(7,5)
	var data = soil(world.grid,target)
	if world.trees.has(target):
		world.trees[target].queue_free()
		world.trees.erase(target)
	world.decorated_cells.erase(target)
	player.cell = Vector2i(8,5)
	player.position = world.grid.world_position(player.cell)
	player.facing = Vector2i.LEFT
	world._begin_context_action()
	check(world.context_action.active.get("object_kind") == "prepare" and player.get_node("Body/ArmRight/Hoe").visible, "Contextual Prepare Soil starts hoe animation")
	paused = true
	world._tick_context_action(1.0)
	check(not data.prepared, "Paused action cannot prepare soil")
	paused = false
	world._tick_context_action(1.0)
	check(data.prepared and not player.get_node("Body/ArmRight/Hoe").visible, "Preparation completes and puts away hoe")
	world._begin_context_action()
	world._tick_context_action(1.1)
	check(data.tree_state == "sapling" and world.planting.seed_count == 2, "Next contextual action plants prepared soil")
	data.moisture = 0.0
	world._begin_context_action()
	check(world.context_action.active.get("object_kind") == "water_plant" and player.get_node("Body/ArmRight/Bottle").visible, "Thirsty sapling selects watering and bottle animation")
	world._tick_context_action(1.0)
	check(data.moisture == 0.5 and world.planting.water_ml == 250, "Scene watering updates shared bottle and climate moisture")
	var pond_cell = Vector2i(7,4)
	var pond = soil(world.grid,pond_cell)
	pond.terrain = "water"
	pond.water_level = 1.0
	player.cell = Vector2i(8,4)
	player.position = world.grid.world_position(player.cell)
	player.facing = Vector2i.LEFT
	world.survival.thirst = 55.0
	world._begin_context_action()
	check(world.context_action.active.get("object_kind") == "water" and player.get_node("Body/ArmRight/Bottle").visible, "Valid pond contextual action animates filling without a new input")
	world._tick_context_action(1.0)
	check(world.planting.water_ml == 750 and world.survival.thirst == 100.0 and pond.water_level == 1.0, "One pond action fills bottle and preserves survival drinking without draining pond")
	player.cell = Vector2i(8,5)
	player.position = world.grid.world_position(player.cell)
	var native_cell = Vector2i(9,5)
	var native = soil(world.grid,native_cell)
	soil(world.grid,Vector2i(10,5))
	native.tree = true
	native.tree_state = "healthy"
	native.tree_health = 1.0
	player.facing = Vector2i.RIGHT
	world._begin_context_action()
	world._tick_context_action(1.3)
	check(native.tree_state == "stump" and not world.grid.traversable(native_cell) and native.pending_seeds == 1 and world.planting.seed_count == 2, "Actual chop preserves blocked stump and creates drop without auto-award")
	check(world.hud.get_node("PlayerStatus/Rows/Supplies/Seeds").text == "2", "HUD does not award seeds at chop completion")
	check(world.grid.cells[5*world.grid.SIZE+10].log, "Tree still falls away and creates blocked log")
	world.planting.seed_count = 9
	var full_target: Dictionary = world.context_action.select(world._interaction_candidates(),player.cell,player.facing)
	check(full_target.get("object_kind") == "tree" and full_target.get("action") == "Remove", "Full seed pouch never blocks stump clearing; drop can remain on ground")
	world.planting.seed_count = 2
	world._begin_context_action()
	check(world.context_action.active.get("object_kind") == "seeds", "Adjacent stump offers Collect Seeds without walking onto it")
	world._tick_context_action(1.0)
	check(world.planting.seed_count == 3 and native.tree_state == "stump" and not world.seed_visuals.has(native_cell), "Collecting removes drop only and preserves stump")
	check(world.hud.get_node("PlayerStatus/Rows/Supplies/Seeds").text == "3", "HUD updates only after explicit seed collection")
	world._begin_context_action()
	world._tick_context_action(1.3)
	check(not native.tree and world.grid.traversable(native_cell), "Next interaction removes stump normally")
	world.region_state.grid.cells[6*world.grid.SIZE+7].pending_seeds = 1
	var water_before: int = world.planting.water_ml
	flow.change_region("wetlands")
	await process_frame
	await process_frame
	flow.change_region("forest")
	await process_frame
	await process_frame
	world = current_scene
	world.set_process(false)
	check(world.planting.water_ml == water_before and world.grid.cells[target.y*world.grid.SIZE+target.x].prepared and world.seed_visuals.has(Vector2i(7,6)), "Scene round trip rebuilds seed drops and retains farming data")
	if DisplayServer.get_name() != "headless" and OS.has_environment("NIHILISTS_CAPTURE_DIR"):
		await create_timer(0.2).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OS.get_environment("NIHILISTS_CAPTURE_DIR").path_join("farming-smoke.png"))
	current_scene.queue_free()
	await process_frame
	save.progression = old_progression
	for path in [save.storage_path,save.storage_path+".tmp"]:
		if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
