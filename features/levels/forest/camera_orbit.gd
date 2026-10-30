extends Node3D

const MIN_ZOOM = 24.0
const MAX_ZOOM = 56.0
const ZOOM_FACTOR = 0.88
const ORBIT_SENSITIVITY = 0.008
var target_zoom = 42.0
var target_yaw = PI * 0.25

func _ready():
	rotation.y = target_yaw
	$Camera3D.size = target_zoom
	$Camera3D.look_at(global_position)

func _unhandled_input(event):
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			target_zoom = clampf(target_zoom * pow(ZOOM_FACTOR, maxf(event.factor, 1.0)), MIN_ZOOM, MAX_ZOOM)
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			target_zoom = clampf(target_zoom / pow(ZOOM_FACTOR, maxf(event.factor, 1.0)), MIN_ZOOM, MAX_ZOOM)
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_RIGHT:
		target_yaw = wrapf(target_yaw - event.relative.x * ORBIT_SENSITIVITY, -PI, PI)
		get_viewport().set_input_as_handled()

func _process(delta):
	var weight = 1.0 - exp(-10.0 * delta)
	rotation.y = lerp_angle(rotation.y, target_yaw, weight)
	$Camera3D.size = lerpf($Camera3D.size, target_zoom, weight)
