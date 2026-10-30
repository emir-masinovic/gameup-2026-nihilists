extends RefCounted
const SIZE = 17
const CELL_SIZE = 2.0
const GENERATION_VERSION = 1
var start = Vector2i(floori(SIZE * 0.5), floori(SIZE * 0.5))
var cells: Array[Dictionary] = []

func generate(world_seed: int):
	cells.clear()
	var rng = RandomNumberGenerator.new()
	rng.seed = world_seed
	for z in range(SIZE):
		for x in range(SIZE):
			var cell = Vector2i(x, z)
			var vegetation = rng.randf() < 0.19
			if cell.distance_to(start) < 2.5 or x == start.x or z == start.y:
				vegetation = false
			cells.append({"tree": vegetation, "shade": rng.randf_range(0.0, 1.0), "rotation": rng.randf_range(0.0, TAU), "scale": rng.randf_range(0.8, 1.2)})

func in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < SIZE and cell.y < SIZE

func traversable(cell: Vector2i) -> bool:
	return in_bounds(cell) and not cells[cell.y * SIZE + cell.x].tree

func world_position(cell: Vector2i) -> Vector3:
	return Vector3((cell.x - start.x) * CELL_SIZE, 0, (cell.y - start.y) * CELL_SIZE)
