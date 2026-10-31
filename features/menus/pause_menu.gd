extends Control
var options: Control
var perks_hud: Control
var previous_hud_layer = 0

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	$Panel/Rows/Resume.pressed.connect(SceneFlow.resume)
	$Panel/Rows/Options.pressed.connect(open_options)
	$Panel/Rows/Perks.pressed.connect(open_perks)
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
	if is_instance_valid(perks_hud):
		perks_hud.close_modal()
	elif is_instance_valid(options):
		options.close()
	else:
		SceneFlow.resume()

func open_perks():
	var scene = get_tree().current_scene
	if scene == null or scene.get("hud") == null: return
	perks_hud = scene.hud
	previous_hud_layer = perks_hud.get_parent().layer
	perks_hud.get_parent().layer = 21
	$Panel.hide()
	perks_hud.perks_closed.connect(func():
		perks_hud.get_parent().layer = previous_hud_layer
		perks_hud = null
		$Panel.show()
		$Panel/Rows/Perks.grab_focus(),CONNECT_ONE_SHOT)
	perks_hud.show_modal("perks")
