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
	for second in range(119): climate.tick(1.0)
	check(data.tree_state == "sapling" and data.growth_age == 119.0, "Maturity takes two favorable minutes")
	var sprout = preload("res://features/levels/forest/VisualSapling.tscn").instantiate()
	root.add_child(sprout)
	var sizes = []
	for age in [0.0,30.0,75.0]:
		data.growth_age = age
		sprout.update_growth(data)
		await create_timer(0.8).timeout
		sizes.append(sprout.scale.y)
	check(sizes[0] < sizes[1] and sizes[1] < sizes[2], "Three distinct visible growing stages")
	data.growth_age = 119.0
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
	check_natural_regeneration()
	check_microclimate()
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
	for stage in [0.0, 30.0, 75.0, 119.0]:
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
	data.growth_age = 120.0
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
	save.progression = {"discoveries":[],"knowledge":0,"upgrades":[]}
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
	var target = Vector2i(5,5)
	var data = soil(world.grid,target)
	data.tilled = true
	player.cell = target
	player.position = world.grid.world_position(target)
	player.facing = Vector2i.UP
	world._update_interaction_marker()
	check(highlighted(world,target) and world.hud.get_node("Context").text.contains(world._binding_label("interact")),"Standing prepared soil uses a binding-derived Interact preview")
	world._try_interact("interact")
	world._try_interact("interact")
	check(world.interactions.action_kind == "plant_sapling","Duplicate input starts one planting action")
	paused = true
	world._tick_context_action(2.0)
	check(world.planting.seed_count == 3,"Pause cannot spend seeds")
	paused = false
	world._tick_context_action(1.1)
	check(data.tree_state == "seed" and world.planting.seed_count == 2,"Planting creates Onur's seed stage through one inventory")
	check(world.hud.get_node("PlayerStatus/Rows/Supplies/Seeds").text == "2","Compact HUD reflects authoritative inventory")
	var knowledge = save.progression.knowledge
	world._discover("interaction.first_planting","Repeated planting")
	check(save.progression.knowledge == knowledge,"Planting retains its stable unique discovery ID")
	world.climate.weather_override = "rain"
	for second in range(8): world.climate.tick(1.0)
	world._refresh_visuals()
	check(data.tree_state == "sapling" and data.growth_age < 120.0 and world.trees[target].has_method("update_growth"),"Rain germinates seeds and restores shared growth-stage visuals")
	player.cell = target+Vector2i.DOWN
	player.position = world.grid.world_position(player.cell)
	player.facing = Vector2i.UP
	world._update_interaction_marker()
	check(highlighted(world,target),"Facing a juvenile highlights the correct target")
	world._try_interact("chop_gather")
	world._tick_context_action(1.0)
	check(not data.tree and data.tree_state == "removed" and world.planting.seed_count == 2,"Juvenile removal never creates a mature tree or refunds seeds")
	world._refresh_visuals()
	check(not world.trees.has(target),"Removed juvenile visual is cleared")
	planting_replant_scene(world,target)
	knowledge = save.progression.knowledge
	world._refresh_visuals()
	world._discover("flora.planted_growth","Repeated growth")
	check(save.progression.knowledge == knowledge,"Mature growth discovery is awarded once")
	flow.change_region("wetlands")
	await process_frame
	await process_frame
	flow.change_region("forest")
	await process_frame
	await process_frame
	check(current_scene.grid.cells[target.y*17+target.x].tree_state == "healthy","Mature vegetation persists through regional round trips")
	current_scene.queue_free()
	await process_frame
	if FileAccess.file_exists(SAVE): DirAccess.remove_absolute(SAVE)

func planting_replant_scene(world: Node, target: Vector2i):
	check(world.planting.plant(world.grid,target),"Removed juvenile soil supports replanting")
	var data: Dictionary = world.grid.cells[target.y*17+target.x]
	data.growth_age = 120.0
	data.tree_state = "healthy"
	data.tree_health = 0.9
	world._refresh_visuals()
	check(not world.trees[target].has_method("update_growth"),"Mature growth switches to shared adult visuals")

