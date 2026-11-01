extends SceneTree

var checks := 0
var failures := 0

func check(condition: bool, description: String) -> void:
	checks += 1
	if condition:
		print("PASS: ", description)
	else:
		failures += 1
		push_error("FAIL: " + description)

func _init() -> void:
	call_deferred("run")

func run() -> void:
	print("--- Running Health Regeneration Tests ---")

	var SurvivalState = load("res://features/player/survival_state.gd")
	var ForestLevelScene = load("res://features/levels/forest/forest_level.tscn")

	# 1. Test 8/10 reserves: Regen rate must be 2.0/s
	print("\n[1] Testing 8/10 reserves (Health +2 per second)...")
	var s = SurvivalState.new()
	s.hunger = 8.0
	s.thirst = 8.0
	s.health = 50.0
	check(s.get_health_regen_rate() == 2.0, "Regen rate at 8/10 is exactly 2.0/s")
	s.tick(1.0, 24.0, 1.0, false, false)
	check(is_equal_approx(s.health, 52.0), "Health increased by 2 after 1.0s (50.0 -> 52.0, got %f)" % s.health)

	# 2. Test 9/10 reserves: Regen rate must be 4.0/s
	print("\n[2] Testing 9/10 reserves (Health +4 per second)...")
	s = SurvivalState.new()
	s.hunger = 9.0
	s.thirst = 9.0
	s.health = 50.0
	check(s.get_health_regen_rate() == 4.0, "Regen rate at 9/10 is exactly 4.0/s")
	s.tick(1.0, 24.0, 1.0, false, false)
	check(is_equal_approx(s.health, 54.0), "Health increased by 4 after 1.0s (50.0 -> 54.0, got %f)" % s.health)

	# 3. Test 10/10 reserves: Regen rate must be 5.0/s
	print("\n[3] Testing 10/10 reserves (Health +5 per second)...")
	s = SurvivalState.new()
	s.hunger = 10.0
	s.thirst = 10.0
	s.health = 50.0
	check(s.get_health_regen_rate() == 5.0, "Regen rate at 10/10 is exactly 5.0/s")
	s.tick(1.0, 24.0, 1.0, false, false)
	check(is_equal_approx(s.health, 55.0), "Health increased by 5 after 1.0s (50.0 -> 55.0, got %f)" % s.health)

	# 4. Asymmetric reserves (bottlenecked by minimum reserve)
	print("\n[4] Testing asymmetric reserves (Limited by the lower of hunger/thirst)...")
	s = SurvivalState.new()
	s.hunger = 10.0
	s.thirst = 8.0
	check(s.get_health_regen_rate() == 2.0, "Hunger=10, Thirst=8 gives regen rate 2.0")

	s.hunger = 8.0
	s.thirst = 10.0
	check(s.get_health_regen_rate() == 2.0, "Hunger=8, Thirst=10 gives regen rate 2.0")

	s.hunger = 10.0
	s.thirst = 9.0
	check(s.get_health_regen_rate() == 4.0, "Hunger=10, Thirst=9 gives regen rate 4.0")

	s.hunger = 9.0
	s.thirst = 10.0
	check(s.get_health_regen_rate() == 4.0, "Hunger=9, Thirst=10 gives regen rate 4.0")

	# 5. Below 8/10: No regeneration
	print("\n[5] Testing reserves below 8/10 (No health regeneration)...")
	s.hunger = 7.0
	s.thirst = 10.0
	check(s.get_health_regen_rate() == 0.0, "Hunger=7, Thirst=10 gives regen rate 0.0")

	s.hunger = 6.0
	s.thirst = 6.0
	s.health = 50.0
	check(s.get_health_regen_rate() == 0.0, "Hunger=6, Thirst=6 gives regen rate 0.0")
	s.tick(1.0, 24.0, 1.0, false, false)
	check(s.health == 50.0, "Health does not increase when reserves are below 8/10")

	# 6. Health capping at 100
	print("\n[6] Testing Health Cap at 100.0...")
	s.hunger = 10.0
	s.thirst = 10.0
	s.health = 98.0
	s.tick(1.0, 24.0, 1.0, false, false)
	check(s.health == 100.0, "Health caps at exactly 100.0 (does not exceed)")
	s.tick(1.0, 24.0, 1.0, false, false)
	check(s.health == 100.0, "Health remains at 100.0 on subsequent ticks")

	# 7. Dead player cannot regenerate
	print("\n[7] Testing Dead Player...")
	s.dead = true
	check(s.get_health_regen_rate() == 0.0, "Dead player has 0.0 regen rate")

	# 8. Level simulation & Floating +5 Popup
	print("\n[8] Testing Level World simulation & Floating +5 Popup...")
	var world = ForestLevelScene.instantiate()
	root.add_child(world)
	await process_frame

	world.survival.hunger = 10.0
	world.survival.thirst = 10.0
	world.survival.health = 70.0
	var health_before = world.survival.health

	# Run a 1.0s simulation tick in world
	world.tick_accumulator = 1.0
	world._process(0.0)

	check(world.survival.health > health_before, "World tick regenerated health (70.0 -> %f)" % world.survival.health)
	
	# Verify that a popup was created with "+5" and green color
	var popups = []
	for child in world.get_children():
		if child.name.begins_with("HealthPopup"):
			popups.append(child)
	check(popups.size() > 0, "Floating health popup was created on health increase")
	if popups.size() > 0:
		var popup = popups[0]
		var label: Label3D = popup.get_node("Amount")
		check(label.text == "+5", "Health popup displays '+5' (got '%s')" % label.text)
		check(label.modulate == Color("4ebd5f"), "Health popup is green")
		check(popup.has_node("Icon"), "Health popup has icon")

	world.queue_free()

	print("\n--- Summary: %d checks passed, %d failures ---" % [checks - failures, failures])
	if failures > 0:
		print("FAILED with %d errors" % failures)
		quit(1)
	else:
		print("ALL HEALTH REGEN TESTS PASSED!")
		quit(0)
