extends SceneTree

var checks := 0
var failures := 0

func check(value: bool, message: String) -> void:
    checks += 1
    if not value:
        failures += 1
        push_error(message)

func _initialize() -> void:
    call_deferred("run")

func bounds(node: Node3D, relative: Transform3D = Transform3D.IDENTITY) -> AABB:
    var transform := relative * node.transform
    var result := AABB()
    if node is MeshInstance3D:
        result = transform * (node as MeshInstance3D).get_aabb()
    for child in node.get_children():
        if child is Node3D:
            var child_bounds := bounds(child, transform)
            if child_bounds.size.length() > 0.0:
                result = child_bounds if result.size.length() == 0.0 else result.merge(child_bounds)
    return result

func run() -> void:
    var scene := load("res://features/levels/forest/nature/nature_tree.tscn") as PackedScene
    var visuals := load("res://features/levels/forest/nature/nature_visuals.gd")
    var first_material: Material
    for variant in range(2):
        var tree = scene.instantiate()
        tree.variant = variant
        root.add_child(tree)
        var box := bounds(tree)
        check(box.position.is_finite() and box.size.is_finite(), "Tree bounds are finite")
        check(absf(box.position.y) < 0.001, "Tree is grounded at its root pivot")
        check(box.size.y > 2.4 and box.size.y < 2.6, "Tree fits the intended height")
        check(maxf(box.size.x, box.size.z) < 1.6, "Crown fits a two-unit grid cell")
        check(tree._leaf_surfaces.size() > 0, "Imported material names identify foliage")
        if tree._leaf_surfaces.size() == 0:
            tree.free()
            continue
        var entry: Dictionary = tree._leaf_surfaces[0]
        var mesh: MeshInstance3D = entry.mesh
        var healthy := mesh.get_surface_override_material(entry.surface)
        if first_material != null:
            check(healthy == first_material, "Variants share healthy foliage material")
        first_material = healthy
        tree.set_health(0.1, false)
        var dry := mesh.get_surface_override_material(entry.surface) as ShaderMaterial
        check(dry != healthy and not dry.get_shader_parameter("bare"), "Low health uses shared dry foliage")
        tree.set_health(0.0, true)
        var dead := mesh.get_surface_override_material(entry.surface) as ShaderMaterial
        check(dead.get_shader_parameter("bare"), "Dead foliage is discarded while bark remains")
        var bark_count := 0
        for index in range(mesh.mesh.get_surface_count()):
            if mesh.get_surface_override_material(index) is StandardMaterial3D:
                bark_count += 1
        check(bark_count > 0, "Dead tree retains trunk surfaces")
        tree.rotation.z = PI / 2.0
        var fallen := bounds(tree)
        check(fallen.size.x > 2.4, "Rotating the root moves the whole model around its base")
        check(tree.position == Vector3.ZERO, "Falling leaves the tree base fixed")
        tree.free()
    for prop in [visuals.instantiate_stump(), visuals.instantiate_log(), visuals.instantiate_grass(), visuals.instantiate_shrub()]:
        var box := bounds(prop)
        check(box.size.is_finite() and box.size.length() > 0.0, "Prop contains finite visible geometry")
        check(absf(box.position.y) < 0.001, "Prop wrapper is grounded")
        prop.free()
    var grass_a: Node3D = visuals.instantiate_grass()
    var grass_b: Node3D = visuals.instantiate_grass()
    var material_a: Material = grass_a.get_child(0).get_child(0).get_surface_override_material(0)
    var material_b: Material = grass_b.get_child(0).get_child(0).get_surface_override_material(0)
    check(material_a == material_b, "Ground vegetation shares materials between cells")
    check(material_a is ShaderMaterial, "Ground vegetation uses lightweight foliage wind")
    grass_a.free()
    grass_b.free()
    var initial_dead = scene.instantiate()
    initial_dead.set_health(0.0, true)
    root.add_child(initial_dead)
    check(initial_dead._state == 3, "Health set before ready is applied after model creation")
    initial_dead.free()
    print("NATURE ASSETS: ", checks, " checks, ", failures, " failures")
    quit(0 if failures == 0 else 1)
