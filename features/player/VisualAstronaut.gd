extends Node3D
# Visual adaptation of Onur's astronaut at 638ba20. No controller or grid logic.
signal chop_impact(impact_position: Vector3)
const step_duration = 0.16
var _body: Node3D
var _arm_left: Node3D
var _arm_right: Node3D
var _leg_left: Node3D
var _leg_right: Node3D
var _hoe: Node3D
var _bottle: Node3D
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
var is_drinking: bool = false
var _drink_target_pos: Vector3 = Vector3.ZERO
var _drink_elapsed: float = 0.0
signal till_impact(impact_position: Vector3)
signal water_fill_splash(impact_position: Vector3)
signal water_pour_splash(impact_position: Vector3)
var _axe: Node3D
var _step_dust: CPUParticles3D
var _step_count = 0
var _step_elapsed = 0.0
var _step_planted = false
var _target_yaw = 0.0
var is_chopping = false
var _chop_target_pos = Vector3.ZERO
var _chop_elapsed = 0.0
var _chop_swing_count = 0
var _chop_hit_delivered = false
var moving: bool:
	get:
		return is_instance_valid(get_parent()) and get_parent().get("moving") == true

func _ready():
	_cache_nodes()
	_axe.visible = false
	if get_parent().has_signal("cell_entered"):
		get_parent().cell_entered.connect(_on_step)

func _cache_nodes():
	_body = self
	_arm_left = get_node_or_null("ArmLeft")
	_arm_right = get_node_or_null("ArmRight")
	_leg_left = get_node_or_null("LegLeft")
	_leg_right = get_node_or_null("LegRight")
	_axe = get_node_or_null("ArmRight/Axe")
	_hoe = get_node_or_null("ArmRight/Hoe")
	_bottle = get_node_or_null("ArmRight/Bottle")

func _on_step(_cell: Vector2i):
	stop_chopping()
	stop_farming()
	stop_drinking()
	_step_count += 1
	_step_elapsed = 0.0
	_step_planted = false
	var direction: Vector2i = get_parent().facing
	_target_yaw = atan2(-direction.x, -direction.y)

func start_chopping(target_world_pos: Vector3):
	stop_farming()
	is_chopping = true
	_chop_target_pos = target_world_pos
	_chop_elapsed = 0.0
	_chop_swing_count = 0
	_chop_hit_delivered = false
	_axe.visible = true
	var direction = target_world_pos - global_position
	_target_yaw = atan2(-direction.x, -direction.z)

func stop_chopping():
	is_chopping = false
	_chop_elapsed = 0.0
	_chop_hit_delivered = false
	if is_instance_valid(_axe): _axe.visible = false

