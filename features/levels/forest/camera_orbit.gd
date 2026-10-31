extends Node3D
signal mode_changed(mode: String)

const CAMERA_MODES = ["Follow Player", "Board Center", "Free Camera"]
const MIN_ZOOM = 10.0
const FOLLOW_MIN_ZOOM = 5.0
const MAX_ZOOM = 56.0
const ZOOM_FACTOR = 0.88
var target_zoom = 42.0
var target_yaw = PI * 0.25
var target_pitch = PI * 0.25
var pitch = PI * 0.25
var drag_button = 0
var mode = "Follow Player"
var board_center = Vector3.ZERO
var free_center = Vector3.ZERO
var player_target: Node3D
var _last_default = "Follow Player"

func _ready():
	board_center = global_position
	_last_default = SettingsManager.camera_mode
	mode = _last_default
	rotation.y = target_yaw
	$Camera3D.size = target_zoom
	_apply_projection()
	SettingsManager.graphics_changed.connect(_settings_changed)
	get_tree().root.focus_exited.connect(_cancel_drag)

# Region arrivals resolve the new player/board target immediately, retaining
# orbit and zoom without carrying the old region position.
func configure_targets(center: Vector3, player: Node3D, restore: Dictionary = {}):
	board_center = center
	player_target = player
	if not restore.is_empty():
		mode = restore.get("mode", mode)
		if mode not in CAMERA_MODES:
			mode = "Follow Player"
		target_yaw = restore.get("target_yaw", restore.get("yaw", target_yaw))
		rotation.y = restore.get("yaw", target_yaw)
		target_pitch = restore.get("target_pitch", restore.get("pitch", target_pitch))
		pitch = restore.get("pitch", target_pitch)
		target_zoom = clampf(restore.get("target_zoom", restore.get("zoom", target_zoom)), _minimum_zoom(), MAX_ZOOM)
		$Camera3D.size = clampf(restore.get("zoom", target_zoom), _minimum_zoom(), MAX_ZOOM)
	free_center = global_position
	if is_instance_valid(player_target): player_target.camera_controlled = mode == "Free Camera"
	global_position = _target_position()
	_cancel_drag()
	_update_camera()

func get_transition_state() -> Dictionary:
	return {"mode": mode, "yaw": rotation.y, "target_yaw": target_yaw,
		"pitch": pitch, "target_pitch": target_pitch, "zoom": $Camera3D.size,
		"target_zoom": target_zoom}

func set_mode(value: String):
	if value not in CAMERA_MODES or value == mode:
		return
	if value == "Free Camera": free_center = global_position
	mode = value
	SettingsManager.camera_mode = mode
	_last_default = mode
	SettingsManager.save_settings()
	if is_instance_valid(player_target):
		player_target.camera_controlled = mode == "Free Camera"
		player_target.require_release = true
	target_zoom = clampf(target_zoom,_minimum_zoom(),MAX_ZOOM)
	$Camera3D.size = clampf($Camera3D.size,_minimum_zoom(),MAX_ZOOM)
	_cancel_drag()
	mode_changed.emit(mode)

func _target_position() -> Vector3:
	if mode == "Free Camera": return free_center
	if mode == "Follow Player" and is_instance_valid(player_target):
		return player_target.global_position
	return board_center

func _settings_changed():
	if _last_default != SettingsManager.camera_mode:
		_last_default = SettingsManager.camera_mode
		set_mode(_last_default)
	_apply_projection()

func _cancel_drag():
	drag_button = 0

func _input(event):
	if mode == "Free Camera" and not get_tree().paused and get_tree().root.has_focus() and event is InputEventKey and event.physical_keycode in [KEY_UP,KEY_DOWN,KEY_LEFT,KEY_RIGHT]:
		get_viewport().set_input_as_handled()
	# Release is observed even when a UI control consumes the event.
	if event is InputEventMouseButton and not event.pressed and event.button_index == drag_button:
		_cancel_drag()

func _unhandled_input(event):
	if get_tree().paused or not get_tree().root.has_focus():
		_cancel_drag()
		return
	if event.is_action_pressed("camera_mode_cycle") and not event.is_echo():
		set_mode(CAMERA_MODES[(CAMERA_MODES.find(mode) + 1) % CAMERA_MODES.size()])
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and event.pressed:
		if event.is_action_pressed("camera_orbit"):
			drag_button = event.button_index
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("camera_zoom_in"):
			target_zoom = clampf(target_zoom * pow(ZOOM_FACTOR, maxf(event.factor, 1.0)), _minimum_zoom(), MAX_ZOOM)
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("camera_zoom_out"):
			target_zoom = clampf(target_zoom / pow(ZOOM_FACTOR, maxf(event.factor, 1.0)), _minimum_zoom(), MAX_ZOOM)
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and drag_button != 0:
		var mask = 1 << (drag_button - 1)
		if not event.button_mask & mask:
			_cancel_drag()
			return
		var sensitivity = SettingsManager.mouse_sensitivity
		target_yaw = wrapf(target_yaw - event.relative.x * sensitivity, -PI, PI)
		target_pitch += event.relative.y * sensitivity
		get_viewport().set_input_as_handled()

func _notification(what):
	if what == NOTIFICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_cancel_drag()

func _apply_projection():
	$Camera3D.projection = Camera3D.PROJECTION_PERSPECTIVE if SettingsManager.camera_projection == "Perspective" else Camera3D.PROJECTION_ORTHOGONAL
	$Camera3D.fov = 55.0
	$Camera3D.near = 0.1
	$Camera3D.far = 200.0
	_update_camera()

func _update_camera():
	# Analytic yaw/pitch frame transports up through poles without horizon snaps.
	var frame = Basis(Vector3.RIGHT, -pitch)
	$Camera3D.position = frame.z * ($Camera3D.size * 1.4 if $Camera3D.projection == Camera3D.PROJECTION_PERSPECTIVE else 50.0)
	$Camera3D.basis = frame

func _process(delta):
	if get_tree().paused: return
	if mode == "Free Camera":
		var eye = $Camera3D.global_position
		var weight = 1.0-exp(-10.0*delta)
		rotation.y = lerp_angle(rotation.y,target_yaw,weight)
		pitch = lerpf(pitch,target_pitch,weight)
		_update_camera()
		global_position = eye-global_basis*$Camera3D.position
		var pan = Vector2(float(Input.is_physical_key_pressed(KEY_RIGHT))-float(Input.is_physical_key_pressed(KEY_LEFT)),float(Input.is_physical_key_pressed(KEY_DOWN))-float(Input.is_physical_key_pressed(KEY_UP)))
		if not get_tree().root.has_focus(): pan = Vector2.ZERO
		global_position += (global_basis.x*pan.x+global_basis.z*pan.y).normalized()*12.0*delta
		free_center = global_position
		$Camera3D.size = lerpf($Camera3D.size,target_zoom,weight)
		_update_camera()
		return
	var weight = 1.0 - exp(-10.0 * delta)
	global_position = global_position.lerp(_target_position(), weight)
	rotation.y = lerp_angle(rotation.y, target_yaw, weight)
	pitch = lerpf(pitch, target_pitch, weight)
	$Camera3D.size = lerpf($Camera3D.size, target_zoom, weight)
	_update_camera()

func _minimum_zoom() -> float:
	return FOLLOW_MIN_ZOOM if mode != "Board Center" else MIN_ZOOM
