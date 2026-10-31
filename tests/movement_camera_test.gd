extends SceneTree

var checks = 0
var failures = 0
const CARDINALS = [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]

func check(value: bool, message: String):
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func _initialize():
	call_deferred("run")

func orient(camera: Camera3D, yaw: float, pitch: float):
	camera.basis = Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, -pitch)
	camera.position = camera.basis.z * 60.0

func run():
	var stage = Node3D.new()
	root.add_child(stage)
	var camera = Camera3D.new()
	stage.add_child(camera)
	camera.current = true
	camera.size = 42.0
	camera.fov = 55.0
	var grid = load("res://features/levels/forest/grid_data.gd").new()
	grid.generate(2026)
	var player = load("res://features/player/grid_player.gd").new()
	var body = Node3D.new()
	body.name = "Body"
	player.add_child(body)
	stage.add_child(player)
	player.configure(grid)
	player.set_process(false)
	await process_frame
	var entered: Array[Vector2i] = []
	player.cell_entered.connect(func(value: Vector2i): entered.append(value))
	# Score independently from real camera projection, including positions away
	# from the pivot where perspective does not preserve opposing screen axes.
	for projection in [Camera3D.PROJECTION_ORTHOGONAL, Camera3D.PROJECTION_PERSPECTIVE]:
		camera.projection = projection
		for yaw in [0.0, 0.37, PI / 4.0, PI / 2.0, 2.5, PI, 4.2, 5.9]:
			for pitch in [0.0, 0.000001, -0.000001, 0.3, PI / 4.0, PI / 2.0, PI / 2.0 + 0.000001, 2.3, PI, 3.9, PI * 1.5, TAU]:
				orient(camera, yaw, pitch)
				for offset in [Vector2i.ZERO, Vector2i(3, 2), Vector2i(-2, -3)]:
					player.cell = grid.start + offset
					player.position = grid.world_position(player.cell)
					var origin = camera.unproject_position(player.global_position)
					var steps: Dictionary = {}
					var longest = 0.0
					for direction in CARDINALS:
						var step = camera.unproject_position(stage.to_global(grid.world_position(player.cell + direction))) - origin
						steps[direction] = step
						longest = maxf(longest, step.length())
					for requested in CARDINALS:
						var mapped: Vector2i = player.screen_direction_to_grid(requested)
						check(CARDINALS.has(mapped), "Camera mapping always cardinal")
						var best_score = -INF
						for direction in CARDINALS:
							if steps[direction].length() > maxf(0.00001, longest * 0.0001):
								best_score = maxf(best_score, steps[direction].normalized().dot(Vector2(requested)))
						var score: float = steps[mapped].normalized().dot(Vector2(requested))
						check(best_score - score <= 0.08001 and score >= -0.00001, "Projected step follows requested screen direction within hysteresis")
						check(steps[mapped].length() > maxf(0.00001, longest * 0.0001), "Collapsed projected axis is excluded")
		# Exercise actual InputMap movement and the original world-space API.
		for pitch in [PI / 4.0, -PI / 4.0, PI / 2.0, PI * 1.5, 0.0]:
			orient(camera, 0.37, pitch)
			for index in range(4):
				player.cell = grid.start
				player.position = grid.world_position(player.cell)
				var expected: Vector2i = player.screen_direction_to_grid(CARDINALS[index])
				var action = ["move_north", "move_east", "move_south", "move_west"][index]
				var before = entered.size()
				Input.action_press(action)
				player._process(0.0)
				Input.action_release(action)
				check(player.cell == grid.start + expected and player.facing == expected, "Input moves and faces mapped passable neighbor")
				check(entered.size() == before + 1 and entered.back() == player.cell, "Mapped step emits exactly one cell entry")
				check(not player.try_move(Vector2i.UP), "Mapped movement still rejects overlapping steps")
				player.move_tween.kill()
				player.moving = false
	# A small orbit around a tie retains the preceding axis; a clear lead switches.
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	player.cell = grid.start
	player.position = grid.world_position(player.cell)
	player._screen_directions.clear()
	orient(camera, 0.0, PI / 2.0)
	var previous: Vector2i = player.screen_direction_to_grid(Vector2i.UP)
	orient(camera, deg_to_rad(47.0), PI / 2.0)
	check(player.screen_direction_to_grid(Vector2i.UP) == previous, "Small tie crossing retains movement axis")
	orient(camera, deg_to_rad(51.0), PI / 2.0)
	check(player.screen_direction_to_grid(Vector2i.UP) != previous, "Clear alignment advantage changes movement axis")
	player._screen_directions.clear()
	orient(camera, PI / 4.0, PI / 2.0)
	var first_tie: Vector2i = player.screen_direction_to_grid(Vector2i.UP)
	player._screen_directions.clear()
	check(player.screen_direction_to_grid(Vector2i.UP) == first_tie, "Fresh exact tie resolves deterministically")
	check(player.screen_direction_to_grid(Vector2i(1, 1)) == Vector2i.ZERO, "Mapping rejects diagonal input")
	check(not player.try_move(Vector2i(1, 1)), "World API still rejects diagonals")
	var blocked = grid.start + Vector2i.UP
	grid.cells[blocked.y * grid.SIZE + blocked.x].tree = true
	var before = entered.size()
	check(not player.try_move(Vector2i.UP) and entered.size() == before, "Blocked world step emits no entry")
	check(player.try_move(Vector2i.DOWN), "World cardinal API remains camera independent")
	await create_timer(0.45).timeout
	check(not player.moving and player.position.is_equal_approx(grid.world_position(player.cell)), "Mapped movement preserves cell tween completion")
	stage.queue_free()
	await process_frame
	print("MOVEMENT CAMERA: ", checks, " checks, ", failures, " failures")
	quit(0 if failures == 0 else 1)
