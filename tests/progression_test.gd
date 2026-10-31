extends SceneTree

const SAVE_SCRIPT = preload("res://features/save_system/save_manager.gd")
const SURVIVAL_SCRIPT = preload("res://features/player/survival_state.gd")
const TEST_PATH = "user://progression_gameplay_test.json"
var failures = 0
var checks = 0

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	for path in [TEST_PATH, TEST_PATH + ".tmp"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	var saves = SAVE_SCRIPT.new()
	saves.storage_path = TEST_PATH
	check(not saves.load_progression() and saves.progression.knowledge == 0, "Missing file loads zero Knowledge")
	check(not saves.has_resumable_run(), "Progression does not create a resumable run")
	check(not saves.purchase_heat_resistance(), "Upgrade requires three Knowledge")
	check(not saves.discover("  "), "Empty discovery rejected")
	check(saves.discover("plant.tree"), "First discovery persists")
	check(not saves.discover("plant.tree") and saves.progression.knowledge == 1, "Duplicate gives no Knowledge")
	var reloaded = SAVE_SCRIPT.new()
	reloaded.storage_path = TEST_PATH
	check(reloaded.load_progression(), "New manager loads saved discoveries")
	check(not reloaded.discover("plant.tree") and reloaded.progression.knowledge == 1, "Duplicate remains blocked after reload")
	check(reloaded.discover("event.heat") and reloaded.discover("place.bonfire"), "Three discoveries give three Knowledge")
	check(reloaded.purchase_heat_resistance(), "Upgrade persists at cost three")
	check(reloaded.has_heat_resistance() and reloaded.progression.knowledge == 0, "Upgrade spends exact cost")
	check(not reloaded.purchase_heat_resistance(), "Upgrade cannot be bought twice")
	check(saves.load_progression() and saves.has_heat_resistance() and saves.progression.knowledge == 0, "Upgrade survives reload")
	check(saves.progression.discoveries.size() == 3, "Upgrade preserves discoveries")
	check(saves.discover("plant.shrub") and saves.progression.knowledge == 1, "Knowledge can be earned after purchase")
	var persisted = FileAccess.get_file_as_string(TEST_PATH)
	var snapshot = saves.progression.duplicate(true)
	# A file cannot act as a parent directory, guaranteeing an open failure.
	saves.storage_path = TEST_PATH + "/blocked.json"
	check(not saves.discover("failed.discovery"), "Failed write is not a discovery")
	check(saves.progression == snapshot, "Failed discovery leaves memory unchanged")
	check(FileAccess.get_file_as_string(TEST_PATH) == persisted, "Failed discovery preserves disk")
	var failed_purchase = SAVE_SCRIPT.new()
	failed_purchase.storage_path = saves.storage_path
	failed_purchase.progression = {"discoveries": ["a", "b", "c"], "knowledge": 3, "upgrades": []}
	check(not failed_purchase.purchase_heat_resistance(), "Failed purchase reports failure")
	check(failed_purchase.progression.knowledge == 3 and not failed_purchase.has_heat_resistance(), "Failed purchase retains currency and upgrade state")
	saves.storage_path = TEST_PATH
	for invalid in ["not json", '{"version":99,"progression":{"discoveries":[],"knowledge":5,"upgrades":[]}}', '{"version":1,"progression":{"discoveries":[],"knowledge":-1,"upgrades":[]}}']:
		var file = FileAccess.open(TEST_PATH, FileAccess.WRITE)
		file.store_string(invalid)
		file.close()
		check(not saves.load_progression(), "Invalid file is rejected")
		check(saves.progression == {"discoveries": [], "knowledge": 0, "upgrades": []}, "Invalid file loads safe defaults")
		check(FileAccess.get_file_as_string(TEST_PATH) == invalid, "Loading invalid file does not overwrite it")
	var ordinary = SURVIVAL_SCRIPT.new()
	var resistant = SURVIVAL_SCRIPT.new()
	ordinary.tick(15.0, 50.0, 0.0, false, false)
	resistant.tick(15.0, 50.0, 0.0, false, true)
	check(ordinary.exposure > 0.0 and ordinary.health == 100.0, "Heat accumulates gradually before damage")
	check(resistant.exposure < ordinary.exposure, "Upgrade reduces heat accumulation")
	var shaded = SURVIVAL_SCRIPT.new()
	shaded.tick(15.0, 50.0, 1.0, false, false)
	check(shaded.exposure < ordinary.exposure, "Shade protects against heat")
	for second in range(130):
		ordinary.tick(1.0, 50.0, 0.0, false, false)
	check(ordinary.health < 100.0 and not ordinary.dead, "Sustained overheating damages a living player after a warning period")
	var before_rest = ordinary.health
	ordinary.tick(5.0, 50.0, 0.0, true, false)
	check(ordinary.health > before_rest and ordinary.exposure < 60.0, "Safe bonfire cools and restores health")
	ordinary.tick(100.0, 50.0, 0.0, true, false)
	check(ordinary.health == 100.0 and ordinary.exposure == 0.0, "Recovery clamps at full health and no exposure")
	ordinary.exposure = 50.0
	ordinary.tick(5.0, 20.0, 0.0, false, false)
	check(ordinary.exposure < 50.0, "Cool weather reduces exposure")
	for second in range(300):
		ordinary.tick(1.0, 50.0, 0.0, false, false)
	check(ordinary.dead and ordinary.health == 0.0, "Prolonged heat causes death")
	ordinary.tick(300.0, 20.0, 1.0, true, true)
	check(ordinary.dead and ordinary.health == 0.0, "Safe area cannot resurrect dead run")
	var ramp_run = SURVIVAL_SCRIPT.new()
	var ramp_resistant = SURVIVAL_SCRIPT.new()
	for elapsed in range(480):
		var temperature = 24.0 + float(elapsed) * 0.025
		ramp_run.tick(1.0, temperature, 0.0, false, false)
		ramp_resistant.tick(1.0, temperature, 0.0, false, true)
	check(ramp_run.body_temperature > 37.0, "Unshaded climate ramp creates gradual thermal pressure")
	check(ramp_resistant.body_temperature < ramp_run.body_temperature, "Resistance reduces body warming during the same climate ramp")
	var next_run = SURVIVAL_SCRIPT.new()
	check(not next_run.dead and next_run.health == 100.0 and next_run.exposure == 0.0, "New survival instance starts healthy")
	next_run.tick(-1.0, 50.0, 0.0, false, false)
	check(next_run.health == 100.0 and next_run.exposure == 0.0, "Negative time cannot mutate survival")
	for path in [TEST_PATH, TEST_PATH + ".tmp"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	saves.free()
	reloaded.free()
	failed_purchase.free()
	print("PROGRESSION: ", checks, " checks, ", failures, " failures")
	quit(0 if failures == 0 else 1)