func _process(delta):
	_update_animation(delta)

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
				_arm_right.rotation.y = 0.0
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
			# Phase 1: Wind-up / Raising axe high over shoulder
			var t = swing_time / windup_time
			var ease_up = sin(t * PI * 0.5)

			if _arm_right:
				_arm_right.rotation.x = lerpf(0.0, 1.85, ease_up)
				_arm_right.rotation.y = lerpf(0.0, 0.35, ease_up)
				_arm_right.rotation.z = lerpf(-0.08, -0.3, ease_up)
			if _arm_left:
				_arm_left.rotation.x = lerpf(0.0, -0.55, ease_up)
				_arm_left.rotation.z = lerpf(0.08, 0.22, ease_up)

			_body.rotation.x = lerpf(0.0, 0.16, ease_up)
			_body.rotation.y = _target_yaw + lerpf(0.0, 0.22, ease_up)
			_body.position.y = lerpf(0.0, 0.035, ease_up)
			_body.scale = Vector3.ONE

			if _leg_left:
				_leg_left.rotation.x = -0.12
			if _leg_right:
				_leg_right.rotation.x = 0.18
		elif swing_time < impact_time:
			# Phase 2: Powerful downward chop stroke towards tree trunk
			var t = (swing_time - windup_time) / (impact_time - windup_time)
			var strike_curve = t * t * (3.0 - 2.0 * t)

			if _arm_right:
				_arm_right.rotation.x = lerpf(1.85, -1.35, strike_curve)
				_arm_right.rotation.y = lerpf(0.35, -0.15, strike_curve)
				_arm_right.rotation.z = lerpf(-0.3, 0.05, strike_curve)
			if _arm_left:
				_arm_left.rotation.x = lerpf(-0.55, -0.25, strike_curve)

			_body.rotation.x = lerpf(0.16, -0.36, strike_curve)
			_body.rotation.y = _target_yaw + lerpf(0.22, -0.16, strike_curve)
			_body.position.y = lerpf(0.035, -0.04, strike_curve)
			_body.scale = Vector3(1.03, 0.96, 1.03)
		else:
			# Phase 3 & 4: Impact delivery & recoil / reset
			if not _chop_hit_delivered:
				_chop_hit_delivered = true
				var hit_point = global_position.lerp(_chop_target_pos, 0.65) + Vector3(0, 0.65, 0)
				chop_impact.emit(hit_point)

			var t = (swing_time - impact_time) / (swing_duration - impact_time)
			var shudder = sin(t * PI * 3.0) * exp(-t * 5.0) * 0.08
			if _arm_right:
				_arm_right.rotation.x = lerpf(-1.35, 0.0, t) + shudder
				_arm_right.rotation.y = lerpf(-0.15, 0.0, t)
				_arm_right.rotation.z = lerpf(0.05, -0.08, t)
			if _arm_left:
				_arm_left.rotation.x = lerpf(-0.25, 0.0, t)
			_body.rotation.x = lerpf(-0.36, 0.0, t)
			_body.rotation.y = lerp_angle(_body.rotation.y, _target_yaw, t)
			_body.position.y = lerpf(-0.04, 0.0, t)
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
				var hit_point = global_position.lerp(_till_target_pos, 0.7) + Vector3(0, 0.05, 0)
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
			var splash_pt = global_position.lerp(_fill_target_pos, 0.6) + Vector3(0, 0.03, 0)
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
			var pour_pt = global_position.lerp(_water_target_pos, 0.7) + Vector3(0, 0.1, 0)
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
	elif is_drinking:
		_drink_elapsed += delta
		# Character kneels down towards water, scoops water with cupped hands up to helmet/face to drink
		var cycle = fmod(_drink_elapsed, 0.9)
		var kneel = minf(_drink_elapsed * 3.5, 1.0)
		_body.position.y = lerpf(0.0, -0.16, kneel)
		_body.rotation.x = lerpf(0.0, -0.38, kneel)
		if _leg_left:
			_leg_left.rotation.x = lerpf(0.0, -0.42, kneel)
		if _leg_right:
			_leg_right.rotation.x = lerpf(0.0, 0.38, kneel)
		if cycle < 0.45:
			# Reach cupped hands down into the water
			var t = cycle / 0.45
			var ease_down = sin(t * PI * 0.5)
			if _arm_left:
				_arm_left.rotation.x = lerpf(0.0, -0.85, ease_down)
				_arm_left.rotation.z = lerpf(0.08, 0.28, ease_down)
			if _arm_right:
				_arm_right.rotation.x = lerpf(0.0, -0.85, ease_down)
				_arm_right.rotation.z = lerpf(-0.08, -0.28, ease_down)
		else:
			# Bring cupped hands up to helmet visor to drink, head tilting slightly
			var t = (cycle - 0.45) / 0.45
			var ease_up = sin(t * PI * 0.5)
			if _arm_left:
				_arm_left.rotation.x = lerpf(-0.85, -1.55, ease_up)
				_arm_left.rotation.z = lerpf(0.28, 0.42, ease_up)
			if _arm_right:
				_arm_right.rotation.x = lerpf(-0.85, -1.55, ease_up)
				_arm_right.rotation.z = lerpf(-0.28, -0.42, ease_up)
			_body.rotation.x = lerpf(-0.38, -0.18, ease_up)
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
			_arm_right.rotation.y = lerpf(_arm_right.rotation.y, 0.0, blend)
			_arm_right.rotation.x = lerpf(_arm_right.rotation.x, 0.0, blend)
			_arm_right.rotation.z = lerpf(_arm_right.rotation.z, -0.08, blend)
		_body.rotation.x = lerpf(_body.rotation.x, 0.0, blend)
		_body.rotation.z = lerpf(_body.rotation.z, 0.0, blend)
		_body.scale = _body.scale.lerp(Vector3.ONE, blend)
		_body.rotation.y = lerp_angle(_body.rotation.y, _target_yaw, delta * 15.0)

		# Subtle idle breathing
		var breath = sin(Time.get_ticks_msec() * 0.003) * 0.012
		_body.position.y = lerpf(_body.position.y, breath, delta * 8.0)

func start_tilling(target_world_pos: Vector3):
	stop_farming()
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
	var dir_to_ground = target_world_pos - global_position
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
	stop_farming()
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
	var dir_to_water = target_world_pos - global_position
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
	stop_farming()
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
	var dir_to_target = target_world_pos - global_position
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
	stop_farming()
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


func start_drinking(target_world_pos: Vector3):
	stop_farming()
	stop_chopping()
	is_drinking = true
	_drink_target_pos = target_world_pos
	_drink_elapsed = 0.0
	_cache_nodes()
	if _bottle != null: _bottle.visible = false
	if _axe != null: _axe.visible = false
	if _hoe != null: _hoe.visible = false
	var dir_to_water = target_world_pos - global_position
	if dir_to_water.length_squared() > 0.001:
		_target_yaw = atan2(-dir_to_water.x, -dir_to_water.z)
		if _body != null:
			_body.rotation.y = _target_yaw

func stop_drinking():
	is_drinking = false
	_drink_elapsed = 0.0

func stop_farming():
	stop_tilling()
	stop_filling_water()
	stop_watering()
	stop_gathering()
	stop_drinking()
