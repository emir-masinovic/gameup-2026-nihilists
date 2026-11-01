extends RefCounted

# Celsius is the authoritative temperature state. Exposure remains a compatibility
# view for older callers; it is never integrated separately from body temperature.
const NORMAL_BODY_TEMPERATURE = 37.0
const HEAT_THRESHOLD = 28.0
const DANGER_EXPOSURE = 60.0
const MAX_TICK_SECONDS = 30.0
const STEP_SECONDS = 0.25

const MAX_HUNGER = 10.0
const MAX_THIRST = 10.0
const MAX_HEALTH = 100.0

var health = 100.0
var body_temperature = NORMAL_BODY_TEMPERATURE
var wetness = 0.0
# Food and water are remaining reserves: a high value is good (0.0 to 10.0).
var hunger = 10.0
var thirst = 10.0
var berry_count: int = 0
var dead = false
var exposure: float:
	get:
		return snappedf(clampf((body_temperature - NORMAL_BODY_TEMPERATURE) * 30.0, 0.0, 100.0), 0.001)
	set(value):
		if is_finite(value):
			body_temperature = NORMAL_BODY_TEMPERATURE + clampf(value, 0.0, 100.0) / 30.0

# Per-second game rates, kept together for balancing rather than spread over HUD
# or level code. These are deliberately forgiving exploration mechanics.
var rates: Dictionary = {
	"heat_per_degree": 0.001,
	"temperature_relaxation": 0.003,
	"cold_per_degree": 0.0012,
	"comfortable_recovery": 0.018,
	"rain_wetting": 2.0,
	"canopy_interception": 0.85,
	"drying": 0.18,
	"hot_drying": 0.018,
	"wet_cooling": 0.008,
	"camp_temperature_recovery": 0.14,
	"camp_drying": 2.5,
	"camp_healing": 4.0,
	"hunger_depletion": 0.010,
	"thirst_depletion": 0.014,
	"hot_thirst_depletion": 0.0005,
	"critical_reserve": 1.0,
	"hunger_damage": 0.35,
	"thirst_damage": 0.55,
	"hot_danger": 39.0,
	"cold_danger": 35.0,
	"temperature_damage": 0.8,
	"temperature_severity": 1.8,
	"berry_food": 3.0,
	"berry_water": 0.0,
	"drink_water": 3.0,
	"heal_amount": 10.0,
}

