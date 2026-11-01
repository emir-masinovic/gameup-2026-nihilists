extends Node3D
const VFX = preload("res://features/levels/forest/ResourceClimateVFX.tres")
var flames: MultiMeshInstance3D
var rain: MultiMeshInstance3D
var rain_material: ShaderMaterial
var rain_impacts: MultiMeshInstance3D
var impact_material: ShaderMaterial
var fire_material: ShaderMaterial
var wind_streaks: MultiMeshInstance3D
var wind_material: ShaderMaterial
var wind_streaks_enabled = false
var atmosphere: Node3D

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
	_configure_rainfall(grid,world_seed)
	_configure_wind(world_seed)
	atmosphere = preload("res://features/levels/forest/VisualAtmosphere.gd").new()
	add_child(atmosphere)
	atmosphere.configure(world_seed)

func update_atmosphere(delta: float, biome: String, temperature: float, weather: String, sun_direction: Vector3):
	atmosphere.update_state(delta,biome,temperature,weather,sun_direction)

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


# Bounded reusable thin ribbons, animated on the GPU; shared shelter remains authoritative.
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
			mesh.add_vertex(Vector3((vertex.x-0.5)*VFX.wind_line_length,sin(vertex.x*PI)*0.22+vertex.y*VFX.wind_line_width,0))
	wind_streaks.multimesh = MultiMesh.new()
	wind_streaks.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	wind_streaks.multimesh.use_custom_data = true
	wind_streaks.multimesh.mesh = mesh.commit()
	wind_streaks.multimesh.instance_count = clampi(VFX.wind_line_count,0,32)
	var rng = RandomNumberGenerator.new()
	rng.seed = world_seed ^ 0x51A17
	for i in range(wind_streaks.multimesh.instance_count):
		wind_streaks.multimesh.set_instance_transform(i,Transform3D(Basis.IDENTITY,Vector3(rng.randf_range(-VFX.wind_line_extent,VFX.wind_line_extent),rng.randf_range(1.8,3.0),rng.randf_range(-VFX.wind_line_extent,VFX.wind_line_extent))))
		wind_streaks.multimesh.set_instance_custom_data(i,Color(rng.randf(),0,0,1))
	wind_material = ShaderMaterial.new()
	var shader = Shader.new()
	shader.code = """shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
uniform vec2 wind_direction=vec2(0.8,0.6);
uniform float wind_time=0.0;
uniform float wind_strength=0.0;
uniform float line_opacity=0.0;
uniform float line_lifetime=9.0;
uniform float line_speed=1.4;
uniform vec2 player_position=vec2(0.0);
uniform vec2 shelter_origin=vec2(-16.0);
uniform vec4 wind_exposure[73];
varying float visibility;
void vertex(){
 float phase=fract(wind_time/max(line_lifetime,1.0)+INSTANCE_CUSTOM.r);
 vec2 travel=wind_direction*(phase-0.5)*line_lifetime*line_speed;
 vec2 center=MODEL_MATRIX[3].xz+travel;
 ivec2 cell=ivec2(floor((center-shelter_origin)/2.0+vec2(0.5)));
 int index=clamp(cell.y*17+cell.x,0,288);
 float exposure=wind_exposure[index/4][index%4];
 float inside=step(0.0,float(cell.x))*step(0.0,float(cell.y))*step(float(cell.x),16.0)*step(float(cell.y),16.0);
 visibility=pow(sin(phase*3.14159265),1.2)*smoothstep(0.55,0.85,wind_strength)*exposure*inside*smoothstep(1.5,3.0,distance(center,player_position));
 VERTEX.xz=wind_direction*VERTEX.x+travel;
}
void fragment(){
 ALBEDO=vec3(0.98,0.99,1.0);
 ALPHA=line_opacity*visibility*sin(UV.x*3.14159265);
}
"""
	wind_material.shader = shader
	wind_material.set_shader_parameter("line_opacity",VFX.wind_line_opacity)
	wind_material.set_shader_parameter("line_lifetime",VFX.wind_line_lifetime)
	wind_material.set_shader_parameter("line_speed",VFX.wind_line_speed)
	wind_streaks.material_override = wind_material
	var extent = VFX.wind_line_extent+VFX.wind_line_lifetime*VFX.wind_line_speed*0.5+VFX.wind_line_length
	wind_streaks.custom_aabb = AABB(Vector3(-extent,0,-extent),Vector3(extent*2,5,extent*2))
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

# The two pools share phase, site table and seed. Landing sites change each cycle
# on the GPU, without per-drop CPU updates or scene-tree allocations.
func _configure_rainfall(grid: RefCounted, world_seed: int):
	var sites: Array[Vector3] = []
	var rng = RandomNumberGenerator.new()
	rng.seed = world_seed ^ 0x71A2
	for i in range(grid.cells.size()):
		var cell = grid.cells[i]
		if cell.tree or cell.get("log",false) or cell.get("berry_bush",false): continue
		sites.append(grid.world_position(Vector2i(i%grid.SIZE,i/grid.SIZE)))
	for i in range(sites.size()-1,0,-1):
		var j = rng.randi_range(0,i)
		var site = sites[i]
		sites[i] = sites[j]
		sites[j] = site
	var site_count = mini(sites.size(),256)
	var packed = PackedVector4Array()
	packed.resize(128)
	for i in range(site_count):
		var pair = packed[i/2]
		if i%2 == 0: pair.x = sites[i].x; pair.y = sites[i].z
		else: pair.z = sites[i].x; pair.w = sites[i].z
		packed[i/2] = pair
	var count = clampi(VFX.splash_count,0,256) if site_count > 0 else 0
	var drop = BoxMesh.new()
	drop.size = Vector3(0.028,0.5,0.028)
	var ring = TorusMesh.new()
	ring.inner_radius = 0.065
	ring.outer_radius = 0.09
	ring.rings = 8
	ring.ring_segments = 3
	rain_material = ShaderMaterial.new()
	rain_material.shader = preload("res://features/levels/forest/ShaderRainDrop.gdshader")
	impact_material = ShaderMaterial.new()
	impact_material.shader = preload("res://features/levels/forest/ShaderRainImpact.gdshader")
	impact_material.set_shader_parameter("splash_size",VFX.splash_size)
	impact_material.set_shader_parameter("splash_opacity",VFX.splash_opacity)
	impact_material.set_shader_parameter("splash_variation",VFX.splash_variation)
	rain = MultiMeshInstance3D.new()
	rain.name = "Rain"
	rain_impacts = MultiMeshInstance3D.new()
	rain_impacts.name = "RainImpacts"
	for pool in [rain,rain_impacts]:
		pool.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		pool.multimesh = MultiMesh.new()
		pool.multimesh.transform_format = MultiMesh.TRANSFORM_3D
		pool.multimesh.use_custom_data = true
		pool.multimesh.mesh = drop if pool == rain else ring
		pool.multimesh.instance_count = count
		pool.material_override = rain_material if pool == rain else impact_material
		pool.material_override.set_shader_parameter("rain_sites",packed)
		pool.material_override.set_shader_parameter("rain_site_count",site_count)
		pool.material_override.set_shader_parameter("rain_cycle_seconds",VFX.rain_cycle_seconds)
		pool.custom_aabb = AABB(Vector3(-18,0,-18),Vector3(36,8,36))
		pool.visible = false
		add_child(pool)
	for i in range(count):
		var data = Color(rng.randf(),float(i),rng.randf(),1)
		for pool in [rain,rain_impacts]:
			pool.multimesh.set_instance_transform(i,Transform3D.IDENTITY)
			pool.multimesh.set_instance_custom_data(i,data)
