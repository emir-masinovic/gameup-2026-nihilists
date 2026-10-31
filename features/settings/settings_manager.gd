extends Node
signal graphics_changed

const MAX_FPS_LIMIT = 1000
const DEFAULT_MOUSE_SENSITIVITY = 0.008
const MIN_MOUSE_SENSITIVITY = 0.002
const MAX_MOUSE_SENSITIVITY = 0.02
var mouse_sensitivity = DEFAULT_MOUSE_SENSITIVITY
var camera_projection = "Orthographic"

const DEFAULT_BINDINGS = {
	"move_north": [KEY_W, KEY_UP], "move_south": [KEY_S, KEY_DOWN],
	"move_west": [KEY_A, KEY_LEFT], "move_east": [KEY_D, KEY_RIGHT],
	"interact": [KEY_E, 0], "chop_gather": [KEY_SPACE, 0], "pause": [KEY_ESCAPE, KEY_P],
	"camera_orbit": [-MOUSE_BUTTON_MIDDLE, -MOUSE_BUTTON_RIGHT],
	"camera_zoom_in": [-MOUSE_BUTTON_WHEEL_UP, 0],
	"camera_zoom_out": [-MOUSE_BUTTON_WHEEL_DOWN, 0]
}
var storage_path = "user://settings.cfg"
var volumes = {"Master": 0.8, "Music": 0.8, "SFX": 0.8}
var bindings: Dictionary = DEFAULT_BINDINGS.duplicate(true)
var fullscreen = false
var vsync = true
var fps_limit = 60
var resolution = Vector2i(1152, 720)
var msaa_3d = Viewport.MSAA_2X
var shadow_quality = 2
var _applied_resolution = Vector2i.ZERO
var _applied_shadow = -1


func _ready():
	for bus in ["Music", "SFX"]:
		if AudioServer.get_bus_index(bus) < 0:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, bus)
			AudioServer.set_bus_send(AudioServer.bus_count - 1, "Master")
	load_settings()
	apply_settings()

func load_settings():
	var config = ConfigFile.new()
	if config.load(storage_path) != OK:
		return
	for bus in volumes:
		var value = config.get_value("audio", bus, 0.8)
		if (value is float or value is int) and is_finite(float(value)):
			volumes[bus] = clampf(float(value), 0.0, 1.0)
	var full = config.get_value("video", "fullscreen", false)
	fullscreen = full if full is bool else false
	var sync = config.get_value("video", "vsync", true)
	vsync = sync if sync is bool else true
	var fps = config.get_value("video", "fps_limit", 60)
	fps_limit = fps if fps is int and fps >= 0 and fps <= MAX_FPS_LIMIT else 60
	var size_value = config.get_value("video", "resolution", Vector2i(1152, 720))
	resolution = size_value if size_value is Vector2i and size_value.x >= 800 and size_value.y >= 600 and size_value.x <= 7680 and size_value.y <= 4320 else Vector2i(1152, 720)
	var aa = config.get_value("video", "msaa_3d", Viewport.MSAA_2X)
	msaa_3d = aa if aa is int and aa in [Viewport.MSAA_DISABLED, Viewport.MSAA_2X, Viewport.MSAA_4X] else Viewport.MSAA_2X
	var shadows = config.get_value("video", "shadow_quality", 2)
	shadow_quality = shadows if shadows is int and shadows in [0, 1, 2, 3] else 2
	var projection = config.get_value("gameplay", "camera_projection", "Orthographic")
	camera_projection = projection if projection is String and projection in ["Orthographic", "Perspective"] else "Orthographic"
	var sensitivity = config.get_value("controls", "mouse_sensitivity", DEFAULT_MOUSE_SENSITIVITY)
	mouse_sensitivity = clampf(float(sensitivity), MIN_MOUSE_SENSITIVITY, MAX_MOUSE_SENSITIVITY) if (sensitivity is float or sensitivity is int) and is_finite(float(sensitivity)) else DEFAULT_MOUSE_SENSITIVITY
	var candidate = config.get_value("controls", "bindings", {})
	if candidate is Dictionary:
		var merged = DEFAULT_BINDINGS.duplicate(true)
		for action in DEFAULT_BINDINGS:
			if candidate.has(action):
				merged[action] = candidate[action]
		var used = {}
		var valid = true
		for action in merged:
			if not merged[action] is Array or merged[action].size() != 2:
				valid = false
				break
			for code in merged[action]:
				if not code is int or not valid_code(action, code) or (code != 0 and used.has(code)):
					valid = false
					break
				if code != 0:
					used[code] = true
		if valid:
			bindings = merged

