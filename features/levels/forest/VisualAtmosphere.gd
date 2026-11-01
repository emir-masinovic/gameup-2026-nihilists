extends Node3D
# Ephemeral presentation only. No weather authority, gameplay or saved state.
const VFX = preload("res://features/levels/forest/ResourceClimateVFX.tres")
var rays: MultiMeshInstance3D
var ray_material: ShaderMaterial
var rainbow: MeshInstance3D
var rainbow_material: StandardMaterial3D
var previous_weather = ""
var rainbow_remaining = 0.0
var rainbow_alpha = 0.0
var elapsed = 0.0

func configure(world_seed: int):
	rays = MultiMeshInstance3D.new()
	rays.name = "SunRays"
	rays.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	rays.multimesh = MultiMesh.new()
	rays.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	rays.multimesh.use_custom_data = true
	rays.multimesh.mesh = QuadMesh.new()
	rays.multimesh.instance_count = clampi(VFX.sun_ray_count,0,16)
	var rng = RandomNumberGenerator.new()
	rng.seed = world_seed ^ 0x5A71
	for i in range(rays.multimesh.instance_count):
		rays.multimesh.set_instance_transform(i,Transform3D(Basis.IDENTITY,Vector3(rng.randf_range(-12,12),0.1,rng.randf_range(-12,12))))
		rays.multimesh.set_instance_custom_data(i,Color(rng.randf(),0,0,1))
	ray_material = ShaderMaterial.new()
	ray_material.shader = preload("res://features/levels/forest/ShaderSunRays.gdshader")
	ray_material.set_shader_parameter("ray_length",VFX.sun_ray_length)
	ray_material.set_shader_parameter("ray_width",VFX.sun_ray_width)
	ray_material.set_shader_parameter("ray_speed",VFX.sun_ray_speed)
	rays.material_override = ray_material
	rays.custom_aabb = AABB(Vector3(-28,0,-28),Vector3(56,20,56))
	rays.visible = false
	add_child(rays)
	rainbow = MeshInstance3D.new()
	rainbow.name = "PostRainRainbow"
	rainbow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mesh = SurfaceTool.new()
	mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
	var colors = [Color("f4a2a0"),Color("edbd87"),Color("e9d99a"),Color("a4c89d"),Color("9ebdd3"),Color("aea7cf"),Color("c3a2ce")]
	for band in range(colors.size()):
		for segment in range(32):
			for corner in [Vector2(0,0),Vector2(1,0),Vector2(1,1),Vector2(0,0),Vector2(1,1),Vector2(0,1)]:
				var angle = (segment+corner.x)/32.0*PI
				var inset = (band+corner.y)*0.09
				var color = colors[band]
				color.a = pow(maxf(sin(angle),0),0.35)
				mesh.set_color(color)
				mesh.add_vertex(Vector3(cos(angle)*(5.0-inset),sin(angle)*(3.8-inset),0)*VFX.rainbow_scale)
	rainbow.mesh = mesh.commit()
	rainbow_material = StandardMaterial3D.new()
	rainbow_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rainbow_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rainbow_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	rainbow_material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	rainbow_material.vertex_color_use_as_albedo = true
	rainbow.material_override = rainbow_material
	rainbow.visible = false
	add_child(rainbow)

func update_state(delta: float, biome: String, temperature: float, weather: String, sun_direction: Vector3):
	elapsed += delta
	var sunny = sun_direction.y > VFX.rainbow_min_sun_height
	var hot = clampf((temperature-28.0)/12.0,0.0,1.0) if weather == "heat" else 0.0
	rays.visible = biome == "drylands" and sunny and hot > 0.0
	ray_material.set_shader_parameter("ray_opacity",VFX.drylands_ray_opacity*hot)
	ray_material.set_shader_parameter("sun_direction",sun_direction)
	ray_material.set_shader_parameter("ray_time",elapsed)
	if previous_weather == "rain" and weather in ["clear","cool"] and sunny:
		rainbow_remaining = VFX.rainbow_duration
	previous_weather = weather
	if not sunny or weather in ["rain","heat"]:
		rainbow_remaining = 0.0
	rainbow_remaining = maxf(0.0,rainbow_remaining-delta)
	var target = VFX.rainbow_opacity if rainbow_remaining > VFX.rainbow_fade else 0.0
	rainbow_alpha = move_toward(rainbow_alpha,target,delta*VFX.rainbow_opacity/maxf(VFX.rainbow_fade,0.1))
	rainbow_material.albedo_color = Color(1,1,1,rainbow_alpha)
	rainbow.visible = rainbow_alpha > 0.001
	if sunny:
		var horizontal = Vector3(sun_direction.x,0,sun_direction.z).normalized()
		rainbow.position = -horizontal*6.0+Vector3.UP*0.3
		rainbow.look_at(rainbow.global_position+horizontal,Vector3.UP)
