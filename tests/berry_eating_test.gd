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

	# 2. Give berries to player
	survival.berry_count = 3
	survival.hunger = 50.0
	survival.thirst = 50.0

	# 3. Test eating on a NON-BERRY cell
	var non_berry_cell = Vector2i(8, 8)
	grid.cells[non_berry_cell.y * grid.SIZE + non_berry_cell.x].berry_bush = false
	player.cell = non_berry_cell
	player.position = grid.world_position(non_berry_cell)

	var eat_action = InputEventAction.new()
	eat_action.action = "eat"
	eat_action.pressed = true

	level._unhandled_input(eat_action)
	check(survival.berry_count == 3, "Cannot eat berries on a non-berry cell (count stays 3)")
	check(not player.is_eating, "Player does not start eating animation on non-berry cell")
	check(not berry_node.visible, "Berry does not appear on non-berry cell")

	# 4. Move to a BERRY cell and eat
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
	check(survival.berry_count == 2, "Eating on berry cell consumes 1 berry (3 -> 2)")
	check(survival.hunger > 50.0, "Hunger restored after eating")
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

	# 9. Test when reserves are full
	survival.hunger = 100.0
	survival.thirst = 100.0
	level._unhandled_input(eat_action)
	check(survival.berry_count == 2, "Cannot eat when food and water are full")
	check(not player.is_eating, "Player does not eat when full")

	# 10. Test when 0 berries
	survival.hunger = 50.0
	survival.berry_count = 0
	level._unhandled_input(eat_action)
	check(survival.berry_count == 0, "Cannot eat when berry count is 0")
	check(not player.is_eating, "Player does not eat with 0 berries")

	level.queue_free()
	await process_frame
	print("BERRY EATING TEST: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
