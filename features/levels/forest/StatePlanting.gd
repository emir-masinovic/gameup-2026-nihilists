extends RefCounted
# Run-local inventory; vegetation lives in each region's authoritative GridData.
const INITIAL_SEEDS = 3
const MAX_SEEDS = 9
const GROWTH_SECONDS = 120.0
const MAX_WATER_ML = 1000
const WATER_PER_POUR = 250
const WATER_PER_FILL = 500
var water_ml = 500
var seed_count = INITIAL_SEEDS

func soil_availability(grid: RefCounted, cell: Vector2i, occupied: bool = false) -> Dictionary:
	var reason = ""
	if not grid.in_bounds(cell):
		reason = "Outside the forest"
	else:
		var data: Dictionary = grid.cells[cell.y * grid.SIZE + cell.x]
		if occupied or data.tree or data.get("log", false) or data.get("berry_bush", false) or data.get("spaceship", false) or data.get("recycle_bin", false) or cell == grid.recycle_bin_cell:
			reason = "Cell is occupied"
		elif data.get("trash", false):
			reason = "Clear trash first"
		elif data.terrain != "soil" and not data.get("tilled", false):
			reason = "Plant on bare soil"
		elif cell == grid.start or grid.SPACESHIP_CELLS.has(cell):
			reason = "Keep camp and trails clear"
		elif not data.get("tilled", false) and (cell.distance_to(grid.start) < 2.5 or cell.x == grid.start.x or cell.y == grid.start.y or cell == grid.objective):
			reason = "Keep camp and trails clear"
		elif data.get("burning", false):
			reason = "Soil is burning"
		elif data.get("burned", false):
			reason = "Charred soil is not ready for planting"
	return {"available": reason.is_empty(), "reason": reason}

func availability(grid: RefCounted, cell: Vector2i, occupied: bool = false) -> Dictionary:
	var result = soil_availability(grid, cell, occupied)
	if result.available and not grid.cells[cell.y * grid.SIZE + cell.x].get("prepared", false):
		result = {"available": false, "reason": "Prepare soil first"}
	if result.available and seed_count <= 0:
		result = {"available": false, "reason": "No seeds remaining"}
	return result

func prepare(grid: RefCounted, cell: Vector2i, occupied: bool = false) -> bool:
	if not soil_availability(grid, cell, occupied).available: return false
	var data: Dictionary = grid.cells[cell.y * grid.SIZE + cell.x]
	if data.get("prepared", false): return false
	data.prepared = true
	return true

func water_availability(grid: RefCounted, cell: Vector2i) -> Dictionary:
	if not grid.in_bounds(cell): return {"available": false, "reason": "Outside forest"}
	var data: Dictionary = grid.cells[cell.y * grid.SIZE + cell.x]
	var valid: bool = data.tree and data.get("planted", false) and data.tree_state == "sapling" and not data.get("burning", false) and not data.get("burned", false) and data.moisture < 0.65
	return {"available": valid and water_ml >= WATER_PER_POUR, "reason": "Refill bottle at a pond" if valid and water_ml < WATER_PER_POUR else "Plant does not need water"}

func water_plant(grid: RefCounted, cell: Vector2i) -> bool:
	if not water_availability(grid, cell).available: return false
	water_ml -= WATER_PER_POUR
	var data: Dictionary = grid.cells[cell.y * grid.SIZE + cell.x]
	data.moisture = minf(1.0, data.moisture + 0.5)
	return true

func fill_bottle(grid: RefCounted, cell: Vector2i) -> int:
	if not grid.in_bounds(cell): return 0
	var data: Dictionary = grid.cells[cell.y * grid.SIZE + cell.x]
	if data.terrain != "water" or data.get("water_level", 0.0) <= 0.1: return 0
	var filled = mini(WATER_PER_FILL, MAX_WATER_ML - water_ml)
	water_ml += filled
	return filled

func plant(grid: RefCounted, cell: Vector2i, occupied: bool = false) -> bool:
	if not availability(grid, cell, occupied).available: return false
	var data: Dictionary = grid.cells[cell.y * grid.SIZE + cell.x]
	seed_count -= 1
	data.tree = true
	data.tree_state = "sapling"
	data.tree_health = 0.35
	data.planted = true
	data.natural = false
	data.regeneration_credit = 0.0
	data.growth_age = 0.0
	data.growth_discovered = false
	data.fuel = 0.15
	return true

func record_seed_drop(grid: RefCounted, event: Dictionary) -> int:
	if event.get("kind", "") != "tree_cut" or not event.get("seed_eligible", false): return 0
	var data: Dictionary = grid.cells[event.cell.y * grid.SIZE + event.cell.x]
	if data.get("seed_yield_claimed", false) or data.get("planted", false): return 0
	data.seed_yield_claimed = true
	data.pending_seeds = 1
	return 1

func collect_seed(grid: RefCounted, event: Dictionary) -> int:
	if event.get("kind", "") != "collect_seeds": return 0
	var data: Dictionary = grid.cells[event.cell.y * grid.SIZE + event.cell.x]
	if data.get("burning", false): return 0
	var amount = mini(int(data.get("pending_seeds", 0)), MAX_SEEDS - seed_count)
	seed_count += amount
	data.pending_seeds = int(data.get("pending_seeds", 0)) - amount
	return amount

static func growth_stage(age: float) -> int:
	return 0 if age < GROWTH_SECONDS * 0.25 else 1 if age < GROWTH_SECONDS * 0.625 else 2

# Integrated directional interaction entry points; inventory and crop writes live here.
func plant_seed(grid: RefCounted, cell: Vector2i) -> bool:
	if not plant(grid,cell): return false
	var data: Dictionary = grid.cells[cell.y*grid.SIZE+cell.x]
	data.tree_state = "seed"
	data.tree_health = 0.1
	data.water_needed = 1.0
	return true

func water_crop(grid: RefCounted, cell: Vector2i) -> bool:
	if not grid.in_bounds(cell) or water_ml < WATER_PER_POUR: return false
	var data: Dictionary = grid.cells[cell.y*grid.SIZE+cell.x]
	if not data.tree or data.tree_state not in ["seed","sapling"] or data.burning or data.burned: return false
	water_ml -= WATER_PER_POUR
	data.moisture = minf(1.0,data.moisture+0.5)
	data.health = 1.0
	data.trampled = 0.0
	if data.tree_state == "seed": data.water_needed = maxf(0.0,data.get("water_needed",1.0)-0.5)
	return true
