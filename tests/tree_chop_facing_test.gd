extends SceneTree

var checks = 0
var failures = 0

func check(value: bool, message: String):
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func _initialize():
	call_deferred("run")

func run():
	var GridData = load("res://features/levels/forest/grid_data.gd")
	var ForestInteractions = load("res://features/levels/forest/forest_interactions.gd")
	var GridPlayerScene = load("res://features/player/grid_player.tscn")
	
	var grid = GridData.new()
	grid.generate(2026)
	var interactions = ForestInteractions.new()
	interactions.configure(grid)
	
	var player_pos = grid.start
	var tree_cell = player_pos + Vector2i.RIGHT
	grid.cells[tree_cell.y * grid.SIZE + tree_cell.x].tree = true
	grid.cells[tree_cell.y * grid.SIZE + tree_cell.x].tree_state = "healthy"
	
	# Test 1: Adjacent to tree, but facing AWAY (e.g. facing UP or LEFT)
	# Must not trigger tree_cut when facing away from the tree!
	interactions.target = Vector2i(-1, -1)
	if interactions.begin(player_pos, Vector2i.UP):
		check(interactions.action_kind != "tree_cut", "Facing UP does not chop tree on RIGHT")
	interactions.target = Vector2i(-1, -1)
	if interactions.begin(player_pos, Vector2i.LEFT):
		check(interactions.action_kind != "tree_cut", "Facing LEFT does not chop tree on RIGHT")
	interactions.target = Vector2i(-1, -1)
	if interactions.begin(player_pos, Vector2i.DOWN):
		check(interactions.action_kind != "tree_cut", "Facing DOWN does not chop tree on RIGHT")
	interactions.target = Vector2i(-1, -1)
	
	# Test 2: Adjacent to tree AND facing the tree (RIGHT)
	check(interactions.begin(player_pos, Vector2i.RIGHT), "Can chop tree when adjacent and directly facing it")
	check(interactions.action_kind == "tree_cut", "Action kind is tree_cut")
	check(interactions.target == tree_cell, "Target is the faced tree")
	interactions.target = Vector2i(-1, -1)
	
	# Test 3: Player node, Axe visibility, and chopping animation state
	var player = GridPlayerScene.instantiate()
	root.add_child(player)
	player.set_process(false)
	player.configure(grid)
	player.cell = player_pos
	player.position = grid.world_position(player_pos)
	
	var axe = player.get_node_or_null("Body/ArmRight/Axe")
	check(axe != null, "Player possesses Axe node in ArmRight")
	check(not axe.visible, "Axe is initially hidden during normal stance")
	
	var tree_world_pos = grid.world_position(tree_cell)
	player.start_chopping(tree_world_pos)
	check(player.is_chopping, "Player enters chopping state")
	check(axe.visible, "Axe becomes visible in hand when chopping begins")
	
	# Test 4: Impact signal and animation progression
	var impact_record = {"emitted": false, "pos": Vector3.ZERO}
	player.chop_impact.connect(func(pos: Vector3):
		impact_record.emitted = true
		impact_record.pos = pos
	)
	
	# Advance animation past wind-up and strike (0.46s)
	player._update_animation(0.46)
	check(impact_record.emitted, "Chop animation delivers strike and emits chop_impact")
	check(impact_record.pos.distance_to(tree_world_pos) < 2.0, "Impact is delivered directly onto tree trunk")
	
	# Test 5: Stopping chopping hides the axe
	player.stop_chopping()
	check(not player.is_chopping, "Chopping stopped")
	check(not axe.visible, "Axe is safely stowed away after chopping")
	
	# Test 6: Stump removal facing check
	grid.cells[tree_cell.y * grid.SIZE + tree_cell.x].tree_state = "stump"
	interactions.target = Vector2i(-1, -1)
	if interactions.begin(player_pos, Vector2i.UP):
		check(interactions.action_kind != "stump_removed", "Facing away does not remove stump")
	interactions.target = Vector2i(-1, -1)
	check(interactions.begin(player_pos, Vector2i.RIGHT), "Can remove stump when facing it")
	check(interactions.action_kind == "stump_removed", "Action kind is stump_removed")
	
	player.free()
	
	print("TREE CHOP FACING TEST: ", checks, " checks, ", failures, " failures")
	quit(0 if failures == 0 else 1)
