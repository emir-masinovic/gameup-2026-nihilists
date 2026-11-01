extends SceneTree

var checks := 0
var failures := 0

func check(condition: bool, message: String):
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + message)
	else:
		print("PASS: " + message)

func _initialize():
	call_deferred("run")

func run():
	var LevelScene = load("res://features/levels/forest/forest_level.tscn")
	var level = LevelScene.instantiate()
	root.add_child(level)
	await process_frame
	await process_frame

	var player = level.get_node("GridPlayer")
	var body = player.get_node("Body")
	var survival = level.survival
	var grid = level.grid
	var hud = level.hud

	# 1. Verify Body and Audio nodes
	var berry_node = body.get_node_or_null("ArmRight/Berry")
	check(berry_node != null, "Body has ArmRight/Berry node")
	check(berry_node != null and not berry_node.visible, "Berry node starts hidden")
	var audio_node = body.get_node_or_null("EatingAudio")
	check(audio_node != null, "Body has EatingAudio node")
	check(audio_node != null and audio_node.stream != null, "EatingAudio has eating sound effect loaded")

	# 2. Give berries to player; hunger and thirst out of 10
	survival.berry_count = 5
	survival.hunger = 4.0
	survival.thirst = 5.0
	survival.health = 80.0

	# 3. Test eating on a NON-BERRY cell
	var non_berry_cell = Vector2i(8, 8)
	grid.cells[non_berry_cell.y * grid.SIZE + non_berry_cell.x].berry_bush = false
	player.cell = non_berry_cell
	player.position = grid.world_position(non_berry_cell)

	var eat_action = InputEventAction.new()
	eat_action.action = "eat"
	eat_action.pressed = true

	level._unhandled_input(eat_action)
	check(survival.berry_count == 5, "Cannot eat berries on a non-berry cell (count stays 5)")
	check(not player.is_eating, "Player does not start eating animation on non-berry cell")
	check(not berry_node.visible, "Berry does not appear on non-berry cell")

	# 4. Move to a BERRY cell and eat (+3 hunger)
	var berry_cell = Vector2i(6, 8)
	grid.cells[berry_cell.y * grid.SIZE + berry_cell.x].berry_bush = true
	player.cell = berry_cell
	player.position = grid.world_position(berry_cell)

	var signal_state = {"eat_cue": false, "audio_cue": false}
	player.eat_cue.connect(func(_pos): signal_state.eat_cue = true)
	level.audio_cue.connect(func(cue, _pos):
		if cue == "eat": signal_state.audio_cue = true
	)

	level._unhandled_input(eat_action)
	check(survival.berry_count == 4, "Eating on berry cell consumes 1 berry (5 -> 4)")
	check(is_equal_approx(survival.hunger, 7.0), "Hunger restored by exactly 3 units (4.0 -> 7.0)")
	check(survival.health == 80.0, "Health not increased when hunger and thirst not full (thirst=5.0)")
	check(player.is_eating, "Player enters eating state")
	check(berry_node.visible, "Berry appears in right hand at start of eating")

	# 5. Advance animation - check hand raising towards visor
	body._update_animation(0.2)
	check(body.is_eating, "Still eating at 0.2s")
	check(berry_node.visible, "Berry still in hand while raising to visor")
	check(body.get_node("ArmRight").rotation.x < -0.5, "Right arm raised towards visor")

	# 6. Advance animation to eating/munching phase (t >= 0.35s)
	body._update_animation(0.25) # total 0.45s
	check(signal_state.eat_cue, "Eat cue emitted when berry reaches mouth")
	check(signal_state.audio_cue, "Audio cue 'eat' emitted to sound system")

	# 7. Advance animation to berry consumed phase (t >= 0.55s)
	body._update_animation(0.2) # total 0.65s
	check(not berry_node.visible, "Berry disappeared after being eaten")

	# 8. Advance animation to completion
	body._update_animation(0.6) # total 1.25s
	check(not player.is_eating, "Eating animation completed and player returned to idle")
	check(not berry_node.visible, "Berry remains hidden after eating ends")

	# 9. Test healing: satisfy thirst to 10 and hunger to 10, then eat berry -> health +10
	survival.thirst = 10.0
	survival.hunger = 8.0
	survival.health = 80.0
	level._unhandled_input(eat_action)
	check(is_equal_approx(survival.hunger, 10.0), "Hunger reaches 10.0")
	check(is_equal_approx(survival.health, 90.0), "Reaching 10 on both hunger and thirst heals 10 health (80 -> 90)")
	body.stop_eating()

	# Eat again when hunger=10 and thirst=10 -> health heals again (+10 -> 100)
	level._unhandled_input(eat_action)
	check(is_equal_approx(survival.health, 100.0), "Eating with full reserves heals health to max 100")
	body.stop_eating()

	# 10. When hunger=10, thirst=10, health=100 -> cannot eat more
	var count_before = survival.berry_count
	level._unhandled_input(eat_action)
	check(survival.berry_count == count_before, "Cannot eat when hunger, thirst, and health are all full")
	check(not player.is_eating, "Player does not eat when fully satisfied")

	# 11. Test water drinking healing: hunger=10, thirst=8, health=85
	survival.health = 85.0
	survival.hunger = 10.0
	survival.thirst = 8.0
	var drank = survival.drink()
	check(drank and is_equal_approx(survival.thirst, 10.0), "Drinking brings thirst to 10.0")
	check(is_equal_approx(survival.health, 95.0), "Drinking with hunger=10 brings health +10 (85 -> 95)")

	# Drink again to cap health at 100
	drank = survival.drink()
	check(drank and is_equal_approx(survival.health, 100.0), "Drinking heals health capped at 100")

	# Cannot drink when health=100 and thirst=10
	drank = survival.drink()
	check(not drank, "Cannot drink when thirst=10 and health=100")

	# Cannot drink to heal if hunger < 10
	survival.health = 80.0
	survival.thirst = 10.0
	survival.hunger = 6.0
	drank = survival.drink()
	check(not drank, "Cannot drink to heal when hunger is not yet 10")
	check(survival.health == 80.0, "Health remains unchanged when hunger not satisfied")

	level.queue_free()
	await process_frame
	print("BERRY EATING TEST: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
