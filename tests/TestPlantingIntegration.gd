extends SceneTree
const Regions = preload("res://features/levels/forest/RunRegions.gd")
const Planting = preload("res://features/levels/forest/StatePlanting.gd")
const SAVE = "user://planting_integration_test.json"
var checks = 0
var failures = 0
func check(value: bool, message: String):
	checks += 1
	if not value:
		failures += 1
		push_error(message)
func _initialize():
	call_deferred("run")
func soil(grid: RefCounted, cell: Vector2i) -> Dictionary:
	var data: Dictionary = grid.cells[cell.y * grid.SIZE + cell.x]
	data.tree = false
	data.tree_state = "removed"
	data.tree_health = 0.0
	data.log = false
	data.berry_bush = false
	data.prepared = true
	data.terrain = "soil"
	data.burned = false
	data.burning = false
	data.moisture = 0.8
	return data
func run():
	var models = Regions.new()
	models.configure(2026)
	var state = models.enter("forest")
	var grid = state.grid
	var climate = state.climate
	var planting = models.planting
	var cell = Vector2i(5,5)
	var data = soil(grid,cell)
	check(planting.seed_count == 3, "Run starts with limited seeds")
	for key in ["tree","log","berry_bush","burning","burned"]:
		data[key] = true
		check(not planting.plant(grid,cell), "Reject occupied/unsafe cell: " + key)
		data[key] = false
	data.terrain = "water"
	data.water_level = 0.0
	check(not planting.plant(grid,cell), "Even dried ponds cannot be planted")
	data.terrain = "grass"
	check(not planting.plant(grid,cell), "Require bare soil")
	data.prepared = true
	data.terrain = "soil"
	check(not planting.plant(grid,cell,true), "Reject player, decoration or registered occupancy")
	for reserved in [grid.start,grid.objective,Vector2i(0,8),Vector2i(1,8),Vector2i(15,8),Vector2i(16,8)]:
		soil(grid,reserved)
		check(not planting.plant(grid,reserved), "Keep camp and regional trails open")
	check(planting.seed_count == 3, "Rejected planting never consumes seeds")
	check(planting.plant(grid,cell), "Plant seed on empty soil")
	check(planting.seed_count == 2 and data.tree_state == "sapling" and data.tree_health == 0.35, "Plant consumes exactly one seed and creates Onur sprout state")
	check(not planting.plant(grid,cell), "Cannot double plant")
	climate.weather_override = "rain"
	climate.warming_limit = 0.0
	climate.ignition_chance = 0.0
	for second in range(239): climate.tick(1.0)
	check(data.tree_state == "sapling" and data.growth_age == 239.0, "Maturity takes four favorable minutes")
	var sprout = preload("res://features/levels/forest/VisualSapling.tscn").instantiate()
	root.add_child(sprout)
	var sizes = []
	for age in [0.0,60.0,120.0]:
		data.growth_age = age
		sprout.update_growth(data)
		sizes.append(sprout.scale.y)
	check(sizes[0] < sizes[1] and sizes[1] < sizes[2], "Three distinct visible growing stages")
	data.growth_age = 239.0
	climate.tick(1.0)
	check(data.tree_state == "healthy" and data.fuel == 1.0, "Mature planted tree joins existing vegetation/fuel states")
	check(climate.shade_at(cell+Vector2i.UP) > 0.0, "Grown tree provides neighboring shade")
	var event = {"cell":cell,"kind":"tree_cut","seed_eligible":true}
	check(planting.record_seed_drop(grid,event) == 0, "Planted trees cannot create seed profit")
	var other = Vector2i(4,5)
	var dry = soil(grid,other)
	check(planting.plant(grid,other), "Second seed plants")
	dry.moisture = 0.0
	climate.weather_override = "heat"
	for second in range(60): climate.tick(1.0)
	check(dry.growth_age == 0.0 and dry.tree_health < 0.35, "Drought stops growth and damages seedling")
	for second in range(60): climate.tick(1.0)
	check(dry.tree_state == "dead", "Prolonged drought kills young vegetation")
	dry.moisture = 0.9
	climate.weather_override = "rain"
	climate.tick(1.0)
	check(dry.tree_state == "dead", "Dead saplings do not resurrect")
	models.enter("wetlands")
	models.advance(10.0)
	var returned = models.enter("forest")
	check(returned.grid == grid and returned.grid.cells[cell.y*grid.SIZE+cell.x].planted, "Regional round trip retains planted mature tree")
	check(models.planting.seed_count == 1 and dry.tree_state == "dead", "Seed inventory and failed plants persist within run")
	var original = Vector2i(3,5)
	soil(grid,original)
	var original_event = {"cell":original,"kind":"tree_cut","seed_eligible":true}
	check(planting.record_seed_drop(grid,original_event) == 1 and planting.collect_seed(grid,{"kind":"collect_seeds","cell":original}) == 1, "Original healthy tree drops one collectible seed")
	check(planting.record_seed_drop(grid,original_event) == 0, "Repeated tree event cannot farm inventory")
	planting.seed_count = 9
	check(planting.record_seed_drop(grid,{"cell":Vector2i(3,6),"kind":"tree_cut","seed_eligible":true}) == 1 and planting.collect_seed(grid,{"cell":Vector2i(3,6),"kind":"collect_seeds"}) == 0 and planting.seed_count == 9, "Inventory has finite cap and retains uncollected drop")
	var cutter = preload("res://features/levels/forest/forest_interactions.gd").new()
	cutter.configure(grid)
	var native = soil(grid,Vector2i(2,4))
	native.tree = true
	native.tree_state = "healthy"
	native.tree_health = 1.0
	check(cutter.begin(Vector2i(3,4),Vector2i.LEFT), "Existing tree cutting begins")
	var cut: Dictionary = cutter.tick(2.0,Vector2i(3,4))
	check(cut.get("seed_eligible", false), "Actual healthy tree completion offers seed")
	check(cutter.begin(Vector2i(3,4),Vector2i.LEFT), "Existing stump clearing begins")
	check(not cutter.tick(2.0,Vector2i(3,4)).get("seed_eligible", false), "Actual stump completion offers no seed")
	data.moisture = 0.0
	data.burning = true
	climate.weather_override = "heat"
	for second in range(24): climate.tick(1.0)
	check(data.burned and data.tree_state == "dead" and data.fuel == 0.0, "Mature planted trees burn through existing fire simulation")
	planting.seed_count = 0
	check(not planting.plant(grid,soil_cell(grid)), "No seeds prevents planting")
	models.configure(2026)
	check(models.planting.seed_count == 3 and models.states.is_empty(), "New run resets inventory and planted vegetation")
	sprout.queue_free()
	check_juvenile_removal()
	await scene_checks()
	print("PLANTING INTEGRATION: ", checks, " checks, ", failures, " failures")
	quit(failures)
