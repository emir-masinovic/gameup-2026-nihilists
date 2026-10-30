extends PanelContainer
signal closed
var waiting_action = ""
var waiting_slot = 0
var category = "Gameplay"
var category_buttons = {}
var category_group = ButtonGroup.new()
@onready var content = $Margin/Rows/Columns/ContentPanel/ContentMargin/Scroll/Content
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

func show_category(title: String):
	category = title
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
			label("Camera projection")
			var projection = OptionButton.new()
			projection.name = "CameraProjection"
			var modes = ["Orthographic", "Perspective"]
			for mode in modes:
				projection.add_item(mode)
			projection.select(modes.find(SettingsManager.camera_projection))
			projection.item_selected.connect(func(index): SettingsManager.camera_projection = modes[index]; persist())
			content.add_child(projection)
		"Video":
			var supported = SettingsManager.desktop_display_supported()
			var full = CheckButton.new()
			full.text = "Fullscreen"
			full.button_pressed = SettingsManager.fullscreen
			full.disabled = not supported
			full.toggled.connect(func(value): SettingsManager.fullscreen = value; persist(); show_category("Video"))
			content.add_child(full)
			var sync = CheckButton.new()
			sync.text = "VSync"
			sync.button_pressed = SettingsManager.vsync
			sync.disabled = not supported
			sync.toggled.connect(func(value): SettingsManager.vsync = value; persist())
			content.add_child(sync)
			label("Window resolution")
			var sizes = SettingsManager.available_resolutions()
			var resolution_choice = OptionButton.new()
			resolution_choice.name = "Resolution"
			for size_value in sizes:
				resolution_choice.add_item("%d × %d" % [size_value.x, size_value.y])
			var selected_size = sizes.find(SettingsManager.resolution)
			if selected_size < 0 and supported:
				selected_size = sizes.find(DisplayServer.window_get_size())
			resolution_choice.select(selected_size)
			resolution_choice.disabled = not supported or SettingsManager.fullscreen
			resolution_choice.item_selected.connect(func(index): SettingsManager.resolution = sizes[index]; persist())
			content.add_child(resolution_choice)
			if SettingsManager.fullscreen:
				label("Resolution applies in windowed mode; fullscreen uses the desktop resolution.")
			label("3D anti-aliasing (MSAA)")
			var aa = OptionButton.new()
			aa.name = "MSAA"
			for text in ["Disabled", "2×", "4×"]:
				aa.add_item(text)
			aa.select(SettingsManager.msaa_3d)
			aa.item_selected.connect(func(index): SettingsManager.msaa_3d = index; persist())
			content.add_child(aa)
			label("Shadows")
			var shadows = OptionButton.new()
			shadows.name = "Shadows"
			for text in ["Off", "Low", "Medium", "High"]:
				shadows.add_item(text)
			shadows.select(SettingsManager.shadow_quality)
			shadows.item_selected.connect(func(index): SettingsManager.shadow_quality = index; persist())
			content.add_child(shadows)
			label("FPS limit")
			var fps = OptionButton.new()
			var limits = [0, 30, 60, 120]
			for value in limits:
				fps.add_item("Unlimited" if value == 0 else str(value))
			fps.select(limits.find(SettingsManager.fps_limit))
			fps.item_selected.connect(func(index): SettingsManager.fps_limit = limits[index]; persist())
			content.add_child(fps)
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
				if action == "camera_orbit":
					content.add_child(HSeparator.new())
					label("Camera")
				var row = HBoxContainer.new()
				var name_label = Label.new()
				name_label.text = {"camera_orbit": "Orbit Camera", "camera_zoom_in": "Zoom In", "camera_zoom_out": "Zoom Out"}.get(action, action.replace("_", " ").capitalize())
				name_label.custom_minimum_size.x = 140
				row.add_child(name_label)
				for slot in range(2):
					var button = Button.new()
					button.text = SettingsManager.binding_text(SettingsManager.bindings[action][slot])
					button.custom_minimum_size.x = 110
					button.pressed.connect(func(): waiting_action = action; waiting_slot = slot; status.text = "Press input for " + name_label.text + " (Esc cancels)")
					row.add_child(button)
				content.add_child(row)
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
