extends Node
# Isolated prototype: one bounded screen-space decision, never per-blade polling.
# Experimental-branch default; --grass-no-lod provides comparison.
var cover: Node3D
var high: ArrayMesh
var low: ArrayMesh
var blend = 0.0
var target = 0.0
var clock = 0.0
var projected_height = 0.0
var projected_width = 0.0
var low_active = false
func configure(owner_cover):
	cover = owner_cover
	high = cover.batches[0].renderer.multimesh.mesh
	low = cover._grass_tuft(1)

static func screen_size(camera: Camera3D, origin: Vector3) -> Vector2:
	if camera.is_position_behind(origin): return Vector2.ZERO
	var screen = camera.unproject_position(origin)
	var height = screen.distance_to(camera.unproject_position(origin+Vector3.UP*0.5))
	var width = maxf(screen.distance_to(camera.unproject_position(origin+Vector3.RIGHT*0.1)),screen.distance_to(camera.unproject_position(origin+Vector3.BACK*0.1)))
	var viewport = camera.get_viewport()
	var logical = viewport.get_visible_rect().size
	var physical = Vector2(viewport.get_texture().get_size())
	var pixel_scale = physical.y/maxf(1.0,logical.y)
	return Vector2(height,width)*pixel_scale

func _process(delta):
	if cover == null or cover.batches.is_empty(): return
	clock -= delta
	var batch = cover.batches[0]
	if clock <= 0:
		clock = 0.15
		var camera = get_viewport().get_camera_3d()
		if camera == null: return
		# Conservative largest sample protects close parts of a perspective board.
		var pixels = Vector2.ZERO
		for anchor in [Vector3.ZERO,Vector3(-12,0,-12),Vector3(12,0,-12),Vector3(-12,0,12),Vector3(12,0,12)]:
			var sample = screen_size(camera,cover.to_global(anchor))
			pixels = pixels.max(sample)
		projected_height = pixels.x
		projected_width = pixels.y
		target = 1.0-smoothstep(5.0,10.0,maxf(projected_height,projected_width*2.0))
		if low_active and target < 0.98:
			batch.renderer.multimesh.mesh = high
			low_active = false
	blend = move_toward(blend,target,delta*2.5)
	batch.renderer.material_override.set_shader_parameter("lod_straighten",blend)
	if not low_active and blend >= 0.999 and target >= 0.999:
		batch.renderer.multimesh.mesh = low
		low_active = true
