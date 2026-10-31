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
	run_regions = null
	region_arrival_from = ""
	camera_state.clear()
	region_transitioning = false
	next_seed = int((Time.get_ticks_usec() + next_seed * 1664525) % 2147483647)
	transition(playable_scene)

func main_menu():
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
