extends Node3D

var indicator_type: String = "seed"
var progress: float = 0.0
var base_y: float = 0.0

var _plate: MeshInstance3D
var _icon: MeshInstance3D
var _bar_bg: MeshInstance3D
var _bar_fill: MeshInstance3D

var _water_mat: StandardMaterial3D
var _growth_mat: StandardMaterial3D

func _ready():
	base_y = position.y
	_create_indicator_meshes()
	update_state(indicator_type, progress)

func _create_indicator_meshes():
	# Background plate
	var plate_mat = StandardMaterial3D.new()
	plate_mat.albedo_color = Color(0.06, 0.1, 0.08, 0.88)
	plate_mat.roughness = 0.8
	
	_plate = MeshInstance3D.new()
	_plate.name = "Plate"
	var plate_mesh = BoxMesh.new()
	plate_mesh.size = Vector3(0.56, 0.42, 0.02)
	plate_mesh.material = plate_mat
	_plate.mesh = plate_mesh
	add_child(_plate)
	
	# Icon Materials
	_water_mat = StandardMaterial3D.new()
	_water_mat.albedo_color = Color(0.22, 0.72, 1.0)
	_water_mat.roughness = 0.2
	_water_mat.emission_enabled = true
	_water_mat.emission = Color(0.15, 0.55, 0.85)
	_water_mat.emission_energy_multiplier = 0.6
	
	_growth_mat = StandardMaterial3D.new()
	_growth_mat.albedo_color = Color(0.35, 0.92, 0.42)
	_growth_mat.roughness = 0.3
	_growth_mat.emission_enabled = true
	_growth_mat.emission = Color(0.25, 0.75, 0.32)
	_growth_mat.emission_energy_multiplier = 0.5
	
	# Icon mesh
	_icon = MeshInstance3D.new()
	_icon.name = "Icon"
	_icon.position = Vector3(0, 0.09, 0.02)
	add_child(_icon)
	
	# Progress bar background
	var bg_mat = StandardMaterial3D.new()
	bg_mat.albedo_color = Color(0.12, 0.15, 0.14)
	bg_mat.roughness = 0.9
	
	_bar_bg = MeshInstance3D.new()
	_bar_bg.name = "BarBG"
	var bg_mesh = BoxMesh.new()
	bg_mesh.size = Vector3(0.44, 0.06, 0.015)
	bg_mesh.material = bg_mat
	_bar_bg.mesh = bg_mesh
	_bar_bg.position = Vector3(0, -0.1, 0.02)
	add_child(_bar_bg)
	
	# Progress bar fill
	_bar_fill = MeshInstance3D.new()
	_bar_fill.name = "BarFill"
	_bar_fill.position = Vector3(-0.21, -0.1, 0.03)
	add_child(_bar_fill)

func update_state(type: String, prog: float):
	indicator_type = type
	progress = clampf(prog, 0.0, 1.0)
	if _icon == null:
		return
		
	if indicator_type == "seed":
		# Water drop shape (prism/pyramid)
		var drop_mesh = PrismMesh.new()
		drop_mesh.size = Vector3(0.14, 0.18, 0.04)
		drop_mesh.material = _water_mat
		_icon.mesh = drop_mesh
		_icon.rotation.z = PI
	else:
		# Sprout shape
		var sprout_mesh = CylinderMesh.new()
		sprout_mesh.top_radius = 0.015
		sprout_mesh.bottom_radius = 0.09
		sprout_mesh.height = 0.18
		sprout_mesh.radial_segments = 5
		sprout_mesh.material = _growth_mat
		_icon.mesh = sprout_mesh
		_icon.rotation.z = 0.0
		
	# Update fill bar width
	var fill_w = maxf(0.001, 0.42 * progress)
	var fill_mesh = BoxMesh.new()
	fill_mesh.size = Vector3(fill_w, 0.05, 0.015)
	fill_mesh.material = _water_mat if indicator_type == "seed" else _growth_mat
	_bar_fill.mesh = fill_mesh
	_bar_fill.position = Vector3(-0.21 + fill_w * 0.5, -0.1, 0.03)

func _process(_delta: float):
	var cam = get_viewport().get_camera_3d()
	if cam != null:
		global_transform.basis = cam.global_transform.basis
	position.y = base_y + sin(Time.get_ticks_msec() * 0.0035) * 0.04
