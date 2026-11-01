extends SceneTree
var failures = 0
var checks = 0
func check(value, message):
	checks += 1
	if not value: failures += 1; push_error(message)
func _initialize(): call_deferred("run")
func run():
	root.size = Vector2i(1152,720)
	root.content_scale_size = Vector2i(1152,720)
	root.get_node("SceneFlow").next_seed = 2026
	change_scene_to_file("res://features/levels/forest/forest_level.tscn")
	await process_frame
	await process_frame
	var world = current_scene
	world.set_process(false)
	world.get_node("GridPlayer").set_process(false)
	var cover = world.ground_cover
	var lod = cover.lod_controller
	check(lod != null,"Screen-space LOD is enabled only in the experimental renderer")
	if lod == null: quit(1); return
	lod.set_process(false)
	var batch = cover.batches[0]
	var high = lod.high.surface_get_arrays(0)
	var low = lod.low.surface_get_arrays(0)
	check(high[Mesh.ARRAY_VERTEX].size() == 21 and high[Mesh.ARRAY_INDEX].size() == 45,"Indexed high tuft reuses vertices without removing triangles")
	check(low[Mesh.ARRAY_VERTEX].size() == 9 and low[Mesh.ARRAY_INDEX].size() == 9,"Low tuft retains three complete blades with three triangles")
	for arrays in [high,low]:
		for i in range(arrays[Mesh.ARRAY_VERTEX].size()):
			if arrays[Mesh.ARRAY_TEX_UV][i].y == 0: check(arrays[Mesh.ARRAY_VERTEX][i].y == 0,"Both LOD roots stay grounded")
	var camera = world.get_node("CameraRig/Camera3D")
	var rig = camera.get_parent()
	rig.set_process(false)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 20
	rig._update_camera()
	var small = lod.screen_size(camera,Vector3.ZERO)
	camera.size = 56
	rig._update_camera()
	var large = lod.screen_size(camera,Vector3.ZERO)
	check(small.x > large.x and small.y > large.y,"Screen-size metric responds to orthographic zoom")
	var logical_width = root.content_scale_size
	root.size = Vector2i(1600,900)
	await process_frame
	await process_frame
	var resized = lod.screen_size(camera,Vector3.ZERO)
	check(resized.x > large.x*1.1,"LOD tracks physical render resolution rather than only logical UI size")
	root.size = Vector2i(1152,720)
	await process_frame
	await process_frame
	for i in range(120): lod._process(1.0/60.0)
	check(lod.low_active and batch.renderer.multimesh.mesh == lod.low,"Max Board Center framing reaches cheap geometry after morph")
	camera.size = 10
	rig._update_camera()
	lod.clock = 0
	lod._process(1.0/60.0)
	check(not lod.low_active and lod.blend > 0.9,"Zoom-in restores high topology before gently restoring curvature")
	for i in range(120): lod._process(1.0/60.0)
	check(lod.blend < 0.01,"Close view restores full curved detail")
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.position = camera.position.normalized()*15
	var close = lod.screen_size(camera,Vector3.ZERO)
	camera.position = camera.position.normalized()*80
	check(lod.screen_size(camera,Vector3.ZERO).x < close.x,"Perspective metric depends on actual camera depth")
	for mode in ["Follow Player","Board Center","Free Camera"]:
		rig.set_mode(mode)
		rig._update_camera()
		check(lod.screen_size(camera,Vector3.ZERO).is_finite(),"Projected LOD metric remains finite in "+mode)
	var original = world.grid.cells.duplicate(true)
	var transforms = batch.renderer.multimesh.buffer.duplicate()
	for frame in range(40): lod._process(1.0/60.0)
	check(world.grid.cells == original and batch.renderer.multimesh.buffer == transforms,"LOD never alters climate or per-instance placement buffers")
	check(batch.renderer.material_override.get_shader_parameter("spatial_wind_enabled"),"Coherent wind uses the shared texture while retaining wind controls")
	check(batch.renderer.material_override.get_shader_parameter("wind_exposure").size() == 73,"Canopy shelter remains authoritative")
	for strength in [0.0,0.5,1.0]:
		cover.set_wind({"direction":Vector2.ZERO if strength == 0 else Vector2(-1,0),"strength":strength,"time":6.0})
		check(batch.renderer.material_override.get_shader_parameter("wind_strength") == strength,"Authoritative wind intensity passes unchanged to shader")
		check(batch.renderer.material_override.get_shader_parameter("wind_direction").length_squared() > 0.9,"Zero-wind direction cannot normalize to NaN")
	check(world.grid.cells == original,"Wind presentation never modifies climate or ecological state")
	print("GRASS V2: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
