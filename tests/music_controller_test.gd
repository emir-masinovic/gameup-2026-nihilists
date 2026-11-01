extends SceneTree

var checks: int = 0
var failures: int = 0

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var music_script = load("res://features/audio/ControllerMusic.gd")
	check(music_script != null, "ControllerMusic script exists")
	
	var music = music_script.new()
	root.add_child(music)
	
	check(music.player != null, "MusicPlayer is created")
	check(music.player.bus == &"Music", "Music player routed to Music bus")
	check(music.player.process_mode == Node.PROCESS_MODE_ALWAYS, "Music plays continuously regardless of pause")
	check(music.intro_stream != null, "Intro stream loaded")
	check(music.loop_stream != null, "Loop stream loaded")
	check(not music.intro_stream.loop, "Intro stream does not loop")
	check(music.loop_stream.loop, "Loop stream has loop enabled")
	check(music.get_current_track() == "intro", "Intro track starts at game opening")
	check(music.player.stream == music.intro_stream, "Player stream assigned to intro stream")
	
	var events: Array[String] = []
	music.track_changed.connect(func(track): events.append(track))
	
	# Simulate intro finishing -> should transition to loop track
	music._on_finished()
	check(music.get_current_track() == "loop", "Transitions to loop track on intro finish")
	check(music.player.stream == music.loop_stream, "Player stream assigned to loop stream")
	check(events.size() == 1 and events[0] == "loop", "track_changed signal emitted for loop")
	
	# Test stop
	music.stop()
	check(music.get_current_track() == "none", "Track is none after stop")
	check(not music.is_playing(), "is_playing is false after stop")
	
	# Test manual intro restart
	music.play_intro()
	check(music.get_current_track() == "intro", "play_intro restarts intro track")
	
	music.queue_free()
	
	# Test integration inside SoundPalette
	var palette = load("res://features/audio/SoundPalette.gd").new()
	root.add_child(palette)
	check(palette.music != null, "SoundPalette owns music controller instance")
	check(palette.music.player.bus == &"Music", "Integrated music controller uses Music bus")
	check(palette.music.get_current_track() == "intro", "Integrated music starts on intro track")
	
	palette.queue_free()
	await process_frame
	
	print("Music Controller: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
