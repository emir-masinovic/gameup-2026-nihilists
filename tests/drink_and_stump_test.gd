extends SceneTree
var checks = 0
var failures = 0
func check(ok: bool, message: String):
	checks += 1
	if not ok: failures += 1; push_error(message)
func _initialize(): call_deferred("run")
func run():
	if not OS.get_user_data_dir().contains("NihilistsRepairValidation"):
		push_error("Repair test requires isolated user data")
		quit(2)
		return
	var level = load("res://features/levels/forest/forest_level.tscn").instantiate()
	root.add_child(level)
	level.set_process(false)
	var grid = level.grid
	var player = level.get_node("GridPlayer")
	player.set_process(false)
	var actions = level.interactions
	var survival = level.survival
	var stand = Vector2i(5,5)
	var tree = Vector2i(5,6)
	var data = grid.cells[tree.y*grid.SIZE+tree.x]
	data.merge({"tree":true,"tree_state":"healthy","tree_health":1.0,"planted":false,"seed_yield_claimed":false,"pending_seeds":0,"log":false,"burning":false,"burned":false,"terrain":"grass"},true)
	player.cell = stand
	player.facing = Vector2i.DOWN
	actions.seeds = 8
	level._try_interact("chop_gather")
	check(actions.action_kind == "tree_cut","Facing chop dispatch")
	var event = actions.tick(2.0,stand)
	level._finish_interaction(event)
	check(data.tree_state == "stump" and data.pending_seeds == 3,"One eligible tree creates three collectible seeds")
	check(not grid.traversable(tree) and not player.try_move(Vector2i.DOWN),"Stump blocks movement")
	level._try_interact("chop_gather")
	event = actions.tick(1.0,stand)
	level._finish_interaction(event)
	check(actions.seeds == 9 and data.pending_seeds == 2 and data.tree_state == "stump","Partial pickup retains blocked stump and exact leftovers")
	check(not actions.begin(stand,Vector2i.DOWN,"chop_gather"),"Full inventory cannot gather or remove stump with Chop/Gather")
	var previews = [level._action_preview("interact"),level._action_preview("chop_gather")]
	check(previews[0].object_kind == "stump_removed" and previews[1].is_empty(),"Full inventory previews explicit removal")
	level._try_interact("interact")
	check(actions.action_kind == "stump_removed","Interact removes stump before underfoot farming")
	level._finish_interaction(actions.tick(1.0,stand))
	check(not data.tree and data.pending_seeds == 2 and actions.seeds == 9 and grid.traversable(tree),"Removal leaves persistent nonblocking pickup without reward")
	actions.seeds = 7
	check(actions.begin(stand,Vector2i.DOWN,"chop_gather"),"Loose pickup collectible from adjacent cell")
	event = actions.tick(1.0,stand)
	level._finish_interaction(event)
	check(actions.seeds == 9 and data.pending_seeds == 0,"Remaining quantity collected once")
	check(actions.tick(1.0,stand).is_empty(),"Completion cannot issue a duplicate reward")
	data.merge({"tree":true,"tree_state":"stump","pending_seeds":0},true)
	check(not actions.begin(stand,Vector2i.DOWN,"chop_gather"),"Empty stump still requires Interact")
	data.merge({"tree":false,"tree_state":"removed","terrain":"soil","tilled":true,"prepared":true,"pending_seeds":0,"log":false,"berry_bush":false,"burning":false,"burned":false},true)
	stand = tree
	player.cell = stand
	player.facing = Vector2i.DOWN
	var water = grid.cells[7*grid.SIZE+5]
	water.merge({"tree":false,"terrain":"water","water":true,"water_depth":1.0,"water_level":1.0,"burning":false},true)
	actions.seeds = 0
	actions.water_ml = 200
	survival.thirst = 30
	level._try_interact("chop_gather")
	check(actions.action_kind == "drink_water" and player.is_drinking,"Direct drinking starts animation")
	level._finish_interaction(actions.tick(1.0,stand))
	check(survival.thirst == 75 and actions.water_ml == 200 and not player.is_drinking,"Drinking changes hydration only and stops animation")
	level._try_interact("interact")
	check(actions.action_kind == "fill_water","Unavailable planting falls back to bottle filling")
	level._finish_interaction(actions.tick(3.0,stand))
	check(actions.water_ml == 700 and survival.thirst == 75,"Filling changes bottle only")
	actions.water_ml = 900
	actions.begin(stand,Vector2i.DOWN,"interact")
	level._finish_interaction(actions.tick(3.0,stand))
	check(actions.water_ml == 1000,"Bottle filling clamps remaining capacity")
	check(not actions.begin(stand,Vector2i.DOWN,"interact"),"Full bottle rejects fill when no farming is available")
	actions.seeds = 1
	check(actions.begin(stand,Vector2i.DOWN,"interact") and actions.action_kind == "plant_sapling","Valid planting wins even with full bottle")
	actions.cancel()
	data.tree = true
	data.tree_state = "seed"
	actions.water_ml = 500
	check(actions.begin(stand,Vector2i.DOWN,"interact") and actions.action_kind == "water_soil","Valid crop watering beats facing water")
	actions.cancel()
	actions.water_ml = 0
	check(actions.begin(stand,Vector2i.DOWN,"interact") and actions.action_kind == "fill_water","Empty bottle makes watering unavailable and allows fill")
	actions.cancel()
	for kind in ["interact","chop_gather"]:
		actions.water_ml = 0
		check(actions.begin(stand,Vector2i.DOWN,kind),"Water action starts while water exists")
		water.water = false
		water.terrain = "grass"
		water.water_depth = 0.0
		water.water_level = 0.0
		var hydration = survival.thirst
		event = actions.tick(3.0,stand)
		level._finish_interaction(event)
		check(event.is_empty() and actions.water_ml == 0 and survival.thirst == hydration,"Missing water cancels without resource changes")
		water.water = true
		water.water_depth = 1.0
		water.terrain = "water"
		water.water_level = 1.0
	data.tree = false
	data.tilled = false
	data.prepared = false
	check(actions.begin(stand,Vector2i.DOWN,"interact") and actions.action_kind == "till_soil","Valid underfoot soil preparation wins over filling")
	actions.cancel()
	var settings = root.get_node("SettingsManager")
	var old = settings.bindings.duplicate(true)
	settings.bindings.interact = [KEY_K,0]
	settings.bindings.chop_gather = [KEY_J,0]
	level._update_interaction_marker()
	var text = level.hud.get_node("Context").text
	check(text.contains("K") and text.contains("J") and not text.contains("Space"),"Both prompts derive remapped bindings")
	check(level.interaction_marker.visible and level.selected_interaction.cell in [stand,stand+Vector2i.DOWN],"Ring tracks an actual preview target")
	settings.bindings = old
	level.queue_free()
	await process_frame
	await process_frame
	print("DRINK AND STUMP: ",checks," checks, ",failures," failures")
	quit(failures)
