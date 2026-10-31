extends Node3D
## Base-pivot tree. Variant must be set before entering the scene tree.
## Rendering only: health and death always come from ClimateSimulation.
const CONIFER: PackedScene = preload("res://features/levels/forest/nature/tree_conifer.glb")
const DECIDUOUS: PackedScene = preload("res://features/levels/forest/nature/tree_deciduous.glb")
const FOLIAGE_SHADER: Shader = preload("res://features/levels/forest/nature/shader_foliage.gdshader")
static var _foliage_materials: Array[ShaderMaterial] = []
static var _bark_material: StandardMaterial3D
@export_range(0, 1) var variant: int = 0
var _leaf_surfaces: Array[Dictionary] = []
var _state: int = -1
var _health: float = 1.0
var _dead: bool = false
var _moisture: float = 1.0
var _burned: bool = false

func _ready() -> void:
    _ensure_materials()
    var model: Node3D = (CONIFER if variant % 2 == 0 else DECIDUOUS).instantiate()
    model.name = "Model"
    var model_scale: float = 1.63 if variant % 2 == 0 else 1.46
    model.scale = Vector3.ONE * model_scale
    # The source mesh child is offset down by 0.05; cancel before scaling.
    model.position.y = 0.05 * model_scale
    add_child(model)
    _configure_surfaces(model)
    set_health(_health, _dead, _moisture, _burned)

static func _ensure_materials() -> void:
    if not _foliage_materials.is_empty():
        return
    _bark_material = StandardMaterial3D.new()
    _bark_material.albedo_color = Color(0.29, 0.17, 0.095)
    _bark_material.roughness = 1.0
    for index in range(4):
        var material := ShaderMaterial.new()
        material.shader = FOLIAGE_SHADER
        material.set_shader_parameter("leaf_color", [Color(0.13, 0.34, 0.20), Color(0.64, 0.54, 0.13), Color(0.48, 0.25, 0.08), Color(0.3, 0.2, 0.1)][index])
        material.set_shader_parameter("bare", index == 3)
        _foliage_materials.append(material)

func _configure_surfaces(node: Node) -> void:
    if node is MeshInstance3D:
        var instance := node as MeshInstance3D
        for surface in range(instance.mesh.get_surface_count()):
            var material := instance.mesh.surface_get_material(surface)
            if material != null and material.resource_name.to_lower().contains("leaf"):
                _leaf_surfaces.append({"mesh": instance, "surface": surface})
            else:
                instance.set_surface_override_material(surface, _bark_material)
    for child in node.get_children():
        _configure_surfaces(child)

func set_health(health: float, dead: bool, moisture: float = 1.0, burned: bool = false) -> void:
    _health = clampf(health, 0.0, 1.0)
    _dead = dead
    _moisture = clampf(moisture, 0.0, 1.0)
    _burned = burned
    var condition = minf(_health, 0.2 + _moisture * 1.25)
    var next_state: int = 3 if dead or burned else (0 if condition >= 0.66 else (1 if condition >= 0.33 else 2))
    if next_state == _state or _leaf_surfaces.is_empty():
        return
    _state = next_state
    for entry in _leaf_surfaces:
        (entry.mesh as MeshInstance3D).set_surface_override_material(entry.surface, _foliage_materials[_state])
