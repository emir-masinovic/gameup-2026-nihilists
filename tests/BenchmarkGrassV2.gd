extends SceneTree
var output = []
func _initialize(): call_deferred("run")
func run():
	root.size = Vector2i(1152,720)
	root.content_scale_size = Vector2i(1152,720)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	root.get_node("SettingsManager").shadow_quality = 2
	var flow = root.get_node("SceneFlow")
	flow.next_seed = 2026
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--grass-biome="):
			flow.run_regions = load("res://features/levels/forest/RunRegions.gd").new()
			flow.run_regions.configure(2026)
			flow.run_regions.current_id = argument.get_slice("=",1)
	var start = Time.get_ticks_usec()
	change_scene_to_file("res://features/levels/forest/forest_level.tscn")
	await process_frame
	await process_frame
	var world = current_scene
	world.set_process(false)
	world.get_node("GridPlayer").set_process(false)
	if OS.get_cmdline_user_args().has("--grass-night"):
		world.presentation_elapsed = (0.75-world.starting_day_phase)*world.day_night_duration
		world._update_lighting()
	var cover = world.ground_cover
	var generation_ms = (Time.get_ticks_usec()-start)/1000.0
	for batch in cover.batches: batch.renderer.extra_cull_margin = 0.7
	for frame in range(1 if OS.get_cmdline_user_args().has("--grass-wind-only") else 150):
		cover._process(10.0 if OS.get_cmdline_user_args().has("--grass-wind-only") else 1.0/60.0)
		await process_frame
	if OS.get_cmdline_user_args().has("--grass-hide"): cover.batches[0].renderer.visible = false
	if OS.get_cmdline_user_args().has("--grass-chunks"): make_chunks(cover)
	var camera = world.get_node("CameraRig")
	camera.set_process(false)
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
	for projection in ([] if OS.get_cmdline_user_args().has("--grass-wind-only") else [Camera3D.PROJECTION_ORTHOGONAL,Camera3D.PROJECTION_PERSPECTIVE]):
		for zoom in ([8.0] if OS.get_cmdline_user_args().has("--grass-close") else [20.0,42.0,56.0]):
			camera.mode = "Board Center" if zoom == 56 else "Follow Player"
			camera.target_zoom = zoom
			camera.get_node("Camera3D").projection = projection
			camera.get_node("Camera3D").size = zoom
			camera.pitch = 0.75
			for argument in OS.get_cmdline_user_args():
				if argument.begins_with("--grass-pitch="): camera.pitch = float(argument.get_slice("=",1))
			camera.rotation.y = PI/4
			camera._update_camera()
			for frame in range(40): await process_frame
			var samples: Array[float] = []
			var cpu: Array[float] = []
			var gpu: Array[float] = []
			var last = Time.get_ticks_usec()
			for frame in range(120):
				world._update_wind(float(frame)/60.0)
				await process_frame
				var now = Time.get_ticks_usec()
				samples.append((now-last)/1000.0)
				last = now
				cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(root.get_viewport_rid()))
				gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid()))
			samples.sort()
			var grass = cover.batches[0]
			var arrays = grass.renderer.multimesh.mesh.surface_get_arrays(0)
			var visible = 0
			for value in grass.sizes:
				if value > 0.001: visible += 1
			var record = {"projection":projection,"zoom":zoom,"biome":world.region_id,"allocated_tufts":grass.indices.size(),"nonzero_tufts":visible,"vertices_per_tuft":arrays[Mesh.ARRAY_VERTEX].size(),"triangles_per_tuft":(arrays[Mesh.ARRAY_INDEX].size() if arrays[Mesh.ARRAY_INDEX]!=null and arrays[Mesh.ARRAY_INDEX].size()>0 else arrays[Mesh.ARRAY_VERTEX].size())/3,"frame_median_ms":samples[60],"frame_p95_ms":samples[114],"render_cpu_ms":cpu.reduce(func(a,b): return a+b,0.0)/cpu.size(),"render_gpu_ms":gpu.reduce(func(a,b): return a+b,0.0)/gpu.size(),"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"total_primitives":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),"world_generation_ms":generation_ms,"instance_buffer_bytes":grass.renderer.multimesh.buffer.size()*4,"wind_texture_bytes":cover.get("_wind_texture").get_image().get_data().size() if cover.get("_wind_texture") != null and cover.get("_wind_texture").get_image()!=null else 0,"cover_generation_ms":cover.get("generation_ms"),"cover_update_ms":cover.get("update_ms"),"lod_height_pixels":cover.get("lod_controller").projected_height if cover.get("lod_controller") != null else -1.0,"lod_width_pixels":cover.get("lod_controller").projected_width if cover.get("lod_controller") != null else -1.0}
			output.append(record)
			print("GRASS BENCH ",JSON.stringify(record))
			if OS.has_environment("GRASS_BENCH_OUT"):
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png(OS.get_environment("GRASS_BENCH_OUT")+"-"+str(projection)+"-"+str(int(zoom))+".png")
	if OS.get_cmdline_user_args().has("--grass-wind-frames") and OS.has_environment("GRASS_BENCH_OUT"):
		camera.get_node("Camera3D").projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.get_node("Camera3D").size = 20
		camera.pitch = 0.75
		camera._update_camera()
		if cover.get("lod_controller") != null:
			for settle in range(120): cover.get("lod_controller")._process(1.0/60.0)
			cover.get("lod_controller").set_process(false)
		for frame in range(181):
			var wind = world.climate.wind_state(0.0,float(frame)/30.0)
			cover.set_wind(wind)
			world.hud.set_wind(wind)
			load("res://features/levels/forest/nature/nature_tree.gd").set_wind(wind)
			await process_frame
			if frame%30 == 0:
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png(OS.get_environment("GRASS_BENCH_OUT")+"-wind-"+str(frame/30)+".png")
	if OS.has_environment("GRASS_BENCH_OUT"):
		var file = FileAccess.open(OS.get_environment("GRASS_BENCH_OUT")+".json",FileAccess.WRITE)
		file.store_string(JSON.stringify(output,"  "))
	quit()

# Diagnostic snapshot only: world simulation is intentionally frozen in this
# harness. Never used by gameplay; measures culling/draw overhead without a rewrite.
func make_chunks(cover):
	if cover.get("lod_controller") != null: cover.get("lod_controller").set_process(false)
	var batch = cover.batches[0]
	var groups = {}
	for i in range(batch.indices.size()):
		var point: Vector3 = batch.origins[i]
		var key = Vector2i(floori((point.x+17)/8),floori((point.z+17)/8))
		if not groups.has(key): groups[key] = []
		groups[key].append(i)
	for key in groups:
		var chunk = MultiMeshInstance3D.new()
		chunk.multimesh = MultiMesh.new()
		chunk.multimesh.transform_format = MultiMesh.TRANSFORM_3D
		chunk.multimesh.use_custom_data = true
		chunk.multimesh.mesh = batch.renderer.multimesh.mesh
		chunk.multimesh.instance_count = groups[key].size()
		for j in range(groups[key].size()):
			var i: int = groups[key][j]
			chunk.multimesh.set_instance_transform(j,batch.renderer.multimesh.get_instance_transform(i))
			chunk.multimesh.set_instance_custom_data(j,batch.renderer.multimesh.get_instance_custom_data(i))
		chunk.material_override = batch.renderer.material_override
		chunk.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		chunk.extra_cull_margin = 0.7
		cover.add_child(chunk)
	batch.renderer.visible = false
