extends Node3D
## Imported shrub geometry plus conspicuous red fruit distinguish usable bushes.
const SHRUB: PackedScene = preload("res://features/levels/forest/nature/shrub.glb")
const MAX_BUSHES := 8
static var _healthy: StandardMaterial3D
static var _stressed: StandardMaterial3D
static var _fruit: StandardMaterial3D
static var _berry_mesh: SphereMesh
var bushes: Array[Dictionary] = []

func configure(grid: RefCounted) -> void:
	for bush in bushes:
		bush.node.free()
	bushes.clear()
	_ensure_resources()
	for i in range(grid.cells.size()):
		if not grid.cells[i].get("berry_bush", false) or bushes.size() >= MAX_BUSHES:
			continue
		var cell := Vector2i(i % grid.SIZE, floori(float(i) / grid.SIZE))
		var pivot := Node3D.new()
		pivot.name = "BerryBush%d" % i
		pivot.position = grid.world_position(cell) + Vector3(0.25, 0.06, 0.25)
		var model := SHRUB.instantiate() as Node3D
		model.scale = Vector3.ONE * 1.8
		pivot.add_child(model)
		var berries := MultiMeshInstance3D.new()
		berries.name = "Berries"
		berries.multimesh = MultiMesh.new()
		berries.multimesh.transform_format = MultiMesh.TRANSFORM_3D
		berries.multimesh.mesh = _berry_mesh
		berries.multimesh.instance_count = 7
		berries.material_override = _fruit
		berries.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for j in range(7):
			var angle := float(j) * TAU / 7.0
			var at := Vector3(cos(angle) * 0.28, 0.28 + float(j % 3) * 0.1, sin(angle) * 0.28)
			berries.multimesh.set_instance_transform(j, Transform3D(Basis.IDENTITY, at))
		pivot.add_child(berries)
		add_child(pivot)
		bushes.append({"index": i, "node": pivot, "model": model, "berries": berries})
	update_state(grid)

func update_state(grid: RefCounted) -> void:
	for bush in bushes:
		var data: Dictionary = grid.cells[bush.index]
		var has_bush: bool = data.get("berry_bush", false)
		bush.node.visible = has_bush
		if not has_bush:
			continue
		var healthy: bool = float(data.get("health", 1.0)) > 0.4 and float(data.get("moisture", 1.0)) > 0.35 and not data.get("burning", false)
		_apply_material(bush.model, _healthy if healthy else _stressed)
		bush.berries.visible = int(data.get("berries", 0)) > 0 and not data.get("burning", false) and float(data.get("health", 1.0)) > 0.05 and float(data.get("moisture", 1.0)) >= 0.12

static func _ensure_resources() -> void:
	if _healthy != null:
		return
	_healthy = StandardMaterial3D.new()
	_healthy.albedo_color = Color("416d32")
	_healthy.roughness = 1.0
	_stressed = StandardMaterial3D.new()
	_stressed.albedo_color = Color("8b7340")
	_stressed.roughness = 1.0
	_fruit = StandardMaterial3D.new()
	_fruit.albedo_color = Color("e94356")
	_fruit.roughness = 0.8
	_berry_mesh = SphereMesh.new()
	_berry_mesh.radius = 0.085
	_berry_mesh.height = 0.17
	_berry_mesh.radial_segments = 6
	_berry_mesh.rings = 3

func _apply_material(node: Node, material: Material) -> void:
	if node is MeshInstance3D:
		node.material_override = material
	for child in node.get_children():
		_apply_material(child, material)
