extends RefCounted

var grid: RefCounted
var target = Vector2i(-1, -1)
var progress = 0.0
var duration = 1.2
var origin = Vector2i.ZERO
var _interaction_kind = ""

func configure(data: RefCounted):
	grid = data
	_cancel()

func begin(player: Vector2i, facing: Vector2i) -> bool:
	if target.x >= 0 or grid == null:
		return false
	var directions = [facing, Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
	for direction in directions:
		if absi(direction.x) + absi(direction.y) != 1:
			continue
		var candidate = player + direction
		if not grid.in_bounds(candidate):
			continue
		var cell = grid.cells[candidate.y * grid.SIZE + candidate.x]
		if cell.get("burning", false):
			continue
		if cell.get("log", false):
			_interaction_kind = "log_cleared"
		elif cell.tree:
			_interaction_kind = "stump_removed" if cell.get("tree_state", "healthy") == "stump" else "tree_cut"
		else:
			continue
		target = candidate
		origin = player
		progress = 0.0
		return true
	return false

func tick(delta: float, player: Vector2i) -> Dictionary:
	if target.x < 0:
		return {}
	if player != origin:
		_cancel()
		return {}
	var cell = grid.cells[target.y * grid.SIZE + target.x]
	# Weather or fire may invalidate an action while it is in progress.
	if cell.get("burning", false) or (_interaction_kind == "log_cleared" and not cell.get("log", false)) or (_interaction_kind != "log_cleared" and not cell.tree):
		_cancel()
		return {}
	if not is_finite(delta) or delta <= 0.0:
		return {}
	progress += delta
	if progress < maxf(duration, 0.01):
		return {}
	var event = {"cell": target, "direction": target - player, "kind": _interaction_kind}
	if _interaction_kind == "log_cleared":
		cell.log = false
		cell.fuel = 0.0
	elif _interaction_kind == "stump_removed":
		cell.tree = false
		cell.tree_state = "removed"
		cell.fuel = 0.0
	else:
		event.seed_eligible = cell.get("tree_state", "healthy") == "healthy" and cell.get("tree_health", 1.0) >= 0.66 and not cell.get("planted", false)
		cell.tree_state = "stump"
		cell.tree_health = 0.0
		# A cut cell is a practical break in fuel; the displaced wood blocks its landing.
		cell.fuel = 0.0
		var landing = target + (target - player)
		if grid.in_bounds(landing) and landing.distance_to(grid.start) > 2.5 and grid.traversable(landing) and landing not in [Vector2i(0,8),Vector2i(1,8),Vector2i(15,8),Vector2i(16,8)]:
			var landing_cell = grid.cells[landing.y * grid.SIZE + landing.x]
			landing_cell.log = true
			landing_cell.log_direction = target - player
			landing_cell.fuel = maxf(float(landing_cell.get("fuel", 0.0)), 0.65)
			event.landing = landing
	_cancel()
	return event

func _cancel() -> void:
	target = Vector2i(-1, -1)
	progress = 0.0
	_interaction_kind = ""
