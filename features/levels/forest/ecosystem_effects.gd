extends Node3D
var flames: MultiMeshInstance3D
var rain: MultiMeshInstance3D
var rain_material: ShaderMaterial
var fire_material: ShaderMaterial

func configure(grid: RefCounted, world_seed: int, material: ShaderMaterial):
	fire_material = material
	flames = MultiMeshInstance3D.new()
	flames.name = "WildfireFlames"
	flames.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var cone = CylinderMesh.new()
	cone.top_radius = 0.01
	cone.bottom_radius = 0.45
	cone.height = 1.2
	cone.radial_segments = 5
	cone.rings = 2
	flames.multimesh = MultiMesh.new()
	flames.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	flames.multimesh.mesh = cone
	flames.multimesh.instance_count = grid.SIZE * grid.SIZE
	flames.multimesh.visible_instance_count = 0
	flames.material_override = material
	add_child(flames)
	rain = MultiMeshInstance3D.new()
	rain.name = "Rain"
	rain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var drop = BoxMesh.new()
	drop.size = Vector3(0.018, 0.35, 0.018)
	rain.multimesh = MultiMesh.new()
	rain.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	rain.multimesh.use_custom_data = true
	rain.multimesh.mesh = drop
	rain.multimesh.instance_count = 96
	var rng = RandomNumberGenerator.new()
	rng.seed = world_seed + 5107
	for i in range(96):
		rain.multimesh.set_instance_transform(i, Transform3D(Basis(), Vector3(rng.randf_range(-17,17),0,rng.randf_range(-17,17))))
		rain.multimesh.set_instance_custom_data(i, Color(rng.randf(),0,0,1))
	rain_material = ShaderMaterial.new()
	var shader = Shader.new()
	shader.code = "shader_type spatial; render_mode unshaded; uniform float rain_time=0.0; void vertex(){VERTEX.y += mod(INSTANCE_CUSTOM.r*8.0-rain_time*6.0,8.0);} void fragment(){ALBEDO=vec3(0.48,0.67,0.78);}"
	rain_material.shader = shader
	rain.material_override = rain_material
	rain.visible = false
	add_child(rain)

func update_state(grid: RefCounted, weather: String):
	var count = 0
	for i in range(grid.cells.size()):
		if grid.cells[i].get("burning", false):
			var cell = Vector2i(i % grid.SIZE, floori(float(i) / grid.SIZE))
			flames.multimesh.set_instance_transform(count, Transform3D(Basis(),grid.world_position(cell)+Vector3(0,0.6,0)))
			count += 1
	flames.multimesh.visible_instance_count = count
	rain.visible = weather == "rain"

func update_clock(seconds: float):
	if rain_material != null:
		rain_material.set_shader_parameter("rain_time", seconds)
