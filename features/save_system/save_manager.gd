extends Node

const VERSION = 1
var storage_path = "user://progression.json"
var run_path = "user://run.json"
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
	# Run restoration is deliberately unavailable until a real run schema and restorer exist.
	return false

func _read_json(path: String) -> Variant:
	var parser = JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path)) != OK:
		return null
	return parser.data
