extends RefCounted

var grid: RefCounted
var target = Vector2i(-1, -1)
var origin = Vector2i.ZERO
var progress = 0.0
var duration = 1.2
var action_kind: String = ""
var _interaction_kind: String = ""
var inventory = preload("res://features/levels/forest/StatePlanting.gd").new()
var seeds: int:
	get: return inventory.seed_count
	set(value): inventory.seed_count = clampi(value,0,inventory.MAX_SEEDS)
var last_error: String = ""

const MAX_WATER_ML: int = 1000
const WATER_PER_POUR: int = 250
const WATER_PER_FILL: int = 500

var water_ml: int:
	get: return inventory.water_ml
	set(value): inventory.water_ml = clampi(value,0,inventory.MAX_WATER_ML)

func configure(data: RefCounted, authoritative_inventory: RefCounted = null):
	if authoritative_inventory != null: inventory = authoritative_inventory
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
	return cell.get("tree_state", "") == "sapling" or cell.get("tree_state", "") == "seed" or (cell.get("planted", false) and cell.get("growth_age", 0.0) < preload("res://features/levels/forest/StatePlanting.gd").GROWTH_SECONDS and cell.get("tree_state", "") != "stump")

func kind_for(cell: Dictionary) -> String:
	if cell.get("burning", false): return ""
	if cell.get("tree",false) and cell.get("tree_state") == "stump": return "stump_removed"
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
	# 1. Gather adjacent stump seeds or non-blocking loose pickups; preserve stump.
	# 2. Face water to drink or tree/log to chop; empty stumps require Interact.
	if action_group == "chop_gather":
		return _begin_chop_gather(player, front, current_cell, front_cell)

	# Action Group: "interact" (E key)
	# 1. Stand on seed/sapling -> water crop
	# 2. Stand on tilled soil -> plant seed
	# 3. Prepare eligible untilled soil underfoot.
	# 4. Face water -> fill water bottle if no underfoot farming is available.
	# 5. Face crop -> harvest/clear crop with hoe
	if action_group == "interact":
		return _begin_interact(player, front, current_cell, front_cell)

	# Action Group: "" (Auto-detect / unconstrained call)
	if current_cell.get("pending_seeds", 0) > 0:
		return _begin_chop_gather(player, front, current_cell, front_cell)
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
	if front_cell != null and front_cell.get("tree", false) and front_cell.get("tree_state") in ["seed", "sapling"]:
		return _begin_interact(player, front, current_cell, front_cell)
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

	return _begin_interact(player, front, current_cell, front_cell)

func _start_action(player: Vector2i, cell: Vector2i, kind: String) -> bool:
	target = cell
	origin = player
	progress = 0.0
	action_kind = kind
	_interaction_kind = kind
	duration = 1.2 if kind == "tree_cut" else (0.9 if kind == "drink_water" else 0.8)
	return true

func _is_water_cell(cell: Dictionary) -> bool:
	if cell.get("water", false) and cell.get("water_depth", 0.0) > 0.08:
		return true
	if cell.get("terrain", "") == "water" and cell.get("water_level", 0.0) > 0.08:
		return true
	return false

func _begin_chop_gather(player: Vector2i, front: Vector2i, current_cell: Dictionary, front_cell) -> bool:
	# Loose seeds remain collectible on occupied/farmed ground without blocking it.
	if current_cell.get("pending_seeds", 0) > 0 and seeds < inventory.MAX_SEEDS and not current_cell.get("burning", false):
		return _start_action(player, player, "collect_seeds")
	if front_cell == null or front_cell.get("burning", false):
		return false
	if front_cell.get("pending_seeds", 0) > 0:
		if seeds < inventory.MAX_SEEDS:
			return _start_action(player, front, "collect_seeds")
		if front_cell.get("tree", false) and front_cell.get("tree_state") == "stump":
			return false
	if front_cell.get("tree",false) and front_cell.get("tree_state") == "stump":
		return false
	if _is_water_cell(front_cell):
		return _start_action(player, front, "drink_water")
	var kind = kind_for(front_cell)
	if kind in ["tree_cut", "sapling_removed", "log_cleared"]:
		return _start_action(player, front, kind)
	return false