func check_microclimate():
	var models = []
	var target = Vector2i(6,5)
	var source = Vector2i(5,5)
	for cut in [false,true]:
		var regions = Regions.new()
		regions.configure(2026)
		var state = regions.get_region("forest")
		state.climate.baseline_temperature = 32.0
		state.climate.warming_limit = 0.0
		state.climate.weather_override = "clear"
		state.climate.ignition_chance = 0.0
		for cell_data in state.grid.cells:
			cell_data.tree = false
			cell_data.tree_state = "removed"
		var tree = soil(state.grid,source)
		tree.tree = true
		tree.tree_state = "stump" if cut else "healthy"
		tree.tree_health = 0.0 if cut else 1.0
		var neighbor = soil(state.grid,target)
		neighbor.terrain = "grass"
		neighbor.moisture = 0.6
		neighbor.health = 1.0
		state.climate.tick(0.01)
		models.append(state)
	check(models[0].climate.temperature_at(target) < models[1].climate.temperature_at(target), "Mature adjacent canopy cools local ground")
	check(is_equal_approx(models[0].climate.temperature_at(Vector2i(7,5)),models[0].climate.temperature), "Cooling stays within one cardinal cell")
	check(models[1].grid.cells[target.y*17+target.x].moisture > 0.59, "Cutting does not instantly damage soil moisture")
	for second in range(90):
		for state in models: state.climate.tick(1.0)
	var covered = models[0].grid.cells[target.y*17+target.x]
	var exposed = models[1].grid.cells[target.y*17+target.x]
	check(covered.moisture > exposed.moisture and covered.health >= exposed.health, "Cut patch dries and degrades faster through climate ticks")
	var state = models[1]
	var tree = soil(state.grid,source)
	var planting = Planting.new()
	planting.plant(state.grid,source)
	check(state.climate.shade_at(target) < models[0].climate.shade_at(target), "Young sapling shade is weaker than mature canopy")
	state.climate.weather_override = "rain"
	var before: float = exposed.health
	state.climate.tick(1.0)
	check(exposed.health < 1.0, "First rain tick cannot instantly reverse degradation")
	for second in range(119): state.climate.tick(1.0)
	check(tree.tree_state == "healthy" and state.climate.shade_at(target) > 0.0, "Reforestation eventually restores local shelter")
	check(exposed.health > before and exposed.moisture > 0.35, "Sustained rain gradually recovers surviving ground")
	check(tree.tree_health >= 0.82, "Faster maturity retains comparable mature-tree health")
	soil(state.grid,source)
	planting.plant(state.grid,source)
	state.climate.sapling_growth_rate = 4.0
	for second in range(30): state.climate.tick(1.0)
	check(tree.tree_state == "healthy" and tree.growth_age >= 120.0, "Demo acceleration grows plants in 30 favorable seconds without speeding climate")
	check(Planting.growth_stage(29.0)==0 and Planting.growth_stage(30.0)==1 and Planting.growth_stage(74.0)==1 and Planting.growth_stage(75.0)==2, "Visible growth thresholds share the normal 120-second balance")


