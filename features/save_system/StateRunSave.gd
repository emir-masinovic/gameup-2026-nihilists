extends RefCounted
# Object-free Variant data preserves Vector2i keys and 64-bit RNG states exactly.
const VERSION = 1
const Regions = preload("res://features/levels/forest/RunRegions.gd")
const SKIP = ["exposure","cells","_grid","grid","regeneration_occupied","growth_occupied"]
static func fields(model) -> Dictionary:
	var data = {}
	for property in model.get_script().get_script_property_list():
		var key: String = property.name
		if key in SKIP: continue
		var value = model.get(key)
		if value is RandomNumberGenerator: data[key] = {"rng_state":value.state}
		elif typeof(value) in [TYPE_BOOL,TYPE_INT,TYPE_FLOAT,TYPE_STRING,TYPE_STRING_NAME,TYPE_VECTOR2I,TYPE_VECTOR2,TYPE_VECTOR3,TYPE_ARRAY,TYPE_DICTIONARY]: data[key] = value.duplicate(true) if value is Array or value is Dictionary else value
	return data

static func safe(value, depth: int = 0) -> bool:
	if depth > 24: return false
	if value is float: return is_finite(value)
	if value is Vector2 or value is Vector3: return value.is_finite()
	if value is Array:
		if value.size() > 4096: return false
		for item in value:
			if not safe(item,depth+1): return false
		return true
	if value is Dictionary:
		if value.size() > 4096: return false
		for key in value:
			if not safe(key,depth+1) or not safe(value[key],depth+1): return false
		return true
	return typeof(value) in [TYPE_NIL,TYPE_BOOL,TYPE_INT,TYPE_STRING,TYPE_STRING_NAME,TYPE_VECTOR2I,TYPE_VECTOR2,TYPE_VECTOR3]

static func apply(model, data: Dictionary) -> bool:
	var defaults = fields(model)
	for key in data:
		if not defaults.has(key): return false
		if model.get(key) is RandomNumberGenerator:
			if not data[key] is Dictionary or not data[key].get("rng_state") is int: return false
		else:
			if typeof(data[key]) != typeof(defaults[key]): return false
			if defaults[key] is Dictionary:
				for field in defaults[key]:
					if not data[key].has(field) or typeof(data[key][field]) != typeof(defaults[key][field]): return false
			if key == "weather_cycle":
				if data[key].is_empty(): return false
				for weather in data[key]:
					if weather not in ["clear","rain","cool","heat"]: return false
	for key in data:
		if model.get(key) is RandomNumberGenerator: model.get(key).state = data[key].rng_state
		else: model.set(key,data[key])
	return true

static func capture(world, progression: Dictionary) -> Dictionary:
	var regions = world.regions
	var states = {}
	for id in regions.states:
		var state = regions.states[id]
		var meta = state.duplicate()
		for key in ["grid","climate","foraging"]: meta.erase(key)
		states[id] = {"meta":meta,"cells":state.grid.cells.duplicate(true),"climate":fields(state.climate)}
	return {"version":VERSION,"seed":regions.seed_for("forest"),"region":regions.current_id,"elapsed":regions.elapsed,"survival":fields(regions.survival),"planting":fields(regions.planting),"objectives":fields(regions.objectives),"states":states,"player":{"cell":world.get_node("GridPlayer").cell,"facing":world.get_node("GridPlayer").facing},"camera":world.get_node("CameraRig").get_transition_state(),"clock":world.presentation_elapsed,"progression":progression.duplicate(true),"extensions":{}}

static func restore(data):
	if not data is Dictionary or not safe(data) or data.get("version") != VERSION: return null
	if not data.get("seed") is int or data.seed < 0 or data.seed >= Regions.SEED_MODULUS: return null
	if not data.get("region") in Regions.IDS or not data.get("states") is Dictionary or not data.states.has(data.region): return null
	if not data.get("elapsed") is float or data.elapsed < 0 or not data.get("clock") is float or data.clock < 0: return null
	if not data.get("player") is Dictionary or not data.player.get("cell") is Vector2i or not data.player.get("facing") in [Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT]: return null
	if not data.get("camera") is Dictionary or not data.get("progression") is Dictionary: return null
	if data.camera.get("mode","") not in ["Follow Player","Board Center","Free Camera"]: return null
	for key in ["yaw","target_yaw","pitch","target_pitch","zoom","target_zoom"]:
		if not data.camera.get(key) is float or absf(data.camera[key]) > 100000: return null
	if not data.get("extensions",{}) is Dictionary: return null
	var run = Regions.new()
	run.configure(data.seed)
	for pair in [[run.survival,"survival"],[run.planting,"planting"],[run.objectives,"objectives"]]:
		if not data.get(pair[1]) is Dictionary or not apply(pair[0],data[pair[1]]): return null
	if run.survival.health <= 0 or run.survival.health > 100 or run.survival.dead or run.planting.seed_count < 0 or run.planting.seed_count > 9 or run.planting.water_ml < 0 or run.planting.water_ml > 1000: return null
	for key in ["wetness","hunger","thirst"]:
		if run.survival.get(key) < 0 or run.survival.get(key) > 100: return null
	if run.survival.body_temperature < 20 or run.survival.body_temperature > 50 or run.survival.berry_count < 0: return null
	for id in data.states:
		if not id in Regions.IDS: return null
		var saved = data.states[id]
		if not saved is Dictionary or not saved.get("cells") is Array or saved.cells.size() != 289 or not saved.get("climate") is Dictionary or not saved.get("meta") is Dictionary: return null
		var state = run.get_region(id)
		for i in range(289):
			var cell = saved.cells[i]
			if not cell is Dictionary: return null
			for key in state.grid.cells[i]:
				if not cell.has(key) or typeof(cell[key]) != typeof(state.grid.cells[i][key]): return null
			if not cell.tree_state in ["seed","sapling","healthy","dead","stump","removed"]: return null
			if not cell.get("pending_seeds",0) is int or cell.get("pending_seeds",0) < 0: return null
			if not (cell.get("growth_age",0.0) is float or cell.get("growth_age",0.0) is int) or cell.get("growth_age",0.0) < 0: return null
			for key in ["health","tree_health","moisture"]:
				if cell[key] < 0 or cell[key] > 1: return null
			if cell.get("terrain") not in ["grass","soil","water"]: return null
			if cell.has("log_direction") and not cell.log_direction is Vector2i: return null
		if not apply(state.climate,saved.climate): return null
		for key in saved.meta:
			if key in ["grid","climate","foraging"]: return null
			state[key] = saved.meta[key]
		if not state.get("cut_cells") is Dictionary or not state.get("last_updated") is float or not state.get("visited") is bool: return null
		for cell in state.cut_cells:
			if not cell is Vector2i or not state.grid.in_bounds(cell): return null
		state.grid.cells.assign(saved.cells)
	var active = run.states[data.region].grid
	var has_safe_tile = false
	for y in range(17):
		for x in range(17):
			if active.traversable(Vector2i(x,y)): has_safe_tile = true
	if not has_safe_tile: return null
	run.presentation_time = data.clock
	run.elapsed = data.elapsed
	run.current_id = data.region
	return run
