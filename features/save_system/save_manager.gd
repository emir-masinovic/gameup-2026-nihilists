extends Node

const VERSION = 1
const UPGRADE_COSTS = {"heat_resistance": 3, "quick_chop": 2, "fire_resilience": 2}
var storage_path = "user://progression.json"
var run_path = "user://session.save"
var run_extensions: Dictionary = {}
var progression = {"discoveries": [], "knowledge": 0, "upgrades": []}
func _ready():
	load_progression()

func _valid_progression(data: Variant) -> bool:
	if not data is Dictionary:
		return false
	if not data.get("discoveries") is Array or not data.get("upgrades") is Array:
		return false
	var knowledge = data.get("knowledge", -1)
	if not (knowledge is int or knowledge is float) or not is_finite(float(knowledge)) or knowledge < 0 or floor(knowledge) != knowledge:
		return false
	for field in ["discoveries", "upgrades"]:
		for entry in data[field]:
			if not entry is String:
				return false
	return true

func load_progression() -> bool:
	progression = {"discoveries": [], "knowledge": 0, "upgrades": []}
	if not FileAccess.file_exists(storage_path):
		return false
	var data = _read_json(storage_path)
	if not data is Dictionary or data.get("version") != VERSION or not _valid_progression(data.get("progression")):
		return false
	progression = data.progression.duplicate(true)
	return true

func save_progression(data: Dictionary) -> Error:
	if not _valid_progression(data):
		return ERR_INVALID_DATA
	var temp_path = storage_path + ".tmp"
	var file = FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify({"version": VERSION, "progression": data}))
	file.close()
	var error = DirAccess.rename_absolute(temp_path, storage_path)
	if error == OK:
		progression = data.duplicate(true)
	return error

func has_resumable_run() -> bool:
	return read_run() != null

func _read_json(path: String) -> Variant:
	var parser = JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path)) != OK:
		return null
	return parser.data

func discover(id: String) -> bool:
	if id.strip_edges().is_empty() or id in progression.discoveries:
		return false
	var updated = progression.duplicate(true)
	updated.discoveries.append(id)
	updated.knowledge += 1
	return save_progression(updated) == OK

func has_upgrade(id: String) -> bool:
	return id in progression.upgrades

func upgrade_cost(id: String) -> int:
	return UPGRADE_COSTS.get(id, -1)

func purchase_upgrade(id: String) -> bool:
	var cost = upgrade_cost(id)
	if cost < 0 or has_upgrade(id) or progression.knowledge < cost:
		return false
	var updated = progression.duplicate(true)
	updated.knowledge -= cost
	updated.upgrades.append(id)
	return save_progression(updated) == OK

func has_heat_resistance() -> bool:
	return has_upgrade("heat_resistance")

func purchase_heat_resistance() -> bool:
	return purchase_upgrade("heat_resistance")

func get_chop_multiplier() -> float:
	return 0.65 if has_upgrade("quick_chop") else 1.0

func get_fire_damage_multiplier() -> float:
	return 0.6 if has_upgrade("fire_resilience") else 1.0

# Explicit fresh-game reset; atomic save preserves the old state on write failure.
func reset_progression() -> Error:
	return save_progression({"discoveries":[],"knowledge":0,"upgrades":[]})

const RunSave = preload("res://features/save_system/StateRunSave.gd")
func save_run(world) -> Error:
	var data = RunSave.capture(world,progression)
	for id in run_extensions: data.extensions[id] = run_extensions[id].capture.call(world)
	if RunSave.restore(data) == null or not _valid_progression(data.progression): return ERR_INVALID_DATA
	var temp = run_path+".tmp"
	var file = FileAccess.open(temp,FileAccess.WRITE)
	if file == null: return FileAccess.get_open_error()
	file.store_var(data,false)
	file.flush()
	file.close()
	return DirAccess.rename_absolute(temp,run_path)

func read_run():
	if not FileAccess.file_exists(run_path): return null
	var file = FileAccess.open(run_path,FileAccess.READ)
	if file == null or file.get_length() > 4194304 or file.get_length() < 8: return null
	var data = file.get_var(false)
	file.close()
	if not data is Dictionary or not _valid_progression(data.get("progression")) or RunSave.restore(data) == null: return null
	for id in data.get("extensions",{}):
		if not run_extensions.has(id): return null
	return data

# Code-owned callbacks only: save contents never name scripts or executable objects.
func register_run_extension(id: String, capture: Callable, restore: Callable) -> bool:
	if id.is_empty() or run_extensions.has(id) or not capture.is_valid() or not restore.is_valid(): return false
	run_extensions[id] = {"capture":capture,"restore":restore}
	return true

func restore_extensions(run, fields: Dictionary) -> bool:
	for id in fields:
		if not run_extensions.has(id): return false # Required feature unavailable.
		if run_extensions[id].restore.call(run,fields[id]) != true: return false
	return true
