extends Node3D
signal cell_entered(cell: Vector2i)
signal chop_impact(impact_position: Vector3)
signal till_impact(impact_position: Vector3)
signal water_fill_splash(splash_position: Vector3)
signal water_pour_splash(splash_position: Vector3)

const CARDINAL_DIRECTIONS = [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
const INPUT_ALIGNMENT_HYSTERESIS = 0.08

@export_range(0.15, 0.8) var step_duration: float = 0.32

var facing = Vector2i.UP
var cell = Vector2i.ZERO
var grid: RefCounted
var moving = false
var move_tween: Tween
var _screen_directions: Dictionary = {}

var is_chopping: bool = false
var _chop_target_pos: Vector3 = Vector3.ZERO
var _chop_elapsed: float = 0.0
var _chop_swing_count: int = 0
var _chop_hit_delivered: bool = false

var is_tilling: bool = false
var _till_target_pos: Vector3 = Vector3.ZERO
var _till_elapsed: float = 0.0
var _till_swing_count: int = 0
var _till_hit_delivered: bool = false

var is_filling_water: bool = false
var _fill_target_pos: Vector3 = Vector3.ZERO
var _fill_elapsed: float = 0.0
var _fill_splash_timer: float = 0.0

var is_watering: bool = false
var _water_target_pos: Vector3 = Vector3.ZERO
var _water_elapsed: float = 0.0
var _water_poured: bool = false

var is_gathering: bool = false
var _gather_elapsed: float = 0.0

var _body: Node3D
var _arm_left: Node3D
var _arm_right: Node3D
var _leg_left: Node3D
var _leg_right: Node3D
var _axe: Node3D
var _hoe: Node3D
var _bottle: Node3D
var _step_dust: CPUParticles3D

var _step_count: int = 0
var _step_elapsed: float = 0.0
var _step_planted: bool = false
var _target_yaw: float = 0.0

func _ready():
	_cache_nodes()
	_create_step_dust()
	if _axe != null:
		_axe.visible = false
	if _hoe != null:
		_hoe.visible = false
	if _bottle != null:
		_bottle.visible = false

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
		if _axe == null and _arm_right != null:
			_axe = _arm_right.get_node_or_null("Axe")
		if _hoe == null and _arm_right != null:
			_hoe = _arm_right.get_node_or_null("Hoe")
		if _bottle == null and _arm_right != null:
			_bottle = _arm_right.get_node_or_null("Bottle")

func configure(data: RefCounted):
	grid = data
	cell = grid.start
	position = grid.world_position(cell)
	_screen_directions.clear()
	_cache_nodes()
	if _axe != null:
		_axe.visible = false
	if _hoe != null:
		_hoe.visible = false
	if _bottle != null:
		_bottle.visible = false

func start_chopping(target_world_pos: Vector3):
	is_chopping = true
	is_tilling = false
	is_filling_water = false
	is_watering = false
	_chop_target_pos = target_world_pos
	_chop_elapsed = 0.0
	_chop_swing_count = 0
	_chop_hit_delivered = false
	_cache_nodes()
	if _axe != null:
		_axe.visible = true
	if _hoe != null:
		_hoe.visible = false
	if _bottle != null:
		_bottle.visible = false
	var dir_to_tree = target_world_pos - position
	if dir_to_tree.length_squared() > 0.001:
		_target_yaw = atan2(-dir_to_tree.x, -dir_to_tree.z)
		if _body != null:
			_body.rotation.y = _target_yaw

func stop_chopping():
	is_chopping = false
	_chop_elapsed = 0.0
	_chop_hit_delivered = false
	_cache_nodes()
	if _axe != null:
		_axe.visible = false

func start_tilling(target_world_pos: Vector3):
	is_tilling = true
	is_chopping = false
	is_filling_water = false
	is_watering = false
	_till_target_pos = target_world_pos
	_till_elapsed = 0.0
	_till_swing_count = 0
	_till_hit_delivered = false
	_cache_nodes()
	if _hoe != null:
		_hoe.visible = true
	if _axe != null:
		_axe.visible = false
	if _bottle != null:
		_bottle.visible = false
	var dir_to_ground = target_world_pos - position
	if dir_to_ground.length_squared() > 0.001:
		_target_yaw = atan2(-dir_to_ground.x, -dir_to_ground.z)
		if _body != null:
			_body.rotation.y = _target_yaw

func stop_tilling():
	is_tilling = false
	_till_elapsed = 0.0
	_till_hit_delivered = false
	_cache_nodes()
	if _hoe != null:
		_hoe.visible = false

func start_filling_water(target_world_pos: Vector3):
	is_filling_water = true
	is_chopping = false
	is_tilling = false
	is_watering = false
	_fill_target_pos = target_world_pos
	_fill_elapsed = 0.0
	_fill_splash_timer = 0.0
	_cache_nodes()
	if _bottle != null:
		_bottle.visible = true
	if _axe != null:
		_axe.visible = false
	if _hoe != null:
		_hoe.visible = false
	var dir_to_water = target_world_pos - position
	if dir_to_water.length_squared() > 0.001:
		_target_yaw = atan2(-dir_to_water.x, -dir_to_water.z)
		if _body != null:
			_body.rotation.y = _target_yaw

func stop_filling_water():
	is_filling_water = false
	_fill_elapsed = 0.0
	_cache_nodes()
	if _bottle != null:
		_bottle.visible = false

func start_watering(target_world_pos: Vector3):
	is_watering = true
	is_chopping = false
	is_tilling = false
	is_filling_water = false
	_water_target_pos = target_world_pos
	_water_elapsed = 0.0
	_water_poured = false
	_cache_nodes()
	if _bottle != null:
		_bottle.visible = true
	if _axe != null:
		_axe.visible = false
	if _hoe != null:
		_hoe.visible = false
	var dir_to_target = target_world_pos - position
	if dir_to_target.length_squared() > 0.001:
		_target_yaw = atan2(-dir_to_target.x, -dir_to_target.z)
		if _body != null:
			_body.rotation.y = _target_yaw

func stop_watering():
	is_watering = false
	_water_elapsed = 0.0
	_water_poured = false
	_cache_nodes()
	if _bottle != null:
		_bottle.visible = false

func start_gathering(target_world_pos: Vector3):
	is_chopping = false
	is_tilling = false
	is_filling_water = false
	is_watering = false
	is_gathering = true
	_gather_elapsed = 0.0
	_cache_nodes()
	if _bottle != null:
		_bottle.visible = false
	if _axe != null:
		_axe.visible = false
	if _hoe != null:
		_hoe.visible = false

func stop_gathering():
	is_gathering = false
	_gather_elapsed = 0.0

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
			var stride_t = t / 0.72
			var stride_curve = sin(stride_t * PI)
			_body.position.y = stride_curve * 0.11
			_body.scale = Vector3.ONE
			_body.rotation.x = -stride_curve * 0.14
			_body.rotation.z = stride_curve * 0.06 * foot_side
			
			var leg_angle = stride_curve * 0.75 * foot_side
			if _leg_left:
				_leg_left.rotation.x = leg_angle
			if _leg_right:
				_leg_right.rotation.x = -leg_angle
				
			if _arm_left:
				_arm_left.rotation.x = -leg_angle * 0.75
				_arm_left.rotation.z = 0.06
			if _arm_right:
				_arm_right.rotation.x = leg_angle * 0.75
				_arm_right.rotation.z = -0.06
		else:
			if not _step_planted:
				_step_planted = true
				if _step_dust != null:
					var boot_offset_x = -0.13 if (_step_count % 2 == 1) else 0.13
					_step_dust.position = Vector3(boot_offset_x, 0.02, 0.0)
					_step_dust.restart()
					
			var impact_t = (t - 0.72) / 0.28
			var cushion = sin(impact_t * PI)
			_body.position.y = -cushion * 0.035
			_body.scale = Vector3(1.0 + cushion * 0.05, 1.0 - cushion * 0.06, 1.0 + cushion * 0.05)
			
			_body.rotation.x = lerpf(_body.rotation.x, 0.0, impact_t * 1.5)
			_body.rotation.z = lerpf(_body.rotation.z, 0.0, impact_t * 1.5)
			
			if _leg_left:
				_leg_left.rotation.x = lerpf(_leg_left.rotation.x, 0.0, impact_t * 2.0)
			if _leg_right:
				_leg_right.rotation.x = lerpf(_leg_right.rotation.x, 0.0, impact_t * 2.0)
			if _arm_left:
				_arm_left.rotation.x = lerpf(_arm_left.rotation.x, 0.0, impact_t * 2.0)
			if _arm_right:
				_arm_right.rotation.x = lerpf(_arm_right.rotation.x, 0.0, impact_t * 2.0)
				
		_body.rotation.y = lerp_angle(_body.rotation.y, _target_yaw, delta * 20.0)
	elif is_chopping:
		_chop_elapsed += delta
		var swing_duration = 0.6
		var swing_time = fposmod(_chop_elapsed, swing_duration)
		var swing_idx = floori(_chop_elapsed / swing_duration)
		
		if swing_idx != _chop_swing_count:
			_chop_swing_count = swing_idx
			_chop_hit_delivered = false
			
		var windup_time = 0.35
		var impact_time = 0.45
		
		if swing_time < windup_time:
			# Wind-up: Raising large axe high above shoulder
			var t = swing_time / windup_time
			var ease_up = sin(t * PI * 0.5)
			
			if _arm_right:
				_arm_right.rotation.x = lerpf(0.0, 1.95, ease_up)
				_arm_right.rotation.y = lerpf(0.0, 0.4, ease_up)
				_arm_right.rotation.z = lerpf(-0.08, -0.32, ease_up)
			if _arm_left:
				_arm_left.rotation.x = lerpf(0.0, -0.6, ease_up)
				_arm_left.rotation.z = lerpf(0.08, 0.25, ease_up)
				
			_body.rotation.x = lerpf(0.0, 0.18, ease_up)
			_body.rotation.y = _target_yaw + lerpf(0.0, 0.25, ease_up)
			_body.position.y = lerpf(0.0, 0.04, ease_up)
			_body.scale = Vector3.ONE
			
			if _leg_left:
				_leg_left.rotation.x = -0.12
			if _leg_right:
				_leg_right.rotation.x = 0.18
		elif swing_time < impact_time:
			# Downward chop stroke towards tree trunk
			var t = (swing_time - windup_time) / (impact_time - windup_time)
			var strike_curve = t * t * (3.0 - 2.0 * t)
			
			if _arm_right:
				_arm_right.rotation.x = lerpf(1.95, -1.4, strike_curve)
				_arm_right.rotation.y = lerpf(0.4, -0.15, strike_curve)
				_arm_right.rotation.z = lerpf(-0.32, 0.05, strike_curve)
			if _arm_left:
				_arm_left.rotation.x = lerpf(-0.6, -0.25, strike_curve)
				
			_body.rotation.x = lerpf(0.18, -0.38, strike_curve)
			_body.rotation.y = _target_yaw + lerpf(0.25, -0.18, strike_curve)
			_body.position.y = lerpf(0.04, -0.05, strike_curve)
			_body.scale = Vector3(1.04, 0.95, 1.04)
		else:
			# Impact delivery & recoil
			if not _chop_hit_delivered:
				_chop_hit_delivered = true
				var hit_point = position.lerp(_chop_target_pos, 0.65) + Vector3(0, 0.65, 0)
				chop_impact.emit(hit_point)
				
			var t = (swing_time - impact_time) / (swing_duration - impact_time)
			var shudder = sin(t * PI * 3.0) * exp(-t * 5.0) * 0.08
			if _arm_right:
				_arm_right.rotation.x = lerpf(-1.4, 0.0, t) + shudder
				_arm_right.rotation.y = lerpf(-0.15, 0.0, t)
				_arm_right.rotation.z = lerpf(0.05, -0.08, t)
			if _arm_left:
				_arm_left.rotation.x = lerpf(-0.25, 0.0, t)
			_body.rotation.x = lerpf(-0.38, 0.0, t)
			_body.rotation.y = lerp_angle(_body.rotation.y, _target_yaw, t)
			_body.position.y = lerpf(-0.05, 0.0, t)
			_body.scale = _body.scale.lerp(Vector3.ONE, t)
	elif is_tilling:
		_till_elapsed += delta
		var swing_duration = 0.45
		var swing_time = fposmod(_till_elapsed, swing_duration)
		var swing_idx = floori(_till_elapsed / swing_duration)
		
		if swing_idx != _till_swing_count:
			_till_swing_count = swing_idx
			_till_hit_delivered = false
			
		var windup_time = 0.22
		var impact_time = 0.32
		
		if swing_time < windup_time:
			# Wind-up: Lift hoe upward and bend knees
			var t = swing_time / windup_time
			var ease_up = sin(t * PI * 0.5)
			if _arm_right:
				_arm_right.rotation.x = lerpf(0.0, 0.95, ease_up)
				_arm_right.rotation.z = lerpf(-0.08, -0.15, ease_up)
			if _arm_left:
				_arm_left.rotation.x = lerpf(0.0, -0.45, ease_up)
			_body.rotation.x = lerpf(0.0, -0.12, ease_up)
			_body.position.y = lerpf(0.0, 0.02, ease_up)
		elif swing_time < impact_time:
			# Plunge hoe downward into soil in front of player
			var t = (swing_time - windup_time) / (impact_time - windup_time)
			var strike_curve = t * t * (3.0 - 2.0 * t)
			if _arm_right:
				_arm_right.rotation.x = lerpf(0.95, -1.5, strike_curve)
				_arm_right.rotation.z = lerpf(-0.15, 0.05, strike_curve)
			if _arm_left:
				_arm_left.rotation.x = lerpf(-0.45, -0.8, strike_curve)
			_body.rotation.x = lerpf(-0.12, -0.42, strike_curve)
			_body.position.y = lerpf(0.02, -0.06, strike_curve)
		else:
			# Strike dirt & pull hoe blade through the soil
			if not _till_hit_delivered:
				_till_hit_delivered = true
				var hit_point = position.lerp(_till_target_pos, 0.7) + Vector3(0, 0.05, 0)
				till_impact.emit(hit_point)
			var t = (swing_time - impact_time) / (swing_duration - impact_time)
			if _arm_right:
				_arm_right.rotation.x = lerpf(-1.5, -0.2, t)
			if _arm_left:
				_arm_left.rotation.x = lerpf(-0.8, 0.0, t)
			_body.rotation.x = lerpf(-0.42, 0.0, t)
			_body.position.y = lerpf(-0.06, 0.0, t)
	elif is_filling_water:
		_fill_elapsed += delta
		_fill_splash_timer += delta
		if _fill_splash_timer >= 0.45:
			_fill_splash_timer = 0.0
			var splash_pt = position.lerp(_fill_target_pos, 0.6) + Vector3(0, 0.03, 0)
			water_fill_splash.emit(splash_pt)
		
		# Kneel down low near water edge
		var kneel = minf(_fill_elapsed * 3.0, 1.0)
		_body.position.y = lerpf(0.0, -0.15, kneel)
		_body.rotation.x = lerpf(0.0, -0.36, kneel)
		if _leg_left:
			_leg_left.rotation.x = lerpf(0.0, -0.4, kneel)
		if _leg_right:
			_leg_right.rotation.x = lerpf(0.0, 0.35, kneel)
		
		# Submerge bottle in water with gentle ripple bobbing
		var bob = sin(_fill_elapsed * 5.0) * 0.05
		if _arm_right:
			_arm_right.rotation.x = lerpf(0.0, -1.25 + bob, kneel)
			_arm_right.rotation.z = lerpf(0.0, -0.12, kneel)
		if _arm_left:
			_arm_left.rotation.x = lerpf(0.0, -0.45, kneel)
	elif is_watering:
		_water_elapsed += delta
		var pour = minf(_water_elapsed * 3.5, 1.0)
		_body.position.y = lerpf(0.0, -0.06, pour)
		_body.rotation.x = lerpf(0.0, -0.22, pour)
		if _arm_right:
			_arm_right.rotation.x = lerpf(0.0, -0.9, pour)
			_arm_right.rotation.z = lerpf(0.0, 0.65, pour)
		if _arm_left:
			_arm_left.rotation.x = lerpf(0.0, -0.25, pour)
		if _water_elapsed > 0.25 and not _water_poured:
			_water_poured = true
			var pour_pt = position.lerp(_water_target_pos, 0.7) + Vector3(0, 0.1, 0)
			water_pour_splash.emit(pour_pt)
	elif is_gathering:
		_gather_elapsed += delta
		var kneel = minf(_gather_elapsed * 3.5, 1.0)
		_body.position.y = lerpf(0.0, -0.16, kneel)
		_body.rotation.x = lerpf(0.0, -0.4, kneel)
		if _leg_left:
			_leg_left.rotation.x = lerpf(0.0, -0.42, kneel)
		if _leg_right:
			_leg_right.rotation.x = lerpf(0.0, 0.38, kneel)
		var reach = sin(_gather_elapsed * 6.0) * 0.1
		if _arm_left:
			_arm_left.rotation.x = lerpf(0.0, -0.85 + reach, kneel)
			_arm_left.rotation.z = lerpf(0.0, 0.2, kneel)
		if _arm_right:
			_arm_right.rotation.x = lerpf(0.0, -0.85 - reach, kneel)
			_arm_right.rotation.z = lerpf(0.0, -0.2, kneel)
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
	if is_chopping:
		stop_chopping()
	if is_tilling:
		stop_tilling()
	if is_filling_water:
		stop_filling_water()
	if is_watering:
		stop_watering()
	facing = direction
	_target_yaw = atan2(-direction.x, -direction.y)
	if _body != null:
		_body.rotation.y = _target_yaw
	var target = cell + direction
	if not grid.traversable(target):
		return false
	moving = true
	cell = target
	cell_entered.emit(cell)
	_cache_nodes()
	_step_count += 1
	_step_elapsed = 0.0
	_step_planted = false
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
