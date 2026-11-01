extends Node3D
# Four fixed batches,32 total slots. No particles, collisions, textures or saved state.
const DEFAULTS = preload("res://features/levels/forest/ResourceClouds.tres")
const CAPACITY = 32
var material: ShaderMaterial
var batches: Array[MultiMeshInstance3D] = []
var wind_direction = Vector2.RIGHT
var wind_strength = 0.0
var heading = 0.0
var _heading_initialized = false
var weather = "clear"
var player_position = Vector3.ZERO
var travel = Vector2.ZERO
var coverage = 0.0
var darkening = 0.0
var preview: Dictionary = {}

func configure(world_seed: int):
	name = "Clouds"
	material = ShaderMaterial.new()
	material.shader = preload("res://features/levels/forest/ShaderClouds.gdshader")
	var rng = RandomNumberGenerator.new()
	rng.seed = world_seed ^ 0xC10D
	for variant in range(4):
		var batch = MultiMeshInstance3D.new()
		batch.name = ["SmallWhite","Puff","WindStretched","RainCloud"][variant]
		batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		batch.multimesh = MultiMesh.new()
		batch.multimesh.transform_format = MultiMesh.TRANSFORM_3D
		batch.multimesh.use_custom_data = true
		batch.multimesh.mesh = _make_cloud(variant)
		batch.multimesh.instance_count = CAPACITY/4
		batch.material_override = material
		batch.custom_aabb = AABB(Vector3(-55,0,-55),Vector3(110,26,110))
		for i in range(CAPACITY/4):
			batch.multimesh.set_instance_transform(i,Transform3D(Basis.IDENTITY,Vector3(rng.randf_range(-1,1),0,rng.randf_range(-1,1))))
			batch.multimesh.set_instance_custom_data(i,Color(float(i*4+variant),rng.randf_range(0.8,1.2),rng.randf(),0.9 if variant == 3 else 1.0))
		add_child(batch)
		batches.append(batch)
	coverage = DEFAULTS.count*DEFAULTS.clear_density

func _make_cloud(variant: int) -> ArrayMesh:
	var shapes = [
		[Vector3(-0.7,0,0),Vector3(0.3,0.25,0),Vector3(1,0,0)],
		[Vector3(-1,0,0),Vector3(0,0.5,0),Vector3(1,0,0),Vector3(0,0,0.6)],
		[Vector3(-1.7,0,0),Vector3(-0.6,0.2,0),Vector3(0.7,0.1,0),Vector3(1.8,0,0)],
		[Vector3(-1.2,0,0),Vector3(0,0.35,0),Vector3(1.2,0,0),Vector3(0,0,-0.65)]]
	var sphere = SphereMesh.new()
	sphere.radius = 0.9
	sphere.height = 1.8
	sphere.radial_segments = 7
	sphere.rings = 3
	var faces = sphere.get_faces()
	var mesh = SurfaceTool.new()
	mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
	for offset in shapes[variant]:
		for i in range(0,faces.size(),3):
			var a = faces[i]*Vector3(1,0.6,0.8)+offset
			var b = faces[i+1]*Vector3(1,0.6,0.8)+offset
			var c = faces[i+2]*Vector3(1,0.6,0.8)+offset
			mesh.set_normal((b-a).cross(c-a).normalized())
			for at in [a,b,c]: mesh.add_vertex(at)
	return mesh.commit()

func value(key: String):
	return preview.get(key,DEFAULTS.get(key))

func set_weather(next_weather: String, sun_height: float, rainbow: MeshInstance3D):
	weather = next_weather
	material.set_shader_parameter("daylight",smoothstep(-0.12,0.24,sun_height))
	material.set_shader_parameter("rainbow_position",Vector2(rainbow.position.x,rainbow.position.z))
	material.set_shader_parameter("rainbow_clearance",clampf(rainbow.material_override.albedo_color.a/maxf(0.01,preload("res://features/levels/forest/ResourceClimateVFX.tres").rainbow_opacity),0,1) if rainbow.visible else 0.0)

func set_wind(state: Dictionary):
	wind_direction = state.direction
	wind_strength = state.strength
	if not _heading_initialized and wind_direction.length_squared() > 0.000001:
		heading = wind_direction.angle()
		_heading_initialized = true

func _process(delta: float):
	visible = value("enabled")
	var viewport = get_viewport()
	var camera = viewport.get_camera_3d()
	if camera != null:
		var size = viewport.get_visible_rect().size
		material.set_shader_parameter("player_screen_uv",camera.unproject_position(player_position)/size)
		material.set_shader_parameter("screen_aspect",size.x/maxf(size.y,1.0))
	# Smooth shortest-arc yaw, without altering authoritative drift or placement.
	if wind_direction.length_squared() > 0.000001:
		heading = lerp_angle(heading,wind_direction.angle(),1.0-exp(-2.0*maxf(delta,0.0)))
	material.set_shader_parameter("cloud_heading",heading)
	travel += wind_direction*(0.18+0.55*wind_strength)*float(value("speed_multiplier"))*delta
	var density = float(value("rain_density")) if weather == "rain" else float(value("heat_density")) if weather == "heat" else 0.65 if weather == "cool" else float(value("clear_density"))
	coverage = move_toward(coverage,clampf(float(value("count"))*density,0,CAPACITY),delta*2.0)
	darkening = move_toward(darkening,float(value("rain_darkening")) if weather == "rain" else 0.0,delta*0.2)
	for key in ["extent","altitude","cloud_scale"]: material.set_shader_parameter(key,float(value(key)))
	material.set_shader_parameter("cloud_opacity",float(value("opacity")))
	material.set_shader_parameter("travel",travel)
	material.set_shader_parameter("coverage",coverage)
	material.set_shader_parameter("darkening",darkening)
