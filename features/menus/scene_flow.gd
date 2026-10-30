extends Node

const MAIN_MENU = "res://features/menus/main_menu.tscn"
var playable_scene: String = ProjectSettings.get_setting("application/run/playable_scene", "res://features/levels/prototype/prototype.tscn")
var next_seed: int = 2026
var pause_menu: Control
var pause_layer: CanvasLayer

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS

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
	next_seed = int((Time.get_ticks_usec() + next_seed * 1664525) % 2147483647)
	transition(playable_scene)

func main_menu():
	transition(MAIN_MENU)

func open_pause():
	if pause_menu != null:
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
