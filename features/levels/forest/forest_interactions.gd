extends RefCounted
var grid: RefCounted
var target = Vector2i(-1, -1)
var progress = 0.0
var duration = 1.2
var origin = Vector2i.ZERO

func configure(data: RefCounted):
	grid = data

func begin(player: Vector2i, facing: Vector2i) -> bool:
	if target.x >= 0:
		return false
	var directions = [facing, Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
	for direction in directions:
		var candidate = player + direction
		if grid.in_bounds(candidate) and grid.cells[candidate.y * grid.SIZE + candidate.x].tree:
			target = candidate
			origin = player
			progress = 0.0
			return true
	return false

func tick(delta: float, player: Vector2i) -> Dictionary:
	if target.x < 0:
		return {}
	if player != origin:
		target = Vector2i(-1, -1)
		return {}
	progress += maxf(delta, 0.0)
	if progress < duration:
		return {}
	var cell = grid.cells[target.y * grid.SIZE + target.x]
	var event = {"cell": target, "direction": target - player}
	if cell.get("tree_state", "healthy") == "stump":
		cell.tree = false
		cell.tree_state = "removed"
		event.kind = "stump_removed"
	else:
		cell.tree_state = "stump"
		cell.tree_health = 0.0
		event.kind = "tree_cut"
	target = Vector2i(-1, -1)
	return event
