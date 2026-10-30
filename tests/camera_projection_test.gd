extends SceneTree
var checks = 0
var failures = 0
func check(value: bool, message: String):
	checks += 1
	if not value:
		failures += 1
		push_error(message)
func _initialize():
	call_deferred("run")
func run():
	var test_saves = root.get_node("SaveManager")
	test_saves.storage_path = "user://camera_projection_test_progression.json"
	test_saves.load_progression()
	var settings = root.get_node("SettingsManager")
	settings.storage_path = "user://camera_projection_test.cfg"
	var original_volume = settings.volumes.Master
	settings.camera_projection = "Perspective"
	check(settings.save_settings() == OK, "Projection saves to isolated config")
	settings.camera_projection = "Orthographic"
	settings.load_settings()
	check(settings.camera_projection == "Perspective", "Projection persists")
	var rig = Node3D.new()
	rig.set_script(load("res://features/levels/forest/camera_orbit.gd"))
	var camera = Camera3D.new()
	camera.name = "Camera3D"
	rig.add_child(camera)
	root.add_child(rig)
	check(camera.projection == Camera3D.PROJECTION_PERSPECTIVE, "Saved perspective applies on ready")
	check(is_equal_approx(camera.fov, 55.0) and is_equal_approx(camera.near, 0.1) and is_equal_approx(camera.far, 200.0), "Perspective lens configured")
	var pivot = rig.global_position
	for mode in ["Orthographic", "Perspective"]:
		settings.camera_projection = mode
		settings.apply_settings()
		check(camera.projection == (Camera3D.PROJECTION_PERSPECTIVE if mode == "Perspective" else Camera3D.PROJECTION_ORTHOGONAL), "Projection switches immediately: " + mode)
		for zoom in [10.0, 42.0, 56.0]:
			rig.target_zoom = zoom
			rig._process(10.0)
			check(is_equal_approx(camera.size, zoom), "Zoom size: " + mode)
			if mode == "Perspective":
				check(is_equal_approx(camera.position.length(), zoom * 1.4), "Perspective distance follows zoom")
			for angle in [PI * 0.5, PI, PI * 1.5, -PI * 0.5]:
				rig.pitch = angle
				rig._update_camera()
				check(camera.basis.is_finite() and is_equal_approx(camera.basis.determinant(), 1.0), "Finite camera across poles")
				check(camera.global_basis.z.normalized().dot((camera.global_position - pivot).normalized()) > 0.999, "Both projections preserve fixed pivot")
	settings.camera_projection = "Perspective"
	check(settings.reset_category("Gameplay") == OK, "Gameplay defaults save")
	check(settings.camera_projection == "Orthographic" and camera.projection == Camera3D.PROJECTION_ORTHOGONAL, "Defaults restore orthographic immediately")
	check(settings.volumes.Master == original_volume, "Gameplay defaults preserve audio")
	var config = ConfigFile.new()
	config.set_value("gameplay", "camera_projection", "Invalid")
	config.save(settings.storage_path)
	settings.load_settings()
	check(settings.camera_projection == "Orthographic", "Invalid projection falls back safely")
	DirAccess.remove_absolute(settings.storage_path)
	rig.queue_free()
	print("CAMERA PROJECTION: ", checks, " checks, ", failures, " failures")
	if FileAccess.file_exists(test_saves.storage_path):
		DirAccess.remove_absolute(test_saves.storage_path)
	quit(0 if failures == 0 else 1)
