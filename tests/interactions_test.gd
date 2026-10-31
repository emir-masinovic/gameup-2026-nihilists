extends SceneTree
func _initialize():
	var grid = load("res://features/levels/forest/grid_data.gd").new()
	grid.generate(2026)
	var interaction = load("res://features/levels/forest/forest_interactions.gd").new()
	interaction.configure(grid)
	var player = grid.start
	var target = player + Vector2i.RIGHT
	grid.cells[target.y * grid.SIZE + target.x].tree = true
	assert(interaction.begin(player, Vector2i.RIGHT))
	assert(interaction.tick(0.5, player).is_empty())
	assert(interaction.tick(1.0, player + Vector2i.UP).is_empty())
	assert(interaction.target.x == -1)
	assert(interaction.begin(player, Vector2i.RIGHT))
	var cut = interaction.tick(2.0, player)
	assert(cut.kind == "tree_cut" and cut.direction == target - player)
	assert(grid.traversable(target))
	assert(grid.cells[target.y * grid.SIZE + target.x].tree_state == "stump")
	assert(interaction.begin(player, Vector2i.RIGHT))
	assert(interaction.tick(2.0, player).kind == "stump_removed")
	assert(grid.traversable(target))
	assert(grid.cells[target.y * grid.SIZE + target.x].tree_state == "removed")
	print("INTERACTIONS: 12 checks passed")
	quit()
