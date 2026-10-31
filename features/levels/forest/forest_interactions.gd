extends RefCounted

var grid: RefCounted
var target = Vector2i(-1, -1)
var origin = Vector2i.ZERO
var progress = 0.0
var duration = 1.2
var action_kind: String = ""
var _interaction_kind: String = ""
var seeds: int = 3
var last_error: String = ""

const MAX_WATER_ML: int = 1000
const WATER_PER_POUR: int = 250
const WATER_PER_FILL: int = 500

var water_ml: int = 500

func configure(data: RefCounted):
	grid = data
	cancel()

func cancel() -> void:
	target = Vector2i(-1, -1)
	action_kind = ""
	_interaction_kind = ""
	progress = 0.0

func _cancel() -> void:
	cancel()

func is_juvenile(cell: Dictionary) -> bool:
	return cell.get("tree_state", "") == "sapling" or cell.get("tree_state", "") == "seed" or (cell.get("planted", false) and cell.get("growth_age", 0.0) < 240.0 and cell.get("tree_state", "") != "stump")

func kind_for(cell: Dictionary) -> String:
	if cell.get("burning", false): return ""
	if cell.get("log", false): return "log_cleared"
	if not cell.get("tree", false): return ""
	if cell.get("tree_state", "healthy") == "stump": return "stump_removed"
	return "sapling_removed" if is_juvenile(cell) else "tree_cut"

func begin(player: Vector2i, facing: Vector2i, action_group: String = "") -> bool:
	if target.x >= 0 or grid == null:
		return false
	last_error = ""
	if not grid.in_bounds(player):
		return false

	var current_cell = grid.cells[player.y * grid.SIZE + player.x]
	var front = player + facing
	var front_cell = grid.cells[front.y * grid.SIZE + front.x] if grid.in_bounds(front) else null

	# Action Group: "chop_gather" (Space key)
	# 1. Stand on cut tree remains / stump -> collect seeds (+3 seeds, remains removed)
	# 2. Face tree -> chop tree down (axe animation, leaves remains on ground)
	if action_group == "chop_gather":
		return _begin_chop_gather(player, front, current_cell, front_cell)

	# Action Group: "interact" (E key)
	# 1. Stand on seed/sapling -> water crop
	# 2. Stand on tilled soil -> plant seed
	# 3. Face water -> fill water bottle
	# 4. Face crop -> harvest/clear crop with hoe
	# 5. Stand on untilled soil -> till soil under feet (Bulunduğun hücre)
	if action_group == "interact":
		return _begin_interact(player, front, current_cell, front_cell)

	# Action Group: "" (Auto-detect / unconstrained call)
	if current_cell.get("tree", false) and current_cell.get("tree_state") == "stump":
		return _begin_chop_gather(player, front, current_cell, front_cell)
	if current_cell.get("tree", false) and current_cell.get("tree_state") in ["seed", "sapling"]:
		return _begin_interact(player, front, current_cell, front_cell)
	if not current_cell.get("tree", false) and current_cell.get("tilled", false):
		return _begin_interact(player, front, current_cell, front_cell)
	if front_cell != null and _is_water_cell(front_cell):
		return _begin_interact(player, front, current_cell, front_cell)
	if front_cell != null and front_cell.get("tree", false) and front_cell.get("tree_state") == "stump":
		target = front
		origin = player
		progress = 0.0
		action_kind = "stump_removed"
		_interaction_kind = "stump_removed"
		duration = 0.8
		return true
	if front_cell != null and front_cell.get("tree", false):
		return _begin_chop_gather(player, front, current_cell, front_cell)
	if front_cell != null and front_cell.get("log", false):
		target = front
		origin = player
		progress = 0.0
		action_kind = "log_cleared"
		_interaction_kind = "log_cleared"
		duration = 1.2
		return true

	# Default to interact attempt on player's position (e.g. till soil)
	return _begin_interact(player, front, current_cell, front_cell)

func _is_water_cell(cell: Dictionary) -> bool:
	if cell.get("water", false) and cell.get("water_depth", 0.0) > 0.08:
		return true
	if cell.get("terrain", "") == "water" and cell.get("water_level", 0.0) > 0.08:
		return true
	return false

func _begin_chop_gather(player: Vector2i, front: Vector2i, current_cell: Dictionary, front_cell) -> bool:
	# Priority 1: Standing on cut tree remains / stump (Collect seeds)
	# Requirement: "ağaç kesildikten sonra ağaç hücresinin kalıntısının üzerine gidilebilmeli ve space tuşu ile tohum toplandıktan sonra ağaç kalıntısı yerden kaybolmalı."
	if current_cell.get("tree", false) and current_cell.get("tree_state") == "stump":
		target = player
		origin = player
		progress = 0.0
		action_kind = "collect_seeds"
		_interaction_kind = "collect_seeds"
		duration = 0.8
		return true

	# Priority 2: Facing tree (healthy, dead, or juvenile sapling/planted tree)
	if front_cell != null and front_cell.get("tree", false):
		var k = kind_for(front_cell)
		if k in ["tree_cut", "sapling_removed"]:
			target = front
			origin = player
			progress = 0.0
			action_kind = k
			_interaction_kind = k
			if k != "tree_cut":
				duration = 0.8
			return true

	return false

