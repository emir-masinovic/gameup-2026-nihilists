extends RefCounted
var grid: RefCounted
var target = Vector2i(-1, -1)
var progress = 0.0
var duration = 1.2
var origin = Vector2i.ZERO
var action_kind: String = ""
var seeds: int = 3
var last_error: String = ""

const MAX_WATER_ML: int = 1000
const WATER_PER_POUR: int = 250
const WATER_PER_FILL: int = 500

var water_ml: int = 500

func configure(data: RefCounted):
	grid = data

func cancel() -> void:
	target = Vector2i(-1, -1)
	action_kind = ""
	progress = 0.0

func begin(player: Vector2i, facing: Vector2i, action_group: String = "") -> bool:
	if target.x >= 0:
		return false
	last_error = ""
	if not grid.in_bounds(player):
		return false
	var current_cell = grid.cells[player.y * grid.SIZE + player.x]
	var front = player + facing
	var front_cell = grid.cells[front.y * grid.SIZE + front.x] if grid.in_bounds(front) else null

	# Action Group: "chop_gather" (Space key)
	# 1. Stand on cut tree remains -> collect seeds (+3 seeds, remains removed)
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
	if front_cell != null and front_cell.get("water", false) and front_cell.get("water_depth", 0.0) > 0.08:
		return _begin_interact(player, front, current_cell, front_cell)
	if front_cell != null and front_cell.get("tree", false) and front_cell.get("tree_state", "healthy") in ["healthy", "dead"]:
		return _begin_chop_gather(player, front, current_cell, front_cell)
	if front_cell != null and front_cell.get("tree", false) and front_cell.get("tree_state") in ["seed", "sapling"]:
		return _begin_interact(player, front, current_cell, front_cell)
	return _begin_interact(player, front, current_cell, front_cell)

func _begin_chop_gather(player: Vector2i, front: Vector2i, current_cell: Dictionary, front_cell) -> bool:
	# Priority 1: Standing on cut tree remains / stump (Collect seeds)
	# Requirement: "ağaç kesildikten sonra ağaç hücresinin kalıntısının üzerine gidilebilmeli ve space tuşu ile tohum toplandıktan sonra ağaç kalıntısı yerden kaybolmalı."
	if current_cell.get("tree", false) and current_cell.get("tree_state") == "stump":
		target = player
		origin = player
		progress = 0.0
		action_kind = "collect_seeds"
		duration = 0.8
		return true

	# Priority 2: Facing tree (healthy or dead) to chop down with axe
	if front_cell != null and front_cell.get("tree", false) and front_cell.get("tree_state", "healthy") in ["healthy", "dead"]:
		target = front
		origin = player
		progress = 0.0
		action_kind = "tree_cut"
		duration = 1.2
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
		duration = 1.0
		return true

	# Priority 3: Water source (Lake / Puddle) in front (Filling water bottle)
	if front_cell != null and front_cell.get("water", false) and front_cell.get("water_depth", 0.0) > 0.08:
		if water_ml >= MAX_WATER_ML:
			last_error = "water_full"
			target = Vector2i(-1, -1)
			return false
		target = front
		origin = player
		progress = 0.0
		action_kind = "fill_water"
		duration = 2.4
		return true

	# Priority 4: Facing sapling/seed (Harvest/clear crop with hoe)
	if front_cell != null and front_cell.get("tree", false) and front_cell.get("tree_state") in ["seed", "sapling"]:
		target = front
		origin = player
		progress = 0.0
		action_kind = "harvest_crop"
		duration = 0.8
		return true

	# Priority 5: Tilling untilled soil with hoe ONLY ON CURRENT CELL (Bulunduğun hücre)
	# Requirement: "Sadece bulunduğun hücrenin üzerindeki toprak çapalanabilir, ağaç kesme işlemi gibi bir sonraki hücredeki toprak değil."
	if not current_cell.get("tree", false) and not current_cell.get("water", false) and not current_cell.get("tilled", false) and player != grid.start and player != grid.objective:
		target = player
		origin = player
		progress = 0.0
		action_kind = "till_soil"
		duration = 0.8
		return true

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
	if action_kind == "fill_water":
		var filled = min(WATER_PER_FILL, MAX_WATER_ML - water_ml)
		water_ml = min(MAX_WATER_ML, water_ml + WATER_PER_FILL)
		event["amount"] = filled
	elif action_kind == "till_soil":
		cell.tilled = true
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
		cell.tree_state = "stump"
		cell.tree_health = 0.0
		event.kind = "tree_cut"
		# Requirement: Do not add seeds here. Gained later by stepping on remains and pressing Space.
	elif cell.get("tree_state", "healthy") == "stump":
		cell.tree = false
		cell.tree_state = "removed"
		event.kind = "stump_removed"
	else:
		cell.tree_state = "stump"
		cell.tree_health = 0.0
		event.kind = "tree_cut"
	target = Vector2i(-1, -1)
	action_kind = ""
	return event
	target = Vector2i(-1, -1)
	action_kind = ""
	return event
