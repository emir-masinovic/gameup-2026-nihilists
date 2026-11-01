extends SceneTree
var failures = 0
func _initialize():
	call_deferred("run")
func check(value, message):
	if not value:
		failures += 1
		push_error(message)
func run():
	var settings = root.get_node("SettingsManager")
	settings.storage_path = "user://audio_desktop_settings.cfg"
	var saves = root.get_node("SaveManager")
	saves.storage_path = "user://audio_desktop_progression.json"
	saves.load_progression()
	var flow = root.get_node("SceneFlow")
	flow.next_seed = 2026
	flow.transition(flow.playable_scene)
	await process_frame
	await process_frame
	current_scene.set_process(false)
	var bus = AudioServer.get_bus_index("SFX")
	var capture = AudioEffectCapture.new()
	AudioServer.add_bus_effect(bus, capture)
	AudioServer.set_bus_mute(bus, false)
	AudioServer.set_bus_volume_db(bus, 0.0)
	var driver = AudioServer.get_driver_name()
	check(driver != "Dummy", "Actual audio driver required")
	for cue in ["ui_confirm", "ui_back", "footstep", "chop", "tree_fall", "discovery"]:
		capture.clear_buffer()
		check(flow.sounds.play_cue(cue, Vector3.ZERO), "Dispatch " + cue)
		await create_timer(0.85).timeout
		var samples = capture.get_buffer(capture.get_frames_available())
		var peak = 0.0
		for sample in samples:
			peak = maxf(peak, maxf(absf(sample.x), absf(sample.y)))
		check(peak > 0.0001, "Nonzero SFX audio waveform for " + cue)
		print("AUDIO WAVEFORM ", cue, " peak=", peak, " samples=", samples.size())
	# Capture each unmodified generated MP3 to verify decoding, duration, silence
	# and peaks using the actual desktop audio driver. Not a perceptual review.
	flow.sounds.ambience.set_process(false)
	for ambient_voice in flow.sounds.ambience.voices: ambient_voice.stop()
	var probe = AudioStreamPlayer.new()
	probe.bus = &"SFX"
	root.add_child(probe)
	for id in ["AmbienceForest","AmbienceWetlands","AmbienceDrylands","AmbienceWind","AmbienceRain","SoundStepGrass","SoundStepMud","SoundStepDry","SoundStepWet","SoundRaindrop","SoundFrog"]:
		var path = "res://features/audio/"+id+".mp3"
		check(ResourceLoader.exists(path),"Generated asset exists "+id)
		if not ResourceLoader.exists(path): continue
		var stream = load(path)
		stream.loop = false
		check(stream.get_length() > 0.35 and stream.get_length() < 4.0,"Expected short clip duration "+id)
		capture.clear_buffer()
		probe.stream = stream
		probe.play()
		var peak = 0.0
		var frames = 0
		var clipped = 0
		var energy = 0.0
		for sample_tick in range(ceili((stream.get_length()+0.15)*10)):
			await create_timer(0.1).timeout
			var samples = capture.get_buffer(capture.get_frames_available())
			for sample in samples:
				peak = maxf(peak,maxf(absf(sample.x),absf(sample.y)))
				energy += sample.length_squared()
				if absf(sample.x) >= 0.9999 or absf(sample.y) >= 0.9999: clipped += 1
			frames += samples.size()
		check(peak > 0.0001,"Decoded non-silent "+id)
		print("GENERATED AUDIO ",id," duration=",stream.get_length()," peak=",peak," clipped_frames=",clipped," rms=",sqrt(energy/maxf(1,frames*2)))
		if id.begins_with("Ambience"): stream.loop = true
	probe.queue_free()
	var controller = flow.sounds.ambience
	controller.set_process(true)
	controller._sample(current_scene)
	check(controller.biome == "forest","Forest biome selected")
	var wind_stream = controller.voices[2].stream
	for destination in ["wetlands","forest","drylands","forest"]:
		flow.change_region(destination)
		await process_frame
		await process_frame
		current_scene.set_process(false)
		controller._sample(current_scene)
		check(controller.biome == destination and controller.voices.size() == 4,"Bounded biome transition "+destination)
		check(controller.voices[2].stream == wind_stream,"Wind resource survives region change")
	current_scene.climate.weather_override = "rain"
	current_scene.climate.tick(1)
	controller._sample(current_scene)
	check(controller.targets[3] > -80,"Rain audio responds to simulation")
	current_scene.climate.weather_override = "clear"
	current_scene.climate.tick(1)
	controller._sample(current_scene)
	check(controller.targets[3] == -80,"Clear weather silences rain target")
	paused = true
	controller._process(0.1)
	check(controller.voices[2].stream_paused,"Pause suspends environment playback")
	paused = false
	AudioServer.remove_bus_effect(bus, AudioServer.get_bus_effect_count(bus) - 1)
	settings.apply_settings()
	flow.main_menu()
	await process_frame
	await create_timer(3.0).timeout
	check(controller.targets.all(func(value): return value == -80.0) and controller.voices.all(func(voice): return not voice.playing),"Main menu releases all continuous world audio")
	if FileAccess.file_exists(saves.storage_path): DirAccess.remove_absolute(saves.storage_path)
	print("AUDIO DESKTOP driver=", driver, " failures=", failures)
	quit(0 if failures == 0 else 1)
