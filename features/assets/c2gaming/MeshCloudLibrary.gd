extends RefCounted
# Imported scenes are inspected once, baked into three shared meshes, then freed.
# Keep original FBX geometry, normals and transforms; the presenter owns appearance.
const SOURCES = [preload("res://features/assets/c2gaming/Cloud_01.fbx"),preload("res://features/assets/c2gaming/Cloud_02.fbx"),preload("res://features/assets/c2gaming/Cloud_03.fbx")]
static var _meshes: Array[ArrayMesh] = []

static func mesh_for(variant: int) -> ArrayMesh:
	if _meshes.is_empty():
		for i in range(SOURCES.size()):
			var scene = SOURCES[i].instantiate()
			var surface = SurfaceTool.new()
			surface.begin(Mesh.PRIMITIVE_TRIANGLES)
			_append(scene,Transform3D.IDENTITY,surface)
			var baked = surface.commit()
			var box = baked.get_aabb()
			var scale_value = [5.2,4.4,3.8][i]/box.size.x
			var normalized = SurfaceTool.new()
			normalized.begin(Mesh.PRIMITIVE_TRIANGLES)
			normalized.append_from(baked,0,Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*scale_value),-box.get_center()*scale_value))
			_meshes.append(normalized.commit())
			scene.free()
	# Small/puff/stretched/rain retain their original four batching slots.
	return _meshes[[2,1,0,1][variant]]

static func _append(node: Node, parent: Transform3D, surface: SurfaceTool):
	var transform = parent*node.transform if node is Node3D else parent
	if node is MeshInstance3D and node.mesh != null:
		for i in range(node.mesh.get_surface_count()): surface.append_from(node.mesh,i,transform)
	for child in node.get_children(): _append(child,transform,surface)