func check_natural_regeneration():
	for region in ["forest","wetlands","drylands"]:
		var models = Regions.new()
		models.configure(2026)
		var state = models.enter(region)
		var climate = state.climate
		climate.weather_override = "rain"
		climate.ignition_chance = 0.0
		for data in state.grid.cells:
			data.tree = false
			data.tree_state = "removed"
			data.tree_health = 0.0
			data.moisture = 0.85
			data.health = 1.0
			data.shade = 0.6
		var parent: Dictionary = state.grid.cells[5*17+5]
		parent.merge({"tree":true,"tree_state":"healthy","tree_health":1.0},true)
		for second in range(90): climate.tick(1.0)
		var births = state.grid.cells.filter(func(data): return data.get("natural",false))
		check(births.size() == 1 and births[0].tree_state == "sapling" and births[0].growth_age == 0.0,"Favorable "+region+" creates one gradual natural sapling")
		if births.is_empty(): continue
		var sprout: Dictionary = births[0]
		var index = state.grid.cells.find(sprout)
		var cell = Vector2i(index%17,index/17)
		check(not state.grid._protected_route(cell) and not sprout.get("prepared",false) and sprout.terrain != "water","Natural seedlings respect routes and farming exclusions")
		check(models.planting.seed_count == 3 and sprout.growth_discovered and models.planting.record_seed_drop(state.grid,{"kind":"tree_cut","seed_eligible":true,"cell":cell}) == 0,"Natural births award no inventory, growth discovery or renewable seed drops")
		for second in range(30): climate.tick(1.0)
		check(Planting.growth_stage(sprout.growth_age)==1,"Natural seedlings use existing first growth stage")
		for second in range(45): climate.tick(1.0)
		check(Planting.growth_stage(sprout.growth_age)==2,"Natural seedlings use existing young-tree stage")
		for second in range(45): climate.tick(1.0)
		check(sprout.tree_state == "healthy" and sprout.growth_age >= 120.0,"Natural trees mature after 120 favorable seconds")
		models.advance(2.0)
		models.enter("wetlands" if region != "wetlands" else "forest")
		check(models.enter(region).grid.cells[index] == sprout,"Natural vegetation survives regional round trips")
		var target = Vector2i(4,4)
		var ground: Dictionary = state.grid.cells[4*17+4]
		ground.tree = false
		for flag in ["prepared","log","berry_bush","protected_route"]:
			ground[flag] = true
			check(not climate._can_regenerate(target),"Natural regeneration excludes "+flag)
			ground[flag] = false
		var count_before = state.grid.cells.filter(func(data): return data.tree).size()
		climate._tree_limit = count_before
		climate._reproduce_tree()
		check(state.grid.cells.filter(func(data): return data.tree).size() == count_before,"Population cap prevents further reproduction")
		# Existing drought mortality applies equally to naturally born trees.
		sprout.tree = true
		sprout.tree_state = "sapling"
		sprout.tree_health = 0.001
		sprout.growth_age = 0.0
		sprout.moisture = 0.0
		climate.weather_override = "heat"
		climate.tick(10.0)
		check(sprout.tree_state == "dead","Natural seedlings remain vulnerable to drought")
	var counts = []
	var forest_snapshot: Array = []
	for region in ["forest","wetlands","drylands"]:
		var models = Regions.new()
		models.configure(2026)
		var state = models.enter(region)
		state.climate.ignition_chance = 0.0
		for second in range(180): state.climate.tick(1.0)
		counts.append(state.grid.cells.filter(func(data): return data.get("natural",false)).size())
		if region == "forest": forest_snapshot = state.grid.cells.duplicate(true)
	check(counts[1] > counts[0] and counts[0] >= counts[2] and counts[2] == 0,"Representative climates favor Wetlands regeneration and suppress dry Drylands")
	var replay = Regions.new()
	replay.configure(2026)
	var repeated = replay.enter("forest")
	repeated.climate.ignition_chance = 0.0
	for second in range(180): repeated.climate.tick(1.0)
	check(repeated.grid.cells == forest_snapshot,"Reproduction is deterministic for the same seed and elapsed climate")
	for i in range(12):
		repeated.grid.cells[i].merge({"tree":true,"natural":true,"tree_state":"healthy","tree_health":1.0,"regeneration_credit":180.0},true)
	repeated.climate._tree_limit = 289
	var capped = repeated.grid.cells.filter(func(data): return data.tree).size()
	repeated.climate._reproduce_tree()
	check(repeated.grid.cells.filter(func(data): return data.tree).size() == capped,"Twelve natural trees cap reproduction independently of the total-tree limit")
	print("NATURAL REGENERATION forest/wetlands/drylands: ",counts)
