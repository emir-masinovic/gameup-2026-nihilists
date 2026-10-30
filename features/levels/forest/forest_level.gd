extends Node3D
const GridData = preload("res://features/levels/forest/grid_data.gd")
const TREE = preload("res://features/levels/forest/forest_tree.tscn")
@export var world_seed: int = 2026
var grid = GridData.new()

func _ready():
	grid.generate(world_seed)
	var materials: Array[ShaderMaterial] = []
	for color in [Color("637850"), Color("718759"), Color("59704a"), Color("807854")]:
		var material = ShaderMaterial.new()
		material.shader = preload("res://features/levels/forest/shader_grid.gdshader")
		material.set_shader_parameter("terrain_color", color)
		material.set_shader_parameter("cell_size", grid.CELL_SIZE)
		materials.append(material)
	var tile = BoxMesh.new()
	tile.size = Vector3(grid.CELL_SIZE, 0.3, grid.CELL_SIZE)
	for z in range(grid.SIZE):
		for x in range(grid.SIZE):
			var cell = Vector2i(x, z)
			var data = grid.cells[z * grid.SIZE + x]
			var ground = MeshInstance3D.new()
			ground.mesh = tile
			ground.material_override = materials[mini(int(data.shade * materials.size()), materials.size() - 1)]
			ground.position = grid.world_position(cell) + Vector3(0, -0.15, 0)
			$Terrain.add_child(ground)
			if data.tree:
				var tree = TREE.instantiate()
				tree.position = grid.world_position(cell)
				tree.rotation.y = data.rotation
				tree.scale = Vector3.ONE * data.scale
				$Vegetation.add_child(tree)
	$GridPlayer.configure(grid)
	$CameraRig.position = grid.world_position(grid.start)
	$HUD/Info.text = "FOREST"
	SettingsManager.graphics_changed.connect(_apply_shadow_quality)
	_apply_shadow_quality()

func _apply_shadow_quality():
	$Sun.shadow_enabled = SettingsManager.shadow_quality > 0
	$Sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
