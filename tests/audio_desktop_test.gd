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
	AudioServer.remove_bus_effect(bus, AudioServer.get_bus_effect_count(bus) - 1)
	settings.apply_settings()
	flow.main_menu()
	await process_frame
	await create_timer(0.3).timeout
	if FileAccess.file_exists(saves.storage_path): DirAccess.remove_absolute(saves.storage_path)
	print("AUDIO DESKTOP driver=", driver, " failures=", failures)
	quit(0 if failures == 0 else 1)
