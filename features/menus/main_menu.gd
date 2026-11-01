extends Control
var options: Control

func _ready():
	$Panel/Rows/NewGame.pressed.connect(SceneFlow.new_game)
	$Panel/Rows/NewGame.tooltip_text = "Starts fresh. Replaces the Continue save when returning to Main Menu."
	$Panel/Rows/Continue.disabled = not SaveManager.has_resumable_run()
	$Panel/Rows/Continue.pressed.connect(func():
		if SceneFlow.continue_game() != OK:
			$Panel/Rows/Continue.disabled = true
			$Panel/Rows/Continue.tooltip_text = "Save unavailable or could not be restored.")
	$Panel/Rows/Options.pressed.connect(open_options)
	$Panel/Rows/Exit.pressed.connect(func(): get_tree().quit())
	$Panel/Rows/Exit.visible = not OS.has_feature("web")

func open_options():
	if is_instance_valid(options):
		return
	options = preload("res://features/menus/options_menu.tscn").instantiate()
	add_child(options)
	$Panel.hide()
	options.closed.connect(func(): options.queue_free(); $Panel.show(); $Panel/Rows/Options.grab_focus())

func _unhandled_key_input(event):
	if not is_instance_valid(options) and get_viewport().gui_get_focus_owner() == null:
		if event.is_action_pressed("ui_down") or event.is_action_pressed("ui_up") or event.is_action_pressed("ui_left") or event.is_action_pressed("ui_right"):
			$Panel/Rows/NewGame.grab_focus()
			get_viewport().set_input_as_handled()
