extends RefCounted

const SIZE = 17
const CELL_SIZE = 2.0
const GENERATION_VERSION = 2
const SPACESHIP_CELLS: Array[Vector2i] = [
	Vector2i(9, 0), Vector2i(10, 0),
	Vector2i(9, 1), Vector2i(10, 1)
]
var start = Vector2i(8, 8)
var cells: Array[Dictionary] = []
var objective = Vector2i(8, 0)
var recycle_bin_cell: Vector2i = Vector2i(-1, -1)
var trash_cells: Array[Vector2i] = []

func generate(world_seed: int):
	cells.clear()
	recycle_bin_cell = Vector2i(-1, -1)
	trash_cells.clear()
	var rng = RandomNumberGenerator.new()
	rng.seed = world_seed
	# Gameplay and cosmetic draws are separate: visual variants never move trees.
	var cosmetic_rng = RandomNumberGenerator.new()
	cosmetic_rng.seed = world_seed ^ 0x79A13
	var clusters: Array[Vector2] = []
	for i in range(10):
		clusters.append(Vector2(rng.randf_range(0, SIZE - 1), rng.randf_range(0, SIZE - 1)))
	for z in range(SIZE):
		for x in range(SIZE):
			var cell = Vector2i(x, z)
			var density = 0.025
			for center in clusters:
				density += maxf(0.0, 1.0 - Vector2(cell).distance_to(center) / 3.2) * 0.48
			var vegetation = rng.randf() < minf(density, 0.78)
			if _protected_route(cell):
				vegetation = false
			cells.append({
				"tree": vegetation,
				"tree_state": "healthy" if vegetation else "removed",
				"tree_health": 1.0 if vegetation else 0.0,
				"shade": cosmetic_rng.randf(),
				"rotation": cosmetic_rng.randf_range(0.0, TAU),
				"scale": cosmetic_rng.randf_range(0.8, 1.2),
				"terrain": "grass" if rng.randf() > 0.15 else "soil",
				"water": false,
				"water_level": 0.0,
				"water_depth": 0.0,
				"tilled": false,
				"prepared": false,
				"water_needed": 1.0,
				"variant": cosmetic_rng.randi_range(0, 3),
				"log": false,
				"burning": false,
				"burned": false,
				"fuel": 1.0 if vegetation else 0.45,
				"fire_time": 0.0,
				"spaceship": false,
				"recycle_bin": false,
				"trash": false
			})
	# A single small connected pond/lake, kept off the central guaranteed dry cross.
	var pond = Vector2i(rng.randi_range(2, 5), rng.randi_range(2, 5))
	if rng.randf() < 0.5:
		pond.x = SIZE - 1 - pond.x
	if rng.randf() < 0.5:
		pond.y = SIZE - 1 - pond.y
	var pond_cells: Array[Vector2i] = [pond]
	var pond_size = rng.randi_range(2, 5)
	while pond_cells.size() < pond_size:
		var frontier: Array[Vector2i] = []
		for source in pond_cells:
			for offset in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				var candidate: Vector2i = source + offset
				if in_bounds(candidate) and not _protected_route(candidate) and not pond_cells.has(candidate) and not frontier.has(candidate):
					frontier.append(candidate)
		if frontier.is_empty():
			break
		pond_cells.append(frontier[rng.randi_range(0, frontier.size() - 1)])

	# Requirement: "No tree should spawn inside a lake or pond"
	for cell in pond_cells:
		var data: Dictionary = cells[cell.y * SIZE + cell.x]
		data.terrain = "water"
		data.water = true
		data.water_level = 1.0
		data.water_depth = 1.0
		data.tree = false
		data.tree_state = "removed"
		data.tree_health = 0.0
		data.fuel = 0.0

	# Spaceship footprint at northern clearing edge (stands upright, 2x2 cells, free of trees/water/berries)
	for cell in SPACESHIP_CELLS:
		var data: Dictionary = cells[cell.y * SIZE + cell.x]
		data.terrain = "grass"
		data.water = false
		data.water_level = 0.0
		data.water_depth = 0.0
		data.tree = false
		data.tree_state = "removed"
		data.tree_health = 0.0
		data.log = false
		data.fuel = 0.0
		data.burning = false
		data.burned = false
		data.tilled = false
		data.prepared = false
		data.spaceship = true

	# Recycle bin placement: exactly 1 per map on a clear, random cell.
	# Must not overlap with berries (cross route), water/ponds, trees, logs, or spaceship.
	var bin_candidates: Array[Vector2i] = []
	for z in range(2, SIZE - 2):
		for x in range(2, SIZE - 2):
			var cell = Vector2i(x, z)
			if _protected_route(cell) or cell == objective:
				continue
			var data: Dictionary = cells[z * SIZE + x]
			if data.water or data.terrain == "water" or data.tree or data.log or data.get("spaceship", false):
				continue
			var has_walkable_neighbor = false
			for offset in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
				var n = cell + offset
				if in_bounds(n) and not _protected_route(n):
					var nd = cells[n.y * SIZE + n.x]
					if not nd.water and nd.terrain != "water" and not nd.tree and not nd.log:
						has_walkable_neighbor = true
						break
			if has_walkable_neighbor:
				bin_candidates.append(cell)

	if not bin_candidates.is_empty():
		recycle_bin_cell = bin_candidates[rng.randi_range(0, bin_candidates.size() - 1)]
	else:
		recycle_bin_cell = Vector2i(6, 6)

	var bin_data: Dictionary = cells[recycle_bin_cell.y * SIZE + recycle_bin_cell.x]
	bin_data.recycle_bin = true
	bin_data.tree = false
	bin_data.tree_state = "removed"
	bin_data.tree_health = 0.0
	bin_data.water = false
	bin_data.water_level = 0.0
	bin_data.water_depth = 0.0
	bin_data.log = false
	bin_data.burning = false
	bin_data.burned = false
	bin_data.tilled = false
	bin_data.prepared = false
	bin_data.fuel = 0.0
	bin_data.trash = false

	# Trash clutter placement: a few random cells (4 cells) that do not overlap
	# with berries, ponds/water, trees, logs, spaceship, or recycle bin.
	var trash_candidates: Array[Vector2i] = []
	for z in range(1, SIZE - 1):
		for x in range(1, SIZE - 1):
			var cell = Vector2i(x, z)
			if _protected_route(cell) or cell == objective or cell == recycle_bin_cell:
				continue
			var diff = (cell - recycle_bin_cell).abs()
			if diff.x <= 1 and diff.y <= 1:
				continue
			var data: Dictionary = cells[z * SIZE + x]
			if data.water or data.terrain == "water" or data.tree or data.log or data.get("spaceship", false):
				continue
			trash_candidates.append(cell)

	for i in range(trash_candidates.size() - 1, 0, -1):
		var j = rng.randi_range(0, i)
		var tmp = trash_candidates[i]
		trash_candidates[i] = trash_candidates[j]
		trash_candidates[j] = tmp

	var num_trash = mini(4, trash_candidates.size())
	for i in range(num_trash):
		var c = trash_candidates[i]
		var d: Dictionary = cells[c.y * SIZE + c.x]
		d.trash = true
		trash_cells.append(c)

