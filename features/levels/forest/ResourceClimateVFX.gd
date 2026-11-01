extends Resource
# Presentation tuning only; no climate state or gameplay/save authority.
@export_group("Grass Wind")
@export_range(0.0,3.0,0.05) var wind_deformation = 2.2
@export_range(0.0,1.0,0.05) var gust_strength = 0.85
@export_range(0.1,3.0,0.1) var gust_speed = 1.6
@export_group("Wind Lines")
@export_range(0,32,1) var wind_line_count = 14
@export_range(0.0,1.0,0.05) var wind_line_opacity = 0.5
@export_range(1.0,15.0,0.5) var wind_line_lifetime = 9.0
@export_range(0.1,3.0,0.1) var wind_line_speed = 1.4
@export_range(0.01,0.08,0.005) var wind_line_width = 0.035
@export_range(1.0,6.0,0.1) var wind_line_length = 3.5
@export_range(4.0,16.0,1.0) var wind_line_extent = 12.0
@export_group("Rain Impacts")
@export_range(0,256,1) var splash_count = 160
@export_range(0.1,3.0,0.1) var splash_size = 1.7
@export_range(0.0,1.0,0.05) var splash_opacity = 0.75
@export_range(0.0,0.5,0.05) var splash_variation = 0.25
@export_range(0.5,2.0,0.1) var rain_cycle_seconds = 1.1
@export_group("Sun Rays")
@export_range(0,16,1) var sun_ray_count = 7
@export_range(0.0,0.5,0.01) var drylands_ray_opacity = 0.24
@export_range(3.0,14.0,0.5) var sun_ray_length = 9.0
@export_range(0.1,0.8,0.05) var sun_ray_width = 0.35
@export_range(0.0,1.0,0.05) var sun_ray_speed = 0.3
@export_group("Rainbow")
@export_range(0.0,0.6,0.01) var rainbow_opacity = 0.45
@export_range(5.0,40.0,1.0) var rainbow_duration = 20.0
@export_range(0.5,5.0,0.5) var rainbow_fade = 3.0
@export_range(0.5,1.5,0.1) var rainbow_scale = 1.0
@export_range(0.05,0.6,0.05) var rainbow_min_sun_height = 0.15
@export_group("Heat Tint")
@export_range(0.0,0.6,0.01) var forest_heat_strength = 0.38
@export_range(0.0,0.6,0.01) var wetlands_heat_strength = 0.32
@export_range(0.0,0.6,0.01) var drylands_heat_strength = 0.16

func heat_strength(biome: String) -> float:
	return drylands_heat_strength if biome == "drylands" else wetlands_heat_strength if biome == "wetlands" else forest_heat_strength
