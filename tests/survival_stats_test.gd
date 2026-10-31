extends SceneTree

const Survival = preload("res://features/player/survival_state.gd")
var checks = 0
var failures = 0

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func advance(state: RefCounted, seconds: int, temperature: float, shade: float = 0.0, safe: bool = false, resistance: bool = false, context: Dictionary = {}) -> void:
	for second in range(seconds):
		state.tick(1.0, temperature, shade, safe, resistance, context)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var comfortable = Survival.new()
	advance(comfortable, 240, 24.0)
	check(comfortable.health == 100.0 and comfortable.body_temperature == 37.0, "Comfortable exploration preserves normal body temperature and health for four minutes")
	check(comfortable.hunger > 70.0 and comfortable.thirst > 60.0, "Food and water remain forgiving during early exploration")
	var exposed = Survival.new()
	var shaded = Survival.new()
	var resistant = Survival.new()
	var first_heat_damage = -1
	var first_heat_death = -1
	for second in range(1, 241):
		exposed.tick(1.0, 45.0, 0.0, false, false)
		shaded.tick(1.0, 45.0, 1.0, false, false)
		resistant.tick(1.0, 45.0, 0.0, false, true)
		if first_heat_damage < 0 and exposed.health < 100.0:
			first_heat_damage = second
		if first_heat_death < 0 and exposed.dead:
			first_heat_death = second
	check(first_heat_damage >= 120 and first_heat_damage <= 240, "Unprotected 45 C becomes dangerous after two to four minutes")
	check(first_heat_death > first_heat_damage + 45, "Heat danger leaves time to reach shelter before death")
	check(shaded.health > exposed.health and shaded.body_temperature < exposed.body_temperature, "Shade protects body temperature and health")
	check(resistant.health > exposed.health and resistant.body_temperature < exposed.body_temperature, "Heat Resistance slows body warming")
	var dry_cold = Survival.new()
	var wet_cold = Survival.new()
	wet_cold.wetness = 80.0
	advance(dry_cold, 90, 8.0)
	advance(wet_cold, 90, 8.0, 0.0, false, false, {"weather": "rain", "wind": 1.0})
	check(wet_cold.body_temperature < dry_cold.body_temperature and wet_cold.health < dry_cold.health, "Cold rain and wind make wet clothing hazardous")
	var rain_open = Survival.new()
	var rain_canopy = Survival.new()
	advance(rain_open, 30, 18.0, 0.0, false, false, {"weather": "rain", "canopy": 0.0})
	advance(rain_canopy, 30, 18.0, 0.0, false, false, {"weather": "rain", "canopy": 1.0})
	check(rain_open.wetness > 40.0 and rain_canopy.wetness < 10.0, "Canopy intercepts most rain while leaving partial wetting")
	check(rain_open.body_temperature < rain_canopy.body_temperature, "Rain cooling uses actual wetness")
	var wet_hot = Survival.new()
	var dry_hot = Survival.new()
	wet_hot.wetness = 100.0
	advance(wet_hot, 30, 45.0)
	advance(dry_hot, 30, 45.0)
	check(wet_hot.body_temperature < dry_hot.body_temperature, "Evaporation provides useful short-term heat relief")
	for temperature in [32.0, 42.0]:
		var resting = Survival.new()
		resting.body_temperature = temperature
		resting.wetness = 80.0
		resting.health = 40.0
		advance(resting, 45, -10.0, 0.0, true, false, {"weather": "clear"})
		check(resting.body_temperature == 37.0 and resting.wetness == 0.0 and resting.health == 100.0, "Camp warms or cools safely, dries clothes and heals")
		check(resting.hunger < 100.0 and resting.thirst < 100.0, "Camp does not invent food or drinking water")
	var fair_start = Survival.new()
	advance(fair_start, 180, 28.0)
	check(fair_start.health == 100.0 and fair_start.hunger > 10.0 and fair_start.thirst > 10.0, "First three minutes do not force food or water damage")
	var depleted = Survival.new()
	depleted.hunger = 11.0
	depleted.thirst = 11.0
	depleted.tick(5.0, 24.0, 0.0, false, false)
	check(depleted.health == 100.0, "Reserves above the critical threshold do not damage health")
	depleted.hunger = 0.0
	depleted.thirst = 0.0
	depleted.tick(10.0, 24.0, 0.0, false, false)
	check(depleted.health > 85.0 and depleted.health < 100.0 and not depleted.dead, "Empty reserves cause gradual, recoverable health loss")
	check(not depleted.eat_berry(), "Eating requires an actual berry")
	depleted.add_berries(2)
	depleted.add_berries(-5)
	check(depleted.berry_count == 2 and depleted.eat_berry() and depleted.berry_count == 1, "Eating consumes exactly one collected berry")
	check(depleted.hunger == 24.0 and depleted.thirst == 3.0, "Berries restore bounded food and a little water")
	check(depleted.drink() and depleted.thirst == 48.0, "Drinking restores water reserves")
	depleted.hunger = 99.0
	depleted.thirst = 99.0
	check(depleted.eat_berry() and depleted.hunger == 100.0 and depleted.thirst == 100.0, "Consumption clamps reserves at full")
	depleted.add_berries(1)
	check(not depleted.eat_berry() and depleted.berry_count == 1 and not depleted.drink(), "Full reserves do not waste berries or report a drink")
	depleted.damage(1000.0)
	depleted.tick(30.0, 24.0, 1.0, true, true)
	check(depleted.dead and depleted.health == 0.0, "Lethal damage latches death and camp cannot resurrect")
	check(not depleted.eat_berry() and not depleted.drink(), "Consumption cannot revive a dead run")
	var fresh = Survival.new()
	check(not fresh.dead and fresh.health == 100.0 and fresh.body_temperature == 37.0 and fresh.wetness == 0.0 and fresh.hunger == 100.0 and fresh.thirst == 100.0 and fresh.berry_count == 0, "A new attempt resets every temporary survival state")
	for delta in [-1.0, 0.0, NAN, INF]:
		fresh.tick(delta, 45.0, 0.0, false, false)
	fresh.tick(1.0, NAN, 0.0, false, false)
	fresh.tick(1.0, 24.0, INF, false, false)
	fresh.damage(NAN)
	fresh.damage(-1.0)
	check(fresh.health == 100.0 and fresh.body_temperature == 37.0 and fresh.hunger == 100.0 and fresh.thirst == 100.0, "Invalid deltas, environment and damage cannot mutate state")
	fresh.tick(1.0, 24.0, 0.0, false, false, {"canopy": NAN, "wind": "bad", "fire_hazard": INF})
	check(is_finite(fresh.body_temperature) and is_finite(fresh.wetness), "Malformed optional context falls back safely")
	var extreme = Survival.new()
	var bounded = Survival.new()
	var began = Time.get_ticks_usec()
	extreme.tick(1.0e20, 45.0, 0.0, false, false)
	var elapsed_ms = (Time.get_ticks_usec() - began) / 1000.0
	bounded.tick(30.0, 45.0, 0.0, false, false)
	check(extreme.body_temperature == bounded.body_temperature and extreme.hunger == bounded.hunger and extreme.thirst == bounded.thirst and elapsed_ms < 2000.0, "Extreme catch-up is bounded to thirty seconds and finishes promptly")
	var small_steps = Survival.new()
	for frame in range(120):
		small_steps.tick(0.25, 45.0, 0.0, false, false)
	check(is_equal_approx(small_steps.body_temperature, bounded.body_temperature) and is_equal_approx(small_steps.thirst, bounded.thirst), "Thermal and reserve integration agrees across frame partitions")
	fresh.exposure = 42.0
	check(fresh.exposure == 42.0 and fresh.body_temperature > 37.0, "Legacy exposure maps to actual body temperature")
	fresh.tick(10.0, 24.0, 0.0, false, false)
	check(fresh.exposure < 42.0, "Comfortable conditions reduce derived overheating risk")
	var fire_warmth = Survival.new()
	fire_warmth.wetness = 50.0
	fire_warmth.tick(5.0, 24.0, 0.0, false, false, {"fire_hazard": 1.0})
	check(fire_warmth.body_temperature > 37.0 and fire_warmth.wetness < 50.0 and fire_warmth.health == 100.0, "Fire context warms and dries; direct fire health damage stays level-owned")
	print("SURVIVAL STATS: ", checks, " checks, ", failures, " failures; 45 C danger at ", first_heat_damage, " s, death at ", first_heat_death, " s; cap runtime ", elapsed_ms, " ms")
	quit(0 if failures == 0 else 1)
