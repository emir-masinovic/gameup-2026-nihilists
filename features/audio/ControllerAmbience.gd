extends Node
# Three environmental layers; biome owns two fixed voices only for crossfades.
const ROOT = "res://features/audio/"
const SILENT = -80.0
var voices: Array[AudioStreamPlayer] = []
var targets: Array[float] = [SILENT,SILENT,SILENT,SILENT]
var streams = {}
var world_ref: WeakRef
var biome = ""
var active_biome = 0
var poll = 0.0
var detail_clock = 12.0
var detail_voice: AudioStreamPlayer
var rng = RandomNumberGenerator.new()
var output = false
var camera_presence = 0.5
var detail_level = -29.0

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	output = AudioServer.get_driver_name() != "Dummy"
	rng.seed = 2026
	for id in ["Forest","Wetlands","Drylands","Wind","Rain"]:
		var stream = load_optional("Ambience"+id)
		if stream != null:
			stream.loop = true
			streams[id.to_lower()] = stream
	for i in range(4):
		var voice = AudioStreamPlayer.new()
		voice.bus = &"SFX"
		voice.volume_db = SILENT
		add_child(voice)
		voices.append(voice)
	for id in ["SoundFrog","SoundRaindrop"]: streams[id] = load_optional(id)
	detail_voice = AudioStreamPlayer.new()
	detail_voice.bus = &"SFX"
	add_child(detail_voice)

func load_optional(id: String):
	var path = ROOT+id+".mp3"
	return load(path) if ResourceLoader.exists(path) else null

static func surface(data: Dictionary) -> String:
	if (data.get("water",false) or data.get("terrain","") == "water") and maxf(data.get("water_depth",0.0),data.get("water_level",0.0)) > 0.02: return "wet"
	var moisture: float = data.get("moisture",0.5)
	var terrain: String = data.get("terrain","grass")
	if data.get("tilled",false) or data.get("prepared",false): return "mud"
	# Match the renderer's vegetation vitality and eligibility, not wetness alone.
	var vitality = minf(data.get("health",1.0),moisture*1.65)
	var grass = terrain == "grass" and not data.get("burning",false) and (not data.get("burned",false) or data.get("burn_recovery",0.0) >= 0.2)
	if grass and vitality >= 0.55: return "grass"
	if moisture >= 0.8 and (not grass or vitality < 0.4): return "mud"
	if terrain in ["sand","soil"] or moisture < 0.35 or vitality < 0.35: return "dry"
	return "grass" if grass and vitality >= 0.4 else "dry"

static func presence(framing: float) -> float:
	return 1.0-smoothstep(7.0,56.0,framing)

static func camera_framing(camera: Camera3D, player: Node3D) -> float:
	var distance = camera.global_position.distance_to(player.global_position)/1.4
	var mode = camera.get_parent().get("mode")
	if mode is String and mode == "Free Camera":
		return maxf(camera.size,distance) if camera.projection == Camera3D.PROJECTION_ORTHOGONAL else distance
	return camera.size if camera.projection == Camera3D.PROJECTION_ORTHOGONAL else distance

func category_gain(category: String) -> float:
	if category == "footstep": return lerpf(0.55,1.10,camera_presence)
	if category == "detail": return lerpf(0.50,1.15,camera_presence)
	if category == "chop" or category == "tree_fall": return lerpf(0.70,1.05,camera_presence)
	if category == "ambience": return lerpf(0.80,1.05,camera_presence)
	return 1.0

static func mix(strength: float, rain: bool, canopy: float, exposure: float, health: float) -> Vector3:
	return Vector3(0.035+0.055*clampf(health,0,1), 0.14*pow(clampf(strength,0,1),1.5)*lerpf(0.4,1.0,clampf(exposure,0,1)), (0.12*(1.0-0.5*clampf(canopy,0,1))) if rain else 0.0)

func stop_world():
	world_ref = null
	targets.fill(SILENT)
	for voice in voices:
		voice.stop()
		voice.volume_db = SILENT
	detail_voice.stop()

func attach_world(world):
	world_ref = weakref(world) if world != null else null
	poll = 0.0

func _process(delta):
	var world = world_ref.get_ref() if world_ref != null else null
	var suspended = get_tree().paused or (is_instance_valid(world) and world.get("ended") == true)
	for voice in voices: voice.stream_paused = suspended
	detail_voice.stream_paused = suspended
	if suspended: return
	if is_instance_valid(world):
		var camera = get_viewport().get_camera_3d()
		var player = world.get_node_or_null("GridPlayer")
		if camera != null and player != null:
			camera_presence = lerpf(camera_presence,presence(camera_framing(camera,player)),1.0-exp(-delta*4.0))
	detail_voice.volume_db = detail_level+linear_to_db(category_gain("detail"))
	poll -= delta
	if poll <= 0.0:
		poll = 0.2
		_sample(world)
	for i in range(voices.size()):
		var voice = voices[i]
		voice.volume_db = move_toward(voice.volume_db,targets[i],delta*35.0)
		if targets[i] <= SILENT and voice.volume_db <= SILENT: voice.stop()
		elif not voice.playing and voice.stream != null and output: voice.play()
	if not is_instance_valid(world):
		detail_voice.stop()
		return
	detail_clock -= delta
	if detail_clock <= 0.0:
		detail_clock = rng.randf_range(12,24)
		var climate = world.get("climate")
		if climate == null: return
		var id = "SoundRaindrop" if climate.weather == "rain" else ("SoundFrog" if biome == "wetlands" else "")
		if id == "SoundFrog" and world.grid.cells[world.get_node("GridPlayer").cell.y*world.grid.SIZE+world.get_node("GridPlayer").cell.x].health < 0.35: return
		if streams.get(id) != null and not detail_voice.playing:
			detail_voice.stream = streams[id]
			detail_level = rng.randf_range(-31,-27)
			detail_voice.volume_db = detail_level+linear_to_db(category_gain("detail"))
			if output: detail_voice.play()

func _sample(world):
	if not is_instance_valid(world) or world.get("climate") == null:
		targets.fill(SILENT)
		return
	var climate = world.climate
	var player = world.get_node_or_null("GridPlayer")
	if player == null: return
	var run_time = world.regions.elapsed
	var wind = climate.wind_state(world.tick_accumulator,run_time)
	var data: Dictionary = world.grid.cells[player.cell.y*world.grid.SIZE+player.cell.x]
	var levels = mix(wind.strength,climate.weather == "rain",climate.shade_at(player.cell),climate.wind_exposure_at(player.cell,wind.direction),data.health)
	var next: String = world.region_id
	if next != biome:
		# Rapid switches reuse the fixed inactive slot, never allocate another voice.
		targets[active_biome] = SILENT
		active_biome = 1-active_biome
		voices[active_biome].stop()
		voices[active_biome].volume_db = SILENT
		voices[active_biome].stream = streams.get(next)
		biome = next
	targets[active_biome] = linear_to_db(levels.x*category_gain("ambience"))
	for i in range(2,4):
		var stream = streams.get("wind" if i == 2 else "rain")
		if voices[i].stream != stream: voices[i].stream = stream
		var gain = levels.y if i == 2 else levels.z
		targets[i] = linear_to_db(gain*category_gain("ambience")) if gain > 0.0001 else SILENT