func _begin_interact(player: Vector2i, front: Vector2i, current_cell: Dictionary, front_cell) -> bool:
	# Retain useful failure feedback when no fallback action is available.
	if current_cell.get("tree_state", "") in ["seed", "sapling"] and water_ml < WATER_PER_POUR:
		last_error = "no_water"
	elif current_cell.get("tilled", false) and not current_cell.get("tree", false) and seeds <= 0:
		last_error = "no_seeds"
	# Explicit removal always wins over underfoot farming, even at full inventory.
	if front_cell != null and front_cell.get("tree", false) and front_cell.get("tree_state") == "stump" and not front_cell.get("burning", false):
		return _start_action(player, front, "stump_removed")

	# Priority 1: Standing on a growing seed or sapling (Watering)
	if current_cell.get("tree", false) and current_cell.get("tree_state") in ["seed", "sapling"] and not current_cell.get("burning", false) and not current_cell.get("burned", false) and water_ml >= WATER_PER_POUR:
		target = player
		origin = player
		progress = 0.0
		action_kind = "water_soil"
		_interaction_kind = "water_soil"
		duration = 0.8
		return true

	# Priority 2: Standing on tilled ground without a tree (Planting seed)
	if not current_cell.get("tree", false) and current_cell.get("tilled", false) and not current_cell.get("burning", false) and not current_cell.get("burned", false) and inventory.availability(grid, player).available:
		target = player
		origin = player
		progress = 0.0
		action_kind = "plant_sapling"
		_interaction_kind = "plant_sapling"
		duration = 1.0
		return true

	# Priority 3: Facing sapling/seed (Harvest/clear crop with hoe)
	if front_cell != null and front_cell.get("tree", false) and front_cell.get("tree_state") in ["seed", "sapling"]:
		target = front
		origin = player
		progress = 0.0
		action_kind = "harvest_crop"
		_interaction_kind = "harvest_crop"
		duration = 0.8
		return true

	# Priority 4: Prepare eligible untilled soil underfoot before filling.
	if not current_cell.get("tree", false) \
			and not current_cell.get("log", false) \
			and not current_cell.get("berry_bush", false) \
			and int(current_cell.get("berries", 0)) <= 0 \
			and not current_cell.get("trash", false) \
			and not current_cell.get("burning", false) \
			and not current_cell.get("burned", false) \
			and not _is_water_cell(current_cell) \
			and not current_cell.get("tilled", false) \
			and not grid._protected_route(player) \
			and player != grid.objective \
			and player != grid.start \
			and not current_cell.get("spaceship", false) \
			and not current_cell.get("recycle_bin", false) \
			and player != grid.recycle_bin_cell:
		target = player
		origin = player
		progress = 0.0
		action_kind = "till_soil"
		_interaction_kind = "till_soil"
		duration = 0.8
		return true

	# Priority 5: Facing water source, after valid underfoot farming.
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

	return false

func tick(delta: float, player: Vector2i) -> Dictionary:
	if target.x < 0 or grid == null:
		return {}
	if player != origin:
		cancel()
		return {}
	var cell = grid.cells[target.y * grid.SIZE + target.x]
	if (action_kind in ["drink_water", "fill_water"] and not _is_water_cell(cell)) \
			or (action_kind == "till_soil" and (
				cell.get("tree", false) \
				or cell.get("log", false) \
				or cell.get("berry_bush", false) \
				or int(cell.get("berries", 0)) > 0 \
				or cell.get("trash", false) \
				or cell.get("burned", false) \
				or _is_water_cell(cell)
			)) \
			or cell.get("burning", false) \
			or (action_kind == "plant_sapling" and (cell.tree or seeds <= 0 or not cell.get("prepared", false))) \
			or (action_kind == "water_soil" and (water_ml < WATER_PER_POUR or cell.tree_state not in ["seed", "sapling"])) \
			or (action_kind == "harvest_crop" and (not cell.get("tree", false) or cell.get("tree_state", "") not in ["seed", "sapling"])) \
			or (action_kind == "collect_seeds" and (cell.get("pending_seeds", 0) <= 0 or seeds >= inventory.MAX_SEEDS)):
		cancel()
		return {}
	if action_kind in ["tree_cut", "sapling_removed", "log_cleared", "stump_removed"]:
		if action_kind != kind_for(cell):
			cancel()
			return {}
	if not is_finite(delta) or delta <= 0.0:
		return {}
	progress += delta
	if progress < maxf(duration, 0.01):
		return {}

	var event = {"cell": target, "direction": target - player, "kind": action_kind}

	if action_kind == "drink_water":
		event.kind = "drink_water"
	elif action_kind == "fill_water":
		var filled = mini(WATER_PER_FILL, MAX_WATER_ML - water_ml)
		water_ml = mini(MAX_WATER_ML, water_ml + WATER_PER_FILL)
		event["amount"] = filled
	elif action_kind == "till_soil":
		cell.terrain = "soil"
		cell.tilled = true
		cell.prepared = true
		cell.health = 0.9
		cell.trampled = 0.0
		if cell.get("berry_bush", false):
			cell.berry_bush = false
			cell.berries = 0
			cell.berry_regrowth = 0.0
	elif action_kind == "water_soil":
		if not inventory.water_crop(grid,target):
			cancel()
			return {}
		event.amount = WATER_PER_POUR
	elif action_kind == "plant_sapling":
		if not inventory.plant_seed(grid,target):
			cancel()
			return {}
	elif action_kind == "harvest_crop":
		cell.tree = false
		cell.tree_state = "removed"
		cell.tree_health = 0.0
		# Removing a crop never refunds a seed (natural/planted exploit prevention).
	elif action_kind == "collect_seeds":
		event.amount = inventory.collect_seed(grid, event)

	elif action_kind == "tree_cut":
		event.seed_eligible = cell.get("tree_state", "healthy") == "healthy" and cell.get("tree_health", 1.0) >= 0.66 and not cell.get("planted", false)
		cell.pending_seeds = cell.get("pending_seeds",0) + (3 if event.seed_eligible and not cell.get("seed_yield_claimed",false) else 0)
		cell.seed_yield_claimed = true
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
