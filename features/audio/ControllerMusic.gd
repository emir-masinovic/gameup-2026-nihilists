extends Node

## Background music controller for game intro and continuous exploration loop.
## Plays on the dedicated "Music" audio bus managed by SettingsManager.

signal track_changed(track_name: String)
signal music_started
signal music_stopped

enum State { STOPPED, INTRO, LOOP }

const BUS_NAME = &"Music"
const INTRO_PATH = "res://features/audio/music_calm_exploration.mp3"
const LOOP_PATH = "res://features/audio/music_exploration_loop.mp3"
const DEFAULT_VOLUME_DB = -6.0

var player: AudioStreamPlayer
var intro_stream: AudioStreamMP3
var loop_stream: AudioStreamMP3
var current_state: State = State.STOPPED
var output: bool = false
var base_volume_db: float = DEFAULT_VOLUME_DB

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	output = AudioServer.get_driver_name() != "Dummy"
	
	_load_streams()
	_setup_player()
	
	# Start intro music on game opening
	play_intro()

func _load_streams() -> void:
	if ResourceLoader.exists(INTRO_PATH):
		intro_stream = load(INTRO_PATH) as AudioStreamMP3
		if intro_stream != null:
			intro_stream.loop = false
	if ResourceLoader.exists(LOOP_PATH):
		loop_stream = load(LOOP_PATH) as AudioStreamMP3
		if loop_stream != null:
			loop_stream.loop = true

func _setup_player() -> void:
	player = AudioStreamPlayer.new()
	player.name = "MusicPlayer"
	player.bus = BUS_NAME
	player.process_mode = Node.PROCESS_MODE_ALWAYS
	player.volume_db = base_volume_db
	player.finished.connect(_on_finished)
	add_child(player)

func play_intro() -> void:
	if intro_stream == null:
		play_loop()
		return
	
	current_state = State.INTRO
	player.stop()
	player.stream = intro_stream
	player.volume_db = base_volume_db
	if output:
		player.play()
	track_changed.emit("intro")
	music_started.emit()

func play_loop() -> void:
	if loop_stream == null:
		current_state = State.STOPPED
		return
	
	current_state = State.LOOP
	player.stop()
	player.stream = loop_stream
	player.volume_db = base_volume_db
	if output:
		player.play()
	track_changed.emit("loop")
	music_started.emit()

func stop() -> void:
	current_state = State.STOPPED
	if player != null:
		player.stop()
	music_stopped.emit()

func is_playing() -> bool:
	if output and player != null:
		return player.playing
	return current_state != State.STOPPED

func get_current_track() -> String:
	match current_state:
		State.INTRO:
			return "intro"
		State.LOOP:
			return "loop"
		_:
			return "none"

func _on_finished() -> void:
	match current_state:
		State.INTRO:
			play_loop()
		State.LOOP:
			# Fallback in case loop property did not cycle
			if output and player != null and not player.playing:
				player.play()
