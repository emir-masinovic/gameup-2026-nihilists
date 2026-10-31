extends Node
## Small licensed forest/UI palette. Owns no simulation or audio-bus settings.
const SFX_BUS = &"SFX"
const UI_VOICE_LIMIT = 4
const WORLD_VOICE_LIMIT = 8
const FILES = {
	"ui_confirm": ["confirmation_001.ogg"],
	"ui_back": ["back_001.ogg"],
	"discovery": ["pluck_001.ogg"],
	"footstep": ["footstep_grass_000.ogg", "footstep_grass_001.ogg", "footstep_grass_002.ogg"],
	"chop": ["impactWood_medium_000.ogg"],
	"tree_fall": ["impactWood_heavy_000.ogg"],
}
const LEVELS = {"ui_confirm": -17.0, "ui_back": -17.0, "discovery": -13.0,
	"footstep": -12.0, "chop": -9.0, "tree_fall": -7.0}
var emitted_counts: Dictionary = {}
# Counts dispatched voices; a Dummy driver has no audible output.
var played_counts: Dictionary = {}
var _has_audio_output = false
var _streams: Dictionary = {}
var _last_played: Dictionary = {}
var _variation: Dictionary = {}
var _ui_voices: Array[AudioStreamPlayer] = []
var _world_voices: Array[AudioStreamPlayer3D] = []
var _world_ref: WeakRef
var _ui_index = 0
var _world_index = 0

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Headless Dummy playback retains queued Vorbis decoders at immediate exit.
	# Keep real streams/routing testable without submitting work to a missing device.
	_has_audio_output = AudioServer.get_driver_name() != "Dummy"
	for cue in FILES:
		var clips: Array[AudioStream] = []
		for filename in FILES[cue]:
			var clip = load("res://features/audio/" + filename) as AudioStream
			if clip != null:
				clips.append(clip)
		_streams[cue] = clips
	for i in UI_VOICE_LIMIT:
		var voice = AudioStreamPlayer.new()
		voice.name = "SoundUI%d" % i
		voice.bus = SFX_BUS
		add_child(voice)
		_ui_voices.append(voice)
	get_tree().node_added.connect(_hook_button)
	for button in get_tree().root.find_children("*", "BaseButton", true, false):
		_hook_button(button)

func _exit_tree():
	_detach_world()
	for voice in _ui_voices:
		voice.stop()
		voice.stream = null
	_streams.clear()

func _hook_button(node: Node):
	if node is BaseButton and node.get_meta("sound_palette_owner", 0) != get_instance_id():
		node.set_meta("sound_palette_owner", get_instance_id())
		node.pressed.connect(_on_button_pressed.bind(weakref(node)))

func _on_button_pressed(button_ref: WeakRef):
	var button = button_ref.get_ref() as BaseButton
	if button == null or button.disabled:
		return
	var label = str(button.name).to_lower()
	if button is Button:
		label += " " + button.text.to_lower()
	var back = false
	for word in ["back", "close", "cancel", "return", "resume"]:
		if word in label:
			back = true
			break
	play_cue("ui_back" if back else "ui_confirm")

func attach_world(world: Node3D):
	if _world_ref != null and _world_ref.get_ref() == world:
		return
	_detach_world()
	if world == null or not world.has_signal("audio_cue"):
		return
	_world_ref = weakref(world)
	world.connect("audio_cue", _on_world_cue)
	world.tree_exiting.connect(_detach_world, CONNECT_ONE_SHOT)
	for i in WORLD_VOICE_LIMIT:
		var voice = AudioStreamPlayer3D.new()
		voice.name = "SoundWorld%d" % i
		voice.bus = SFX_BUS
		voice.process_mode = Node.PROCESS_MODE_PAUSABLE
		voice.unit_size = 18.0
		voice.max_distance = 75.0
		voice.panning_strength = 0.55
		world.add_child(voice)
		_world_voices.append(voice)

func _detach_world():
	if _world_ref != null:
		var world = _world_ref.get_ref()
		if is_instance_valid(world):
			if world.is_connected("audio_cue", _on_world_cue):
				world.disconnect("audio_cue", _on_world_cue)
			if world.tree_exiting.is_connected(_detach_world):
				world.tree_exiting.disconnect(_detach_world)
	for voice in _world_voices:
		if is_instance_valid(voice):
			voice.stop()
			voice.stream = null
			voice.queue_free()
	_world_voices.clear()
	_world_ref = null
	_world_index = 0

func _on_world_cue(cue: String, at: Vector3):
	# Forest cue coordinates are local to the emitting world.
	var world = _world_ref.get_ref() if _world_ref != null else null
	play_cue(cue, world.to_global(at) if is_instance_valid(world) else at)

func play_cue(cue: String, at: Vector3 = Vector3.ZERO) -> bool:
	emitted_counts[cue] = emitted_counts.get(cue, 0) + 1
	if not _streams.has(cue) or _streams[cue].is_empty():
		return false
	var now = Time.get_ticks_msec()
	var gap = 60 if cue.begins_with("ui_") else 100
	if now - int(_last_played.get(cue, -1000)) < gap:
		return false
	var positional = cue in ["footstep", "chop", "tree_fall"]
	if positional and (_world_voices.is_empty() or get_tree().paused):
		return false
	var variant = int(_variation.get(cue, 0)) % _streams[cue].size()
	_variation[cue] = variant + 1
	if positional:
		var voice = _world_voices[_world_index % WORLD_VOICE_LIMIT]
		_world_index += 1
		voice.stop()
		voice.global_position = at
		voice.stream = _streams[cue][variant]
		voice.volume_db = LEVELS[cue]
		if _has_audio_output:
			voice.play()
	else:
		var voice = _ui_voices[_ui_index % UI_VOICE_LIMIT]
		_ui_index += 1
		voice.stop()
		voice.stream = _streams[cue][variant]
		voice.volume_db = LEVELS[cue]
		if _has_audio_output:
			voice.play()
	_last_played[cue] = now
	played_counts[cue] = played_counts.get(cue, 0) + 1
	return true
