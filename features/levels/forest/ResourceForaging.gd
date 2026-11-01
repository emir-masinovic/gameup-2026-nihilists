extends RefCounted
## The grid owns forage state, so recreating this adapter preserves depletion.
const REGROWTH_SECONDS := 180.0
const HARVEST_AMOUNT := 2
var grid: RefCounted

func configure(data: RefCounted, world_seed: int, region_id: String) -> void:
	grid = data
	if grid.cells.is_empty() or grid.cells[0].has("berry_bush"):
		return
	for cell_data in grid.cells:
		cell_data.berry_bush = false
		cell_data.berries = 0
		cell_data.berry_regrowth = 0.0
	for sc in grid.SPACESHIP_CELLS:
		if grid.in_bounds(sc):
			var cd: Dictionary = grid.cells[sc.y * grid.SIZE + sc.x]
			cd.berry_bush = false
			cd.berries = 0
	if grid.in_bounds(grid.recycle_bin_cell):
		var cd: Dictionary = grid.cells[grid.recycle_bin_cell.y * grid.SIZE + grid.recycle_bin_cell.x]
		cd.berry_bush = false
		cd.berries = 0
	for tc in grid.trash_cells:
		if grid.in_bounds(tc):
			var cd: Dictionary = grid.cells[tc.y * grid.SIZE + tc.x]
			cd.berry_bush = false
			cd.berries = 0
	var count: int = {"forest": 4, "wetlands": 3, "drylands": 1}.get(region_id, 1)
	var candidates: Array[Vector2i] = []
	for z in range(2, grid.SIZE - 2):
		for x in range(2, grid.SIZE - 2):
			var cell := Vector2i(x, z)
			if grid.traversable(cell) and cell.distance_to(grid.start) >= 2.0 and (x == grid.start.x or z == grid.start.y):
				var cd: Dictionary = grid.cells[z * grid.SIZE + x]
				if not cd.get("recycle_bin", false) and not cd.get("trash", false) and not grid.SPACESHIP_CELLS.has(cell):
					candidates.append(cell)
	var rng := RandomNumberGenerator.new()
	rng.seed = world_seed ^ 0xBE771
	for i in range(candidates.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var swap := candidates[i]
		candidates[i] = candidates[j]
		candidates[j] = swap
	# Forest's first food sits two steps along the guaranteed dry central route.
	var early := Vector2i(6, 8)
	if region_id == "forest" and candidates.has(early):
		candidates.erase(early)
		candidates.push_front(early)
	for i in range(mini(count, candidates.size())):
		var cell: Vector2i = candidates[i]
		var cell_data: Dictionary = grid.cells[cell.y * grid.SIZE + cell.x]
		cell_data.berry_bush = true
		cell_data.berries = HARVEST_AMOUNT

func availability(cell: Vector2i) -> Dictionary:
	if grid == null or not grid.in_bounds(cell):
		return {"available": false, "reason": "No berry bush"}
	var data: Dictionary = grid.cells[cell.y * grid.SIZE + cell.x]
	if not data.get("berry_bush", false) or data.get("recycle_bin", false) or data.get("trash", false):
		return {"available": false, "reason": "No berry bush"}
	if data.get("burning", false):
		return {"available": false, "reason": "Bush is burning"}
	if float(data.get("health", 1.0)) <= 0.05:
		return {"available": false, "reason": "Bush cannot fruit in this condition"}
	if float(data.get("moisture", 1.0)) < 0.12:
		return {"available": false, "reason": "Bush is too dry"}
	if int(data.get("berries", 0)) <= 0:
		return {"available": false, "reason": "Berries are regrowing"}
	return {"available": true, "reason": ""}

func harvest(cell: Vector2i) -> int:
	if not availability(cell).available:
		return 0
	var data: Dictionary = grid.cells[cell.y * grid.SIZE + cell.x]
	var amount := mini(HARVEST_AMOUNT, int(data.berries))
	data.berries = 0
	data.berry_regrowth = 0.0
	return amount

func tick(seconds: float) -> void:
	if grid == null or not is_finite(seconds) or seconds <= 0.0:
		return
	for data in grid.cells:
		if not data.get("berry_bush", false) or data.get("recycle_bin", false) or data.get("trash", false):
			continue
		if data.get("burning", false):
			data.berries = 0
			data.berry_regrowth = 0.0
			continue
		if int(data.get("berries", 0)) > 0:
			continue
		# Only elapsed favorable climate contributes; drought never silently regrows food.
		if float(data.get("moisture", 0.0)) <= 0.35 or float(data.get("health", 0.0)) <= 0.4:
			continue
		data.berry_regrowth = minf(REGROWTH_SECONDS, float(data.get("berry_regrowth", 0.0)) + seconds)
		if data.berry_regrowth >= REGROWTH_SECONDS:
			data.berries = HARVEST_AMOUNT
			data.berry_regrowth = 0.0
