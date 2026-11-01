extends Node3D
# Cosmetic seeded candidates,10 bounded batches; authoritative cell state is read-only.
const MESHES = preload("res://features/assets/c2gaming/MeshEcologyLibrary.gd")
var batches: Array[MultiMeshInstance3D] = []
var sites: Array[Dictionary] = []
var clock = 0.0
var _materials: Array[ShaderMaterial] = []
var _world: Node3D

func configure(world: Node3D):
	name = "EcologyDecorations"
	_world = world
	var grid = world.grid
	var biome = world.region_id
	var rng = RandomNumberGenerator.new()
	rng.seed = world.world_seed ^ 0xF10E2
	var noise = FastNoiseLite.new()
	noise.seed = world.world_seed
	noise.frequency = 0.13
	var groups: Array = []
	for i in range(10): groups.append([])
	var flower_limit = {"forest":120,"wetlands":160,"drylands":40}[biome]
	var branch_limit = {"forest":24,"wetlands":12,"drylands":32}[biome]
	var flowers = 0
	var branches = 0
	for index in range(grid.cells.size()):
		rng.seed = world.world_seed ^ 0xF10E2 ^ (index*7919)
		var cell = Vector2i(index%grid.SIZE,index/grid.SIZE)
		if not _eligible(cell): continue
		var at = grid.world_position(cell)
		var patch = smoothstep(0.25,0.75,0.5+0.5*noise.get_noise_2d(at.x,at.z))
		var wet = 1.0
		if biome == "wetlands":
			for neighbor in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
				var next = cell+neighbor
				if grid.in_bounds(next) and grid.cells[next.y*grid.SIZE+next.x].get("water",false): wet = 1.4
		var flower_chance = {"forest":0.7,"wetlands":0.9,"drylands":0.22}[biome]*patch*wet
		if rng.randf() < flower_chance and flowers < flower_limit:
			var center = Vector3(rng.randf_range(-0.45,0.45),0.035,rng.randf_range(-0.45,0.45))
			for j in range(1 if biome == "drylands" else 2):
				if flowers >= flower_limit: break
				_add_site(groups,rng.randi_range(0,4),index,at+center+Vector3(rng.randf_range(-0.2,0.2),0,rng.randf_range(-0.2,0.2)),rng)
				flowers += 1
		else:
			var trees = 0
			for neighbor in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
				var next = cell+neighbor
				if grid.in_bounds(next) and grid.cells[next.y*grid.SIZE+next.x].tree: trees += 1
			var chance = {"forest":0.16,"wetlands":0.08,"drylands":0.22}[biome]*(0.6+trees*0.4)
			if rng.randf() < chance and branches < branch_limit:
				_add_site(groups,rng.randi_range(5,9),index,at+Vector3(rng.randf_range(-0.25,0.25),0.035,rng.randf_range(-0.25,0.25)),rng)
				branches += 1
	for is_branch in [false,true]:
		var material = ShaderMaterial.new()
		material.shader = preload("res://features/levels/forest/ShaderEcologyProps.gdshader")
		material.set_shader_parameter("branch",is_branch)
		material.set_shader_parameter("wetlands",biome == "wetlands")
		_materials.append(material)
	for variant in range(10):
		var batch = MultiMeshInstance3D.new()
		batch.name = MESHES.FILES[variant]
		batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		batch.multimesh = MultiMesh.new()
		batch.multimesh.transform_format = MultiMesh.TRANSFORM_3D
		batch.multimesh.use_custom_data = true
		batch.multimesh.use_colors = true
		batch.multimesh.mesh = MESHES.mesh_for(variant)
		batch.multimesh.instance_count = groups[variant].size()
		batch.material_override = _materials[0 if variant < 5 else 1]
		for slot in range(groups[variant].size()):
			var site = groups[variant][slot]
			site.batch = variant;site.slot = slot
			batch.multimesh.set_instance_transform(slot,site.transform)
			batch.multimesh.set_instance_color(slot,Color.WHITE)
			sites.append(site)
		add_child(batch)
		batches.append(batch)
	update_state()

func _add_site(groups: Array, variant: int, index: int, at: Vector3, rng: RandomNumberGenerator):
	var scale_value = rng.randf_range(0.8,1.15)
	groups[variant].append({"index":index,"transform":Transform3D(Basis(Vector3.UP,rng.randf_range(0,TAU)).scaled(Vector3.ONE*scale_value),at),"from":0.0,"target":0.0,"start":0.0,"active":-1.0})

func _eligible(cell: Vector2i) -> bool:
	var grid = _world.grid
	if not grid.in_bounds(cell) or cell.x <= 0 or cell.y <= 0 or cell.x >= grid.SIZE-1 or cell.y >= grid.SIZE-1: return false
	if cell.distance_to(grid.start) < 2.5 or cell.x == grid.start.x or cell.y == grid.start.y or cell == grid.objective or _world.decorated_cells.has(cell): return false
	# Unlike planting occupancy, decorative props must ignore the player's temporary cell.
	for descriptor in _world.custom_interactables:
		if descriptor.cell == cell: return false
	var data = grid.cells[cell.y*grid.SIZE+cell.x]
	return data.terrain == "grass" and not data.get("water",false) and not data.tree and not data.get("log",false) and not data.get("berry_bush",false) and not data.get("prepared",false) and not data.get("tilled",false) and not data.get("burning",false) and not data.get("burned",false) and data.get("pending_seeds",0) == 0 and data.get("tree_state","") != "stump"

func update_state():
	for site in sites:
		var grid = _world.grid
		var data = grid.cells[site.index]
		var cell = Vector2i(site.index%grid.SIZE,site.index/grid.SIZE)
		var active = 1.0 if _eligible(cell) else 0.0
		var target = minf(float(data.get("health",1)),smoothstep(0.04,0.65,float(data.get("moisture",1))))
		if absf(site.target-target) < 0.001 and active == site.active: continue
		site.from = lerpf(site.from,site.target,clampf((clock-site.start)/2.5,0,1))
		site.target = target;site.start = clock;site.active = active
		batches[site.batch].multimesh.set_instance_custom_data(site.slot,Color(site.from,target,clock,active))

func _process(delta: float):
	clock += delta
	for material in _materials: material.set_shader_parameter("visual_time",clock)
