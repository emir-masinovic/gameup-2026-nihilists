extends RefCounted
var grid: RefCounted
var target = Vector2i(-1, -1)
var progress = 0.0
var duration = 1.2
var origin = Vector2i.ZERO
var action_kind: String = ""
var seeds: int = 3
var last_error: String = ""

func configure(data: RefCounted):
	grid = data

func begin(player: Vector2i, facing: Vector2i) -> bool:
	if target.x >= 0:
		return false
	last_error = ""
	# Priority 1: Check tree or stump directly in front (player must be adjacent AND facing it)
	var front = player + facing
	if grid.in_bounds(front):
		var front_cell = grid.cells[front.y * grid.SIZE + front.x]
		if front_cell.tree:
			target = front
			origin = player
			progress = 0.0
			if front_cell.get("tree_state", "healthy") == "stump":
				action_kind = "stump_removed"
				duration = 1.2
			else:
				action_kind = "tree_cut"
				duration = 1.2
			return true
	# Priority 2: Clear ground interaction (Watering dry soil or Planting sapling)
	if grid.in_bounds(front):
		var cell = grid.cells[front.y * grid.SIZE + front.x]
		if front != grid.start and front != grid.objective and not cell.tree and not cell.get("water", false):
			var moisture = cell.get("moisture", 1.0)
			var health = cell.get("health", 1.0)
			if moisture < 0.45 or health < 0.75:
				target = front
				origin = player
				progress = 0.0
				action_kind = "water_soil"
				duration = 0.8
				return true
			elif grid.traversable(front):
				if seeds <= 0:
					last_error = "no_seeds"
					target = Vector2i(-1, -1)
					return false
				target = front
				origin = player
				progress = 0.0
				action_kind = "plant_sapling"
				duration = 1.0
				return true
			else:
				target = Vector2i(-1, -1)
				return false
	return false

func tick(delta: float, player: Vector2i) -> Dictionary:
	if target.x < 0:
		return {}
	if player != origin:
		target = Vector2i(-1, -1)
		action_kind = ""
		return {}
	progress += maxf(delta, 0.0)
	if progress < duration:
		return {}
	var cell = grid.cells[target.y * grid.SIZE + target.x]
	var event = {"cell": target, "direction": target - player, "kind": action_kind}
	if action_kind == "water_soil":
		cell.moisture = 1.0
		cell.health = 1.0
		cell.trampled = 0.0
	elif action_kind == "plant_sapling":
		seeds = max(0, seeds - 1)
		cell.tree = true
		cell.tree_state = "sapling"
		cell.tree_health = 0.35
		cell.moisture = clampf(cell.get("moisture", 0.5) + 0.2, 0.0, 1.0)
	elif cell.get("tree_state", "healthy") == "stump":
		cell.tree = false
		cell.tree_state = "removed"
		event.kind = "stump_removed"
	else:
		cell.tree_state = "stump"
		cell.tree_health = 0.0
		event.kind = "tree_cut"
		seeds += 3
	target = Vector2i(-1, -1)
	action_kind = ""
	return event
