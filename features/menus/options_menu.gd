extends PanelContainer
signal closed
var waiting_action = ""
var waiting_slot = 0
var category = "Gameplay"
var category_buttons = {}
var category_group = ButtonGroup.new()
@onready var content = $Margin/Rows/Columns/ContentPanel/ContentMargin/Scroll/ContentPadding/Content
@onready var status = $Margin/Rows/Status
@onready var back_button = $Margin/Rows/Footer/Back
@onready var defaults_button = $Margin/Rows/Footer/Defaults

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	for title in ["Gameplay", "Video", "Audio", "Controls"]:
		var button = Button.new()
		button.text = title
		button.toggle_mode = true
		button.button_group = category_group
		button.add_theme_stylebox_override("pressed", preload("res://features/menus/style_category_active.tres"))
		category_buttons[title] = button
		button.custom_minimum_size.y = 44
		button.pressed.connect(show_category.bind(title))
		$Margin/Rows/Columns/Sidebar.add_child(button)
	back_button.pressed.connect(close)
	defaults_button.pressed.connect(restore_category)
	show_category("Gameplay")
	back_button.grab_focus()

func close():
	waiting_action = ""
	closed.emit()

func _input(event):
	var pressed_key = event is InputEventKey and event.pressed and not event.echo
	var pressed_mouse = event is InputEventMouseButton and event.pressed
	if waiting_action != "" and (pressed_key or pressed_mouse):
		# GUI buttons emit pressed on release, after _input; that release cannot bind itself.
		if pressed_key and event.keycode == KEY_ESCAPE:
			waiting_action = ""
			status.text = "Binding cancelled."
		else:
			var code = event.physical_keycode if pressed_key else -event.button_index
			var message = SettingsManager.rebind(waiting_action, waiting_slot, code)
			waiting_action = ""
			show_category("Controls")
			status.text = "Binding saved." if message == "" else message
		get_viewport().set_input_as_handled()
	elif pressed_key and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause")):
		close()
		get_viewport().set_input_as_handled()

func label(text: String):
	var node = Label.new()
	node.text = text
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(node)

func persist():
	SettingsManager.apply_settings()
	status.text = "Saved." if SettingsManager.save_settings() == OK else "Could not save settings."

# All settings share one label column and one expanding control column.
func setting_row(title: String, control: Control, control_name: String) -> HBoxContainer:
	var row = HBoxContainer.new()
	row.name = control_name + "Row"
	row.add_theme_constant_override("separation", 12)
	var caption = Label.new()
	caption.name = "SettingLabel"
	caption.text = title
	caption.custom_minimum_size.x = 180
	row.add_child(caption)
	control.name = control_name
	control.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN if control is CheckBox else Control.SIZE_EXPAND_FILL
	if control_name in ["Resolution", "FPSLimit"]:
		control.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		control.custom_minimum_size.x = 200 if control_name == "Resolution" else 110
	row.add_child(control)
	content.add_child(row)
	return row

func segmented_control(options: Array, selected: int, on_selected: Callable) -> HBoxContainer:
	var segments = HBoxContainer.new()
	segments.add_theme_constant_override("separation", 4)
	var group = ButtonGroup.new()
	for index in options.size():
		var button = Button.new()
		button.name = options[index]
		button.text = str(options[index]).replace("2x", "2\u00d7").replace("4x", "4\u00d7")
		button.toggle_mode = true
		button.button_group = group
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.button_pressed = index == selected
		button.pressed.connect(on_selected.bind(index))
		segments.add_child(button)
	# Equal minima plus equal stretch keep segments equal while allowing resize.
	var minimum_width = 0.0
	for button in segments.get_children():
		minimum_width = maxf(minimum_width, button.get_combined_minimum_size().x)
	for button in segments.get_children():
		button.custom_minimum_size.x = minimum_width
	return segments

func binding_row(action: String) -> HBoxContainer:
	var row = HBoxContainer.new()
	row.name = "Binding" + action
	row.add_theme_constant_override("separation", 12)
	var caption = Label.new()
	caption.name = "ActionLabel"
	caption.text = {"camera_mode_cycle": "Cycle Camera Mode", "camera_orbit": "Orbit Camera", "camera_zoom_in": "Zoom In", "camera_zoom_out": "Zoom Out"}.get(action, action.replace("_", " ").capitalize())
	caption.custom_minimum_size.x = 180
	row.add_child(caption)
	for slot in range(2):
		var button = Button.new()
		button.name = "Primary" if slot == 0 else "Secondary"
		button.text = SettingsManager.binding_text(SettingsManager.bindings[action][slot])
		button.custom_minimum_size.x = 140
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(func(): waiting_action = action; waiting_slot = slot; status.text = "Press input for " + caption.text + " (Esc cancels)")
		row.add_child(button)
	content.add_child(row)
	return row

# Editing never changes the saved cap until Enter or focus loss.
func commit_fps(field: LineEdit):
	var value = field.text.strip_edges()
	if not value.is_valid_int() or value.begins_with("+") or value.begins_with("-") or int(value) < 0 or int(value) > SettingsManager.MAX_FPS_LIMIT:
		field.text = str(SettingsManager.fps_limit)
		status.text = "Enter a whole number from 0 to 1000 (0 = Unlimited)."
		return
	var cap = int(value)
	field.text = str(cap)
	if cap != SettingsManager.fps_limit:
		SettingsManager.fps_limit = cap
		persist()

