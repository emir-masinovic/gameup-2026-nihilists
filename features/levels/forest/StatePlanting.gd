extends RefCounted
# Run-local inventory; vegetation lives in each region's authoritative GridData.
const INITIAL_SEEDS = 3
const MAX_SEEDS = 9
const GROWTH_SECONDS = 240.0
var seed_count = INITIAL_SEEDS

func availability(grid: RefCounted, cell: Vector2i, occupied: bool = false) -> Dictionary:
	var reason = ""
	if not grid.in_bounds(cell):
		reason = "Outside the forest"
	else:
		var data: Dictionary = grid.cells[cell.y * grid.SIZE + cell.x]
		if occupied or data.tree or data.get("log", false) or data.get("berry_bush", false):
			reason = "Cell is occupied"
		elif data.terrain != "soil":
			reason = "Plant on bare soil"
		elif cell.distance_to(grid.start) < 2.5 or cell.x == grid.start.x or cell.y == grid.start.y or cell == grid.objective:
			reason = "Keep camp and trails clear"
		elif data.get("burning", false):
			reason = "Soil is burning"
		elif data.get("burned", false):
			reason = "Charred soil is not ready for planting"
		elif seed_count <= 0:
			reason = "No seeds remaining"
	return {"available": reason.is_empty(), "reason": reason}

func plant(grid: RefCounted, cell: Vector2i, occupied: bool = false) -> bool:
	if not availability(grid, cell, occupied).available: return false
	var data: Dictionary = grid.cells[cell.y * grid.SIZE + cell.x]
	seed_count -= 1
	data.tree = true
	data.tree_state = "sapling"
	data.tree_health = 0.35
	data.planted = true
	data.growth_age = 0.0
	data.growth_discovered = false
	data.fuel = 0.15
	return true

func collect_seed(grid: RefCounted, event: Dictionary) -> int:
	if event.get("kind", "") != "tree_cut" or not event.get("seed_eligible", false): return 0
	var data: Dictionary = grid.cells[event.cell.y * grid.SIZE + event.cell.x]
	if data.get("seed_yield_claimed", false) or data.get("planted", false): return 0
	# Claim even at capacity: neither stumps nor repeated events can farm seeds.
	data.seed_yield_claimed = true
	var before = seed_count
	seed_count = mini(seed_count + 1, MAX_SEEDS)
	return seed_count - before
