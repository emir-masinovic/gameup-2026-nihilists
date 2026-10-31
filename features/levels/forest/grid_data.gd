extends RefCounted
const SIZE = 17
const CELL_SIZE = 2.0
const GENERATION_VERSION = 1
var start = Vector2i(floori(SIZE * 0.5), floori(SIZE * 0.5))
var cells: Array[Dictionary] = []
var objective = Vector2i(8, 0)

func generate(world_seed: int):
	cells.clear()
	var rng = RandomNumberGenerator.new()
	rng.seed = world_seed
	var lake_quad = rng.randi_range(0, 3)
	var lake_center = [Vector2i(4, 4), Vector2i(12, 4), Vector2i(4, 12), Vector2i(12, 12)][lake_quad]
	var lake_radius = rng.randf_range(1.6, 2.1)
	for z in range(SIZE):
		for x in range(SIZE):
			var cell = Vector2i(x, z)
			var is_lake = cell.distance_to(lake_center) <= lake_radius and x != start.x and z != start.y and cell.distance_to(start) > 2.8
			var vegetation = rng.randf() < 0.19
			if cell.distance_to(start) < 2.5 or x == start.x or z == start.y or is_lake:
				vegetation = false
			cells.append({
				"tree": vegetation,
				"water": is_lake,
				"water_depth": 1.0 if is_lake else 0.0,
				"shade": rng.randf_range(0.0, 1.0),
				"rotation": rng.randf_range(0.0, TAU),
				"scale": rng.randf_range(0.8, 1.2)
			})

func in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < SIZE and cell.y < SIZE

func traversable(cell: Vector2i) -> bool:
	if not in_bounds(cell):
		return false
	var data = cells[cell.y * SIZE + cell.x]
	if data.get("tree", false):
		return false
	if data.get("water", false) and data.get("water_depth", 0.0) > 0.25:
		return false
	return true

func world_position(cell: Vector2i) -> Vector3:
	return Vector3((cell.x - start.x) * CELL_SIZE, 0, (cell.y - start.y) * CELL_SIZE)