func show_category(title: String):
	category = title
	content.get_parent().add_theme_constant_override("margin_right", 12 if title == "Controls" else 0)
	for name in category_buttons:
		category_buttons[name].set_pressed_no_signal(name == title)
	defaults_button.disabled = false
	waiting_action = ""
	for child in content.get_children():
		content.remove_child(child)
		child.queue_free()
	status.text = ""
	match title:
		"Gameplay":
			var camera_modes = SettingsManager.CAMERA_MODES
			var camera_mode = OptionButton.new()
			for mode_name in camera_modes:
				camera_mode.add_item(mode_name)
			camera_mode.select(camera_modes.find(SettingsManager.camera_mode))
			camera_mode.item_selected.connect(func(index): SettingsManager.camera_mode = camera_modes[index]; persist())
			setting_row("Default camera mode", camera_mode, "CameraMode")
			label("Cycle modes with the camera mode binding. In Free Camera, hold Shift while dragging the orbit button to pan.")
			var modes = ["Orthographic", "Perspective"]
			var projection = segmented_control(modes, modes.find(SettingsManager.camera_projection), func(index): SettingsManager.camera_projection = modes[index]; persist())
			projection.add_theme_constant_override("separation", 12)
			setting_row("Camera projection", projection, "CameraProjection")
		"Video":
			var supported = SettingsManager.desktop_display_supported()
			var full = compact_checkbox()
			full.button_pressed = SettingsManager.fullscreen
			full.disabled = not supported
			full.toggled.connect(func(value): SettingsManager.fullscreen = value; persist(); show_category("Video"))
			setting_row("Fullscreen", full, "Fullscreen")
			var sync = compact_checkbox()
			sync.button_pressed = SettingsManager.vsync
			sync.disabled = not supported
			sync.toggled.connect(func(value): SettingsManager.vsync = value; persist())
			setting_row("VSync", sync, "VSync")
			var sizes = SettingsManager.available_resolutions()
			var resolution_choice = OptionButton.new()
			for size_value in sizes:
				resolution_choice.add_item("%d × %d" % [size_value.x, size_value.y])
			var selected_size = sizes.find(SettingsManager.resolution)
			if selected_size < 0 and supported:
				selected_size = sizes.find(DisplayServer.window_get_size())
			resolution_choice.select(selected_size)
			resolution_choice.disabled = not supported or SettingsManager.fullscreen
			resolution_choice.item_selected.connect(func(index): SettingsManager.resolution = sizes[index]; persist())
			setting_row("Window resolution", resolution_choice, "Resolution")
			if SettingsManager.fullscreen:
				label("Resolution applies in windowed mode; fullscreen uses the desktop resolution.")
			setting_row("3D anti-aliasing", segmented_control(["Off", "2x", "4x"], SettingsManager.msaa_3d, func(index): SettingsManager.msaa_3d = index; persist()), "MSAA")
			setting_row("Shadows", segmented_control(["Off", "Low", "Medium", "High"], SettingsManager.shadow_quality, func(index): SettingsManager.shadow_quality = index; persist()), "Shadows")
			var fps = LineEdit.new()
			fps.text = str(SettingsManager.fps_limit)
			fps.placeholder_text = "0 = Unlimited"
			fps.tooltip_text = "0 = Unlimited"
			fps.text_submitted.connect(func(_text): commit_fps(fps))
			fps.focus_exited.connect(func(): commit_fps(fps))
			setting_row("FPS limit", fps, "FPSLimit")
			if not supported:
				label("Window mode and VSync are controlled by the browser or display backend.")
		"Audio":
			for bus in ["Master", "Music", "SFX"]:
				label(bus)
				var slider = HSlider.new()
				slider.min_value = 0
				slider.max_value = 1
				slider.step = 0.01
				slider.value = SettingsManager.volumes[bus]
				slider.custom_minimum_size = Vector2(260, 30)
				slider.value_changed.connect(func(value): SettingsManager.volumes[bus] = value; persist())
				content.add_child(slider)
		"Controls":
			for action in SettingsManager.bindings:
				if action == "camera_mode_cycle":
					content.add_child(HSeparator.new())
					label("Camera")
				binding_row(action)
			label("Mouse Sensitivity")
			var sensitivity = HSlider.new()
			sensitivity.name = "MouseSensitivity"
			sensitivity.min_value = SettingsManager.MIN_MOUSE_SENSITIVITY
			sensitivity.max_value = SettingsManager.MAX_MOUSE_SENSITIVITY
			sensitivity.step = 0.001
			sensitivity.value = SettingsManager.mouse_sensitivity
			sensitivity.custom_minimum_size = Vector2(260, 30)
			sensitivity.value_changed.connect(func(value): SettingsManager.mouse_sensitivity = value; persist())
			content.add_child(sensitivity)

func restore_category():
	var error = SettingsManager.reset_category(category)
	show_category(category)
	status.text = "Defaults restored." if error == OK else "Could not restore defaults."

func compact_checkbox() -> CheckBox:
	var checkbox = CheckBox.new()
	checkbox.add_theme_icon_override("checked", load("res://features/menus/icons/checkbox_checked.svg"))
	checkbox.add_theme_icon_override("unchecked", load("res://features/menus/icons/checkbox_unchecked.svg"))
	for style in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		checkbox.add_theme_stylebox_override(style, StyleBoxEmpty.new())
	return checkbox
