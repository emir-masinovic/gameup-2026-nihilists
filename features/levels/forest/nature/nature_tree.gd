extends Node3D
## Base-pivot tree. Variant must be set before entering the scene tree.
## Rendering only: health and death always come from ClimateSimulation.
const CONIFER: PackedScene = preload("res://features/levels/forest/nature/tree_conifer.glb")
const DECIDUOUS: PackedScene = preload("res://features/levels/forest/nature/tree_deciduous.glb")
const FOLIAGE_SHADER: Shader = preload("res://features/levels/forest/nature/shader_foliage.gdshader")
static var _foliage_materials: Array[ShaderMaterial] = []
static var _recovery_materials: Array[ShaderMaterial] = []
var _recovering = false
static var _branch_mesh: ArrayMesh
static var _charred_material: StandardMaterial3D
var _branches: MeshInstance3D
static var _bark_material: StandardMaterial3D
@export_range(0, 1) var variant: int = 0
var _leaf_surfaces: Array[Dictionary] = []
var _bark_surfaces: Array[Dictionary] = []
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
    _branches = MeshInstance3D.new()
    _branches.name = "WitheredBranches"
    _branches.mesh = _branch_mesh
    _branches.material_override = _bark_material
    add_child(_branches)
    set_health(_health, _dead, _moisture, _burned)

static func _ensure_materials() -> void:
    if not _foliage_materials.is_empty():
        return
    _bark_material = StandardMaterial3D.new()
    _bark_material.albedo_color = Color(0.29, 0.17, 0.095)
    _bark_material.roughness = 1.0
    _charred_material = _bark_material.duplicate()
    _charred_material.albedo_color = Color("231e1a")
    var tool = SurfaceTool.new()
    tool.begin(Mesh.PRIMITIVE_TRIANGLES)
    var rod = BoxMesh.new()
    rod.size = Vector3(0.065,1.0,0.065)
    for end in [Vector3(-0.52,1.95,0.1),Vector3(0.5,1.8,-0.25),Vector3(0.2,2.25,0.35)]:
        var start = Vector3(0,1.1,0)
        var direction: Vector3 = end-start
        var basis = Basis(Quaternion(Vector3.UP,direction.normalized())).scaled(Vector3(1,direction.length(),1))
        tool.append_from(rod,0,Transform3D(basis,(start+end)*0.5))
    _branch_mesh = tool.commit()
    for index in range(4):
        var material := ShaderMaterial.new()
        material.shader = FOLIAGE_SHADER
        material.set_shader_parameter("leaf_color", [Color(0.13, 0.34, 0.20), Color(0.64, 0.54, 0.13), Color(0.48, 0.25, 0.08), Color(0.3, 0.2, 0.1)][index])
        material.set_shader_parameter("bare", index == 3)
        material.set_shader_parameter("canopy_density", [1.0,0.6,0.22,0.0][index])
        material.set_shader_parameter("sway", [0.045,0.025,0.01,0.0][index])
        _foliage_materials.append(material)
    for index in range(2):
        var material = _foliage_materials[index+1].duplicate()
        material.set_shader_parameter("leaf_color", Color(0.25,0.46,0.17))
        material.set_shader_parameter("canopy_density",[0.6,0.28][index])
        _recovery_materials.append(material)

func _configure_surfaces(node: Node) -> void:
    if node is MeshInstance3D:
        var instance := node as MeshInstance3D
        for surface in range(instance.mesh.get_surface_count()):
            var material := instance.mesh.surface_get_material(surface)
            if material != null and material.resource_name.to_lower().contains("leaf"):
                _leaf_surfaces.append({"mesh": instance, "surface": surface})
            else:
                instance.set_surface_override_material(surface, _bark_material)
                _bark_surfaces.append({"mesh":instance,"surface":surface})
    for child in node.get_children():
        _configure_surfaces(child)

func set_health(health: float, dead: bool, moisture: float = 1.0, burned: bool = false) -> void:
    var previous_health = _health
    var was_recovering = _recovering
    _health = clampf(health, 0.0, 1.0)
    _dead = dead
    _moisture = clampf(moisture, 0.0, 1.0)
    _burned = burned
    var condition = minf(_health, 0.2 + _moisture * 1.25)
    var next_state: int = 3 if dead or burned else (0 if condition >= 0.66 else (1 if condition >= 0.33 else 2))
    # Hysteresis avoids repeated foliage changes around condition thresholds.
    if not dead and not burned and _state in [0,1,2] and next_state != _state:
        if (_state == 0 and condition > 0.62) or (_state == 1 and condition > 0.29 and condition < 0.70) or (_state == 2 and condition < 0.37):
            next_state = _state
    _recovering = not dead and not burned and next_state in [1,2] and _moisture > 0.55 and (_health > previous_health+0.0005 or (was_recovering and _health >= previous_health-0.0005))
    if is_instance_valid(_branches):
        _branches.visible = next_state >= 1
        _branches.material_override = _charred_material if burned else _bark_material
    for entry in _bark_surfaces:
        entry.mesh.set_surface_override_material(entry.surface,_charred_material if burned else _bark_material)
    if (next_state == _state and _recovering == was_recovering) or _leaf_surfaces.is_empty():
        return
    _state = next_state
    for entry in _leaf_surfaces:
        (entry.mesh as MeshInstance3D).set_surface_override_material(entry.surface, _recovery_materials[_state-1] if _recovering else _foliage_materials[_state])

static func set_wind(state: Dictionary) -> void:
    _ensure_materials()
    for material in _foliage_materials + _recovery_materials:
        material.set_shader_parameter("wind_direction",state.direction)
        material.set_shader_parameter("wind_strength",state.strength)
        material.set_shader_parameter("wind_time",state.time)