func check_juvenile_removal():
	var models = Regions.new()
	models.configure(2026)
	var grid = models.enter("forest").grid
	var cutter = preload("res://features/levels/forest/forest_interactions.gd").new()
	cutter.configure(grid)
	var target = Vector2i(4,4)
	var player = target + Vector2i.RIGHT
	var landing = target + Vector2i.LEFT
	for stage in [0.0, 60.0, 120.0, 239.0]:
		for dead in [false,true]:
			var data = soil(grid,target)
			soil(grid,landing)
			models.planting.seed_count = 3
			models.planting.plant(grid,target)
			data.growth_age = stage
			if dead: data.tree_state = "dead"
			check(cutter.begin(player,Vector2i.LEFT), "Young/dead sapling removal can begin")
			var event = cutter.tick(2.0,player)
			check(event.get("kind", "") == "sapling_removed" and not event.has("landing") and not event.get("seed_eligible",false), "Juvenile never enters full-tree fall/log/seed logic")
			check(not data.tree and data.tree_state == "removed" and not grid.cells[landing.y*grid.SIZE+landing.x].log, "Young vegetation removal leaves empty cell without mature stump/log")
	var data = soil(grid,target)
	models.planting.seed_count = 3
	models.planting.plant(grid,target)
	check(cutter.begin(player,Vector2i.LEFT), "Start removal before growth boundary")
	data.growth_age = 240.0
	data.tree_state = "healthy"
	check(cutter.tick(2.0,player).is_empty() and data.tree_state == "healthy", "Maturing invalidates an in-progress juvenile action")
	check(cutter.begin(player,Vector2i.LEFT), "Fully grown planted tree can be chopped")
	check(cutter.tick(2.0,player).get("kind", "") == "tree_cut" and data.tree_state == "stump", "Only mature planted tree retains existing stump behavior")
	soil(grid,target)
	models.planting.seed_count = 3
	models.planting.plant(grid,target)
	cutter.begin(player,Vector2i.LEFT)
	cutter.tick(2.0,player)
	models.enter("wetlands")
	var returned = models.enter("forest")
	check(not returned.grid.cells[target.y*grid.SIZE+target.x].tree and returned.grid.cells[target.y*grid.SIZE+target.x].tree_state == "removed", "Removed sapling stays removed after regional round trip")

