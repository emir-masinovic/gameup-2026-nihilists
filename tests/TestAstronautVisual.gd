extends SceneTree
var failures = 0
func check(value: bool, message: String):
	if not value:
		failures += 1
		push_error(message)
func _initialize():
	call_deferred("run")
func run():
	var grid = preload("res://features/levels/forest/grid_data.gd").new()
	grid.generate(2026)
	var player = preload("res://features/player/grid_player.tscn").instantiate()
	root.add_child(player)
	player.configure(grid)
	player.set_process(false)
	var body = player.get_node("Body")
	body.set_process(false)
	var origin: Vector2i = player.cell
	check(player.try_move(Vector2i.UP), "Existing controller accepts grid step")
	body._update_animation(0.04)
	check(body.position.y > 0.05, "Onur hop animates only visual child")
	check(player.cell == origin + Vector2i.UP, "Logical step remains one cell")
	check(absf(body.get_node("LegLeft").rotation.x) > 0.1, "Walking swings limbs")
	check(is_equal_approx(body.step_duration, 0.16), "Visual timing follows existing 0.16-second step")
	await create_timer(0.2).timeout
	check(not player.moving, "Existing movement tween completes")
	body.start_chopping(player.global_position + Vector3(2,0,0))
	body._update_animation(0.2)
	check(body.get_node("ArmRight/Axe").visible and body.is_chopping, "Chop visual exposes axe")
	check(player.cell == origin + Vector2i.UP, "Chopping visual cannot move player")
	body.stop_chopping()
	body._update_animation(1.0 / 12.0)
	check(is_zero_approx(body.get_node("ArmRight").rotation.y), "Idle restores arm twist after chopping")
	check(not body.get_node("ArmRight/Axe").visible, "Cancelled/completed chop hides axe")
	for action in ["tilling","filling_water","watering","gathering"]:
		body.call("start_"+action,player.global_position + Vector3(2,0,0))
		body._update_animation(0.2)
		check(body.get("is_"+action), "Visual-only farming pose starts: "+action)
		check(player.cell == origin + Vector2i.UP, "Farming pose never changes logical cell")
		body.stop_farming()
		check(not body.get_node("ArmRight/Hoe").visible and not body.get_node("ArmRight/Bottle").visible, "Stopping action hides farming tools")
	player.queue_free()
	await process_frame
	print("ASTRONAUT VISUAL: hop, limbs, turn, chop and unchanged grid controller; failures=", failures)
	quit(failures)