func _protected_route(cell: Vector2i) -> bool:
	return cell.distance_to(start) < 2.5 or cell.x == start.x or cell.y == start.y or SPACESHIP_CELLS.has(cell) or cell == recycle_bin_cell

func in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < SIZE and cell.y < SIZE

func traversable(cell: Vector2i) -> bool:
	if not in_bounds(cell):
		return false
	var data: Dictionary = cells[cell.y * SIZE + cell.x]
	if data.get("spaceship", false) or data.get("recycle_bin", false) or cell == recycle_bin_cell:
		return false
	if data.get("tree", false):
		var state = data.get("tree_state", "healthy")
		# Stumps, seeds, and saplings are traversable so player can stand on them to collect seeds or water.
		if state not in ["stump", "seed", "sapling"]:
			return false
	if data.get("log", false):
		return false
	var is_water = data.get("terrain", "grass") == "water" or data.get("water", false)
	if is_water:
		if data.get("water", false):
			if float(data.get("water_depth", 1.0)) > 0.25:
				return false
		else:
			if float(data.get("water_level", 1.0)) > 0.1:
				return false
	return true

func world_position(cell: Vector2i) -> Vector3:
	return Vector3((cell.x - start.x) * CELL_SIZE, 0, (cell.y - start.y) * CELL_SIZE)
