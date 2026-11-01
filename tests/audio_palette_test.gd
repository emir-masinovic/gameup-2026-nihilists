extends SceneTree
class FreeRig extends Node3D:
	var mode = "Free Camera"
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
	check(adaptive.surface({"terrain":"grass","moisture":0.95,"health":0.95}) == "grass","Dense wet living grass is not exposed mud")
	check(adaptive.surface({"terrain":"grass","moisture":0.95,"health":0.2}) == "mud","Exposed wet degraded ground uses mud")
	check(adaptive.surface({"terrain":"grass","moisture":0.2,"health":0.2}) == "dry","Dry sparse vegetation uses dry step")
	check(adaptive.surface({"terrain":"soil","moisture":0.4,"prepared":true}) == "mud","Prepared soil never suppresses contact playback")
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
	check(palette._streams.step_mud[0].resource_path.ends_with("footstep_grass_000.ogg"),"Mud and cultivated soil reuse the approved existing OGG")
	check(palette._streams.footstep[0].resource_path.ends_with("SoundStepGrass.mp3") and palette._streams.step_dry[0].resource_path.ends_with("SoundStepDry.mp3") and palette._streams.step_wet[0].resource_path.ends_with("SoundStepWet.mp3"),"Grass Dry Wet samples unchanged")
	var controller = palette.ambience
	controller.camera_presence = adaptive.presence(7)
	var close = controller.category_gain("footstep")
	check(is_equal_approx(close,1.10) and controller.category_gain("ui_confirm") == 1.0,"Close gains bounded; UI unaffected")
	controller.camera_presence = adaptive.presence(56)
	check(is_equal_approx(controller.category_gain("footstep"),0.55) and controller.category_gain("ambience") > 0.0,"Far gains quieter but ambience remains audible")
	check(adaptive.presence(20) > adaptive.presence(40),"Camera response continuous across framing range")
	var camera = Camera3D.new()
	var actor = Node3D.new()
	root.add_child(camera)
	root.add_child(actor)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 12
	check(adaptive.camera_framing(camera,actor) == 12,"Orthographic framing uses visible size rather than fixed 50-unit eye")
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.position = Vector3(0,0,56)
	check(is_equal_approx(adaptive.camera_framing(camera,actor),40),"Perspective framing uses actual eye distance")
	var rig = FreeRig.new()
	root.add_child(rig)
	camera.reparent(rig)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 12
	camera.global_position = Vector3(0,0,140)
	check(adaptive.camera_framing(camera,actor) >= 100,"Free camera distance prevents falsely intimate distant framing")
	camera.free()
	rig.free()
	actor.free()
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
