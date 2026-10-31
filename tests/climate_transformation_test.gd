extends SceneTree
const Data = preload("res://features/levels/forest/grid_data.gd")
const Climate = preload("res://features/levels/forest/climate_simulation.gd")
const Terrain = preload("res://features/levels/forest/RendererTerrain.gd")
var failures = 0
func check(value, message):
	if not value:
		failures += 1
		push_error(message)
func _initialize():
	call_deferred("run")
func run():
	var grid = Data.new()
	grid.generate(2026)
	var climate = Climate.new()
	climate.configure(grid, 2026)
	climate.weather_override = "heat"
	climate.baseline_temperature = 42.0
	climate.ignition_chance = 0.0
	var pond = -1
	for i in range(grid.cells.size()):
		if grid.cells[i].terrain == "water":
			pond = i
	check(pond >= 0, "Seed has a real pond")
	for i in range(100):
		climate.tick(30.0)
	var dry_count = 0
	for data in grid.cells:
		if data.terrain != "water" and data.health < 0.25 and data.moisture < 0.2:
			dry_count += 1
	check(dry_count > 200, "Actual prolonged no-rain heat produces a dry sparse world")
	var pond_cell = Vector2i(pond % grid.SIZE, floori(float(pond) / grid.SIZE))
	check(grid.traversable(pond_cell), "Actual evaporation opens the pond cell")
	check(Terrain.water_surface_scale(grid.cells[pond].water_level) == 0.0, "Traversable dry pond has no blue water surface")
	check(Terrain.water_surface_scale(0.6) > Terrain.water_surface_scale(0.3), "Water surface shrinks with bounded water level")
	var burned_cell = Vector2i(2,2)
	while grid.cells[burned_cell.y * grid.SIZE + burned_cell.x].terrain == "water":
		burned_cell.x += 1
	var data = grid.cells[burned_cell.y * grid.SIZE + burned_cell.x]
	climate._ignite(burned_cell)
	for i in range(30):
		climate.tick(1.0)
	check(data.burned and data.health == 0.0, "Actual ignition consumes fuel and leaves charred ground")
	climate.weather_override = "rain"
	climate.baseline_temperature = 20.0
	climate.warming_limit = 0.0
	climate.tick(30.0)
	check(data.burned and data.burn_recovery < 0.2, "First rain does not instantly erase char")
	for i in range(50):
		climate.tick(30.0)
	check(data.health > 0.5 and data.burn_recovery > 0.5 and data.fuel == 0.0, "Sustained favorable weather gradually recovers ground without renewing fire fuel")
	check(grid.cells[pond].water_level > 0.1 and not grid.traversable(pond_cell), "Actual rainfall refills the pond and restores blocking")
	check(Terrain.water_surface_scale(grid.cells[pond].water_level) > 0.0, "Refilled pond surface reappears")
	var renderer = Terrain.new()
	var palette: Array[ShaderMaterial] = []
	for i in range(16):
		palette.append(ShaderMaterial.new())
	renderer.configure(grid, palette, StandardMaterial3D.new(), ShaderMaterial.new())
	check(renderer.rendered_cell_count() == grid.cells.size(), "Every cell retains a solid bed under optional water")
	check(renderer.batches.size() == 18, "Water and climate terrain retain bounded shared batches")
	for batch in renderer.batches:
		check(batch.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "Coplanar terrain receives shadows without casting self-shadow acne")
		check(batch.custom_aabb.size.x == grid.SIZE * grid.CELL_SIZE, "Initially empty climate batches retain bounded full-grid culling bounds")
	renderer.free()
	print("CLIMATE TRANSFORMATION: ", failures, " failures; dry cells=", dry_count)
	quit(0 if failures == 0 else 1)
