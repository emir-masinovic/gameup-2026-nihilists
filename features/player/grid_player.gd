extends Node3D
signal cell_entered(cell: Vector2i)
signal chop_impact(impact_position: Vector3)
signal till_impact(impact_position: Vector3)
signal water_fill_splash(impact_position: Vector3)
signal water_pour_splash(impact_position: Vector3)

const CARDINAL_DIRECTIONS = [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
const INPUT_ALIGNMENT_HYSTERESIS = 0.08
const MAPPING_ALIGNMENT_HYSTERESIS = 0.16
var facing = Vector2i.UP
var cell = Vector2i.ZERO
var grid: RefCounted
var moving = false
var require_release = false
var move_tween: Tween
var _screen_directions: Dictionary = {}

var is_chopping: bool:
	get: return $Body.is_chopping if has_node("Body") else false
var is_tilling: bool:
	get: return $Body.is_tilling if has_node("Body") else false
var is_filling_water: bool:
	get: return $Body.is_filling_water if has_node("Body") else false
var is_watering: bool:
	get: return $Body.is_watering if has_node("Body") else false
var is_gathering: bool:
	get: return $Body.is_gathering if has_node("Body") else false

func _ready():
	if has_node("Body"):
		var body = $Body
		if body.has_signal("chop_impact"): body.chop_impact.connect(func(pos): chop_impact.emit(pos))
		if body.has_signal("till_impact"): body.till_impact.connect(func(pos): till_impact.emit(pos))
		if body.has_signal("water_fill_splash"): body.water_fill_splash.connect(func(pos): water_fill_splash.emit(pos))
		if body.has_signal("water_pour_splash"): body.water_pour_splash.connect(func(pos): water_pour_splash.emit(pos))

func start_chopping(target_world_pos: Vector3):
	if has_node("Body") and $Body.has_method("start_chopping"):
		$Body.start_chopping(target_world_pos)

func stop_chopping():
	if has_node("Body") and $Body.has_method("stop_chopping"):
		$Body.stop_chopping()

func start_tilling(target_world_pos: Vector3):
	if has_node("Body") and $Body.has_method("start_tilling"):
		$Body.start_tilling(target_world_pos)

func stop_tilling():
	if has_node("Body") and $Body.has_method("stop_tilling"):
		$Body.stop_tilling()

func start_filling_water(target_world_pos: Vector3):
	if has_node("Body") and $Body.has_method("start_filling_water"):
		$Body.start_filling_water(target_world_pos)

func stop_filling_water():
	if has_node("Body") and $Body.has_method("stop_filling_water"):
		$Body.stop_filling_water()

func start_watering(target_world_pos: Vector3):
	if has_node("Body") and $Body.has_method("start_watering"):
		$Body.start_watering(target_world_pos)

func stop_watering():
	if has_node("Body") and $Body.has_method("stop_watering"):
		$Body.stop_watering()

func start_gathering(target_world_pos: Vector3):
	if has_node("Body") and $Body.has_method("start_gathering"):
		$Body.start_gathering(target_world_pos)

func stop_gathering():
	if has_node("Body") and $Body.has_method("stop_gathering"):
		$Body.stop_gathering()

func _update_animation(delta: float):
	if has_node("Body") and $Body.has_method("_update_animation"):
		$Body._update_animation(delta)

func configure(data: RefCounted):
	grid = data
	cell = grid.start
	position = grid.world_position(cell)
	_screen_directions.clear()

func _process(_delta):
	if require_release:
		for action in ["move_north", "move_south", "move_west", "move_east"]:
			if Input.is_action_pressed(action):
				return
		require_release = false
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
	var right: Vector2 = projected[Vector2i.RIGHT]
	var down: Vector2 = projected[Vector2i.DOWN]
	var complete_projection = true
	for direction in CARDINAL_DIRECTIONS:
		var step: Vector2 = projected[direction]
		if not step.is_finite() or step.length() <= minimum_length:
			complete_projection = false
	# At a truly edge-on view the projected grid axes are collinear. No
	# bijection can make all four requested directions visually meaningful.
	if not complete_projection or absf(right.normalized().cross(down.normalized())) < 0.0001:
		return _nearest_visible_direction(screen_direction, projected, minimum_length)

	# Solve all four keys together. Independent nearest-direction choices can
	# bind two keys to the same world axis and make another axis unreachable.
	var best: Dictionary = {}
	var best_score = -INF
	for north in CARDINAL_DIRECTIONS:
		var clockwise = Vector2i(-north.y, north.x)
		for east in [clockwise, -clockwise]:
			var candidate = {Vector2i.UP: north, Vector2i.RIGHT: east,
				Vector2i.DOWN: -north, Vector2i.LEFT: -east}
			var score = _mapping_alignment(candidate, projected)
			# Fixed enumeration starts with the identity map and resolves ties.
			if score > best_score + 0.000001:
				best = candidate
				best_score = score
	if best.is_empty():
		return _nearest_visible_direction(screen_direction, projected, minimum_length)
	var previous_score = _mapping_alignment(_screen_directions, projected)
	if previous_score != -INF and best_score - previous_score <= MAPPING_ALIGNMENT_HYSTERESIS:
		best = _screen_directions
	_screen_directions = best
	return best[screen_direction]

func _mapping_alignment(mapping: Dictionary, projected: Dictionary) -> float:
	if mapping.size() != 4:
		return -INF
	var north: Vector2i = mapping.get(Vector2i.UP, Vector2i.ZERO)
	var east: Vector2i = mapping.get(Vector2i.RIGHT, Vector2i.ZERO)
	if not CARDINAL_DIRECTIONS.has(north) or not CARDINAL_DIRECTIONS.has(east) or Vector2(north).dot(Vector2(east)) != 0 or mapping.get(Vector2i.DOWN) != -north or mapping.get(Vector2i.LEFT) != -east:
		return -INF
	var total = 0.0
	for requested in CARDINAL_DIRECTIONS:
		var score: float = projected[mapping[requested]].normalized().dot(Vector2(requested))
		if score < -0.00001:
			return -INF
		total += score
	return total

func _nearest_visible_direction(screen_direction: Vector2i, projected: Dictionary, minimum_length: float) -> Vector2i:
	var scores: Dictionary = {}
	var best_direction = screen_direction
	var best_score = -INF
	for direction in CARDINAL_DIRECTIONS:
		var step: Vector2 = projected[direction]
		if not step.is_finite() or step.length() <= minimum_length:
			continue
		var score = step.normalized().dot(Vector2(screen_direction))
		scores[direction] = score
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
