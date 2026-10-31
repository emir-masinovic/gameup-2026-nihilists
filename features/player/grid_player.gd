extends Node3D
signal cell_entered(cell: Vector2i)
const CARDINAL_DIRECTIONS = [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
const INPUT_ALIGNMENT_HYSTERESIS = 0.08

@export_range(0.15, 0.8) var step_duration: float = 0.32

var facing = Vector2i.UP
var cell = Vector2i.ZERO
var grid: RefCounted
var moving = false
var move_tween: Tween
var _screen_directions: Dictionary = {}

var _body: Node3D
var _arm_left: Node3D
var _arm_right: Node3D
var _leg_left: Node3D
var _leg_right: Node3D
var _step_dust: CPUParticles3D

var _step_count: int = 0
var _step_elapsed: float = 0.0
var _step_planted: bool = false
var _target_yaw: float = 0.0

func _ready():
	_cache_nodes()
	_create_step_dust()

func _create_step_dust():
	if _step_dust != null:
		return
	_step_dust = CPUParticles3D.new()
	_step_dust.name = "StepDust"
	_step_dust.emitting = false
	_step_dust.one_shot = true
	_step_dust.explosiveness = 0.95
	_step_dust.amount = 6
	_step_dust.lifetime = 0.35
	_step_dust.direction = Vector3(0, 1, 0)
	_step_dust.spread = 50.0
	_step_dust.initial_velocity_min = 0.4
	_step_dust.initial_velocity_max = 0.85
	_step_dust.gravity = Vector3(0, -3.5, 0)
	
	var dust_mat = StandardMaterial3D.new()
	dust_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dust_mat.albedo_color = Color(0.55, 0.46, 0.35, 0.5)
	dust_mat.roughness = 1.0
	
	var sphere = SphereMesh.new()
	sphere.radius = 0.035
	sphere.height = 0.07
	sphere.radial_segments = 5
	sphere.rings = 3
	sphere.material = dust_mat
	_step_dust.mesh = sphere
	add_child(_step_dust)

func _cache_nodes():
	if _body == null:
		_body = get_node_or_null("Body")
	if _body != null:
		if _arm_left == null:
			_arm_left = _body.get_node_or_null("ArmLeft")
		if _arm_right == null:
			_arm_right = _body.get_node_or_null("ArmRight")
		if _leg_left == null:
			_leg_left = _body.get_node_or_null("LegLeft")
		if _leg_right == null:
			_leg_right = _body.get_node_or_null("LegRight")

func configure(data: RefCounted):
	grid = data
	cell = grid.start
	position = grid.world_position(cell)
	_screen_directions.clear()
	_cache_nodes()

func _process(delta: float):
	_update_animation(delta)
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

func _update_animation(delta: float):
	_cache_nodes()
	if _body == null:
		return
	if moving:
		_step_elapsed += delta
		var t = clampf(_step_elapsed / step_duration, 0.0, 1.0)
		var foot_side = 1.0 if (_step_count % 2 == 1) else -1.0
		
		if t < 0.72:
			# Stride phase (push-off and aerial stride)
			var stride_t = t / 0.72
			var stride_curve = sin(stride_t * PI)
			
			# Hop arc
			_body.position.y = stride_curve * 0.11
			_body.scale = Vector3.ONE
			# Leaning into the step & shifting weight
			_body.rotation.x = -stride_curve * 0.14
			_body.rotation.z = stride_curve * 0.06 * foot_side
			
			# Deliberate leg strides
			var leg_angle = stride_curve * 0.75 * foot_side
			if _leg_left:
				_leg_left.rotation.x = leg_angle
			if _leg_right:
				_leg_right.rotation.x = -leg_angle
				
			# Natural opposing arm swings with mass
			if _arm_left:
				_arm_left.rotation.x = -leg_angle * 0.75
				_arm_left.rotation.z = 0.06
			if _arm_right:
				_arm_right.rotation.x = leg_angle * 0.75
				_arm_right.rotation.z = -0.06
		else:
			# Foot plant & impact cushion phase (t >= 0.72)
			if not _step_planted:
				_step_planted = true
				if _step_dust != null:
					var boot_offset_x = -0.13 if (_step_count % 2 == 1) else 0.13
					_step_dust.position = Vector3(boot_offset_x, 0.02, 0.0)
					_step_dust.restart()
					
			var impact_t = (t - 0.72) / 0.28
			var cushion = sin(impact_t * PI)
			# Heel strike dip & rebound
			_body.position.y = -cushion * 0.035
			# Weight compression / squash
			_body.scale = Vector3(1.0 + cushion * 0.05, 1.0 - cushion * 0.06, 1.0 + cushion * 0.05)
			
			_body.rotation.x = lerpf(_body.rotation.x, 0.0, impact_t * 1.5)
			_body.rotation.z = lerpf(_body.rotation.z, 0.0, impact_t * 1.5)
			
			# Legs plant firmly on ground
			if _leg_left:
				_leg_left.rotation.x = lerpf(_leg_left.rotation.x, 0.0, impact_t * 2.0)
			if _leg_right:
				_leg_right.rotation.x = lerpf(_leg_right.rotation.x, 0.0, impact_t * 2.0)
			if _arm_left:
				_arm_left.rotation.x = lerpf(_arm_left.rotation.x, 0.0, impact_t * 2.0)
			if _arm_right:
				_arm_right.rotation.x = lerpf(_arm_right.rotation.x, 0.0, impact_t * 2.0)
				
		_body.rotation.y = lerp_angle(_body.rotation.y, _target_yaw, delta * 20.0)
	else:
		# Return limbs smoothly to relaxed stance
		var blend = delta * 12.0
		if _leg_left:
			_leg_left.rotation.x = lerpf(_leg_left.rotation.x, 0.0, blend)
		if _leg_right:
			_leg_right.rotation.x = lerpf(_leg_right.rotation.x, 0.0, blend)
		if _arm_left:
			_arm_left.rotation.x = lerpf(_arm_left.rotation.x, 0.0, blend)
			_arm_left.rotation.z = lerpf(_arm_left.rotation.z, 0.08, blend)
		if _arm_right:
			_arm_right.rotation.x = lerpf(_arm_right.rotation.x, 0.0, blend)
			_arm_right.rotation.z = lerpf(_arm_right.rotation.z, -0.08, blend)
		_body.rotation.x = lerpf(_body.rotation.x, 0.0, blend)
		_body.rotation.z = lerpf(_body.rotation.z, 0.0, blend)
		_body.scale = _body.scale.lerp(Vector3.ONE, blend)
		_body.rotation.y = lerp_angle(_body.rotation.y, _target_yaw, delta * 15.0)
		
		# Subtle idle breathing
		var breath = sin(Time.get_ticks_msec() * 0.003) * 0.012
		_body.position.y = lerpf(_body.position.y, breath, delta * 8.0)

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
	_cache_nodes()
	_step_count += 1
	_step_elapsed = 0.0
	_step_planted = false
	_target_yaw = atan2(-direction.x, -direction.y)
	if _body:
		_body.rotation.y = _target_yaw
	move_tween = create_tween()
	move_tween.tween_property(self, "position", grid.world_position(cell), step_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	move_tween.finished.connect(_on_step_finished)
	return true

func _on_step_finished():
	moving = false
	_step_planted = false
	if _body:
		_body.position.y = 0.0
		_body.scale = Vector3.ONE
