class_name NatureVisuals
extends RefCounted
## Shared imported scenes; all instances are visual-only and have no collision.
const STUMP: PackedScene = preload("res://features/levels/forest/nature/stump.glb")
const LOG: PackedScene = preload("res://features/levels/forest/nature/log.glb")
const GRASS: PackedScene = preload("res://features/levels/forest/nature/grass.glb")
const SHRUB: PackedScene = preload("res://features/levels/forest/nature/shrub.glb")
const FOLIAGE_SHADER: Shader = preload("res://features/levels/forest/nature/shader_foliage.gdshader")
static var _bark: StandardMaterial3D
static var _inner_wood: StandardMaterial3D
static var _plant: ShaderMaterial

static func instantiate_stump() -> Node3D:
    return _instantiate_grounded(STUMP, 1.7, "Stump")

static func instantiate_log() -> Node3D:
    return _instantiate_grounded(LOG, 2.1, "Log")

static func instantiate_grass() -> Node3D:
    return _instantiate_grounded(GRASS, 1.0, "Grass")

static func instantiate_shrub() -> Node3D:
    return _instantiate_grounded(SHRUB, 1.6, "Shrub")

static func _instantiate_grounded(scene: PackedScene, model_scale: float, label: String) -> Node3D:
    var pivot := Node3D.new()
    pivot.name = label
    var model := scene.instantiate() as Node3D
    model.scale = Vector3.ONE * model_scale
    model.position.y = 0.05 * model_scale
    pivot.add_child(model)
    _ensure_materials()
    _apply_materials(model)
    return pivot

static func _ensure_materials() -> void:
    if _bark != null:
        return
    _bark = StandardMaterial3D.new()
    _bark.albedo_color = Color(0.29, 0.17, 0.095)
    _bark.roughness = 1.0
    _inner_wood = StandardMaterial3D.new()
    _inner_wood.albedo_color = Color(0.66, 0.46, 0.28)
    _inner_wood.roughness = 1.0
    _plant = ShaderMaterial.new()
    _plant.shader = FOLIAGE_SHADER
    _plant.set_shader_parameter("leaf_color", Color(0.19, 0.38, 0.18))
    _plant.set_shader_parameter("wind_height", 0.3)
    _plant.set_shader_parameter("sway", 0.015)

static func _apply_materials(node: Node) -> void:
    if node is MeshInstance3D:
        var mesh := node as MeshInstance3D
        for index in range(mesh.mesh.get_surface_count()):
            var source := mesh.mesh.surface_get_material(index)
            var source_name: String = source.resource_name.to_lower() if source else ""
            var material: Material = _plant
            if source_name.contains("bark"):
                material = _bark
            elif source_name.contains("wood"):
                material = _inner_wood
            mesh.set_surface_override_material(index, material)
    for child in node.get_children():
        _apply_materials(child)
