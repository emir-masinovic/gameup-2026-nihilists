extends Node3D
# Visual adaptation of Onur's astronaut at 638ba20. No controller or grid logic.
signal chop_impact(impact_position: Vector3)
const step_duration = 0.16
var _body: Node3D
var _arm_left: Node3D
var _arm_right: Node3D
var _leg_left: Node3D
var _leg_right: Node3D
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

func _on_step(_cell: Vector2i):
	stop_chopping()
	_step_count += 1
	_step_elapsed = 0.0
	_step_planted = false
	var direction: Vector2i = get_parent().facing
	_target_yaw = atan2(-direction.x, -direction.y)

func start_chopping(target_world_pos: Vector3):
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
