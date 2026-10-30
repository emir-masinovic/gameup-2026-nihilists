extends Control
var world: Node
var modal_kind = ""

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	$Modal/Rows/Close.pressed.connect(close_modal)
	$Modal/Rows/Next.pressed.connect(func(): close_modal(); SceneFlow.new_game())
	$Modal/Rows/Menu.pressed.connect(func(): close_modal(); SceneFlow.main_menu())
	$Modal/Rows/Upgrade.pressed.connect(func():
		if SaveManager.purchase_heat_resistance():
			notify("Heat Resistance purchased permanently")
		show_modal("bonfire"))

func _input(event):
	if $Modal.visible and event.is_action_pressed("pause"):
		if modal_kind == "bonfire":
			close_modal()
		get_viewport().set_input_as_handled()

func notify(message: String):
	$Toast.text = message
	$Toast/Timer.start()

func show_modal(kind: String):
	modal_kind = kind
	$Modal.show()
	$Dim.show()
	get_tree().paused = true
	$Modal/Rows/Title.text = {"bonfire": "Bonfire - safe shelter", "death": "The forest claimed this attempt", "success": "Clearing reached"}[kind]
	$Modal/Rows/Progress.text = "Knowledge: %d | Discoveries: %d\nHeat Resistance: %s" % [SaveManager.progression.knowledge, SaveManager.progression.discoveries.size(), "Owned" if SaveManager.has_heat_resistance() else "Not purchased"]
	var names: PackedStringArray = []
	for id in SaveManager.progression.discoveries:
		names.append(id.get_slice(".", 1).replace("_", " ").capitalize())
	$Modal/Rows/Progress.text += "\nDiscovered: " + (", ".join(names) if not names.is_empty() else "Explore to find something new")
	$Modal/Rows/Upgrade.visible = kind == "bonfire"
	$Modal/Rows/Upgrade.disabled = SaveManager.has_heat_resistance() or SaveManager.progression.knowledge < 3
	$Modal/Rows/Close.visible = kind == "bonfire"
	$Modal/Rows/Next.visible = kind != "bonfire"
	if kind == "bonfire":
		$Modal/Rows/Close.grab_focus()
	else:
		$Modal/Rows/Next.grab_focus()

func close_modal():
	$Modal.hide()
	$Dim.hide()
	get_tree().paused = false
	modal_kind = ""

func _on_toast_timeout():
	$Toast.text = ""