func highlighted(world: Node, cell: Vector2i) -> bool:
	var marker: Node3D = world.interaction_marker
	var expected: Vector3 = world.grid.world_position(cell) + Vector3(0,0.12,0)
	return marker.visible and marker.position.is_equal_approx(expected)

func soil_cell(grid: RefCounted) -> Vector2i:
	soil(grid,Vector2i(2,2))
	return Vector2i(2,2)
func scene_checks():
	var save = root.get_node("SaveManager")
	save.storage_path = SAVE
	if FileAccess.file_exists(SAVE): DirAccess.remove_absolute(SAVE)
	save.load_progression()
	var flow = root.get_node("SceneFlow")
	flow.next_seed = 2026
	flow.run_regions = Regions.new()
	flow.run_regions.configure(2026)
	flow.run_regions.enter("forest")
	change_scene_to_file("res://features/levels/forest/forest_level.tscn")
	await process_frame
	await process_frame
	var world = current_scene
	world.set_process(false)
	var player = world.get_node("GridPlayer")
	player.set_process(false)
	var target = Vector2i(7,5)
	soil(world.grid,target)
	if world.trees.has(target):
		world.trees[target].queue_free()
		world.trees.erase(target)
	world.decorated_cells.erase(target)
	player.cell = Vector2i(8,5)
	player.position = world.grid.world_position(player.cell)
	player.facing = Vector2i.LEFT
	world._update_interaction_marker()
	check(highlighted(world,target) and world.hud.get_node("Context").text.contains("Plant Seed"), "Empty eligible soil ring matches the named Interact action")
	for reason in ["burning","burned","occupied","seeds","protected"]:
		var soil_data: Dictionary = world.grid.cells[target.y*world.grid.SIZE+target.x]
		if reason == "burning": soil_data.burning = true
		if reason == "burned": soil_data.burned = true
		if reason == "occupied": world.decorated_cells[target] = true
		if reason == "seeds": world.planting.seed_count = 0
		if reason == "protected":
			player.cell = Vector2i(8,4)
			soil(world.grid,Vector2i(8,5))
		world._update_interaction_marker()
		check(not highlighted(world,Vector2i(8,5) if reason == "protected" else target), "Invalid soil has no planting ring: " + reason)
		soil_data.burning = false
		soil_data.burned = false
		world.decorated_cells.erase(target)
		world.planting.seed_count = 3
		player.cell = Vector2i(8,5)
	world._begin_context_action()
	player.cell = Vector2i(0,0)
	world._update_interaction_marker()
	check(not world.interaction_marker.visible and not world.hud.get_node("Context").text.contains("Plant Seed"), "Out-of-range cached action cannot retain a ring or stale prompt")
	player.cell = Vector2i(8,5)
	world._update_interaction_marker()
	check(highlighted(world,target), "Still valid in-range action retains its correct target")
	world.grid.cells[target.y*world.grid.SIZE+target.x].log = true
	world._update_interaction_marker()
	check(not highlighted(world,target) and not world.hud.get_node("Context").text.contains("Plant Seed"), "Stale active planting target clears ring and prompt immediately")
	world._tick_context_action(0.1)
	check(world.context_action.active.is_empty() and world.planting.seed_count == 3, "Invalidated planting cancels without spending seeds")
	world.grid.cells[target.y*world.grid.SIZE+target.x].log = false
	world._begin_context_action()
	check(world.context_action.active.get("object_kind", "") == "plant", "Existing contextual Interact selects planting without separate action")
	paused = true
	world._tick_context_action(2.0)
	check(world.planting.seed_count == 3, "Pause cannot complete planting")
	paused = false
	world._tick_context_action(1.1)
	check(world.planting.seed_count == 2 and world.trees[target].has_method("update_growth"), "Context completion creates visible sprout and consumes seed")
	check(world.hud.get_node("PlayerStatus/Rows/Supplies/Seeds").text == "2", "Existing HUD displays compact inventory")
	var knowledge: int = save.progression.knowledge
	world._discover("interaction.first_planting", "Repeated planting")
	check(save.progression.knowledge == knowledge, "Planting discovery awards Knowledge only once")
	world._update_interaction_marker()
	check(highlighted(world,target) and world.hud.get_node("Context").text.contains("Sapling") and world.hud.get_node("Context").text.contains("Remove"), "Juvenile prompt names sapling removal rather than mature chopping")
	world._begin_context_action()
	world._tick_context_action(1.3)
	var data: Dictionary = world.grid.cells[target.y*world.grid.SIZE+target.x]
	check(not data.tree and data.tree_state == "removed" and not world.trees.has(target), "Scene removes sapling without creating mature stump visual")
	check(world.planting.plant(world.grid,target), "Removed juvenile cell can be replanted")
	world._refresh_visuals()
	data.growth_age = 240.0
	data.tree_state = "healthy"
	data.tree_health = 0.9
	world._refresh_visuals()
	check(not world.trees[target].has_method("update_growth"), "Mature plant switches to shared existing tree visual")
	knowledge = save.progression.knowledge
	world._refresh_visuals()
	world._discover("flora.planted_growth", "Repeated growth")
	check(save.progression.knowledge == knowledge and save.progression.discoveries.has("flora.planted_growth"), "Growth discovery uses stable unique ID")
	var young_cell = Vector2i(9,5)
	soil(world.grid,young_cell)
	if world.trees.has(young_cell):
		world.trees[young_cell].queue_free()
		world.trees.erase(young_cell)
	world.planting.plant(world.grid,young_cell)
	world.grid.cells[young_cell.y * world.grid.SIZE + young_cell.x].growth_age = 70.0
	world._refresh_visuals()
	if DisplayServer.get_name() != "headless" and OS.has_environment("NIHILISTS_CAPTURE_DIR"):
		await create_timer(0.3).timeout
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png(OS.get_environment("NIHILISTS_CAPTURE_DIR").path_join("planting-desktop.png")) == OK, "Desktop Compatibility snapshot saved")
	var seeds_before: int = world.planting.seed_count
	check(flow.change_region("wetlands") == OK, "Actual scene transitions to wetlands")
	await process_frame
	await process_frame
	check(flow.change_region("forest") == OK, "Actual scene returns to forest")
	await process_frame
	await process_frame
	world = current_scene
	world.set_process(false)
	check(world.planting.seed_count == seeds_before and world.trees.has(target) and not world.trees[target].has_method("update_growth"), "Region scene reconstruction preserves inventory and grown tree")
	check(world.trees[young_cell].has_method("update_growth") and world.grid.cells[young_cell.y * world.grid.SIZE + young_cell.x].growth_age >= 70.0, "Regional reconstruction retains young plant stage and progress")
	check(save.progression.knowledge >= knowledge and save.progression.discoveries.has("flora.planted_growth"), "Regional reconstruction cannot duplicate growth discovery")
	current_scene.queue_free()
	await process_frame
	for path in [SAVE,SAVE+".tmp"]:
		if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
