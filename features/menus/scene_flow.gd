extends Node

const MAIN_MENU = "res://features/menus/main_menu.tscn"
var playable_scene: String = ProjectSettings.get_setting("application/run/playable_scene", "res://features/levels/prototype/prototype.tscn")
var next_seed: int = 2026
var pause_menu: Control
var pause_layer: CanvasLayer
var run_regions: RefCounted
var region_arrival_from = ""
var region_transitioning = false
var camera_state = {}
var sounds: Node
var pending_restore = {}

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	sounds = preload("res://features/audio/SoundPalette.gd").new()
	add_child(sounds)

func _unhandled_key_input(event):
	if event.is_action_pressed("pause") and not event.is_echo():
		if get_tree().current_scene != null and get_tree().current_scene.scene_file_path != MAIN_MENU:
			if pause_menu == null:
				open_pause()
			else:
				pause_menu.close_top_panel()
			get_viewport().set_input_as_handled()

func transition(path: String) -> Error:
	resume()
	return get_tree().change_scene_to_file(path)

func new_game():
	var error = SaveManager.reset_progression()
	if error != OK:
		push_error("Could not start a fresh game: progression reset failed")
		return error
	return retry_game()

# A new attempt within the same save retains earned progression.
func retry_game():
	pending_restore.clear()
	run_regions = null
	region_arrival_from = ""
	camera_state.clear()
	region_transitioning = false
	next_seed = int((Time.get_ticks_usec() + next_seed * 1664525) % 2147483647)
	return transition(playable_scene)

func continue_game():
	var data = SaveManager.read_run()
	if data == null: return ERR_INVALID_DATA
	var restored = SaveManager.RunSave.restore(data)
	if restored == null or not SaveManager.restore_extensions(restored,data.get("extensions",{})): return ERR_INVALID_DATA
	var error = SaveManager.save_progression(data.progression)
	if error != OK: return error
	run_regions = restored
	next_seed = data.seed
	camera_state = data.camera
	pending_restore = data
	region_arrival_from = ""
	return transition(playable_scene)

func main_menu():
	var world = get_tree().current_scene
	if world != null and world.get("regions") != null and not world.get("ended"):
		var error = SaveManager.save_run(world)
		if error != OK:
			var dialog = AcceptDialog.new()
			dialog.name = "SaveError"
			dialog.title = "Could not save"
			dialog.dialog_text = "Your game is still open. Please try returning to Main Menu again."
			get_tree().root.add_child(dialog)
			dialog.confirmed.connect(dialog.queue_free)
			dialog.canceled.connect(dialog.queue_free)
			dialog.popup_centered()
			return error
	if is_instance_valid(sounds): sounds.ambience.stop_world()
	run_regions = null
	region_arrival_from = ""
	camera_state.clear()
	region_transitioning = false
	transition(MAIN_MENU)

func open_pause():
	if pause_menu != null or region_transitioning:
		return
	pause_menu = preload("res://features/menus/pause_menu.tscn").instantiate()
	pause_layer = CanvasLayer.new()
	pause_layer.layer = 20
	get_tree().root.add_child(pause_layer)
	pause_layer.add_child(pause_menu)
	get_tree().paused = true

func resume():
	get_tree().paused = false
	if is_instance_valid(pause_layer):
		pause_layer.queue_free()
	pause_layer = null
	pause_menu = null

func change_region(destination: String) -> Error:
	if run_regions == null or get_tree().paused:
		return ERR_UNAVAILABLE
	var previous: String = run_regions.current_id
	var connected = (previous == "forest" and destination in ["drylands", "wetlands"]) or (destination == "forest" and previous in ["drylands", "wetlands"])
	if not connected:
		return ERR_INVALID_PARAMETER
	region_arrival_from = previous
	run_regions.enter(destination)
	return transition(playable_scene)
