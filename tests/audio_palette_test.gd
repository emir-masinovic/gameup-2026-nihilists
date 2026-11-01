extends SceneTree
class CueWorld extends Node3D:
	signal audio_cue(cue: String, at: Vector3)
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
	var adaptive = load("res://features/audio/ControllerAmbience.gd")
	check(adaptive.surface({"terrain":"grass","moisture":0.5}) == "grass","Healthy grass surface")
	check(adaptive.surface({"terrain":"soil","moisture":0.85,"tilled":true}) == "mud","Saturated farmland uses mud")
	check(adaptive.surface({"terrain":"soil","moisture":0.4}) == "dry","Prepared soil uses soil step")
	check(adaptive.surface({"terrain":"grass","moisture":0.2}) == "dry","Drought changes footsteps without biome lookup")
	check(adaptive.surface({"water":true,"water_depth":0.1}) == "wet","Shallow water takes priority")
	var quiet = adaptive.mix(0.1,false,0,1,0.2)
	var strong = adaptive.mix(0.9,true,0,1,1)
	check(strong.y > quiet.y and quiet.z == 0 and strong.z > 0,"Wind nonlinear response and rain gating")
	check(adaptive.mix(0.9,true,1,0,1).y < strong.y and adaptive.mix(0.9,true,1,0,1).z < strong.z,"Existing canopy and wind shelter attenuate weather")
	var button = Button.new()
	button.name = "ExistingConfirm"
	root.add_child(button)
	var palette = load("res://features/audio/SoundPalette.gd").new()
	root.add_child(palette)
	check(palette.ambience.voices.size() == 4,"Fixed four voices for three layers including biome crossfade")
	check(palette.ambience.load_optional("DefinitelyMissing") == null,"Missing asset safely returns null")
	check(palette._ui_voices.size() == 4, "UI pool is bounded")
	palette._hook_button(button)
	button.pressed.emit()
	check(palette.played_counts.get("ui_confirm", 0) == 1, "Existing buttons play confirm")
	check(palette.emitted_counts.get("ui_confirm", 0) == 1, "Repeated button hook does not duplicate signal callbacks")
	var back = Button.new()
	back.name = "Back"
	root.add_child(back)
	back.pressed.emit()
	check(palette.played_counts.get("ui_back", 0) == 1, "New buttons play back")
	check(not palette.play_cue("ui_back"), "Repeated UI cue is throttled")
	var world = CueWorld.new()
	world.position = Vector3(10, 0, 0)
	root.add_child(world)
	palette.attach_world(world)
	palette.attach_world(world)
	check(palette._world_voices.size() == 8, "Repeated attachment keeps eight world voices")
	for cue in ["footstep", "chop", "tree_fall", "discovery"]:
		world.audio_cue.emit(cue, Vector3(2, 0, 3))
		check(palette.played_counts.get(cue, 0) == 1, "World signal plays " + cue)
	check(palette._world_voices[0].global_position == Vector3(12, 0, 3), "World-local cue is placed globally")
	for voice in palette._ui_voices + palette._world_voices:
		check(voice.bus == &"SFX", "All voices use Settings SFX bus")
	paused = true
	check(not palette._world_voices[0].can_process(), "World voices pause with gameplay")
	check(palette.can_process(), "UI palette remains active while paused")
	check(not palette.play_cue("chop"), "Paused world does not emit new physical sounds")
	paused = false
	check(not palette.play_cue("weather_rain"), "Missing ambient recording is not substituted")
	check(palette.emitted_counts.get("weather_rain", 0) == 1, "Unsupported cues stay observable")
	world.queue_free()
	await process_frame
	check(palette._world_voices.is_empty(), "World exit clears positional voice pool")
	var next_world = CueWorld.new()
	root.add_child(next_world)
	palette.attach_world(next_world)
	check(palette._world_voices.size() == 8, "Restart creates one fresh bounded pool")
	next_world.queue_free()
	button.queue_free()
	back.queue_free()
	palette.queue_free()
	await process_frame
	await create_timer(0.1).timeout
	print("Audio palette: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
