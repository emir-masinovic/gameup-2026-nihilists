extends Node3D
signal cell_entered(cell: Vector2i)
const CARDINAL_DIRECTIONS = [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
const INPUT_ALIGNMENT_HYSTERESIS = 0.08
var facing = Vector2i.UP
var cell = Vector2i.ZERO
var grid: RefCounted
var moving = false
var move_tween: Tween
var _screen_directions: Dictionary = {}

func configure(data: RefCounted):
	grid = data
	cell = grid.start
	position = grid.world_position(cell)
	_screen_directions.clear()

func _process(_delta):
	if moving or grid == null:
		return
	var direction = Vector2i.ZERO
	if Input.is_action_pressed("move_north"):
		direction = Vector2i.UP
	elif Input.is_action_pressed("move_south"):
		direction = Vector2i.DOWN
	elif Input.is_action_pressed("move_west"):
		direction = Vector2i.LEFT
	elif Input.is_action_pressed("move_east"):
		direction = Vector2i.RIGHT
	if direction != Vector2i.ZERO:
		try_move(screen_direction_to_grid(direction))

func screen_direction_to_grid(screen_direction: Vector2i) -> Vector2i:
	if abs(screen_direction.x) + abs(screen_direction.y) != 1:
		return Vector2i.ZERO
	var camera = get_viewport().get_camera_3d()
	if camera == null or grid == null:
		return screen_direction
	var origin: Vector3 = get_parent().to_global(grid.world_position(cell))
	var screen_origin = camera.unproject_position(origin)
	var projected: Dictionary = {}
	var longest = 0.0
	for direction in CARDINAL_DIRECTIONS:
		var target: Vector3 = get_parent().to_global(grid.world_position(cell + direction))
		var step = camera.unproject_position(target) - screen_origin
		projected[direction] = step
		longest = maxf(longest, step.length())
	# At a horizontal view one grid axis can vanish. Do not normalize its
	# floating-point residue into an apparently perfect screen direction.
	var minimum_length = maxf(0.00001, longest * 0.0001)
	var scores: Dictionary = {}
	var best_direction = screen_direction
	var best_score = -INF
	for direction in CARDINAL_DIRECTIONS:
		var step: Vector2 = projected[direction]
		if not step.is_finite() or step.length() <= minimum_length:
			continue
		var score = step.normalized().dot(Vector2(screen_direction))
		scores[direction] = score
		# Fixed cardinal iteration order resolves exact ties reproducibly.
		if score > best_score + 0.000001:
			best_score = score
			best_direction = direction
	var previous: Vector2i = _screen_directions.get(screen_direction, Vector2i.ZERO)
	if scores.has(previous) and scores[previous] >= 0.0 and best_score - scores[previous] <= INPUT_ALIGNMENT_HYSTERESIS:
		best_direction = previous
	_screen_directions[screen_direction] = best_direction
	return best_direction

func try_move(direction: Vector2i) -> bool:
	if moving or grid == null or abs(direction.x) + abs(direction.y) != 1:
		return false
	var target = cell + direction
	if not grid.traversable(target):
		return false
	facing = direction
	moving = true
	cell = target
	cell_entered.emit(cell)
	$Body.rotation.y = atan2(-direction.x, -direction.y)
	move_tween = create_tween()
	move_tween.tween_property(self, "position", grid.world_position(cell), 0.16).set_trans(Tween.TRANS_SINE)
	move_tween.finished.connect(func(): moving = false)
	return true
