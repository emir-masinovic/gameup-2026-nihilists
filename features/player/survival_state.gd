extends RefCounted

const HEAT_THRESHOLD = 28.0
const DANGER_EXPOSURE = 60.0

var health = 100.0
var exposure = 0.0
var dead = false

func tick(seconds: float, temperature: float, shade: float, safe: bool, heat_resistance: bool) -> void:
	if dead or not is_finite(seconds) or seconds <= 0.0 or not is_finite(temperature) or not is_finite(shade):
		return
	var heat_rate = maxf(temperature - HEAT_THRESHOLD, 0.0) * 0.18 * (1.0 - clampf(shade, 0.0, 1.0) * 0.8)
	if heat_resistance:
		heat_rate *= 0.5
	# Integrate in bounded steps so a long frame cannot skip the danger threshold.
	var remaining = seconds
	while remaining > 0.0:
		var step = minf(remaining, 0.25)
		if safe:
			exposure = maxf(0.0, exposure - 12.0 * step)
			health = minf(100.0, health + 4.0 * step)
		else:
			var cooling = 0.5 + clampf(shade, 0.0, 1.0) * 4.0
			exposure = clampf(exposure + (heat_rate - cooling) * step, 0.0, 100.0)
			if exposure >= DANGER_EXPOSURE:
				health = maxf(0.0, health - (2.0 + (exposure - DANGER_EXPOSURE) * 0.15) * step)
		if health <= 0.0:
			dead = true
			return
		remaining -= step
