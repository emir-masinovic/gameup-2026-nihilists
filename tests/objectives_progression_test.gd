extends SceneTree

const SAVE_SCRIPT = preload("res://features/save_system/save_manager.gd")
const OBJECTIVES_SCRIPT = preload("res://features/levels/forest/run_objectives.gd")
const INTERACTIONS_SCRIPT = preload("res://features/levels/forest/forest_interactions.gd")
const GRID_SCRIPT = preload("res://features/levels/forest/grid_data.gd")
const TEST_PATH = "user://objectives_progression_test.json"
var failures = 0
var checks = 0

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func clean_files() -> void:
	for path in [TEST_PATH, TEST_PATH + ".tmp"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)

func empty_grid() -> RefCounted:
	var grid = GRID_SCRIPT.new()
	grid.generate(2026)
	for cell in grid.cells:
		cell.tree = false
		cell.tree_state = "removed"
		cell.tree_health = 0.0
		cell.log = false
		cell.fuel = 0.4
		cell.terrain = "grass"
		cell.water_level = 0.0
		cell.burning = false
		cell.burned = false
	return grid

func add_tree(grid: RefCounted, position: Vector2i) -> void:
	var cell = grid.cells[position.y * grid.SIZE + position.x]
	cell.tree = true
	cell.tree_state = "healthy"
	cell.tree_health = 1.0
	cell.fuel = 1.0

