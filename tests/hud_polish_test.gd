extends SceneTree
var checks = 0
var failures = 0
func check(value, message):
	checks += 1
	if not value:
		failures += 1
		push_error(message)
func _initialize():
	call_deferred("run")
func run():
	var saves = root.get_node("SaveManager")
	saves.storage_path = "user://hud_polish_test.json"
	saves.load_progression()
	var flow = root.get_node("SceneFlow")
	flow.new_game()
	await process_frame
	await process_frame
	var world = current_scene
	world.set_process(false)
	var hud = world.hud
	hud.update_status(64, 32, 30, "rain", 2.5, 7, false, false)
	check(hud.get_node("PlayerStatus/Rows/Health/Bar").value == 64, "Health bar")
	check(hud.get_node("PlayerStatus/Rows/Heat/Bar").value == 32, "Heat bar")
	check(hud.get_node("WorldStatus/Rows/Climate/Icon").weather == "rain", "Weather icon")
	check(hud.get_node("WorldStatus/Rows/Knowledge/Value").text == "7 Knowledge", "Knowledge display")
	check(not hud.has_node("Stats") and not hud.has_node("Objective"), "No debug or quest block")
	check(hud.get_node("Context").text == "", "Context hidden away from bonfire")
	hud.update_status(100, 0, 24, "clear", 0, 0, true, false)
	check(hud.get_node("Context").text.contains("Bonfire"), "Bonfire context relevant")
	for viewport_size in [Vector2i(1152,720), Vector2i(800,600)]:
		root.size = viewport_size
		await process_frame
		for panel in ["PlayerStatus", "WorldStatus"]:
			check(root.get_visible_rect().grow(1).encloses(hud.get_node(panel).get_global_rect()), "Status fits viewport")
	flow.open_pause()
	flow.pause_menu.open_options()
	await process_frame
	check(paused and flow.pause_layer.layer > hud.get_canvas_layer_node().layer, "Options covers compact HUD")
	check(flow.pause_menu.options.get_theme_stylebox("panel").bg_color.a == 1, "Options opaque")
	flow.pause_menu.options.back_button.pressed.emit()
	await process_frame
	check(paused, "Back keeps pause")
	flow.resume()
	flow.main_menu()
	await process_frame
	await process_frame
	if FileAccess.file_exists(saves.storage_path):
		DirAccess.remove_absolute(saves.storage_path)
	print("HUD POLISH: ", checks, " checks, ", failures, " failures")
	quit(0 if failures == 0 else 1)