func _begin_interact(player: Vector2i, front: Vector2i, current_cell: Dictionary, front_cell) -> bool:
	# Priority 1: Standing on a growing seed or sapling (Watering)
	# Requirement: "Su, yalnızca büyümekte olan tohum ya da fidanın grid hücresinin üzerine gelindiğinde sulanabilmeli."
	if current_cell.get("tree", false) and current_cell.get("tree_state") in ["seed", "sapling"]:
		if water_ml < WATER_PER_POUR:
			last_error = "no_water"
			target = Vector2i(-1, -1)
			return false
		target = player
		origin = player
		progress = 0.0
		action_kind = "water_soil"
		_interaction_kind = "water_soil"
		duration = 0.8
		return true

	# Priority 2: Standing on tilled ground without a tree (Planting seed)
	# Requirement: "Tohum, yalnızca çapalanan toprağa ekilebilmeli ve karakter hangi grid hücresinin üzerindeyse oraya ekilebilmeli."
	if not current_cell.get("tree", false) and current_cell.get("tilled", false):
		if seeds <= 0:
			last_error = "no_seeds"
			target = Vector2i(-1, -1)
			return false
		target = player
		origin = player
		progress = 0.0
		action_kind = "plant_sapling"
		_interaction_kind = "plant_sapling"
		duration = 1.0
		return true

	# Priority 3: Water source (Lake / Puddle / Pond) in front (Filling water bottle)
	if front_cell != null and _is_water_cell(front_cell):
		if water_ml >= MAX_WATER_ML:
			last_error = "water_full"
			target = Vector2i(-1, -1)
			return false
		target = front
		origin = player
		progress = 0.0
		action_kind = "fill_water"
		_interaction_kind = "fill_water"
		duration = 2.4
		return true

	# Priority 4: Facing sapling/seed (Harvest/clear crop with hoe)
	if front_cell != null and front_cell.get("tree", false) and front_cell.get("tree_state") in ["seed", "sapling"]:
		target = front
		origin = player
		progress = 0.0
		action_kind = "harvest_crop"
		_interaction_kind = "harvest_crop"
		duration = 0.8
		return true

	# Priority 5: Tilling untilled soil with hoe ONLY ON CURRENT CELL (Bulunduğun hücre)
	# Requirement: "Sadece bulunduğun hücrenin üzerindeki toprak çapalanabilir, ağaç kesme işlemi gibi bir sonraki hücredeki toprak değil."
	if not current_cell.get("tree", false) and not _is_water_cell(current_cell) and not current_cell.get("tilled", false) and player != grid.start and player != grid.objective:
		target = player
		origin = player
		progress = 0.0
		action_kind = "till_soil"
		_interaction_kind = "till_soil"
		duration = 0.8
		return true

	return false

func tick(delta: float, player: Vector2i) -> Dictionary:
	if target.x < 0 or grid == null:
		return {}
	if player != origin:
		cancel()
		return {}
	var cell = grid.cells[target.y * grid.SIZE + target.x]
	if action_kind in ["tree_cut", "sapling_removed", "stump_removed", "log_cleared"]:
		if action_kind != kind_for(cell):
			cancel()
			return {}
	if not is_finite(delta) or delta <= 0.0:
		return {}
	progress += delta
	if progress < maxf(duration, 0.01):
		return {}

	var event = {"cell": target, "direction": target - player, "kind": action_kind}

	if action_kind == "fill_water":
		var filled = mini(WATER_PER_FILL, MAX_WATER_ML - water_ml)
		water_ml = mini(MAX_WATER_ML, water_ml + WATER_PER_FILL)
		event["amount"] = filled
	elif action_kind == "till_soil":
		cell.tilled = true
		cell.prepared = true
		cell.health = 0.9
		cell.trampled = 0.0
	elif action_kind == "water_soil":
		water_ml = max(0, water_ml - WATER_PER_POUR)
		event["amount"] = WATER_PER_POUR
		cell.moisture = 1.0
		cell.health = 1.0
		cell.trampled = 0.0
		if cell.get("tree_state") == "seed":
			cell.water_needed = maxf(0.0, cell.get("water_needed", 1.0) - 0.5)
			if cell.water_needed <= 0.0:
				cell.tree_state = "sapling"
				cell.tree_health = 0.25
	elif action_kind == "plant_sapling":
		seeds = max(0, seeds - 1)
		cell.tree = true
		cell.tree_state = "seed"
		cell.water_needed = 1.0
		cell.tree_health = 0.1
		cell.planted = true
		cell.growth_age = 0.0
		cell.fuel = 0.15
	elif action_kind == "harvest_crop":
		cell.tree = false
		cell.tree_state = "removed"
		cell.tree_health = 0.0
		seeds += 1
	elif action_kind == "collect_seeds":
		cell.tree = false
		cell.tree_state = "removed"
		cell.tree_health = 0.0
		seeds += 3
		event.kind = "collect_seeds"
	elif action_kind == "tree_cut":
		event.seed_eligible = cell.get("tree_state", "healthy") == "healthy" and cell.get("tree_health", 1.0) >= 0.66 and not cell.get("planted", false)
		cell.tree_state = "stump"
		cell.tree_health = 0.0
		cell.fuel = 0.0
		var landing = target + (target - player)
		if grid.in_bounds(landing) and landing.distance_to(grid.start) > 2.5 and grid.traversable(landing) and landing not in [Vector2i(0,8),Vector2i(1,8),Vector2i(15,8),Vector2i(16,8)]:
			var landing_cell = grid.cells[landing.y * grid.SIZE + landing.x]
			landing_cell.log = true
			landing_cell.log_direction = target - player
			landing_cell.fuel = maxf(float(landing_cell.get("fuel", 0.0)), 0.65)
			event.landing = landing
		event.kind = "tree_cut"
	elif action_kind == "log_cleared":
		cell.log = false
		cell.fuel = 0.0
	elif action_kind in ["stump_removed", "sapling_removed"]:
		cell.tree = false
		cell.tree_state = "removed"
		cell.fuel = 0.0
	elif cell.get("tree_state", "healthy") == "stump":
		cell.tree = false
		cell.tree_state = "removed"
		event.kind = "stump_removed"

	cancel()
	return event
