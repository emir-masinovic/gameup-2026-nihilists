extends RefCounted
# Ten shared meshes retain imported material colors as vertex colors for one draw each.
const FILES = ["Flower01","Flower02","Flower03","Flower04","Flower05","Log04","Log05","Log06","Log07","Log08"]
static var _meshes: Array[ArrayMesh] = []

static func mesh_for(variant: int) -> ArrayMesh:
	if _meshes.is_empty():
		for i in range(FILES.size()):
			var scene = load("res://features/assets/c2gaming/"+FILES[i]+".fbx").instantiate()
			var surface = SurfaceTool.new()
			surface.begin(Mesh.PRIMITIVE_TRIANGLES)
			_append(scene,Transform3D.IDENTITY,surface)
			var raw = surface.commit()
			var box = raw.get_aabb()
			var size = Vector3.ONE*(0.72/box.size.y) if i < 5 else Vector3(1.25/maxf(box.size.x,box.size.z),0.14/box.size.y,1.25/maxf(box.size.x,box.size.z))
			var mesh = SurfaceTool.new()
			mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
			mesh.append_from(raw,0,Transform3D(Basis.IDENTITY.scaled(size),-Vector3(box.get_center().x,box.position.y,box.get_center().z)*size))
			_meshes.append(mesh.commit())
			scene.free()
	return _meshes[variant]

static func _append(node: Node, parent: Transform3D, output: SurfaceTool):
	var transform = parent*node.transform if node is Node3D else parent
	if node is MeshInstance3D and node.mesh != null:
		for surface in range(node.mesh.get_surface_count()):
			var arrays = node.mesh.surface_get_arrays(surface)
			var vertices = arrays[Mesh.ARRAY_VERTEX]
			var normals = arrays[Mesh.ARRAY_NORMAL]
			var indices = arrays[Mesh.ARRAY_INDEX]
			var material = node.get_active_material(surface)
			var color = material.albedo_color if material is StandardMaterial3D else Color.WHITE
			for k in range(indices.size() if indices != null and not indices.is_empty() else vertices.size()):
				var index = indices[k] if indices != null and not indices.is_empty() else k
				output.set_color(color)
				output.set_normal((transform.basis.inverse().transposed()*normals[index]).normalized())
				output.add_vertex(transform*vertices[index])
	for child in node.get_children(): _append(child,transform,output)
