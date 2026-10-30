extends Control
var options: Control

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	$Panel/Rows/Resume.pressed.connect(SceneFlow.resume)
	$Panel/Rows/Options.pressed.connect(open_options)
	$Panel/Rows/MainMenu.pressed.connect(SceneFlow.main_menu)
	$Panel/Rows/Exit.pressed.connect(func(): get_tree().quit())
	$Panel/Rows/Exit.visible = not OS.has_feature("web")
	$Panel/Rows/Resume.grab_focus()

func open_options():
	if is_instance_valid(options):
		return
	options = preload("res://features/menus/options_menu.tscn").instantiate()
	add_child(options)
	$Panel.hide()
	options.closed.connect(func(): options.queue_free(); $Panel.show(); $Panel/Rows/Options.grab_focus())

func close_top_panel():
	if is_instance_valid(options):
		options.close()
	else:
		SceneFlow.resume()
