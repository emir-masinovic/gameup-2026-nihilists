extends RefCounted

# Only logical models live here. Scene geometry is rebuilt for the active region.
const GridData = preload("res://features/levels/forest/grid_data.gd")
const Climate = preload("res://features/levels/forest/climate_simulation.gd")
const Survival = preload("res://features/player/survival_state.gd")
const Objectives = preload("res://features/levels/forest/run_objectives.gd")
const IDS = ["forest", "drylands", "wetlands"]
const MAX_CATCHUP_SECONDS = 30.0
const SEED_MODULUS = 2147483647

var current_id = "forest"
var states: Dictionary = {}
var survival = Survival.new()
var objectives = Objectives.new()
var elapsed = 0.0
var _run_seed = 2026

func configure(run_seed: int) -> void:
	_run_seed = run_seed
	current_id = "forest"
	states.clear()
	survival = Survival.new()
	objectives = Objectives.new()
	elapsed = 0.0

func seed_for(id: String) -> int:
	if id == "forest":
		return _run_seed
	var offset = 104729 if id == "drylands" else 209458 if id == "wetlands" else 0
	return posmod(posmod(_run_seed, SEED_MODULUS) + offset, SEED_MODULUS)

func get_region(id: String) -> Dictionary:
	if not IDS.has(id):
		return {}
	if states.has(id):
		return states[id]
	var grid = GridData.new()
	var climate = Climate.new()
	var seed_value = seed_for(id)
	grid.generate(seed_value)
	# Set the instance baseline before configure computes its first temperature.
	if id == "drylands":
		climate.baseline_temperature += 3.0
	elif id == "wetlands":
		climate.baseline_temperature -= 2.0
	climate.configure(grid, seed_value)
	for data in grid.cells:
		if id == "drylands":
			data.moisture *= 0.55
			data.tree_health *= 0.8
			data.health *= 0.6
		elif id == "wetlands":
			data.moisture = minf(1.0, data.moisture + 0.15)
	# A previously stressed patch recovers through the real moisture/health model.
	if id == "wetlands":
		var habitat: Dictionary = grid.cells[5 * grid.SIZE + 8]
		habitat.health = 0.45
		habitat.recovery_low = 0.45
		habitat.moisture = maxf(habitat.moisture, 0.7)
		habitat.terrain = "grass"
		habitat.tree = false
		habitat.tree_health = 0.0
		habitat.tree_state = "removed"
	var state = {"grid": grid, "climate": climate, "cut_cells": {},
		"visited": false, "last_updated": elapsed}
	states[id] = state
	return state

func entry(id: String, from_id: String) -> Vector2i:
	if id == "drylands" and from_id == "forest":
		return Vector2i(15, 8)
	if id == "wetlands" and from_id == "forest":
		return Vector2i(1, 8)
	if id == "forest" and from_id == "drylands":
		return Vector2i(1, 8)
	if id == "forest" and from_id == "wetlands":
		return Vector2i(15, 8)
	return Vector2i(8, 8)

func exit_destination(id: String, cell: Vector2i) -> String:
	if cell == Vector2i(0, 8):
		if id == "forest":
			return "drylands"
		if id == "wetlands":
			return "forest"
	elif cell == Vector2i(16, 8):
		if id == "forest":
			return "wetlands"
		if id == "drylands":
			return "forest"
	return ""

# The level ticks the active climate, then advances this run clock. There is no
# wall-clock source, timer, survival damage, or inactive simulation in the cache.
func advance(seconds: float) -> void:
	if not is_finite(seconds) or seconds <= 0.0:
		return
	var next_elapsed = elapsed + seconds
	if not is_finite(next_elapsed):
		return
	elapsed = next_elapsed
	if states.has(current_id):
		states[current_id].last_updated = elapsed

func enter(id: String) -> Dictionary:
	var state = get_region(id)
	if state.is_empty():
		return state
	if id != current_id:
		var remaining = clampf(elapsed - float(state.last_updated), 0.0, MAX_CATCHUP_SECONDS)
		while remaining > 0.0:
			var step = minf(remaining, 1.0)
			state.climate.tick(step)
			remaining -= step
	# Discard work beyond the cap instead of charging it again on the next visit.
	state.last_updated = elapsed
	state.visited = true
	current_id = id
	return state

func region_name(id: String) -> String:
	return {"forest": "Forest", "drylands": "Drylands", "wetlands": "Wetlands"}.get(id, "Unknown region")

# The renderer still interpolates these by actual cell health and moisture.
func palette_for(id: String) -> Dictionary:
	if id == "drylands":
		return {"soil": Color("9b7550"), "dry_green": Color("657041"), "wet_green": Color("82914f")}
	if id == "wetlands":
		return {"soil": Color("635944"), "dry_green": Color("315f47"), "wet_green": Color("4e8964")}
	return {"soil": Color("80684a"), "dry_green": Color("315f3c"), "wet_green": Color("5c894a")}
