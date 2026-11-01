extends Node3D
var flames: MultiMeshInstance3D
var rain: MultiMeshInstance3D
var rain_material: ShaderMaterial
var rain_impacts: MultiMeshInstance3D
var impact_material: ShaderMaterial
var fire_material: ShaderMaterial
var wind_streaks: MultiMeshInstance3D
var wind_material: ShaderMaterial
var wind_streaks_enabled = false

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
	drop.size = Vector3(0.028, 0.5, 0.028)
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
	_configure_impacts(grid,world_seed)
	_configure_wind(world_seed)

func update_state(grid: RefCounted, weather: String):
	var count = 0
	for i in range(grid.cells.size()):
		if grid.cells[i].get("burning", false):
			var cell = Vector2i(i % grid.SIZE, floori(float(i) / grid.SIZE))
			flames.multimesh.set_instance_transform(count, Transform3D(Basis(),grid.world_position(cell)+Vector3(0,0.6,0)))
			count += 1
	flames.multimesh.visible_instance_count = count
	rain.visible = weather == "rain"
	rain_impacts.visible = rain.visible

func update_clock(seconds: float):
	if rain_material != null:
		rain_material.set_shader_parameter("rain_time", seconds)
	if impact_material != null: impact_material.set_shader_parameter("rain_time",seconds)


# Six reusable ribbons, animated entirely on the GPU. No particle nodes.
func _configure_wind(world_seed: int):
	wind_streaks_enabled = not OS.get_cmdline_user_args().has("--no-wind-streaks")
	wind_streaks = MultiMeshInstance3D.new()
	wind_streaks.name = "WindStreaks"
	wind_streaks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mesh = SurfaceTool.new()
	mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
	for segment in range(8):
		var a = float(segment)/8.0
		var b = float(segment+1)/8.0
		for vertex in [Vector2(a,-1),Vector2(a,1),Vector2(b,1),Vector2(a,-1),Vector2(b,1),Vector2(b,-1)]:
			mesh.set_uv(Vector2(vertex.x,(vertex.y+1.0)*0.5))
			mesh.add_vertex(Vector3((vertex.x-0.5)*3.0,sin(vertex.x*PI)*0.22+vertex.y*0.024,0))
	wind_streaks.multimesh = MultiMesh.new()
	wind_streaks.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	wind_streaks.multimesh.use_custom_data = true
	wind_streaks.multimesh.mesh = mesh.commit()
	wind_streaks.multimesh.instance_count = 6
	var rng = RandomNumberGenerator.new()
	rng.seed = world_seed ^ 0x51A17
	for i in range(6):
		wind_streaks.multimesh.set_instance_transform(i,Transform3D(Basis.IDENTITY,Vector3(rng.randf_range(-12,12),rng.randf_range(1.8,3.0),rng.randf_range(-12,12))))
		wind_streaks.multimesh.set_instance_custom_data(i,Color(rng.randf(),0,0,1))
	wind_material = ShaderMaterial.new()
	var shader = Shader.new()
	shader.code = """shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
uniform vec2 wind_direction=vec2(0.8,0.6);
uniform float wind_time=0.0;
uniform float wind_strength=0.0;
uniform vec2 player_position=vec2(0.0);
uniform vec2 shelter_origin=vec2(-16.0);
uniform vec4 wind_exposure[73];
varying float visibility;
void vertex(){
 float phase=fract(wind_time/7.0+INSTANCE_CUSTOM.r);
 vec2 travel=wind_direction*(phase-0.5)*10.0;
 vec2 center=MODEL_MATRIX[3].xz+travel;
 ivec2 cell=ivec2(floor((center-shelter_origin)/2.0+vec2(0.5)));
 int index=clamp(cell.y*17+cell.x,0,288);
 float exposure=wind_exposure[index/4][index%4];
 float inside=step(0.0,float(cell.x))*step(0.0,float(cell.y))*step(float(cell.x),16.0)*step(float(cell.y),16.0);
 visibility=pow(sin(phase*3.14159265),2.0)*smoothstep(0.55,0.85,wind_strength)*exposure*inside*smoothstep(1.5,3.0,distance(center,player_position));
 VERTEX.xz=wind_direction*VERTEX.x+travel;
}
void fragment(){
 ALBEDO=vec3(0.9,0.96,1.0);
 ALPHA=0.26*visibility*sin(UV.x*3.14159265);
}
"""
	wind_material.shader = shader
	wind_streaks.material_override = wind_material
	wind_streaks.custom_aabb = AABB(Vector3(-21,0,-21),Vector3(42,5,42))
	add_child(wind_streaks)

func update_wind(state: Dictionary, player_position: Vector3):
	wind_streaks.visible = wind_streaks_enabled and state.strength > 0.55
	if not wind_streaks_enabled: return
	wind_material.set_shader_parameter("wind_direction",state.direction)
	wind_material.set_shader_parameter("wind_strength",state.strength)
	wind_material.set_shader_parameter("wind_time",state.time)
	wind_material.set_shader_parameter("player_position",Vector2(player_position.x,player_position.z))

func set_wind_shelter(values: PackedVector4Array, origin: Vector3):
	wind_material.set_shader_parameter("wind_exposure",values)
	wind_material.set_shader_parameter("shelter_origin",Vector2(origin.x,origin.z))

# Bounded GPU-animated impact rings at actual ground height, never falling particles.
func _configure_impacts(grid: RefCounted, world_seed: int):
	rain_impacts = MultiMeshInstance3D.new()
	rain_impacts.name = "RainImpacts"
	rain_impacts.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mesh = TorusMesh.new()
	mesh.inner_radius = 0.065
	mesh.outer_radius = 0.09
	mesh.rings = 8
	mesh.ring_segments = 3
	rain_impacts.multimesh = MultiMesh.new()
	rain_impacts.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	rain_impacts.multimesh.use_custom_data = true
	rain_impacts.multimesh.mesh = mesh
	var sites: Array[Vector3] = []
	var rng = RandomNumberGenerator.new()
	rng.seed = world_seed ^ 0x71A2
	for i in range(grid.cells.size()):
		var cell = grid.cells[i]
		if cell.tree or cell.get("log",false) or cell.get("berry_bush",false): continue
		var at = grid.world_position(Vector2i(i%grid.SIZE,i/grid.SIZE))
		sites.append(at+Vector3(rng.randf_range(-0.65,0.65),0.028,rng.randf_range(-0.65,0.65)))
	rain_impacts.multimesh.instance_count = mini(32,sites.size())
	for i in range(rain_impacts.multimesh.instance_count):
		var at = sites[rng.randi_range(0,sites.size()-1)]
		rain_impacts.multimesh.set_instance_transform(i,Transform3D(Basis.IDENTITY,at))
		rain_impacts.multimesh.set_instance_custom_data(i,Color(rng.randf(),0,0,1))
	impact_material = ShaderMaterial.new()
	var shader = Shader.new()
	shader.code = """shader_type spatial;
render_mode unshaded,cull_disabled,depth_draw_never;
uniform float rain_time=0.0;
void vertex(){float phase=fract(rain_time*1.7+INSTANCE_CUSTOM.r);VERTEX.xz*=0.3+phase*1.5;VERTEX.y*=0.25;COLOR=vec4(1.0,1.0,1.0,(1.0-phase)*0.55);}
void fragment(){ALBEDO=vec3(0.7,0.82,0.85);ALPHA=COLOR.a;}
"""
	impact_material.shader = shader
	rain_impacts.material_override = impact_material
	rain_impacts.extra_cull_margin = 0.2
	rain_impacts.visible = false
	add_child(rain_impacts)