func run() -> void:
	clean_files()
	var saves = SAVE_SCRIPT.new()
	saves.storage_path = TEST_PATH
	check(saves.get_chop_multiplier() == 1.0 and saves.get_fire_damage_multiplier() == 1.0, "Unowned upgrades have no effect")
	check(saves.upgrade_cost("quick_chop") == 2 and saves.upgrade_cost("fire_resilience") == 2 and saves.upgrade_cost("heat_resistance") == 3, "All upgrade costs fit seven discoveries")
	check(saves.upgrade_cost("unknown") == -1 and not saves.purchase_upgrade("unknown"), "Unknown upgrade cannot consume currency")
	check(not saves.purchase_upgrade("quick_chop"), "Insufficient currency cannot buy faster chopping")
	for index in range(7):
		check(saves.discover("test.discovery.%d" % index), "Unique discovery awards persistent Knowledge")
	check(not saves.discover("test.discovery.0") and saves.progression.knowledge == 7, "Duplicate discovery cannot farm Knowledge")
	check(saves.purchase_upgrade("quick_chop"), "Faster chopping purchases for two Knowledge")
	check(is_equal_approx(saves.get_chop_multiplier(), 0.65) and saves.progression.knowledge == 5, "Chop upgrade changes duration by thirty-five percent")
	check(not saves.purchase_upgrade("quick_chop") and saves.progression.knowledge == 5, "Duplicate purchase preserves currency")
	check(saves.purchase_upgrade("fire_resilience") and is_equal_approx(saves.get_fire_damage_multiplier(), 0.6), "Fire upgrade reduces fire damage by forty percent")
	check(saves.purchase_heat_resistance() and saves.has_heat_resistance() and saves.progression.knowledge == 0, "Legacy heat API and all three purchases share the same balance")
	var loaded = SAVE_SCRIPT.new()
	loaded.storage_path = TEST_PATH
	check(loaded.load_progression() and loaded.has_upgrade("quick_chop") and loaded.has_upgrade("fire_resilience") and loaded.has_heat_resistance(), "All three upgrades survive restart in version one")
	var legacy = {"version": 1, "progression": {"discoveries": ["plant.tree"], "knowledge": 4, "upgrades": ["heat_resistance"]}}
	var file = FileAccess.open(TEST_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(legacy))
	file.close()
	check(loaded.load_progression() and loaded.has_heat_resistance() and loaded.progression.knowledge == 4, "Original version-one save loads without losing balance or upgrade")
	check(not loaded.discover("plant.tree") and loaded.progression.knowledge == 4, "Legacy discovery stays unique")
	var persisted = FileAccess.get_file_as_string(TEST_PATH)
	var before = loaded.progression.duplicate(true)
	loaded.storage_path = TEST_PATH + "/blocked.json"
	check(not loaded.purchase_upgrade("quick_chop") and not loaded.purchase_upgrade("fire_resilience"), "Failed writes reject both new upgrades")
	check(loaded.progression == before and loaded.get_chop_multiplier() == 1.0 and loaded.get_fire_damage_multiplier() == 1.0, "Failed purchase changes neither balance nor modifiers")
	check(FileAccess.get_file_as_string(TEST_PATH) == persisted, "Failed purchase preserves previous save")
	loaded.storage_path = TEST_PATH
	check(loaded.purchase_upgrade("quick_chop") and loaded.purchase_upgrade("fire_resilience") and loaded.progression.knowledge == 0, "Legacy save can purchase new upgrades")

	var objectives = OBJECTIVES_SCRIPT.new()
	check(not objectives.ready_for_clearing(), "New attempt cannot immediately finish")
	check(not objectives.record_mitigation() and not objectives.observe_recovery(), "Out-of-order evidence cannot skip surveying")
	check(objectives.observe_problem() and not objectives.observe_problem(), "Survey registers once")
	check(not objectives.observe_recovery() and not objectives.ready_for_clearing(), "Recovery alone cannot skip mitigation")
	check(objectives.record_mitigation() and not objectives.record_mitigation(), "Firebreak mitigation registers once after survey")
	check(objectives.observe_recovery() and not objectives.observe_recovery(), "Recovery registers once after mitigation")
	check(objectives.ready_for_clearing() and "clearing" in objectives.summary(), "Evidence immediately unlocks return without a timer")
	check(not OBJECTIVES_SCRIPT.new().problem_seen, "Next attempt resets environmental evidence")

	var grid = empty_grid()
	var interaction = INTERACTIONS_SCRIPT.new()
	interaction.configure(grid)
	var player = Vector2i(2, 3)
	var tree = Vector2i(3, 3)
	var landing = Vector2i(4, 3)
	add_tree(grid, tree)
	interaction.duration = 1.2 * loaded.get_chop_multiplier()
	check(interaction.begin(player, Vector2i.RIGHT), "Adjacent tree starts chopping")
	check(interaction.tick(0.5, player).is_empty(), "Chop requires its upgraded duration")
	var cut = interaction.tick(0.29, player)
	check(cut.get("kind") == "tree_cut" and cut.get("landing") == landing, "Quick chop completes before ordinary 1.2 seconds and predicts landing")
	check(grid.traversable(tree) and grid.cells[tree.y * grid.SIZE + tree.x].fuel == 0.0, "Cut leaves a traversable, fuel-free stump")
	check(grid.cells[landing.y * grid.SIZE + landing.x].log and not grid.traversable(landing), "Fallen log blocks the predictable landing cell")
	check(interaction.begin(player, Vector2i.RIGHT) and interaction.tick(2.0, player).get("kind") == "stump_removed", "Second action removes stump")
	check(grid.traversable(tree) and grid.cells[tree.y * grid.SIZE + tree.x].fuel == 0.0, "Stump removal opens a fuel-free firebreak cell")
	check(interaction.begin(tree, Vector2i.RIGHT), "Adjacent fallen log can be cleared")
	check(interaction.tick(0.2, tree).is_empty() and interaction.tick(2.0, tree + Vector2i.DOWN).is_empty(), "Movement cancels log clearing")
	check(grid.cells[landing.y * grid.SIZE + landing.x].log, "Cancelled clearing leaves log intact")
	check(interaction.begin(tree, Vector2i.RIGHT) and interaction.tick(2.0, tree).get("kind") == "log_cleared", "Completed log clearing emits its distinct event")
	check(grid.traversable(landing) and grid.cells[landing.y * grid.SIZE + landing.x].fuel == 0.0, "Cleared log restores passability and removes fuel")

	grid = empty_grid()
	interaction.configure(grid)
	player = grid.start
	tree = player + Vector2i.RIGHT
	add_tree(grid, tree)
	check(interaction.begin(player, Vector2i.RIGHT), "Safe-area tree interaction remains available")
	cut = interaction.tick(2.0, player)
	check(not cut.has("landing") and not grid.cells[(tree.y * grid.SIZE) + tree.x + 1].log, "Fallen logs cannot obstruct bonfire safe area")
	grid = empty_grid()
	interaction.configure(grid)
	player = Vector2i(2, 3)
	tree = Vector2i(3, 3)
	landing = Vector2i(4, 3)
	add_tree(grid, tree)
	add_tree(grid, landing)
	check(interaction.begin(player, Vector2i.RIGHT), "Tree with occupied landing can still be chopped")
	cut = interaction.tick(2.0, player)
	check(not cut.has("landing") and not grid.cells[landing.y * grid.SIZE + landing.x].log, "Occupied landing never gains a log")
	grid = empty_grid()
	interaction.configure(grid)
	add_tree(grid, tree)
	grid.cells[tree.y * grid.SIZE + tree.x].burning = true
	check(not interaction.begin(player, Vector2i.RIGHT), "Burning tree cannot be chopped")
	grid.cells[tree.y * grid.SIZE + tree.x].burning = false
	check(interaction.begin(player, Vector2i.RIGHT), "Extinguished tree can be worked")
	grid.cells[tree.y * grid.SIZE + tree.x].burning = true
	check(interaction.tick(2.0, player).is_empty() and interaction.target.x < 0, "Ignition cancels an active chop")

	clean_files()
	saves.free()
	loaded.free()
	print("OBJECTIVES_PROGRESSION: ", checks, " checks, ", failures, " failures")
	quit(0 if failures == 0 else 1)
