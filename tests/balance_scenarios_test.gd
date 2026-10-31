extends SceneTree
const Data = preload("res://features/levels/forest/grid_data.gd")
const Survival = preload("res://features/player/survival_state.gd")
const Climate = preload("res://features/levels/forest/climate_simulation.gd")
func _initialize():
	call_deferred("run")
func run():
	for world_seed in [2026, 42, 7]:
		var grid = Data.new()
		grid.generate(world_seed)
		var climate = Climate.new()
		climate.configure(grid, world_seed)
		var exposed = Survival.new()
		var sheltered = Survival.new()
		var resistant = Survival.new()
		var first_danger = -1
		var first_death = -1
		var first_fire = -1
		var max_fire = 0
		var min_moisture = 1.0
		var minimum_temperature = climate.temperature
		var maximum_temperature = climate.temperature
		var began = Time.get_ticks_usec()
		for second in range(1, 601):
			climate.tick()
			exposed.tick(1.0, climate.temperature, 0.0, false, false)
			sheltered.tick(1.0, climate.temperature, 0.6, false, false)
			resistant.tick(1.0, climate.temperature, 0.0, false, true)
			if first_danger < 0 and exposed.exposure >= exposed.DANGER_EXPOSURE:
				first_danger = second
			if first_death < 0 and exposed.dead:
				first_death = second
			var flames = 0
			for data in grid.cells:
				flames += 1 if data.burning else 0
				if data.terrain != "water":
					min_moisture = minf(min_moisture, data.moisture)
			if flames > 0 and first_fire == -1:
				first_fire = second
			max_fire = maxi(max_fire, flames)
			minimum_temperature = minf(minimum_temperature, climate.temperature)
			maximum_temperature = maxf(maximum_temperature, climate.temperature)
		var mean_health = 0.0
		var ground_count = 0
		var burned_count = 0
		for data in grid.cells:
			if data.terrain != "water":
				mean_health += data.health
				ground_count += 1
			burned_count += 1 if data.burned else 0
		print("SURVIVAL seed=", world_seed, " exposed_danger=", first_danger, " exposed_death=", first_death, " shade_health_600=", sheltered.health, " resistance_health_600=", resistant.health)
		print("BALANCE seed=", world_seed, " first_fire=", first_fire, " max_burning=", max_fire, " min_ground_moisture=", min_moisture, " mean_health_600=", mean_health / ground_count, " temperature_range=", minimum_temperature, "..", maximum_temperature, " burned_cells=", burned_count, " runtime_ms=", (Time.get_ticks_usec() - began) / 1000.0)
	quit()