func tick(seconds: float, temperature: float, shade: float, safe: bool, heat_resistance: bool, context: Dictionary = {}) -> void:
	if dead or not is_finite(seconds) or seconds <= 0.0 or not is_finite(temperature) or not is_finite(shade):
		return
	if health <= 0.0:
		damage(0.0)
		return
	var shelter = clampf(shade, 0.0, 1.0)
	var canopy = _context_fraction(context, "canopy", shelter)
	var wind = _context_fraction(context, "wind", 0.0)
	var fire = _context_fraction(context, "fire_hazard", 0.0)
	var camp = _context_fraction(context, "camp_intensity", 1.0)
	var raining = context.get("weather", "clear") == "rain"
	var ambient = clampf(temperature, -60.0, 70.0)
	var hot_air = maxf(ambient - HEAT_THRESHOLD, 0.0)
	# Bound both CPU work and catch-up damage after an extreme stall.
	var remaining = minf(seconds, MAX_TICK_SECONDS)
	while remaining > 0.0:
		var step = minf(remaining, STEP_SECONDS)
		hunger = clampf(hunger - float(rates.hunger_depletion) * step, 0.0, 10.0)
		thirst = clampf(thirst - (float(rates.thirst_depletion) + hot_air * float(rates.hot_thirst_depletion)) * step, 0.0, 10.0)
		var rain_gain = float(rates.rain_wetting) * (1.0 - canopy * float(rates.canopy_interception)) if raining else 0.0
		var drying = (float(rates.drying) + hot_air * float(rates.hot_drying)) * (1.0 + wind * 0.5) + fire * 0.8
		if safe:
			if raining:
				rain_gain *= 1.0 - camp * 0.35
				drying += float(rates.camp_drying) * 0.2 * camp
			else:
				drying = float(rates.camp_drying) * camp
		wetness = clampf(wetness + (rain_gain - drying) * step, 0.0, 100.0)
		var wet_fraction = wetness / 100.0
		var warming = hot_air * float(rates.heat_per_degree) * (1.0 - shelter * 0.8)
		if heat_resistance:
			warming *= 0.5
		var cooling = maxf(16.0 + wet_fraction * 8.0 - ambient, 0.0) * float(rates.cold_per_degree) * (1.0 + wind * 0.75)
		# Evaporation helps in heat, while wet clothes raise the cold threshold.
		var evaporation = wet_fraction * float(rates.wet_cooling) * (1.0 + wind)
		# Mild-weather rain should shed excess heat without constant cooling far
		# below comfort. Colder air retains the existing cold-exposure danger.
		var response = clampf((body_temperature - 36.3) / 0.7, 0.0, 1.5)
		var temperate = clampf((ambient - 12.0) / 6.0, 0.0, 1.0) * clampf((30.0 - ambient) / 4.0, 0.0, 1.0)
		cooling *= lerpf(1.0, response, temperate)
		evaporation *= lerpf(1.0, response, temperate)
		var thermal_change = warming - cooling - evaporation + fire * 0.04
		thermal_change -= (body_temperature - NORMAL_BODY_TEMPERATURE) * float(rates.temperature_relaxation)
		if is_zero_approx(warming + cooling + evaporation + fire):
			body_temperature = move_toward(body_temperature, NORMAL_BODY_TEMPERATURE, float(rates.comfortable_recovery) * step)
		else:
			body_temperature = clampf(body_temperature + thermal_change * step, 25.0, 45.0)
		# Environment always contributes, even beside an almost-extinguished fire.
		# Retain the accepted camp comfort response, scaled by actual intensity.
		if safe and camp > 0.0:
			body_temperature = move_toward(body_temperature, NORMAL_BODY_TEMPERATURE, float(rates.camp_temperature_recovery) * camp * step)
		var severity = maxf(body_temperature - float(rates.hot_danger), float(rates.cold_danger) - body_temperature)
		if severity >= 0.0:
			damage((float(rates.temperature_damage) + severity * float(rates.temperature_severity)) * step)
		if safe and not dead:
			health = minf(100.0, health + float(rates.camp_healing) * step)
		# Depleted reserves cause gradual damage; camp does not refill food/water.
		var critical = float(rates.critical_reserve)
		var hunger_penalty = clampf((critical - hunger) / critical, 0.0, 1.0) * float(rates.hunger_damage)
		var thirst_penalty = clampf((critical - thirst) / critical, 0.0, 1.0) * float(rates.thirst_damage)
		damage((hunger_penalty + thirst_penalty) * step)
		if dead:
			return
		remaining -= step

func damage(amount: float) -> void:
	if dead or not is_finite(amount) or amount < 0.0:
		return
	health = clampf(health - amount, 0.0, 100.0)
	if health <= 0.0:
		dead = true

func add_berries(amount: int) -> void:
	if dead or amount <= 0:
		return
	berry_count += mini(amount, 2147483647 - berry_count)

func eat_berry() -> bool:
	if dead or berry_count <= 0:
		return false
	if hunger >= 9.99 and (thirst < 9.99 or health >= 100.0):
		return false
	berry_count -= 1
	hunger = minf(10.0, hunger + float(rates.berry_food))
	if float(rates.berry_water) > 0.0:
		thirst = minf(10.0, thirst + float(rates.berry_water))
	if hunger >= 9.99 and thirst >= 9.99 and health < 100.0:
		health = minf(100.0, health + float(rates.heal_amount))
	return true

func drink() -> bool:
	if dead:
		return false
	if thirst >= 9.99 and (hunger < 9.99 or health >= 100.0):
		return false
	thirst = minf(10.0, thirst + float(rates.drink_water))
	if hunger >= 9.99 and thirst >= 9.99 and health < 100.0:
		health = minf(100.0, health + float(rates.heal_amount))
	return true

func _context_fraction(context: Dictionary, key: String, fallback: float) -> float:
	var value: Variant = context.get(key, fallback)
	if (value is float or value is int) and is_finite(float(value)):
		return clampf(float(value), 0.0, 1.0)
	return fallback
