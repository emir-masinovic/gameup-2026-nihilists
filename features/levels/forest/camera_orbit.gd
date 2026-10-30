extends Node3D

const MIN_ZOOM = 24.0
const MAX_ZOOM = 56.0
const ZOOM_FACTOR = 0.88
const MIN_PITCH = PI / 18.0
const MAX_PITCH = PI * 85.0 / 180.0
var target_zoom = 42.0
var target_yaw = PI * 0.25
var target_pitch = PI * 0.25
var pitch = PI * 0.25
var drag_button = 0

func _ready():
	rotation.y = target_yaw
	$Camera3D.size = target_zoom
	_update_camera()
	get_tree().root.focus_exited.connect(_cancel_drag)

func _cancel_drag():
	drag_button = 0

func _input(event):
	# Release is observed even when a UI control consumes the event.
	if event is InputEventMouseButton and not event.pressed and event.button_index == drag_button:
		_cancel_drag()

func _unhandled_input(event):
	if get_tree().paused or not get_tree().root.has_focus():
		_cancel_drag()
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index in [MOUSE_BUTTON_MIDDLE, MOUSE_BUTTON_RIGHT]:
			drag_button = event.button_index
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			target_zoom = clampf(target_zoom * pow(ZOOM_FACTOR, maxf(event.factor, 1.0)), MIN_ZOOM, MAX_ZOOM)
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			target_zoom = clampf(target_zoom / pow(ZOOM_FACTOR, maxf(event.factor, 1.0)), MIN_ZOOM, MAX_ZOOM)
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and drag_button != 0:
		var mask = MOUSE_BUTTON_MASK_MIDDLE if drag_button == MOUSE_BUTTON_MIDDLE else MOUSE_BUTTON_MASK_RIGHT
		if not event.button_mask & mask:
			_cancel_drag()
			return
		var sensitivity = SettingsManager.mouse_sensitivity
		target_yaw = wrapf(target_yaw - event.relative.x * sensitivity, -PI, PI)
		target_pitch = clampf(target_pitch + event.relative.y * sensitivity, MIN_PITCH, MAX_PITCH)
		get_viewport().set_input_as_handled()

func _notification(what):
	if what == NOTIFICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_cancel_drag()

func _update_camera():
	$Camera3D.position = Vector3(0, sin(pitch), cos(pitch)) * 50.0
	$Camera3D.look_at(global_position, Vector3.UP)

func _process(delta):
	var weight = 1.0 - exp(-10.0 * delta)
	rotation.y = lerp_angle(rotation.y, target_yaw, weight)
	pitch = lerpf(pitch, target_pitch, weight)
	$Camera3D.size = lerpf($Camera3D.size, target_zoom, weight)
	_update_camera()