func apply_settings():
	for bus in volumes:
		AudioServer.set_bus_volume_linear(AudioServer.get_bus_index(bus), volumes[bus])
	Engine.max_fps = fps_limit
	if not OS.has_feature("web") and DisplayServer.get_name() != "headless":
		var desired_mode = DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
		var mode_changed = DisplayServer.window_get_mode() != desired_mode
		if mode_changed:
			DisplayServer.window_set_mode(desired_mode)
		if not fullscreen and (mode_changed or _applied_resolution != resolution):
			var usable = DisplayServer.screen_get_usable_rect()
			var size_value = resolution.min(usable.size)
			DisplayServer.window_set_size(size_value)
			DisplayServer.window_set_position(usable.position + (usable.size - size_value) / 2)
			_applied_resolution = resolution
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)
	get_tree().root.msaa_3d = msaa_3d
	if _applied_shadow != shadow_quality:
		RenderingServer.directional_shadow_atlas_set_size(shadow_atlas_size(), true)
		_applied_shadow = shadow_quality
	graphics_changed.emit()
	for action in bindings:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		InputMap.action_erase_events(action)
		for code in bindings[action]:
			if code == 0:
				continue
			var event: InputEvent
			if code < 0:
				event = InputEventMouseButton.new()
				event.button_index = -code
			else:
				event = InputEventKey.new()
				event.physical_keycode = code
			InputMap.action_add_event(action, event)

func save_settings() -> Error:
	var config = ConfigFile.new()
	for bus in volumes:
		config.set_value("audio", bus, volumes[bus])
	config.set_value("video", "fullscreen", fullscreen)
	config.set_value("video", "vsync", vsync)
	config.set_value("video", "fps_limit", fps_limit)
	config.set_value("video", "resolution", resolution)
	config.set_value("video", "msaa_3d", msaa_3d)
	config.set_value("video", "shadow_quality", shadow_quality)
	config.set_value("gameplay", "camera_projection", camera_projection)
	config.set_value("controls", "bindings", bindings)
	config.set_value("controls", "mouse_sensitivity", mouse_sensitivity)
	return config.save(storage_path)

func shadow_atlas_size() -> int:
	return [512, 512, 1024, 2048][shadow_quality]

func desktop_display_supported() -> bool:
	return not OS.has_feature("web") and DisplayServer.get_name() != "headless"

func available_resolutions() -> Array[Vector2i]:
	var sizes: Array[Vector2i] = []
	var maximum = DisplayServer.screen_get_usable_rect().size if desktop_display_supported() else Vector2i(1920, 1080)
	var candidates = [Vector2i(800, 600), Vector2i(1024, 768), Vector2i(1152, 720), Vector2i(1280, 720), Vector2i(1366, 768), Vector2i(1600, 900), Vector2i(1920, 1080), resolution]
	if desktop_display_supported() and not fullscreen:
		candidates.append(DisplayServer.window_get_size())
	for size_value in candidates:
		if size_value.x >= 800 and size_value.y >= 600 and size_value.x <= maximum.x and size_value.y <= maximum.y and not sizes.has(size_value):
			sizes.append(size_value)
	sizes.sort_custom(func(a, b): return a.x < b.x if a.x != b.x else a.y < b.y)
	return sizes

func _reset_category(category: String):
	match category:
		"Gameplay":
			camera_projection = "Orthographic"
		"Audio":
			volumes = {"Master": 0.8, "Music": 0.8, "SFX": 0.8}
		"Controls":
			mouse_sensitivity = DEFAULT_MOUSE_SENSITIVITY
			bindings = DEFAULT_BINDINGS.duplicate(true)
		"Video":
			fullscreen = false
			vsync = true
			fps_limit = 60
			resolution = Vector2i(1152, 720)
			msaa_3d = Viewport.MSAA_2X
			shadow_quality = 2

func reset_category(category: String) -> Error:
	if category not in ["Gameplay", "Audio", "Video", "Controls"]:
		return ERR_UNAVAILABLE
	_reset_category(category)
	apply_settings()
	return save_settings()

func reset_defaults() -> Error:
	for category in ["Gameplay", "Audio", "Video", "Controls"]:
		_reset_category(category)
	apply_settings()
	return save_settings()

func rebind(action: String, slot: int, code: int) -> String:
	if not bindings.has(action) or slot not in [0, 1] or not valid_code(action, code):
		return "Invalid binding."
	for other in bindings:
		for index in range(2):
			if code != 0 and bindings[other][index] == code and (other != action or index != slot):
				return "Already assigned to " + other.replace("_", " ") + "."
	bindings[action][slot] = code
	apply_settings()
	return "" if save_settings() == OK else "Could not save controls."

func valid_code(action: String, code: int) -> bool:
	if code == 0:
		return true
	if action == "camera_orbit":
		return -code in [1, 2, 3, 8, 9]
	if action.begins_with("camera_"):
		return code < 0 and -code in range(1, 10)
	return code > 0 or -code in range(1, 10)

func binding_text(code: int) -> String:
	if code == 0:
		return "Unbound"
	if code > 0:
		return OS.get_keycode_string(code)
	return {1: "Left Mouse", 2: "Right Mouse", 3: "Middle Mouse", 4: "Wheel Up", 5: "Wheel Down", 6: "Wheel Left", 7: "Wheel Right", 8: "Mouse 4", 9: "Mouse 5"}.get(-code, "Mouse")
